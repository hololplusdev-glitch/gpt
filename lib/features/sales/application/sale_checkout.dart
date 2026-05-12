import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/persistence/daos/active_pos_session_dao.dart';
import 'package:holol_POS/core/persistence/daos/catalog_dao.dart';
import 'package:holol_POS/core/persistence/daos/sales_dao.dart';
import 'package:holol_POS/core/persistence/daos/shift_dao.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/core/persistence/pos_config_repository.dart';
import 'package:holol_POS/core/services/invoice_number_service.dart';
import 'package:holol_POS/core/services/invoices/invoice_document_builder.dart';
import 'package:holol_POS/core/services/payments/payment_method_resolver.dart';
import 'package:holol_POS/core/services/pos_devices/payment_profile_service.dart';
import 'package:holol_POS/core/services/pos_devices/print_queue.dart';
import 'package:holol_POS/core/services/pos_devices/print_job_processor.dart';
import 'package:holol_POS/core/services/pricing/pricing_engine.dart';
import 'package:holol_POS/core/services/sync/upload_queue.dart';
import 'package:holol_POS/core/services/time/clock.dart';
import 'package:holol_POS/features/cashier/domain/models/cart.dart';
import 'package:holol_POS/features/sales/domain/models/sale_inputs.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
import 'package:uuid/uuid.dart';

/// Final sale completion owner.
///
/// Single allowed path:
/// PaymentDialog -> SaleCheckout.complete -> Sales aggregate + OutboxEvents + PrintJobs.
class SaleCheckout {
  final SalesDao _salesDao;
  final ShiftDao _shiftDao;
  final CatalogDao _catalogDao;
  final PosConfigRepository _config;
  final InvoiceNumberService _invoiceNumberService;
  final InvoiceDocumentBuilder _invoiceDocumentBuilder;
  final UploadQueue _uploadQueue;
  final PrintQueue _printQueue;
  final PrintJobProcessor _printJobProcessor;
  final PaymentProfileService _paymentProfileService;
  final ActivePosSession? _activeSession;
  final PricingEngine _pricingEngine;
  final Clock _clock;

  const SaleCheckout({
    required SalesDao salesDao,
    required ShiftDao shiftDao,
    required CatalogDao catalogDao,
    required PosConfigRepository config,
    required InvoiceNumberService invoiceNumberService,
    required InvoiceDocumentBuilder invoiceDocumentBuilder,
    required UploadQueue uploadQueue,
    required PrintQueue printQueue,
    required PrintJobProcessor printJobProcessor,
    required PaymentProfileService paymentProfileService,
    required ActivePosSession? activeSession,
    PricingEngine pricingEngine = const PricingEngine(),
    Clock clock = const SystemClock(),
  }) : _salesDao = salesDao,
       _shiftDao = shiftDao,
       _catalogDao = catalogDao,
       _config = config,
       _invoiceNumberService = invoiceNumberService,
       _invoiceDocumentBuilder = invoiceDocumentBuilder,
       _uploadQueue = uploadQueue,
       _printQueue = printQueue,
       _printJobProcessor = printJobProcessor,
       _paymentProfileService = paymentProfileService,
       _activeSession = activeSession,
       _pricingEngine = pricingEngine,
       _clock = clock;

  static const _uuid = Uuid();

  Future<SaleCheckoutResult> complete(SaleCheckoutRequest request) async {
    final session = _requireActiveSession();
    final shift = await _requireOpenShift(session);
    final shiftId = shift.id;

    if (request.cart.isEmpty) {
      throw const SaleCheckoutException('No items in cart.');
    }

    final draftLines = request.cart.toSaleLineInputs();
    final officialLines = await _resolveOfficialPrices(
      session: session,
      draftLines: draftLines,
    );

    _validateSaleInputs(lineItems: officialLines);

    final quote = _quoteSale(officialLines);
    final resolved = await _resolvePaymentIntent(request.paymentIntent);

    var tendered = quote.grandTotal;
    var change = 0.0;

    if (resolved.allowsChange) {
      tendered =
          double.tryParse(
            request.paymentIntent.tenderedText.trim().isEmpty
                ? '0'
                : request.paymentIntent.tenderedText,
          ) ??
          double.nan;

      if (tendered.isNaN) {
        throw const SaleCheckoutException('Enter a valid tendered amount.');
      }

      if (tendered < quote.grandTotal) {
        throw const SaleCheckoutException('Insufficient amount tendered.');
      }

      change = PricingEngine.roundAmount(tendered - quote.grandTotal);
    }

    var effectiveType = resolved.type;
    var profileRequiresReference = false;

    if (resolved.needsPaymentProfile) {
      final profile = await _paymentProfileService.getActivePaymentProfile();

      // Network/Card policy:
      // - Network is never treated as cash.
      // - If a real integrated terminal is unavailable, allow manual network
      //   recording with a warning already shown in PaymentDialog.
      // - Future terminal integration should replace this branch with actual
      //   send/wait/approve flow and terminal approval fields.
      if (profile == null || !profile.enabled) {
        effectiveType = PaymentMethodType.manualCard;
        profileRequiresReference = resolved.requiresReference;
      } else {
        final mode = PaymentProfileMode.fromCode(profile.mode);

        if (mode == PaymentProfileMode.integrated &&
            !_paymentProfileService.integratedAvailable(profile)) {
          effectiveType = PaymentMethodType.manualCard;
          profileRequiresReference =
              profile.requireReference || resolved.requiresReference;
        } else if (mode == PaymentProfileMode.integrated) {
          throw const SaleCheckoutException(
            'Integrated payment flow is not implemented yet.',
          );
        } else {
          effectiveType = PaymentMethodType.manualCard;
          profileRequiresReference =
              profile.requireReference || resolved.requiresReference;
        }
      }
    }

    final requirements = checkoutPaymentRequirements(
      resolved,
      paymentProfileRequiresReference:
          request.paymentIntent.kind == SaleTenderKind.network
          ? false
          : profileRequiresReference,
    );

    final reference = request.paymentIntent.reference.trim();

    if (requirements.requiresReference && reference.isEmpty) {
      throw const SaleCheckoutException('Payment reference is required.');
    }

    final isCustomerCredit =
        effectiveType == PaymentMethodType.customerCredit ||
        resolved.type == PaymentMethodType.customerCredit;

    if (isCustomerCredit &&
        (request.customerId == null || request.customerId!.trim().isEmpty)) {
      throw const SaleCheckoutException(
        'Customer is required for credit sale.',
      );
    }

    final payments = [
      SalePaymentInput(
        paymentMethodId: resolved.methodId,
        paymentMethodCode: resolved.code,
        paymentMethodName: resolved.displayName,
        paymentMethodType: effectiveType,
        requiresReference: requirements.requiresReference,
        amount: quote.grandTotal,
        cashTendered: resolved.allowsChange ? tendered : null,
        changeGiven: resolved.allowsChange ? change : null,
        referenceNo: reference.isEmpty ? null : reference,
        bankId: resolved.bankId,
        cardTypeId: resolved.cardTypeId,
      ),
    ];

    final paymentResult = PaymentPolicy(
      requireCardReference: false,
    ).validate(quote: quote, payments: payments);

    final localInvoiceNo = await _invoiceNumberService.generateNext(
      custCode: session.custCode,
      branchNo: session.activeBranchNo,
      machineNo: session.activeMachineNo,
      userId: session.activeUserId,
      sequenceType: _saleSequenceType(session),
    );

    final saleId = 'SALE_${_uuid.v4()}';
    final now = _clock.now();
    final idempotencyKey = 'sale_${request.checkoutAttemptId}';

    final envelope = _buildSaleEnvelope(
      saleId: saleId,
      localInvoiceNo: localInvoiceNo,
      shiftId: shiftId,
      session: session,
      lines: officialLines,
      payments: payments,
      quote: quote,
      paymentResult: paymentResult,
      customerId: request.customerId,
      customerName: request.customerName,
      customerTaxNumber: request.customerTaxNumber,
      idempotencyKey: idempotencyKey,
      now: now,
    );

    final invoiceDocument = await _invoiceDocumentBuilder
        .buildFromCheckoutSnapshot(
          saleId: saleId,
          localInvoiceNo: localInvoiceNo,
          invoiceDateTime: now,
          statusCode: SaleStatus.completed.code,
          syncStatusCode: OutboxStatus.pending.code,
          terminalId: session.activeMachineNo,
          machineNo: session.activeMachineNo,
          branchNo: session.activeBranchNo,
          branchYear: session.activeBranchYear,
          storeId: session.activeStoreId,
          priceLevelId: session.activePriceLevelId,
          useTax: session.activeUseTax,
          cashierId: session.activeUserId,
          cashierName: session.activeUserName,
          customerId: request.customerId,
          customerName: request.customerName,
          customerTaxNumber: request.customerTaxNumber,
          lines: officialLines,
          quote: quote,
          payments: payments,
          taxes: envelope.taxes,
        );

    final invoiceArchive = InvoiceDocumentsCompanion.insert(
      id: 'DOC_$saleId',
      saleId: saleId,
      snapshotJson: Value(invoiceDocument.toJsonString()),
      hash: Value(invoiceDocument.auditHash),
      archivedAt: Value(now),
      validationStatus: Value(invoiceDocument.validationStatus),
      validationError: Value(invoiceDocument.validationMessage),
    );

    final printJobs = (_config.autoPrintAfterSale || session.autoPrint)
        ? await _printQueue.invoiceReceipt(
            document: invoiceDocument,
            createdAt: now,
            createdBy: session.activeUserId,
            requireAutoPrint: true,
            preferredPrinterName: session.printerName,
          )
        : const <PrintJobsCompanion>[];

    final printJobIds = printJobs
        .map((job) => job.id.value)
        .toList(growable: false);

    await _salesDao.persistSaleEnvelope(
      header: envelope.header,
      items: envelope.items,
      payments: envelope.payments,
      taxes: envelope.taxes,
      invoiceDocument: invoiceArchive,
      printJobs: printJobs,
      auditLogEntry: envelope.auditLogEntry,
      outboxEntry: _uploadQueue.saleCreated(
        saleId: saleId,
        localInvoiceNo: localInvoiceNo,
        machineNo: session.activeMachineNo,
        branchNo: session.activeBranchNo,
        shiftId: shiftId,
        cashierId: session.activeUserId,
        grandTotal: quote.grandTotal,
        completedAt: now,
        idempotencyKey: idempotencyKey,
      ),
    );

    if (printJobIds.isNotEmpty) {
      await _printJobProcessor.processJobIds(printJobIds);
    }

    return SaleCheckoutResult(
      saleId: saleId,
      localSaleNo: localInvoiceNo,
      selectedPaymentType: effectiveType,
      change: change,
      uploadQueued: true,
    );
  }

  Future<ResolvedPaymentMethod> _resolvePaymentIntent(
    SalePaymentIntent intent,
  ) async {
    final methods = await _catalogDao.getActivePaymentMethods();

    PaymentMethod? firstWhere(bool Function(PaymentMethod method) test) {
      for (final method in methods) {
        final type = PaymentMethodResolver.typeFromStored(
          methodCode: method.code,
          storedTypeCode: method.type,
        );
        if (type != null && test(method)) return method;
      }
      return null;
    }

    PaymentMethodType? typeOf(PaymentMethod method) {
      return PaymentMethodResolver.typeFromStored(
        methodCode: method.code,
        storedTypeCode: method.type,
      );
    }

    ResolvedPaymentMethod fromRow(PaymentMethod method) {
      return PaymentMethodResolver.resolve(
        methodId: method.id,
        code: method.code,
        displayName: method.name,
        storedTypeCode: method.type,
        requiresReference: method.requiresReference,
        bankId: method.bankId,
        cardTypeId: method.cardTypeId,
      );
    }

    ResolvedPaymentMethod withoutReference(ResolvedPaymentMethod method) {
      return ResolvedPaymentMethod(
        methodId: method.methodId,
        code: method.code,
        displayName: method.displayName,
        type: method.type,
        bankId: method.bankId,
        cardTypeId: method.cardTypeId,
        requiresReference: false,
        allowsChange: method.allowsChange,
        isManual: method.isManual,
        needsPaymentProfile: method.needsPaymentProfile,
      );
    }

    switch (intent.kind) {
      case SaleTenderKind.cash:
        final method = firstWhere((method) => typeOf(method)?.isCash ?? false);
        if (method == null) {
          throw const SaleCheckoutException('لا توجد طريقة دفع كاش مفعلة.');
        }
        return fromRow(method);

      case SaleTenderKind.network:
        final manual = firstWhere(
          (method) => typeOf(method) == PaymentMethodType.manualCard,
        );
        if (manual != null) return withoutReference(fromRow(manual));

        final card = firstWhere((method) => typeOf(method)?.isCard ?? false);
        if (card != null) return withoutReference(fromRow(card));

        return const ResolvedPaymentMethod(
          methodId: 'MANUAL_CARD_FALLBACK',
          code: PaymentMethodCodes.manualCard,
          displayName: 'شبكة',
          type: PaymentMethodType.manualCard,
          requiresReference: false,
          allowsChange: false,
          isManual: true,
          needsPaymentProfile: false,
        );

      case SaleTenderKind.credit:
        final method = firstWhere(
          (method) => typeOf(method) == PaymentMethodType.customerCredit,
        );
        if (method != null) return fromRow(method);

        return const ResolvedPaymentMethod(
          methodId: 'CUSTOMER_CREDIT',
          code: 'CUSTOMER_CREDIT',
          displayName: 'آجل',
          type: PaymentMethodType.customerCredit,
          requiresReference: false,
          allowsChange: false,
          isManual: true,
          needsPaymentProfile: false,
        );
    }
  }

  Future<List<SaleLineInput>> _resolveOfficialPrices({
    required ActivePosSession session,
    required List<SaleLineInput> draftLines,
  }) async {
    final resolved = <SaleLineInput>[];

    for (final line in draftLines) {
      final price = await _catalogDao.resolveItemPrice(
        itemId: line.itemId,
        priceLevelId: session.activePriceLevelId,
        storeId: session.activeStoreId,
        unitId: line.unitId,
      );

      if (price == null) {
        throw SaleCheckoutException(
          'Missing exact ITEM_PRICE for ${line.itemName}.',
        );
      }

      resolved.add(
        SaleLineInput(
          itemId: line.itemId,
          unitId: price.unitId ?? line.unitId,
          itemName: line.itemName,
          unitName: price.unitName ?? line.unitName,
          unitSize: line.unitSize,
          barcode: line.barcode,
          unitPrice: price.unitPrice,
          taxRate: price.taxRate,
          discountType: line.discountType,
          discountValue: line.discountValue,
          discountAmount: _officialDiscountAmount(
            line: line,
            officialUnitPrice: price.unitPrice,
          ),
          allowDiscount: price.allowDiscount,
          notes: line.notes,
        ),
      );
    }

    return resolved;
  }

  Future<Shift> _requireOpenShift(ActivePosSession session) async {
    final shift = await _shiftDao.getOpenShift(
      session.activeMachineNo,
      cashierId: session.activeUserId,
    );

    if (shift == null || shift.status != ShiftStatus.open.code) {
      throw const SaleCheckoutException(
        'No open shift. Open a shift before selling.',
      );
    }

    return shift;
  }

  double _officialDiscountAmount({
    required SaleLineInput line,
    required double officialUnitPrice,
  }) {
    if (line.discountType == DiscountType.percentage &&
        line.discountValue != null) {
      final base = officialUnitPrice * line.quantity;
      return PricingEngine.roundAmount(base * (line.discountValue! / 100));
    }

    return line.discountAmount;
  }

  CheckoutQuote _quoteSale(List<SaleLineInput> lines) {
    final session = _requireActiveSession();

    try {
      return _pricingEngine.calculateQuote(
        lines: lines.toPricingLineInputs(),
        taxRate: 0,
        useTax: session.activeUseTax,
        priceIncludesTax: session.priceIncludesTax,
      );
    } on PricingException catch (e) {
      throw SaleCheckoutException(e.message);
    }
  }

  _SaleEnvelope _buildSaleEnvelope({
    required String saleId,
    required String localInvoiceNo,
    required String shiftId,
    required ActivePosSession session,
    required List<SaleLineInput> lines,
    required List<SalePaymentInput> payments,
    required CheckoutQuote quote,
    required PaymentValidationResult paymentResult,
    required String? customerId,
    required String? customerName,
    required String? customerTaxNumber,
    required String idempotencyKey,
    required DateTime now,
  }) {
    final header = SalesCompanion(
      id: Value(saleId),
      localSaleNo: Value(localInvoiceNo),
      type: Value(SaleType.sale.code),
      status: Value(SaleStatus.completed.code),
      terminalId: Value(session.activeMachineNo),
      shiftId: Value(shiftId),
      cashierId: Value(session.activeUserId),
      branchNo: Value(session.activeBranchNo),
      custCode: Value(session.custCode),
      branchYear: Value(session.activeBranchYear),
      machineNo: Value(session.activeMachineNo),
      storeId: Value(session.activeStoreId),
      priceLevelId: Value(session.activePriceLevelId),
      useTax: Value(session.activeUseTax),
      priceIncludesTax: Value(session.priceIncludesTax),
      sourceUserId: Value(session.activeUserId),
      cashierNameSnapshot: Value(session.activeUserName),
      customerId: Value(customerId),
      customerNameSnapshot: Value(customerName),
      customerTaxNumberSnapshot: Value(customerTaxNumber),
      subtotal: Value(quote.subtotal),
      discountTotal: Value(quote.discountTotal),
      taxTotal: Value(quote.taxTotal),
      grandTotal: Value(quote.grandTotal),
      paidTotal: Value(paymentResult.paidTotal),
      remainingTotal: Value(paymentResult.remainingTotal),
      changeTotal: Value(paymentResult.changeTotal),
      idempotencyKey: Value(idempotencyKey),
      createdAt: Value(now),
      completedAt: Value(now),
    );

    final processedItems = <_ProcessedItem>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final pricedLine = quote.lines[i];

      processedItems.add(
        _ProcessedItem(
          input: line,
          taxableAmount: pricedLine.taxableAmount,
          taxAmount: pricedLine.taxAmount,
          lineTotal: pricedLine.lineTotal,
        ),
      );
    }

    final itemCompanions = <SaleLinesCompanion>[];

    for (final p in processedItems) {
      itemCompanions.add(
        SaleLinesCompanion(
          id: Value('TI_${_uuid.v4()}'),
          saleId: Value(saleId),
          itemId: Value(p.input.itemId),
          unitId: Value(p.input.unitId),
          itemNameSnapshot: Value(p.input.itemName),
          unitNameSnapshot: Value(p.input.unitName),
          barcode: Value(p.input.barcode),
          qtyScaled: Value(_toQtyScaled(p.input.quantity)),
          qtyScale: const Value(_quantityScale),
          unitPrice: Value(p.input.unitPrice),
          taxRate: Value(p.input.taxRate),
          taxableAmount: Value(p.taxableAmount),
          taxAmount: Value(p.taxAmount),
          lineDiscountType: Value(p.input.discountType?.code),
          lineDiscountValue: Value(p.input.discountValue),
          lineDiscountAmount: Value(p.input.discountAmount),
          grossAmount: Value(p.input.unitPrice * p.input.quantity),
          allowDiscountSnapshot: Value(p.input.allowDiscount),
          storeId: Value(session.activeStoreId),
          priceLevelId: Value(session.activePriceLevelId),
          unitSize: Value(p.input.unitSize),
          lineTotal: Value(p.lineTotal),
          notes: Value(p.input.notes),
        ),
      );
    }

    final paymentCompanions = <SalePaymentsCompanion>[];

    for (final p in payments) {
      final paymentType = p.resolvedType;

      paymentCompanions.add(
        SalePaymentsCompanion(
          id: Value('TP_${_uuid.v4()}'),
          saleId: Value(saleId),
          paymentMethodId: Value(p.paymentMethodId),
          methodCodeSnapshot: Value(p.paymentMethodCode),
          methodNameSnapshot: Value(p.paymentMethodName ?? p.paymentMethodCode),
          methodTypeSnapshot: Value(paymentType.code),
          isManual: Value(PaymentMethodResolver.isManual(paymentType)),
          amount: Value(p.amount),
          cashTendered: Value(p.cashTendered),
          changeGiven: Value(p.changeGiven),
          referenceNo: Value(p.referenceNo),
          bankId: Value(p.bankId),
          cardTypeId: Value(p.cardTypeId),
          paymentDeviceRef: Value(p.terminalRef),
          authCode: Value(p.authCode),
          rrn: Value(p.rrn),
          cardScheme: Value(p.cardScheme),
          cardLast4: Value(p.cardLast4),
          status: Value(PaymentStatus.completed.code),
          createdAt: Value(now),
        ),
      );
    }

    final taxCompanions = <SaleTaxSummaryCompanion>[];
    final taxGroups =
        <double, ({double taxableAmount, double taxAmount, double rate})>{};

    for (final p in processedItems) {
      if (p.taxAmount <= 0 && p.input.taxRate <= 0) continue;

      final existing = taxGroups[p.input.taxRate];
      taxGroups[p.input.taxRate] = (
        taxableAmount: (existing?.taxableAmount ?? 0) + p.taxableAmount,
        taxAmount: (existing?.taxAmount ?? 0) + p.taxAmount,
        rate: p.input.taxRate,
      );
    }

    for (final entry in taxGroups.entries) {
      taxCompanions.add(
        SaleTaxSummaryCompanion(
          id: Value('TT_${_uuid.v4()}'),
          saleId: Value(saleId),
          taxRate: Value(entry.value.rate),
          taxableAmount: Value(entry.value.taxableAmount),
          taxAmount: Value(entry.value.taxAmount),
        ),
      );
    }

    final auditLogEntry = AuditLogCompanion(
      id: Value('AUD_${_uuid.v4()}'),
      action: Value(AuditAction.saleCompleted.code),
      actorId: Value(session.activeUserId),
      actorName: Value(session.activeUserName),
      targetType: Value(OutboxEntityType.sale.code),
      targetId: Value(saleId),
      detailsJson: Value(
        jsonEncode({
          'invoiceNo': localInvoiceNo,
          'grandTotal': quote.grandTotal,
          'itemCount': lines.length,
        }),
      ),
      terminalId: Value(session.activeMachineNo),
      createdAt: Value(now),
    );

    return _SaleEnvelope(
      header: header,
      items: itemCompanions,
      payments: paymentCompanions,
      taxes: taxCompanions,
      auditLogEntry: auditLogEntry,
    );
  }

  void _validateSaleInputs({required List<SaleLineInput> lineItems}) {
    for (final line in lineItems) {
      if (line.quantity <= 0) {
        throw SaleCheckoutException('Invalid quantity for ${line.itemName}.');
      }

      if (line.unitPrice <= 0) {
        throw SaleCheckoutException('Missing price for ${line.itemName}.');
      }

      if (line.discountAmount < 0) {
        throw SaleCheckoutException('Invalid discount for ${line.itemName}.');
      }

      if (!line.allowDiscount && line.discountAmount > 0) {
        throw SaleCheckoutException(
          'Discounts are not allowed for ${line.itemName}.',
        );
      }

      if (line.taxRate < 0) {
        throw SaleCheckoutException('Invalid tax rate for ${line.itemName}.');
      }

      final lineSubtotal = line.unitPrice * line.quantity;

      if (line.discountAmount > lineSubtotal) {
        throw SaleCheckoutException(
          'Discount exceeds line subtotal for ${line.itemName}.',
        );
      }
    }
  }

  String _saleSequenceType(ActivePosSession session) {
    final series = session.invoiceSeries?.trim();
    return series == null || series.isEmpty ? 'sale' : series;
  }

  ActivePosSession _requireActiveSession() {
    final session = _activeSession;

    if (session == null) {
      throw const SaleCheckoutException(
        'Select a cashier and POS machine before selling.',
      );
    }

    return session;
  }
}

class SaleCheckoutRequest {
  final Cart cart;
  final String checkoutAttemptId;
  final SalePaymentIntent paymentIntent;
  final String? customerId;
  final String? customerName;
  final String? customerTaxNumber;

  const SaleCheckoutRequest({
    required this.cart,
    required this.checkoutAttemptId,
    required this.paymentIntent,
    this.customerId,
    this.customerName,
    this.customerTaxNumber,
  });
}

class CheckoutPaymentRequirements {
  final bool requiresReference;
  final bool showsReference;

  const CheckoutPaymentRequirements({
    required this.requiresReference,
    required this.showsReference,
  });
}

CheckoutPaymentRequirements checkoutPaymentRequirements(
  ResolvedPaymentMethod method, {
  bool paymentProfileRequiresReference = false,
}) {
  final requiresReference =
      method.requiresReference ||
      (method.needsPaymentProfile && paymentProfileRequiresReference);

  return CheckoutPaymentRequirements(
    requiresReference: requiresReference,
    showsReference: requiresReference || !method.type.isCash,
  );
}

class SaleCheckoutResult {
  final String saleId;
  final String localSaleNo;
  final PaymentMethodType selectedPaymentType;
  final double change;
  final bool uploadQueued;
  const SaleCheckoutResult({
    required this.saleId,
    required this.localSaleNo,
    required this.selectedPaymentType,
    required this.change,
    required this.uploadQueued,
  });

  String get invoiceNo => localSaleNo;
}

class SaleCheckoutException extends BusinessException {
  const SaleCheckoutException(super.message) : super(code: 'checkout_error');
}

class PaymentPolicy {
  final bool requireCardReference;

  const PaymentPolicy({required this.requireCardReference});

  PaymentValidationResult validate({
    required CheckoutQuote quote,
    required List<SalePaymentInput> payments,
  }) {
    if (payments.isEmpty) {
      throw const SaleCheckoutException('At least one payment is required.');
    }

    if (quote.grandTotal < 0) {
      throw const SaleCheckoutException('Invalid sale total.');
    }

    var paidTotal = 0.0;
    var explicitChangeTotal = 0.0;
    var hasChangeCapablePayment = false;

    for (final payment in payments) {
      final type = payment.resolvedType;

      if (payment.amount <= 0) {
        throw const SaleCheckoutException(
          'Payment amount must be greater than zero.',
        );
      }

      final cashTendered = payment.cashTendered;
      final changeGiven = payment.changeGiven ?? 0;

      if ((cashTendered ?? 0) < 0 || changeGiven < 0) {
        throw const SaleCheckoutException(
          'Invalid cash tendered/change values.',
        );
      }

      if (type.allowsChange) {
        hasChangeCapablePayment = true;

        if (cashTendered != null && cashTendered < payment.amount) {
          throw const SaleCheckoutException(
            'Cash tendered is less than payment amount.',
          );
        }
      } else if (changeGiven > 0 || cashTendered != null) {
        throw const SaleCheckoutException(
          'Change is only allowed for cash payments.',
        );
      }

      if (payment.requiresReference ||
          (requireCardReference && type.isManualCard)) {
        if (!payment.hasReference) {
          throw const SaleCheckoutException(
            'Card payment reference is required.',
          );
        }
      }

      if (type.isIntegratedCard && !payment.hasTerminalApproval) {
        throw const SaleCheckoutException(
          'Integrated card payment requires terminal approval.',
        );
      }

      if (type == PaymentMethodType.customerCredit) {
        // Credit sale is an accounts-receivable balance, not a collected payment.
        // It is allowed only after SaleCheckout.complete has verified customerId.
        // Keep the SalePayment row as the payment arrangement snapshot, but do
        // not include it in paidTotal.
        continue;
      }

      paidTotal += payment.amount;
      explicitChangeTotal += changeGiven;
    }

    final remaining = quote.grandTotal - paidTotal;

    if (remaining > 0 &&
        !payments.any(
          (payment) => payment.resolvedType == PaymentMethodType.customerCredit,
        )) {
      throw SaleCheckoutException(
        'Payment of ${paidTotal.toStringAsFixed(2)} is insufficient for total ${quote.grandTotal.toStringAsFixed(2)}',
      );
    }

    final overpayment = paidTotal > quote.grandTotal
        ? paidTotal - quote.grandTotal
        : 0.0;

    if ((overpayment > 0 || explicitChangeTotal > 0) &&
        !hasChangeCapablePayment) {
      throw const SaleCheckoutException(
        'Overpayment requires a cash payment for change.',
      );
    }

    return PaymentValidationResult(
      paidTotal: paidTotal,
      remainingTotal: remaining > 0 ? remaining : 0,
      changeTotal: explicitChangeTotal > 0 ? explicitChangeTotal : overpayment,
    );
  }
}

class PaymentValidationResult {
  final double paidTotal;
  final double remainingTotal;
  final double changeTotal;

  const PaymentValidationResult({
    required this.paidTotal,
    required this.remainingTotal,
    required this.changeTotal,
  });
}

class _SaleEnvelope {
  final SalesCompanion header;
  final List<SaleLinesCompanion> items;
  final List<SalePaymentsCompanion> payments;
  final List<SaleTaxSummaryCompanion> taxes;
  final AuditLogCompanion auditLogEntry;

  const _SaleEnvelope({
    required this.header,
    required this.items,
    required this.payments,
    required this.taxes,
    required this.auditLogEntry,
  });
}

class _ProcessedItem {
  final SaleLineInput input;
  final double taxableAmount;
  final double taxAmount;
  final double lineTotal;

  const _ProcessedItem({
    required this.input,
    required this.taxableAmount,
    required this.taxAmount,
    required this.lineTotal,
  });
}

const int _quantityScale = 1000;

int _toQtyScaled(double quantity) => (quantity * _quantityScale).round();

final saleCheckoutProvider = Provider<SaleCheckout>((ref) {
  return SaleCheckout(
    salesDao: ref.watch(salesDaoProvider),
    shiftDao: ref.watch(shiftDaoProvider),
    catalogDao: ref.watch(catalogDaoProvider),
    config: ref.watch(posConfigProvider),
    invoiceNumberService: ref.watch(invoiceNumberServiceProvider),
    invoiceDocumentBuilder: ref.watch(invoiceDocumentBuilderProvider),
    uploadQueue: ref.watch(uploadQueueProvider),
    printQueue: ref.watch(printQueueProvider),
    printJobProcessor: ref.watch(printJobProcessorProvider),
    paymentProfileService: ref.watch(paymentProfileServiceProvider),
    activeSession: ref.watch(activePosSessionProvider).valueOrNull,
    clock: ref.watch(clockProvider),
  );
});
