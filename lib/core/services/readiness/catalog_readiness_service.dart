// core/services/readiness/catalog_readiness_service.dart
// WHY: Prevents entry to the cashier screen when the local catalog is
// incomplete — selling without items, prices, or POS_MACHINE config
// produces broken invoices that cannot be uploaded to Backend.

import 'package:pos_flutter/core/persistence/daos/catalog_dao.dart';
import 'package:pos_flutter/core/persistence/database.dart';

/// Aggregated readiness result — a single "go/no-go" gate.
class CatalogReadiness {
  static const noPricesForCurrentContext =
      'No prices for current store/price level';

  final bool hasMachineConfig;
  final bool hasItems;
  final bool hasSellableUnits;
  final bool hasPrices;
  final bool hasPaymentMethods;
  final bool hasStoreId;
  final bool hasPriceLevelId;
  final int itemCount;
  final int sellableUnitCount;
  final int priceCount;
  final int paymentMethodCount;
  final List<String> blockers;

  CatalogReadiness({
    required this.hasMachineConfig,
    required this.hasItems,
    required this.hasSellableUnits,
    required this.hasPrices,
    required this.hasPaymentMethods,
    required this.hasStoreId,
    required this.hasPriceLevelId,
    required this.itemCount,
    required this.sellableUnitCount,
    required this.priceCount,
    required this.paymentMethodCount,
    required this.blockers,
  });

  /// True only when all mandatory checks pass.
  bool get isReady => blockers.isEmpty;

  String get blockerSummary => blockers.join(', ');

  List<String> get syncWarnings => [
    if (blockers.contains(noPricesForCurrentContext))
      'ITEM_PRICE warning: No local prices for current store/price level.',
  ];
}

class CatalogReadinessService {
  final CatalogDao _catalogDao;
  final ActivePosSession? _activeSession;

  const CatalogReadinessService({
    required CatalogDao catalogDao,
    required ActivePosSession? activeSession,
  }) : _catalogDao = catalogDao,
       _activeSession = activeSession;

  /// Runs all readiness checks and returns an aggregated result.
  Future<CatalogReadiness> check() async {
    final blockers = <String>[];

    final storeId = _activeSession?.activeStoreId ?? '';
    final priceLevelId = _activeSession?.activePriceLevelId ?? '';
    final hasStoreId = storeId.isNotEmpty;
    final hasPriceLevelId = priceLevelId.isNotEmpty;
    if (!hasStoreId || !hasPriceLevelId) {
      blockers.add('POS_MACHINE defaults missing');
    }

    // Check 2: At least one active item exists.
    final itemCount = await _catalogDao.countActiveSellableItems();
    if (itemCount == 0) {
      blockers.add('No active items');
    }

    // Check 3: At least one sellable unit exists for an active item.
    final sellableUnitCount = await _catalogDao
        .countSellableUnitsForActiveItems();
    if (sellableUnitCount == 0) {
      blockers.add('No sellable item units');
    }

    // Check 4: At least one price row matches the current device context.
    final priceCount = hasStoreId && hasPriceLevelId
        ? await _catalogDao.countPricesForContext(storeId, priceLevelId)
        : 0;
    if (priceCount == 0) {
      blockers.add(CatalogReadiness.noPricesForCurrentContext);
    }

    // Check 5: At least one payment method exists.
    final paymentMethodCount = await _catalogDao.countActivePaymentMethods();
    if (paymentMethodCount == 0) {
      blockers.add('No active payment methods');
    }

    return CatalogReadiness(
      hasMachineConfig: hasStoreId && hasPriceLevelId,
      hasItems: itemCount > 0,
      hasSellableUnits: sellableUnitCount > 0,
      hasPrices: priceCount > 0,
      hasPaymentMethods: paymentMethodCount > 0,
      hasStoreId: hasStoreId,
      hasPriceLevelId: hasPriceLevelId,
      itemCount: itemCount,
      sellableUnitCount: sellableUnitCount,
      priceCount: priceCount,
      paymentMethodCount: paymentMethodCount,
      blockers: blockers,
    );
  }
}
