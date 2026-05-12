// features/shift/application/shift_service.dart
// WHY: Orchestrates the shift lifecycle — open, extend, close.
// Validates business rules, calculates totals, and queues sync events.

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/core/constants/pos_config_keys.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/persistence/daos/active_pos_session_dao.dart';
import 'package:holol_POS/core/persistence/daos/sales_dao.dart';
import 'package:holol_POS/core/persistence/daos/shift_dao.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/core/persistence/pos_config_repository.dart';
import 'package:holol_POS/core/services/time/clock.dart';
import 'package:holol_POS/core/services/sync/upload_queue.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
import 'package:uuid/uuid.dart';

/// Business logic for the entire shift lifecycle.
class ShiftService {
  final ShiftDao _shiftDao;
  final SalesDao _salesDao;
  final PosConfigRepository _config;
  final UploadQueue _uploadQueue;
  final Clock _clock;

  ShiftService({
    required ShiftDao shiftDao,
    required SalesDao salesDao,
    required PosConfigRepository config,
    required UploadQueue uploadQueue,
    Clock clock = const SystemClock(),
  }) : _shiftDao = shiftDao,
       _salesDao = salesDao,
       _config = config,
       _uploadQueue = uploadQueue,
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
    if (openingCash < 0 || openingCash.isNaN) {
      throw const ShiftException('Opening cash cannot be negative.');
    }
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

    final outboxEntry = _uploadQueue.shiftOpened(
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
    if (actualCash < 0 || actualCash.isNaN) {
      throw const ShiftException('Actual cash cannot be negative.');
    }
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

    // Expected cash = opening + cash sales - cash returns.
    final expectedCash =
        shift.openingCash + totals.cashSales - totals.cashReturns;
    final difference = actualCash - expectedCash;

    final now = _clock.now();
    final outboxEntry = _uploadQueue.shiftClosed(
      localId: localId,
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
      cashReturns: totals.cashReturns,
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
    final shift = await _shiftDao.getById(localId);
    if (shift == null) throw ShiftException('Shift not found');

    final minutes = overrideMinutes ?? _config.shiftExtendMinutes;
    final currentExpiry = shift.expiresAt ?? _clock.now();
    final newExpiry = currentExpiry.add(Duration(minutes: minutes));

    final now = _clock.now();
    final outboxEntry = _uploadQueue.shiftExtended(
      localId: localId,
      extendedByMinutes: minutes,
      newExpiry: newExpiry,
      extendedAt: now,
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
  // Queries
  // ---------------------------------------------------------------------------

  /// Get current open shift for terminal.
  Future<Shift?> getCurrentShift(String machineNo, {String? cashierId}) async {
    return _shiftDao.getOpenShift(machineNo, cashierId: cashierId);
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
    config: ref.watch(posConfigProvider),
    uploadQueue: ref.watch(uploadQueueProvider),
    clock: ref.watch(clockProvider),
  );
});
