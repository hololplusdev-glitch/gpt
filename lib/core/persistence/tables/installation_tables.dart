// core/persistence/tables/installation_tables.dart
// WHY: Installation, branch profile, terminal profile, local settings, and
// invoice sequences. Separates server-derived terminal config from local
// device/app installation data.

import 'package:drift/drift.dart';

// =============================================================================
// APP INSTALLATION — local device identity (not server POS machine config)
// =============================================================================

/// Tracks the physical device / app installation.
/// One row per device. Not synced from server.
class AppInstallation extends Table {
  TextColumn get id => text()();
  TextColumn get installationId => text()();
  TextColumn get platform => text()();
  TextColumn get deviceName => text().nullable()();
  TextColumn get deviceModel => text().nullable()();
  TextColumn get osVersion => text().nullable()();
  TextColumn get appVersion => text().nullable()();
  IntColumn get dbSchemaVersion => integer().withDefault(const Constant(0))();
  DateTimeColumn get firstInstalledAt => dateTime()();
  DateTimeColumn get lastOpenedAt => dateTime()();
  DateTimeColumn get registeredAt => dateTime().nullable()();
  TextColumn get lastTerminalId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class BranchProfile extends Table {
  TextColumn get id => text()();
  TextColumn get tenantCode => text()();
  TextColumn get branchNo => text()();
  TextColumn get branchYear => text().nullable()();
  TextColumn get branchCode => text().nullable()();
  TextColumn get name => text()();
  TextColumn get nameAr => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get taxNumber => text().nullable()();
  TextColumn get commercialRegistrationNo => text().nullable()();
  TextColumn get commercialName => text().nullable()();
  TextColumn get invoiceType => text().nullable()();
  TextColumn get streetName => text().nullable()();
  TextColumn get buildingNo => text().nullable()();
  TextColumn get cityName => text().nullable()();
  TextColumn get postalZone => text().nullable()();
  TextColumn get businessCategory => text().nullable()();
  TextColumn get sourceUpdatedAt => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncProfileTable extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get baseUrl => text()();
  TextColumn get custCode => text()();
  TextColumn get bootstrapUserId => text().withDefault(const Constant('1'))();
  IntColumn get pageLimit => integer().withDefault(const Constant(100))();
  IntColumn get timeoutSeconds => integer().nullable()();
  BoolColumn get setupCompleted => boolean().withDefault(const Constant(false))();
  BoolColumn get initialSyncCompleted =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastFullSyncAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class PosMachines extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().nullable()();
  TextColumn get custCode => text()();
  TextColumn get machineNo => text()();
  TextColumn get branchNo => text().nullable()();
  TextColumn get branchYear => text().nullable()();
  TextColumn get storeId => text().nullable()();
  TextColumn get priceLevelId => text().nullable()();
  TextColumn get cashId => text().nullable()();
  TextColumn get defaultBankId => text().nullable()();
  TextColumn get defaultCardTypeId => text().nullable()();
  TextColumn get invoiceSeries => text().nullable()();
  TextColumn get returnInvoiceSeries => text().nullable()();
  BoolColumn get useTax => boolean().withDefault(const Constant(true))();
  BoolColumn get priceIncludesTax =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get requiresShift => boolean().withDefault(const Constant(true))();
  TextColumn get printerName => text().nullable()();
  BoolColumn get autoPrint => boolean().withDefault(const Constant(false))();
  BoolColumn get allowDuplicateItems =>
      boolean().withDefault(const Constant(false))();
  TextColumn get lastServerTime => text().nullable()();
  DateTimeColumn get lastBootstrapAt => dateTime().nullable()();
  TextColumn get sourceUpdatedAt => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ActivePosSessionRow')
class ActivePosSessions extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get sessionId => text().nullable()();
  TextColumn get custCode => text()();
  TextColumn get activeUserId => text()();
  TextColumn get activeMachineNo => text()();
  TextColumn get openShiftId => text().nullable()();
  DateTimeColumn get loginAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class TerminalLocalSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

class InvoiceSequences extends Table {
  TextColumn get id => text()();
  TextColumn get custCode => text()();
  TextColumn get branchNo => text()();
  TextColumn get machineNo => text()();
  TextColumn get userId => text()();
  TextColumn get sequenceType => text().withDefault(const Constant('sale'))();
  IntColumn get currentValue => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'UNIQUE (cust_code, branch_no, machine_no, user_id, sequence_type)',
  ];
}
