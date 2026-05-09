export 'package:pos_flutter/features/cashier/domain/models/cart.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_flutter/core/errors/app_exception.dart';
import 'package:pos_flutter/core/persistence/daos/catalog_dao.dart';
import 'package:pos_flutter/features/cashier/domain/models/cart.dart';
import 'package:pos_flutter/shared/models/enums.dart';
import 'package:pos_flutter/shared/models/sellable_item_snapshot.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';

typedef CartPriceResolver = Future<ResolvedItemPrice?> Function({
  required String itemId,
  required String unitId,
  required double quantity,
});

/// Riverpod state shell only.
/// Cart owns cart decisions. This notifier only applies async price resolution
/// and publishes the new Cart state.
class CartNotifier extends StateNotifier<Cart> {
  final CartPriceResolver _priceResolver;

  CartNotifier({required CartPriceResolver priceResolver})
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

final cartProvider = StateNotifierProvider<CartNotifier, Cart>((ref) {
  return CartNotifier(
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
