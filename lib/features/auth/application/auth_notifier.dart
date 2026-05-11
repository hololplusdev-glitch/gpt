import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_flutter/core/errors/app_exception.dart';
import 'package:pos_flutter/core/persistence/daos/active_pos_session_dao.dart';
import 'package:pos_flutter/core/persistence/daos/audit_dao.dart';
import 'package:pos_flutter/core/persistence/daos/auth_dao.dart';
import 'package:pos_flutter/core/persistence/daos/shift_dao.dart';
import 'package:pos_flutter/shared/models/enums.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';
import 'package:uuid/uuid.dart';

/// UI state for cashier selection only.
/// Runtime truth is activePosSessionProvider.
class CashierSelectionState {
  final bool isLoading;
  final String? errorMessage;

  const CashierSelectionState({this.isLoading = false, this.errorMessage});
}

class CashierSelectionNotifier extends StateNotifier<CashierSelectionState> {
  final AuthDao _authDao;
  final AuditDao _auditDao;
  final ActivePosSessionDao _sessionDao;
  final ShiftDao _shiftDao;

  static const _uuid = Uuid();

  CashierSelectionNotifier({
    required AuthDao authDao,
    required AuditDao auditDao,
    required ActivePosSessionDao sessionDao,
    required ShiftDao shiftDao,
  }) : _authDao = authDao,
       _auditDao = auditDao,
       _sessionDao = sessionDao,
       _shiftDao = shiftDao,
       super(const CashierSelectionState());

  /// Only supported login flow:
  /// user number + selected runtime machine.
  Future<bool> selectCashierAndMachine(
    String userNumber,
    String machineNo,
  ) async {
    state = const CashierSelectionState(isLoading: true);

    try {
      final user = await _authDao.findByUsername(userNumber);
      if (user == null) {
        state = const CashierSelectionState(
          errorMessage: 'User not found in downloaded data.',
        );
        return false;
      }

      if (!user.isActive || !user.canLoginPos) {
        state = const CashierSelectionState(
          errorMessage: 'User not authorized for POS.',
        );
        return false;
      }

      final machine = await _sessionDao.getMachine(
        custCode: user.custCode,
        machineNo: machineNo,
      );

      if (machine == null) {
        state = const CashierSelectionState(
          errorMessage: 'Selected POS machine not found.',
        );
        return false;
      }

      final existingMachineShift = await _shiftDao.getOpenShift(
        machine.machineNo,
      );

      if (existingMachineShift != null &&
          existingMachineShift.cashierId != user.id) {
        state = const CashierSelectionState(
          errorMessage:
              'يوجد شفت مفتوح على هذا الجهاز لمستخدم آخر. أغلق الشفت أولًا.',
        );
        return false;
      }

      final session = await _sessionDao.startSession(
        user: user,
        machine: machine,
      );

      if (existingMachineShift != null) {
        await _sessionDao.attachOpenShift(existingMachineShift.id);
      }

      final sessionId = session.sessionId ?? 'SESS_${_uuid.v4()}';

      await _authDao.writeSessionLog(
        id: sessionId,
        userId: session.activeUserId,
        username: session.activeUserName,
        terminalId: session.activeMachineNo,
      );

      await _auditDao.log(
        id: 'AUD_${_uuid.v4()}',
        action: AuditAction.login,
        actorId: session.activeUserId,
        actorName: session.activeUserName,
        terminalId: session.activeMachineNo,
      );

      state = const CashierSelectionState();
      return true;
    } catch (e) {
      state = CashierSelectionState(errorMessage: ErrorMapper.userMessage(e));
      return false;
    }
  }

  Future<void> logout() async {
    final session = await _sessionDao.getActive();

    if (session?.sessionId != null) {
      await _authDao.updateSessionLogout(session!.sessionId!);
    }

    await _sessionDao.clearActive();
    state = const CashierSelectionState();
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = const CashierSelectionState();
    }
  }
}

final cashierSelectionProvider =
    StateNotifierProvider<CashierSelectionNotifier, CashierSelectionState>((
      ref,
    ) {
      return CashierSelectionNotifier(
        authDao: ref.watch(authDaoProvider),
        auditDao: ref.watch(auditDaoProvider),
        sessionDao: ref.watch(activePosSessionDaoProvider),
        shiftDao: ref.watch(shiftDaoProvider),
      );
    });
