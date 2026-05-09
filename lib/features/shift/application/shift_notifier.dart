// features/shift/application/shift_notifier.dart
// WHY: Riverpod state for the active shift. UI observes this to enforce shift guards.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_flutter/core/errors/app_exception.dart';
import 'package:pos_flutter/core/persistence/database.dart';
import 'package:pos_flutter/features/shift/application/shift_service.dart';

/// State for the active shift.
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

/// Manages shift lifecycle state.
class ShiftNotifier extends StateNotifier<ShiftState> {
  final ShiftService _shiftService;

  ShiftNotifier(this._shiftService) : super(const ShiftState());

  /// Load the current open shift for the terminal (on app start or login).
  Future<void> loadCurrentShift(String terminalId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final shift = await _shiftService.getCurrentShift(terminalId);
      state = ShiftState(activeShift: shift);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.userMessage(e),
      );
    }
  }

  /// Open a new shift.
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
        terminalId: terminalId,
        cashierId: cashierId,
        cashierName: cashierName,
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

  /// Close the current shift.
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
        localId: state.activeShift!.id,
        actualCash: actualCash,
        cashierId: cashierId,
        cashierName: cashierName,
        terminalId: terminalId,
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

  /// Extend the current shift.
  Future<bool> extendShift({
    required String cashierId,
    required String terminalId,
    int? overrideMinutes,
  }) async {
    if (!state.hasOpenShift) return false;
    try {
      final shift = await _shiftService.extendShift(
        localId: state.activeShift!.id,
        cashierId: cashierId,
        terminalId: terminalId,
        overrideMinutes: overrideMinutes,
      );
      state = ShiftState(activeShift: shift);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: ErrorMapper.userMessage(e));
      return false;
    }
  }

  /// Clear any error.
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final shiftProvider = StateNotifierProvider<ShiftNotifier, ShiftState>((ref) {
  return ShiftNotifier(ref.watch(shiftServiceProvider));
});
