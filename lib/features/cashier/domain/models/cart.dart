import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/persistence/daos/catalog_dao.dart';
import 'package:holol_POS/core/services/pricing/pricing_engine.dart';
import 'package:holol_POS/features/sales/domain/models/sale_inputs.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/shared/models/sellable_item_snapshot.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
import 'package:holol_POS/shared/refactor/pos_business_rules.dart';

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
  final DiscountType? discountType;
  final double? discountValue;
  final String? notes;

  const CartItem({
    required this.sellableItem,
    required this.quantity,
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
    DiscountType? discountType,
    double? discountValue,
    String? notes,
  }) {
    return CartItem(
      sellableItem: sellableItem ?? this.sellableItem,
      quantity: quantity ?? this.quantity,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      notes: notes ?? this.notes,
    );
  }

  CartItem withoutDiscount() {
    return CartItem(
      sellableItem: sellableItem,
      quantity: quantity,
      notes: notes,
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
      allowDiscount: allowDiscount,
      notes: notes,
    );
  }

  Map<String, dynamic> toHeldOrderSnapshotJson() {
    return toSaleLineInput().toHeldOrderSnapshotJson();
  }
}

class Cart {
  final List<CartItem> items;

  const Cart({this.items = const []});

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  int get totalLinesCount => items.length;

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
      SaleLineValidator.validateQuantityForSnapshot(snapshot, 1.0);
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

    SaleLineValidator.validateQuantityForSnapshot(
      current.sellableItem,
      newQuantity,
    );

    return replaceLine(current.copyWith(quantity: newQuantity));
  }

  Cart applyResolvedPrice({
    required String itemId,
    required String unitId,
    required SellableItemSnapshot pricedSnapshot,
  }) {
    final current = findLine(itemId, unitId);
    if (current == null) return this;

    return replaceLine(current.copyWith(sellableItem: pricedSnapshot));
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

        SaleLineValidator.validateDiscount(
          allowDiscount: item.allowDiscount,
          itemName: item.productName,
          value: value,
        );

        return item.copyWith(discountType: type, discountValue: value);
      }).toList(),
    );
  }

  Cart clearLineDiscount(String itemId, String? unitId) {
    return Cart(
      items: items
          .map(
            (item) =>
                _sameLine(item, itemId, unitId) ? item.withoutDiscount() : item,
          )
          .toList(),
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
    return PosSaleQuoteRules.quote(
      pricingEngine: pricingEngine,
      lines: toSaleLineInputs(),
      useTax: useTax,
      priceIncludesTax: priceIncludesTax,
    );
  }

static Cart fromSaleLineInputs(List<SaleLineInput> lines) {
    final items = <CartItem>[];

    for (final line in lines) {
      final snapshot = SellableItemSnapshot(
        itemId: line.itemId,
        unitId: line.unitId,
        itemName: line.itemName,
        unitName: line.unitName,
        unitSize: line.unitSize,
        barcode: line.barcode,
        unitPrice: line.unitPrice,
        taxRate: line.taxRate,
        allowDiscount: line.allowDiscount,
        useQtyFraction: line.useQtyFraction,
      );

      final existingIndex = items.indexWhere(
        (item) => item.itemId == line.itemId && item.unitId == line.unitId,
      );

      final nextItem = CartItem(
        sellableItem: snapshot,
        quantity: line.quantity,
        discountType: line.discountType,
        discountValue: line.discountValue,
        notes: line.notes,
      );

      if (existingIndex < 0) {
        items.add(nextItem);
      } else {
        final existing = items[existingIndex];
        items[existingIndex] = existing.copyWith(
          quantity: existing.quantity + line.quantity,
        );
      }
    }

    return Cart(items: items);
  }

  bool _sameLine(CartItem item, String itemId, String? unitId) {
    return item.itemId == itemId && item.unitId == unitId;
  }
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

  void clearLineDiscount(String itemId, String? unitId) {
    state = state.clearLineDiscount(itemId, unitId);
  }

  void removeItem(String itemId, String? unitId) {
    state = state.removeItem(itemId, unitId);
  }

  void clearCart() {
    state = const Cart();
  }

  void restoreFromSaleLineInputs(List<SaleLineInput> lines) {
    state = Cart.fromSaleLineInputs(lines);
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
