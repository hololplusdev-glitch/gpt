
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
import 'package:holol_POS/core/services/pos_devices/payment_profile_service.dart';
import 'package:holol_POS/core/services/pos_devices/print_queue.dart';
import 'package:holol_POS/core/services/pos_devices/print_job_processor.dart';
import 'package:holol_POS/core/services/pricing/pricing_engine.dart';
import 'package:holol_POS/core/services/sync/outbox_event_factory.dart';
import 'package:holol_POS/core/services/time/clock.dart';
import 'package:holol_POS/features/cashier/domain/models/cart.dart';
import 'package:holol_POS/features/sales/domain/models/sale_inputs.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
import 'package:uuid/uuid.dart';
import 'package:holol_POS/shared/refactor/pos_business_rules.dart';
import 'package:holol_POS/shared/refactor/pos_payment_draft.dart';

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
  final OutboxEventFactory _outboxEventFactory;
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
    required OutboxEventFactory outboxEventFactory,
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
       _outboxEventFactory = outboxEventFactory,
       _printQueue = printQueue,
       _printJobProcessor = printJobProcessor,
       _paymentProfileService = paymentProfileService,
       _activeSession = activeSession,
       _pricingEngine = pricingEngine,
       _clock = clock;

  static const _uuid = Uuid();

  Future<SaleCheckoutResult> complete(SaleCheckoutRequest request) async {
    final session = PosBusinessGuards.requireActiveSession(
      _activeSession,
      message: 'Select a cashier and POS machine before selling.',
      exceptionFactory: SaleCheckoutException.new,
    );
    final shift = await PosBusinessGuards.requireOpenShift(
      shiftDao: _shiftDao,
      session: session,
      message: 'No open shift. Open a shift before selling.',
      exceptionFactory: SaleCheckoutException.new,
    );
    final shiftId = shift.id;

    if (request.cart.isEmpty) {
      throw const SaleCheckoutException('No items in cart.');
    }

    final draftLines = request.cart.toSaleLineInputs();

    final officialLines = await PosOfficialPriceResolver(
      catalogDao: _catalogDao,
      exceptionFactory: SaleCheckoutException.new,
    ).resolve(
      session: session,
      draftLines: draftLines,
    );

    SaleLineValidator.validateSaleLines(
      officialLines,
      exceptionFactory: SaleCheckoutException.new,
    );

    final quote = PosSaleQuoteRules.quote(
      pricingEngine: _pricingEngine,
      lines: officialLines,
      useTax: session.activeUseTax,
      priceIncludesTax: session.priceIncludesTax,
      exceptionFactory: SaleCheckoutException.new,
    );
    final requestedPaymentIntents = request.paymentIntents;

    if (requestedPaymentIntents.isEmpty) {
      throw const SaleCheckoutException('At least one payment is required.');
    }

    final paymentInputResolver = PaymentInputResolver(
      catalogDao: _catalogDao,
      paymentProfileService: _paymentProfileService,
      activeSession: _activeSession,
      exceptionFactory: SaleCheckoutException.new,
    );

    final payments = <SalePaymentInput>[];
    var change = 0.0;
    PaymentMethodType? primaryType;

    for (final intent in requestedPaymentIntents) {
      final payment = await paymentInputResolver.build(intent);

      payments.add(payment);

      primaryType ??= payment.paymentMethodType;
      change += payment.changeGiven ?? 0.0;
    }

    final hasCustomerCredit = payments.any(
      (payment) =>
          payment.paymentMethodType == PaymentMethodType.customerCredit,
    );

    if (hasCustomerCredit &&
        (request.customerId == null || request.customerId!.trim().isEmpty)) {
      throw const SaleCheckoutException(
        'Customer is required for credit sale.',
      );
    }

    final paymentResult = PaymentPolicy(
      requireCardReference: _config.requireCardReference,
      exceptionFactory: SaleCheckoutException.new,
    ).validate(quote: quote, payments: payments);

    final localInvoiceNo = await _invoiceNumberService.generateNext(
      branchNo: session.activeBranchNo,
      machineNo: session.activeMachineNo,
      sequenceType: PosBusinessRules.sequenceType(
        session.invoiceSeries,
        fallback: 'sale',
      ),
    );

    final saleId = 'SALE_${_uuid.v4()}';
    final now = _clock.now();
    final idempotencyKey = 'sale_${request.checkoutAttemptId}';

    final envelope = const PosSaleEnvelopeBuilder().build(
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
      outboxEntry: _outboxEventFactory.saleCreated(
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
      selectedPaymentType: primaryType ?? PaymentMethodType.cash,
      change: change,
      uploadQueued: true,
    );
  }
}

class SaleCheckoutRequest {
  final Cart cart;
  final String checkoutAttemptId;
  final List<SalePaymentIntent> paymentIntents;
  final String? customerId;
  final String? customerName;
  final String? customerTaxNumber;

  SaleCheckoutRequest({
    required this.cart,
    required this.checkoutAttemptId,
    required this.paymentIntents,
    this.customerId,
    this.customerName,
    this.customerTaxNumber,
  });
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

final saleCheckoutProvider = Provider<SaleCheckout>((ref) {
  return SaleCheckout(
    salesDao: ref.watch(salesDaoProvider),
    shiftDao: ref.watch(shiftDaoProvider),
    catalogDao: ref.watch(catalogDaoProvider),
    config: ref.watch(posConfigProvider),
    invoiceNumberService: ref.watch(invoiceNumberServiceProvider),
    invoiceDocumentBuilder: ref.watch(invoiceDocumentBuilderProvider),
    outboxEventFactory: ref.watch(outboxEventFactoryProvider),
    printQueue: ref.watch(printQueueProvider),
    printJobProcessor: ref.watch(printJobProcessorProvider),
    paymentProfileService: ref.watch(paymentProfileServiceProvider),
    activeSession: ref.watch(activePosSessionProvider).valueOrNull,
    clock: ref.watch(clockProvider),
  );
});
