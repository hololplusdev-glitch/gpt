// features/shift/application/shift_notifier.dart
// WHY: Riverpod state for the active shift. UI observes this to enforce shift guards.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_flutter/core/errors/app_exception.dart';
import 'package:pos_flutter/core/persistence/daos/active_pos_session_dao.dart';
import 'package:pos_flutter/core/persistence/database.dart';
import 'package:pos_flutter/features/shift/application/shift_service.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';

typedef ActiveSessionReader = ActivePosSession? Function();

class ShiftState {
  final Shift? activeShift;
  final bool isLoading;
  final String? errorMessage;

  const ShiftState({
    this.activeShift,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get hasOpenShift => activeShift != null;

  ShiftState copyWith({
    Shift? activeShift,
    bool? isLoading,
    String? errorMessage,
    bool clearShift = false,
    bool clearError = false,
  }) {
    return ShiftState(
      activeShift: clearShift ? null : (activeShift ?? this.activeShift),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ShiftNotifier extends StateNotifier<ShiftState> {
  final ShiftService _shiftService;
  final ActiveSessionReader _readSession;

  ShiftNotifier(this._shiftService, this._readSession)
    : super(const ShiftState());

  Future<void> loadCurrentShift(String terminalId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final session = _requireSession();
      final shift = await _shiftService.getCurrentShift(session.activeMachineNo);
      state = ShiftState(activeShift: shift);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.userMessage(e),
      );
    }
  }

  Future<bool> openShift({
    required String terminalId,
    required String cashierId,
    required String cashierName,
    required double openingCash,
    String? shiftTypeId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final shift = await _shiftService.openShift(
        session: _requireSession(),
        openingCash: openingCash,
        shiftTypeId: shiftTypeId,
      );
      state = ShiftState(activeShift: shift);
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
    required double actualCash,
    required String cashierId,
    required String cashierName,
    required String terminalId,
    String? closingNotes,
  }) async {
    if (!state.hasOpenShift) {
      state = state.copyWith(errorMessage: 'No open shift to close');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _shiftService.closeShift(
        session: _requireSession(),
        localId: state.activeShift!.id,
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
    required String cashierId,
    required String terminalId,
    int? overrideMinutes,
  }) async {
    if (!state.hasOpenShift) return false;

    try {
      final shift = await _shiftService.extendShift(
        session: _requireSession(),
        localId: state.activeShift!.id,
        overrideMinutes: overrideMinutes,
      );
      state = ShiftState(activeShift: shift);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: ErrorMapper.userMessage(e));
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
