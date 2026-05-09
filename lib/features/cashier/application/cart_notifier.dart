export 'package:pos_flutter/features/cashier/domain/models/cart.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_flutter/core/errors/app_exception.dart';
import 'package:pos_flutter/core/persistence/daos/catalog_dao.dart';
import 'package:pos_flutter/features/cashier/application/cart_mapper.dart';
import 'package:pos_flutter/features/cashier/domain/models/cart.dart';
import 'package:pos_flutter/shared/models/enums.dart';
import 'package:pos_flutter/shared/models/sellable_item_snapshot.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';

typedef CartPriceResolver =
    Future<ResolvedItemPrice?> Function({
      required String itemId,
      required String unitId,
      required double quantity,
    });

/// Manages the in-memory cart.
class CartNotifier extends StateNotifier<Cart> {
  final CartPriceResolver? _priceResolver;

  CartNotifier({CartPriceResolver? priceResolver})
    : _priceResolver = priceResolver,
      super(const Cart());

  /// Add a resolved catalog snapshot to the cart.
  /// Returns the new quantity for the line.
  Future<double> addSellableItem(SellableItemSnapshot snapshot) async {
    final resolvedUnitId = snapshot.unitId;
    final existing = state.items.indexWhere(
      (i) => _sameLine(i, snapshot.itemId, resolvedUnitId),
    );

    if (existing >= 0) {
      final newQty = state.items[existing].quantity + 1;
      await changeQuantityWithPricing(snapshot.itemId, resolvedUnitId, newQty);
      return newQty;
    }

    state = Cart(
      items: [
        ...state.items,
        CartItem(sellableItem: snapshot, quantity: 1.0),
      ],
    );
    return 1;
  }

  Future<void> incrementItem(String itemId, String? unitId) async {
    final item = _findLine(itemId, unitId);
    if (item == null) return;
    await changeQuantityWithPricing(itemId, unitId, item.quantity + 1);
  }

  Future<void> decrementItem(String itemId, String? unitId) async {
    final item = _findLine(itemId, unitId);
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

    final current = _findLine(itemId, unitId);
    if (current == null) return;

    var updatedLine = current.copyWith(quantity: newQuantity);
    if (!current.isPriceOverridden &&
        unitId != null &&
        unitId.isNotEmpty &&
        _priceResolver != null) {
      final price = await _resolvePrice(itemId, unitId, newQuantity);
      updatedLine = updatedLine.copyWith(
        sellableItem: SellableItemSnapshot(
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

    state = Cart(
      items: state.items
          .map((item) => _sameLine(item, itemId, unitId) ? updatedLine : item)
          .toList(),
    );
  }

  /// Apply discount to a line item.
  void applyLineDiscount(
    String itemId,
    String? unitId, {
    required DiscountType type,
    required double value,
    required double amount,
  }) {
    state = Cart(
      items: state.items.map((i) {
        if (_sameLine(i, itemId, unitId)) {
          if (!i.allowDiscount && (amount > 0 || value > 0)) {
            throw BusinessException(
              'Discounts are not allowed for ${i.productName}.',
              code: 'DISCOUNT_NOT_ALLOWED',
            );
          }
          return i.copyWith(
            discountType: type,
            discountValue: value,
            discountAmount: amount,
          );
        }
        return i;
      }).toList(),
    );
  }

  /// Override price (requires supervisor approval in UI).
  void overridePrice(String itemId, String? unitId, double newPrice) {
    state = Cart(
      items: state.items.map((i) {
        if (_sameLine(i, itemId, unitId)) {
          return i.copyWith(
            overrideUnitPrice: newPrice,
            isPriceOverridden: true,
          );
        }
        return i;
      }).toList(),
    );
  }

  /// Remove an item from cart.
  void removeItem(String itemId, String? unitId) {
    state = Cart(
      items: state.items.where((i) => !_sameLine(i, itemId, unitId)).toList(),
    );
  }

  /// Clear all items.
  void clearCart() {
    state = const Cart();
  }

  /// Restore cart from a versioned held-order snapshot.
  void restoreFromHeldOrderJson(String snapshotJson) {
    state = Cart(items: CartMapper.cartItemsFromHeldOrderJson(snapshotJson));
  }

  bool _sameLine(CartItem item, String itemId, String? unitId) {
    return item.itemId == itemId && item.unitId == unitId;
  }

  CartItem? _findLine(String itemId, String? unitId) {
    for (final item in state.items) {
      if (_sameLine(item, itemId, unitId)) return item;
    }
    return null;
  }

  Future<ResolvedItemPrice> _resolvePrice(
    String itemId,
    String unitId,
    double quantity,
  ) async {
    try {
      final price = await _priceResolver!(
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

/// Cart provider.
final cartProvider = StateNotifierProvider<CartNotifier, Cart>((ref) {
  return CartNotifier(
    priceResolver:
        ({
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
