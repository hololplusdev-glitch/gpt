import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/features/cashier/application/product_providers.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/persistence/daos/catalog_dao.dart';
import 'package:holol_POS/core/services/pricing/pricing_engine.dart';
import 'package:holol_POS/features/sales/domain/models/sale_inputs.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/shared/models/sellable_item_snapshot.dart';
import 'package:holol_POS/shared/refactor/pos_business_rules.dart';

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

class CartQuoteState {
  final CheckoutQuote? quote;
  final Object? error;

  const CartQuoteState._({this.quote, this.error});

  const CartQuoteState.empty() : this._();

  const CartQuoteState.data(CheckoutQuote quote) : this._(quote: quote);

  const CartQuoteState.failure(Object error) : this._(error: error);

  bool get hasQuote => quote != null;
}

/// UI preview only.
/// Official checkout totals are recalculated by SaleCheckout.
final cartQuoteProvider = Provider<CartQuoteState>((ref) {
  final cart = ref.watch(cartProvider);

  if (cart.isEmpty) return const CartQuoteState.empty();

  final session = ref.watch(activePosSessionProvider).valueOrNull;
  if (session == null) return const CartQuoteState.empty();

  try {
    final quote = cart.previewQuote(
      pricingEngine: const PricingEngine(),
      useTax: session.activeUseTax,
      priceIncludesTax: session.priceIncludesTax,
    );

    return CartQuoteState.data(quote);
  } catch (e) {
    return CartQuoteState.failure(e);
  }
});

abstract final class PosRuntimeStateInvalidator {
  static T requireAsyncValue<T>(
    AsyncValue<T> state, {
    String message = 'Async state value is not ready.',
  }) {
    final value = state.valueOrNull;
    if (value == null) throw StateError(message);
    return value;
  }

  static void clearCashierState(dynamic ref) {
    ref.read(cartProvider.notifier).clearCart();
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(selectedCategoryProvider.notifier).state = null;
    ref.read(customerSearchQueryProvider.notifier).state = '';
    invalidateCashierCatalogState(ref);
  }

  static void invalidateCashierCatalogState(dynamic ref) {
    ref.invalidate(cashierProductCardsProvider);
    ref.invalidate(customerSearchResultsProvider);
    ref.invalidate(categoryListProvider);
  }

  static void invalidateMasterDataDownloadProviders(dynamic ref) {
    ref.invalidate(catalogReadinessProvider);
    invalidateCashierCatalogState(ref);
  }

  static void invalidateActiveSessionRuntime(dynamic ref) {
    ref.invalidate(activePosSessionProvider);
    ref.invalidate(activePaymentProfileProvider);
    ref.invalidate(manualPaymentProfileProvider);
  }

  static void invalidateSetupRuntime(
    dynamic ref, {
    required dynamic posSessionControllerProvider,
    required dynamic shiftControllerProvider,
    bool includeSyncProfile = false,
  }) {
    if (includeSyncProfile) ref.invalidate(syncProfileProvider);
    invalidateActiveSessionRuntime(ref);
    ref.invalidate(posSessionControllerProvider);
    ref.invalidate(shiftControllerProvider);
    invalidateMasterDataDownloadProviders(ref);
  }
}
