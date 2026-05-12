// features/cashier/application/product_providers.dart
// WHY: DB-backed product/category/payment providers for the cashier UI.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/persistence/daos/catalog_dao.dart';
import 'package:holol_POS/core/persistence/database.dart' hide Customer;
import 'package:holol_POS/features/cashier/domain/models/product.dart';
import 'package:holol_POS/shared/models/customer.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';

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

class CashierCatalogState {
  final List<ProductCardViewModel> products;
  final String? emptyReason;
  final String? emptyMessage;

  const CashierCatalogState({
    required this.products,
    this.emptyReason,
    this.emptyMessage,
  });
}

final cashierProductCardsProvider = FutureProvider<CashierCatalogState>((
  ref,
) async {
  final catalogDao = ref.watch(catalogDaoProvider);
  final search = ref.watch(searchQueryProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final session = ref.watch(activePosSessionProvider).valueOrNull;

  if (session == null) {
    return const CashierCatalogState(
      products: [],
      emptyReason: 'NO_ACTIVE_POS_SESSION',
      emptyMessage: 'لا توجد جلسة كاشير نشطة.',
    );
  }

  final storeId = session.activeStoreId;
  final priceLevelId = session.activePriceLevelId;

  if (storeId.isEmpty) {
    return const CashierCatalogState(
      products: [],
      emptyReason: 'NO_ACTIVE_STORE',
      emptyMessage: 'لا يوجد مخزن نشط للجهاز الحالي.',
    );
  }

  if (priceLevelId.isEmpty) {
    return const CashierCatalogState(
      products: [],
      emptyReason: 'NO_ACTIVE_PRICE_LEVEL',
      emptyMessage: 'لا يوجد مستوى سعر نشط للجهاز الحالي.',
    );
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

  if (items.isEmpty) {
    return CashierCatalogState(
      products: const [],
      emptyReason: search.isNotEmpty || selectedCategory != null
          ? 'NO_MATCHING_PRODUCTS'
          : 'NO_SELLABLE_ITEMS',
      emptyMessage: search.isNotEmpty || selectedCategory != null
          ? 'لا توجد منتجات مطابقة.'
          : 'لا توجد منتجات قابلة للبيع.',
    );
  }

  final unitsByItem = await catalogDao.getSellableUnitsForItems(
    items.map((item) => item.id).toSet(),
  );
  final allUnits = unitsByItem.values.expand((units) => units).toList();

  final pricesByItemUnit = await catalogDao.resolveItemPricesForUnits(
    allUnits,
    storeId: storeId,
    priceLevelId: priceLevelId,
  );

  final cards = <ProductCardViewModel>[];

  for (final item in items) {
    final itemUnits = unitsByItem[item.id] ?? const <SellableItemUnit>[];

    final units = _pricedUnitsForItem(
      catalogDao: catalogDao,
      item: item,
      units: itemUnits,
      pricesByItemUnit: pricesByItemUnit,
    );

    cards.add(ProductCardViewModel(item: _productFromRow(item), units: units));
  }

  if (cards.every((card) => card.units.isEmpty)) {
    return CashierCatalogState(
      products: const [],
      emptyReason: 'NO_PRICED_PRODUCTS',
      emptyMessage: 'لا توجد أسعار صالحة لهذا المخزن ومستوى السعر.',
    );
  }

  return CashierCatalogState(products: cards);
});

final customerSearchQueryProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

final customerSearchResultsProvider =
    FutureProvider.autoDispose<List<Customer>>((ref) async {
      final query = ref.watch(customerSearchQueryProvider);
      return ref
          .watch(catalogDaoProvider)
          .searchActiveCustomers(query: query, limit: 30);
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
    final price =
        pricesByItemUnit[ItemUnitPriceKey(item.id, unit.sourceUnitId)];

    if (price == null) {
      continue;
    }

    try {
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
    } on AppException {
      rethrow;
    } catch (error) {
      throw BusinessException(
        'تعذر تجهيز المنتج ${item.name} للبيع.',
        code: 'PRODUCT_CARD_BUILD_FAILED',
      );
    }
  }

  return pricedUnits;
}
