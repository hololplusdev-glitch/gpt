import 'package:drift/drift.dart';
import 'package:holol_POS/core/persistence/daos/payment_profile_dao.dart';
import 'package:holol_POS/core/persistence/database.dart';
export 'package:holol_POS/core/persistence/database.dart'
    show PaymentDeviceProfile;
import 'package:holol_POS/core/services/time/clock.dart';
import 'package:holol_POS/shared/models/enums.dart';

class PaymentProfileService {
  final PaymentProfileDao _dao;
  final Clock _clock;

  const PaymentProfileService({
    required PaymentProfileDao dao,
    Clock clock = const SystemClock(),
  }) : _dao = dao,
       _clock = clock;

  Stream<PaymentDeviceProfile?> watchActive(String userId) =>
      _dao.watchActive(userId);

  Future<PaymentDeviceProfile?> getActivePaymentProfile(String userId) =>
      _dao.getActive(userId);

  Future<void> saveManualConfiguration({
    required String userId,
    required bool enabled,
    required bool requireReference,
  }) async {
    final now = _clock.now();
    final existing = await _dao.getManualProfile(userId);
    await _dao.upsert(
      PaymentDeviceProfilesCompanion(
        id: Value('manual-card-$userId'),
        userId: Value(userId),
        name: const Value('Manual card'),
        enabled: Value(enabled),
        mode: Value(PaymentProfileMode.manual.code),
        provider: Value(PaymentProvider.manual.code),
        connectionType: Value(PaymentConnectionType.none.code),
        requireReference: Value(requireReference),
        deviceTerminalRef: const Value<String?>(null),
        merchantId: const Value<String?>(null),
        endpoint: const Value<String?>(null),
        timeoutSeconds: const Value<int?>(null),
        createdAt: Value(existing?.createdAt ?? now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> ensureManualProfile(String userId) async {
    final existing = await _dao.getManualProfile(userId);
    if (existing != null) return;
    await saveManualConfiguration(
      userId: userId,
      enabled: false,
      requireReference: true,
    );
  }
}
