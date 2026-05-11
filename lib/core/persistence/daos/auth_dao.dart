// core/persistence/daos/auth_dao.dart
// WHY: Organized DB access for authentication operations.
// AuthDao owns local PIN and authentication-related audit logs.

import 'dart:math';

import 'package:drift/drift.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/core/services/time/clock.dart';

/// Data access for user authentication and session logging.
class AuthDao {
  final AppDatabase _db;
  final Clock _clock;

  AuthDao(this._db, {Clock clock = const SystemClock()}) : _clock = clock;

  /// Find user by username, ID, usr_id, or login_name.
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

  Future<PosUser?> findById(String userId) async {
    return (_db.select(
      _db.posUsers,
    )..where((u) => u.id.equals(userId))).getSingleOrNull();
  }

  static const _pinPrefix = 'local-pin-v1';

  Future<bool> hasLocalPin({
    required String custCode,
    required String userId,
  }) async {
    final row =
        await (_db.select(_db.localUserPins)..where(
              (pin) =>
                  pin.custCode.equals(custCode) & pin.userId.equals(userId),
            ))
            .getSingleOrNull();

    return row != null && row.pinHash.trim().isNotEmpty;
  }

  Future<void> setLocalPin({
    required String custCode,
    required String userId,
    required String pin,
  }) async {
    _validatePin(pin);

    final now = _clock.now();
    final existing =
        await (_db.select(_db.localUserPins)..where(
              (row) =>
                  row.custCode.equals(custCode) & row.userId.equals(userId),
            ))
            .getSingleOrNull();

    final salt = existing?.pinSalt ?? _newSalt();

    await _db
        .into(_db.localUserPins)
        .insertOnConflictUpdate(
          LocalUserPinsCompanion(
            custCode: Value(custCode),
            userId: Value(userId),
            pinHash: Value(_hashPin(pin, salt: salt)),
            pinSalt: Value(salt),
            createdAt: Value(existing?.createdAt ?? now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<bool> verifyLocalPin({
    required String custCode,
    required String userId,
    required String pin,
  }) async {
    _validatePin(pin);

    final row =
        await (_db.select(_db.localUserPins)..where(
              (pinRow) =>
                  pinRow.custCode.equals(custCode) &
                  pinRow.userId.equals(userId),
            ))
            .getSingleOrNull();

    if (row == null) return false;
    return row.pinHash == _hashPin(pin, salt: row.pinSalt);
  }

  void _validatePin(String pin) {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw ArgumentError('PIN must be exactly 4 digits.');
    }
  }

  String _hashPin(String pin, {required String salt}) {
    final payload = '$salt:$pin';

    var hash = 0xcbf29ce484222325;
    for (final unit in payload.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }

    return '$_pinPrefix:$salt:${hash.toRadixString(16)}';
  }

  String _newSalt() {
    final random = Random.secure();
    return List<int>.generate(
      12,
      (_) => random.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

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

  Future<void> updateSessionLogout(String sessionId) async {
    final log = await (_db.select(
      _db.auditLog,
    )..where((s) => s.id.equals(sessionId))).getSingleOrNull();

    if (log == null) return;

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
