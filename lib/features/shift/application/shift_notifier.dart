// features/shift/application/shift_notifier.dart
// WHY: Shift actions + shift dashboard projection.
// Runtime SSOT is ActivePosSession.openShiftId.
// This file must not own "current shift" truth.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_flutter/core/errors/app_exception.dart';
import 'package:pos_flutter/core/persistence/daos/active_pos_session_dao.dart';
import 'package:pos_flutter/core/persistence/daos/sales_dao.dart';
import 'package:pos_flutter/core/persistence/database.dart';
import 'package:pos_flutter/features/shift/application/shift_service.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';

typedef ActiveSessionReader = ActivePosSession? Function();

/// UI command state only.
/// Not a source of truth for whether a shift is open.
class ShiftState {
  final bool isLoading;
  final String? errorMessage;

  const ShiftState({this.isLoading = false, this.errorMessage});

  ShiftState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ShiftState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Read model for the current shift screen.
/// Derived from ActivePosSession.openShiftId + DB queries.
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

/// Single read path for current shift details.
/// If there is no ActivePosSession.openShiftId, there is no current shift.
final activeShiftDashboardProvider =
    FutureProvider.autoDispose<ShiftDashboard?>((ref) async {
      final session = ref.watch(activePosSessionProvider).valueOrNull;
      final shiftId = session?.openShiftId?.trim();

      if (shiftId == null || shiftId.isEmpty) {
        return null;
      }

      final shiftDao = ref.watch(shiftDaoProvider);
      final salesDao = ref.watch(salesDaoProvider);

      final shift = await shiftDao.getById(shiftId);
      if (shift == null) {
        return null;
      }

      final totals = await salesDao.getShiftSalesTotals(shiftId);
      final movements = await shiftDao.getCashMovementTotals(shiftId);

      return ShiftDashboard(
        shift: shift,
        totals: totals,
        cashIn: movements.cashIn,
        cashOut: movements.cashOut,
        cashRefund: movements.cashRefund,
      );
    });

class ShiftNotifier extends StateNotifier<ShiftState> {
  final ShiftService _shiftService;
  final ActiveSessionReader _readSession;

  ShiftNotifier(this._shiftService, this._readSession)
    : super(const ShiftState());

  Future<bool> openShift({
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

      state = const ShiftState();
      return true;
    } on ShiftException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.userMessage(e),
      );
      return false;
    }
  }

  Future<bool> closeShift({
    required String shiftId,
    required double actualCash,
    String? closingNotes,
  }) async {
    final normalizedShiftId = shiftId.trim();
    if (normalizedShiftId.isEmpty) {
      state = state.copyWith(errorMessage: 'No open shift to close.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _shiftService.closeShift(
        session: _requireSession(),
        localId: normalizedShiftId,
        actualCash: actualCash,
        closingNotes: closingNotes,
      );

      state = const ShiftState();
      return true;
    } on ShiftException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.userMessage(e),
      );
      return false;
    }
  }

  Future<bool> extendShift({
    required String shiftId,
    int? overrideMinutes,
  }) async {
    final normalizedShiftId = shiftId.trim();
    if (normalizedShiftId.isEmpty) return false;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _shiftService.extendShift(
        session: _requireSession(),
        localId: normalizedShiftId,
        overrideMinutes: overrideMinutes,
      );

      state = const ShiftState();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.userMessage(e),
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
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

final shiftProvider = StateNotifierProvider<ShiftNotifier, ShiftState>((ref) {
  return ShiftNotifier(
    ref.watch(shiftServiceProvider),
    () => ref.read(activePosSessionProvider).valueOrNull,
  );
});
