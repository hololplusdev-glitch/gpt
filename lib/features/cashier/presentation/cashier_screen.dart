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
import 'package:holol_POS/shared/refactor/pos_scan_flow.dart';
import 'package:holol_POS/shared/refactor/pos_ui_widgets.dart';

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

  final _scannerBuffer = StringBuffer();
  DateTime? _lastScannerKeyTime;
  DateTime? _scannerBufferStartedAt;

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
    if (_searchFocus.hasFocus || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final now = DateTime.now();
    final logicalKey = event.logicalKey;

    final isTerminator =
        logicalKey == LogicalKeyboardKey.enter ||
        logicalKey == LogicalKeyboardKey.numpadEnter ||
        logicalKey == LogicalKeyboardKey.tab;

    if (isTerminator) {
      final code = _scannerBuffer.toString();
      final startedAt = _scannerBufferStartedAt;
      _clearScannerBuffer();

      if (startedAt == null || code.trim().length < 3) {
        return KeyEventResult.ignored;
      }

      final elapsed = now.difference(startedAt);
      final maxScannerDuration = Duration(milliseconds: code.length * 90);

      if (elapsed <= maxScannerDuration) {
        unawaited(
          _handleBarcodeSubmit(
            code,
            intent: _BarcodeSubmitIntent.scannerLikeInput,
          ),
        );
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    }

    final character = event.character;
    if (character == null || character.isEmpty) {
      return KeyEventResult.ignored;
    }

    if (character.runes.length != 1 ||
        character.codeUnitAt(0) < 0x20 ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }

    final last = _lastScannerKeyTime;
    if (last == null ||
        now.difference(last) > const Duration(milliseconds: 120)) {
      _scannerBuffer.clear();
      _scannerBufferStartedAt = now;
    }

    _scannerBuffer.write(character);
    _lastScannerKeyTime = now;

    return KeyEventResult.handled;
  }

  void _clearScannerBuffer() {
    _scannerBuffer.clear();
    _lastScannerKeyTime = null;
    _scannerBufferStartedAt = null;
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
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
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
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          title: Text(l10n.posShort),
        ),
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
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < AppBreakpoints.medium;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: const BoxDecoration(
            gradient: AppColors.headerGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: isCompact
                ? Padding(
                    padding: AppSpacing.verticalSm,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            AppBrandMark(label: l10n.posShort),
                            const Spacer(),
                            AppCashierBadge(cashierName: cashierName),
                            const SizedBox(width: AppSpacing.xs),
                            AppOverflowActions(
                              onHold: () => _holdOrder(context),
                              onHeldOrders: () => _showHeldOrders(context),
                              onShift: () => context.push(AppRoutes.shift),
                              onHistory: () => context.push(AppRoutes.history),
                              onSync: () => context.push(AppRoutes.syncMonitor),
                              onDevices: () =>
                                  context.push(AppRoutes.posDevices),
                              onSettings: () =>
                                  context.push(AppRoutes.settings),
                            ),
                            AppLogoutButton(
                              onPressed: () => ref
                                  .read(posSessionControllerProvider.notifier)
                                  .logout(),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppCashierSearchField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          hintText: l10n.searchProductsOrScanBarcode,
                          onChanged: _scheduleProductSearch,
                          onSubmitted: (value) => _handleBarcodeSubmit(
                            value,
                            intent: _BarcodeSubmitIntent.manualSearch,
                          ),
                          onScanPressed: ref.watch(hasCameraScannerProvider)
                              ? () => showBarcodeScannerSheet(context)
                              : null,
                        ),
                      ],
                    ),
                  )
                : SizedBox(
                    height: AppSpacing.jumbo + AppSpacing.sm,
                    child: Row(
                      children: [
                        AppBrandMark(label: l10n.posShort),
                        const SizedBox(width: AppSpacing.xxl),
                        Expanded(
                          child: AppCashierSearchField(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            hintText: l10n.searchProductsOrScanBarcode,
                            onChanged: _scheduleProductSearch,
                            onSubmitted: (value) => _handleBarcodeSubmit(
                              value,
                              intent: _BarcodeSubmitIntent.manualSearch,
                            ),
                            onScanPressed: ref.watch(hasCameraScannerProvider)
                                ? () => showBarcodeScannerSheet(context)
                                : null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
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
                          onPressed: () => ref
                              .read(posSessionControllerProvider.notifier)
                              .logout(),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
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
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.lg),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: AppColors.surface,
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                const Expanded(child: CartPanel()),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MenuAction extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuAction({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: AppSpacing.xl),
        const SizedBox(width: AppSpacing.md),
        Flexible(child: Text(label)),
      ],
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: AppSpacing.borderRadiusLg,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '${cart.totalLinesCount}',
                  style: const TextStyle(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              l10n.viewCart,
              style: const TextStyle(
                color: AppColors.onPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              quoteTotal,
              style: const TextStyle(
                color: AppColors.onPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.keyboard_arrow_up,
                color: AppColors.onPrimary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
