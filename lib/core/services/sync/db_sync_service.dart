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
/// SSOT rules:
/// - SyncDao owns outbox status transitions.
/// - DbSyncService owns upload orchestration only.
/// - Missing upload API must not mutate business events to blocked.
/// - blocked is reserved for permanent server rejection or unrecoverable payload.
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
    var uploadUnavailable = 0;

    final recovered = await _syncDao.recoverStuckUploading();

    if (!_apiClient.isConfigured) {
      final remaining = await _remainingRetryableCount();

      if (remaining > 0 || recovered > 0) {
        await _auditDao.log(
          id: 'AUD_${_uuid.v4()}',
          action: AuditAction.syncFailed,
          actorId: 'SYSTEM',
          detailsJson: jsonEncode({
            'synced': 0,
            'failed': 0,
            'uploadUnavailable': remaining,
            'remaining': remaining,
            'blockedCount': await _syncDao.getBlockedCount(),
            'recoveredStuckUploading': recovered,
            'reason': 'upload_api_not_configured',
          }),
          terminalId: terminalId,
        );
      }

      return SyncResult(
        synced: 0,
        failed: 0,
        uploadUnavailable: remaining,
        remaining: remaining,
        blockedCount: await _syncDao.getBlockedCount(),
        recoveredStuckUploading: recovered,
      );
    }

    final pending = await _syncDao.getPending(limit: 50);
    final processedIds = pending.map((entry) => entry.id).toSet();

    for (final entry in pending) {
      final result = await _processEntry(entry);

      switch (result) {
        case _OutboxEntryProcessResult.accepted:
          synced++;
        case _OutboxEntryProcessResult.failed:
          failed++;
        case _OutboxEntryProcessResult.uploadUnavailable:
          uploadUnavailable++;
      }

      if (result == _OutboxEntryProcessResult.uploadUnavailable) {
        break;
      }
    }

    if (uploadUnavailable == 0) {
      final retryable = (await _syncDao.getRetryable(
        limit: 20,
      )).where((entry) => !processedIds.contains(entry.id));

      for (final entry in retryable) {
        final result = await _processEntry(entry);

        switch (result) {
          case _OutboxEntryProcessResult.accepted:
            synced++;
          case _OutboxEntryProcessResult.failed:
            failed++;
          case _OutboxEntryProcessResult.uploadUnavailable:
            uploadUnavailable++;
        }

        if (result == _OutboxEntryProcessResult.uploadUnavailable) {
          break;
        }
      }
    }

    if (synced > 0 || failed > 0 || uploadUnavailable > 0 || recovered > 0) {
      await _auditDao.log(
        id: 'AUD_${_uuid.v4()}',
        action: synced > 0 && failed == 0 && uploadUnavailable == 0
            ? AuditAction.syncSucceeded
            : AuditAction.syncFailed,
        actorId: 'SYSTEM',
        detailsJson: jsonEncode({
          'synced': synced,
          'failed': failed,
          'uploadUnavailable': uploadUnavailable,
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
      uploadUnavailable: uploadUnavailable,
      remaining: await _remainingRetryableCount(),
      blockedCount: await _syncDao.getBlockedCount(),
      recoveredStuckUploading: recovered,
    );
  }

  Future<int> getPendingCount() {
    return _syncDao.getPendingCount();
  }

  Future<_OutboxEntryProcessResult> _processEntry(OutboxEvent entry) async {
    try {
      await _syncDao.markUploading(entry.id);

      final upload = await _upload(entry);

      await _syncDao.markUploaded(
        entry: entry,
        syncLogId: 'SL_${_uuid.v4()}',
        serverId: upload.serverId,
        serverMappingId: upload.serverMappingId,
        serverResponse: upload.responseSummary,
      );

      return _OutboxEntryProcessResult.accepted;
    } on UploadApiUnavailableException catch (_) {
      await _syncDao.restorePending(
        entry.id,
        reason: 'Upload API unavailable. Event remains pending.',
      );
      return _OutboxEntryProcessResult.uploadUnavailable;
    } on SyncRejectedException catch (e) {
      await _syncDao.markBlocked(
        entry.id,
        blockedReason: 'server_rejected',
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

      return _OutboxEntryProcessResult.failed;
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

      return _OutboxEntryProcessResult.failed;
    }
  }

  Future<int> _remainingRetryableCount() async {
    return await _syncDao.getPendingCount() +
        await _syncDao.getRetryableCount();
  }

  Future<_UploadAccepted> _upload(OutboxEvent entry) async {
    if (!_apiClient.isConfigured) {
      throw const UploadApiUnavailableException(
        'Invoice upload API is not configured.',
      );
    }

    // Upload endpoint contract is intentionally not guessed here.
    // When Backend provides the contract, this method becomes the single owner
    // of request path, payload envelope, response parsing, and idempotency.
    throw const UploadApiUnavailableException(
      'Invoice upload API is not documented yet. Pending invoices remain local.',
    );
  }
}

enum _OutboxEntryProcessResult { accepted, failed, uploadUnavailable }

class _UploadAccepted {
  final String? serverId;
  final String? serverMappingId;
  final String? responseSummary;

  const _UploadAccepted()
    : serverId = null,
      serverMappingId = null,
      responseSummary = null;
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
  final int uploadUnavailable;
  final int remaining;
  final int blockedCount;
  final int recoveredStuckUploading;

  const SyncResult({
    required this.synced,
    required this.failed,
    this.uploadUnavailable = 0,
    required this.remaining,
    required this.blockedCount,
    required this.recoveredStuckUploading,
  });

  bool get hasWorkRemaining => remaining > 0 || uploadUnavailable > 0;

  @override
  String toString() {
    return 'SyncResult(synced: $synced, failed: $failed, uploadUnavailable: $uploadUnavailable, remaining: $remaining, blockedCount: $blockedCount)';
  }
}
