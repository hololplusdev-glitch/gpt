import 'package:pos_flutter/shared/models/enums.dart';
import 'package:pos_flutter/shared/models/sellable_item_snapshot.dart';

class CartItem {
  final SellableItemSnapshot sellableItem;
  final double quantity;
  final double discountAmount;
  final DiscountType? discountType;
  final double? discountValue;
  final bool isPriceOverridden;
  final double? overrideUnitPrice;
  final String? notes;

  const CartItem({
    required this.sellableItem,
    required this.quantity,
    this.discountAmount = 0.0,
    this.discountType,
    this.discountValue,
    this.isPriceOverridden = false,
    this.overrideUnitPrice,
    this.notes,
  });

  String get itemId => sellableItem.itemId;
  String get unitId => sellableItem.unitId;
  String get productName => sellableItem.itemName;
  String get unitName => sellableItem.unitName;
  String? get barcode => sellableItem.barcode;
  double get unitPrice => overrideUnitPrice ?? sellableItem.unitPrice;
  double get taxRate => sellableItem.taxRate;
  bool get allowDiscount => sellableItem.allowDiscount;
  String get priceSource => sellableItem.priceSource;
  String get lineKey => '$itemId|$unitId';

  CartItem copyWith({
    SellableItemSnapshot? sellableItem,
    double? quantity,
    double? discountAmount,
    DiscountType? discountType,
    double? discountValue,
    bool? isPriceOverridden,
    double? overrideUnitPrice,
    bool clearOverrideUnitPrice = false,
    String? notes,
  }) {
    return CartItem(
      sellableItem: sellableItem ?? this.sellableItem,
      quantity: quantity ?? this.quantity,
      discountAmount: discountAmount ?? this.discountAmount,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      isPriceOverridden: isPriceOverridden ?? this.isPriceOverridden,
      overrideUnitPrice: clearOverrideUnitPrice
          ? null
          : (overrideUnitPrice ?? this.overrideUnitPrice),
      notes: notes ?? this.notes,
    );
  }
}

class Cart {
  final List<CartItem> items;

  const Cart({this.items = const []});

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  int get totalItemCount =>
      items.fold(0, (sum, item) => sum + item.quantity.round());
}
