import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_flutter/core/persistence/daos/catalog_dao.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';
import 'package:pos_flutter/core/errors/app_exception.dart';
import 'package:pos_flutter/core/services/pricing/pricing_engine.dart';
import 'package:pos_flutter/features/sales/domain/models/sale_inputs.dart';
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

  SaleLineInput toSaleLineInput() {
    return SaleLineInput(
      itemId: itemId,
      unitId: unitId,
      itemName: productName,
      unitName: unitName,
      barcode: barcode,
      quantity: quantity,
      unitPrice: unitPrice,
      taxRate: taxRate,
      discountType: discountType,
      discountValue: discountValue,
      discountAmount: discountAmount,
      isPriceOverridden: isPriceOverridden,
      allowDiscount: allowDiscount,
      priceSource: priceSource,
      notes: notes,
    );
  }

  Map<String, dynamic> toHeldOrderSnapshotJson() {
    return {
      'itemId': itemId,
      'unitId': unitId,
      'itemName': productName,
      'unitName': unitName,
      'barcode': barcode,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'taxRate': taxRate,
      'discountType': discountType?.code,
      'discountValue': discountValue,
      'discountAmount': discountAmount,
      'isPriceOverridden': isPriceOverridden,
      'allowDiscount': allowDiscount,
      'priceSource': priceSource,
      'notes': notes,
    };
  }

  static CartItem fromSnapshotJson(Map<String, dynamic> json) {
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
        priceSource: json['priceSource'] as String? ?? PriceSource.itemPrice.code,
      ),
      quantity: _double(json['quantity'], fallback: 1.0),
      discountType: _parseDiscountType(json['discountType']),
      discountValue: _nullableDouble(json['discountValue']),
      discountAmount: _double(json['discountAmount']),
      isPriceOverridden: json['isPriceOverridden'] as bool? ?? false,
      notes: json['notes'] as String?,
    );
  }
}

class Cart {
  final List<CartItem> items;

  const Cart({this.items = const []});

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  int get totalItemCount {
    return items.fold(0, (sum, item) => sum + item.quantity.round());
  }

  CartItem? findLine(String itemId, String? unitId) {
    for (final item in items) {
      if (_sameLine(item, itemId, unitId)) return item;
    }
    return null;
  }

  double quantityFor(String itemId, String? unitId) {
    return findLine(itemId, unitId)?.quantity ?? 0;
  }

  Cart addSellableItem(SellableItemSnapshot snapshot) {
    final existing = findLine(snapshot.itemId, snapshot.unitId);

    if (existing == null) {
      return Cart(
        items: [
          ...items,
          CartItem(sellableItem: snapshot, quantity: 1.0),
        ],
      );
    }

    return changeQuantity(
      existing.itemId,
      existing.unitId,
      existing.quantity + 1,
    );
  }

  Cart replaceLine(CartItem updatedLine) {
    return Cart(
      items: items
          .map(
            (item) => _sameLine(item, updatedLine.itemId, updatedLine.unitId)
                ? updatedLine
                : item,
          )
          .toList(),
    );
  }

  Cart changeQuantity(String itemId, String? unitId, double newQuantity) {
    if (newQuantity <= 0) return removeItem(itemId, unitId);

    final current = findLine(itemId, unitId);
    if (current == null) return this;

    return replaceLine(current.copyWith(quantity: newQuantity));
  }

  Cart applyResolvedPrice({
    required String itemId,
    required String unitId,
    required SellableItemSnapshot pricedSnapshot,
  }) {
    final current = findLine(itemId, unitId);
    if (current == null) return this;

    return replaceLine(
      current.copyWith(sellableItem: pricedSnapshot),
    );
  }

  Cart applyLineDiscount(
    String itemId,
    String? unitId, {
    required DiscountType type,
    required double value,
    required double amount,
  }) {
    return Cart(
      items: items.map((item) {
        if (!_sameLine(item, itemId, unitId)) return item;

        if (!item.allowDiscount && (amount > 0 || value > 0)) {
          throw BusinessException(
            'Discounts are not allowed for ${item.productName}.',
            code: 'DISCOUNT_NOT_ALLOWED',
          );
        }

        return item.copyWith(
          discountType: type,
          discountValue: value,
          discountAmount: amount,
        );
      }).toList(),
    );
  }

  Cart overridePrice(String itemId, String? unitId, double newPrice) {
    return Cart(
      items: items.map((item) {
        if (!_sameLine(item, itemId, unitId)) return item;

        return item.copyWith(
          overrideUnitPrice: newPrice,
          isPriceOverridden: true,
        );
      }).toList(),
    );
  }

  Cart removeItem(String itemId, String? unitId) {
    return Cart(
      items: items.where((item) => !_sameLine(item, itemId, unitId)).toList(),
    );
  }

  List<SaleLineInput> toSaleLineInputs() {
    return items.map((item) => item.toSaleLineInput()).toList();
  }

  List<Map<String, dynamic>> toHeldOrderSnapshotJson() {
    return items.map((item) => item.toHeldOrderSnapshotJson()).toList();
  }

  CheckoutQuote previewQuote({
    required PricingEngine pricingEngine,
    required bool useTax,
    required bool priceIncludesTax,
  }) {
    return pricingEngine.calculateQuote(
      lines: toSaleLineInputs()
          .map(
            (line) => PricingLineInput(
              itemId: line.itemId,
              unitId: line.unitId,
              unitPrice: line.unitPrice,
              quantity: line.quantity,
              discountAmount: line.discountAmount,
              taxRate: line.taxRate,
            ),
          )
          .toList(),
      taxRate: 0,
      useTax: useTax,
      priceIncludesTax: priceIncludesTax,
    );
  }

  static Cart fromHeldOrderSnapshotJson(String snapshotJson) {
    final decoded = jsonDecode(snapshotJson);

    if (decoded is List) {
      return Cart(
        items: decoded
            .cast<Map<String, dynamic>>()
            .map(CartItem.fromSnapshotJson)
            .toList(),
      );
    }

    if (decoded is Map<String, dynamic>) {
      final items = decoded['items'];

      if (items is List) {
        return Cart(
          items: items
              .cast<Map<String, dynamic>>()
              .map(CartItem.fromSnapshotJson)
              .toList(),
        );
      }
    }

    throw const FormatException('Invalid held order snapshot.');
  }

  bool _sameLine(CartItem item, String itemId, String? unitId) {
    return item.itemId == itemId && item.unitId == unitId;
  }
}

double _double(Object? value, {double fallback = 0.0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

double? _nullableDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

DiscountType? _parseDiscountType(Object? value) {
  if (value == null) return null;

  if (value is String) {
    for (final type in DiscountType.values) {
      if (type.code == value) return type;
    }
  }

  return null;
}

typedef CartPriceResolver = Future<ResolvedItemPrice?> Function({
  required String itemId,
  required String unitId,
  required double quantity,
});

/// Riverpod state shell for Cart.
///
/// Cart owns the business decisions and value transformations.
/// CartController only applies async price resolution and publishes state.
class CartController extends StateNotifier<Cart> {
  final CartPriceResolver _priceResolver;

  CartController({required CartPriceResolver priceResolver})
    : _priceResolver = priceResolver,
      super(const Cart());

  Future<double> addSellableItem(SellableItemSnapshot snapshot) async {
    final existingQty = state.quantityFor(snapshot.itemId, snapshot.unitId);
    final targetQty = existingQty + 1;

    if (existingQty <= 0) {
      state = state.addSellableItem(snapshot);
      return 1;
    }

    await changeQuantityWithPricing(snapshot.itemId, snapshot.unitId, targetQty);
    return targetQty;
  }

  Future<void> incrementItem(String itemId, String? unitId) async {
    final item = state.findLine(itemId, unitId);
    if (item == null) return;

    await changeQuantityWithPricing(itemId, unitId, item.quantity + 1);
  }

  Future<void> decrementItem(String itemId, String? unitId) async {
    final item = state.findLine(itemId, unitId);
    if (item == null) return;

    await changeQuantityWithPricing(itemId, unitId, item.quantity - 1);
  }

  Future<void> changeQuantityWithPricing(
    String itemId,
    String? unitId,
    double newQuantity,
  ) async {
    if (newQuantity <= 0) {
      removeItem(itemId, unitId);
      return;
    }

    final current = state.findLine(itemId, unitId);
    if (current == null) return;

    var next = state.changeQuantity(itemId, unitId, newQuantity);

    if (!current.isPriceOverridden && unitId != null && unitId.isNotEmpty) {
      final price = await _resolvePrice(itemId, unitId, newQuantity);

      next = next.applyResolvedPrice(
        itemId: itemId,
        unitId: unitId,
        pricedSnapshot: SellableItemSnapshot(
          itemId: current.itemId,
          unitId: current.unitId,
          itemName: current.productName,
          unitName: current.unitName,
          barcode: current.barcode,
          unitPrice: price.unitPrice,
          taxRate: price.taxRate,
          allowDiscount: price.allowDiscount,
          priceSource: price.priceSource,
        ),
      );
    }

    state = next;
  }

  void applyLineDiscount(
    String itemId,
    String? unitId, {
    required DiscountType type,
    required double value,
    required double amount,
  }) {
    state = state.applyLineDiscount(
      itemId,
      unitId,
      type: type,
      value: value,
      amount: amount,
    );
  }

  void overridePrice(String itemId, String? unitId, double newPrice) {
    state = state.overridePrice(itemId, unitId, newPrice);
  }

  void removeItem(String itemId, String? unitId) {
    state = state.removeItem(itemId, unitId);
  }

  void clearCart() {
    state = const Cart();
  }

  void restoreFromHeldOrderJson(String snapshotJson) {
    state = Cart.fromHeldOrderSnapshotJson(snapshotJson);
  }

  Future<ResolvedItemPrice> _resolvePrice(
    String itemId,
    String unitId,
    double quantity,
  ) async {
    try {
      final price = await _priceResolver(
        itemId: itemId,
        unitId: unitId,
        quantity: quantity,
      );

      if (price == null) {
        throw const BusinessException(
          'No active sale price is configured for this quantity.',
          code: 'PRICE_NOT_CONFIGURED',
        );
      }

      return price;
    } on BusinessException {
      rethrow;
    } catch (_) {
      throw const BusinessException(
        'Unable to resolve item price.',
        code: 'PRICE_RESOLUTION_FAILED',
      );
    }
  }
}

final cartProvider = StateNotifierProvider<CartController, Cart>((ref) {
  return CartController(
    priceResolver: ({
      required String itemId,
      required String unitId,
      required double quantity,
    }) {
      final catalogDao = ref.read(catalogDaoProvider);
      final session = ref.read(activePosSessionProvider).valueOrNull;

      if (session == null) {
        throw const BusinessException(
          'Select a cashier and POS machine before pricing items.',
          code: 'NO_ACTIVE_POS_SESSION',
        );
      }

      return catalogDao.resolveItemPrice(
        itemId: itemId,
        unitId: unitId,
        priceLevelId: session.activePriceLevelId,
        storeId: session.activeStoreId,
        quantity: quantity,
      );
    },
  );
});
