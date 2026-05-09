// core/persistence/tables/device_tables.dart
// WHY: Local device config — NOT backend master data.
// Payment device profiles and printer profiles are local hardware setup.
// Connection-specific fields moved to settings_json.

import 'package:drift/drift.dart';

/// Payment device profiles — local hardware/integration config.
/// Replaces PaymentProfiles. NOT backend master data.
/// mode: 'manual','integrated'
/// provider: 'manual','geidea','pax','bank','other'
/// connection_type: 'none','lan','usb','sdk'
class PaymentDeviceProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  BoolColumn get enabled => boolean().withDefault(const Constant(false))();
  TextColumn get mode => text()();
  TextColumn get provider => text()();
  TextColumn get connectionType => text()();
  BoolColumn get requireReference =>
      boolean().withDefault(const Constant(false))();
  TextColumn get deviceTerminalRef => text().nullable()();
  TextColumn get merchantId => text().nullable()();
  TextColumn get endpoint => text().nullable()();
  IntColumn get timeoutSeconds => integer().nullable()();
  TextColumn get settingsJson => text().nullable()();
  TextColumn get lastTestStatus => text().nullable()();
  DateTimeColumn get lastTestAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Printer profiles — local printer hardware config.
/// Connection-specific fields (ip, port, bluetooth, usb, etc.) moved to settings_json.
/// role: 'cashier','kitchen'
/// connection_type: 'network_ip','usb','bluetooth','system_printer','android_built_in'
/// driver_type: 'escpos','system_printer','android_built_in'
/// arabic_mode: 'text','raster'
class PrinterProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get role => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get connectionType => text()();
  TextColumn get driverType => text()();
  IntColumn get paperWidthMm => integer().withDefault(const Constant(80))();
  TextColumn get arabicMode => text()();
  BoolColumn get autoPrint => boolean().withDefault(const Constant(true))();
  IntColumn get copies => integer().withDefault(const Constant(1))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  TextColumn get settingsJson => text().nullable()();
  TextColumn get lastTestStatus => text().nullable()();
  DateTimeColumn get lastTestAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
