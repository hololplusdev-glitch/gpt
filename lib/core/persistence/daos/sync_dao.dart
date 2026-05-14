// core/persistence/daos/sync_dao.dart
// WHY: DB access for the sync outbox queue.
// All business events are queued here for eventual push to Backend.

import 'package:drift/drift.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/core/services/time/clock.dart';

/// Data access for sync queue operations.
class SyncDao {
  final AppDatabase _db;
  final Clock _clock;

  SyncDao(this._db, {Clock clock = const SystemClock()}) : _clock = clock;


  /// Get all pending sync entries, ordered by creation time.
  Future<List<OutboxEvent>> getPending({int limit = 50}) async {
    final rows =
        await (_db.select(_db.outboxEvents)
              ..where((s) => s.status.equals(OutboxStatus.pending.code))
              ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]))
            .get();
    rows.sort(_compareBySyncPriority);
    return rows.take(limit).toList();
  }

  /// Get failed entries that can be retried.
  Future<List<OutboxEvent>> getRetryable({int limit = 20}) async {
    final rows =
        await (_db.select(_db.outboxEvents)
              ..where(
                (s) =>
                    s.status.equals(OutboxStatus.failed.code) &
                    s.retryCount.isSmallerThan(s.maxRetries),
              )
              ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]))
            .get();
    rows.sort(_compareBySyncPriority);
    return rows.take(limit).toList();
  }

  /// Mark entry as uploading.
  Future<void> markUploading(String id) async {
    await (_db.update(_db.outboxEvents)..where((s) => s.id.equals(id))).write(
      OutboxEventsCompanion(
        status: Value(OutboxStatus.uploading.code),
        lastAttemptAt: Value(_clock.now()),
      ),
    );
  }

  /// Finalize an accepted server sync in one local transaction.
  Future<void> markUploaded({
    required OutboxEvent entry,
    required String syncLogId,
    String? serverId,
    String? serverMappingId,
    String? serverResponse,
  }) async {
    final now = _clock.now();

    await _db.transaction(() async {
      await (_db.update(
        _db.outboxEvents,
      )..where((s) => s.id.equals(entry.id))).write(
        OutboxEventsCompanion(
          status: Value(OutboxStatus.uploaded.code),
          uploadedAt: Value(now),
        ),
      );

      if (serverId != null &&
          serverId.isNotEmpty &&
          serverMappingId != null &&
          serverMappingId.isNotEmpty) {
        await _db
            .into(_db.serverMappings)
            .insert(
              ServerMappingsCompanion(
                id: Value(serverMappingId),
                entityType: Value(entry.entityType),
                localId: Value(entry.entityId),
                serverId: Value(serverId),
                mappedAt: Value(now),
              ),
            );
      }

      await _db
          .into(_db.syncAttempts)
          .insert(
            SyncAttemptsCompanion(
              id: Value(syncLogId),
              outboxEventId: Value(entry.id),
              direction: const Value('upload'),
              eventType: Value(entry.eventType),
              entityId: Value(entry.entityId),
              status: const Value('success'),
              responseSummary: Value(serverResponse),
              startedAt: Value(now),
              finishedAt: Value(now),
            ),
          );
    });
  }

  /// Mark entry as failed.
  Future<void> markFailed(String id, String error) async {
    final entry = await (_db.select(
      _db.outboxEvents,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    if (entry == null) return;

    final newRetryCount = entry.retryCount + 1;
    final newStatus = newRetryCount >= entry.maxRetries
        ? OutboxStatus.blocked.code
        : OutboxStatus.failed.code;

    await (_db.update(_db.outboxEvents)..where((s) => s.id.equals(id))).write(
      OutboxEventsCompanion(
        status: Value(newStatus),
        retryCount: Value(newRetryCount),
        lastError: Value(error),
        lastAttemptAt: Value(_clock.now()),
      ),
    );
  }

  Future<void> markBlocked(
    String id, {
    required String blockedReason,
    String? error,
  }) async {
    await (_db.update(_db.outboxEvents)..where((s) => s.id.equals(id))).write(
      OutboxEventsCompanion(
        status: Value(OutboxStatus.blocked.code),
        blockedReason: Value(blockedReason),
        lastError: Value(error),
        lastAttemptAt: Value(_clock.now()),
      ),
    );
  }

  /// Restore an event back to pending without consuming retries.
  ///
  /// Used when the upload API is unavailable. This is not a business failure
  /// and must not convert the event to failed/blocked.
  Future<void> restorePending(String id, {String? reason}) async {
    await (_db.update(_db.outboxEvents)..where((s) => s.id.equals(id))).write(
      OutboxEventsCompanion(
        status: Value(OutboxStatus.pending.code),
        lastError: Value(reason),
        lastAttemptAt: Value(_clock.now()),
      ),
    );
  }

  /// Recover sync entries left in uploading after a crash or app kill.
  Future<int> recoverStuckUploading({
    Duration leaseTimeout = const Duration(minutes: 15),
  }) async {
    final cutoff = _clock.now().subtract(leaseTimeout);
    final stuck =
        await (_db.select(_db.outboxEvents)..where(
              (s) =>
                  s.status.equals(OutboxStatus.uploading.code) &
                  (s.lastAttemptAt.isNull() |
                      s.lastAttemptAt.isSmallerThanValue(cutoff)),
            ))
            .get();

    for (final entry in stuck) {
      await (_db.update(
        _db.outboxEvents,
      )..where((s) => s.id.equals(entry.id))).write(
        OutboxEventsCompanion(
          status: Value(OutboxStatus.failed.code),
          lastError: const Value('Recovered from stale uploading state.'),
          lastAttemptAt: Value(_clock.now()),
        ),
      );
    }

    return stuck.length;
  }

  /// Log a sync attempt.
  Future<void> logAttempt({
    required String id,
    String? outboxEventId,
    required String eventType, // was int
    required String entityId,
    required bool success,
    String? serverResponse,
    String? errorMessage,
  }) async {
    final now = _clock.now();
    await _db
        .into(_db.syncAttempts)
        .insert(
          SyncAttemptsCompanion(
            id: Value(id),
            outboxEventId: Value(outboxEventId),
            direction: const Value('upload'),
            eventType: Value(eventType),
            entityId: Value(entityId),
            status: Value(success ? 'success' : OutboxStatus.failed.code),
            responseSummary: Value(serverResponse),
            errorMessage: Value(errorMessage),
            startedAt: Value(now),
            finishedAt: Value(now),
          ),
        );
  }

  /// Get count of pending entries.
  Future<int> getPendingCount() async {
    return _countWhere(
      _db.outboxEvents.status.equals(OutboxStatus.pending.code),
    );
  }

  /// Get count of failed or blocked entries.
  Future<int> getProblemCount() async {
    return _countWhere(
      _db.outboxEvents.status.equals(OutboxStatus.failed.code) |
          _db.outboxEvents.status.equals(OutboxStatus.blocked.code),
    );
  }

  Future<int> getRetryableCount() async {
    return _countWhere(
      _db.outboxEvents.status.equals(OutboxStatus.failed.code) &
          _db.outboxEvents.retryCount.isSmallerThan(
            _db.outboxEvents.maxRetries,
          ),
    );
  }

  Future<int> getBlockedCount() async {
    return _countWhere(
      _db.outboxEvents.status.equals(OutboxStatus.blocked.code),
    );
  }

  /// Get count of successfully synced entries.
  Future<int> getUploadedCount() async {
    return _countWhere(
      _db.outboxEvents.status.equals(OutboxStatus.uploaded.code),
    );
  }

  Future<int> _countWhere(Expression<bool> predicate) async {
    final count = countAll();
    final query = _db.selectOnly(_db.outboxEvents)
      ..addColumns([count])
      ..where(predicate);
    return query.map((row) => row.read(count) ?? 0).getSingle();
  }

  int _compareBySyncPriority(OutboxEvent a, OutboxEvent b) {
    final priorityCompare = _syncPriority(a).compareTo(_syncPriority(b));
    if (priorityCompare != 0) return priorityCompare;
    return a.createdAt.compareTo(b.createdAt);
  }

  int _syncPriority(OutboxEvent entry) {
    final type = OutboxEventType.fromCode(entry.eventType);

    switch (type) {
      case OutboxEventType.shiftOpened:
        return 10;
      case OutboxEventType.saleCreated:
      case OutboxEventType.returnCreated:
        return 20;
      case OutboxEventType.saleVoided:
        return 30;
      case OutboxEventType.shiftExtended:
        return 40;
      case OutboxEventType.shiftClosed:
        return 50;
      case null:
        return 999;
    }
  }
}
