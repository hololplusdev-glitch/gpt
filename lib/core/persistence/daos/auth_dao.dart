import 'package:drift/drift.dart';

import 'package:holol_POS/core/persistence/daos/dao_shared.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/core/services/time/clock.dart';

class AuthDao {
  final AppDatabase _db;
  final Clock _clock;

  AuthDao(this._db, {Clock clock = const SystemClock()}) : _clock = clock;

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

  Future<bool> hasLocalPin({required String userId}) async {
    final row = await (_db.select(
      _db.localUserPins,
    )..where((pin) => pin.userId.equals(userId))).getSingleOrNull();

    return row != null && row.pinHash.trim().isNotEmpty;
  }

  Future<void> setLocalPin({
    required String userId,
    required String pin,
  }) async {
    DaoLocalPinCodec.validate(pin);

    final now = _clock.now();
    final existing = await (_db.select(
      _db.localUserPins,
    )..where((row) => row.userId.equals(userId))).getSingleOrNull();

    final salt = existing?.pinSalt ?? DaoLocalPinCodec.newSalt();

    await _db
        .into(_db.localUserPins)
        .insertOnConflictUpdate(
          LocalUserPinsCompanion(
            userId: Value(userId),
            pinHash: Value(DaoLocalPinCodec.hash(pin, salt: salt)),
            pinSalt: Value(salt),
            createdAt: Value(existing?.createdAt ?? now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<bool> verifyLocalPin({
    required String userId,
    required String pin,
  }) async {
    DaoLocalPinCodec.validate(pin);

    final row = await (_db.select(
      _db.localUserPins,
    )..where((pinRow) => pinRow.userId.equals(userId))).getSingleOrNull();

    if (row == null) return false;
    return row.pinHash == DaoLocalPinCodec.hash(pin, salt: row.pinSalt);
  }
}
