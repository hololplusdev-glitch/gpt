import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_flutter/core/errors/app_exception.dart';
import 'package:pos_flutter/core/persistence/daos/active_pos_session_dao.dart';
import 'package:pos_flutter/core/persistence/daos/audit_dao.dart';
import 'package:pos_flutter/core/persistence/daos/auth_dao.dart';
import 'package:pos_flutter/shared/models/enums.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';
import 'package:uuid/uuid.dart';

/// Thin auth facade. ActivePosSession is the runtime truth.
class AuthState {
  final ActivePosSession? session;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({this.session, this.isLoading = false, this.errorMessage});

  bool get isAuthenticated => session != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthDao _authDao;
  final AuditDao _auditDao;
  final ActivePosSessionDao _sessionDao;

  static const _uuid = Uuid();

  AuthNotifier({
    required AuthDao authDao,
    required AuditDao auditDao,
    required ActivePosSessionDao sessionDao,
  }) : _authDao = authDao,
       _auditDao = auditDao,
       _sessionDao = sessionDao,
       super(const AuthState());

  Future<bool> selectCashier(String username) async {
    state = const AuthState(isLoading: true);

    try {
      final user = await _authDao.findByUsername(username);
      if (user == null) {
        state = const AuthState(errorMessage: 'User not found in synced data.');
        return false;
      }

      if (!user.isActive || !user.canLoginPos) {
        state = const AuthState(errorMessage: 'User not authorized for POS.');
        return false;
      }

      final accesses = await _sessionDao.listAllowedMachinesForUser(
        custCode: user.custCode,
        userId: user.id,
      );

      if (accesses.isEmpty) {
        state = const AuthState(
          errorMessage: 'No POS machine access found for this user.',
        );
        return false;
      }

      if (accesses.length > 1) {
        state = const AuthState(
          errorMessage:
              'Multiple POS machines are allowed. Select a machine explicitly.',
        );
        return false;
      }

      return selectCashierAndMachine(username, accesses.single.machineNo);
    } catch (e) {
      state = AuthState(errorMessage: ErrorMapper.userMessage(e));
      return false;
    }
  }

  Future<bool> selectCashierAndMachine(String username, String machineNo) async {
    state = const AuthState(isLoading: true);

    try {
      final user = await _authDao.findByUsername(username);
      if (user == null) {
        state = const AuthState(errorMessage: 'User not found in synced data.');
        return false;
      }

      if (!user.isActive || !user.canLoginPos) {
        state = const AuthState(errorMessage: 'User not authorized for POS.');
        return false;
      }

      final machine = await _sessionDao.getMachine(
        custCode: user.custCode,
        machineNo: machineNo,
      );

      if (machine == null) {
        state = const AuthState(errorMessage: 'Selected POS machine not found.');
        return false;
      }

      final session = await _sessionDao.startSession(
        user: user,
        machine: machine,
      );

      final sessionId = session.sessionId ?? 'SESS_${_uuid.v4()}';

      await _authDao.writeSessionLog(
        id: sessionId,
        userId: user.id,
        username: user.username,
        terminalId: session.activeMachineNo,
      );

      await _auditDao.log(
        id: 'AUD_${_uuid.v4()}',
        action: AuditAction.login,
        actorId: user.id,
        actorName: user.displayName,
        terminalId: session.activeMachineNo,
      );

      state = AuthState(session: session);
      return true;
    } catch (e) {
      state = AuthState(errorMessage: ErrorMapper.userMessage(e));
      return false;
    }
  }

  Future<bool> login(String username, String password) {
    return selectCashier(username);
  }

  Future<void> logout() async {
    final session = state.session;

    if (session != null && session.sessionId != null) {
      await _authDao.updateSessionLogout(session.sessionId!);
    }

    await _sessionDao.clearActive();
    state = const AuthState();
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = AuthState(session: state.session);
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    authDao: ref.watch(authDaoProvider),
    auditDao: ref.watch(auditDaoProvider),
    sessionDao: ref.watch(activePosSessionDaoProvider),
  );
});
