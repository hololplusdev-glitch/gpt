import 'package:drift/drift.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/core/services/time/clock.dart';

class PaymentProfileDao {
  final AppDatabase _db;

  final Clock _clock;

  PaymentProfileDao(this._db, {Clock clock = const SystemClock()})
    : _clock = clock;

  Stream<PaymentDeviceProfile?> watchActive(String userId) {
    return (_db.select(_db.paymentDeviceProfiles)..where(
          (p) => p.id.equals(_manualProfileId(userId)) & p.enabled.equals(true),
        ))
        .watchSingleOrNull();
  }

  Stream<PaymentDeviceProfile?> watchManualProfile(String userId) {
    return (_db.select(
      _db.paymentDeviceProfiles,
    )..where((p) => p.id.equals(_manualProfileId(userId)))).watchSingleOrNull();
  }

  Future<PaymentDeviceProfile?> getActive(String userId) {
    return (_db.select(_db.paymentDeviceProfiles)..where(
          (p) => p.id.equals(_manualProfileId(userId)) & p.enabled.equals(true),
        ))
        .getSingleOrNull();
  }

  Future<PaymentDeviceProfile?> getManualProfile(String userId) {
    return (_db.select(
      _db.paymentDeviceProfiles,
    )..where((p) => p.id.equals(_manualProfileId(userId)))).getSingleOrNull();
  }

  Future<void> upsert(PaymentDeviceProfilesCompanion profile) {
    return _db.into(_db.paymentDeviceProfiles).insertOnConflictUpdate(profile);
  }

  static String manualProfileId(String userId) => _manualProfileId(userId);

  static String _manualProfileId(String userId) => 'manual-card-$userId';

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
