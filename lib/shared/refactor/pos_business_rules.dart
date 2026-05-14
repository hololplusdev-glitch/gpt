import 'dart:convert';

import 'package:drift/drift.dart';
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
import 'package:holol_POS/shared/models/sellable_item_snapshot.dart';

typedef BusinessRuleExceptionFactory = BusinessException Function(String message);

abstract final class PosDomainTolerances {
  static const double money = 0.01;
  static const double quantity = 0.000001;
}

abstract final class PosBusinessRules {
  static String sequenceType(String? configuredSeries, {required String fallback}) {
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
      throw _exception(exceptionFactory, 'Invalid quantity for ${line.itemName}.', code: 'INVALID_QUANTITY');
    }
    if (!line.useQtyFraction && !isWholeQuantity(line.quantity)) {
      throw _exception(exceptionFactory, 'Fraction quantity is not allowed for ${line.itemName}.', code: 'QUANTITY_FRACTION_NOT_ALLOWED');
    }
    if (line.unitPrice <= 0) {
      throw _exception(exceptionFactory, 'Missing price for ${line.itemName}.', code: 'MISSING_PRICE');
    }
    if (line.taxRate < 0) {
      throw _exception(exceptionFactory, 'Invalid tax rate for ${line.itemName}.', code: 'INVALID_TAX_RATE');
    }
    if ((line.discountValue ?? 0) < 0) {
      throw _exception(exceptionFactory, 'Invalid discount for ${line.itemName}.', code: 'INVALID_DISCOUNT');
    }
    if (!line.allowDiscount && line.discountType != null && (line.discountValue ?? 0) > 0) {
      throw _exception(exceptionFactory, 'Discounts are not allowed for ${line.itemName}.', code: 'DISCOUNT_NOT_ALLOWED');
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
        lines: lines.toPricingLineInputs(),
        taxRate: 0,
        useTax: useTax,
        priceIncludesTax: priceIncludesTax,
      );
    } on PricingException catch (e) {
      throw exceptionFactory?.call(e.message) ?? BusinessException(e.message, code: 'PRICING_ERROR');
    }
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
      throw exceptionFactory?.call(message) ?? BusinessException(message, code: code);
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
      throw exceptionFactory?.call(message) ?? BusinessException(message, code: code);
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
      throw exceptionFactory?.call('Sale not found.') ?? const BusinessException('Sale not found.', code: 'SALE_NOT_FOUND');
    }
    if (sale.type != SaleType.sale.code || sale.status != SaleStatus.completed.code) {
      throw exceptionFactory?.call('Only completed normal sales can be changed.') ??
          const BusinessException('Only completed normal sales can be changed.', code: 'SALE_NOT_MUTABLE');
    }
    return sale;
  }
}

class PosOfficialPriceResolver {
  final CatalogDao catalogDao;
  final BusinessRuleExceptionFactory? exceptionFactory;

  const PosOfficialPriceResolver({
    required this.catalogDao,
    this.exceptionFactory,
  });

  Future<List<SaleLineInput>> resolve({
    required ActivePosSession session,
    required List<SaleLineInput> draftLines,
  }) async {
    final resolved = <SaleLineInput>[];

    for (final line in draftLines) {
      final item = await catalogDao.getItemById(line.itemId);

      if (item == null || item.inactive || item.noSale) {
        throw _exception('Item ${line.itemName} is no longer sellable.');
      }

      final price = await catalogDao.resolveItemPrice(
        itemId: line.itemId,
        priceLevelId: session.activePriceLevelId,
        storeId: session.activeStoreId,
        unitId: line.unitId,
      );

      if (price == null) {
        throw _exception('Missing exact ITEM_PRICE for ${line.itemName}.');
      }

      resolved.add(
        SaleLineInput(
          itemId: item.id,
          unitId: price.unitId ?? line.unitId,
          itemName: item.name,
          unitName: price.unitName ?? line.unitName,
          unitSize: price.unitSize ?? line.unitSize,
          barcode: line.barcode ?? price.barcode,
          useQtyFraction: price.useQtyFraction,
          quantity: line.quantity,
          unitPrice: price.unitPrice,
          taxRate: price.taxRate != 0 ? price.taxRate : item.taxRate,
          discountType: line.discountType,
          discountValue: line.discountValue,
          allowDiscount: price.allowDiscount,
          notes: line.notes,
        ),
      );
    }

    return resolved;
  }

  BusinessException _exception(String message) {
    return exceptionFactory?.call(message) ?? BusinessException(message, code: 'OFFICIAL_PRICE_ERROR');
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
    throw exceptionFactory?.call(message) ?? BusinessException(message, code: 'INVALID_HELD_ORDER_SNAPSHOT');
  }

  static String requiredText(
    Object? value,
    String fieldName, {
    BusinessRuleExceptionFactory? exceptionFactory,
  }) {
    final result = text(value);
    if (result == null || result.isEmpty) {
      final message = 'Held order snapshot is missing $fieldName.';
      throw exceptionFactory?.call(message) ?? BusinessException(message, code: 'INVALID_HELD_ORDER_SNAPSHOT');
    }
    return result;
  }

  static String? text(Object? value) {
    final result = value?.toString().trim();
    if (result == null || result.isEmpty || result.toLowerCase() == 'null') return null;
    return result;
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
      final itemId = PosHeldSnapshotReader.requiredText(snapshot['itemId'], 'itemId', exceptionFactory: exceptionFactory);
      final unitId = PosHeldSnapshotReader.requiredText(snapshot['unitId'], 'unitId', exceptionFactory: exceptionFactory);
      final quantity = PosHeldSnapshotReader.doubleValue(snapshot['quantity'], fallback: 1.0);
      final oldUnitPrice = PosHeldSnapshotReader.nullableDouble(snapshot['unitPrice']);
      final oldTaxRate = PosHeldSnapshotReader.nullableDouble(snapshot['taxRate']);
      final oldUnitName = PosHeldSnapshotReader.text(snapshot['unitName']);
      final itemName = PosHeldSnapshotReader.text(snapshot['itemName']) ?? itemId;

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

      final discountType = DiscountType.fromCode(PosHeldSnapshotReader.text(snapshot['discountType']));
      final discountValue = PosHeldSnapshotReader.nullableDouble(snapshot['discountValue']);

      if (oldUnitPrice != null && oldUnitPrice != sellable.unitPrice) {
        warnings.add('تغير سعر $itemName من $oldUnitPrice إلى ${sellable.unitPrice}.');
      }
      if (oldTaxRate != null && oldTaxRate != sellable.taxRate) {
        warnings.add('تغيرت ضريبة $itemName من $oldTaxRate إلى ${sellable.taxRate}.');
      }
      if (oldUnitName != null && oldUnitName != sellable.unitName) {
        warnings.add('تغير اسم وحدة $itemName من $oldUnitName إلى ${sellable.unitName}.');
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
        unitPrice: sellable.unitPrice,
        taxRate: sellable.taxRate,
        discountType: discountType,
        discountValue: discountValue,
        allowDiscount: sellable.allowDiscount,
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
    return exceptionFactory?.call(message) ?? BusinessException(message, code: 'HELD_ORDER_REHYDRATION_ERROR');
  }
}

class PosHeldOrderResumeData {
  final List<SaleLineInput> lines;
  final List<String> warnings;

  const PosHeldOrderResumeData({
    required this.lines,
    required this.warnings,
  });
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
final taxGroups = <double, ({double taxableAmount, double taxAmount, double rate})>{};
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
