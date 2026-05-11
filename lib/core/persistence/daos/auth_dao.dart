// core/persistence/daos/auth_dao.dart
// WHY: Organized DB access for authentication operations.
// Separates raw SQL concerns from business logic.

import 'dart:math';

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

  static const _pinPrefix = 'local-pin-v1';

  bool hasLocalPin(PosUser user) {
    final value = user.pinHash?.trim();
    return value != null && value.isNotEmpty;
  }

  Future<void> setLocalPin({
    required String custCode,
    required String userId,
    required String pin,
  }) async {
    _validatePin(pin);
    await (_db.update(_db.posUsers)
          ..where((u) => u.custCode.equals(custCode) & u.id.equals(userId)))
        .write(PosUsersCompanion(pinHash: Value(_hashPin(pin))));
  }

  bool verifyLocalPin({required PosUser user, required String pin}) {
    _validatePin(pin);
    final stored = user.pinHash?.trim();
    if (stored == null || stored.isEmpty) return false;

    if (stored.startsWith('$_pinPrefix:')) {
      final parts = stored.split(':');
      if (parts.length != 3) return false;
      return _hashPin(pin, salt: parts[1]) == stored;
    }

    // Backward compatibility for any backend-provided plain PIN during rollout.
    return stored == pin;
  }

  void _validatePin(String pin) {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw ArgumentError('PIN must be exactly 4 digits.');
    }
  }

  String _hashPin(String pin, {String? salt}) {
    final effectiveSalt = salt ?? _newSalt();
    final payload = '$effectiveSalt:$pin';

    var hash = 0xcbf29ce484222325;
    for (final unit in payload.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }

    return '$_pinPrefix:$effectiveSalt:${hash.toRadixString(16)}';
  }

  String _newSalt() {
    final random = Random.secure();
    return List<int>.generate(
      12,
      (_) => random.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
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
    return [if (row.canUseMachine) 'USE_MACHINE'];
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
