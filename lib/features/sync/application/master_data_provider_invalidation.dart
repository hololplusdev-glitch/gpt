import 'package:holol_POS/features/cashier/application/product_providers.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';

void invalidateMasterDataDownloadProviders(dynamic ref) {
  ref.invalidate(catalogReadinessProvider);
  ref.invalidate(cashierProductCardsProvider);
  ref.invalidate(categoryListProvider);
  ref.invalidate(customersProvider);
}
