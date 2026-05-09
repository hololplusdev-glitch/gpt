// features/sales/application/sales_service.dart
// WHY: Orchestrates the complete checkout pipeline.
// Validates shift, checks permissions, calculates totals, and persists the sale
// atomically. Invoice upload/stock deduction are intentionally outside this flow.
//
// TODO(Phase:DecimalQty): Support fractional quantities when item.use_qty_fraction=1.
// Currently quantity is int-only throughout SaleLineInput.

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_flutter/core/errors/app_exception.dart';
import 'package:pos_flutter/core/persistence/daos/audit_dao.dart';
import 'package:pos_flutter/core/persistence/daos/sales_dao.dart';
import 'package:pos_flutter/core/persistence/daos/shift_dao.dart';
import 'package:pos_flutter/core/persistence/database.dart';
import 'package:pos_flutter/core/persistence/pos_config_repository.dart';
import 'package:pos_flutter/core/services/invoice_number_service.dart';
import 'package:pos_flutter/core/services/payments/payment_method_resolver.dart';
import 'package:pos_flutter/core/services/permission_service.dart';
import 'package:pos_flutter/core/services/pricing/pricing_engine.dart';
import 'package:pos_flutter/core/services/time/clock.dart';
import 'package:pos_flutter/features/sales/domain/models/sale_inputs.dart';
import 'package:pos_flutter/shared/models/enums.dart';
import 'package:pos_flutter/shared/models/sales_history.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';
import 'package:uuid/uuid.dart';

/// The checkout pipeline from validated cart to persisted sale.
class SalesService {
  final SalesDao _salesDao;
  final ShiftDao _shiftDao;
  final AuditDao _auditDao;
  final PermissionService _permissions;
  final PosConfigRepository _config;
  final ActivePosSession? _activeSession;
  final InvoiceNumberService _invoiceNumberService;
  final PricingEngine _pricingEngine;
  final Clock _clock;

  SalesService({
    required SalesDao salesDao,
    required ShiftDao shiftDao,
    required AuditDao auditDao,
    required PermissionService permissions,
    required PosConfigRepository config,
    required ActivePosSession? activeSession,
    required InvoiceNumberService invoiceNumberService,
    PricingEngine pricingEngine = const PricingEngine(),
    Clock clock = const SystemClock(),
  }) : _salesDao = salesDao,
       _shiftDao = shiftDao,
       _auditDao = auditDao,
       _permissions = permissions,
       _config = config,
       _activeSession = activeSession,
       _invoiceNumberService = invoiceNumberService,
       _pricingEngine = pricingEngine,
       _clock = clock;

  static const _uuid = Uuid();

  // ---------------------------------------------------------------------------
  // Pricing
  // ---------------------------------------------------------------------------

  CheckoutQuote quoteSale({
    required List<SaleLineInput> lineItems,
    SaleDiscountInput? invoiceDiscount,
  }) {
    try {
      return _pricingEngine.calculateQuote(
        lines: lineItems
            .map(
              (line) => PricingLineInput(
                itemId: line.itemId,
                unitId: line.unitId,
                unitPrice: line.unitPrice,
                quantity: line.quantity,
                discountAmount: line.discountAmount,
                taxRate: line.taxRate,
              ),
            )
            .toList(),
        taxRate: 0,
        useTax: _requireActiveSession().activeUseTax,
        priceIncludesTax: _config.priceIncludesTax,
        invoiceDiscount: invoiceDiscount == null
            ? null
            : PricingDiscountInput(
                type: invoiceDiscount.type,
                value: invoiceDiscount.value,
              ),
      );
    } on PricingException catch (e) {
      throw SaleException(e.message);
    }
  }

  // ---------------------------------------------------------------------------
  // Complete Sale
  // ---------------------------------------------------------------------------

  /// Validate, persist, and finalize a sale.
  /// Returns the created sale local ID.
  Future<String> completeSale({
    required String shiftId,
    required List<SaleLineInput> lineItems,
    required List<SalePaymentInput> payments,
    String? customerId,
    String? customerName,
    String? customerTaxNumber,
    SaleDiscountInput? invoiceDiscount,
    String? notes,
  }) async {
    final activeSession = _requireActiveSession();
    final activeMachineNo = activeSession.activeMachineNo;
    final activeBranchNo = activeSession.activeBranchNo;
    final activeUserId = activeSession.activeUserId;

    // 1. Validate permission
    await _permissions.requirePermission(
      userId: activeUserId,
      terminalId: activeMachineNo,
      permission: PermissionCode.saleCreate,
    );

    // 2. Validate open shift
    final shift = await _shiftDao.getById(shiftId);
    final isOpen = shift != null && shift.status == ShiftStatus.open.code;
    if (!isOpen) {
      throw SaleException('No open shift. Open a shift before selling.');
    }

    // 3. Validate cart not empty
    if (lineItems.isEmpty) {
      throw SaleException('No items in cart.');
    }
    _validateSaleInputs(lineItems: lineItems);

    // 4. Calculate official checkout quote.
    final quote = quoteSale(
      lineItems: lineItems,
      invoiceDiscount: invoiceDiscount,
    );
    final subtotal = quote.subtotal;
    final discountTotal = quote.discountTotal;
    final taxTotal = quote.taxTotal;
    final grandTotal = quote.grandTotal;
    final invoiceDiscountAmount = quote.invoiceDiscountAmount;
    final processedItems = <_ProcessedItem>[];

    for (var i = 0; i < lineItems.length; i++) {
      final line = lineItems[i];
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

    // 5. Validate payments against the same quote that will be persisted.
    final paymentResult = PaymentPolicy(
      requireCardReference: false,
      allowCustomerCredit: _config.allowCustomerCredit,
    ).validate(quote: quote, payments: payments);
    final paidTotal = paymentResult.paidTotal;
    final remaining = paymentResult.remainingTotal;
    final changeTotal = paymentResult.changeTotal;

    // 6. Generate local invoice number
    final localInvoiceNo = await _invoiceNumberService.generateNext(
      custCode: activeSession.custCode,
      branchNo: activeBranchNo,
      machineNo: activeMachineNo,
      userId: activeUserId,
    );

    // 7. Persist atomically
    final saleId = 'SALE_${_uuid.v4()}';
    final now = _clock.now();
    final idempotencyKey = 'sale_$saleId';

    final header = SalesCompanion(
      id: Value(saleId),
      localSaleNo: Value(localInvoiceNo),
      type: Value(SaleType.sale.code),
      status: Value(SaleStatus.completed.code),
      terminalId: Value(activeMachineNo),
      shiftId: Value(shiftId),
      cashierId: Value(activeUserId),
      branchNo: Value(activeBranchNo),
      tenantCode: Value(activeSession.custCode),
      branchYear: Value(activeSession.activeBranchYear),
      machineNo: Value(activeMachineNo),
      storeId: Value(activeSession.activeStoreId),
      priceLevelId: Value(activeSession.activePriceLevelId),
      useTax: Value(activeSession.activeUseTax),
      sourceUserId: Value(activeUserId),
      cashierNameSnapshot: Value(activeSession.activeUserName),
      customerId: Value(customerId),
      customerNameSnapshot: Value(customerName),
      customerTaxNumberSnapshot: Value(customerTaxNumber),
      subtotal: Value(subtotal),
      discountTotal: Value(discountTotal),
      taxTotal: Value(taxTotal),
      grandTotal: Value(grandTotal),
      paidTotal: Value(paidTotal),
      remainingTotal: Value(remaining > 0 ? remaining : 0),
      changeTotal: Value(changeTotal),
      syncStatus: Value(OutboxStatus.pending.code),
      idempotencyKey: Value(idempotencyKey),
      notes: Value(notes),
      createdAt: Value(now),
      completedAt: Value(now),
    );

    final itemCompanions = <SaleLinesCompanion>[];

    // Distribute invoice discount
    var remainingInvoiceDiscount = invoiceDiscountAmount;
    final totalTaxableForDiscount = processedItems.fold(
      0.0,
      (sum, p) => sum + p.taxableAmount,
    );

    for (int i = 0; i < processedItems.length; i++) {
      final p = processedItems[i];
      final itemRowId = 'TI_${_uuid.v4()}';

      var lineInvoiceDiscount = 0.0;
      if (invoiceDiscountAmount > 0 && totalTaxableForDiscount > 0) {
        if (i == processedItems.length - 1) {
          lineInvoiceDiscount = remainingInvoiceDiscount;
        } else {
          lineInvoiceDiscount = PricingEngine.roundAmount(
            invoiceDiscountAmount * p.taxableAmount / totalTaxableForDiscount,
          );
        }
        remainingInvoiceDiscount -= lineInvoiceDiscount;
      }

      itemCompanions.add(
        SaleLinesCompanion(
          id: Value(itemRowId),
          saleId: Value(saleId),
          itemId: Value(p.input.itemId),
          unitId: Value(p.input.unitId),
          itemNameSnapshot: Value(p.input.itemName),
          unitNameSnapshot: Value(p.input.unitName),
          barcode: Value(p.input.barcode),
          qtyScaled: Value(p.input.quantity.round()),
          unitPrice: Value(p.input.unitPrice),
          taxRate: Value(p.input.taxRate),
          taxableAmount: Value(p.taxableAmount),
          taxAmount: Value(p.taxAmount),
          lineDiscountType: Value(p.input.discountType?.code),
          lineDiscountValue: Value(p.input.discountValue),
          lineDiscountAmount: Value(p.input.discountAmount),
          invoiceDiscountShare: Value(lineInvoiceDiscount),
          grossAmount: Value(p.input.unitPrice * p.input.quantity),
          allowDiscountSnapshot: Value(p.input.allowDiscount),
          priceSource: Value(_priceSourceForLine(p.input)),
          storeId: Value(activeSession.activeStoreId),
          priceLevelId: Value(activeSession.activePriceLevelId),
          unitSize: Value(p.input.unitSize),
          lineTotal: Value(p.lineTotal),
          overrideReason: Value(p.input.isPriceOverridden ? 'manual' : null),
          notes: Value(p.input.notes),
        ),
      );
    }

    final paymentCompanions = <SalePaymentsCompanion>[];
    for (final p in payments) {
      final paymentRowId = 'TP_${_uuid.v4()}';
      final paymentType = p.resolvedType;
      paymentCompanions.add(
        SalePaymentsCompanion(
          id: Value(paymentRowId),
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

    // Tax summary
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

    // Discount summary
    List<SaleAdjustmentsCompanion>? discountCompanions;
    if (invoiceDiscount != null && invoiceDiscountAmount > 0) {
      discountCompanions = [
        SaleAdjustmentsCompanion(
          id: Value('TD_${_uuid.v4()}'),
          saleId: Value(saleId),
          scope: Value(AdjustmentScope.invoice.code),
          type: Value(invoiceDiscount.type.code),
          source: Value(AdjustmentSource.manual.code),
          value: Value(invoiceDiscount.value),
          amount: Value(invoiceDiscountAmount),
          reason: Value(invoiceDiscount.reason),
          approvedBy: Value(invoiceDiscount.approvedBy),
          createdAt: Value(now),
        ),
      ];
    }

    final auditLogEntry = AuditLogCompanion(
      id: Value('AUD_${_uuid.v4()}'),
      action: Value(AuditAction.saleCompleted.code),
      actorId: Value(activeUserId),
      actorName: Value(activeSession.activeUserName),
      targetType: Value(OutboxEntityType.sale.code),
      targetId: Value(saleId),
      detailsJson: Value(
        jsonEncode({
          'invoiceNo': localInvoiceNo,
          'grandTotal': grandTotal,
          'itemCount': lineItems.length,
        }),
      ),
      terminalId: Value(activeMachineNo),
      createdAt: Value(now),
    );

    final outboxEntry = OutboxEventsCompanion(
      id: Value('OBX_${_uuid.v4()}'),
      eventType: Value(OutboxEventType.saleCreated.code),
      entityType: Value(OutboxEntityType.sale.code),
      entityId: Value(saleId),
      payloadJson: Value(
        jsonEncode({
          'saleId': saleId,
          'localSaleNo': localInvoiceNo,
          'machineNo': activeMachineNo,
          'branchNo': activeBranchNo,
          'shiftId': shiftId,
          'cashierId': activeUserId,
          'grandTotal': grandTotal,
          'completedAt': now.toIso8601String(),
        }),
      ),
      status: Value(OutboxStatus.pending.code),
      createdAt: Value(now),
      idempotencyKey: Value(idempotencyKey),
    );

    await _salesDao.persistSaleEnvelope(
      header: header,
      items: itemCompanions,
      payments: paymentCompanions,
      taxes: taxCompanions,
      discounts: discountCompanions,
      auditLogEntry: auditLogEntry,
      outboxEntry: outboxEntry,
    );

    return saleId;
  }

  // ---------------------------------------------------------------------------
  // Held Orders
  // ---------------------------------------------------------------------------

  /// Hold the current cart as a suspended order.
  Future<String> holdOrder({
    required String shiftId,
    required List<SaleLineInput> items,
    String? customerId,
    String? customerName,
    String? referenceName,
    String? notes,
  }) async {
    final activeSession = _requireActiveSession();
    final terminalId = activeSession.activeMachineNo;
    final cashierId = activeSession.activeUserId;
    
    await _permissions.requirePermission(
      userId: cashierId,
      terminalId: terminalId,
      permission: PermissionCode.holdOrder,
    );
    if (!_config.useHeldInvoices) {
      throw SaleException('Held orders are disabled by POS configuration.');
    }

    // Check max held orders
    final currentCount = await _salesDao.countActiveHeldOrders(shiftId);
    if (currentCount >= _config.maxHeldInvoices) {
      throw SaleException(
        'Maximum held orders (${_config.maxHeldInvoices}) reached.',
      );
    }

    _validateSaleInputs(lineItems: items);
    final quote = quoteSale(lineItems: items);
    final id = 'HLD_${_uuid.v4()}';
    final now = _clock.now();

    final itemsJson = jsonEncode({
      'version': 1,
      'type': 'cart_snapshot',
      'createdAt': now.toIso8601String(),
      'createdBy': cashierId,
      'items': items.map((i) => i.toHeldOrderSnapshotJson()).toList(),
    });

    await _salesDao.holdOrder(
      HeldOrdersCompanion(
        id: Value(id),
        custCode: Value(session.custCode),
        branchNo: Value(session.activeBranchNo),
        branchYear: Value(session.activeBranchYear),
        machineNo: Value(session.activeMachineNo),
        storeId: Value(session.activeStoreId),
        priceLevelId: Value(session.activePriceLevelId),
        useTax: Value(session.activeUseTax),
        shiftId: Value(shiftId),
        cashierId: Value(cashierId),
        customerId: Value(customerId),
        customerNameSnapshot: Value(customerName),
        referenceName: Value(referenceName),
        snapshotJson: Value(itemsJson),
        subtotal: Value(quote.subtotal),
        taxTotal: Value(quote.taxTotal),
        discountTotal: Value(quote.discountTotal),
        grandTotal: Value(quote.grandTotal),
        status: Value(HeldOrderStatus.held.code),
        notes: Value(notes),
        heldAt: Value(now),
      ),
    );

    await _auditDao.log(
      id: 'AUD_${_uuid.v4()}',
      action: AuditAction.orderHeld,
      actorId: cashierId,
      targetType: OutboxEntityType.heldOrder.code,
      targetId: id,
      terminalId: terminalId,
    );

    return id;
  }

  /// Resume a held order — returns the items JSON for cart restoration.
  Future<String> resumeHeldOrder({
    required String orderId,
  }) async {
    final activeSession = _requireActiveSession();
    final terminalId = activeSession.activeMachineNo;
    final cashierId = activeSession.activeUserId;
    
    await _permissions.requirePermission(
      userId: cashierId,
      terminalId: terminalId,
      permission: PermissionCode.recallOrder,
    );

    final orders = await _salesDao.getAllHeldOrders(terminalId);
    final order = orders.where((o) => o.id == orderId).firstOrNull;
    if (order == null) {
      throw SaleException('Held order not found or already resumed.');
    }

    await _salesDao.resumeHeldOrder(orderId, _clock.now());

    await _auditDao.log(
      id: 'AUD_${_uuid.v4()}',
      action: AuditAction.orderRecalled,
      actorId: cashierId,
      targetType: OutboxEntityType.heldOrder.code,
      targetId: orderId,
      terminalId: terminalId,
    );

    return order.snapshotJson;
  }

  /// Cancel a held order.
  Future<void> cancelHeldOrder({
    required String orderId,
  }) async {
    final activeSession = _requireActiveSession();
    final terminalId = activeSession.activeMachineNo;
    final cashierId = activeSession.activeUserId;
    
    await _permissions.requirePermission(
      userId: cashierId,
      terminalId: terminalId,
      permission: PermissionCode.cancelHeldOrder,
    );

    await _salesDao.cancelHeldOrder(orderId);

    await _auditDao.log(
      id: 'AUD_${_uuid.v4()}',
      action: AuditAction.orderCancelled,
      actorId: cashierId,
      targetType: OutboxEntityType.heldOrder.code,
      targetId: orderId,
      terminalId: terminalId,
    );
  }

  /// Get active held orders for current shift.
  Future<List<HeldOrder>> getHeldOrders(String shiftId) async {
    return _salesDao.getActiveHeldOrders(shiftId);
  }

  // ---------------------------------------------------------------------------
  // Void Sale
  // ---------------------------------------------------------------------------

  /// Void a completed sale.
  Future<void> voidSale({
    required String saleId,
    String? supervisorId,
  }) async {
    final activeSession = _requireActiveSession();
    
    await _permissions.requirePermission(
      userId: activeSession.activeUserId,
      terminalId: activeSession.activeMachineNo,
      permission: PermissionCode.saleVoid,
    );

    final now = _clock.now();
    final outboxEntry = OutboxEventsCompanion(
      id: Value('OBX_${_uuid.v4()}'),
      eventType: Value(OutboxEventType.saleVoided.code),
      entityType: Value(OutboxEntityType.sale.code),
      entityId: Value(saleId),
      payloadJson: Value(
        jsonEncode({
          'saleId': saleId,
          'cashierId': activeSession.activeUserId,
          'cashierName': activeSession.activeUserName,
          'supervisorId': supervisorId,
          'voidedAt': now.toIso8601String(),
        }),
      ),
      status: Value(OutboxStatus.pending.code),
      createdAt: Value(now),
      idempotencyKey: Value('void_$saleId'),
    );

    final auditLogEntry = AuditLogCompanion(
      id: Value('AUD_${_uuid.v4()}'),
      action: Value(AuditAction.saleVoided.code),
      actorId: Value(activeSession.activeUserId),
      actorName: Value(activeSession.activeUserName),
      supervisorId: Value(supervisorId),
      targetType: Value(OutboxEntityType.sale.code),
      targetId: Value(saleId),
      terminalId: Value(activeSession.activeMachineNo),
      createdAt: Value(now),
    );

    await _salesDao.voidSaleEnvelope(
      saleId: saleId,
      voidedAt: now,
      outboxEntry: outboxEntry,
      auditLogEntry: auditLogEntry,
    );
  }

  // ---------------------------------------------------------------------------
  // History queries
  // ---------------------------------------------------------------------------

  /// Get sales for today.
  Future<List<Sale>> getTodaysSales() async {
    return _salesDao.getSalesByDate(_clock.now());
  }

  Future<List<SaleSummary>> searchSalesHistory({
    String? query,
    int limit = 100,
  }) {
    return _salesDao.searchSalesHistory(query: query, limit: limit);
  }

  Future<List<String>> getDistinctCashierIds() =>
      _salesDao.getDistinctCashierIds();
  Future<List<({String code, String label})>>
  getDistinctPaymentMethodsForHistory() =>
      _salesDao.getDistinctPaymentMethodsForHistory();

  Future<List<SaleSummary>> getSalesFiltered(SalesHistoryFilter filter) async {
    final sales = await _salesDao.getSalesFiltered(filter);
    final paymentLabels = await _salesDao.getPrimaryPaymentLabelsForSales(
      sales.map((sale) => sale.id),
    );
    return sales
        .map(
          (s) => SaleSummary(
            id: s.id,
            localSaleNo: s.localSaleNo,
            status: s.status,
            grandTotal: s.grandTotal,
            createdAt: s.createdAt,
            cashierId: s.cashierId,
            paymentMethodLabel: paymentLabels[s.id],
          ),
        )
        .toList();
  }

  /// Get sale by ID with full details.
  Future<SaleDetail?> getSaleDetail(String saleId) async {
    final sale = await _salesDao.getById(saleId);
    if (sale == null) return null;
    final items = await _salesDao.getSaleLines(saleId);
    final payments = await _salesDao.getSalePayments(saleId);
    return SaleDetail(sale: sale, items: items, payments: payments);
  }

  void _validateSaleInputs({required List<SaleLineInput> lineItems}) {
    for (final line in lineItems) {
      if (line.quantity <= 0) {
        throw SaleException('Invalid quantity for ${line.itemName}.');
      }
      if (line.unitPrice <= 0) {
        throw SaleException('Missing price for ${line.itemName}.');
      }
      if (line.discountAmount < 0) {
        throw SaleException('Invalid discount for ${line.itemName}.');
      }
      if (!line.allowDiscount && line.discountAmount > 0) {
        throw SaleException('Discounts are not allowed for ${line.itemName}.');
      }
      if (line.taxRate < 0) {
        throw SaleException('Invalid tax rate for ${line.itemName}.');
      }
      final lineSubtotal = line.unitPrice * line.quantity;
      if (line.discountAmount > lineSubtotal) {
        throw SaleException(
          'Discount exceeds line subtotal for ${line.itemName}.',
        );
      }
    }
  }

  ActivePosSession _requireActiveSession() {
    final session = _activeSession;
    if (session == null) {
      throw const SaleException('Select a cashier and POS machine before selling.');
    }
    return session;
  }
}

class PaymentPolicy {
  final bool requireCardReference;
  final bool allowCustomerCredit;

  const PaymentPolicy({
    required this.requireCardReference,
    required this.allowCustomerCredit,
  });

  PaymentValidationResult validate({
    required CheckoutQuote quote,
    required List<SalePaymentInput> payments,
  }) {
    if (payments.isEmpty) {
      throw SaleException('At least one payment is required.');
    }
    if (quote.grandTotal < 0) {
      throw SaleException('Invalid sale total.');
    }

    var paidTotal = 0.0;
    var explicitChangeTotal = 0.0;
    var hasChangeCapablePayment = false;

    for (final payment in payments) {
      final type = payment.resolvedType;
      if (payment.amount <= 0) {
        throw SaleException('Payment amount must be greater than zero.');
      }

      final cashTendered = payment.cashTendered;
      final changeGiven = payment.changeGiven ?? 0;
      if ((cashTendered ?? 0) < 0 || changeGiven < 0) {
        throw SaleException('Invalid cash tendered/change values.');
      }

      if (type.allowsChange) {
        hasChangeCapablePayment = true;
        if (cashTendered != null && cashTendered < payment.amount) {
          throw SaleException('Cash tendered is less than payment amount.');
        }
      } else if (changeGiven > 0 || cashTendered != null) {
        throw SaleException('Change is only allowed for cash payments.');
      }

      if (payment.requiresReference ||
          (requireCardReference && type.isManualCard)) {
        if (!payment.hasReference) {
          throw SaleException('Card payment reference is required.');
        }
      }

      if (type.isIntegratedCard && !payment.hasTerminalApproval) {
        throw SaleException(
          'Integrated card payment requires terminal approval.',
        );
      }

      paidTotal += payment.amount;
      explicitChangeTotal += changeGiven;
    }

    final remaining = quote.grandTotal - paidTotal;
    if (remaining > 0 && !allowCustomerCredit) {
      throw SaleException(
        'Payment of ${paidTotal.toStringAsFixed(2)} is insufficient for total ${quote.grandTotal.toStringAsFixed(2)}',
      );
    }

    final overpayment = paidTotal > quote.grandTotal
        ? paidTotal - quote.grandTotal
        : 0.0;
    if ((overpayment > 0 || explicitChangeTotal > 0) &&
        !hasChangeCapablePayment) {
      throw SaleException('Overpayment requires a cash payment for change.');
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

/// Full sale detail with lines and payments.
class SaleDetail {
  final Sale sale;
  final List<SaleLine> items;
  final List<SalePayment> payments;

  const SaleDetail({
    required this.sale,
    required this.items,
    required this.payments,
  });
}

/// Input for an invoice-level discount.
class SaleDiscountInput {
  final DiscountType type;
  final double value;
  final String? reason;
  final String? approvedBy;

  const SaleDiscountInput({
    required this.type,
    required this.value,
    this.reason,
    this.approvedBy,
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

String _priceSourceForLine(SaleLineInput input) {
  if (input.isPriceOverridden) return PriceSource.manualOverride.code;
  return input.priceSource;
}

/// Sale-specific exception.
class SaleException extends BusinessException {
  const SaleException(super.message) : super(code: 'sale_error');
}

final salesServiceProvider = Provider<SalesService>((ref) {
  return SalesService(
    salesDao: ref.watch(salesDaoProvider),
    shiftDao: ref.watch(shiftDaoProvider),
    auditDao: ref.watch(auditDaoProvider),
    permissions: ref.watch(permissionServiceProvider),
    config: ref.watch(posConfigProvider),
    activeSession: ref.watch(activePosSessionProvider).valueOrNull,
    invoiceNumberService: ref.watch(invoiceNumberServiceProvider),
    clock: ref.watch(clockProvider),
  );
});
