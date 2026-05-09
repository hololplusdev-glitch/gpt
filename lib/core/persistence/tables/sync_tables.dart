// core/persistence/tables/sync_tables.dart
// WHY: Separates download sync (master_sync_*) from upload sync (outbox/attempts).
// Download = master data from server. Upload = local events to server.

import 'package:drift/drift.dart';

// =============================================================================
// DOWNLOAD SYNC — master data sync tracking
// =============================================================================

/// Per-master-type high-water mark and last status.
class MasterSyncState extends Table {
  TextColumn get syncType => text()();
  TextColumn get lastSuccessTime => text().nullable()();
  TextColumn get lastServerTime => text().nullable()();
  TextColumn get lastStatus => text().withDefault(const Constant('never'))();
  TextColumn get lastError => text().nullable()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {syncType};
}

class ScopedSyncState extends Table {
  TextColumn get syncKey => text()();
  TextColumn get type => text()();
  TextColumn get scopeJson => text()();
  TextColumn get lastServerTime => text().nullable()();
  TextColumn get lastSuccessTime => text().nullable()();
  TextColumn get lastStatus => text().withDefault(const Constant('never'))();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {syncKey};
}

/// Full master-data sync run history.
class MasterSyncRuns extends Table {
  TextColumn get id => text()();
  TextColumn get mode => text()();
  TextColumn get status => text()();
  TextColumn get tenantCode => text().nullable()();
  TextColumn get sourceUserId => text().nullable()();
  TextColumn get branchNo => text().nullable()();
  TextColumn get machineNo => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  IntColumn get totalRowsReceived => integer().withDefault(const Constant(0))();
  IntColumn get totalRowsSaved => integer().withDefault(const Constant(0))();
  IntColumn get failedTypesCount => integer().withDefault(const Constant(0))();
  TextColumn get errorSummary => text().nullable()();
  TextColumn get detailsJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-p_type run details for a master-data sync run.
class MasterSyncTypeRuns extends Table {
  TextColumn get id => text()();
  TextColumn get runId => text()();
  TextColumn get syncType => text()();
  TextColumn get status => text()();
  TextColumn get oldServerTime => text().nullable()();
  TextColumn get newServerTime => text().nullable()();
  TextColumn get sentLastUpdate => text().nullable()();
  IntColumn get rowsReceived => integer().withDefault(const Constant(0))();
  IntColumn get rowsSaved => integer().withDefault(const Constant(0))();
  IntColumn get pagesCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  TextColumn get errorCode => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  TextColumn get detailsJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-page diagnostics for master-data pagination.
class MasterSyncPageRuns extends Table {
  TextColumn get id => text()();
  TextColumn get typeRunId => text()();
  TextColumn get syncType => text()();
  IntColumn get pageNo => integer()();
  IntColumn get offsetValue => integer()();
  IntColumn get limitValue => integer()();
  IntColumn get paginationTotal => integer().nullable()();
  TextColumn get hasMore => text().nullable()();
  IntColumn get rowsReceived => integer().withDefault(const Constant(0))();
  TextColumn get serverTime => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get status => text()();
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// =============================================================================
// UPLOAD SYNC — outbox for local events destined for server
// =============================================================================

/// Outbox events — replaces Outbox.
/// event_type: 'sale_created','sale_voided','shift_closed', etc.
/// entity_type: 'sale','shift','held_order', etc.
/// status: 'pending','uploading','uploaded','failed','blocked'
@TableIndex(
  name: 'idx_outbox_status_created_at',
  columns: {#status, #createdAt},
)
@TableIndex(name: 'idx_outbox_entity', columns: {#entityType, #entityId})
@TableIndex(name: 'idx_outbox_event_type', columns: {#eventType})
class OutboxEvents extends Table {
  TextColumn get id => text()();
  TextColumn get eventType => text()(); // stable string code
  TextColumn get entityType => text()(); // stable string code
  TextColumn get entityId => text()();
  TextColumn get payloadJson => text()();
  TextColumn get status => text()(); // stable string code
  TextColumn get blockedReason => text().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  IntColumn get maxRetries => integer().withDefault(const Constant(5))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get uploadedAt => dateTime().nullable()();
  TextColumn get idempotencyKey => text().unique()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Sync attempts — replaces SyncLogs. Not audit.
/// direction: 'upload','download'
/// status: 'success','failed','timeout'
@TableIndex(
  name: 'idx_sync_attempts_outbox_event_id',
  columns: {#outboxEventId},
)
@TableIndex(name: 'idx_sync_attempts_started_at', columns: {#startedAt})
class SyncAttempts extends Table {
  TextColumn get id => text()();
  TextColumn get outboxEventId =>
      text().nullable().references(OutboxEvents, #id)();
  TextColumn get direction => text()();
  TextColumn get eventType => text()();
  TextColumn get entityId => text()();
  TextColumn get status => text()();
  TextColumn get requestSummary => text().nullable()();
  TextColumn get responseSummary => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Maps local IDs to server IDs after upload acknowledgement.
class ServerMappings extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get localId => text()();
  TextColumn get serverId => text()();
  DateTimeColumn get mappedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['UNIQUE (entity_type, local_id)'];
}
