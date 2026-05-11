import 'package:drift/drift.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/core/services/time/clock.dart';

class PaymentProfileDao {
  final AppDatabase _db;

  final Clock _clock;

  PaymentProfileDao(this._db, {Clock clock = const SystemClock()})
    : _clock = clock;

  Stream<PaymentDeviceProfile?> watchActive() {
    return (_db.select(_db.paymentDeviceProfiles)
          ..where((p) => p.enabled.equals(true))
          ..limit(1))
        .watchSingleOrNull();
  }

  Stream<PaymentDeviceProfile?> watchManualProfile() {
    return (_db.select(
      _db.paymentDeviceProfiles,
    )..where((p) => p.mode.equals('manual'))).watchSingleOrNull();
  }

  Future<PaymentDeviceProfile?> getActive() {
    return (_db.select(_db.paymentDeviceProfiles)
          ..where((p) => p.enabled.equals(true))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<PaymentDeviceProfile?> getManualProfile() {
    return (_db.select(
      _db.paymentDeviceProfiles,
    )..where((p) => p.mode.equals('manual'))).getSingleOrNull();
  }

  Future<void> upsert(PaymentDeviceProfilesCompanion profile) {
    return _db.into(_db.paymentDeviceProfiles).insertOnConflictUpdate(profile);
  }

  Future<void> saveTestResult({
    required String id,
    required bool success,
    String? error,
  }) {
    return (_db.update(
      _db.paymentDeviceProfiles,
    )..where((p) => p.id.equals(id))).write(
      PaymentDeviceProfilesCompanion(
        lastTestStatus: Value(success ? 'ready' : 'failed'),
        lastTestAt: Value(_clock.now()),
        lastError: Value<String?>(success ? null : error),
        updatedAt: Value(_clock.now()),
      ),
    );
  }
}
