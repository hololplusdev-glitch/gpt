// core/services/readiness/catalog_readiness_service.dart
// WHY: Prevents entry to the cashier screen when the local catalog is
// incomplete — selling without items, prices, or POS_MACHINE config
// produces broken invoices that cannot be uploaded to Backend.

import 'package:holol_POS/core/persistence/daos/active_pos_session_dao.dart';
import 'package:holol_POS/core/persistence/daos/catalog_dao.dart';
import 'package:holol_POS/shared/refactor/pos_payment_draft.dart';
import 'package:holol_POS/shared/refactor/pos_runtime_state.dart';

/// Aggregated readiness result — a single "go/no-go" gate.
class CatalogReadiness {
  static const noPricesForCurrentContext =
      PosCatalogReadinessRules.noPricesForCurrentContext;

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

    final runtimeContext = PosRuntimeContextRules.tryRead(_activeSession);
    final hasStoreId = runtimeContext?.storeId.isNotEmpty ?? false;
    final hasPriceLevelId = runtimeContext?.priceLevelId.isNotEmpty ?? false;

    PosCatalogReadinessRules.addRuntimeContextBlockers(
      session: _activeSession,
      blockers: blockers,
    );

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
    final priceCount = runtimeContext == null
        ? 0
        : await _catalogDao.countPricesForContext(
            runtimeContext.storeId,
            runtimeContext.priceLevelId,
          );

    PosCatalogReadinessRules.addPriceBlockers(
      context: runtimeContext,
      priceCount: priceCount,
      blockers: blockers,
    );

    final paymentMethodCount = await _catalogDao.countActivePaymentMethods();
    blockers.addAll(
      PosCheckoutPaymentMasterDataPolicy.readinessBlockers(paymentMethodCount),
    );

    return CatalogReadiness(
      hasMachineConfig: hasStoreId && hasPriceLevelId,
      hasItems: itemCount > 0,
      hasSellableUnits: sellableUnitCount > 0,
      hasPrices: priceCount > 0,
      hasPaymentMethods:
          PosCheckoutPaymentMasterDataPolicy.hasUsablePaymentMethods(
            paymentMethodCount,
          ),
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
