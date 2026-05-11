import 'package:holol_POS/shared/models/sellable_item_snapshot.dart';

class ProductCategory {
  final String id;
  final String name;
  final String? nameAr;
  final int sortOrder;
  final String? iconName;

  const ProductCategory({
    required this.id,
    required this.name,
    this.nameAr,
    this.sortOrder = 0,
    this.iconName,
  });
}

class ProductListItem {
  final String id;
  final String? code;
  final String name;
  final String? nameAr;
  final String? categoryId;
  final String? imageUrl;
  final String? defaultUnitId;

  const ProductListItem({
    required this.id,
    this.code,
    required this.name,
    this.nameAr,
    this.categoryId,
    this.imageUrl,
    this.defaultUnitId,
  });
}

class ProductUnitOption {
  final SellableItemSnapshot sellableItem;
  final bool isDefault;

  const ProductUnitOption({
    required this.sellableItem,
    required this.isDefault,
  });
}

class ProductCardViewModel {
  final ProductListItem item;
  final List<ProductUnitOption> units;

  const ProductCardViewModel({required this.item, required this.units});

  ProductUnitOption? get defaultUnit {
    if (units.isEmpty) return null;
    for (final unit in units) {
      if (unit.isDefault) return unit;
    }
    return units.first;
  }

  bool get isSellable => defaultUnit != null;
}
