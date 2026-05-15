// features/shift/application/shift_controller.dart
// WHY: Shift command controller + shift dashboard projection.
// Runtime SSOT is the Shifts table.
// Shift is mandatory. Router must only check open shift existence, not dashboard
// totals.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/persistence/daos/active_pos_session_dao.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/features/shift/application/shift_service.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
import 'package:holol_POS/shared/refactor/pos_business_rules.dart';
import 'package:holol_POS/shared/refactor/pos_runtime_state.dart';

typedef ActiveSessionReader = ActivePosSession? Function();

class ShiftCommandState {
  final bool isLoading;
  final String? errorMessage;

  const ShiftCommandState({this.isLoading = false, this.errorMessage});

  ShiftCommandState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ShiftCommandState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ShiftCommandResult {
  final bool success;
  final String? errorMessage;

  const ShiftCommandResult._({required this.success, this.errorMessage});

  const ShiftCommandResult.success() : this._(success: true);

  const ShiftCommandResult.failure(String message)
    : this._(success: false, errorMessage: message);
}

class ShiftDashboard {
  final Shift shift;
  final ShiftSalesTotals totals;

  const ShiftDashboard({required this.shift, required this.totals});

  double get expectedCash => PosShiftTotalsRules.expectedCash(
    openingCash: shift.openingCash,
    totals: totals,
  );
}

/// Lightweight open-shift projection.
/// Use this for routing and guards only.
final activeShiftProvider = FutureProvider.autoDispose<Shift?>((ref) async {
  final session = ref.watch(activePosSessionProvider).valueOrNull;

  if (session == null) {
    return null;
  }

  final shiftDao = ref.watch(shiftDaoProvider);

  return shiftDao.getOpenShift(
    session.activeMachineNo,
    cashierId: session.activeUserId,
  );
});

/// Heavy dashboard projection.
/// Use this only for the shift screen.
final activeShiftDashboardProvider =
    FutureProvider.autoDispose<ShiftDashboard?>((ref) async {
      final shift = await ref.watch(activeShiftProvider.future);

      if (shift == null) {
        return null;
      }

      final salesDao = ref.watch(salesDaoProvider);
      final sales = await salesDao.getSalesForShift(shift.id);
      final payments = await salesDao.getSalePaymentsForSales(
        sales.map((sale) => sale.id),
      );

      final totals = PosShiftTotalsRules.calculate(
        sales: sales,
        payments: payments,
      );

      return ShiftDashboard(shift: shift, totals: totals);
    });

class ShiftController extends StateNotifier<ShiftCommandState> {
  final ShiftService _shiftService;
  final ActiveSessionReader _readSession;
  final Future<void> Function() _refreshShiftState;

  ShiftController(
    this._shiftService,
    this._readSession,
    this._refreshShiftState,
  ) : super(const ShiftCommandState());

  Future<ShiftCommandResult> openShift({
    required double openingCash,
    String? shiftTypeId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _shiftService.openShift(
        session: PosBusinessGuards.requireActiveSession(
          _readSession(),
          message: 'Select a cashier and POS machine before shift operations.',
          code: 'NO_ACTIVE_POS_SESSION',
        ),
        openingCash: openingCash,
        shiftTypeId: shiftTypeId,
      );

      await _refreshShiftState();

      state = const ShiftCommandState();

      return const ShiftCommandResult.success();
    } on ShiftException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);

      return ShiftCommandResult.failure(e.message);
    } catch (e) {
      final message = PosRuntimeErrorText.commandMessage(e);

      state = state.copyWith(isLoading: false, errorMessage: message);

      return ShiftCommandResult.failure(message);
    }
  }

  Future<ShiftCommandResult> closeShift({
    required String shiftId,
    required double actualCash,
    String? closingNotes,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _shiftService.closeShift(
        session: PosBusinessGuards.requireActiveSession(
          _readSession(),
          message: 'Select a cashier and POS machine before shift operations.',
          code: 'NO_ACTIVE_POS_SESSION',
        ),
        localId: shiftId,
        actualCash: actualCash,
        closingNotes: closingNotes,
      );

      await _refreshShiftState();

      state = const ShiftCommandState();

      return const ShiftCommandResult.success();
    } on ShiftException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);

      return ShiftCommandResult.failure(e.message);
    } catch (e) {
      final message = PosRuntimeErrorText.commandMessage(e);

      state = state.copyWith(isLoading: false, errorMessage: message);

      return ShiftCommandResult.failure(message);
    }
  }

  Future<ShiftCommandResult> extendShift({
    required String shiftId,
    int? overrideMinutes,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _shiftService.extendShift(
        session: PosBusinessGuards.requireActiveSession(
          _readSession(),
          message: 'Select a cashier and POS machine before shift operations.',
          code: 'NO_ACTIVE_POS_SESSION',
        ),
        localId: shiftId,
        overrideMinutes: overrideMinutes,
      );

      await _refreshShiftState();

      state = const ShiftCommandState();

      return const ShiftCommandResult.success();
    } catch (e) {
      final message = PosRuntimeErrorText.commandMessage(e);

      state = state.copyWith(isLoading: false, errorMessage: message);

      return ShiftCommandResult.failure(message);
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void setError(String message) {
    state = state.copyWith(isLoading: false, errorMessage: message);
  }
}

final shiftControllerProvider =
    StateNotifierProvider<ShiftController, ShiftCommandState>((ref) {
      return ShiftController(
        ref.watch(shiftServiceProvider),
        () => ref.read(activePosSessionProvider).valueOrNull,
        () async {
          ref.invalidate(activeShiftProvider);
          ref.invalidate(activeShiftDashboardProvider);
        },
      );
    });
