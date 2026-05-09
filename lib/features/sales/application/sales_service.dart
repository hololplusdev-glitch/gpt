// features/sales/application/sales_service.dart
// WHY: Non-checkout sales support only: held orders, void, and history.
// Sale completion is owned exclusively by SaleCheckout.
//
// TODO(Phase:DecimalQty): Support fractional quantities when item.use_qty_fraction=1.
// Currently quantity is int-only throughout SaleLineInput.

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_flutter/core/errors/app_exception.dart';
import 'package:pos_flutter/core/persistence/daos/active_pos_session_dao.dart';
import 'package:pos_flutter/core/persistence/daos/audit_dao.dart';
import 'package:pos_flutter/core/persistence/daos/sales_dao.dart';
import 'package:pos_flutter/core/persistence/database.dart';
import 'package:pos_flutter/core/persistence/pos_config_repository.dart';
import 'package:pos_flutter/core/services/pricing/pricing_engine.dart';
import 'package:pos_flutter/core/services/time/clock.dart';
import 'package:pos_flutter/core/services/sync/upload_queue.dart';
import 'package:pos_flutter/features/sales/domain/models/sale_inputs.dart';
import 'package:pos_flutter/shared/models/enums.dart';
import 'package:pos_flutter/shared/models/sales_history.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';
import 'package:uuid/uuid.dart';

/// Non-checkout sales support: held orders, void, and history.
class SalesService {
  final SalesDao _salesDao;
  final AuditDao _auditDao;
  final PosConfigRepository _config;
  final UploadQueue _uploadQueue;
  final ActivePosSession? _activeSession;
  final PricingEngine _pricingEngine;
  final Clock _clock;

  SalesService({
    required SalesDao salesDao,
    required AuditDao auditDao,
    required PosConfigRepository config,
    required UploadQueue uploadQueue,
    required ActivePosSession? activeSession,
    PricingEngine pricingEngine = const PricingEngine(),
    Clock clock = const SystemClock(),
  }) : _salesDao = salesDao,
       _auditDao = auditDao,
       _config = config,
       _uploadQueue = uploadQueue,
       _activeSession = activeSession,
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
        priceIncludesTax: _requireActiveSession().priceIncludesTax,
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
        custCode: Value(activeSession.custCode),
        branchNo: Value(activeSession.activeBranchNo),
        branchYear: Value(activeSession.activeBranchYear),
        machineNo: Value(activeSession.activeMachineNo),
        storeId: Value(activeSession.activeStoreId),
        priceLevelId: Value(activeSession.activePriceLevelId),
        useTax: Value(activeSession.activeUseTax),
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

    final now = _clock.now();
    final outboxEntry = _uploadQueue.saleVoided(
      saleId: saleId,
      cashierId: activeSession.activeUserId,
      cashierName: activeSession.activeUserName,
      supervisorId: supervisorId,
      voidedAt: now,
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

/// Sale-specific exception.
class SaleException extends BusinessException {
  const SaleException(super.message) : super(code: 'sale_error');
}

final salesServiceProvider = Provider<SalesService>((ref) {
  return SalesService(
    salesDao: ref.watch(salesDaoProvider),
    auditDao: ref.watch(auditDaoProvider),
    config: ref.watch(posConfigProvider),
    uploadQueue: ref.watch(uploadQueueProvider),
    activeSession: ref.watch(activePosSessionProvider).valueOrNull,
    clock: ref.watch(clockProvider),
  );
});
