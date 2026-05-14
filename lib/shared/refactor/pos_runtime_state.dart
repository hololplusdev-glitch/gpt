import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/persistence/daos/catalog_dao.dart';
import 'package:holol_POS/core/services/pricing/pricing_engine.dart';
import 'package:holol_POS/features/sales/domain/models/sale_inputs.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/shared/models/sellable_item_snapshot.dart';
import 'package:holol_POS/shared/refactor/pos_business_rules.dart';
import 'package:holol_POS/core/persistence/daos/active_pos_session_dao.dart';
import 'package:holol_POS/core/persistence/daos/audit_dao.dart';
import 'package:holol_POS/core/persistence/daos/auth_dao.dart';
import 'package:holol_POS/core/persistence/daos/shift_dao.dart';
import 'package:holol_POS/core/persistence/database.dart' hide Customer;
import 'package:holol_POS/features/cashier/domain/models/product.dart';
import 'package:holol_POS/shared/models/customer.dart';
import 'package:uuid/uuid.dart';
import 'package:holol_POS/core/network/network_models.dart';
import 'package:holol_POS/core/services/master_data/master_data_contract.dart';
import 'package:holol_POS/core/services/master_data/master_data_download_helper.dart';
import 'package:holol_POS/core/services/master_data/master_data_sync_service.dart';

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

/// Command controller for POS runtime session.
///
/// SSOT rules:
/// - ActivePosSession stores runtime user + machine only.
/// - Shifts table is the only source of open-shift state.
/// - AuthDao owns PIN/user lookup only.
/// - AuditDao owns login/logout audit.
class PosSessionState {
  final bool isLoading;
  final bool isResolvingUser;
  final String? errorMessage;
  final PosUser? resolvedUser;
  final List<RuntimeMachineChoice> machineChoices;
  final String? selectedMachineNo;

  const PosSessionState({
    this.isLoading = false,
    this.isResolvingUser = false,
    this.errorMessage,
    this.resolvedUser,
    this.machineChoices = const [],
    this.selectedMachineNo,
  });

  bool get canLogin {
    return resolvedUser != null &&
        selectedMachineNo?.trim().isNotEmpty == true &&
        !isResolvingUser &&
        !isLoading;
  }

  PosSessionState copyWith({
    bool? isLoading,
    bool? isResolvingUser,
    String? errorMessage,
    bool clearError = false,
    PosUser? resolvedUser,
    bool clearResolvedUser = false,
    List<RuntimeMachineChoice>? machineChoices,
    String? selectedMachineNo,
    bool clearSelectedMachine = false,
  }) {
    return PosSessionState(
      isLoading: isLoading ?? this.isLoading,
      isResolvingUser: isResolvingUser ?? this.isResolvingUser,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      resolvedUser: clearResolvedUser
          ? null
          : (resolvedUser ?? this.resolvedUser),
      machineChoices: machineChoices ?? this.machineChoices,
      selectedMachineNo: clearSelectedMachine
          ? null
          : (selectedMachineNo ?? this.selectedMachineNo),
    );
  }
}

class PosSessionController extends StateNotifier<PosSessionState> {
  final AuthDao _authDao;
  final AuditDao _auditDao;
  final ActivePosSessionDao _sessionDao;
  final ShiftDao _shiftDao;
  final Ref _ref;

  PosSessionController({
    required AuthDao authDao,
    required AuditDao auditDao,
    required ActivePosSessionDao sessionDao,
    required ShiftDao shiftDao,
    required Ref ref,
  }) : _authDao = authDao,
       _auditDao = auditDao,
       _sessionDao = sessionDao,
       _shiftDao = shiftDao,
       _ref = ref,
       super(const PosSessionState());

  static const _uuid = Uuid();

  int _resolveToken = 0;

  Future<void> resolveUserNumber(String value) async {
    final token = ++_resolveToken;
    final number = value.trim();

    state = const PosSessionState();

    if (number.isEmpty) {
      return;
    }

    state = state.copyWith(isResolvingUser: true, clearError: true);

    try {
      final user = await _authDao.findByUsername(number);

      if (token != _resolveToken) return;

      if (user == null) {
        state = const PosSessionState(
          errorMessage: 'رقم المستخدم غير موجود في بيانات التشغيل.',
        );
        return;
      }

      if (!user.isActive || !user.canLoginPos) {
        state = const PosSessionState(
          errorMessage: 'هذا المستخدم غير مسموح له بالدخول إلى نقاط البيع.',
        );
        return;
      }

      final choices = await _sessionDao.listRuntimeMachineChoicesForUser(
        user: user,
      );

      if (token != _resolveToken) return;

      state = PosSessionState(
        resolvedUser: user,
        machineChoices: choices,
        selectedMachineNo: choices.length == 1
            ? choices.single.machineNo
            : null,
        errorMessage: choices.isEmpty
            ? 'لا توجد نقطة تشغيل مرتبطة بهذا المستخدم.'
            : null,
      );
    } catch (e) {
      if (token != _resolveToken) return;
      state = PosSessionState(errorMessage: ErrorMapper.userMessage(e));
    }
  }

  void selectMachine(String? machineNo) {
    state = state.copyWith(
      selectedMachineNo: machineNo,
      clearSelectedMachine: machineNo == null || machineNo.trim().isEmpty,
      clearError: true,
    );
  }

  Future<bool> hasLocalPinForResolvedUser() async {
    final user = state.resolvedUser;

    if (user == null) {
      state = state.copyWith(errorMessage: 'أدخل رقم المستخدم أولًا.');
      return false;
    }

    return _authDao.hasLocalPin(userId: user.id);
  }

  Future<bool> loginWithPin(String pin) async {
    final user = state.resolvedUser;
    final machineNo = state.selectedMachineNo?.trim();

    if (user == null || machineNo == null || machineNo.isEmpty) {
      state = state.copyWith(
        errorMessage: 'أدخل رقم المستخدم واختر نقطة التشغيل.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final hasPin = await _authDao.hasLocalPin(userId: user.id);

      if (hasPin) {
        final ok = await _authDao.verifyLocalPin(userId: user.id, pin: pin);

        if (!ok) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'PIN غير صحيح.',
          );
          return false;
        }
      } else {
        await _authDao.setLocalPin(userId: user.id, pin: pin);
      }

      final machine = await _sessionDao.getMachine(machineNo: machineNo);

      if (machine == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Selected POS machine not found.',
        );
        return false;
      }

      final existingMachineShift = await _shiftDao.getOpenShift(
        machine.machineNo,
      );

      if (existingMachineShift != null &&
          existingMachineShift.cashierId != user.id) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'يوجد شفت مفتوح على هذا الجهاز لمستخدم آخر. أغلق الشفت أولًا.',
        );
        return false;
      }

      final session = await _sessionDao.startSession(
        user: user,
        machine: machine,
      );

      await _auditDao.log(
        id: 'AUD_${_uuid.v4()}',
        action: AuditAction.login,
        actorId: session.activeUserId,
        actorName: session.activeUserName,
        terminalId: session.activeMachineNo,
      );

      await _refreshActiveSession();

      state = const PosSessionState();
      return true;
    } catch (e) {
      state = PosSessionState(errorMessage: ErrorMapper.userMessage(e));
      return false;
    }
  }

  Future<void> logout() async {
    final session = await _sessionDao.getActive();

    if (session != null) {
      await _auditDao.log(
        id: 'AUD_${_uuid.v4()}',
        action: AuditAction.logout,
        actorId: session.activeUserId,
        actorName: session.activeUserName,
        terminalId: session.activeMachineNo,
      );
    }

    await _sessionDao.clearActive();
    _clearCashierState();
    await _refreshActiveSession();

    state = const PosSessionState();
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  Future<void> _refreshActiveSession() async {
    PosRuntimeStateInvalidator.invalidateActiveSessionRuntime(_ref);
    await _ref.read(activePosSessionProvider.future);
  }

  void _clearCashierState() {
    PosRuntimeStateInvalidator.clearCashierState(_ref);
  }
}

final posSessionControllerProvider =
    StateNotifierProvider<PosSessionController, PosSessionState>((ref) {
      return PosSessionController(
        authDao: ref.watch(authDaoProvider),
        auditDao: ref.watch(auditDaoProvider),
        sessionDao: ref.watch(activePosSessionDaoProvider),
        shiftDao: ref.watch(shiftDaoProvider),
        ref: ref,
      );
    });

// WHY: DB-backed product/category/payment providers for the cashier UI.

final searchQueryProvider = StateProvider<String>((ref) => '');

final selectedCategoryProvider = StateProvider<String?>((ref) => null);

final categoryListProvider = FutureProvider<List<ProductCategory>>((ref) async {
  final rows = await ref.watch(catalogDaoProvider).getActiveGroups();
  return rows
      .map(
        (row) => ProductCategory(
          id: row.id,
          name: row.name,
          nameAr: row.nameAr,
          sortOrder: row.sortOrder,
          iconName: row.iconName,
        ),
      )
      .toList();
});

class CashierCatalogState {
  final List<ProductCardViewModel> products;
  final String? emptyReason;
  final String? emptyMessage;

  const CashierCatalogState({
    required this.products,
    this.emptyReason,
    this.emptyMessage,
  });
}

final cashierProductCardsProvider = FutureProvider<CashierCatalogState>((
  ref,
) async {
  final catalogDao = ref.watch(catalogDaoProvider);
  final search = ref.watch(searchQueryProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final session = ref.watch(activePosSessionProvider).valueOrNull;

  if (session == null) {
    return const CashierCatalogState(
      products: [],
      emptyReason: 'NO_ACTIVE_POS_SESSION',
      emptyMessage: 'لا توجد جلسة كاشير نشطة.',
    );
  }

  final storeId = session.activeStoreId;
  final priceLevelId = session.activePriceLevelId;

  if (storeId.isEmpty) {
    return const CashierCatalogState(
      products: [],
      emptyReason: 'NO_ACTIVE_STORE',
      emptyMessage: 'لا يوجد مخزن نشط للجهاز الحالي.',
    );
  }

  if (priceLevelId.isEmpty) {
    return const CashierCatalogState(
      products: [],
      emptyReason: 'NO_ACTIVE_PRICE_LEVEL',
      emptyMessage: 'لا يوجد مستوى سعر نشط للجهاز الحالي.',
    );
  }

  final items = switch ((search.isNotEmpty, selectedCategory)) {
    (true, _) => await catalogDao.searchItems(search, storeId, priceLevelId),
    (false, final category?) => await catalogDao.getItemsByGroup(
      category,
      storeId,
      priceLevelId,
    ),
    _ => await catalogDao.getActiveItems(storeId, priceLevelId),
  };

  if (items.isEmpty) {
    return CashierCatalogState(
      products: const [],
      emptyReason: search.isNotEmpty || selectedCategory != null
          ? 'NO_MATCHING_PRODUCTS'
          : 'NO_SELLABLE_ITEMS',
      emptyMessage: search.isNotEmpty || selectedCategory != null
          ? 'لا توجد منتجات مطابقة.'
          : 'لا توجد منتجات قابلة للبيع.',
    );
  }

  final unitsByItem = await catalogDao.getSellableUnitsForItems(
    items.map((item) => item.id).toSet(),
  );
  final allUnits = unitsByItem.values.expand((units) => units).toList();

  final pricesByItemUnit = await catalogDao.resolveItemPricesForUnits(
    allUnits,
    storeId: storeId,
    priceLevelId: priceLevelId,
  );

  final cards = <ProductCardViewModel>[];

  for (final item in items) {
    final itemUnits = unitsByItem[item.id] ?? const <SellableItemUnit>[];

    final units = _pricedUnitsForItem(
      catalogDao: catalogDao,
      item: item,
      units: itemUnits,
      pricesByItemUnit: pricesByItemUnit,
    );

    cards.add(ProductCardViewModel(item: _productFromRow(item), units: units));
  }

  if (cards.every((card) => card.units.isEmpty)) {
    return CashierCatalogState(
      products: const [],
      emptyReason: 'NO_PRICED_PRODUCTS',
      emptyMessage: 'لا توجد أسعار صالحة لهذا المخزن ومستوى السعر.',
    );
  }

  return CashierCatalogState(products: cards);
});

final customerSearchQueryProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

final customerSearchResultsProvider =
    FutureProvider.autoDispose<List<Customer>>((ref) async {
      final query = ref.watch(customerSearchQueryProvider);
      return ref
          .watch(catalogDaoProvider)
          .searchActiveCustomers(query: query, limit: 30);
    });

ProductListItem _productFromRow(Item item) {
  return ProductListItem(
    id: item.id,
    name: item.name,
    nameAr: item.nameAr,
    categoryId: item.groupId,
    imageUrl: item.imageUrl,
    defaultUnitId: item.defaultUnitId,
    code: item.code,
  );
}

List<ProductUnitOption> _pricedUnitsForItem({
  required CatalogDao catalogDao,
  required Item item,
  required List<SellableItemUnit> units,
  required Map<ItemUnitPriceKey, ResolvedItemPrice> pricesByItemUnit,
}) {
  final pricedUnits = <ProductUnitOption>[];

  for (final unit in units) {
    final price =
        pricesByItemUnit[ItemUnitPriceKey(item.id, unit.sourceUnitId)];

    if (price == null) {
      continue;
    }

    try {
      final sellableItem = catalogDao.toSellableItemSnapshot(
        item: item,
        price: price,
        fallbackUnitId: unit.sourceUnitId,
        fallbackUnitName: unit.unitName,
        barcode: unit.barcode,
      );

      pricedUnits.add(
        ProductUnitOption(
          isDefault: unit.isDefault,
          sellableItem: sellableItem,
        ),
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw BusinessException(
        'تعذر تجهيز المنتج ${item.name} للبيع.',
        code: 'PRODUCT_CARD_BUILD_FAILED',
      );
    }
  }

  return pricedUnits;
}

class PosMasterDataProgressSnapshot {
  final double progress;
  final String status;
  final String pagination;

  const PosMasterDataProgressSnapshot({
    required this.progress,
    required this.status,
    required this.pagination,
  });

  factory PosMasterDataProgressSnapshot.fromProgress(
    MasterDataSyncProgress progress,
  ) {
    final totalSections = progress.totalSections <= 0
        ? 1
        : progress.totalSections;

    final overallProgress =
        ((progress.currentSection + progress.sectionProgress) / totalSections)
            .clamp(0.0, 1.0);

    final pagination = progress.totalPages > 1
        ? 'صفحة ${progress.currentPage} من ${progress.totalPages}'
        : '';

    final label = progress.typeCode == MasterDataType.devicePrivilege.code
        ? progress.typeLabel
        : 'تحميل ${progress.typeCode}';

    return PosMasterDataProgressSnapshot(
      progress: overallProgress,
      status: label,
      pagination: pagination,
    );
  }
}

class PosIncrementalMasterDataResult {
  final MasterDataDownloadResult download;
  final String message;
  final bool isError;

  const PosIncrementalMasterDataResult({
    required this.download,
    required this.message,
    required this.isError,
  });
}

abstract final class PosMasterDataRuntimeWorkflow {
  static Future<String> completeInitialSetup({
    required dynamic ref,
    required SyncProfile syncProfile,
    required MasterDataSyncCancelHandle cancelHandle,
    required dynamic posSessionControllerProvider,
    required dynamic shiftControllerProvider,
    required void Function(PosMasterDataProgressSnapshot snapshot) onProgress,
  }) async {
    final cleanProfile = syncProfile;
    if (cleanProfile.custCode.trim().isEmpty) {
      throw StateError('Customer code is required.');
    }

    final configRepo = ref.read(posConfigProvider);
    await configRepo.seedDefaults();
    await configRepo.initialize();

    await ref.read(masterDataDaoProvider).clearMasterDataCache();

    final download = await ref
        .read(masterDataDownloadHelperProvider)
        .download(
          syncProfile: cleanProfile,
          mode: MasterDataSyncMode.initial,
          cancelHandle: cancelHandle,
          requireReady: false,
          throwOnFatalFailures: true,
          onProgress: (progress) {
            onProgress(PosMasterDataProgressSnapshot.fromProgress(progress));
          },
        );

    await verifySetupUserExists(
      ref: ref,
      usrId: cleanProfile.bootstrapUserId.trim(),
    );

    PosRuntimeStateInvalidator.invalidateMasterDataDownloadProviders(ref);
    await ref.read(runtimeConfigRepositoryProvider).setSetupComplete(true);

    return download.operationalWarningSummary();
  }

  static Future<void> cleanupFailedInitialSetup({
    required dynamic ref,
    required dynamic posSessionControllerProvider,
    required dynamic shiftControllerProvider,
  }) async {
    await ref.read(masterDataDaoProvider).clearMasterDataCache();
    await ref.read(activePosSessionDaoProvider).clearActive();

    PosRuntimeStateInvalidator.invalidateMasterDataDownloadProviders(ref);
    PosRuntimeStateInvalidator.invalidateSetupRuntime(
      ref,
      posSessionControllerProvider: posSessionControllerProvider,
      shiftControllerProvider: shiftControllerProvider,
    );
  }

  static Future<void> resetSetup({
    required dynamic ref,
    required dynamic posSessionControllerProvider,
    required dynamic shiftControllerProvider,
  }) async {
    final repo = ref.read(runtimeConfigRepositoryProvider);

    await repo.resetSetupStatus();
    await repo.clearSyncProfile();
    await ref
        .read(masterDataDaoProvider)
        .clearMasterDataCache(clearRunLogs: true);
    await ref.read(activePosSessionDaoProvider).clearActive();
    ref.read(apiClientProvider).clearConfiguration();

    PosRuntimeStateInvalidator.invalidateSetupRuntime(
      ref,
      posSessionControllerProvider: posSessionControllerProvider,
      shiftControllerProvider: shiftControllerProvider,
      includeSyncProfile: true,
    );
  }

  static Future<void> verifySetupUserExists({
    required dynamic ref,
    required String usrId,
  }) async {
    final exists = await ref.read(masterDataDaoProvider).setupUserExists(usrId);
    if (!exists) {
      throw SyncException(
        'Bootstrap user was not found in synced users.',
        code: 'SETUP_USER_NOT_SYNCED',
      );
    }
  }

  static Future<MasterDataDownloadResult> downloadIncremental({
    required dynamic ref,
    required SyncProfile syncProfile,
    required MasterDataSyncCancelHandle cancelHandle,
    required void Function(MasterDataSyncProgress progress) onProgress,
  }) async {
    final download = await ref
        .read(masterDataDownloadHelperProvider)
        .download(
          syncProfile: syncProfile,
          mode: MasterDataSyncMode.incremental,
          cancelHandle: cancelHandle,
          onProgress: onProgress,
        );

    PosRuntimeStateInvalidator.invalidateMasterDataDownloadProviders(ref);
    return download;
  }

  static String incrementalResultMessage({
    required MasterDataDownloadResult download,
    required String noChangesMessage,
    required String Function(int rowCount, int failedCount) summaryBuilder,
  }) {
    final result = download.summary;
    final failed = download.fatalFailures;
    final readinessWarnings = download.readinessWarnings;

    final resultMessage = result.allNoChanges
        ? noChangesMessage
        : failed.isNotEmpty
        ? summaryBuilder(result.rowCount, failed.length)
        : summaryBuilder(result.rowCount, 0);

    return readinessWarnings.isEmpty
        ? resultMessage
        : '$resultMessage\n${readinessWarnings.join('\n')}';
  }

  static bool incrementalResultIsError(MasterDataDownloadResult download) {
    return download.fatalFailures.isNotEmpty ||
        download.readinessWarnings.isNotEmpty;
  }

  static bool isCancelled(Object error) {
    return error is AppException && error.code == 'CANCELLED';
  }
}
