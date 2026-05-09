// core/persistence/daos/audit_dao.dart
// WHY: Every sensitive operation must be logged locally.
// This DAO writes to audit_log for traceability and compliance.

import 'package:drift/drift.dart';
import 'package:pos_flutter/core/persistence/database.dart';
import 'package:pos_flutter/shared/models/enums.dart';
import 'package:pos_flutter/core/services/time/clock.dart';

/// Data access for audit logging.
class AuditDao {
  final AppDatabase _db;

  final Clock _clock;

  AuditDao(this._db, {Clock clock = const SystemClock()}) : _clock = clock;

  /// Write an audit event.
  Future<void> log({
    required String id,
    required AuditAction action,
    required String actorId,
    String? actorName,
    String? supervisorId,
    String? targetType,
    String? targetId,
    String? detailsJson,
    required String terminalId,
    DateTime? timestamp,
  }) async {
    await _db
        .into(_db.auditLog)
        .insert(
          AuditLogCompanion(
            id: Value(id),
            action: Value(action.code),
            actorId: Value(actorId),
            actorName: Value(actorName),
            supervisorId: Value(supervisorId),
            targetType: Value(targetType),
            targetId: Value(targetId),
            detailsJson: Value(detailsJson),
            terminalId: Value(terminalId),
            createdAt: Value(timestamp ?? _clock.now()),
          ),
        );
  }

  /// Get recent audit entries.
  Future<List<AuditLogData>> getRecent({int limit = 50}) async {
    return (_db.select(_db.auditLog)
          ..orderBy([(a) => OrderingTerm.desc(a.createdAt)])
          ..limit(limit))
        .get();
  }

  /// Get audit entries for a specific entity.
  Future<List<AuditLogData>> getForEntity(
    String entityType,
    String entityId,
  ) async {
    return (_db.select(_db.auditLog)
          ..where(
            (a) =>
                a.targetType.equals(entityType) & a.targetId.equals(entityId),
          )
          ..orderBy([(a) => OrderingTerm.desc(a.createdAt)]))
        .get();
  }
}
