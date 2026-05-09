import 'dart:convert';

import 'package:pos_flutter/features/cashier/domain/models/cart.dart';
import 'package:pos_flutter/features/sales/domain/models/sale_inputs.dart';
import 'package:pos_flutter/shared/models/enums.dart';
import 'package:pos_flutter/shared/models/sellable_item_snapshot.dart';

abstract final class CartMapper {
  static List<SaleLineInput> saleLineInputs(Cart cart) {
    return cart.items
        .map(
          (item) => SaleLineInput(
            itemId: item.itemId,
            unitId: item.unitId,
            itemName: item.productName,
            unitName: item.unitName,
            barcode: item.barcode,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            taxRate: item.taxRate,
            discountType: item.discountType,
            discountValue: item.discountValue,
            discountAmount: item.discountAmount,
            isPriceOverridden: item.isPriceOverridden,
            allowDiscount: item.allowDiscount,
            priceSource: item.priceSource,
            notes: item.notes,
          ),
        )
        .toList();
  }

  static List<CartItem> cartItemsFromJson(
    List<Map<String, dynamic>> itemsJson,
  ) {
    return itemsJson.map(_cartItemFromJson).toList();
  }

  static List<CartItem> cartItemsFromHeldOrderJson(String snapshotJson) {
    final decoded = jsonDecode(snapshotJson);
    if (decoded is List) {
      return cartItemsFromJson(decoded.cast<Map<String, dynamic>>());
    }
    if (decoded is Map<String, dynamic>) {
      final items = decoded['items'];
      if (items is List) {
        return cartItemsFromJson(items.cast<Map<String, dynamic>>());
      }
    }
    throw const FormatException('Invalid held order snapshot.');
  }

  static CartItem _cartItemFromJson(Map<String, dynamic> json) {
    final unitName = json['unitName'] as String? ?? 'Each';
    return CartItem(
      sellableItem: SellableItemSnapshot(
        itemId: json['itemId'] as String,
        unitId: json['unitId'] as String,
        itemName: json['itemName'] as String,
        unitName: unitName,
        barcode: json['barcode'] as String?,
        unitPrice: _double(json['unitPrice']),
        taxRate: _double(json['taxRate']),
        allowDiscount: json['allowDiscount'] as bool? ?? false,
        priceSource:
            json['priceSource'] as String? ?? PriceSource.itemPrice.code,
      ),
      quantity: _double(json['quantity'], fallback: 1.0),
      discountType: _parseDiscountType(json['discountType']),
      discountValue: _nullableDouble(json['discountValue']),
      discountAmount: _double(json['discountAmount']),
      isPriceOverridden: json['isPriceOverridden'] as bool? ?? false,
      notes: json['notes'] as String?,
    );
  }

  static double _double(Object? value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  static double? _nullableDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static DiscountType? _parseDiscountType(Object? value) {
    if (value == null) return null;
    if (value is String) {
      for (final type in DiscountType.values) {
        if (type.code == value) return type;
      }
    }
    return null;
  }
}
