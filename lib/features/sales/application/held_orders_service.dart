import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/persistence/daos/active_pos_session_dao.dart';
import 'package:holol_POS/core/persistence/daos/audit_dao.dart';
import 'package:holol_POS/core/persistence/daos/catalog_dao.dart';
import 'package:holol_POS/core/persistence/daos/sales_dao.dart';
import 'package:holol_POS/core/persistence/daos/shift_dao.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/core/persistence/pos_config_repository.dart';
import 'package:holol_POS/core/services/pricing/pricing_engine.dart';
import 'package:holol_POS/core/services/time/clock.dart';
import 'package:holol_POS/features/sales/domain/models/sale_inputs.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
import 'package:uuid/uuid.dart';
import 'package:holol_POS/shared/refactor/pos_business_rules.dart';

/// Held-order owner only.
/// Held orders are stored as cart intent snapshots.
/// Final prices/totals are always recalculated by PricingEngine and SaleCheckout.
class HeldOrdersService {
  final SalesDao _salesDao;
  final ShiftDao _shiftDao;
  final AuditDao _auditDao;
  final CatalogDao _catalogDao;
  final PosConfigRepository _config;
  final ActivePosSession? _activeSession;
  final PricingEngine _pricingEngine;
  final Clock _clock;

  HeldOrdersService({
    required SalesDao salesDao,
    required ShiftDao shiftDao,
    required AuditDao auditDao,
    required CatalogDao catalogDao,
    required PosConfigRepository config,
    required ActivePosSession? activeSession,
    PricingEngine pricingEngine = const PricingEngine(),
    Clock clock = const SystemClock(),
  }) : _salesDao = salesDao,
       _shiftDao = shiftDao,
       _auditDao = auditDao,
       _catalogDao = catalogDao,
       _config = config,
       _activeSession = activeSession,
       _pricingEngine = pricingEngine,
       _clock = clock;

  static const _uuid = Uuid();
CheckoutQuote previewQuote({required List<SaleLineInput> lineItems}) {
    final session = PosBusinessGuards.requireActiveSession(
      _activeSession,
      message: 'Select a cashier and POS machine before selling.',
      exceptionFactory: SaleException.new,
    );
    SaleLineValidator.validateSaleLines(
      lineItems,
      exceptionFactory: SaleException.new,
      validatePricing: true,
      pricingEngine: _pricingEngine,
      priceIncludesTax: false,
    );
    return PosSaleQuoteRules.quote(
      pricingEngine: _pricingEngine,
      lines: lineItems,
      useTax: session.activeUseTax,
      priceIncludesTax: session.priceIncludesTax,
      exceptionFactory: SaleException.new,
    );
  }

Future<String> holdOrder({
    required List<SaleLineInput> items,
    String? customerId,
    String? customerName,
    String? referenceName,
    String? notes,
  }) async {
    final session = PosBusinessGuards.requireActiveSession(
      _activeSession,
      message: 'Select a cashier and POS machine before selling.',
      exceptionFactory: SaleException.new,
    );
    final shift = await PosBusinessGuards.requireOpenShift(
      shiftDao: _shiftDao,
      session: session,
      message: 'Open a shift before holding orders.',
      exceptionFactory: SaleException.new,
    );
    final shiftId = shift.id;

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

    SaleLineValidator.validateSaleLines(
      items,
      exceptionFactory: SaleException.new,
      validatePricing: true,
      pricingEngine: _pricingEngine,
      priceIncludesTax: false,
    );

    final quote = previewQuote(lineItems: items);
    final id = 'HLD_${_uuid.v4()}';
    final now = _clock.now();

    final snapshotJson = jsonEncode({
      'version': 1,
      'type': 'cart_intent_snapshot',
      'createdAt': now.toIso8601String(),
      'createdBy': session.activeUserId,
      'items': items.map((line) => line.toHeldOrderSnapshotJson()).toList(),
    });

    await _salesDao.holdOrder(
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

  Future<HeldOrderResumeResult> resumeHeldOrder({
    required String orderId,
  }) async {
    final session = PosBusinessGuards.requireActiveSession(
      _activeSession,
      message: 'Select a cashier and POS machine before selling.',
      exceptionFactory: SaleException.new,
    );
    final shift = await PosBusinessGuards.requireOpenShift(
      shiftDao: _shiftDao,
      session: session,
      message: 'Open a shift before holding orders.',
      exceptionFactory: SaleException.new,
    );
    final shiftId = shift.id;

    final orders = await _salesDao.getActiveHeldOrders(shiftId);
    final order = orders.where((o) => o.id == orderId).firstOrNull;

    if (order == null) {
      throw const SaleException('Held order not found or already resumed.');
    }

    final resumeData = await PosHeldOrderRehydrator(
      catalogDao: _catalogDao,
      pricingEngine: _pricingEngine,
      exceptionFactory: SaleException.new,
    ).rehydrate(
      order: order,
      session: session,
    );
    final resumeResult = HeldOrderResumeResult(
      lines: resumeData.lines,
      warnings: resumeData.warnings,
    );

    final now = _clock.now();
    final auditLogEntry = AuditLogCompanion.insert(
      id: 'AUD_${_uuid.v4()}',
      action: AuditAction.orderRecalled.code,
      actorId: session.activeUserId,
      targetType: Value(OutboxEntityType.heldOrder.code),
      targetId: Value(orderId),
      terminalId: session.activeMachineNo,
      createdAt: now,
    );

    final updated = await _salesDao.resumeHeldOrderEnvelope(
      orderId: orderId,
      shiftId: shiftId,
      now: now,
      auditLogEntry: auditLogEntry,
    );

    if (!updated) {
      throw const SaleException('Held order was already changed.');
    }

    return resumeResult;
  }

  Future<void> cancelHeldOrder({required String orderId}) async {
    final session = PosBusinessGuards.requireActiveSession(
      _activeSession,
      message: 'Select a cashier and POS machine before selling.',
      exceptionFactory: SaleException.new,
    );
    final shift = await PosBusinessGuards.requireOpenShift(
      shiftDao: _shiftDao,
      session: session,
      message: 'Open a shift before holding orders.',
      exceptionFactory: SaleException.new,
    );
    final shiftId = shift.id;
    final now = _clock.now();

    final auditLogEntry = AuditLogCompanion.insert(
      id: 'AUD_${_uuid.v4()}',
      action: AuditAction.orderCancelled.code,
      actorId: session.activeUserId,
      targetType: Value(OutboxEntityType.heldOrder.code),
      targetId: Value(orderId),
      terminalId: session.activeMachineNo,
      createdAt: now,
    );

    final updated = await _salesDao.cancelHeldOrderEnvelope(
      orderId: orderId,
      shiftId: shiftId,
      auditLogEntry: auditLogEntry,
    );

    if (!updated) {
      throw const SaleException('Held order not found or already changed.');
    }
  }

  Future<List<HeldOrder>> getCurrentHeldOrders() async {
    final session = PosBusinessGuards.requireActiveSession(
      _activeSession,
      message: 'Select a cashier and POS machine before selling.',
      exceptionFactory: SaleException.new,
    );
    final shift = await PosBusinessGuards.requireOpenShift(
      shiftDao: _shiftDao,
      session: session,
      message: 'Open a shift before holding orders.',
      exceptionFactory: SaleException.new,
    );
    return _salesDao.getActiveHeldOrders(shift.id);
  }

  Future<List<HeldOrder>> getHeldOrders(String shiftId) {
    return _salesDao.getActiveHeldOrders(shiftId);
  }
}

class HeldOrderResumeResult {
  final List<SaleLineInput> lines;
  final List<String> warnings;

  const HeldOrderResumeResult({required this.lines, this.warnings = const []});
}


class SaleException extends BusinessException {
  const SaleException(super.message) : super(code: 'sale_error');
}

final heldOrdersServiceProvider = Provider<HeldOrdersService>((ref) {
  return HeldOrdersService(
    salesDao: ref.watch(salesDaoProvider),
    shiftDao: ref.watch(shiftDaoProvider),
    auditDao: ref.watch(auditDaoProvider),
    catalogDao: ref.watch(catalogDaoProvider),
    config: ref.watch(posConfigProvider),
    activeSession: ref.watch(activePosSessionProvider).valueOrNull,
    clock: ref.watch(clockProvider),
  );
});
