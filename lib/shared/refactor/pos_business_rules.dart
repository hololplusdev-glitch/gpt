import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:holol_POS/core/persistence/daos/dao_shared.dart';
import 'package:uuid/uuid.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/persistence/daos/active_pos_session_dao.dart';
import 'package:holol_POS/core/persistence/daos/catalog_dao.dart';
import 'package:holol_POS/core/persistence/daos/sales_dao.dart';
import 'package:holol_POS/core/persistence/daos/shift_dao.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/core/services/payments/payment_method_resolver.dart';
import 'package:holol_POS/core/services/pricing/pricing_engine.dart';
import 'package:holol_POS/features/sales/domain/models/sale_inputs.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/shared/models/sales_history.dart';
import 'package:holol_POS/shared/models/sellable_item_snapshot.dart';
import 'package:holol_POS/core/persistence/pos_config_repository.dart';
import 'package:holol_POS/core/services/invoice_number_service.dart';
import 'package:holol_POS/core/services/invoices/invoice_document_builder.dart';
import 'package:holol_POS/core/services/pos_devices/print_job_processor.dart';
import 'package:holol_POS/core/services/pos_devices/print_queue.dart';
import 'package:holol_POS/core/services/sync/outbox_event_factory.dart';
import 'package:holol_POS/core/services/time/clock.dart';
import 'package:holol_POS/core/services/formatters/pos_formatters.dart';
import 'package:holol_POS/core/persistence/daos/audit_dao.dart';
import 'package:holol_POS/core/constants/pos_config_keys.dart';
import 'package:holol_POS/core/utils/text_normalizer.dart';
import 'package:holol_POS/core/services/invoices/invoice_document.dart'
    as invoice_doc;

typedef BusinessRuleExceptionFactory =
    BusinessException Function(String message);

abstract final class PosNumericInputRules {
  static double? parseDecimalInput(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }
}

abstract final class PosDomainTolerances {
  static const double money = 0.01;
  static const double quantity = 0.000001;
}

abstract final class PosPaymentMethodRules {
  static PaymentMethodType? typeFromStored({
    required String methodCode,
    String? storedTypeCode,
  }) {
    return PaymentMethodResolver.typeFromStored(
      methodCode: methodCode,
      storedTypeCode: storedTypeCode,
    );
  }

  static bool isManual(PaymentMethodType type) {
    return PaymentMethodResolver.isManual(type);
  }

  static String describe({
    required String methodCode,
    required String? methodName,
    required PaymentMethodType? type,
    required bool manualRecord,
  }) {
    return PaymentMethodResolver.describe(
      methodCode: methodCode,
      methodName: methodName,
      type: type,
      manualRecord: manualRecord,
    );
  }

  static bool isCustomerCredit({
    String? methodType,
    String? methodCode,
  }) {
    return PaymentMethodResolver.isCustomerCredit(
      methodType: methodType,
      methodCode: methodCode,
    );
  }
}


/// Shift-specific exception.
class ShiftException extends BusinessException {
  const ShiftException(super.message) : super(code: 'shift_error');
}

abstract final class PosShiftInputRules {
  static String normalizeShiftId(String raw, {required String emptyMessage}) {
    final value = raw.trim();

    if (value.isEmpty) {
      throw ShiftException(emptyMessage);
    }

    return value;
  }

  static void requireValidOpeningCash(double value) {
    if (!_isValidCashAmount(value)) {
      throw const ShiftException('Opening cash cannot be negative.');
    }
  }

  static void requireValidActualCash(double value) {
    if (!_isValidCashAmount(value)) {
      throw const ShiftException('Actual cash cannot be negative.');
    }
  }

  static int requireValidExtendMinutes(int minutes) {
    if (minutes <= 0) {
      throw const ShiftException('Shift extension minutes must be positive.');
    }

    return minutes;
  }

  static double parseOpeningCashText(String raw) {
    final text = raw.trim();
    final value = text.isEmpty
        ? 0.0
        : PosNumericInputRules.parseDecimalInput(text);

    if (value == null || !_isValidCashAmount(value)) {
      throw const ShiftException('أدخل مبلغ افتتاح صحيح.');
    }

    return value;
  }

  static double parseActualCashText(String raw) {
    final text = raw.trim();
    final value = text.isEmpty
        ? null
        : PosNumericInputRules.parseDecimalInput(text);

    if (value == null || !_isValidCashAmount(value)) {
      throw const ShiftException('أدخل النقد الفعلي في الدرج.');
    }

    return value;
  }

  static bool _isValidCashAmount(double value) {
    return !value.isNaN && !value.isInfinite && value >= 0;
  }
}

class ShiftSalesTotals {
  final double grossSales;
  final double netSales;
  final double cashSales;
  final double cardSales;
  final double otherSales;
  final double cashReturns;
  final double totalDiscounts;
  final double totalTaxes;
  final double totalReturns;
  final double totalVoids;
  final int saleCount;

  const ShiftSalesTotals({
    required this.grossSales,
    required this.netSales,
    required this.cashSales,
    required this.cardSales,
    required this.otherSales,
    required this.cashReturns,
    required this.totalDiscounts,
    required this.totalTaxes,
    required this.totalReturns,
    required this.totalVoids,
    required this.saleCount,
  });
}

abstract final class PosShiftTotalsRules {
  static ShiftSalesTotals calculate({
    required Iterable<Sale> sales,
    required Iterable<SalePayment> payments,
  }) {
    final paymentsBySaleId = <String, List<SalePayment>>{};

    for (final payment in payments) {
      paymentsBySaleId.putIfAbsent(payment.saleId, () => []).add(payment);
    }

    var grossSales = 0.0;
    var netSales = 0.0;
    var totalDiscounts = 0.0;
    var totalTaxes = 0.0;
    var totalReturns = 0.0;
    var totalVoids = 0.0;
    var cashSales = 0.0;
    var cardSales = 0.0;
    var otherSales = 0.0;
    var cashReturns = 0.0;
    var saleCount = 0;

    for (final sale in sales) {
      if (isCompletedNormalSale(sale)) {
        grossSales += sale.grandTotal;
        netSales += sale.subtotal;
        totalDiscounts += sale.discountTotal;
        totalTaxes += sale.taxTotal;
        saleCount++;

        for (final payment
            in paymentsBySaleId[sale.id] ?? const <SalePayment>[]) {
          final methodType = _requireStoredPaymentType(sale, payment);

          switch (methodType) {
            case PaymentMethodType.cash:
              cashSales += payment.amount;
            case PaymentMethodType.manualCard:
              cardSales += payment.amount;
            case PaymentMethodType.customerCredit:
              otherSales += payment.amount;
          }
        }
      } else if (isCompletedReturnSale(sale)) {
        totalReturns += sale.grandTotal;

        for (final payment
            in paymentsBySaleId[sale.id] ?? const <SalePayment>[]) {
          final methodType = PaymentMethodResolver.typeFromStored(
            methodCode: payment.methodCodeSnapshot,
            storedTypeCode: payment.methodTypeSnapshot,
          );

          if (methodType == PaymentMethodType.cash) {
            cashReturns += payment.amount;
          }
        }
      } else if (isVoidedSale(sale)) {
        totalVoids += sale.grandTotal;
      }
    }

    return ShiftSalesTotals(
      grossSales: grossSales,
      netSales: netSales,
      cashSales: cashSales,
      cardSales: cardSales,
      otherSales: otherSales,
      cashReturns: cashReturns,
      totalDiscounts: totalDiscounts,
      totalTaxes: totalTaxes,
      totalReturns: totalReturns,
      totalVoids: totalVoids,
      saleCount: saleCount,
    );
  }

  static bool isCompletedNormalSale(Sale sale) {
    return sale.type == SaleType.sale.code &&
        sale.status == SaleStatus.completed.code;
  }

  static bool isCompletedReturnSale(Sale sale) {
    return sale.type == SaleType.returnSale.code &&
        sale.status == SaleStatus.completed.code;
  }

  static bool isVoidedSale(Sale sale) {
    return sale.status == SaleStatus.voided.code;
  }

  static double expectedCash({
    required double openingCash,
    required ShiftSalesTotals totals,
  }) {
    return openingCash + totals.cashSales - totals.cashReturns;
  }

  static double cashDifference({
    required double actualCash,
    required double expectedCash,
  }) {
    return actualCash - expectedCash;
  }

  static PaymentMethodType _requireStoredPaymentType(
    Sale sale,
    SalePayment payment,
  ) {
    final methodType = PaymentMethodResolver.typeFromStored(
      methodCode: payment.methodCodeSnapshot,
      storedTypeCode: payment.methodTypeSnapshot,
    );

    if (methodType == null) {
      throw StateError(
        'Unknown payment method type in sale ${sale.id}: '
        '${payment.methodCodeSnapshot}',
      );
    }

    return methodType;
  }
}

class PosShiftWorkflow {
  static const _uuid = Uuid();

  final ShiftDao shiftDao;
  final SalesDao salesDao;
  final PosConfigRepository config;
  final OutboxEventFactory outboxEventFactory;
  final Clock clock;

  const PosShiftWorkflow({
    required this.shiftDao,
    required this.salesDao,
    required this.config,
    required this.outboxEventFactory,
    this.clock = const SystemClock(),
  });

  Future<Shift> openShift({
    required ActivePosSession session,
    required double openingCash,
    String? shiftTypeId,
  }) async {
    PosShiftInputRules.requireValidOpeningCash(openingCash);

    final existing = await shiftDao.getOpenShift(session.activeMachineNo);
    if (existing != null) {
      throw ShiftException(
        'A shift is already open on this terminal (${existing.id})',
      );
    }

    final localId = 'SH_${_uuid.v4()}';
    final now = clock.now();
    final idempotencyKey = 'shift_open_$localId';
    final defaultDuration = config.getInt(
      PosConfigKeys.shiftDefaultDurationMinutes,
      fallback: 480,
    );
    final expiresAt = now.add(Duration(minutes: defaultDuration));

    final shiftEntry = ShiftsCompanion.insert(
      id: localId,
      branchNo: Value(session.activeBranchNo),
      branchYear: Value(session.activeBranchYear),
      machineNo: Value(session.activeMachineNo),
      storeId: Value(session.activeStoreId),
      priceLevelId: Value(session.activePriceLevelId),
      cashierId: session.activeUserId,
      shiftTypeId: Value(shiftTypeId),
      openingCash: openingCash,
      status: ShiftStatus.open.code,
      openedAt: now,
      expiresAt: Value(expiresAt),
      idempotencyKey: idempotencyKey,
    );

    final outboxEntry = outboxEventFactory.shiftOpened(
      localId: localId,
      machineNo: session.activeMachineNo,
      cashierId: session.activeUserId,
      cashierName: session.activeUserName,
      openingCash: openingCash,
      openedAt: now,
      expiresAt: expiresAt,
      idempotencyKey: idempotencyKey,
    );

    final auditLogEntry = AuditLogCompanion.insert(
      id: 'AUD_${_uuid.v4()}',
      action: AuditAction.shiftOpened.code,
      actorId: session.activeUserId,
      actorName: Value(session.activeUserName),
      targetType: Value(OutboxEntityType.shift.code),
      targetId: Value(localId),
      terminalId: session.activeMachineNo,
      createdAt: now,
    );

    await shiftDao.createShiftEnvelope(
      shift: shiftEntry,
      outboxEntry: outboxEntry,
      auditLogEntry: auditLogEntry,
    );

    return (await shiftDao.getById(localId))!;
  }

  Future<void> closeShift({
    required ActivePosSession session,
    required String localId,
    required double actualCash,
    String? closingNotes,
  }) async {
    final normalizedLocalId = PosShiftInputRules.normalizeShiftId(
      localId,
      emptyMessage: 'No open shift to close.',
    );

    PosShiftInputRules.requireValidActualCash(actualCash);

    final shift = await shiftDao.getById(normalizedLocalId);
    if (shift == null) throw ShiftException('Shift not found: $localId');

    final isOpen =
        shift.status == ShiftStatus.open.code ||
        shift.status == ShiftStatus.closing.code;

    if (!isOpen) {
      throw const ShiftException('Shift is not open');
    }

    if (config.blockShiftCloseWithHeldInvoices) {
      final heldCount = await salesDao.countActiveHeldOrders(normalizedLocalId);
      if (heldCount > 0) {
        throw ShiftException(
          'Cannot close shift: $heldCount held order(s) remain. Complete or cancel them first.',
        );
      }
    }

    final sales = await salesDao.getSalesForShift(normalizedLocalId);
    final payments = await salesDao.getSalePaymentsForSales(
      sales.map((sale) => sale.id),
    );

    final totals = PosShiftTotalsRules.calculate(
      sales: sales,
      payments: payments,
    );

    final expectedCash = PosShiftTotalsRules.expectedCash(
      openingCash: shift.openingCash,
      totals: totals,
    );

    final difference = PosShiftTotalsRules.cashDifference(
      actualCash: actualCash,
      expectedCash: expectedCash,
    );

    final now = clock.now();

    final outboxEntry = outboxEventFactory.shiftClosed(
      localId: normalizedLocalId,
      machineNo: session.activeMachineNo,
      cashierId: session.activeUserId,
      cashierName: session.activeUserName,
      expectedCash: expectedCash,
      actualCash: actualCash,
      difference: difference,
      grossSales: totals.grossSales,
      netSales: totals.netSales,
      cashSales: totals.cashSales,
      cardSales: totals.cardSales,
      otherSales: totals.otherSales,
      cashReturns: totals.cashReturns,
      totalDiscounts: totals.totalDiscounts,
      totalTaxes: totals.totalTaxes,
      totalReturns: totals.totalReturns,
      totalVoids: totals.totalVoids,
      saleCount: totals.saleCount,
      closedAt: now,
    );

    final auditLogEntry = AuditLogCompanion.insert(
      id: 'AUD_${_uuid.v4()}',
      action: AuditAction.shiftClosed.code,
      actorId: session.activeUserId,
      actorName: Value(session.activeUserName),
      targetType: Value(OutboxEntityType.shift.code),
      targetId: Value(normalizedLocalId),
      detailsJson: Value(
        jsonEncode({
          'expectedCash': expectedCash,
          'actualCash': actualCash,
          'difference': difference,
        }),
      ),
      terminalId: session.activeMachineNo,
      createdAt: now,
    );

    await shiftDao.closeShiftEnvelope(
      localId: normalizedLocalId,
      expectedCash: expectedCash,
      actualCash: actualCash,
      difference: difference,
      grossSales: totals.grossSales,
      netSales: totals.netSales,
      cashSales: totals.cashSales,
      cardSales: totals.cardSales,
      otherSales: totals.otherSales,
      cashReturns: totals.cashReturns,
      totalDiscounts: totals.totalDiscounts,
      totalTaxes: totals.totalTaxes,
      totalReturns: totals.totalReturns,
      totalVoids: totals.totalVoids,
      saleCount: totals.saleCount,
      closingNotes: closingNotes,
      closedAt: now,
      outboxEntry: outboxEntry,
      auditLogEntry: auditLogEntry,
    );
  }

  Future<Shift> extendShift({
    required ActivePosSession session,
    required String localId,
    int? overrideMinutes,
  }) async {
    final normalizedLocalId = PosShiftInputRules.normalizeShiftId(
      localId,
      emptyMessage: 'No open shift to extend.',
    );

    final shift = await shiftDao.getById(normalizedLocalId);
    if (shift == null) throw const ShiftException('Shift not found');

    final minutes = PosShiftInputRules.requireValidExtendMinutes(
      overrideMinutes ?? config.shiftExtendMinutes,
    );
    final currentExpiry = shift.expiresAt ?? clock.now();
    final newExpiry = currentExpiry.add(Duration(minutes: minutes));

    final now = clock.now();

    final outboxEntry = outboxEventFactory.shiftExtended(
      localId: normalizedLocalId,
      extendedByMinutes: minutes,
      newExpiry: newExpiry,
      extendedAt: now,
    );

    final auditLogEntry = AuditLogCompanion.insert(
      id: 'AUD_${_uuid.v4()}',
      action: AuditAction.shiftExtended.code,
      actorId: session.activeUserId,
      targetType: Value(OutboxEntityType.shift.code),
      targetId: Value(normalizedLocalId),
      detailsJson: Value(jsonEncode({'extendedByMinutes': minutes})),
      terminalId: session.activeMachineNo,
      createdAt: now,
    );

    await shiftDao.extendShiftEnvelope(
      localId: normalizedLocalId,
      newExpiry: newExpiry,
      outboxEntry: outboxEntry,
      auditLogEntry: auditLogEntry,
    );

    return (await shiftDao.getById(localId))!;
  }
}

abstract final class PosBusinessRules {
  static String sequenceType(
    String? configuredSeries, {
    required String fallback,
  }) {
    final series = configuredSeries?.trim();
    return series == null || series.isEmpty ? fallback : series;
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

abstract final class PosInvoicePaymentValidationRules {
  static double nonCreditPaymentTotal(
    Iterable<invoice_doc.InvoicePaymentDocument> payments,
  ) {
    return payments.fold<double>(
      0.0,
      (sum, payment) =>
          isCustomerCreditPayment(payment) ? sum : sum + payment.amount,
    );
  }

  static bool isCustomerCreditPayment(
    invoice_doc.InvoicePaymentDocument payment,
  ) {
    return PosPaymentMethodRules.isCustomerCredit(
      methodType: payment.methodType,
      methodCode: payment.paymentMethodCode,
    );
  }
}

class PosInvoiceValidationResult {
  final List<String> errors;

  const PosInvoiceValidationResult(this.errors);

  bool get isValid => errors.isEmpty;

  String? get message => isValid ? null : errors.join('; ');
}

abstract final class PosInvoiceValidationRules {
  static PosInvoiceValidationResult validate(
    invoice_doc.InvoiceDocument document,
  ) {
    final errors = <String>[];

    final lineSubtotal = document.lines.fold<double>(
      0.0,
      (sum, line) => sum + line.lineSubtotal,
    );

    final lineDiscount = document.lines.fold<double>(
      0.0,
      (sum, line) => sum + line.discountAmount,
    );

    final lineTax = document.lines.fold<double>(
      0.0,
      (sum, line) => sum + line.taxAmount,
    );

    final lineTotal = document.lines.fold<double>(
      0.0,
      (sum, line) => sum + line.lineTotal,
    );

    final paymentTotal = PosInvoicePaymentValidationRules.nonCreditPaymentTotal(
      document.payments,
    );

    _expect('subtotal', lineSubtotal, document.totals.subtotal, errors);

    if (lineDiscount > document.totals.discountTotal) {
      errors.add('line discounts exceed invoice discount total');
    }

    _expect('tax total', lineTax, document.totals.taxTotal, errors);

    final invoiceLevelDiscount = document.totals.discountTotal > lineDiscount
        ? document.totals.discountTotal - lineDiscount
        : 0.0;

    _expect(
      'net total',
      lineTotal - invoiceLevelDiscount,
      document.totals.netTotal,
      errors,
    );

    _expect('paid total', paymentTotal, document.totals.paidTotal, errors);

    if (document.totals.changeAmount < 0 ||
        document.totals.remainingTotal < 0 ||
        document.totals.netTotal < 0) {
      errors.add('invoice contains unexpected negative totals');
    }

    return PosInvoiceValidationResult(errors);
  }

  static void _expect(
    String label,
    double actual,
    double expected,
    List<String> errors,
  ) {
    if ((actual - expected).abs() > PosDomainTolerances.money) {
      errors.add('$label mismatch: expected $expected, got $actual');
    }
  }
}


abstract final class PosInvoiceDocumentRules {
  static invoice_doc.InvoicePaymentDocument fromPaymentInput(
    SalePaymentInput payment,
  ) {
    final type = payment.paymentMethodType;
    final manualRecord = PosPaymentMethodRules.isManual(type);
    final name = payment.paymentMethodName ?? payment.paymentMethodCode;

    return invoice_doc.InvoicePaymentDocument(
      paymentMethodId: payment.paymentMethodId,
      paymentMethodCode: payment.paymentMethodCode,
      methodName: name,
      methodType: type.code,
      amount: payment.amount,
      cashTendered: payment.cashTendered,
      changeGiven: payment.changeGiven,
      referenceNo: DaoText.clean(payment.referenceNo),
      bankId: DaoText.clean(payment.bankId),
      cardTypeId: DaoText.clean(payment.cardTypeId),
      manualRecord: manualRecord,
      displayMethod: PosPaymentMethodRules.describe(
        methodCode: payment.paymentMethodCode,
        methodName: name,
        type: type,
        manualRecord: manualRecord,
      ),
      displayAmount: PosFormatters.amount(payment.amount),
    );
  }

  static invoice_doc.InvoicePaymentDocument fromStoredPayment({
    required String saleId,
    required SalePayment payment,
    required PaymentMethod? method,
  }) {
    final code = payment.methodCodeSnapshot;
    final type = PosPaymentMethodRules.typeFromStored(
      methodCode: code,
      storedTypeCode: (payment.methodTypeSnapshot ?? method?.type)?.toString(),
    );

    if (type == null) {
      throw StateError(
        'Unknown payment method type while building invoice for $saleId: $code',
      );
    }

    final manualRecord = payment.isManual || PosPaymentMethodRules.isManual(type);
    final name = payment.methodNameSnapshot ?? method?.name ?? code;
    final amount = payment.amount;

    return invoice_doc.InvoicePaymentDocument(
      paymentMethodId: payment.paymentMethodId,
      paymentMethodCode: code,
      methodName: name,
      methodType: type.code,
      amount: amount,
      cashTendered: payment.cashTendered,
      changeGiven: payment.changeGiven,
      referenceNo: DaoText.clean(payment.referenceNo),
      bankId: DaoText.clean(payment.bankId),
      cardTypeId: DaoText.clean(payment.cardTypeId),
      manualRecord: manualRecord,
      displayMethod: PosPaymentMethodRules.describe(
        methodCode: code,
        methodName: name,
        type: type,
        manualRecord: manualRecord,
      ),
      displayAmount: PosFormatters.amount(amount),
    );
  }

  static String syncEntityTypeForSaleType(String? saleType) {
    return saleType == SaleType.returnSale.code
        ? OutboxEntityType.returnSale.code
        : OutboxEntityType.sale.code;
  }
}


abstract final class SaleLineValidator {
  static bool isWholeQuantity(double value) {
    return (value - value.roundToDouble()).abs() < PosDomainTolerances.quantity;
  }

  static void validateQuantityForSnapshot(
    SellableItemSnapshot snapshot,
    double quantity, {
    BusinessRuleExceptionFactory? exceptionFactory,
  }) {
    if (quantity <= 0) return;
    if (!snapshot.useQtyFraction && !isWholeQuantity(quantity)) {
      throw _exception(
        exceptionFactory,
        'Fraction quantity is not allowed for ${snapshot.itemName}.',
        code: 'QUANTITY_FRACTION_NOT_ALLOWED',
      );
    }
  }

  static void validateDiscount({
    required bool allowDiscount,
    required String itemName,
    required double value,
    BusinessRuleExceptionFactory? exceptionFactory,
  }) {
    if (!allowDiscount && value > 0) {
      throw _exception(
        exceptionFactory,
        'Discount is not allowed for $itemName.',
        code: 'DISCOUNT_NOT_ALLOWED',
      );
    }
    if (value < 0) {
      throw _exception(
        exceptionFactory,
        'Discount cannot be negative.',
        code: 'INVALID_DISCOUNT',
      );
    }
  }

  static void validateSaleLines(
    Iterable<SaleLineInput> lineItems, {
    BusinessRuleExceptionFactory? exceptionFactory,
    bool validatePricing = false,
    PricingEngine pricingEngine = const PricingEngine(),
    bool priceIncludesTax = false,
  }) {
    for (final line in lineItems) {
      validateSaleLineBasics(line, exceptionFactory: exceptionFactory);
      if (!validatePricing) continue;

      try {
        pricingEngine.calculateLine(
          itemId: line.itemId,
          unitId: line.unitId,
          unitPrice: line.unitPrice,
          quantity: line.quantity,
          discountType: line.discountType,
          discountValue: line.discountValue,
          allowDiscount: line.allowDiscount,
          taxRate: line.taxRate,
          priceIncludesTax: priceIncludesTax,
        );
      } on PricingException catch (e) {
        throw _exception(exceptionFactory, e.message);
      }
    }
  }

  static void validateSaleLineBasics(
    SaleLineInput line, {
    BusinessRuleExceptionFactory? exceptionFactory,
  }) {
    if (line.quantity <= 0) {
      throw _exception(
        exceptionFactory,
        'Invalid quantity for ${line.itemName}.',
        code: 'INVALID_QUANTITY',
      );
    }
    if (!line.useQtyFraction && !isWholeQuantity(line.quantity)) {
      throw _exception(
        exceptionFactory,
        'Fraction quantity is not allowed for ${line.itemName}.',
        code: 'QUANTITY_FRACTION_NOT_ALLOWED',
      );
    }
    if (line.unitPrice <= 0) {
      throw _exception(
        exceptionFactory,
        'Missing price for ${line.itemName}.',
        code: 'MISSING_PRICE',
      );
    }
    if (line.taxRate < 0) {
      throw _exception(
        exceptionFactory,
        'Invalid tax rate for ${line.itemName}.',
        code: 'INVALID_TAX_RATE',
      );
    }
    if ((line.discountValue ?? 0) < 0) {
      throw _exception(
        exceptionFactory,
        'Invalid discount for ${line.itemName}.',
        code: 'INVALID_DISCOUNT',
      );
    }
    if (!line.allowDiscount &&
        line.discountType != null &&
        (line.discountValue ?? 0) > 0) {
      throw _exception(
        exceptionFactory,
        'Discounts are not allowed for ${line.itemName}.',
        code: 'DISCOUNT_NOT_ALLOWED',
      );
    }
  }

  static BusinessException _exception(
    BusinessRuleExceptionFactory? factory,
    String message, {
    String code = 'BUSINESS_RULE_VIOLATION',
  }) {
    return factory?.call(message) ?? BusinessException(message, code: code);
  }
}

typedef PosCheckoutQuote = CheckoutQuote;

abstract final class PosSaleQuoteRules {
  static CheckoutQuote quote({
    required PricingEngine pricingEngine,
    required Iterable<SaleLineInput> lines,
    required bool useTax,
    required bool priceIncludesTax,
    BusinessRuleExceptionFactory? exceptionFactory,
  }) {
    try {
      return pricingEngine.calculateQuote(
        lines: [
          for (final line in lines)
            PricingLineInput(
              itemId: line.itemId,
              unitId: line.unitId,
              unitPrice: line.unitPrice,
              quantity: line.quantity,
              discountType: line.discountType,
              discountValue: line.discountValue,
              allowDiscount: line.allowDiscount,
              taxRate: line.taxRate,
            ),
        ],
        taxRate: 0,
        useTax: useTax,
        priceIncludesTax: priceIncludesTax,
      );
    } on PricingException catch (e) {
      throw exceptionFactory?.call(e.message) ??
          BusinessException(e.message, code: 'PRICING_ERROR');
    }
  }
}

abstract final class PosCartQuoteRules {
  static PosCheckoutQuote preview({
    required Cart cart,
    required bool useTax,
    required bool priceIncludesTax,
    PricingEngine pricingEngine = const PricingEngine(),
  }) {
    return cart.previewQuote(
      pricingEngine: pricingEngine,
      useTax: useTax,
      priceIncludesTax: priceIncludesTax,
    );
  }
}

abstract final class PosBusinessGuards {
  static ActivePosSession requireActiveSession(
    ActivePosSession? session, {
    required String message,
    BusinessRuleExceptionFactory? exceptionFactory,
    String code = 'NO_ACTIVE_POS_SESSION',
  }) {
    if (session == null) {
      throw exceptionFactory?.call(message) ??
          BusinessException(message, code: code);
    }
    return session;
  }

  static Future<Shift> requireOpenShift({
    required ShiftDao shiftDao,
    required ActivePosSession session,
    required String message,
    BusinessRuleExceptionFactory? exceptionFactory,
    String code = 'NO_OPEN_SHIFT',
  }) async {
    final shift = await shiftDao.getOpenShift(
      session.activeMachineNo,
      cashierId: session.activeUserId,
    );
    if (shift == null || shift.status != ShiftStatus.open.code) {
      throw exceptionFactory?.call(message) ??
          BusinessException(message, code: code);
    }
    return shift;
  }

  static Future<Sale> requireCompletedNormalSale({
    required SalesDao salesDao,
    required String saleId,
    BusinessRuleExceptionFactory? exceptionFactory,
  }) async {
    final sale = await salesDao.getById(saleId);
    if (sale == null) {
      throw exceptionFactory?.call('Sale not found.') ??
          const BusinessException('Sale not found.', code: 'SALE_NOT_FOUND');
    }
    if (sale.type != SaleType.sale.code ||
        sale.status != SaleStatus.completed.code) {
      throw exceptionFactory?.call(
            'Only completed normal sales can be changed.',
          ) ??
          const BusinessException(
            'Only completed normal sales can be changed.',
            code: 'SALE_NOT_MUTABLE',
          );
    }
    return sale;
  }
}

abstract final class PosHeldSnapshotReader {
  static List<Map<String, dynamic>> itemsFromJson(
    String snapshotJson, {
    BusinessRuleExceptionFactory? exceptionFactory,
  }) {
    final decoded = jsonDecode(snapshotJson);

    if (decoded is List) return decoded.cast<Map<String, dynamic>>();

    if (decoded is Map<String, dynamic>) {
      final items = decoded['items'];
      if (items is List) return items.cast<Map<String, dynamic>>();
    }

    final message = 'Invalid held order snapshot.';
    throw exceptionFactory?.call(message) ??
        BusinessException(message, code: 'INVALID_HELD_ORDER_SNAPSHOT');
  }

  static String requiredText(
    Object? value,
    String fieldName, {
    BusinessRuleExceptionFactory? exceptionFactory,
  }) {
    final result = text(value);
    if (result == null || result.isEmpty) {
      final message = 'Held order snapshot is missing $fieldName.';
      throw exceptionFactory?.call(message) ??
          BusinessException(message, code: 'INVALID_HELD_ORDER_SNAPSHOT');
    }
    return result;
  }

  static String? text(Object? value) {
    return CoreText.clean(value);
  }

  static double doubleValue(Object? value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  static double? nullableDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class PosHeldOrderRehydrator {
  final CatalogDao catalogDao;
  final PricingEngine pricingEngine;
  final BusinessRuleExceptionFactory? exceptionFactory;

  const PosHeldOrderRehydrator({
    required this.catalogDao,
    this.pricingEngine = const PricingEngine(),
    this.exceptionFactory,
  });

  Future<PosHeldOrderResumeData> rehydrate({
    required HeldOrder order,
    required ActivePosSession session,
  }) async {
    final snapshotItems = PosHeldSnapshotReader.itemsFromJson(
      order.snapshotJson,
      exceptionFactory: exceptionFactory,
    );
    if (snapshotItems.isEmpty) {
      throw _exception('Held order snapshot is empty.');
    }

    final lines = <SaleLineInput>[];
    final warnings = <String>[];

    for (final snapshot in snapshotItems) {
      final itemId = PosHeldSnapshotReader.requiredText(
        snapshot['itemId'],
        'itemId',
        exceptionFactory: exceptionFactory,
      );
      final unitId = PosHeldSnapshotReader.requiredText(
        snapshot['unitId'],
        'unitId',
        exceptionFactory: exceptionFactory,
      );
      final quantity = PosHeldSnapshotReader.doubleValue(
        snapshot['quantity'],
        fallback: 1.0,
      );
      final oldUnitPrice = PosHeldSnapshotReader.nullableDouble(
        snapshot['unitPrice'],
      );
      final oldTaxRate = PosHeldSnapshotReader.nullableDouble(
        snapshot['taxRate'],
      );
      final oldUnitName = PosHeldSnapshotReader.text(snapshot['unitName']);
      final itemName =
          PosHeldSnapshotReader.text(snapshot['itemName']) ?? itemId;
      final oldAllowDiscount = snapshot['allowDiscount'] is bool
          ? snapshot['allowDiscount'] as bool
          : null;

      final item = await catalogDao.getItemById(itemId);
      if (item == null || item.inactive || item.noSale) {
        throw _exception('الصنف $itemName لم يعد قابلًا للبيع.');
      }

      final price = await catalogDao.resolveItemPrice(
        itemId: itemId,
        unitId: unitId,
        priceLevelId: session.activePriceLevelId,
        storeId: session.activeStoreId,
      );

      if (price == null) {
        throw _exception('لا يوجد سعر حالي للصنف $itemName.');
      }

      final sellable = catalogDao.toSellableItemSnapshot(
        item: item,
        price: price,
        fallbackUnitId: unitId,
        fallbackUnitName: oldUnitName,
        barcode: PosHeldSnapshotReader.text(snapshot['barcode']),
      );

      final discountType = DiscountType.fromCode(
        PosHeldSnapshotReader.text(snapshot['discountType']),
      );
      final discountValue = PosHeldSnapshotReader.nullableDouble(
        snapshot['discountValue'],
      );

      if (oldUnitPrice != null && oldUnitPrice != sellable.unitPrice) {
        warnings.add(
          'تغير سعر $itemName من $oldUnitPrice إلى ${sellable.unitPrice}.',
        );
      }
      if (oldTaxRate != null && oldTaxRate != sellable.taxRate) {
        warnings.add(
          'تغيرت ضريبة $itemName من $oldTaxRate إلى ${sellable.taxRate}.',
        );
      }
      if (oldUnitName != null && oldUnitName != sellable.unitName) {
        warnings.add(
          'تغير اسم وحدة $itemName من $oldUnitName إلى ${sellable.unitName}.',
        );
      }

      final line = SaleLineInput(
        itemId: sellable.itemId,
        unitId: sellable.unitId,
        itemName: sellable.itemName,
        unitName: sellable.unitName,
        unitSize: sellable.unitSize,
        barcode: sellable.barcode,
        useQtyFraction: sellable.useQtyFraction,
        quantity: quantity,
        unitPrice: oldUnitPrice ?? sellable.unitPrice,
        taxRate: oldTaxRate ?? sellable.taxRate,
        discountType: discountType,
        discountValue: discountValue,
        allowDiscount: oldAllowDiscount ?? sellable.allowDiscount,
        notes: PosHeldSnapshotReader.text(snapshot['notes']),
      );

      SaleLineValidator.validateSaleLines(
        [line],
        exceptionFactory: exceptionFactory,
        validatePricing: true,
        pricingEngine: pricingEngine,
        priceIncludesTax: false,
      );
      lines.add(line);
    }

    return PosHeldOrderResumeData(lines: lines, warnings: warnings);
  }

  BusinessException _exception(String message) {
    return exceptionFactory?.call(message) ??
        BusinessException(message, code: 'HELD_ORDER_REHYDRATION_ERROR');
  }
}

class PosHeldOrderResumeData {
  final List<SaleLineInput> lines;
  final List<String> warnings;

  const PosHeldOrderResumeData({required this.lines, required this.warnings});
}

class PosHeldOrdersWorkflow {
  static const _uuid = Uuid();

  final SalesDao salesDao;
  final ShiftDao shiftDao;
  final AuditDao auditDao;
  final CatalogDao catalogDao;
  final PosConfigRepository config;
  final ActivePosSession? activeSession;
  final PricingEngine pricingEngine;
  final Clock clock;
  final BusinessRuleExceptionFactory? exceptionFactory;

  const PosHeldOrdersWorkflow({
    required this.salesDao,
    required this.shiftDao,
    required this.auditDao,
    required this.catalogDao,
    required this.config,
    required this.activeSession,
    this.pricingEngine = const PricingEngine(),
    this.clock = const SystemClock(),
    this.exceptionFactory,
  });

  CheckoutQuote previewQuote({required List<SaleLineInput> lineItems}) {
    final session = _requireSession();
    _validateLines(lineItems);
    return PosSaleQuoteRules.quote(
      pricingEngine: pricingEngine,
      lines: lineItems,
      useTax: session.activeUseTax,
      priceIncludesTax: session.priceIncludesTax,
      exceptionFactory: exceptionFactory,
    );
  }

  Future<String> holdOrder({
    required List<SaleLineInput> items,
    String? customerId,
    String? customerName,
    String? referenceName,
    String? notes,
  }) async {
    final session = _requireSession();
    final shift = await _requireOpenShift(session);
    final shiftId = shift.id;

    if (!config.useHeldInvoices) {
      throw _exception('Held orders are disabled by POS configuration.');
    }

    final currentCount = await salesDao.countActiveHeldOrders(shiftId);
    if (currentCount >= config.maxHeldInvoices) {
      throw _exception(
        'Maximum held orders (${config.maxHeldInvoices}) reached.',
      );
    }

    _validateLines(items);

    final quote = previewQuote(lineItems: items);
    final id = 'HLD_${_uuid.v4()}';
    final now = clock.now();

    final snapshotJson = jsonEncode({
      'version': 1,
      'type': 'cart_intent_snapshot',
      'createdAt': now.toIso8601String(),
      'createdBy': session.activeUserId,
      'items': items.map((line) => line.toHeldOrderSnapshotJson()).toList(),
    });

    await salesDao.holdOrder(
      HeldOrdersCompanion(
        id: Value(id),
        branchNo: Value(session.activeBranchNo),
        branchYear: Value(session.activeBranchYear),
        machineNo: Value(session.activeMachineNo),
        storeId: Value(session.activeStoreId),
        priceLevelId: Value(session.activePriceLevelId),
        useTax: Value(session.activeUseTax),
        shiftId: Value(shiftId),
        cashierId: Value(session.activeUserId),
        customerId: Value(customerId),
        customerNameSnapshot: Value(customerName),
        referenceName: Value(referenceName),
        snapshotJson: Value(snapshotJson),
        subtotal: Value(quote.subtotal),
        taxTotal: Value(quote.taxTotal),
        discountTotal: Value(quote.discountTotal),
        grandTotal: Value(quote.grandTotal),
        status: Value(HeldOrderStatus.held.code),
        notes: Value(notes),
        heldAt: Value(now),
      ),
    );

    await auditDao.log(
      id: 'AUD_${_uuid.v4()}',
      action: AuditAction.orderHeld,
      actorId: session.activeUserId,
      targetType: OutboxEntityType.heldOrder.code,
      targetId: id,
      terminalId: session.activeMachineNo,
    );

    return id;
  }

  Future<PosHeldOrderResumeData> resumeHeldOrder({
    required String orderId,
  }) async {
    final session = _requireSession();
    final shift = await _requireOpenShift(session);
    final shiftId = shift.id;

    final orders = await salesDao.getActiveHeldOrders(shiftId);
    final order = _findHeldOrder(orders, orderId);

    if (order == null) {
      throw _exception('Held order not found or already resumed.');
    }

    final resumeData = await PosHeldOrderRehydrator(
      catalogDao: catalogDao,
      pricingEngine: pricingEngine,
      exceptionFactory: exceptionFactory,
    ).rehydrate(order: order, session: session);

    final now = clock.now();
    final auditLogEntry = AuditLogCompanion.insert(
      id: 'AUD_${_uuid.v4()}',
      action: AuditAction.orderRecalled.code,
      actorId: session.activeUserId,
      targetType: Value(OutboxEntityType.heldOrder.code),
      targetId: Value(orderId),
      terminalId: session.activeMachineNo,
      createdAt: now,
    );

    final updated = await salesDao.resumeHeldOrderEnvelope(
      orderId: orderId,
      shiftId: shiftId,
      now: now,
      auditLogEntry: auditLogEntry,
    );

    if (!updated) {
      throw _exception('Held order was already changed.');
    }

    return resumeData;
  }

  Future<void> cancelHeldOrder({required String orderId}) async {
    final session = _requireSession();
    final shift = await _requireOpenShift(session);
    final shiftId = shift.id;
    final now = clock.now();

    final auditLogEntry = AuditLogCompanion.insert(
      id: 'AUD_${_uuid.v4()}',
      action: AuditAction.orderCancelled.code,
      actorId: session.activeUserId,
      targetType: Value(OutboxEntityType.heldOrder.code),
      targetId: Value(orderId),
      terminalId: session.activeMachineNo,
      createdAt: now,
    );

    final updated = await salesDao.cancelHeldOrderEnvelope(
      orderId: orderId,
      shiftId: shiftId,
      auditLogEntry: auditLogEntry,
    );

    if (!updated) {
      throw _exception('Held order not found or already changed.');
    }
  }

  Future<List<HeldOrder>> getCurrentHeldOrders() async {
    final session = _requireSession();
    final shift = await _requireOpenShift(session);
    return salesDao.getActiveHeldOrders(shift.id);
  }

  Future<List<HeldOrder>> getHeldOrders(String shiftId) {
    return salesDao.getActiveHeldOrders(shiftId);
  }

  ActivePosSession _requireSession() {
    return PosBusinessGuards.requireActiveSession(
      activeSession,
      message: 'Select a cashier and POS machine before selling.',
      exceptionFactory: exceptionFactory,
    );
  }

  Future<Shift> _requireOpenShift(ActivePosSession session) {
    return PosBusinessGuards.requireOpenShift(
      shiftDao: shiftDao,
      session: session,
      message: 'Open a shift before holding orders.',
      exceptionFactory: exceptionFactory,
    );
  }

  void _validateLines(List<SaleLineInput> lines) {
    SaleLineValidator.validateSaleLines(
      lines,
      exceptionFactory: exceptionFactory,
      validatePricing: true,
      pricingEngine: pricingEngine,
      priceIncludesTax: false,
    );
  }

  HeldOrder? _findHeldOrder(List<HeldOrder> orders, String orderId) {
    for (final order in orders) {
      if (order.id == orderId) return order;
    }
    return null;
  }

  BusinessException _exception(String message) {
    return exceptionFactory?.call(message) ??
        BusinessException(message, code: 'HELD_ORDER_ERROR');
  }
}

class SaleDetailSnapshot {
  final Sale sale;
  final List<SaleLine> items;
  final List<SalePayment> payments;

  const SaleDetailSnapshot({
    required this.sale,
    required this.items,
    required this.payments,
  });
}

abstract final class PosSalesHistorySummaryRules {
  static List<SaleSummary> build({
    required Iterable<Sale> sales,
    required Iterable<SaleLine> lines,
    required Iterable<SalePayment> payments,
  }) {
    final productNamesBySaleId = <String, List<String>>{};

    for (final line in lines) {
      final name = line.itemNameSnapshot.trim();
      if (name.isEmpty) continue;

      final names = productNamesBySaleId.putIfAbsent(line.saleId, () => []);
      if (!names.contains(name)) {
        names.add(name);
      }
    }

    final paymentLabels = primaryPaymentLabels(payments);

    return sales.map((sale) {
      return SaleSummary(
        id: sale.id,
        localSaleNo: sale.localSaleNo,
        type: sale.type,
        status: sale.status,
        grandTotal: sale.grandTotal,
        createdAt: sale.createdAt,
        cashierId: sale.cashierId,
        paymentMethodLabel: paymentLabels[sale.id],
        productSummary: productSummary(productNamesBySaleId[sale.id]),
      );
    }).toList(growable: false);
  }

  static Map<String, String> primaryPaymentLabels(
    Iterable<SalePayment> payments,
  ) {
    final ordered = payments.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final labels = <String, String>{};

    for (final payment in ordered) {
      labels.putIfAbsent(
        payment.saleId,
        () =>
            DaoText.clean(payment.methodNameSnapshot) ??
            DaoText.clean(payment.methodCodeSnapshot) ??
            payment.paymentMethodId,
      );
    }

    return labels;
  }

  static String productSummary(List<String>? names) {
    if (names == null || names.isEmpty) return '';
    if (names.length <= 3) return names.join(', ');

    final visible = names.take(3).join(', ');
    final remaining = names.length - 3;
    return '$visible +$remaining';
  }
}

class PosSalesHistoryWorkflow {
  static const _uuid = Uuid();

  final SalesDao salesDao;
  final ShiftDao shiftDao;
  final InvoiceNumberService invoiceNumberService;
  final InvoiceDocumentBuilder invoiceDocumentBuilder;
  final OutboxEventFactory outboxEventFactory;
  final ActivePosSession? activeSession;
  final Clock clock;

  const PosSalesHistoryWorkflow({
    required this.salesDao,
    required this.shiftDao,
    required this.invoiceNumberService,
    required this.invoiceDocumentBuilder,
    required this.outboxEventFactory,
    required this.activeSession,
    this.clock = const SystemClock(),
  });

  Future<List<SaleSummary>> searchSalesHistory({
    String? query,
    int limit = 100,
  }) async {
    final sales = await salesDao.searchSales(query: query, limit: limit);
    if (sales.isEmpty) return const <SaleSummary>[];

    final saleIds = sales.map((sale) => sale.id).toSet();
    final lines = await salesDao.getSaleLinesForSales(saleIds);
    final payments = await salesDao.getSalePaymentsForSales(saleIds);

    return PosSalesHistorySummaryRules.build(
      sales: sales,
      lines: lines,
      payments: payments,
    );
  }

  Future<SaleDetailSnapshot?> getSaleDetail(String saleId) async {
    final sale = await salesDao.getById(saleId);
    if (sale == null) return null;

    final items = await salesDao.getSaleLines(saleId);
    final payments = await salesDao.getSalePayments(saleId);

    return SaleDetailSnapshot(
      sale: sale,
      items: items,
      payments: payments,
    );
  }

  Future<void> voidSale(String saleId) async {
    final session = PosBusinessGuards.requireActiveSession(
      activeSession,
      message: 'Select a cashier and POS machine first.',
      code: 'NO_ACTIVE_POS_SESSION',
    );

    final sale = await PosBusinessGuards.requireCompletedNormalSale(
      salesDao: salesDao,
      saleId: saleId,
    );

    final now = clock.now();

    if (await _hasCompletedReturnForSale(sale.id)) {
      throw const BusinessException(
        'Sale with a completed return cannot be voided.',
        code: 'SALE_HAS_RETURN',
      );
    }

    await salesDao.voidSaleEnvelope(
      saleId: sale.id,
      voidUpdate: SalesCompanion(
        status: Value(SaleStatus.voided.code),
        voidedAt: Value(now),
      ),
      outboxEntry: outboxEventFactory.saleVoided(
        saleId: sale.id,
        cashierId: session.activeUserId,
        cashierName: session.activeUserName,
        voidedAt: now,
      ),
      auditLogEntry: AuditLogCompanion.insert(
        id: 'AUD_${_uuid.v4()}',
        action: AuditAction.saleVoided.code,
        actorId: session.activeUserId,
        actorName: Value(session.activeUserName),
        targetType: Value(OutboxEntityType.sale.code),
        targetId: Value(sale.id),
        detailsJson: Value(
          jsonEncode({
            'invoiceNo': sale.localSaleNo,
            'grandTotal': sale.grandTotal,
          }),
        ),
        terminalId: session.activeMachineNo,
        createdAt: now,
      ),
    );
  }

  Future<String> returnSale(String saleId) async {
    final session = PosBusinessGuards.requireActiveSession(
      activeSession,
      message: 'Select a cashier and POS machine first.',
      code: 'NO_ACTIVE_POS_SESSION',
    );

    final shift = await PosBusinessGuards.requireOpenShift(
      shiftDao: shiftDao,
      session: session,
      message: 'Open a shift before creating a return.',
      code: 'NO_OPEN_SHIFT',
    );

    final original = await PosBusinessGuards.requireCompletedNormalSale(
      salesDao: salesDao,
      saleId: saleId,
    );

    if (await _hasCompletedReturnForSale(original.id)) {
      throw const BusinessException(
        'This sale has already been fully returned.',
        code: 'SALE_ALREADY_RETURNED',
      );
    }

    final now = clock.now();
    final returnSaleId = 'RET_${_uuid.v4()}';

    final localInvoiceNo = await invoiceNumberService.generateNext(
      branchNo: session.activeBranchNo,
      machineNo: session.activeMachineNo,
      sequenceType: PosBusinessRules.sequenceType(
        session.returnInvoiceSeries,
        fallback: 'return',
      ),
    );

    final idempotencyKey = 'return_${original.id}';

    final originalLines = await salesDao.getSaleLines(original.id);
    final originalPayments = await salesDao.getSalePayments(original.id);
    final originalTaxes = await salesDao.getInvoiceTaxes(original.id);

    final header = SalesCompanion(
      id: Value(returnSaleId),
      localSaleNo: Value(localInvoiceNo),
      idempotencyKey: Value(idempotencyKey),
      type: Value(SaleType.returnSale.code),
      status: Value(SaleStatus.completed.code),
      branchNo: Value(session.activeBranchNo),
      branchYear: Value(session.activeBranchYear),
      terminalId: Value(session.activeMachineNo),
      machineNo: Value(session.activeMachineNo),
      shiftId: Value(shift.id),
      cashierId: Value(session.activeUserId),
      sourceUserId: Value(session.activeUserId),
      cashierNameSnapshot: Value(session.activeUserName),
      customerId: Value(original.customerId),
      customerNameSnapshot: Value(original.customerNameSnapshot),
      customerTaxNumberSnapshot: Value(original.customerTaxNumberSnapshot),
      originalSaleId: Value(original.id),
      storeId: Value(original.storeId),
      priceLevelId: Value(original.priceLevelId),
      useTax: Value(original.useTax),
      priceIncludesTax: Value(original.priceIncludesTax),
      subtotal: Value(original.subtotal),
      discountTotal: Value(original.discountTotal),
      taxTotal: Value(original.taxTotal),
      grandTotal: Value(original.grandTotal),
      paidTotal: Value(original.paidTotal),
      remainingTotal: Value(original.remainingTotal),
      changeTotal: const Value(0),
      createdAt: Value(now),
      completedAt: Value(now),
    );

    final lines = [
      for (final line in originalLines)
        SaleLinesCompanion(
          id: Value('TI_${_uuid.v4()}'),
          saleId: Value(returnSaleId),
          itemId: Value(line.itemId),
          unitId: Value(line.unitId),
          barcode: Value(line.barcode),
          itemNameSnapshot: Value(line.itemNameSnapshot),
          unitNameSnapshot: Value(line.unitNameSnapshot),
          qtyScaled: Value(line.qtyScaled),
          qtyScale: Value(line.qtyScale),
          unitPrice: Value(line.unitPrice),
          grossAmount: Value(line.grossAmount),
          lineDiscountType: Value(line.lineDiscountType),
          lineDiscountValue: Value(line.lineDiscountValue),
          lineDiscountAmount: Value(line.lineDiscountAmount),
          taxableAmount: Value(line.taxableAmount),
          taxRate: Value(line.taxRate),
          taxAmount: Value(line.taxAmount),
          lineTotal: Value(line.lineTotal),
          allowDiscountSnapshot: Value(line.allowDiscountSnapshot),
          unitSize: Value(line.unitSize),
          storeId: Value(line.storeId),
          priceLevelId: Value(line.priceLevelId),
          notes: Value(line.notes),
        ),
    ];

    final payments = [
      for (final payment in originalPayments)
        SalePaymentsCompanion(
          id: Value('TP_${_uuid.v4()}'),
          saleId: Value(returnSaleId),
          paymentMethodId: Value(payment.paymentMethodId),
          methodCodeSnapshot: Value(payment.methodCodeSnapshot),
          methodNameSnapshot: Value(payment.methodNameSnapshot),
          methodTypeSnapshot: Value(payment.methodTypeSnapshot),
          isManual: Value(payment.isManual),
          amount: Value(payment.amount),
          cashTendered: Value(payment.cashTendered),
          changeGiven: const Value(0),
          referenceNo: Value(payment.referenceNo),
          bankId: Value(payment.bankId),
          cardTypeId: Value(payment.cardTypeId),
          paymentDeviceRef: Value(payment.paymentDeviceRef),
          authCode: Value(payment.authCode),
          rrn: Value(payment.rrn),
          cardScheme: Value(payment.cardScheme),
          cardLast4: Value(payment.cardLast4),
          status: Value(PaymentStatus.completed.code),
          createdAt: Value(now),
        ),
    ];

    final taxes = [
      for (final tax in originalTaxes)
        SaleTaxSummaryCompanion(
          id: Value('TT_${_uuid.v4()}'),
          saleId: Value(returnSaleId),
          taxRate: Value(tax.taxRate),
          taxableAmount: Value(tax.taxableAmount),
          taxAmount: Value(tax.taxAmount),
        ),
    ];

    await salesDao.createReturnSaleEnvelope(
      header: header,
      items: lines,
      payments: payments,
      taxes: taxes,
      outboxEntry: outboxEventFactory.returnCreated(
        saleId: returnSaleId,
        originalSaleId: original.id,
        localInvoiceNo: localInvoiceNo,
        machineNo: session.activeMachineNo,
        branchNo: session.activeBranchNo,
        shiftId: shift.id,
        cashierId: session.activeUserId,
        grandTotal: original.grandTotal,
        completedAt: now,
        idempotencyKey: idempotencyKey,
      ),
      auditLogEntry: AuditLogCompanion.insert(
        id: 'AUD_${_uuid.v4()}',
        action: AuditAction.returnCreated.code,
        actorId: session.activeUserId,
        actorName: Value(session.activeUserName),
        targetType: Value(OutboxEntityType.returnSale.code),
        targetId: Value(returnSaleId),
        detailsJson: Value(
          jsonEncode({
            'originalSaleId': original.id,
            'originalInvoiceNo': original.localSaleNo,
            'returnInvoiceNo': localInvoiceNo,
            'grandTotal': original.grandTotal,
          }),
        ),
        terminalId: session.activeMachineNo,
        createdAt: now,
      ),
    );

    await invoiceDocumentBuilder.buildForSale(returnSaleId);

    return returnSaleId;
  }

  Future<bool> _hasCompletedReturnForSale(String originalSaleId) async {
    final returns = await salesDao.getSalesByOriginalSaleId(originalSaleId);

    return returns.any(
      (sale) =>
          sale.type == SaleType.returnSale.code &&
          sale.status == SaleStatus.completed.code,
    );
  }
}

class PosSaleEnvelope {
  final SalesCompanion header;
  final List<SaleLinesCompanion> items;
  final List<SalePaymentsCompanion> payments;
  final List<SaleTaxSummaryCompanion> taxes;
  final AuditLogCompanion auditLogEntry;

  const PosSaleEnvelope({
    required this.header,
    required this.items,
    required this.payments,
    required this.taxes,
    required this.auditLogEntry,
  });
}

class PosSaleEnvelopeBuilder {
  static const int quantityScale = 1000;
  static const _uuid = Uuid();

  const PosSaleEnvelopeBuilder();

  PosSaleEnvelope build({
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

    final processedItems = <_ProcessedSaleLine>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final pricedLine = quote.lines[i];
      processedItems.add(
        _ProcessedSaleLine(
          input: line,
          grossAmount: pricedLine.grossAmount,
          discountAmount: pricedLine.discountAmount,
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
          qtyScaled: Value(toQtyScaled(p.input.quantity)),
          qtyScale: const Value(quantityScale),
          unitPrice: Value(p.input.unitPrice),
          taxRate: Value(p.input.taxRate),
          taxableAmount: Value(p.taxableAmount),
          taxAmount: Value(p.taxAmount),
          lineDiscountType: Value(p.input.discountType?.code),
          lineDiscountValue: Value(p.input.discountValue),
          lineDiscountAmount: Value(p.discountAmount),
          grossAmount: Value(p.grossAmount),
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

    return PosSaleEnvelope(
      header: header,
      items: itemCompanions,
      payments: paymentCompanions,
      taxes: taxCompanions,
      auditLogEntry: auditLogEntry,
    );
  }

  static int toQtyScaled(double quantity) => (quantity * quantityScale).round();
}

class _ProcessedSaleLine {
  final SaleLineInput input;
  final double grossAmount;
  final double discountAmount;
  final double taxableAmount;
  final double taxAmount;
  final double lineTotal;

  const _ProcessedSaleLine({
    required this.input,
    required this.grossAmount,
    required this.discountAmount,
    required this.taxableAmount,
    required this.taxAmount,
    required this.lineTotal,
  });
}

class PosSaleCompletionPersistResult {
  final String saleId;
  final String localSaleNo;
  final bool uploadQueued;

  const PosSaleCompletionPersistResult({
    required this.saleId,
    required this.localSaleNo,
    required this.uploadQueued,
  });
}

class PosSaleCompletionWorkflow {
  static const _uuid = Uuid();

  final SalesDao salesDao;
  final PosConfigRepository config;
  final InvoiceNumberService invoiceNumberService;
  final InvoiceDocumentBuilder invoiceDocumentBuilder;
  final OutboxEventFactory outboxEventFactory;
  final PrintQueue printQueue;
  final PrintJobProcessor printJobProcessor;
  final Clock clock;

  const PosSaleCompletionWorkflow({
    required this.salesDao,
    required this.config,
    required this.invoiceNumberService,
    required this.invoiceDocumentBuilder,
    required this.outboxEventFactory,
    required this.printQueue,
    required this.printJobProcessor,
    required this.clock,
  });

  Future<PosSaleCompletionPersistResult> persistCompletedSale({
    required String shiftId,
    required ActivePosSession session,
    required List<SaleLineInput> lines,
    required List<SalePaymentInput> payments,
    required CheckoutQuote quote,
    required PaymentValidationResult paymentResult,
    required String checkoutAttemptId,
    required String? customerId,
    required String? customerName,
    required String? customerTaxNumber,
  }) async {
    final localInvoiceNo = await invoiceNumberService.generateNext(
      branchNo: session.activeBranchNo,
      machineNo: session.activeMachineNo,
      sequenceType: PosBusinessRules.sequenceType(
        session.invoiceSeries,
        fallback: 'sale',
      ),
    );

    final saleId = 'SALE_${_uuid.v4()}';
    final now = clock.now();
    final idempotencyKey = 'sale_$checkoutAttemptId';

    final envelope = const PosSaleEnvelopeBuilder().build(
      saleId: saleId,
      localInvoiceNo: localInvoiceNo,
      shiftId: shiftId,
      session: session,
      lines: lines,
      payments: payments,
      quote: quote,
      paymentResult: paymentResult,
      customerId: customerId,
      customerName: customerName,
      customerTaxNumber: customerTaxNumber,
      idempotencyKey: idempotencyKey,
      now: now,
    );

    final invoiceDocument = await invoiceDocumentBuilder
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
          customerId: customerId,
          customerName: customerName,
          customerTaxNumber: customerTaxNumber,
          lines: lines,
          quote: quote,
          payments: payments,
          paidTotal: paymentResult.paidTotal,
          remainingTotal: paymentResult.remainingTotal,
          changeTotal: paymentResult.changeTotal,
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

    final printJobs = (config.autoPrintAfterSale || session.autoPrint)
        ? await printQueue.invoiceReceipt(
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

    await salesDao.persistSaleEnvelope(
      header: envelope.header,
      items: envelope.items,
      payments: envelope.payments,
      taxes: envelope.taxes,
      invoiceDocument: invoiceArchive,
      printJobs: printJobs,
      auditLogEntry: envelope.auditLogEntry,
      outboxEntry: outboxEventFactory.saleCreated(
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
      await printJobProcessor.processJobIds(printJobIds);
    }

    return PosSaleCompletionPersistResult(
      saleId: saleId,
      localSaleNo: localInvoiceNo,
      uploadQueued: true,
    );
  }
}

class AddToCartResult {
  final String itemName;
  final double quantity;
  final bool wasIncremented;

  const AddToCartResult({
    required this.itemName,
    required this.quantity,
    required this.wasIncremented,
  });
}

class CartDiscountDraftResult {
  final bool shouldClear;
  final double? value;
  final String? errorMessage;

  const CartDiscountDraftResult._({
    required this.shouldClear,
    this.value,
    this.errorMessage,
  });

  const CartDiscountDraftResult.clear() : this._(shouldClear: true);

  const CartDiscountDraftResult.valid(double value)
    : this._(shouldClear: false, value: value);

  const CartDiscountDraftResult.invalid(String message)
    : this._(shouldClear: false, errorMessage: message);

  bool get isValid => errorMessage == null && !shouldClear && value != null;
}

abstract final class CartDiscountDraftRules {
  static CartDiscountDraftResult parse({
    required String raw,
    required DiscountType type,
    required double grossAmount,
  }) {
    final input = raw.trim();

    if (input.isEmpty) {
      return const CartDiscountDraftResult.clear();
    }

    final value = PosNumericInputRules.parseDecimalInput(raw);

    if (value == null || value < 0) {
      return const CartDiscountDraftResult.invalid('أدخل خصمًا صحيحًا.');
    }

    if (type == DiscountType.percentage && value > 100) {
      return const CartDiscountDraftResult.invalid('النسبة لا تتجاوز 100%.');
    }

    if (type == DiscountType.fixed && value > grossAmount) {
      return const CartDiscountDraftResult.invalid(
        'الخصم لا يتجاوز إجمالي السطر.',
      );
    }

    return CartDiscountDraftResult.valid(value);
  }
}

abstract final class CartLineQuoteLookup {
  static double? lineTotalForItem(CartItem item, CheckoutQuote? quote) {
    return _findLine(item, quote)?.lineTotal;
  }

  static double? lineDiscountForItem(CartItem item, CheckoutQuote? quote) {
    return _findLine(item, quote)?.discountAmount;
  }

  static PricedLine? _findLine(CartItem item, CheckoutQuote? quote) {
    if (quote == null) return null;

    for (final line in quote.lines) {
      if (line.itemId == item.itemId && line.unitId == item.unitId) {
        return line;
      }
    }

    return null;
  }
}

class CartItem {
  final SellableItemSnapshot sellableItem;
  final double quantity;
  final DiscountType? discountType;
  final double? discountValue;
  final String? notes;

  const CartItem({
    required this.sellableItem,
    required this.quantity,
    this.discountType,
    this.discountValue,
    this.notes,
  });

  String get itemId => sellableItem.itemId;
  String get unitId => sellableItem.unitId;
  String get productName => sellableItem.itemName;
  String get unitName => sellableItem.unitName;
  double? get unitSize => sellableItem.unitSize;
  bool get useQtyFraction => sellableItem.useQtyFraction;
  String? get barcode => sellableItem.barcode;
  double get unitPrice => sellableItem.unitPrice;
  double get grossAmount => PricingEngine.roundAmount(unitPrice * quantity);
  double get taxRate => sellableItem.taxRate;
  bool get allowDiscount => sellableItem.allowDiscount;
  String get lineKey => '$itemId|$unitId';

  CartItem copyWith({
    SellableItemSnapshot? sellableItem,
    double? quantity,
    DiscountType? discountType,
    double? discountValue,
    String? notes,
  }) {
    return CartItem(
      sellableItem: sellableItem ?? this.sellableItem,
      quantity: quantity ?? this.quantity,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      notes: notes ?? this.notes,
    );
  }

  CartItem withoutDiscount() {
    return CartItem(
      sellableItem: sellableItem,
      quantity: quantity,
      notes: notes,
    );
  }

  CartItem withUnitPrice(double unitPrice) {
    return copyWith(
      sellableItem: SellableItemSnapshot(
        itemId: sellableItem.itemId,
        unitId: sellableItem.unitId,
        itemName: sellableItem.itemName,
        unitName: sellableItem.unitName,
        unitSize: sellableItem.unitSize,
        barcode: sellableItem.barcode,
        unitPrice: PricingEngine.roundAmount(unitPrice),
        taxRate: sellableItem.taxRate,
        allowDiscount: sellableItem.allowDiscount,
        useQtyFraction: sellableItem.useQtyFraction,
      ),
    );
  }

  SaleLineInput toSaleLineInput() {
    return SaleLineInput(
      itemId: itemId,
      unitId: unitId,
      itemName: productName,
      unitName: unitName,
      unitSize: unitSize,
      barcode: barcode,
      useQtyFraction: useQtyFraction,
      quantity: quantity,
      unitPrice: unitPrice,
      taxRate: taxRate,
      discountType: discountType,
      discountValue: discountValue,
      allowDiscount: allowDiscount,
      notes: notes,
    );
  }

  Map<String, dynamic> toHeldOrderSnapshotJson() {
    return toSaleLineInput().toHeldOrderSnapshotJson();
  }
}

class Cart {
  final List<CartItem> items;

  const Cart({this.items = const []});

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  int get totalLinesCount => items.length;

  CartItem? findLine(String itemId, String? unitId) {
    for (final item in items) {
      if (_sameLine(item, itemId, unitId)) return item;
    }
    return null;
  }

  double quantityFor(String itemId, String? unitId) {
    return findLine(itemId, unitId)?.quantity ?? 0;
  }

  Cart addSellableItem(SellableItemSnapshot snapshot) {
    final existing = findLine(snapshot.itemId, snapshot.unitId);

    if (existing == null) {
      SaleLineValidator.validateQuantityForSnapshot(snapshot, 1.0);
      return Cart(
        items: [
          ...items,
          CartItem(sellableItem: snapshot, quantity: 1.0),
        ],
      );
    }

    return changeQuantity(
      existing.itemId,
      existing.unitId,
      existing.quantity + 1,
    );
  }

  Cart replaceLine(CartItem updatedLine) {
    return Cart(
      items: items
          .map(
            (item) => _sameLine(item, updatedLine.itemId, updatedLine.unitId)
                ? updatedLine
                : item,
          )
          .toList(),
    );
  }

  Cart changeQuantity(String itemId, String? unitId, double newQuantity) {
    if (newQuantity <= 0) return removeItem(itemId, unitId);

    final current = findLine(itemId, unitId);
    if (current == null) return this;

    SaleLineValidator.validateQuantityForSnapshot(
      current.sellableItem,
      newQuantity,
    );

    return replaceLine(current.copyWith(quantity: newQuantity));
  }

  Cart applyResolvedPrice({
    required String itemId,
    required String unitId,
    required SellableItemSnapshot pricedSnapshot,
  }) {
    final current = findLine(itemId, unitId);
    if (current == null) return this;

    return replaceLine(current.copyWith(sellableItem: pricedSnapshot));
  }

  Cart changeUnitPrice(String itemId, String? unitId, double unitPrice) {
    if (unitPrice <= 0 || unitPrice.isNaN) {
      throw const BusinessException(
        'Unit price must be greater than zero.',
        code: 'INVALID_UNIT_PRICE',
      );
    }

    final current = findLine(itemId, unitId);
    if (current == null) return this;

    return replaceLine(current.withUnitPrice(unitPrice));
  }

  Cart applyLineDiscount(
    String itemId,
    String? unitId, {
    required DiscountType type,
    required double value,
  }) {
    return Cart(
      items: items.map((item) {
        if (!_sameLine(item, itemId, unitId)) return item;

        SaleLineValidator.validateDiscount(
          allowDiscount: item.allowDiscount,
          itemName: item.productName,
          value: value,
        );

        return item.copyWith(discountType: type, discountValue: value);
      }).toList(),
    );
  }

  Cart clearLineDiscount(String itemId, String? unitId) {
    return Cart(
      items: items
          .map(
            (item) =>
                _sameLine(item, itemId, unitId) ? item.withoutDiscount() : item,
          )
          .toList(),
    );
  }

  Cart removeItem(String itemId, String? unitId) {
    return Cart(
      items: items.where((item) => !_sameLine(item, itemId, unitId)).toList(),
    );
  }

  List<SaleLineInput> toSaleLineInputs() {
    return items.map((item) => item.toSaleLineInput()).toList();
  }

  List<Map<String, dynamic>> toHeldOrderSnapshotJson() {
    return items.map((item) => item.toHeldOrderSnapshotJson()).toList();
  }

  CheckoutQuote previewQuote({
    required PricingEngine pricingEngine,
    required bool useTax,
    required bool priceIncludesTax,
  }) {
    return PosSaleQuoteRules.quote(
      pricingEngine: pricingEngine,
      lines: toSaleLineInputs(),
      useTax: useTax,
      priceIncludesTax: priceIncludesTax,
    );
  }

  static Cart fromSaleLineInputs(List<SaleLineInput> lines) {
    final items = <CartItem>[];

    for (final line in lines) {
      final snapshot = SellableItemSnapshot(
        itemId: line.itemId,
        unitId: line.unitId,
        itemName: line.itemName,
        unitName: line.unitName,
        unitSize: line.unitSize,
        barcode: line.barcode,
        unitPrice: line.unitPrice,
        taxRate: line.taxRate,
        allowDiscount: line.allowDiscount,
        useQtyFraction: line.useQtyFraction,
      );

      final existingIndex = items.indexWhere(
        (item) => item.itemId == line.itemId && item.unitId == line.unitId,
      );

      final nextItem = CartItem(
        sellableItem: snapshot,
        quantity: line.quantity,
        discountType: line.discountType,
        discountValue: line.discountValue,
        notes: line.notes,
      );

      if (existingIndex < 0) {
        items.add(nextItem);
      } else {
        final existing = items[existingIndex];
        items[existingIndex] = existing.copyWith(
          quantity: existing.quantity + line.quantity,
        );
      }
    }

    return Cart(items: items);
  }

  bool _sameLine(CartItem item, String itemId, String? unitId) {
    return item.itemId == itemId && item.unitId == unitId;
  }
}
