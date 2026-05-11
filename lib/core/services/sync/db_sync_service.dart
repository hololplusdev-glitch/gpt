// core/services/sync/db_sync_service.dart
// WHY: DB-backed sync outbox processor. It never marks data as synced unless
// the configured server endpoint explicitly accepts the payload.

import 'dart:convert';

import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/network/api_client.dart';
import 'package:holol_POS/core/persistence/daos/audit_dao.dart';
import 'package:holol_POS/core/persistence/daos/sync_dao.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:uuid/uuid.dart';

/// Local upload outbox processor.
///
/// The current Backend APEX offline contract only documents master-data download.
/// Until an invoice upload endpoint is provided, this service must block
/// queued sale/shift events instead of pretending they uploaded.
class DbSyncService {
  final SyncDao _syncDao;
  final AuditDao _auditDao;
  final LocalApiClient _apiClient;

  static const _uuid = Uuid();

  DbSyncService({
    required SyncDao syncDao,
    required AuditDao auditDao,
    required LocalApiClient apiClient,
  }) : _syncDao = syncDao,
       _auditDao = auditDao,
       _apiClient = apiClient;

  Future<SyncResult> processQueue({required String terminalId}) async {
    var synced = 0;
    var failed = 0;

    final recovered = await _syncDao.recoverStuckUploading();

    final pending = await _syncDao.getPending(limit: 50);
    final processedIds = pending.map((entry) => entry.id).toSet();
    for (final entry in pending) {
      final accepted = await _processEntry(entry);
      if (accepted) {
        synced++;
      } else {
        failed++;
      }
    }

    final retryable = (await _syncDao.getRetryable(
      limit: 20,
    )).where((entry) => !processedIds.contains(entry.id));
    for (final entry in retryable) {
      final accepted = await _processEntry(entry);
      if (accepted) {
        synced++;
      } else {
        failed++;
      }
    }

    if (synced > 0 || failed > 0) {
      await _auditDao.log(
        id: 'AUD_${_uuid.v4()}',
        action: synced > 0 ? AuditAction.syncSucceeded : AuditAction.syncFailed,
        actorId: 'SYSTEM',
        detailsJson: jsonEncode({
          'synced': synced,
          'failed': failed,
          'remaining': await _remainingRetryableCount(),
          'blockedCount': await _syncDao.getBlockedCount(),
          'recoveredStuckUploading': recovered,
        }),
        terminalId: terminalId,
      );
    }

    return SyncResult(
      synced: synced,
      failed: failed,
      remaining: await _remainingRetryableCount(),
      blockedCount: await _syncDao.getBlockedCount(),
      recoveredStuckUploading: recovered,
    );
  }

  Future<int> getPendingCount() {
    return _syncDao.getPendingCount();
  }

  Future<bool> _processEntry(OutboxEvent entry) async {
    try {
      await _syncDao.markUploading(entry.id);
      await _upload(entry.payloadJson);
      await _syncDao.markUploaded(entry: entry, syncLogId: 'SL_${_uuid.v4()}');
      return true;
    } on UploadApiUnavailableException catch (e) {
      await _syncDao.markBlocked(
        entry.id,
        blockedReason: 'upload_api_unavailable',
        error: e.message,
      );
      await _syncDao.logAttempt(
        id: 'SL_${_uuid.v4()}',
        outboxEventId: entry.id,
        eventType: entry.eventType,
        entityId: entry.entityId,
        success: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      final message = ErrorMapper.userMessage(e);
      await _syncDao.markFailed(entry.id, message);
      await _syncDao.logAttempt(
        id: 'SL_${_uuid.v4()}',
        outboxEventId: entry.id,
        eventType: entry.eventType,
        entityId: entry.entityId,
        success: false,
        errorMessage: message,
      );
      return false;
    }
  }

  Future<int> _remainingRetryableCount() async {
    return await _syncDao.getPendingCount() +
        await _syncDao.getRetryableCount();
  }

  Future<void> _upload(String _) async {
    if (!_apiClient.isConfigured) {
      throw const UploadApiUnavailableException(
        'Invoice upload API is not configured.',
      );
    }
    throw const UploadApiUnavailableException(
      'Invoice upload API is not documented yet. Pending invoices remain local.',
    );
  }
}

class UploadApiUnavailableException extends SyncTransportException {
  const UploadApiUnavailableException(super.message);
}

class SyncTransportException extends SyncException {
  const SyncTransportException(super.message) : super(code: 'sync_transport');
}

class SyncRejectedException extends SyncException {
  const SyncRejectedException(super.message) : super(code: 'sync_rejected');
}

class SyncResult {
  final int synced;
  final int failed;
  final int remaining;
  final int blockedCount;
  final int recoveredStuckUploading;

  const SyncResult({
    required this.synced,
    required this.failed,
    required this.remaining,
    required this.blockedCount,
    required this.recoveredStuckUploading,
  });

  @override
  String toString() =>
      'SyncResult(synced: $synced, failed: $failed, remaining: $remaining, blockedCount: $blockedCount)';
}
