// core/persistence/daos/auth_dao.dart
// WHY: Organized DB access for authentication operations.
// Separates raw SQL concerns from business logic.

import 'package:drift/drift.dart';
import 'package:pos_flutter/core/persistence/database.dart';
import 'package:pos_flutter/core/services/time/clock.dart';

/// Data access for user authentication and session logging.
class AuthDao {
  final AppDatabase _db;

  final Clock _clock;

  AuthDao(this._db, {Clock clock = const SystemClock()}) : _clock = clock;

  /// Find user by username, ID, usr_id, or login_name (case-insensitive).
  /// WHY: The login screen says "User ID or Login Name" — users may type
  /// any of these fields in any casing.
  Future<PosUser?> findByUsername(String username) async {
    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    return _db
        .customSelect(
          '''
          SELECT *
          FROM pos_users
          WHERE lower(trim(id)) = ?
             OR lower(trim(username)) = ?
             OR lower(trim(coalesce(source_user_id, ''))) = ?
             OR lower(trim(coalesce(login_name, ''))) = ?
          LIMIT 1
          ''',
          variables: [
            Variable<String>(normalized),
            Variable<String>(normalized),
            Variable<String>(normalized),
            Variable<String>(normalized),
          ],
          readsFrom: {_db.posUsers},
        )
        .map((row) => _db.posUsers.map(row.data))
        .getSingleOrNull();
  }

  /// DEV-ONLY: Get all users to help debug empty responses
  Future<List<Map<String, dynamic>>> getAllUsersDebug() async {
    final rows = await _db.select(_db.posUsers).get();
    return rows
        .map(
          (user) => {
            'id': user.id,
            'username': user.username,
            'usr_id': user.sourceUserId,
            'login_name': user.loginName,
          },
        )
        .toList();
  }

  /// Find user by ID.
  Future<PosUser?> findById(String userId) async {
    return (_db.select(
      _db.posUsers,
    )..where((u) => u.id.equals(userId))).getSingleOrNull();
  }

  // WHY: UserRole table removed — supervisor status derived from userLevel.
  // roleId kept on Users for future API use.

  /// Get all permissions for a user on a terminal.
  Future<List<String>> getUserPermissions(
    String userId,
    String terminalId,
  ) async {
    final row =
        await (_db.select(_db.posUserMachineAccess)..where(
              (p) => p.userId.equals(userId) & p.machineNo.equals(terminalId),
            ))
            .getSingleOrNull();
    if (row == null) return [];
    return [
      if (row.canUseMachine) 'USE_MACHINE',
    ];
  }

  /// Write session log entry.
  Future<void> writeSessionLog({
    required String id,
    required String userId,
    required String username,
    required String terminalId,
  }) async {
    await _db
        .into(_db.auditLog)
        .insert(
          AuditLogCompanion(
            id: Value(id),
            action: Value('login'),
            actorId: Value(userId),
            actorName: Value(username),
            terminalId: Value(terminalId),
            createdAt: Value(_clock.now()),
          ),
        );
  }

  /// Update session log with logout time.
  Future<void> updateSessionLogout(String sessionId) async {
    final log = await (_db.select(
      _db.auditLog,
    )..where((s) => s.id.equals(sessionId))).getSingleOrNull();
    if (log != null) {
      await _db
          .into(_db.auditLog)
          .insert(
            AuditLogCompanion(
              id: Value('${sessionId}_logout'),
              action: Value('logout'),
              actorId: Value(log.actorId),
              actorName: Value(log.actorName),
              terminalId: Value(log.terminalId),
              createdAt: Value(_clock.now()),
            ),
          );
    }
  }
}
