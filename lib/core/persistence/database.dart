// core/persistence/database.dart
// WHY: Central Drift database declaration.
// Uses DB filename pos_data_v2.sqlite. No old pos_data.sqlite data preserved.
// No migration from old schema. PRAGMA foreign_keys = ON.

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:pos_flutter/core/persistence/tables/all_tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    // -- Installation / Terminal --
    AppInstallation,
    SyncProfileTable,
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
    SaleAdjustments,
    SaleTaxSummary,
    InvoiceDocuments,
    HeldOrders,
    HeldOrderLines,
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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static QueryExecutor _openConnection() {
    // WHY: New filename ensures a clean DB. Old pos_data.sqlite is abandoned.
    return driftDatabase(name: 'pos_data_v2');
  }
}
