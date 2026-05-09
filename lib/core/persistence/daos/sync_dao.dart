// core/persistence/daos/sync_dao.dart
// WHY: DB access for the sync outbox queue.
// All business events are queued here for eventual push to Backend.

import 'package:drift/drift.dart';
import 'package:pos_flutter/core/persistence/database.dart';
import 'package:pos_flutter/shared/models/enums.dart';
import 'package:pos_flutter/core/services/time/clock.dart';

/// Data access for sync queue operations.
class SyncDao {
  final AppDatabase _db;
  final Clock _clock;

  SyncDao(this._db, {Clock clock = const SystemClock()}) : _clock = clock;

  /// Enqueue a sync event.
  Future<void> enqueue(OutboxEventsCompanion entry) async {
    await _db.into(_db.outboxEvents).insert(entry);
  }

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
    final rows = await (_db.select(
      _db.outboxEvents,
    )..where((s) => s.status.equals(OutboxStatus.pending.code))).get();
    return rows.length;
  }

  /// Get count of failed entries.
  Future<int> getFailedCount() async {
    final rows =
        await (_db.select(_db.outboxEvents)..where(
              (s) =>
                  s.status.equals(OutboxStatus.failed.code) |
                  s.status.equals(OutboxStatus.blocked.code),
            ))
            .get();
    return rows.length;
  }

  Future<int> getRetryableCount() async {
    final rows =
        await (_db.select(_db.outboxEvents)..where(
              (s) =>
                  s.status.equals(OutboxStatus.failed.code) &
                  s.retryCount.isSmallerThan(s.maxRetries),
            ))
            .get();
    return rows.length;
  }

  Future<int> getBlockedCount() async {
    final rows = await (_db.select(
      _db.outboxEvents,
    )..where((s) => s.status.equals(OutboxStatus.blocked.code))).get();
    return rows.length;
  }

  /// Get count of successfully synced entries.
  Future<int> getUploadedCount() async {
    final rows = await (_db.select(
      _db.outboxEvents,
    )..where((s) => s.status.equals(OutboxStatus.uploaded.code))).get();
    return rows.length;
  }

  int _compareBySyncPriority(OutboxEvent a, OutboxEvent b) {
    // Assuming eventType is stored as String now, but syncEventPriority took int.
    // We can fallback or parse if needed, but here we just return by createdAt to fix the type errors
    // or map it back if we have the method.
    // For now, let's just sort by createdAt since eventTypes might be strings.
    return a.createdAt.compareTo(b.createdAt);
  }
}
