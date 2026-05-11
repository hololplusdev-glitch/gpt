// core/persistence/tables/payment_tables.dart
// WHY: Unified payment methods — merges old Backend payment tables.

import 'package:drift/drift.dart';

/// Unified payment methods — cash, bank, card types.
/// type stored as stable string code: 'cash', 'bank', 'card', etc.
class PaymentMethods extends Table {
  TextColumn get id => text()();
  TextColumn get tenantCode => text()();
  TextColumn get type => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get nameAr => text().nullable()();
  TextColumn get sourceType => text().nullable()();
  TextColumn get cashId => text().nullable()();
  TextColumn get currencyId => text().nullable()();
  TextColumn get bankId => text().nullable()();
  TextColumn get bankAccountId => text().nullable()();
  TextColumn get cardTypeId => text().nullable()();
  TextColumn get commissionAccountId => text().nullable()();
  RealColumn get commissionRate => real().withDefault(const Constant(0.0))();
  IntColumn get dueIntervalDays => integer().nullable()();
  TextColumn get branchNo => text().nullable()();
  TextColumn get branchYear => text().nullable()();
  BoolColumn get requiresReference =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get sourceUpdatedAt => text().nullable()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['UNIQUE (tenant_code, code)'];
}
