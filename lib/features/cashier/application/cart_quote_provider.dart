import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:holol_POS/core/services/pricing/pricing_engine.dart';
import 'package:holol_POS/features/cashier/domain/models/cart.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';

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
