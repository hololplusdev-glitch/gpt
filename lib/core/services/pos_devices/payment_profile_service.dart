import 'package:drift/drift.dart';
import 'package:pos_flutter/core/persistence/daos/payment_profile_dao.dart';
import 'package:pos_flutter/core/persistence/database.dart';
export 'package:pos_flutter/core/persistence/database.dart'
    show PaymentDeviceProfile;
import 'package:pos_flutter/core/services/time/clock.dart';
import 'package:pos_flutter/shared/models/enums.dart';

class PaymentProfileService {
  final PaymentProfileDao _dao;
  final Clock _clock;

  const PaymentProfileService({
    required PaymentProfileDao dao,
    Clock clock = const SystemClock(),
  }) : _dao = dao,
       _clock = clock;

  Stream<PaymentDeviceProfile?> watchActive() => _dao.watchActive();

  Future<PaymentDeviceProfile?> getActivePaymentProfile() => _dao.getActive();

  Future<void> saveManualConfiguration({
    required bool enabled,
    required bool requireReference,
  }) async {
    final now = _clock.now();
    final existing = await _dao.getManualProfile();
    await _dao.upsert(
      PaymentDeviceProfilesCompanion(
        id: const Value('manual-card'),
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

  Future<void> ensureManualProfile() async {
    final existing = await _dao.getManualProfile();
    if (existing != null) return;
    await saveManualConfiguration(enabled: false, requireReference: true);
  }

  bool integratedAvailable(PaymentDeviceProfile profile) {
    return false;
  }
}
