// features/cashier/presentation/cashier_screen.dart
// Main cashier workspace: product grid + cart panel.
// Supports normal search, USB/Bluetooth keyboard-wedge scanners, and mobile camera scanner.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:holol_POS/app/router.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/layout.dart';
import 'package:holol_POS/core/design_system/spacing.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/l10n/app_localizations.dart';
import 'package:holol_POS/core/scanner/scanner_providers.dart';
import 'package:holol_POS/core/services/formatters/pos_formatters.dart';
import 'package:holol_POS/features/auth/application/pos_session_controller.dart';
import 'package:holol_POS/features/cashier/domain/models/cart.dart';
import 'package:holol_POS/features/cashier/application/cart_quote_provider.dart';
import 'package:holol_POS/features/cashier/application/product_providers.dart';
import 'package:holol_POS/features/cashier/presentation/widgets/barcode_scanner_overlay.dart';
import 'package:holol_POS/features/cashier/presentation/widgets/cart_panel.dart';
import 'package:holol_POS/features/cashier/presentation/widgets/product_grid.dart';
import 'package:holol_POS/features/sales/application/held_orders_service.dart';
import 'package:holol_POS/shared/presentation/utils/app_snackbar.dart';
import 'package:holol_POS/shared/presentation/widgets/app_button.dart';
import 'package:holol_POS/shared/presentation/widgets/app_info_banner.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
import 'package:holol_POS/shared/refactor/pos_runtime_state.dart';
import 'package:holol_POS/shared/refactor/pos_ui_widgets.dart';
import 'package:holol_POS/shared/presentation/widgets/app_scaffold.dart';
import 'package:holol_POS/shared/presentation/widgets/app_search_field.dart';

enum _BarcodeSubmitIntent { manualSearch, scannerLikeInput }

class CashierScreen extends ConsumerStatefulWidget {
  const CashierScreen({super.key});

  @override
  ConsumerState<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends ConsumerState<CashierScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _searchDebounce;

  final _keyboardScanner = PosKeyboardScannerBuffer();

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeSubmit(
    String text, {
    _BarcodeSubmitIntent intent = _BarcodeSubmitIntent.manualSearch,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final input = text.trim();
    if (input.isEmpty) return;

    final result = await PosScanFlow.processKeyboard(
      rawCode: input,
      scannerService: ref.read(barcodeScannerServiceProvider),
      cartController: ref.read(cartProvider.notifier),
      manualSearchFallback: intent == _BarcodeSubmitIntent.manualSearch,
    );

    if (!mounted) return;

    switch (result.outcome) {
      case PosScanFlowOutcome.added:
        final addResult = result.cartResult!;

        _searchController.clear();
        _applyProductSearch('');

        PosScanFeedbackPlayer.play(success: true);

        AppSnackbar.showSuccess(
          context,
          addResult.wasIncremented
              ? l10n.scanAddedProductQuantity(
                  addResult.itemName,
                  addResult.quantity.round(),
                )
              : l10n.scanAddedProduct(addResult.itemName),
        );

      case PosScanFlowOutcome.manualSearch:
        _applyProductSearch(input);

      case PosScanFlowOutcome.notFound:
        PosScanFeedbackPlayer.play(success: false);
        AppSnackbar.showError(context, l10n.barcodeNotFoundCatalog);

      case PosScanFlowOutcome.noPrice:
        PosScanFeedbackPlayer.play(success: false);
        AppSnackbar.showError(
          context,
          l10n.scannedItemNotSellableInCurrentStore,
        );

      case PosScanFlowOutcome.error:
        PosScanFeedbackPlayer.play(success: false);
        AppSnackbar.showError(
          context,
          result.errorMessage ?? 'تعذر معالجة الباركود.',
        );

      case PosScanFlowOutcome.duplicate:
        PosScanFeedbackPlayer.play(success: false);
        AppSnackbar.showError(context, 'الباركود مكرر في الكتالوج');
    }

    _searchFocus.requestFocus();
  }

  KeyEventResult _handleScannerKeyEvent(FocusNode node, KeyEvent event) {
    final scannerEvent = _keyboardScanner.handle(
      event,
      textInputFocused: _searchFocus.hasFocus,
      now: DateTime.now(),
    );

    switch (scannerEvent.disposition) {
      case PosKeyboardScannerDisposition.submit:
        unawaited(
          _handleBarcodeSubmit(
            scannerEvent.code!,
            intent: _BarcodeSubmitIntent.scannerLikeInput,
          ),
        );
        return KeyEventResult.handled;

      case PosKeyboardScannerDisposition.buffering:
        return KeyEventResult.handled;

      case PosKeyboardScannerDisposition.ignored:
        return KeyEventResult.ignored;
    }
  }

  void _scheduleProductSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 275), () {
      if (!mounted) return;
      ref.read(searchQueryProvider.notifier).state = value.trim();
    });
  }

  void _applyProductSearch(String value) {
    _searchDebounce?.cancel();
    ref.read(searchQueryProvider.notifier).state = value.trim();
  }

  Future<void> _showHeldOrders(BuildContext context) async {
    final cart = ref.read(cartProvider);

    if (cart.isNotEmpty) {
      AppSnackbar.showWarning(
        context,
        'أكمل أو امسح السلة الحالية قبل استرجاع طلب معلق.',
      );
      return;
    }

    final service = ref.read(heldOrdersServiceProvider);

    try {
      final orders = await service.getCurrentHeldOrders();

      if (!context.mounted) return;

      if (orders.isEmpty) {
        AppSnackbar.showWarning(context, 'لا توجد طلبات معلقة.');
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return Container(
            constraints: const BoxConstraints(maxHeight: 560),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Drag Handle ──
                const SizedBox(height: AppSpacing.sm),
                const AppBottomSheetHandle(),
                // ── Header ──
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    0,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: AppSpacing.borderRadiusLg,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.pause_circle_outline,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'الطلبات المعلقة',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${orders.length} طلب',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // ── Orders List ──
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (itemContext, index) {
                      final order = orders[index];
                      final title =
                          order.referenceName?.trim().isNotEmpty == true
                          ? order.referenceName!
                          : order.customerNameSnapshot?.trim().isNotEmpty ==
                                true
                          ? order.customerNameSnapshot!
                          : 'طلب معلق';

                      return Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: AppSpacing.borderRadiusMd,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            // ── Order Info ──
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xxs),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.sm,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius:
                                              AppSpacing.borderRadiusSm,
                                        ),
                                        child: Text(
                                          PosFormatters.amount(
                                            order.grandTotal,
                                          ),
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Icon(
                                        Icons.access_time,
                                        size: 13,
                                        color: AppColors.textHint,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        PosFormatters.dateTime(order.heldAt),
                                        style: const TextStyle(
                                          color: AppColors.textHint,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // ── Actions ──
                            const SizedBox(width: AppSpacing.sm),
                            FilledButton.tonalIcon(
                              onPressed: () async {
                                try {
                                  final resumeResult = await service
                                      .resumeHeldOrder(orderId: order.id);

                                  ref
                                      .read(cartProvider.notifier)
                                      .restoreFromSaleLineInputs(
                                        resumeResult.lines,
                                      );

                                  if (sheetContext.mounted) {
                                    Navigator.of(sheetContext).pop();
                                  }

                                  if (context.mounted) {
                                    final warningText =
                                        resumeResult.warnings.isEmpty
                                        ? ''
                                        : '\n${resumeResult.warnings.take(3).join('\n')}';
                                    AppSnackbar.showSuccess(
                                      context,
                                      'تم استرجاع الطلب المعلق.$warningText',
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    AppSnackbar.showError(
                                      context,
                                      ErrorMapper.userMessage(e),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.restore, size: 18),
                              label: const Text('استرجاع'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.success.withValues(
                                  alpha: 0.1,
                                ),
                                foregroundColor: AppColors.success,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            IconButton(
                              tooltip: 'إلغاء',
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.error,
                                size: 20,
                              ),
                              onPressed: () async {
                                try {
                                  await service.cancelHeldOrder(
                                    orderId: order.id,
                                  );

                                  if (sheetContext.mounted) {
                                    Navigator.of(sheetContext).pop();
                                  }

                                  if (context.mounted) {
                                    AppSnackbar.showSuccess(
                                      context,
                                      'تم إلغاء الطلب المعلق.',
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    AppSnackbar.showError(
                                      context,
                                      ErrorMapper.userMessage(e),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          );
        },
      );
    } on SaleException catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, e.message);
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, ErrorMapper.userMessage(e));
      }
    }
  }

  Future<void> _holdOrder(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final cart = ref.read(cartProvider);

    if (cart.isEmpty) {
      AppSnackbar.showWarning(context, l10n.cartEmptyNothingToHold);
      return;
    }

    final activeSession = ref.read(activePosSessionProvider).valueOrNull;
    if (activeSession == null) {
      return;
    }

    final heldOrdersService = ref.read(heldOrdersServiceProvider);

    try {
      await heldOrdersService.holdOrder(items: cart.toSaleLineInputs());

      ref.read(cartProvider.notifier).clearCart();

      if (context.mounted) {
        AppSnackbar.showSuccess(context, l10n.orderHeldSuccessfully);
      }
    } on SaleException catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, e.message);
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, ErrorMapper.userMessage(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 1024;

    final activeSession = ref.watch(activePosSessionProvider).valueOrNull;

    if (activeSession == null) {
      return AppScaffold(
        title: l10n.posShort,
        icon: Icons.point_of_sale,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppContentWidth.narrow),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppInfoBanner.warning(
                  message: 'No active POS session. Please select a machine.',
                ),
                const SizedBox(height: AppSpacing.md),
                const SelectableText(
                  'No session found. Please return to user selection.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    AppButton.primary(
                      onPressed: () => context.push(AppRoutes.settings),
                      icon: Icons.settings,
                      label: l10n.settings,
                    ),
                    AppButton.outlined(
                      onPressed: () => context.push(AppRoutes.posDevices),
                      icon: Icons.devices,
                      label: l10n.posDevices,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Focus(
      autofocus: true,
      onKeyEvent: _handleScannerKeyEvent,
      child: ColoredBox(
        color: AppColors.background,
        child: Column(
          children: [
            _buildTopBar(context, activeSession.activeUserName),
            Expanded(
              child: isWide
                  ? _buildWideLayout()
                  : _buildNarrowLayout(cart.isNotEmpty),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, String cashierName) {
    final l10n = AppLocalizations.of(context)!;
    final canScanWithCamera = ref.watch(hasCameraScannerProvider);

    final search = AppScaffoldSearchConfig(
      controller: _searchController,
      focusNode: _searchFocus,
      hintText: l10n.searchProductsOrScanBarcode,
      mode: AppSearchFieldMode.barcode,
      onChanged: _scheduleProductSearch,
      onSubmitted: (value) => _handleBarcodeSubmit(
        value,
        intent: _BarcodeSubmitIntent.manualSearch,
      ),
      onScanPressed: canScanWithCamera
          ? () => showBarcodeScannerSheet(context)
          : null,
    );

    return AppScaffold.header(
      context,
      titleWidget: AppBrandMark(label: l10n.posShort),
      search: search,
      variant: AppScaffoldVariant.pos,
      actions: [
        AppTopBarButton(
          icon: Icons.pause_circle_outline,
          label: l10n.hold,
          onTap: () => _holdOrder(context),
        ),
        AppTopBarButton(
          icon: Icons.restore_page_outlined,
          label: 'المعلقة',
          onTap: () => _showHeldOrders(context),
        ),
        AppTopBarButton(
          icon: Icons.analytics_outlined,
          label: 'الشفت',
          onTap: () => context.push(AppRoutes.shift),
        ),
        AppTopBarButton(
          icon: Icons.history,
          label: l10n.salesHistory,
          onTap: () => context.push(AppRoutes.history),
        ),
        AppOverflowActions(
          onHold: () => _holdOrder(context),
          onHeldOrders: () => _showHeldOrders(context),
          onShift: () => context.push(AppRoutes.shift),
          onHistory: () => context.push(AppRoutes.history),
          onSync: () => context.push(AppRoutes.syncMonitor),
          onDevices: () => context.push(AppRoutes.posDevices),
          onSettings: () => context.push(AppRoutes.settings),
        ),
        const SizedBox(width: AppSpacing.sm),
        AppCashierBadge(cashierName: cashierName),
        const SizedBox(width: AppSpacing.xs),
        AppLogoutButton(
          onPressed: () =>
              ref.read(posSessionControllerProvider.notifier).logout(),
        ),
      ],
      compactActions: [
        AppCashierBadge(cashierName: cashierName),
        const SizedBox(width: AppSpacing.xs),
        AppOverflowActions(
          onHold: () => _holdOrder(context),
          onHeldOrders: () => _showHeldOrders(context),
          onShift: () => context.push(AppRoutes.shift),
          onHistory: () => context.push(AppRoutes.history),
          onSync: () => context.push(AppRoutes.syncMonitor),
          onDevices: () => context.push(AppRoutes.posDevices),
          onSettings: () => context.push(AppRoutes.settings),
        ),
        AppLogoutButton(
          onPressed: () =>
              ref.read(posSessionControllerProvider.notifier).logout(),
        ),
      ],
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        const Expanded(flex: 65, child: ProductGrid()),
        Container(width: 1, color: AppColors.border),
        const Expanded(flex: 35, child: CartPanel()),
      ],
    );
  }

  Widget _buildNarrowLayout(bool hasCartItems) {
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: hasCartItems ? 96 : 0),
          child: const ProductGrid(),
        ),
        if (hasCartItems)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _CartPreviewBar(onTap: () => _showCartSheet(context)),
          ),
      ],
    );
  }

  void _showCartSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: MediaQuery.sizeOf(context).height < 720 ? 0.96 : 0.92,
          child: const AppRoundedBottomSheetFrame(child: CartPanel()),
        );
      },
    );
  }
}

class _CartPreviewBar extends ConsumerWidget {
  final VoidCallback onTap;

  const _CartPreviewBar({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final quoteState = ref.watch(cartQuoteProvider);
    final l10n = AppLocalizations.of(context)!;

    final quoteTotal = quoteState.quote == null
        ? l10n.quoteError
        : PosFormatters.amount(quoteState.quote!.grandTotal);

    return AppBottomDockBar(
      onTap: onTap,
      badgeText: '${cart.totalLinesCount}',
      label: l10n.viewCart,
      value: quoteTotal,
    );
  }
}
