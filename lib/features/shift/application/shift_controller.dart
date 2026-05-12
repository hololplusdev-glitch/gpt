// features/shift/application/shift_controller.dart
// WHY: Shift command controller + shift dashboard projection.
// Runtime SSOT is the Shifts table.
// Shift is mandatory. Router must only check open shift existence, not dashboard
// totals.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/persistence/daos/active_pos_session_dao.dart';
import 'package:holol_POS/core/persistence/daos/sales_dao.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/features/shift/application/shift_service.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';

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
  final double cashIn;
  final double cashOut;
  final double cashRefund;

  const ShiftDashboard({
    required this.shift,
    required this.totals,
    required this.cashIn,
    required this.cashOut,
    required this.cashRefund,
  });

  double get expectedCash =>
      shift.openingCash + totals.cashSales + cashIn - cashOut - cashRefund;
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

      final shiftDao = ref.watch(shiftDaoProvider);
      final salesDao = ref.watch(salesDaoProvider);

      final totals = await salesDao.getShiftSalesTotals(shift.id);
      final movements = await shiftDao.getCashMovementTotals(shift.id);

      return ShiftDashboard(
        shift: shift,
        totals: totals,
        cashIn: movements.cashIn,
        cashOut: movements.cashOut,
        cashRefund: movements.cashRefund,
      );
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
        session: _requireSession(),
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
      final message = _commandErrorMessage(e);

      state = state.copyWith(isLoading: false, errorMessage: message);

      return ShiftCommandResult.failure(message);
    }
  }

  Future<ShiftCommandResult> closeShift({
    required String shiftId,
    required double actualCash,
    String? closingNotes,
  }) async {
    final normalizedShiftId = shiftId.trim();

    if (normalizedShiftId.isEmpty) {
      const message = 'No open shift to close.';

      state = state.copyWith(errorMessage: message);

      return const ShiftCommandResult.failure(message);
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _shiftService.closeShift(
        session: _requireSession(),
        localId: normalizedShiftId,
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
      final message = _commandErrorMessage(e);

      state = state.copyWith(isLoading: false, errorMessage: message);

      return ShiftCommandResult.failure(message);
    }
  }

  Future<ShiftCommandResult> extendShift({
    required String shiftId,
    int? overrideMinutes,
  }) async {
    final normalizedShiftId = shiftId.trim();

    if (normalizedShiftId.isEmpty) {
      return const ShiftCommandResult.failure('No open shift to extend.');
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _shiftService.extendShift(
        session: _requireSession(),
        localId: normalizedShiftId,
        overrideMinutes: overrideMinutes,
      );

      await _refreshShiftState();

      state = const ShiftCommandState();

      return const ShiftCommandResult.success();
    } catch (e) {
      final message = _commandErrorMessage(e);

      state = state.copyWith(isLoading: false, errorMessage: message);

      return ShiftCommandResult.failure(message);
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  String _commandErrorMessage(Object error) {
    final mapped = ErrorMapper.userMessage(error);
    final raw = error.toString().trim();

    if (raw.isEmpty || raw.toLowerCase() == 'null' || raw == mapped) {
      return mapped;
    }

    if (mapped == 'Something went wrong. Please try again.' ||
        mapped == 'Enter a valid value.') {
      return raw;
    }

    return '$mapped\n$raw';
  }

  ActivePosSession _requireSession() {
    final session = _readSession();

    if (session == null) {
      throw const BusinessException(
        'Select a cashier and POS machine before shift operations.',
        code: 'NO_ACTIVE_POS_SESSION',
      );
    }

    return session;
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
