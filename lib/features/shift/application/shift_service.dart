// features/shift/application/shift_service.dart
// WHY: Orchestrates the shift lifecycle — open, extend, close.
// Validates business rules, calculates totals, and queues sync events.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/core/persistence/daos/active_pos_session_dao.dart';
import 'package:holol_POS/core/persistence/daos/sales_dao.dart';
import 'package:holol_POS/core/persistence/daos/shift_dao.dart';
import 'package:holol_POS/core/persistence/pos_config_repository.dart';
import 'package:holol_POS/core/services/time/clock.dart';
import 'package:holol_POS/core/services/sync/outbox_event_factory.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/shared/refactor/pos_business_rules.dart';

/// Business logic for the entire shift lifecycle.
class ShiftService {
  final ShiftDao _shiftDao;
  final SalesDao _salesDao;
  final PosConfigRepository _config;
  final OutboxEventFactory _outboxEventFactory;
  final Clock _clock;

  ShiftService({
    required ShiftDao shiftDao,
    required SalesDao salesDao,
    required PosConfigRepository config,
    required OutboxEventFactory outboxEventFactory,
    Clock clock = const SystemClock(),
  }) : _shiftDao = shiftDao,
       _salesDao = salesDao,
       _config = config,
       _outboxEventFactory = outboxEventFactory,
       _clock = clock;

  PosShiftWorkflow get _workflow => PosShiftWorkflow(
    shiftDao: _shiftDao,
    salesDao: _salesDao,
    config: _config,
    outboxEventFactory: _outboxEventFactory,
    clock: _clock,
  );

  // ---------------------------------------------------------------------------
  // Open Shift
  // ---------------------------------------------------------------------------

  Future<Shift> openShift({
    required ActivePosSession session,
    required double openingCash,
    String? shiftTypeId,
  }) {
    return _workflow.openShift(
      session: session,
      openingCash: openingCash,
      shiftTypeId: shiftTypeId,
    );
  }

  // ---------------------------------------------------------------------------
  // Close Shift
  // ---------------------------------------------------------------------------

  Future<void> closeShift({
    required ActivePosSession session,
    required String localId,
    required double actualCash,
    String? closingNotes,
  }) {
    return _workflow.closeShift(
      session: session,
      localId: localId,
      actualCash: actualCash,
      closingNotes: closingNotes,
    );
  }

  // ---------------------------------------------------------------------------
  // Extend Shift
  // ---------------------------------------------------------------------------

  Future<Shift> extendShift({
    required ActivePosSession session,
    required String localId,
    int? overrideMinutes,
  }) {
    return _workflow.extendShift(
      session: session,
      localId: localId,
      overrideMinutes: overrideMinutes,
    );
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
final shiftServiceProvider = Provider<ShiftService>((ref) {
  return ShiftService(
    shiftDao: ref.watch(shiftDaoProvider),
    salesDao: ref.watch(salesDaoProvider),
    config: ref.watch(posConfigProvider),
    outboxEventFactory: ref.watch(outboxEventFactoryProvider),
    clock: ref.watch(clockProvider),
  );
});
