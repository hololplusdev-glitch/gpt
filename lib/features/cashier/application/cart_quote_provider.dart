import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_flutter/core/services/pricing/pricing_engine.dart';
import 'package:pos_flutter/features/cashier/application/cart_mapper.dart';
import 'package:pos_flutter/features/cashier/application/cart_notifier.dart';
import 'package:pos_flutter/features/sales/application/sales_service.dart';

class CartQuoteState {
  final CheckoutQuote? quote;
  final Object? error;

  const CartQuoteState._({this.quote, this.error});

  const CartQuoteState.empty() : this._();

  const CartQuoteState.data(CheckoutQuote quote) : this._(quote: quote);

  const CartQuoteState.failure(Object error) : this._(error: error);

  bool get hasQuote => quote != null;
}

final cartQuoteProvider = Provider<CartQuoteState>((ref) {
  final cart = ref.watch(cartProvider);
  if (cart.isEmpty) return const CartQuoteState.empty();

  try {
    final quote = ref
        .watch(salesServiceProvider)
        .quoteSale(lineItems: CartMapper.saleLineInputs(cart));
    return CartQuoteState.data(quote);
  } catch (e) {
    return CartQuoteState.failure(e);
  }
});
