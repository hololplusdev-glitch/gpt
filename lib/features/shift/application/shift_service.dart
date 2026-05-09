// features/shift/application/shift_service.dart
// WHY: Orchestrates the shift lifecycle — open, extend, close.
// Validates business rules, calculates totals, and queues sync events.

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_flutter/core/errors/app_exception.dart';
import 'package:pos_flutter/core/persistence/daos/sales_dao.dart';
import 'package:pos_flutter/core/persistence/daos/shift_dao.dart';
import 'package:pos_flutter/core/persistence/database.dart';
import 'package:pos_flutter/core/persistence/pos_config_repository.dart';
import 'package:pos_flutter/core/services/permission_service.dart';
import 'package:pos_flutter/core/services/time/clock.dart';
import 'package:pos_flutter/shared/models/enums.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';
import 'package:uuid/uuid.dart';

/// Business logic for the entire shift lifecycle.
class ShiftService {
  final ShiftDao _shiftDao;
  final SalesDao _salesDao;
  final PermissionService _permissions;
  final PosConfigRepository _config;
  final Clock _clock;

  ShiftService({
    required ShiftDao shiftDao,
    required SalesDao salesDao,
    required PermissionService permissions,
    required PosConfigRepository config,
    Clock clock = const SystemClock(),
  }) : _shiftDao = shiftDao,
       _salesDao = salesDao,
       _permissions = permissions,
       _config = config,
       _clock = clock;

  static const _uuid = Uuid();

  // ---------------------------------------------------------------------------
  // Open Shift
  // ---------------------------------------------------------------------------

  Future<Shift> openShift({
    required ActivePosSession session,
    required double openingCash,
    String? shiftTypeId,
  }) async {
    // Validate permission
    await _permissions.requirePermission(
      userId: session.activeUserId,
      terminalId: session.activeMachineNo,
      permission: PermissionCode.shiftOpen,
    );

    // Check no open shift exists for this terminal
    final existing = await _shiftDao.getOpenShift(session.activeMachineNo);
    if (existing != null) {
      throw ShiftException(
        'A shift is already open on this terminal (${existing.id})',
      );
    }

    final localId = 'SH_${_uuid.v4()}';
    final now = _clock.now();
    final idempotencyKey = 'shift_open_$localId';
    final defaultDuration = _config.getInt(
      'shift_default_duration_minutes',
      fallback: 480,
    );
    final expiresAt = now.add(Duration(minutes: defaultDuration));

    final shiftEntry = ShiftsCompanion.insert(
      id: localId,
      custCode: Value(session.custCode),
      branchNo: Value(session.activeBranchNo),
      branchYear: Value(session.activeBranchYear),
      machineNo: Value(session.activeMachineNo),
      storeId: Value(session.activeStoreId),
      priceLevelId: Value(session.activePriceLevelId),
      cashierId: session.activeUserId,
      shiftTypeId: Value(shiftTypeId),
      openingCash: openingCash,
      status: ShiftStatus.open.code,
      syncStatus: OutboxStatus.pending.code,
      openedAt: now,
      expiresAt: Value(expiresAt),
      idempotencyKey: idempotencyKey,
    );

    final outboxEntry = OutboxEventsCompanion.insert(
      id: 'OBX_${_uuid.v4()}',
      eventType: OutboxEventType.shiftOpened.code,
      entityType: OutboxEntityType.shift.code,
      entityId: localId,
      payloadJson: jsonEncode({
        'localId': localId,
        'machineNo': session.activeMachineNo,
        'cashierId': session.activeUserId,
        'cashierName': session.activeUserName,
        'openingCash': openingCash,
        'openedAt': now.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      }),
      status: OutboxStatus.pending.code,
      createdAt: now,
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

    await _shiftDao.createShiftEnvelope(
      shift: shiftEntry,
      outboxEntry: outboxEntry,
      auditLogEntry: auditLogEntry,
    );

    return (await _shiftDao.getById(localId))!;
  }

  // ---------------------------------------------------------------------------
  // Close Shift
  // ---------------------------------------------------------------------------

  Future<void> closeShift({
    required ActivePosSession session,
    required String localId,
    required double actualCash,
    String? closingNotes,
  }) async {
    // Validate permission
    await _permissions.requirePermission(
      userId: session.activeUserId,
      terminalId: session.activeMachineNo,
      permission: PermissionCode.shiftClose,
    );

    // Check shift exists and is open
    final shift = await _shiftDao.getById(localId);
    if (shift == null) throw ShiftException('Shift not found: $localId');
    final isOpen =
        shift.status == ShiftStatus.open.code ||
        shift.status == ShiftStatus.closing.code;
    if (!isOpen) {
      throw ShiftException('Shift is not open');
    }

    // Check held orders
    if (_config.blockShiftCloseWithHeldInvoices) {
      final heldCount = await _salesDao.countActiveHeldOrders(localId);
      if (heldCount > 0) {
        throw ShiftException(
          'Cannot close shift: $heldCount held order(s) remain. Complete or cancel them first.',
        );
      }
    }

    // Calculate shift totals from sales
    final totals = await _salesDao.getShiftSalesTotals(localId);

    // Calculate cash movements
    final movements = await _shiftDao.getCashMovementTotals(localId);

    // Expected cash = opening + cash_sales + cash_in - cash_out - cash_refunds
    final expectedCash =
        shift.openingCash +
        totals.cashSales +
        movements.cashIn -
        movements.cashOut -
        movements.cashRefund;
    final difference = actualCash - expectedCash;

    final now = _clock.now();
    final outboxEntry = OutboxEventsCompanion.insert(
      id: 'OBX_${_uuid.v4()}',
      eventType: OutboxEventType.shiftClosed.code,
      entityType: OutboxEntityType.shift.code,
      entityId: localId,
      payloadJson: jsonEncode({
        'localId': localId,
        'machineNo': session.activeMachineNo,
        'cashierId': session.activeUserId,
        'cashierName': session.activeUserName,
        'expectedCash': expectedCash,
        'actualCash': actualCash,
        'difference': difference,
        'grossSales': totals.grossSales,
        'netSales': totals.netSales,
        'cashSales': totals.cashSales,
        'cardSales': totals.cardSales,
        'otherSales': totals.otherSales,
        'totalDiscounts': totals.totalDiscounts,
        'totalTaxes': totals.totalTaxes,
        'totalReturns': totals.totalReturns,
        'totalVoids': totals.totalVoids,
        'saleCount': totals.saleCount,
        'closedAt': now.toIso8601String(),
      }),
      status: OutboxStatus.pending.code,
      createdAt: now,
      idempotencyKey: 'shift_close_$localId',
    );

    final auditLogEntry = AuditLogCompanion.insert(
      id: 'AUD_${_uuid.v4()}',
      action: AuditAction.shiftClosed.code,
      actorId: session.activeUserId,
      actorName: Value(session.activeUserName),
      targetType: Value(OutboxEntityType.shift.code),
      targetId: Value(localId),
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

    await _shiftDao.closeShiftEnvelope(
      localId: localId,
      expectedCash: expectedCash,
      actualCash: actualCash,
      difference: difference,
      grossSales: totals.grossSales,
      netSales: totals.netSales,
      cashSales: totals.cashSales,
      cardSales: totals.cardSales,
      otherSales: totals.otherSales,
      totalDiscounts: totals.totalDiscounts,
      totalTaxes: totals.totalTaxes,
      totalReturns: totals.totalReturns,
      totalVoids: totals.totalVoids,
      saleCount: totals.saleCount,
      closingNotes: closingNotes,
      outboxEntry: outboxEntry,
      auditLogEntry: auditLogEntry,
    );
  }

  // ---------------------------------------------------------------------------
  // Extend Shift
  // ---------------------------------------------------------------------------

  Future<Shift> extendShift({
    required ActivePosSession session,
    required String localId,
    int? overrideMinutes,
  }) async {
    await _permissions.requirePermission(
      userId: session.activeUserId,
      terminalId: session.activeMachineNo,
      permission: PermissionCode.shiftExtend,
    );

    final shift = await _shiftDao.getById(localId);
    if (shift == null) throw ShiftException('Shift not found');

    final minutes = overrideMinutes ?? _config.shiftExtendMinutes;
    final currentExpiry = shift.expiresAt ?? _clock.now();
    final newExpiry = currentExpiry.add(Duration(minutes: minutes));

    final now = _clock.now();
    final outboxEntry = OutboxEventsCompanion.insert(
      id: 'OBX_${_uuid.v4()}',
      eventType: OutboxEventType.shiftExtended.code,
      entityType: OutboxEntityType.shift.code,
      entityId: localId,
      payloadJson: jsonEncode({
        'localId': localId,
        'extendedByMinutes': minutes,
        'newExpiry': newExpiry.toIso8601String(),
        'extendedAt': now.toIso8601String(),
      }),
      status: OutboxStatus.pending.code,
      createdAt: now,
      idempotencyKey: 'shift_extend_$localId',
    );

    final auditLogEntry = AuditLogCompanion.insert(
      id: 'AUD_${_uuid.v4()}',
      action: AuditAction.shiftExtended.code,
      actorId: session.activeUserId,
      targetType: Value(OutboxEntityType.shift.code),
      targetId: Value(localId),
      detailsJson: Value(jsonEncode({'extendedByMinutes': minutes})),
      terminalId: session.activeMachineNo,
      createdAt: now,
    );

    await _shiftDao.extendShiftEnvelope(
      localId: localId,
      newExpiry: newExpiry,
      outboxEntry: outboxEntry,
      auditLogEntry: auditLogEntry,
    );

    return (await _shiftDao.getById(localId))!;
  }

  // ---------------------------------------------------------------------------
  // Cash Movements
  // ---------------------------------------------------------------------------

  /// Record a cash in/out movement during the shift.
  Future<void> addCashMovement({
    required String shiftId,
    required CashMovementType type,
    required double amount,
    String? reason,
    String? approvedBy,
  }) async {
    await _shiftDao.addCashMovement(
      ShiftCashMovementsCompanion.insert(
        id: 'CM_${_uuid.v4()}',
        shiftId: shiftId,
        type: type.code,
        amount: amount,
        reason: Value(reason),
        approvedBy: Value(approvedBy),
        createdAt: _clock.now(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Get current open shift for terminal.
  Future<Shift?> getCurrentShift(String machineNo) async {
    return _shiftDao.getOpenShift(machineNo);
  }
}

/// Shift-specific exception.
class ShiftException extends BusinessException {
  const ShiftException(super.message) : super(code: 'shift_error');
}

final shiftServiceProvider = Provider<ShiftService>((ref) {
  return ShiftService(
    shiftDao: ref.watch(shiftDaoProvider),
    salesDao: ref.watch(salesDaoProvider),
    permissions: ref.watch(permissionServiceProvider),
    config: ref.watch(posConfigProvider),
    clock: ref.watch(clockProvider),
  );
});
