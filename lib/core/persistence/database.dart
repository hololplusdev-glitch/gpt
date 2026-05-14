// core/persistence/database.dart
// WHY: Central Drift database declaration.
// Production storage policy:
// - Uses a stable DB filename: pos_data.sqlite
// - Windows stores DB under C:\ProgramData\HololPlusPOS\data
// - Android/iOS/macOS/Linux use application support directory
// - PRAGMA foreign_keys = ON

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:holol_POS/core/persistence/tables/all_tables.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

    // -- Sales --
    Sales,
    SaleLines,
    SalePayments,
    SaleTaxSummary,
    InvoiceDocuments,
    HeldOrders,

    // -- Download Sync --
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
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // TODO: Add production migrations before shipping.
      // Do not delete or recreate the database in production.
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');

      // Good defaults for local POS durability/performance.
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA synchronous = NORMAL');
      await customStatement('PRAGMA busy_timeout = 5000');
    },
  );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFile = await _resolveDatabaseFile();
      await dbFile.parent.create(recursive: true);

      return NativeDatabase.createInBackground(dbFile);
    });
  }

  static Future<File> _resolveDatabaseFile() async {
    const dbFileName = 'pos_data.sqlite';

    final dataDirectory = await _resolveDataDirectory();

    return File(p.join(dataDirectory.path, dbFileName));
  }

  static Future<Directory> _resolveDataDirectory() async {
    if (Platform.isWindows) {
      return _windowsDataDirectory();
    }

    if (Platform.isLinux) {
      return _linuxDataDirectory();
    }

    // Android / iOS / macOS:
    // Uses application support directory, not temporary/cache.
    final supportDirectory = await getApplicationSupportDirectory();

    return Directory(p.join(supportDirectory.path, 'data'));
  }

  static Future<Directory> _windowsDataDirectory() async {
    final programData = Platform.environment['PROGRAMDATA'];

    if (programData != null && programData.trim().isNotEmpty) {
      return Directory(p.join(programData, 'HololPlusPOS', 'data'));
    }

    // Fallback if PROGRAMDATA is unavailable.
    final supportDirectory = await getApplicationSupportDirectory();

    return Directory(p.join(supportDirectory.path, 'data'));
  }

  static Future<Directory> _linuxDataDirectory() async {
    // Safer default for normal desktop apps without root/service install.
    // If you package POS as a Linux service, move this to:
    // /var/lib/hololplus-pos/data
    final supportDirectory = await getApplicationSupportDirectory();

    return Directory(p.join(supportDirectory.path, 'data'));
  }
}
