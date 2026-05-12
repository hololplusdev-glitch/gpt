// core/persistence/tables/shift_tables.dart
// WHY: Shift lifecycle tables — status stored as stable string codes.
// Live totals computed from sales; final snapshot saved in close_summary_json.

import 'package:drift/drift.dart';

/// Shift records.
/// status: 'open','closing','closed'
@TableIndex(name: 'idx_shifts_machine_status', columns: {#machineNo, #status})
@TableIndex(name: 'idx_shifts_opened_at', columns: {#openedAt})
class Shifts extends Table {
  TextColumn get id => text()();
  TextColumn get serverId => text().nullable()();
  TextColumn get branchNo => text().nullable()();
  TextColumn get branchYear => text().nullable()();
  TextColumn get machineNo => text().nullable()();
  TextColumn get storeId => text().nullable()();
  TextColumn get priceLevelId => text().nullable()();
  TextColumn get cashierId => text()();
  TextColumn get shiftTypeId => text().nullable()();
  RealColumn get openingCash => real()();
  RealColumn get expectedCash => real().withDefault(const Constant(0.0))();
  RealColumn get actualCash => real().withDefault(const Constant(0.0))();
  RealColumn get difference => real().withDefault(const Constant(0.0))();
  TextColumn get status => text()(); // stable string code
  DateTimeColumn get openedAt => dateTime()();
  DateTimeColumn get closedAt => dateTime().nullable()();
  DateTimeColumn get expiresAt => dateTime().nullable()();
  TextColumn get closingNotes => text().nullable()();
  TextColumn get idempotencyKey => text()();
  TextColumn get closeSummaryJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
