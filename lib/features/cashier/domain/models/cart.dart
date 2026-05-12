import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/persistence/daos/catalog_dao.dart';
import 'package:holol_POS/core/services/pricing/pricing_engine.dart';
import 'package:holol_POS/features/sales/domain/models/sale_inputs.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/shared/models/sellable_item_snapshot.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';

class AddToCartResult {
  final String itemName;
  final double quantity;
  final bool wasIncremented;

  const AddToCartResult({
    required this.itemName,
    required this.quantity,
    required this.wasIncremented,
  });
}

class CartItem {
  final SellableItemSnapshot sellableItem;
  final double quantity;
  final double discountAmount;
  final DiscountType? discountType;
  final double? discountValue;
  final String? notes;

  const CartItem({
    required this.sellableItem,
    required this.quantity,
    this.discountAmount = 0.0,
    this.discountType,
    this.discountValue,
    this.notes,
  });

  String get itemId => sellableItem.itemId;
  String get unitId => sellableItem.unitId;
  String get productName => sellableItem.itemName;
  String get unitName => sellableItem.unitName;
  double? get unitSize => sellableItem.unitSize;
  bool get useQtyFraction => sellableItem.useQtyFraction;
  String? get barcode => sellableItem.barcode;
  double get unitPrice => sellableItem.unitPrice;
  double get taxRate => sellableItem.taxRate;
  bool get allowDiscount => sellableItem.allowDiscount;
  String get lineKey => '$itemId|$unitId';

  CartItem copyWith({
    SellableItemSnapshot? sellableItem,
    double? quantity,
    double? discountAmount,
    DiscountType? discountType,
    double? discountValue,
    String? notes,
  }) {
    return CartItem(
      sellableItem: sellableItem ?? this.sellableItem,
      quantity: quantity ?? this.quantity,
      discountAmount: discountAmount ?? this.discountAmount,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      notes: notes ?? this.notes,
    );
  }

  SaleLineInput toSaleLineInput() {
    return SaleLineInput(
      itemId: itemId,
      unitId: unitId,
      itemName: productName,
      unitName: unitName,
      unitSize: unitSize,
      barcode: barcode,
      useQtyFraction: useQtyFraction,
      quantity: quantity,
      unitPrice: unitPrice,
      taxRate: taxRate,
      discountType: discountType,
      discountValue: discountValue,
      discountAmount: discountAmount,
      allowDiscount: allowDiscount,
      notes: notes,
    );
  }

  Map<String, dynamic> toHeldOrderSnapshotJson() {
    return toSaleLineInput().toHeldOrderSnapshotJson();
  }

  static CartItem fromSnapshotJson(Map<String, dynamic> json) {
    final unitName = json['unitName'] as String? ?? 'Each';

    return CartItem(
      sellableItem: SellableItemSnapshot(
        itemId: json['itemId'] as String,
        unitId: json['unitId'] as String,
        itemName: json['itemName'] as String,
        unitName: unitName,
        unitSize: _nullableDouble(json['unitSize']),
        barcode: json['barcode'] as String?,
        unitPrice: _double(json['unitPrice']),
        taxRate: _double(json['taxRate']),
        allowDiscount: json['allowDiscount'] as bool? ?? false,
        useQtyFraction: json['useQtyFraction'] as bool? ?? false,
      ),
      quantity: _double(json['quantity'], fallback: 1.0),
      discountType: _parseDiscountType(json['discountType']),
      discountValue: _nullableDouble(json['discountValue']),
      discountAmount: _double(json['discountAmount']),
      notes: json['notes'] as String?,
    );
  }
}

class Cart {
  final List<CartItem> items;

  const Cart({this.items = const []});

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  int get totalLinesCount => items.length;

  /// Temporary alias for existing UI call-sites.
  int get totalItemCount => totalLinesCount;

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
      _validateQuantityForSnapshot(snapshot, 1.0);
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

    _validateQuantityForSnapshot(current.sellableItem, newQuantity);

    final discountAmount = _calculateDiscountAmount(
      unitPrice: current.unitPrice,
      quantity: newQuantity,
      discountType: current.discountType,
      discountValue: current.discountValue,
      allowDiscount: current.allowDiscount,
    );

    return replaceLine(
      current.copyWith(quantity: newQuantity, discountAmount: discountAmount),
    );
  }

  Cart applyResolvedPrice({
    required String itemId,
    required String unitId,
    required SellableItemSnapshot pricedSnapshot,
  }) {
    final current = findLine(itemId, unitId);
    if (current == null) return this;

    final discountAmount = _calculateDiscountAmount(
      unitPrice: pricedSnapshot.unitPrice,
      quantity: current.quantity,
      discountType: current.discountType,
      discountValue: current.discountValue,
      allowDiscount: pricedSnapshot.allowDiscount,
    );

    return replaceLine(
      current.copyWith(
        sellableItem: pricedSnapshot,
        discountAmount: discountAmount,
      ),
    );
  }

  Cart applyLineDiscount(
    String itemId,
    String? unitId, {
    required DiscountType type,
    required double value,
  }) {
    return Cart(
      items: items.map((item) {
        if (!_sameLine(item, itemId, unitId)) return item;

        final amount = _calculateDiscountAmount(
          unitPrice: item.unitPrice,
          quantity: item.quantity,
          discountType: type,
          discountValue: value,
          allowDiscount: item.allowDiscount,
        );

        return item.copyWith(
          discountType: type,
          discountValue: value,
          discountAmount: amount,
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
      lines: toSaleLineInputs().toPricingLineInputs(),
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

void _validateQuantityForSnapshot(
  SellableItemSnapshot snapshot,
  double quantity,
) {
  if (quantity <= 0) return;

  if (!snapshot.useQtyFraction && !_isWholeQuantity(quantity)) {
    throw BusinessException(
      'Fraction quantity is not allowed for ${snapshot.itemName}.',
      code: 'QUANTITY_FRACTION_NOT_ALLOWED',
    );
  }
}

bool _isWholeQuantity(double value) {
  return (value - value.roundToDouble()).abs() < 0.000001;
}

double _calculateDiscountAmount({
  required double unitPrice,
  required double quantity,
  required DiscountType? discountType,
  required double? discountValue,
  required bool allowDiscount,
}) {
  return const PricingEngine().calculateDiscountAmount(
    grossAmount: PricingEngine.roundAmount(unitPrice * quantity),
    discountType: discountType,
    discountValue: discountValue,
    allowDiscount: allowDiscount,
  );
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

typedef CartPriceResolver =
    Future<ResolvedItemPrice?> Function({
      required String itemId,
      required String unitId,
    });

/// Riverpod state shell for Cart.
///
/// Cart owns the line merge rule:
/// same itemId + same unitId = one line; quantity increments.
/// CartController only applies async price resolution and publishes state.
class CartController extends StateNotifier<Cart> {
  final CartPriceResolver _priceResolver;

  CartController({required CartPriceResolver priceResolver})
    : _priceResolver = priceResolver,
      super(const Cart());

  Future<AddToCartResult> addSellableItem(SellableItemSnapshot snapshot) async {
    final pricedSnapshot = await _resolveCurrentSnapshot(snapshot);
    final existingQty = state.quantityFor(
      pricedSnapshot.itemId,
      pricedSnapshot.unitId,
    );

    state = state.addSellableItem(pricedSnapshot);

    final quantity = state.quantityFor(
      pricedSnapshot.itemId,
      pricedSnapshot.unitId,
    );

    return AddToCartResult(
      itemName: pricedSnapshot.itemName,
      quantity: quantity,
      wasIncremented: existingQty > 0,
    );
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

    if (unitId != null && unitId.isNotEmpty) {
      final pricedSnapshot = await _resolveCurrentSnapshot(
        current.sellableItem,
      );

      next = next.applyResolvedPrice(
        itemId: itemId,
        unitId: unitId,
        pricedSnapshot: pricedSnapshot,
      );
    }

    state = next;
  }

  void applyLineDiscount(
    String itemId,
    String? unitId, {
    required DiscountType type,
    required double value,
  }) {
    state = state.applyLineDiscount(itemId, unitId, type: type, value: value);
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

  Future<SellableItemSnapshot> _resolveCurrentSnapshot(
    SellableItemSnapshot snapshot,
  ) async {
    final price = await _resolvePrice(snapshot.itemId, snapshot.unitId);

    return SellableItemSnapshot(
      itemId: snapshot.itemId,
      unitId: price.unitId ?? snapshot.unitId,
      itemName: snapshot.itemName,
      unitName: price.unitName ?? snapshot.unitName,
      unitSize: price.unitSize ?? snapshot.unitSize,
      barcode: snapshot.barcode ?? price.barcode,
      unitPrice: price.unitPrice,
      taxRate: price.taxRate,
      allowDiscount: price.allowDiscount,
      useQtyFraction: price.useQtyFraction,
    );
  }

  Future<ResolvedItemPrice> _resolvePrice(String itemId, String unitId) async {
    try {
      final price = await _priceResolver(itemId: itemId, unitId: unitId);

      if (price == null) {
        throw const BusinessException(
          'No active sale price is configured for this item.',
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
    priceResolver: ({required String itemId, required String unitId}) {
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
      );
    },
  );
});
