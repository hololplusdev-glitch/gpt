import 'package:drift/drift.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/core/services/time/clock.dart';
import 'package:holol_POS/core/persistence/daos/dao_shared.dart';

class PaymentProfileDao {
  final AppDatabase _db;

  final Clock _clock;

  PaymentProfileDao(this._db, {Clock clock = const SystemClock()})
    : _clock = clock;

  Stream<PaymentDeviceProfile?> watchActive(String userId) {
    return (_db.select(_db.paymentDeviceProfiles)..where(
          (p) =>
              p.id.equals(DaoPaymentProfileIds.manualCard(userId)) &
              p.userId.equals(userId) &
              p.enabled.equals(true),
        ))
        .watchSingleOrNull();
  }

  Stream<PaymentDeviceProfile?> watchManualProfile(String userId) {
    return (_db.select(_db.paymentDeviceProfiles)..where(
          (p) =>
              p.id.equals(DaoPaymentProfileIds.manualCard(userId)) & p.userId.equals(userId),
        ))
        .watchSingleOrNull();
  }

  Future<PaymentDeviceProfile?> getActive(String userId) {
    return (_db.select(_db.paymentDeviceProfiles)..where(
          (p) =>
              p.id.equals(DaoPaymentProfileIds.manualCard(userId)) &
              p.userId.equals(userId) &
              p.enabled.equals(true),
        ))
        .getSingleOrNull();
  }

  Future<PaymentDeviceProfile?> getManualProfile(String userId) {
    return (_db.select(_db.paymentDeviceProfiles)..where(
          (p) =>
              p.id.equals(DaoPaymentProfileIds.manualCard(userId)) & p.userId.equals(userId),
        ))
        .getSingleOrNull();
  }

  Future<void> upsert(PaymentDeviceProfilesCompanion profile) {
    return _db.into(_db.paymentDeviceProfiles).insertOnConflictUpdate(profile);
  }

  static String manualProfileId(String userId) => DaoPaymentProfileIds.manualCard(userId);

) {
    return (_db.update(
      _db.paymentDeviceProfiles,
    )..where((p) => p.id.equals(id))).write(
      PaymentDeviceProfilesCompanion(
        lastTestStatus: Value(DaoProfileStatus.testStatus(success)),
        lastTestAt: Value(_clock.now()),
        lastError: Value<String?>(success ? null : error),
        updatedAt: Value(_clock.now()),
      ),
    );
  }
}
