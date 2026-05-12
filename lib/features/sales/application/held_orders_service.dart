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

/// Held-order owner only.
/// Held orders are intentionally stored as JSON snapshots in HeldOrders.snapshotJson.
/// Final sale totals are recalculated by SaleCheckout.
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
    final shift = await _requireOpenShift(session);
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
    final session = _requireActiveSession();
    final shift = await _requireOpenShift(session);
    final shiftId = shift.id;

    final orders = await _salesDao.getActiveHeldOrders(shiftId);
    final order = orders.where((o) => o.id == orderId).firstOrNull;

    if (order == null) {
      throw const SaleException('Held order not found or already resumed.');
    }

    final resumeResult = await _rehydrateHeldOrder(order, session);

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
    final session = _requireActiveSession();
    final shift = await _requireOpenShift(session);
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
    final session = _requireActiveSession();
    final shift = await _requireOpenShift(session);
    return _salesDao.getActiveHeldOrders(shift.id);
  }

  Future<List<HeldOrder>> getHeldOrders(String shiftId) {
    return _salesDao.getActiveHeldOrders(shiftId);
  }

  Future<HeldOrderResumeResult> _rehydrateHeldOrder(
    HeldOrder order,
    ActivePosSession session,
  ) async {
    final snapshotItems = _snapshotItemsFromJson(order.snapshotJson);
    if (snapshotItems.isEmpty) {
      throw const SaleException('Held order snapshot is empty.');
    }

    final lines = <SaleLineInput>[];
    final warnings = <String>[];

    for (final snapshot in snapshotItems) {
      final itemId = _requiredText(snapshot['itemId'], 'itemId');
      final unitId = _requiredText(snapshot['unitId'], 'unitId');
      final quantity = _double(snapshot['quantity'], fallback: 1.0);
      final oldUnitPrice = _nullableDouble(snapshot['unitPrice']);
      final oldTaxRate = _nullableDouble(snapshot['taxRate']);
      final oldUnitName = _text(snapshot['unitName']);
      final itemName = _text(snapshot['itemName']) ?? itemId;

      final item = await _catalogDao.getItemById(itemId);
      if (item == null || item.inactive || item.noSale) {
        throw SaleException('الصنف $itemName لم يعد قابلًا للبيع.');
      }

      final price = await _catalogDao.resolveItemPrice(
        itemId: itemId,
        unitId: unitId,
        priceLevelId: session.activePriceLevelId,
        storeId: session.activeStoreId,
      );

      if (price == null) {
        throw SaleException('لا يوجد سعر حالي للصنف $itemName.');
      }

      final sellable = _catalogDao.toSellableItemSnapshot(
        item: item,
        price: price,
        fallbackUnitId: unitId,
        fallbackUnitName: oldUnitName,
        barcode: _text(snapshot['barcode']),
      );

      final discountType = DiscountType.fromCode(
        _text(snapshot['discountType']),
      );
      final discountValue = _nullableDouble(snapshot['discountValue']);
      final discountAmount = _pricingEngine.calculateDiscountAmount(
        grossAmount: PricingEngine.roundAmount(sellable.unitPrice * quantity),
        discountType: discountType,
        discountValue: discountValue,
        allowDiscount: sellable.allowDiscount,
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

      lines.add(
        SaleLineInput(
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
          discountAmount: discountAmount,
          allowDiscount: sellable.allowDiscount,
          notes: _text(snapshot['notes']),
        ),
      );
    }

    return HeldOrderResumeResult(lines: lines, warnings: warnings);
  }

  List<Map<String, dynamic>> _snapshotItemsFromJson(String snapshotJson) {
    final decoded = jsonDecode(snapshotJson);

    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }

    if (decoded is Map<String, dynamic>) {
      final items = decoded['items'];
      if (items is List) {
        return items.cast<Map<String, dynamic>>();
      }
    }

    throw const SaleException('Invalid held order snapshot.');
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

  Future<Shift> _requireOpenShift(ActivePosSession session) async {
    final shift = await _shiftDao.getOpenShift(
      session.activeMachineNo,
      cashierId: session.activeUserId,
    );

    if (shift == null || shift.status != ShiftStatus.open.code) {
      throw const SaleException('Open a shift before holding orders.');
    }

    return shift;
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

class HeldOrderResumeResult {
  final List<SaleLineInput> lines;
  final List<String> warnings;

  const HeldOrderResumeResult({required this.lines, this.warnings = const []});
}

String _requiredText(Object? value, String fieldName) {
  final text = _text(value);
  if (text == null || text.isEmpty) {
    throw SaleException('Held order snapshot is missing $fieldName.');
  }
  return text;
}

String? _text(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
    return null;
  }
  return text;
}

double _double(Object? value, {double fallback = 0.0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

double? _nullableDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
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
