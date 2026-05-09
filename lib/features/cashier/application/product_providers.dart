// features/cashier/application/product_providers.dart
// WHY: DB-backed product/category/payment providers for the cashier UI.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_flutter/core/persistence/daos/catalog_dao.dart';
import 'package:pos_flutter/core/persistence/database.dart' hide Customer;
import 'package:pos_flutter/core/services/payments/payment_method_resolver.dart';
import 'package:pos_flutter/features/cashier/domain/models/payment_method_option.dart';
import 'package:pos_flutter/features/cashier/domain/models/product.dart';
import 'package:pos_flutter/shared/models/customer.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final selectedCategoryProvider = StateProvider<String?>((ref) => null);

final categoryListProvider = FutureProvider<List<ProductCategory>>((ref) async {
  final rows = await ref.watch(catalogDaoProvider).getActiveGroups();
  return rows
      .map(
        (row) => ProductCategory(
          id: row.id,
          name: row.name,
          nameAr: row.nameAr,
          sortOrder: row.sortOrder,
          iconName: row.iconName,
        ),
      )
      .toList();
});

final cashierProductCardsProvider = FutureProvider<List<ProductCardViewModel>>((
  ref,
) async {
  final catalogDao = ref.watch(catalogDaoProvider);
  final search = ref.watch(searchQueryProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final session = ref.watch(activePosSessionProvider).valueOrNull;
  final storeId = session?.activeStoreId ?? '';
  final priceLevelId = session?.activePriceLevelId ?? '';

  if (storeId.isEmpty || priceLevelId.isEmpty) {
    return [];
  }

  final items = switch ((search.isNotEmpty, selectedCategory)) {
    (true, _) => await catalogDao.searchItems(search, storeId, priceLevelId),
    (false, final category?) => await catalogDao.getItemsByGroup(
      category,
      storeId,
      priceLevelId,
    ),
    _ => await catalogDao.getActiveItems(storeId, priceLevelId),
  };

  final unitsByItem = await catalogDao.getSellableUnitsForItems(
    items.map((item) => item.id).toSet(),
  );
  final pricesByItemUnit = await catalogDao.resolveItemPricesForUnits(
    unitsByItem.values.expand((units) => units),
    storeId: storeId,
    priceLevelId: priceLevelId,
    quantity: 1,
  );

  return items.map((item) {
    final itemUnits = unitsByItem[item.id] ?? const <SellableItemUnit>[];
    return ProductCardViewModel(
      item: _productFromRow(item),
      units: _pricedUnitsForItem(
        catalogDao: catalogDao,
        item: item,
        units: itemUnits,
        pricesByItemUnit: pricesByItemUnit,
      ),
    );
  }).toList();
});

final paymentMethodsProvider = FutureProvider<List<PaymentMethodOption>>((
  ref,
) async {
  final rows = await ref.watch(catalogDaoProvider).getActivePaymentMethods();
  return rows.map((row) {
    final resolved = PaymentMethodResolver.resolve(
      methodId: row.id,
      code: row.code,
      displayName: row.name,
      storedTypeCode: row.type,
      requiresReference: row.requiresReference,
      bankId: row.bankId,
      cardTypeId: row.cardTypeId,
    );
    return PaymentMethodOption(
      id: resolved.methodId,
      code: resolved.code,
      name: resolved.displayName,
      type: resolved.type,
      requiresReference: resolved.requiresReference,
      bankId: resolved.bankId,
      cardTypeId: resolved.cardTypeId,
    );
  }).toList();
});

final customersProvider = FutureProvider<List<Customer>>((ref) async {
  return ref.watch(catalogDaoProvider).getActiveCustomers();
});

ProductListItem _productFromRow(Item item) {
  return ProductListItem(
    id: item.id,
    name: item.name,
    nameAr: item.nameAr,
    categoryId: item.groupId,
    imageUrl: item.imageUrl,
    defaultUnitId: item.defaultUnitId,
    code: item.code,
  );
}

List<ProductUnitOption> _pricedUnitsForItem({
  required CatalogDao catalogDao,
  required Item item,
  required List<SellableItemUnit> units,
  required Map<ItemUnitPriceKey, ResolvedItemPrice> pricesByItemUnit,
}) {
  final pricedUnits = <ProductUnitOption>[];

  for (final unit in units) {
    try {
      final price =
          pricesByItemUnit[ItemUnitPriceKey(item.id, unit.sourceUnitId)];
      if (price != null) {
        final sellableItem = catalogDao.toSellableItemSnapshot(
          item: item,
          price: price,
          fallbackUnitId: unit.sourceUnitId,
          fallbackUnitName: unit.unitName,
          barcode: unit.barcode,
        );
        pricedUnits.add(
          ProductUnitOption(
            isDefault: unit.isDefault,
            sellableItem: sellableItem,
          ),
        );
      }
    } catch (_) {}
  }

  return pricedUnits;
}
