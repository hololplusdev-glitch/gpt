// core/persistence/daos/catalog_dao.dart
// WHY: DB access for catalog data — items, units, barcodes, prices, groups, taxes.
// Returns raw Drift data objects; mapping to domain models happens in repositories.

import 'package:drift/drift.dart';
import 'package:holol_POS/core/persistence/database.dart' hide Customer;
import 'package:holol_POS/shared/models/customer.dart';
import 'package:holol_POS/shared/models/sellable_item_snapshot.dart';

/// Data access for catalog tables.
class CatalogDao {
  final AppDatabase _db;

  CatalogDao(this._db);

  // ---------------------------------------------------------------------------
  // Sellability
  // ---------------------------------------------------------------------------

  Future<bool> _isItemSellableById(
    String itemId,
    String storeId,
    String priceLevelId,
  ) async {
    final row = await _db
        .customSelect(
          '''
      SELECT 1
      FROM items i
      WHERE i.id = ?
        AND i.inactive = 0
        AND i.no_sale = 0
        AND ${_sellablePriceExistsSql('i')}
      LIMIT 1
      ''',
          variables: [
            Variable<String>(itemId),
            Variable<String>(priceLevelId),
            Variable<String>(storeId),
          ],
          readsFrom: {_db.items, _db.itemPrices},
        )
        .getSingleOrNull();
    return row != null;
  }

  // ---------------------------------------------------------------------------
  // Items
  // ---------------------------------------------------------------------------

  /// Get all active items.
  Future<List<Item>> getActiveItems(String storeId, String priceLevelId) async {
    return _selectSellableItems(storeId: storeId, priceLevelId: priceLevelId);
  }

  /// Get items by group.
  Future<List<Item>> getItemsByGroup(
    String groupId,
    String storeId,
    String priceLevelId,
  ) async {
    return _selectSellableItems(
      storeId: storeId,
      priceLevelId: priceLevelId,
      extraWhere: 'AND i.group_id = ?',
      extraVariables: [Variable<String>(groupId)],
    );
  }

  /// Search items by name or code.
  Future<List<Item>> searchItems(
    String query,
    String storeId,
    String priceLevelId,
  ) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return [];
    return _selectSellableItems(
      storeId: storeId,
      priceLevelId: priceLevelId,
      extraWhere:
          'AND (i.name LIKE ? OR COALESCE(i.name_ar, \'\') LIKE ? OR COALESCE(i.code, \'\') LIKE ?)',
      extraVariables: [
        Variable<String>('%$normalized%'),
        Variable<String>('%$normalized%'),
        Variable<String>('%$normalized%'),
      ],
    );
  }

  Future<List<Item>> _selectSellableItems({
    required String storeId,
    required String priceLevelId,
    String extraWhere = '',
    List<Variable> extraVariables = const [],
  }) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT i.*
      FROM items i
      WHERE i.inactive = 0
        AND i.no_sale = 0
        AND ${_sellablePriceExistsSql('i')}
        $extraWhere
      ORDER BY i.sort_order ASC
      ''',
          variables: [
            Variable<String>(priceLevelId),
            Variable<String>(storeId),
            ...extraVariables,
          ],
          readsFrom: {_db.items, _db.itemPrices},
        )
        .get();
    return rows.map((row) => _db.items.map(row.data)).toList();
  }

  String _sellablePriceExistsSql(String itemAlias) {
    return '''
EXISTS (
  SELECT 1
  FROM item_prices p
  WHERE p.item_id = $itemAlias.id
    AND p.price_level_id = ?
    AND p.unit_price > 0
    AND p.store_id = ?
)
''';
  }

  /// Get item by ID.
  Future<Item?> getItemById(String id) async {
    return (_db.select(
      _db.items,
    )..where((i) => i.id.equals(id))).getSingleOrNull();
  }

  // ---------------------------------------------------------------------------
  // Barcodes
  // ---------------------------------------------------------------------------

  /// Find item by barcode. Returns item+unit+barcode data.
  Future<ItemBarcodeLookup?> lookupBarcode(
    String barcode,
    String storeId,
    String priceLevelId,
  ) async {
    final candidates = barcodeLookupCandidates(barcode);
    if (candidates.isEmpty) return null;

    final rows = await (_db.select(
      _db.itemBarcodes,
    )..where((b) => b.barcode.isIn(candidates))).get();

    if (rows.isEmpty) return null;

    final keyedRows = <String, ({ItemBarcode row, String? sourceUnitId})>{};
    for (final row in rows) {
      final sourceUnitId = await _sourceUnitIdForUnit(row.itemId, row.unitId);
      final key = '${row.itemId}::${sourceUnitId ?? ''}';
      keyedRows.putIfAbsent(key, () => (row: row, sourceUnitId: sourceUnitId));
    }
    if (keyedRows.length > 1) {
      throw const DuplicateCatalogBarcodeException();
    }

    final lookupRow = keyedRows.values.single;
    final barcodeRow = lookupRow.row;

    final item =
        await (_db.select(_db.items)..where(
              (i) => i.id.equals(barcodeRow.itemId) & i.inactive.equals(false),
            ))
            .getSingleOrNull();
    if (item == null) return null;
    if (!await _isItemSellableById(item.id, storeId, priceLevelId)) {
      return null;
    }

    var sourceUnitId = lookupRow.sourceUnitId;
    var unit = barcodeRow.unitId != null
        ? await _getUnitByAnyId(barcodeRow.itemId, barcodeRow.unitId!)
        : null;
    if (sourceUnitId == null) {
      final units = await getSellableUnitsForItem(barcodeRow.itemId);
      if (units.length == 1) {
        sourceUnitId = units.single.sourceUnitId;
        unit = await _getUnitByAnyId(barcodeRow.itemId, sourceUnitId);
      }
    }

    return ItemBarcodeLookup(
      item: item,
      unit: unit,
      barcode: _barcodeWithUnitId(barcodeRow, sourceUnitId),
      sourceUnitId: sourceUnitId,
    );
  }

  static List<String> barcodeLookupCandidates(String rawCode) {
    final trimmed = rawCode.trim();
    if (trimmed.isEmpty) return const [];

    final candidates = <String>[];
    void add(String value) {
      if (value.isNotEmpty && !candidates.contains(value)) {
        candidates.add(value);
      }
    }

    add(trimmed);
    add(trimmed.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ''));
    add(trimmed.replaceAll(RegExp(r'\s+'), ''));

    final compact = candidates.last;
    if (RegExp(r'^\d{12}$').hasMatch(compact)) {
      add('0$compact');
    }
    if (RegExp(r'^0\d{12}$').hasMatch(compact)) {
      add(compact.substring(1));
    }

    return candidates;
  }

  // ---------------------------------------------------------------------------
  // Units
  // ---------------------------------------------------------------------------

  /// Sellable units for an item, exposing source unit IDs for cart/sales.
  Future<List<SellableItemUnit>> getSellableUnitsForItem(String itemId) async {
    final rows =
        await (_db.select(_db.itemUnits)
              ..where(
                (unit) =>
                    unit.itemId.equals(itemId) &
                    unit.inactive.equals(false) &
                    unit.noSale.equals(false),
              )
              ..orderBy([
                (unit) => OrderingTerm.desc(unit.isDefault),
                (unit) => OrderingTerm.asc(unit.name),
                (unit) => OrderingTerm.asc(unit.id),
              ]))
            .get();

    return rows
        .map(
          (unit) => SellableItemUnit(
            localId: unit.id,
            itemId: unit.itemId,
            sourceUnitId: _sourceUnitIdForUnitData(unit),
            unitName: unit.name,
            barcode: null, // Barcodes moved to ItemBarcodes
            isDefault: unit.isDefault,
          ),
        )
        .where((unit) => unit.sourceUnitId.isNotEmpty)
        .toList();
  }

  Future<Map<String, List<SellableItemUnit>>> getSellableUnitsForItems(
    Set<String> itemIds,
  ) async {
    if (itemIds.isEmpty) return {};
    final rows =
        await (_db.select(_db.itemUnits)
              ..where(
                (unit) =>
                    unit.itemId.isIn(itemIds) &
                    unit.inactive.equals(false) &
                    unit.noSale.equals(false),
              )
              ..orderBy([
                (unit) => OrderingTerm.asc(unit.itemId),
                (unit) => OrderingTerm.desc(unit.isDefault),
                (unit) => OrderingTerm.asc(unit.name),
                (unit) => OrderingTerm.asc(unit.id),
              ]))
            .get();
    final grouped = <String, List<SellableItemUnit>>{};
    for (final unit in rows) {
      final sourceUnitId = _sourceUnitIdForUnitData(unit);
      if (sourceUnitId.isEmpty) continue;
      grouped
          .putIfAbsent(unit.itemId, () => [])
          .add(
            SellableItemUnit(
              localId: unit.id,
              itemId: unit.itemId,
              sourceUnitId: sourceUnitId,
              unitName: unit.name,
              barcode: null,
              isDefault: unit.isDefault,
            ),
          );
    }
    return grouped;
  }

  // ---------------------------------------------------------------------------
  // Prices
  // ---------------------------------------------------------------------------

  Future<ResolvedItemPrice?> resolveItemPrice({
    required String itemId,
    required String priceLevelId,
    required String storeId,
    required String unitId,
  }) {
    return _resolveItemPriceRow(
      itemId: itemId,
      priceLevelId: priceLevelId,
      storeId: storeId,
      unitId: unitId,
    );
  }

  Future<Map<ItemUnitPriceKey, ResolvedItemPrice>> resolveItemPricesForUnits(
    Iterable<SellableItemUnit> units, {
    required String priceLevelId,
    required String storeId,
  }) async {
    final requestedUnits = units.toList();
    if (requestedUnits.isEmpty) return {};
    final itemIds = requestedUnits.map((unit) => unit.itemId).toSet();
    final itemRows = await (_db.select(
      _db.items,
    )..where((item) => item.id.isIn(itemIds))).get();
    final itemById = {for (final item in itemRows) item.id: item};
    final unitRows =
        await (_db.select(_db.itemUnits)..where(
              (unit) =>
                  unit.itemId.isIn(itemIds) &
                  unit.inactive.equals(false) &
                  unit.noSale.equals(false),
            ))
            .get();
    final unitsByItem = <String, List<ItemUnit>>{};
    for (final unit in unitRows) {
      unitsByItem.putIfAbsent(unit.itemId, () => []).add(unit);
    }
    final priceRows =
        await (_db.select(_db.itemPrices)..where(
              (price) =>
                  price.itemId.isIn(itemIds) &
                  price.priceLevelId.equals(priceLevelId) &
                  price.storeId.equals(storeId) &
                  price.unitPrice.isBiggerThanValue(0),
            ))
            .get();
    final pricesByItem = <String, List<ItemPrice>>{};
    for (final price in priceRows) {
      pricesByItem.putIfAbsent(price.itemId, () => []).add(price);
    }

    final resolved = <ItemUnitPriceKey, ResolvedItemPrice>{};
    for (final requested in requestedUnits) {
      final item = itemById[requested.itemId];
      if (item == null) continue;
      final itemUnits = unitsByItem[requested.itemId] ?? const <ItemUnit>[];
      final unit = _firstUnitWhere(
        itemUnits,
        (unit) =>
            unit.id == requested.sourceUnitId ||
            unit.sourceUnitId == requested.sourceUnitId ||
            unit.id == requested.localId,
      );
      final unitIds = {
        requested.sourceUnitId,
        requested.localId,
        if (unit != null) unit.id,
        if (unit?.sourceUnitId != null) unit!.sourceUnitId!,
      };
      final allCandidates = (pricesByItem[requested.itemId] ?? const [])
          .where(
            (price) => price.unitId != null && unitIds.contains(price.unitId),
          )
          .toList();
      final candidates = allCandidates;
      if (candidates.isEmpty) {
        continue;
      }
      final price = candidates.first;
      final effectiveUnit =
          unit ??
          _firstUnitWhere(
            itemUnits,
            (unit) =>
                unit.id == price.unitId || unit.sourceUnitId == price.unitId,
          );
      resolved[ItemUnitPriceKey(
        requested.itemId,
        requested.sourceUnitId,
      )] = ResolvedItemPrice(
        unitPrice: price.unitPrice,
        unitId: effectiveUnit == null
            ? (price.unitId == null
                  ? null
                  : _sourceUnitIdFromLocalId(price.unitId!))
            : _sourceUnitIdForUnitData(effectiveUnit),
        unitName: effectiveUnit?.name,
        barcode: null,
        taxRate: item.taxRate,
        allowDiscount: item.allowDiscount,
      );
    }
    return resolved;
  }

  SellableItemSnapshot toSellableItemSnapshot({
    required Item item,
    required ResolvedItemPrice price,
    required String fallbackUnitId,
    required String? fallbackUnitName,
    String? barcode,
  }) {
    return SellableItemSnapshot(
      itemId: item.id,
      unitId: price.unitId ?? fallbackUnitId,
      itemName: item.name,
      unitName: price.unitName ?? fallbackUnitName ?? '',
      barcode: barcode ?? price.barcode,
      unitPrice: price.unitPrice,
      taxRate: price.taxRate != 0 ? price.taxRate : item.taxRate,
      allowDiscount: price.allowDiscount,
    );
  }

  Future<ResolvedItemPrice?> _resolveItemPriceRow({
    required String itemId,
    required String priceLevelId,
    required String storeId,
    required String unitId,
  }) async {
    final item = await getItemById(itemId);
    if (item == null) return null;
    final unit = await _getUnitByAnyId(itemId, unitId);
    final unitIds = {
      unitId,
      if (unit != null) unit.id,
      if (unit?.sourceUnitId != null) unit!.sourceUnitId!,
    };
    final rows =
        await (_db.select(_db.itemPrices)..where(
              (price) =>
                  price.itemId.equals(itemId) &
                  price.priceLevelId.equals(priceLevelId) &
                  price.storeId.equals(storeId) &
                  price.unitPrice.isBiggerThanValue(0),
            ))
            .get();
    final candidates = rows
        .where(
          (price) => price.unitId != null && unitIds.contains(price.unitId),
        )
        .toList();
    if (candidates.isEmpty) return null;
    final price = candidates.first;
    final effectiveUnit =
        unit ?? await _getUnitByAnyId(itemId, price.unitId ?? '');
    return ResolvedItemPrice(
      unitPrice: price.unitPrice,
      unitId: effectiveUnit == null
          ? (price.unitId == null
                ? null
                : _sourceUnitIdFromLocalId(price.unitId!))
          : _sourceUnitIdForUnitData(effectiveUnit),
      unitName: effectiveUnit?.name,
      barcode: null,
      taxRate: item.taxRate,
      allowDiscount: item.allowDiscount,
    );
  }

  // ---------------------------------------------------------------------------
  // Groups / Categories
  // ---------------------------------------------------------------------------

  /// Get all active item groups.
  Future<List<ItemGroup>> getActiveGroups() async {
    return (_db.select(_db.itemGroups)
          ..where((g) => g.isActive.equals(true))
          ..orderBy([(g) => OrderingTerm.asc(g.sortOrder)]))
        .get();
  }

  // ---------------------------------------------------------------------------
  // Payment Methods
  // ---------------------------------------------------------------------------

  /// Get all active payment methods.
  Future<List<PaymentMethod>> getActivePaymentMethods() async {
    return (_db.select(_db.paymentMethods)
          ..where((p) => p.isActive.equals(true))
          ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)]))
        .get();
  }

  /// Get active customers for checkout association.
  Future<List<Customer>> getActiveCustomers() async {
    final rows =
        await (_db.select(_db.customers)
              ..where((customer) => customer.inactive.equals(false))
              ..orderBy([(customer) => OrderingTerm.asc(customer.name)])
              ..limit(200))
            .get();

    return rows
        .map((row) {
          return Customer(
            id: row.id,
            name: row.name,
            phone: row.mobile,
            taxNumber: row.taxNumber,
            isActive: !row.inactive,
          );
        })
        .where((customer) => customer.id.isNotEmpty)
        .toList();
  }

  Future<int> countActiveSellableItems() async {
    final row = await _db
        .customSelect(
          '''
      SELECT COUNT(*) AS count
      FROM items
      WHERE inactive = 0 AND no_sale = 0
      ''',
          readsFrom: {_db.items},
        )
        .getSingle();
    return row.data['count'] as int? ?? 0;
  }

  Future<int> countSellableUnitsForActiveItems() async {
    final row = await _db
        .customSelect(
          '''
      SELECT COUNT(*) AS count
      FROM item_units u
      WHERE u.inactive = 0
        AND u.no_sale = 0
        AND EXISTS (
          SELECT 1
          FROM items i
          WHERE i.id = u.item_id
            AND i.inactive = 0
            AND i.no_sale = 0
        )
      ''',
          readsFrom: {_db.items, _db.itemUnits},
        )
        .getSingle();
    return row.data['count'] as int? ?? 0;
  }

  Future<int> countPricesForContext(String storeId, String priceLevelId) async {
    final row = await _db
        .customSelect(
          '''
      SELECT COUNT(*) AS count
      FROM item_prices p
      WHERE p.price_level_id = ?
        AND p.unit_price > 0
        AND p.store_id = ?
        AND EXISTS (
          SELECT 1
          FROM items i
          WHERE i.id = p.item_id
            AND i.inactive = 0
            AND i.no_sale = 0
        )
      ''',
          variables: [
            Variable<String>(priceLevelId),
            Variable<String>(storeId),
          ],
          readsFrom: {_db.items, _db.itemPrices},
        )
        .getSingle();
    return row.data['count'] as int? ?? 0;
  }

  Future<int> countActivePaymentMethods() async {
    final rows = await (_db.select(
      _db.paymentMethods,
    )..where((method) => method.isActive.equals(true))).get();
    return rows.length;
  }

  Future<ItemUnit?> _getUnitByAnyId(String itemId, String unitId) async {
    return await (_db.select(_db.itemUnits)..where(
          (unit) =>
              unit.itemId.equals(itemId) &
              (unit.id.equals(unitId) | unit.sourceUnitId.equals(unitId)),
        ))
        .getSingleOrNull();
  }

  Future<String?> _sourceUnitIdForUnit(String itemId, String? unitId) async {
    if (unitId == null || unitId.isEmpty) return null;
    final unit = await _getUnitByAnyId(itemId, unitId);
    return unit == null
        ? _sourceUnitIdFromLocalId(unitId)
        : _sourceUnitIdForUnitData(unit);
  }

  ItemBarcode _barcodeWithUnitId(ItemBarcode barcode, String? unitId) {
    return ItemBarcode(
      id: barcode.id,
      itemId: barcode.itemId,
      unitId: unitId,
      barcode: barcode.barcode,
      isPrimary: barcode.isPrimary,
      cachedAt: barcode.cachedAt,
    );
  }

  String _sourceUnitIdFromLocalId(String unitId) {
    final separator = unitId.indexOf(':');
    return separator < 0 ? unitId : unitId.substring(separator + 1);
  }

  String _sourceUnitIdForUnitData(ItemUnit unit) {
    return unit.sourceUnitId ?? _sourceUnitIdFromLocalId(unit.id);
  }

  ItemUnit? _firstUnitWhere(
    List<ItemUnit> units,
    bool Function(ItemUnit unit) test,
  ) {
    for (final unit in units) {
      if (test(unit)) return unit;
    }
    return null;
  }
}

class DuplicateCatalogBarcodeException implements Exception {
  const DuplicateCatalogBarcodeException();
}

/// Barcode lookup result combining item + unit + barcode data.
class ItemBarcodeLookup {
  final Item item;
  final ItemUnit? unit;
  final ItemBarcode barcode;
  final String? sourceUnitId;

  const ItemBarcodeLookup({
    required this.item,
    required this.unit,
    required this.barcode,
    required this.sourceUnitId,
  });
}

class SellableItemUnit {
  final String localId;
  final String itemId;
  final String sourceUnitId;
  final String unitName;
  final String? barcode;
  final bool isDefault;

  const SellableItemUnit({
    required this.localId,
    required this.itemId,
    required this.sourceUnitId,
    required this.unitName,
    this.barcode,
    required this.isDefault,
  });
}

class ItemUnitPriceKey {
  final String itemId;
  final String unitId;

  const ItemUnitPriceKey(this.itemId, this.unitId);

  @override
  bool operator ==(Object other) {
    return other is ItemUnitPriceKey &&
        other.itemId == itemId &&
        other.unitId == unitId;
  }

  @override
  int get hashCode => Object.hash(itemId, unitId);
}

class ResolvedItemPrice {
  final double unitPrice;
  final String? unitId;
  final String? unitName;
  final String? barcode;
  final double taxRate;
  final bool allowDiscount;

  const ResolvedItemPrice({
    required this.unitPrice,
    required this.unitId,
    required this.unitName,
    required this.barcode,
    required this.taxRate,
    required this.allowDiscount,
  });
}
