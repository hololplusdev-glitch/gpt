// core/persistence/tables/all_tables.dart
// WHY: Barrel re-export for backward compatibility during migration.
// All table definitions now live in modular files.
// New code should import specific table files directly.

export 'installation_tables.dart';
export 'master_data_tables.dart';
export 'payment_tables.dart';
export 'sales_tables.dart';
export 'shift_tables.dart';
export 'sync_tables.dart';
export 'device_tables.dart';
export 'audit_tables.dart';
