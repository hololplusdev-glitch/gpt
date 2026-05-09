import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_flutter/core/errors/app_exception.dart';
import 'package:pos_flutter/core/persistence/daos/active_pos_session_dao.dart';
import 'package:pos_flutter/core/persistence/daos/audit_dao.dart';
import 'package:pos_flutter/core/persistence/daos/auth_dao.dart';
import 'package:pos_flutter/core/services/permission_service.dart';
import 'package:pos_flutter/core/services/time/clock.dart';
import 'package:pos_flutter/shared/models/enums.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';
import 'package:uuid/uuid.dart';

class AuthState {
  final CashierSession? session;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({this.session, this.isLoading = false, this.errorMessage});

  bool get isAuthenticated => session != null;
}

class CashierSession {
  final String userId;
  final String username;
  final String displayName;
  final String? roleId;
  final bool isSupervisor;
  final Set<String> permissionCodes;
  final String sessionId;
  final DateTime loginAt;

  const CashierSession({
    required this.userId,
    required this.username,
    required this.displayName,
    this.roleId,
    this.isSupervisor = false,
    required this.permissionCodes,
    required this.sessionId,
    required this.loginAt,
  });
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthDao _authDao;
  final AuditDao _auditDao;
  final ActivePosSessionDao _sessionDao;
  final PermissionService _permissions;
  final Clock _clock;

  static const _uuid = Uuid();

  AuthNotifier({
    required AuthDao authDao,
    required AuditDao auditDao,
    required ActivePosSessionDao sessionDao,
    required PermissionService permissions,
    Clock clock = const SystemClock(),
  }) : _authDao = authDao,
       _auditDao = auditDao,
       _sessionDao = sessionDao,
       _permissions = permissions,
       _clock = clock,
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

      final machine = await _sessionDao.getMachine(
        custCode: user.custCode,
        machineNo: accesses.first.machineNo,
      );
      if (machine == null) {
        state = const AuthState(errorMessage: 'Allowed POS machine not found.');
        return false;
      }

      final activeSession = await _sessionDao.startSession(
        user: user,
        machine: machine,
        priceIncludesTax: false,
      );
      final permissions = await _permissions.getUserPermissions(
        userId: user.id,
        terminalId: activeSession.activeMachineNo,
      );
      final sessionId = activeSession.sessionId ?? 'SESS_${_uuid.v4()}';
      final now = _clock.now();

      await _authDao.writeSessionLog(
        id: sessionId,
        userId: user.id,
        username: user.username,
        terminalId: activeSession.activeMachineNo,
      );
      await _auditDao.log(
        id: 'AUD_${_uuid.v4()}',
        action: AuditAction.login,
        actorId: user.id,
        actorName: user.displayName,
        terminalId: activeSession.activeMachineNo,
      );

      final isSupervisor =
          user.userLevel == 'supervisor' || user.userLevel == 'admin';
      state = AuthState(
        session: CashierSession(
          userId: user.id,
          username: user.username,
          displayName: user.displayName,
          roleId: user.roleId,
          isSupervisor: isSupervisor,
          permissionCodes: permissions.map((p) => p.code).toSet(),
          sessionId: sessionId,
          loginAt: now,
        ),
      );
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
    if (session != null) {
      await _authDao.updateSessionLogout(session.sessionId);
      await _sessionDao.clearActive();
    }
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
    permissions: ref.watch(permissionServiceProvider),
    clock: ref.watch(clockProvider),
  );
});
