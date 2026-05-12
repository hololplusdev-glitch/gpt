// core/persistence/database.dart
// WHY: Central Drift database declaration.
// Uses DB filename pos_data_v4.sqlite. No old pos_data.sqlite data preserved.
// No migration from old schema. PRAGMA foreign_keys = ON.

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:holol_POS/core/persistence/tables/all_tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    // -- Installation / Terminal --
    AppInstallation,
    SyncProfileTable,
    LocalUserPins,
    BranchProfile,
    PosMachines,
    ActivePosSessions,
    TerminalLocalSettings,
    InvoiceSequences,
    // -- Master Data --
    PosUsers,
    PosUserMachineAccess,
    Stores,
    PriceLevels,
    Items,
    ItemUnits,
    ItemBarcodes,
    ItemPrices,
    ItemGroups,
    Customers,
    // -- Payment Methods --
    PaymentMethods,
    // -- Shifts --
    Shifts,
    ShiftCashMovements,
    // -- Sales --
    Sales,
    SaleLines,
    SalePayments,
    SaleTaxSummary,
    InvoiceDocuments,
    HeldOrders,
    // -- Download Sync --
    MasterSyncState,
    ScopedSyncState,
    MasterSyncRuns,
    MasterSyncTypeRuns,
    MasterSyncPageRuns,
    // -- Upload Sync / Outbox --
    OutboxEvents,
    SyncAttempts,
    ServerMappings,
    // -- Devices --
    PaymentDeviceProfiles,
    PrinterProfiles,
    // -- Audit & Print --
    AuditLog,
    PrintJobs,
    PrintHistory,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(localUserPins);
        await m.addColumn(
          posUserMachineAccess,
          posUserMachineAccess.terminalName,
        );
        await m.addColumn(posUserMachineAccess, posUserMachineAccess.useTax);
      }

      if (from < 5) {
        await _dropLegacyShiftsSyncStatusIfExists();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );


  Future<void> _dropLegacyShiftsSyncStatusIfExists() async {
    final hasSyncStatus = await _tableHasColumn('shifts', 'sync_status');
    if (!hasSyncStatus) return;

    final hasCloseSummaryJson =
        await _tableHasColumn('shifts', 'close_summary_json');
    final closeSummaryJsonSource =
        hasCloseSummaryJson ? 'close_summary_json' : 'NULL';

    await transaction(() async {
      await customStatement('DROP INDEX IF EXISTS idx_shifts_machine_status');
      await customStatement('DROP INDEX IF EXISTS idx_shifts_opened_at');

      await customStatement('''
        CREATE TABLE shifts_clean (
          id TEXT NOT NULL PRIMARY KEY,
          server_id TEXT NULL,
          cust_code TEXT NULL,
          branch_no TEXT NULL,
          branch_year TEXT NULL,
          machine_no TEXT NULL,
          store_id TEXT NULL,
          price_level_id TEXT NULL,
          cashier_id TEXT NOT NULL,
          shift_type_id TEXT NULL,
          opening_cash REAL NOT NULL,
          expected_cash REAL NOT NULL DEFAULT 0.0,
          actual_cash REAL NOT NULL DEFAULT 0.0,
          difference REAL NOT NULL DEFAULT 0.0,
          status TEXT NOT NULL,
          opened_at INTEGER NOT NULL,
          closed_at INTEGER NULL,
          expires_at INTEGER NULL,
          closing_notes TEXT NULL,
          idempotency_key TEXT NOT NULL,
          close_summary_json TEXT NULL
        )
      ''');

      await customStatement('''
        INSERT INTO shifts_clean (
          id, server_id, cust_code, branch_no, branch_year, machine_no,
          store_id, price_level_id, cashier_id, shift_type_id, opening_cash,
          expected_cash, actual_cash, difference, status, opened_at,
          closed_at, expires_at, closing_notes, idempotency_key,
          close_summary_json
        )
        SELECT
          id, server_id, cust_code, branch_no, branch_year, machine_no,
          store_id, price_level_id, cashier_id, shift_type_id, opening_cash,
          COALESCE(expected_cash, 0.0),
          COALESCE(actual_cash, 0.0),
          COALESCE(difference, 0.0),
          status, opened_at, closed_at, expires_at, closing_notes,
          idempotency_key, $closeSummaryJsonSource
        FROM shifts
      ''');

      await customStatement('DROP TABLE shifts');
      await customStatement('ALTER TABLE shifts_clean RENAME TO shifts');

      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_shifts_machine_status '
        'ON shifts (machine_no, status)',
      );

      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_shifts_opened_at '
        'ON shifts (opened_at)',
      );
    });
  }

  Future<bool> _tableHasColumn(String tableName, String columnName) async {
    final rows = await customSelect('PRAGMA table_info($tableName)').get();

    for (final row in rows) {
      if (row.data['name'] == columnName) return true;
    }

    return false;
  }

  static QueryExecutor _openConnection() {
    // WHY: New filename ensures a clean DB after schema cleanup.
    return driftDatabase(name: 'pos_data_v4');
  }
}
