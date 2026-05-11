// core/persistence/tables/master_data_tables.dart
// WHY: Server-derived master data cached locally for offline operation.
// All tables use cust_code, source_updated_at, cached_at pattern.
// No Backend-style column names — clean internal schema.

import 'package:drift/drift.dart';

// =============================================================================
// USERS
// =============================================================================

/// Cached user records from backend USER p_type.
/// Auth API not yet implemented — fields kept compatible.
class PosUsers extends Table {
  TextColumn get id => text()();
  TextColumn get custCode => text()();
  TextColumn get sourceUserId => text().nullable()();
  TextColumn get username => text()();
  TextColumn get loginName => text().nullable()();
  TextColumn get displayName => text()();
  TextColumn get displayNameAr => text().nullable()();
  TextColumn get authHash => text().withDefault(const Constant(''))();
  TextColumn get roleId => text().nullable()();
  TextColumn get branchNo => text().nullable()();
  TextColumn get branchYear => text().nullable()();
  TextColumn get defaultStoreId => text().nullable()();
  TextColumn get defaultCashId => text().nullable()();
  TextColumn get accountId => text().nullable()();
  TextColumn get costCenterId => text().nullable()();
  TextColumn get userLevel => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get canLoginPos => boolean().withDefault(const Constant(true))();
  TextColumn get sourceUpdatedAt => text().nullable()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {custCode, id};
}

// =============================================================================
// DEVICE PRIVILEGES
// =============================================================================

/// User-to-POS-machine privileges from backend DEVICE_PRIV p_type.
/// DEVICE_PRIV is the authoritative runtime permission source: usr_id + mchn_nbr.
@TableIndex(name: 'idx_device_priv_cust_user', columns: {#custCode, #userId})
class PosUserMachineAccess extends Table {
  TextColumn get id => text()();
  TextColumn get custCode => text()();
  TextColumn get userId => text()();
  TextColumn get sourceUserId => text().nullable()();
  TextColumn get machineNo => text()();
  TextColumn get terminalName => text().nullable()();
  BoolColumn get useTax => boolean().nullable()();
  TextColumn get branchNo => text().nullable()();
  TextColumn get branchYear => text().nullable()();
  TextColumn get storeId => text().nullable()();
  TextColumn get priceLevelId => text().nullable()();
  TextColumn get defaultBankId => text().nullable()();
  BoolColumn get canUseMachine =>
      boolean().withDefault(const Constant(false))();
  TextColumn get sourceUpdatedAt => text().nullable()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {custCode, userId, machineNo};
}

// =============================================================================
// STORES
// =============================================================================

/// Cached store/warehouse records from backend STORE p_type.
@TableIndex(name: 'idx_stores_cust_id', columns: {#custCode, #id})
class Stores extends Table {
  TextColumn get id => text()();
  TextColumn get custCode => text()();
  TextColumn get branchNo => text().nullable()();
  TextColumn get name => text()();
  TextColumn get nameAr => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  TextColumn get sourceUpdatedAt => text().nullable()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// =============================================================================
// PRICE LEVELS
// =============================================================================

/// Cached price level definitions from backend PRICE_LEVEL p_type.
@TableIndex(name: 'idx_price_levels_cust_id', columns: {#custCode, #id})
class PriceLevels extends Table {
  TextColumn get id => text()();
  TextColumn get custCode => text()();
  TextColumn get name => text()();
  TextColumn get nameAr => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  TextColumn get sourceUpdatedAt => text().nullable()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// =============================================================================
// ITEMS
// =============================================================================

/// Cached item/product catalog from backend ITEM p_type.
@TableIndex(name: 'idx_items_cust_id', columns: {#custCode, #id})
class Items extends Table {
  TextColumn get id => text()();
  TextColumn get custCode => text()();
  TextColumn get code => text().nullable()();
  TextColumn get name => text()();
  TextColumn get nameAr => text().nullable()();
  TextColumn get groupId => text().nullable()();
  TextColumn get defaultUnitId => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  RealColumn get taxRate => real().withDefault(const Constant(0.0))();
  BoolColumn get allowDiscount =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get useQtyFraction =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get useExpiry => boolean().withDefault(const Constant(false))();
  BoolColumn get useBatch => boolean().withDefault(const Constant(false))();
  BoolColumn get inactive => boolean().withDefault(const Constant(false))();
  BoolColumn get noSale => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get sourceUpdatedAt => text().nullable()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// =============================================================================
// ITEM UNITS
// =============================================================================

/// Item units (each, kg, box, etc.) from backend ITEM_UNIT p_type.
/// Barcode is NOT source of truth here — item_barcodes owns that.
@TableIndex(name: 'idx_item_units_cust_item', columns: {#custCode, #itemId})
@TableIndex(name: 'idx_item_units_item_id', columns: {#itemId})
class ItemUnits extends Table {
  TextColumn get id => text()();
  TextColumn get custCode => text()();
  TextColumn get itemId => text()();
  TextColumn get sourceUnitId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get nameAr => text().nullable()();
  RealColumn get conversionFactor => real().withDefault(const Constant(1.0))();
  RealColumn get unitSize => real().nullable()();
  BoolColumn get inactive => boolean().withDefault(const Constant(false))();
  BoolColumn get noSale => boolean().withDefault(const Constant(false))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  TextColumn get sourceUpdatedAt => text().nullable()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// =============================================================================
// ITEM BARCODES — single source of truth for barcodes
// =============================================================================

/// Item barcodes — authoritative source for barcode lookups.
/// Multiple barcodes per item/unit supported.
@TableIndex(
  name: 'idx_item_barcodes_cust_barcode',
  columns: {#custCode, #barcode},
)
@TableIndex(name: 'idx_item_barcodes_barcode', columns: {#barcode})
class ItemBarcodes extends Table {
  TextColumn get id => text()();
  TextColumn get custCode => text()();
  TextColumn get itemId => text()();
  TextColumn get unitId => text().nullable()();
  TextColumn get barcode => text()();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// =============================================================================
// ITEM PRICES
// =============================================================================

/// Item prices per price level, store, and quantity tier.
/// From backend ITEM_PRICE p_type.
@TableIndex(
  name: 'idx_item_prices_lookup',
  columns: {#custCode, #itemId, #unitId, #storeId, #priceLevelId},
)
class ItemPrices extends Table {
  TextColumn get id => text()();
  TextColumn get custCode => text()();
  TextColumn get itemId => text()();
  TextColumn get unitId => text().nullable()();
  TextColumn get storeId => text().nullable()();
  TextColumn get priceLevelId => text().nullable()();
  RealColumn get fromQty => real().nullable()();
  RealColumn get toQty => real().nullable()();
  RealColumn get unitPrice => real()();
  RealColumn get costPrice => real().nullable()();
  DateTimeColumn get effectiveFrom => dateTime().nullable()();
  DateTimeColumn get effectiveTo => dateTime().nullable()();
  TextColumn get sourceUpdatedAt => text().nullable()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// =============================================================================
// ITEM GROUPS
// =============================================================================

/// Item groups / categories. Hierarchical via parent_id.
class ItemGroups extends Table {
  TextColumn get id => text()();
  TextColumn get custCode => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get nameAr => text().nullable()();
  TextColumn get iconName => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// =============================================================================
// CUSTOMERS
// =============================================================================

/// Cached customer records from backend CUSTOMER p_type.
/// Replaces BackendCustomersCache — clean internal schema.
@TableIndex(name: 'idx_customers_cust_id', columns: {#custCode, #id})
class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get custCode => text()();
  TextColumn get name => text()();
  TextColumn get accountId => text().nullable()();
  TextColumn get taxNumber => text().nullable()();
  TextColumn get mobile => text().nullable()();
  RealColumn get discountRate => real().withDefault(const Constant(0.0))();
  BoolColumn get inactive => boolean().withDefault(const Constant(false))();
  TextColumn get sourceUpdatedAt => text().nullable()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
