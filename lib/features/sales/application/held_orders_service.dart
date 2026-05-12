import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/persistence/daos/active_pos_session_dao.dart';
import 'package:holol_POS/core/persistence/daos/audit_dao.dart';
import 'package:holol_POS/core/persistence/daos/sales_dao.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/core/persistence/pos_config_repository.dart';
import 'package:holol_POS/core/services/pricing/pricing_engine.dart';
import 'package:holol_POS/core/services/time/clock.dart';
import 'package:holol_POS/features/sales/domain/models/sale_inputs.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
import 'package:uuid/uuid.dart';

/// Held-order owner only.
/// Held-order totals are UI/preview values.
/// Final sale totals are recalculated by SaleCheckout from exact ITEM_PRICE.
class HeldOrdersService {
  final SalesDao _salesDao;
  final AuditDao _auditDao;
  final PosConfigRepository _config;
  final ActivePosSession? _activeSession;
  final PricingEngine _pricingEngine;
  final Clock _clock;

  HeldOrdersService({
    required SalesDao salesDao,
    required AuditDao auditDao,
    required PosConfigRepository config,
    required ActivePosSession? activeSession,
    PricingEngine pricingEngine = const PricingEngine(),
    Clock clock = const SystemClock(),
  }) : _salesDao = salesDao,
       _auditDao = auditDao,
       _config = config,
       _activeSession = activeSession,
       _pricingEngine = pricingEngine,
       _clock = clock;

  static const _uuid = Uuid();

  CheckoutQuote previewQuote({
    required List<SaleLineInput> lineItems,
  }) {
    final session = _requireActiveSession();

    try {
      return _pricingEngine.calculateQuote(
        lines: lineItems.toPricingLineInputs(),
        taxRate: 0,
        useTax: session.activeUseTax,
        priceIncludesTax: session.priceIncludesTax,
      );
    } on PricingException catch (e) {
      throw SaleException(e.message);
    }
  }

  Future<String> holdOrder({
    required List<SaleLineInput> items,
    String? customerId,
    String? customerName,
    String? referenceName,
    String? notes,
  }) async {
    final session = _requireActiveSession();
    final shiftId = _requireOpenShiftId(session);

    if (!_config.useHeldInvoices) {
      throw const SaleException(
        'Held orders are disabled by POS configuration.',
      );
    }

    final currentCount = await _salesDao.countActiveHeldOrders(shiftId);
    if (currentCount >= _config.maxHeldInvoices) {
      throw SaleException(
        'Maximum held orders (${_config.maxHeldInvoices}) reached.',
      );
    }

    _validatePreviewInputs(lineItems: items);

    final quote = previewQuote(lineItems: items);
    final id = 'HLD_${_uuid.v4()}';
    final now = _clock.now();

    final snapshotJson = jsonEncode({
      'version': 1,
      'type': 'cart_snapshot',
      'createdAt': now.toIso8601String(),
      'createdBy': session.activeUserId,
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

    await _auditDao.log(
      id: 'AUD_${_uuid.v4()}',
      action: AuditAction.orderHeld,
      actorId: session.activeUserId,
      targetType: OutboxEntityType.heldOrder.code,
      targetId: id,
      terminalId: session.activeMachineNo,
    );

    return id;
  }

  Future<String> resumeHeldOrder({required String orderId}) async {
    final session = _requireActiveSession();
    final shiftId = _requireOpenShiftId(session);

    final orders = await _salesDao.getActiveHeldOrders(shiftId);
    final order = orders.where((o) => o.id == orderId).firstOrNull;

    if (order == null) {
      throw const SaleException('Held order not found or already resumed.');
    }

    await _salesDao.resumeHeldOrder(orderId, _clock.now());

    await _auditDao.log(
      id: 'AUD_${_uuid.v4()}',
      action: AuditAction.orderRecalled,
      actorId: session.activeUserId,
      targetType: OutboxEntityType.heldOrder.code,
      targetId: orderId,
      terminalId: session.activeMachineNo,
    );

    return order.snapshotJson;
  }

  Future<void> cancelHeldOrder({required String orderId}) async {
    final session = _requireActiveSession();

    await _salesDao.cancelHeldOrder(orderId);

    await _auditDao.log(
      id: 'AUD_${_uuid.v4()}',
      action: AuditAction.orderCancelled,
      actorId: session.activeUserId,
      targetType: OutboxEntityType.heldOrder.code,
      targetId: orderId,
      terminalId: session.activeMachineNo,
    );
  }

  Future<List<HeldOrder>> getCurrentHeldOrders() {
    final session = _requireActiveSession();
    final shiftId = _requireOpenShiftId(session);
    return _salesDao.getActiveHeldOrders(shiftId);
  }

  Future<List<HeldOrder>> getHeldOrders(String shiftId) {
    return _salesDao.getActiveHeldOrders(shiftId);
  }

  void _validatePreviewInputs({required List<SaleLineInput> lineItems}) {
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

  String _requireOpenShiftId(ActivePosSession session) {
    final shiftId = session.openShiftId?.trim();
    if (shiftId == null || shiftId.isEmpty) {
      throw const SaleException('Open a shift before holding orders.');
    }
    return shiftId;
  }

  ActivePosSession _requireActiveSession() {
    final session = _activeSession;
    if (session == null) {
      throw const SaleException(
        'Select a cashier and POS machine before selling.',
      );
    }
    return session;
  }
}


class SaleException extends BusinessException {
  const SaleException(super.message) : super(code: 'sale_error');
}

final heldOrdersServiceProvider = Provider<HeldOrdersService>((ref) {
  return HeldOrdersService(
    salesDao: ref.watch(salesDaoProvider),
    auditDao: ref.watch(auditDaoProvider),
    config: ref.watch(posConfigProvider),
    activeSession: ref.watch(activePosSessionProvider).valueOrNull,
    clock: ref.watch(clockProvider),
  );
});
