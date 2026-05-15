// core/persistence/daos/shift_dao.dart
// WHY: DB access for shift records. Handles create, update, close, and resume.

import 'package:drift/drift.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/core/persistence/daos/dao_shared.dart';

/// Data access for shift operations.
class ShiftDao {
  final AppDatabase _db;

  ShiftDao(this._db);

  /// Get the current open shift for a terminal.
  /// If cashierId is provided, only that cashier's open shift is returned.
  Future<Shift?> getOpenShift(String machineNo, {String? cashierId}) async {
    final query = _db.select(_db.shifts)
      ..where(
        (s) =>
            s.machineNo.equals(machineNo) &
            (s.status.equals('open') | s.status.equals('closing')),
      );

    final normalizedCashierId = cashierId?.trim();
    if (normalizedCashierId != null && normalizedCashierId.isNotEmpty) {
      query.where((s) => s.cashierId.equals(normalizedCashierId));
    }

    query.limit(1);
    return query.getSingleOrNull();
  }

  /// Get shift by local ID.
  Future<Shift?> getById(String id) async {
    return (_db.select(
      _db.shifts,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  Future<void> createShiftEnvelope({
    required ShiftsCompanion shift,
    required OutboxEventsCompanion outboxEntry,
    required AuditLogCompanion auditLogEntry,
  }) async {
    await _db.transaction(() async {
      await _db.into(_db.shifts).insert(shift);
      await _db.into(_db.outboxEvents).insert(outboxEntry);
      await _db.into(_db.auditLog).insert(auditLogEntry);
    });
  }

  Future<void> closeShiftEnvelope({
    required String localId,
    required double expectedCash,
    required double actualCash,
    required double difference,
    required double grossSales,
    required double netSales,
    required double cashSales,
    required double cardSales,
    required double otherSales,
    required double cashReturns,
    required double totalDiscounts,
    required double totalTaxes,
    required double totalReturns,
    required double totalVoids,
    required int saleCount,
    required OutboxEventsCompanion outboxEntry,
    required AuditLogCompanion auditLogEntry,
    required DateTime closedAt,
    String? closingNotes,
  }) async {
    final summaryJson = DaoShiftCloseSummaryJson.encode(
      grossSales: grossSales,
      netSales: netSales,
      cashSales: cashSales,
      cardSales: cardSales,
      otherSales: otherSales,
      cashReturns: cashReturns,
      totalDiscounts: totalDiscounts,
      totalTaxes: totalTaxes,
      totalReturns: totalReturns,
      totalVoids: totalVoids,
      saleCount: saleCount,
    );

    await _db.transaction(() async {
      await (_db.update(_db.shifts)..where((s) => s.id.equals(localId))).write(
        ShiftsCompanion(
          expectedCash: Value(expectedCash),
          actualCash: Value(actualCash),
          difference: Value(difference),
          status: const Value('closed'),
          closedAt: Value(closedAt),
          closingNotes: Value(closingNotes),
          closeSummaryJson: Value(summaryJson),
        ),
      );
      await _db.into(_db.outboxEvents).insert(outboxEntry);
      await _db.into(_db.auditLog).insert(auditLogEntry);
    });
  }

  Future<void> extendShiftEnvelope({
    required String localId,
    required DateTime newExpiry,
    required OutboxEventsCompanion outboxEntry,
    required AuditLogCompanion auditLogEntry,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.shifts)..where((s) => s.id.equals(localId))).write(
        ShiftsCompanion(expiresAt: Value(newExpiry)),
      );
      await _db.into(_db.outboxEvents).insert(outboxEntry);
      await _db.into(_db.auditLog).insert(auditLogEntry);
    });
  }

  /// Update shift sync status.
  Future<void> updateServerId(String localId, String serverId) async {
    await (_db.update(_db.shifts)..where((s) => s.id.equals(localId))).write(
      ShiftsCompanion(serverId: Value(serverId)),
    );
  }
}
