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
import 'package:holol_POS/core/scanner/barcode_scanner_service.dart';
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

    final service = ref.read(barcodeScannerServiceProvider);
    final result = await service.processBarcode(
      input,
      source: BarcodeScanSource.keyboard,
    );

    if (!mounted) return;

    switch (result) {
      case ScanSuccess():
        final addResult = await ref
            .read(cartProvider.notifier)
            .addSellableItem(result.item);

        if (!mounted) return;

        _searchController.clear();
        _applyProductSearch('');

        _playScanFeedback(success: true);

        AppSnackbar.showSuccess(
          context,
          addResult.wasIncremented
              ? l10n.scanAddedProductQuantity(
                  addResult.itemName,
                  addResult.quantity.round(),
                )
              : l10n.scanAddedProduct(addResult.itemName),
        );

      case ScanNotFound():
        if (intent == _BarcodeSubmitIntent.scannerLikeInput) {
          _playScanFeedback(success: false);
          AppSnackbar.showError(context, l10n.barcodeNotFoundCatalog);
        } else {
          _applyProductSearch(input);
        }

      case ScanNoPrice():
        _playScanFeedback(success: false);
        AppSnackbar.showError(
          context,
          l10n.scannedItemNotSellableInCurrentStore,
        );

      case ScanError():
        _playScanFeedback(success: false);
        AppSnackbar.showError(context, result.message);

      case ScanDuplicate():
        _playScanFeedback(success: false);
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

  void _playScanFeedback({required bool success}) {
    try {
      SystemSound.play(success ? SystemSoundType.click : SystemSoundType.alert);
      if (success) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    } catch (_) {
      // Feedback is non-critical.
    }
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
                            _BrandMark(label: l10n.posShort),
                            const Spacer(),
                            _CashierBadge(cashierName: cashierName),
                            const SizedBox(width: AppSpacing.xs),
                            _OverflowActions(
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
                            _LogoutButton(
                              onPressed: () => ref
                                  .read(posSessionControllerProvider.notifier)
                                  .logout(),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _SearchField(
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
                        _BrandMark(label: l10n.posShort),
                        const SizedBox(width: AppSpacing.xxl),
                        Expanded(
                          child: _SearchField(
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
                        _TopBarButton(
                          icon: Icons.pause_circle_outline,
                          label: l10n.hold,
                          onTap: () => _holdOrder(context),
                        ),
                        _TopBarButton(
                          icon: Icons.restore_page_outlined,
                          label: 'المعلقة',
                          onTap: () => _showHeldOrders(context),
                        ),
                        _TopBarButton(
                          icon: Icons.analytics_outlined,
                          label: 'الشفت',
                          onTap: () => context.push(AppRoutes.shift),
                        ),
                        _TopBarButton(
                          icon: Icons.history,
                          label: l10n.salesHistory,
                          onTap: () => context.push(AppRoutes.history),
                        ),
                        _OverflowActions(
                          onHold: () => _holdOrder(context),
                          onHeldOrders: () => _showHeldOrders(context),
                          onShift: () => context.push(AppRoutes.shift),
                          onHistory: () => context.push(AppRoutes.history),
                          onSync: () => context.push(AppRoutes.syncMonitor),
                          onDevices: () => context.push(AppRoutes.posDevices),
                          onSettings: () => context.push(AppRoutes.settings),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _CashierBadge(cashierName: cashierName),
                        const SizedBox(width: AppSpacing.xs),
                        _LogoutButton(
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

class _BrandMark extends StatelessWidget {
  final String label;

  const _BrandMark({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.point_of_sale,
          color: AppColors.onPrimary,
          size: AppSpacing.xxl,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.onPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onScanPressed;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onChanged,
    this.onSubmitted,
    this.onScanPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: SizedBox(
        height: AppSpacing.jumbo,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(color: AppColors.onPrimary, fontSize: 14),
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.onPrimary.withValues(alpha: 0.15),
            hintText: hintText,
            hintStyle: TextStyle(
              color: AppColors.onPrimary.withValues(alpha: 0.6),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: AppColors.onPrimary.withValues(alpha: 0.7),
              size: AppSpacing.xl,
            ),
            contentPadding: AppSpacing.horizontalMd,
            border: OutlineInputBorder(
              borderRadius: AppSpacing.borderRadiusMd,
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppSpacing.borderRadiusMd,
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppSpacing.borderRadiusMd,
              borderSide: BorderSide(
                color: AppColors.onPrimary.withValues(alpha: 0.4),
              ),
            ),
            suffixIcon: onScanPressed != null
                ? IconButton(
                    icon: Icon(
                      Icons.qr_code_scanner,
                      color: AppColors.onPrimary.withValues(alpha: 0.7),
                      size: AppSpacing.xl,
                    ),
                    tooltip: AppLocalizations.of(context)!.scanBarcode,
                    onPressed: onScanPressed,
                  )
                : null,
          ),
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
        ),
      ),
    );
  }
}

class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TopBarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppSpacing.borderRadiusMd,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: AppColors.onPrimary.withValues(alpha: 0.06),
              borderRadius: AppSpacing.borderRadiusMd,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: AppColors.onPrimary.withValues(alpha: 0.85),
                  size: 20,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.onPrimary.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CashierBadge extends StatelessWidget {
  final String cashierName;

  const _CashierBadge({required this.cashierName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.onPrimary.withValues(alpha: 0.1),
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(color: AppColors.onPrimary.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, color: AppColors.onPrimary, size: 16),
          ),
          const SizedBox(width: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              cashierName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.onPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _LogoutButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return IconButton(
      icon: Icon(
        Icons.logout,
        color: AppColors.onPrimary.withValues(alpha: 0.7),
        size: AppSpacing.xl,
      ),
      tooltip: l10n.logout,
      onPressed: onPressed,
    );
  }
}

class _OverflowActions extends StatelessWidget {
  final VoidCallback onHold;
  final VoidCallback onHeldOrders;
  final VoidCallback onShift;
  final VoidCallback onHistory;
  final VoidCallback onSync;
  final VoidCallback onDevices;
  final VoidCallback onSettings;

  const _OverflowActions({
    required this.onHold,
    required this.onHeldOrders,
    required this.onShift,
    required this.onHistory,
    required this.onSync,
    required this.onDevices,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopupMenuButton<VoidCallback>(
      tooltip: l10n.settings,
      icon: Icon(
        Icons.more_vert,
        color: AppColors.onPrimary.withValues(alpha: 0.85),
      ),
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: onHold,
          child: _MenuAction(
            icon: Icons.pause_circle_outline,
            label: l10n.hold,
          ),
        ),
        PopupMenuItem(
          value: onHeldOrders,
          child: const _MenuAction(
            icon: Icons.restore_page_outlined,
            label: 'الطلبات المعلقة',
          ),
        ),
        PopupMenuItem(
          value: onShift,
          child: const _MenuAction(
            icon: Icons.analytics_outlined,
            label: 'الشفت الحالي',
          ),
        ),
        PopupMenuItem(
          value: onHistory,
          child: _MenuAction(icon: Icons.history, label: l10n.salesHistory),
        ),
        PopupMenuItem(
          value: onSync,
          child: _MenuAction(icon: Icons.sync, label: l10n.syncStatus),
        ),
        PopupMenuItem(
          value: onDevices,
          child: _MenuAction(icon: Icons.devices_other, label: l10n.devices),
        ),
        PopupMenuItem(
          value: onSettings,
          child: _MenuAction(icon: Icons.settings, label: l10n.settings),
        ),
      ],
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
