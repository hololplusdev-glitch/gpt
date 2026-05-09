import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_flutter/core/errors/app_exception.dart';
import 'package:pos_flutter/core/persistence/daos/active_pos_session_dao.dart';
import 'package:pos_flutter/core/persistence/daos/sales_dao.dart';
import 'package:pos_flutter/core/persistence/database.dart';
import 'package:pos_flutter/core/services/sync/upload_queue.dart';
import 'package:pos_flutter/core/services/time/clock.dart';
import 'package:pos_flutter/shared/models/enums.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';
import 'package:uuid/uuid.dart';

/// Sale void owner only.
/// Completion remains owned by SaleCheckout.
class SaleVoidService {
  final SalesDao _salesDao;
  final UploadQueue _uploadQueue;
  final ActivePosSession? _activeSession;
  final Clock _clock;

  const SaleVoidService({
    required SalesDao salesDao,
    required UploadQueue uploadQueue,
    required ActivePosSession? activeSession,
    Clock clock = const SystemClock(),
  }) : _salesDao = salesDao,
       _uploadQueue = uploadQueue,
       _activeSession = activeSession,
       _clock = clock;

  static const _uuid = Uuid();

  Future<void> voidSale({
    required String saleId,
    String? supervisorId,
  }) async {
    final session = _requireActiveSession();
    final now = _clock.now();

    await _salesDao.voidSaleEnvelope(
      saleId: saleId,
      voidedAt: now,
      outboxEntry: _uploadQueue.saleVoided(
        saleId: saleId,
        cashierId: session.activeUserId,
        cashierName: session.activeUserName,
        supervisorId: supervisorId,
        voidedAt: now,
      ),
      auditLogEntry: AuditLogCompanion(
        id: Value('AUD_${_uuid.v4()}'),
        action: Value(AuditAction.saleVoided.code),
        actorId: Value(session.activeUserId),
        actorName: Value(session.activeUserName),
        supervisorId: Value(supervisorId),
        targetType: Value(OutboxEntityType.sale.code),
        targetId: Value(saleId),
        terminalId: Value(session.activeMachineNo),
        createdAt: Value(now),
      ),
    );
  }

  ActivePosSession _requireActiveSession() {
    final session = _activeSession;
    if (session == null) {
      throw const BusinessException(
        'Select a cashier and POS machine before voiding a sale.',
        code: 'NO_ACTIVE_POS_SESSION',
      );
    }
    return session;
  }
}

final saleVoidServiceProvider = Provider<SaleVoidService>((ref) {
  return SaleVoidService(
    salesDao: ref.watch(salesDaoProvider),
    uploadQueue: ref.watch(uploadQueueProvider),
    activeSession: ref.watch(activePosSessionProvider).valueOrNull,
    clock: ref.watch(clockProvider),
  );
});
