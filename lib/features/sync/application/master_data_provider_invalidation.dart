import 'package:pos_flutter/features/cashier/application/product_providers.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';

void invalidateMasterDataDownloadProviders(dynamic ref) {
  ref.invalidate(catalogReadinessProvider);
  ref.invalidate(cashierProductCardsProvider);
  ref.invalidate(categoryListProvider);
  ref.invalidate(paymentMethodsProvider);
  ref.invalidate(customersProvider);
}
