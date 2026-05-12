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
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Development-only schema cleanup. This project currently does not ship
      // production migrations; existing dev DBs should be recreated.
      // Keep this empty to avoid carrying removed columns forward.
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static QueryExecutor _openConnection() {
    // WHY: New filename ensures a clean DB after schema cleanup.
    return driftDatabase(name: 'pos_data_v4');
  }
}
