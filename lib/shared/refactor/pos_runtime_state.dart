import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/features/cashier/application/product_providers.dart';
import 'package:holol_POS/features/cashier/domain/models/cart.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';

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
