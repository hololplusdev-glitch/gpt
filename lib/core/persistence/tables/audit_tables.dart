// core/persistence/tables/audit_tables.dart
// WHY: Audit log for compliance and print job queue for recovery.
// Audit is NOT sync — these are separate concerns.

import 'package:drift/drift.dart';
import 'package:holol_POS/core/persistence/tables/sales_tables.dart';

/// Audit log — who did what. Not a sync log.
/// action stored as stable string code:
/// 'login','logout','sale_completed','sale_voided','shift_opened', etc.
@TableIndex(name: 'idx_audit_log_created_at', columns: {#createdAt})
@TableIndex(name: 'idx_audit_log_target', columns: {#targetType, #targetId})
class AuditLog extends Table {
  TextColumn get id => text()();
  TextColumn get action => text()(); // stable string code
  TextColumn get actorId => text()();
  TextColumn get actorName => text().nullable()();
  TextColumn get supervisorId => text().nullable()();
  TextColumn get targetType => text().nullable()();
  TextColumn get targetId => text().nullable()();
  TextColumn get detailsJson => text().nullable()();
  TextColumn get terminalId => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Retryable print job queue with recovery support.
/// status: 'pending','printing','printed','failed','cancelled'
/// document_type: 'invoice_receipt','invoice_receipt_copy'
@TableIndex(
  name: 'idx_print_jobs_status_created_at',
  columns: {#status, #createdAt},
)
@TableIndex(name: 'idx_print_jobs_sale_id', columns: {#saleId})
class PrintJobs extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get printerProfileId => text()();
  TextColumn get printerRoleSnapshot => text()();
  TextColumn get documentType => text()();
  TextColumn get status => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get maxAttempts => integer().withDefault(const Constant(3))();
  TextColumn get payloadSnapshotJson => text()();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get lockedAt => dateTime().nullable()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get printedAt => dateTime().nullable()();
  TextColumn get createdBy => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Print history — audit trail for printed/reprinted receipts.
@TableIndex(name: 'idx_print_history_sale_id', columns: {#saleId})
class PrintHistory extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get invoiceNo => text()();
  TextColumn get printJobId => text().nullable()();
  TextColumn get printerProfileId => text().nullable()();
  TextColumn get printerNameSnapshot => text().nullable()();
  TextColumn get printerRoleSnapshot => text().nullable()();
  TextColumn get documentType => text()();
  BoolColumn get isReprint => boolean().withDefault(const Constant(false))();
  IntColumn get copyNumber => integer().withDefault(const Constant(0))();
  TextColumn get reprintReason => text().nullable()();
  TextColumn get printedBy => text().nullable()();
  TextColumn get status => text()();
  TextColumn get failureReason => text().nullable()();
  TextColumn get payloadHash => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get printedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
