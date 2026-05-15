// features/cashier/presentation/widgets/cart_panel.dart
// Cart panel displaying items, totals, and action buttons.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:holol_POS/app/router.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/spacing.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/l10n/app_localizations.dart';
import 'package:holol_POS/core/services/formatters/pos_formatters.dart';
import 'package:holol_POS/features/cashier/domain/models/cart.dart';
import 'package:holol_POS/features/cashier/presentation/dialogs/payment_dialog.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/shared/presentation/utils/app_snackbar.dart';
import 'package:holol_POS/shared/presentation/widgets/app_button.dart';
import 'package:holol_POS/shared/presentation/widgets/app_empty_state.dart';
import 'package:holol_POS/shared/presentation/dialogs/app_dialog.dart';
import 'package:holol_POS/shared/refactor/pos_ui_widgets.dart';
import 'package:holol_POS/shared/refactor/pos_business_rules.dart';

class CartPanel extends ConsumerStatefulWidget {
  const CartPanel({super.key});

  @override
  ConsumerState<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends ConsumerState<CartPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _confirmClearCart() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    final confirmed = await AppDialog.show<bool>(
      context: context,
      dialog: AppDialog.warning(
        title: 'مسح السلة',
        content: Text(
          cart.items.length == 1
              ? 'سيتم حذف الصنف الموجود في السلة.'
              : 'سيتم حذف جميع الأصناف الموجودة في السلة.',
        ),
        confirmLabel: 'مسح السلة',
        cancelLabel: 'إلغاء',
      ),
    );

    if (confirmed == true && mounted) {
      ref.read(cartProvider.notifier).clearCart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final quoteState = ref.watch(cartQuoteProvider);
    final l10n = AppLocalizations.of(context)!;

    ref.listen(cartProvider, (previous, next) {
      if (previous != null && next.items.length > previous.items.length) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    return Container(
      color: AppColors.cartBackground,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            color: AppColors.surface,
            child: Row(
              children: [
                const Icon(
                  Icons.shopping_cart,
                  size: AppSpacing.xl,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  l10n.cartWithCount(cart.totalLinesCount),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (cart.isNotEmpty)
                  AppButton.text(
                    onPressed: _confirmClearCart,
                    icon: Icons.delete_outline,
                    customColor: AppColors.error,
                    label: l10n.clearCart,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: cart.isEmpty
                ? AppEmptyState(
                    icon: Icons.shopping_cart_outlined,
                    title: l10n.cartEmpty,
                    subtitle: l10n.tapProductsToAdd,
                  )
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      indent: AppSpacing.lg,
                      endIndent: AppSpacing.lg,
                    ),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      final lineTotal = CartLineQuoteLookup.lineTotalForItem(
                        item,
                        quoteState.quote,
                      );
                      final discountAmount =
                          CartLineQuoteLookup.lineDiscountForItem(
                            item,
                            quoteState.quote,
                          );

                      return _CartItemTile(
                        item: item,
                        officialLineTotal: lineTotal,
                        officialDiscountAmount: discountAmount,
                      );
                    },
                  ),
          ),
          if (cart.isNotEmpty) ...[
            const Divider(height: 1),
            _CartTotals(quoteState: quoteState),
            _PayButton(cart: cart, quoteState: quoteState),
          ],
        ],
      ),
    );
  }
}

class _CartItemTile extends ConsumerStatefulWidget {
  final CartItem item;
  final double? officialLineTotal;
  final double? officialDiscountAmount;

  const _CartItemTile({
    required this.item,
    this.officialLineTotal,
    this.officialDiscountAmount,
  });

  @override
  ConsumerState<_CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends ConsumerState<_CartItemTile> {
  late final TextEditingController _discountController;
  DiscountType _discountType = DiscountType.percentage;
  String? _discountError;

  CartItem get item => widget.item;

  @override
  void initState() {
    super.initState();
    _discountController = TextEditingController();
    _syncDiscountFromItem();
  }

  @override
  void didUpdateWidget(covariant _CartItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.discountType != widget.item.discountType ||
        oldWidget.item.discountValue != widget.item.discountValue ||
        oldWidget.item.lineKey != widget.item.lineKey) {
      _syncDiscountFromItem();
    }
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  void _syncDiscountFromItem() {
    _discountType = widget.item.discountType ?? DiscountType.percentage;
    _discountController.text = widget.item.discountValue == null
        ? ''
        : widget.item.discountValue!.toStringAsFixed(2);
    _discountError = null;
  }

  Future<void> _changeQuantity(double quantity) async {
    try {
      await ref
          .read(cartProvider.notifier)
          .changeQuantityWithPricing(item.itemId, item.unitId, quantity);
    } catch (error) {
      if (!mounted) return;
      AppSnackbar.showError(context, ErrorMapper.userMessage(error));
    }
  }

  void _removeItem() {
    ref.read(cartProvider.notifier).removeItem(item.itemId, item.unitId);
  }

  void _clearDiscount() {
    try {
      ref
          .read(cartProvider.notifier)
          .clearLineDiscount(item.itemId, item.unitId);
      _discountController.clear();
      setState(() => _discountError = null);
    } catch (error) {
      AppSnackbar.showError(context, ErrorMapper.userMessage(error));
    }
  }

  void _applyDiscount() {
    if (!item.allowDiscount) return;

    final result = CartDiscountDraftRules.parse(
      raw: _discountController.text,
      type: _discountType,
      grossAmount: item.grossAmount,
    );

    if (result.shouldClear) {
      _clearDiscount();
      return;
    }

    if (!result.isValid) {
      setState(() => _discountError = result.errorMessage);
      return;
    }

    try {
      ref
          .read(cartProvider.notifier)
          .applyLineDiscount(
            item.itemId,
            item.unitId,
            type: _discountType,
            value: result.value!,
          );
      setState(() => _discountError = null);
    } catch (error) {
      AppSnackbar.showError(context, ErrorMapper.userMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lineTotal = widget.officialLineTotal;
    final discountAmount = widget.officialDiscountAmount;

    return AppLineItemTile(
      title: Text(
        item.productName,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      chips: [
        AppAmountChip(label: 'السعر', value: item.unitPrice, enabled: false),
        Text(
          'x ${PosFormatters.quantity(item.quantity)}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        if (discountAmount != null && discountAmount > PosDomainTolerances.money)
          Text(
            l10n.discountAmountLabel(
              PosFormatters.amount(discountAmount),
            ),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.success),
          ),
      ],
      editor: AppInlineDiscountEditor(
        controller: _discountController,
        type: _discountType,
        enabled: item.allowDiscount,
        error: _discountError,
        onTypeChanged: (type) {
          setState(() {
            _discountType = type;
            _discountError = null;
          });

          if (_discountController.text.trim().isNotEmpty) {
            _applyDiscount();
          }
        },
        onSubmitted: _applyDiscount,
        onClear: _clearDiscount,
      ),
      quantityControls: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSquareIconButton(
            icon: Icons.remove,
            onTap: () => _changeQuantity(item.quantity - 1),
          ),
          Container(
            width: 42,
            alignment: Alignment.center,
            child: Text(
              PosFormatters.quantity(item.quantity),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          AppSquareIconButton(
            icon: Icons.add,
            onTap: () => _changeQuantity(item.quantity + 1),
          ),
        ],
      ),
      amount: lineTotal == null
          ? Text(
              '—',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.end,
            )
          : Text.rich(
              PosFormatters.amountRich(
                lineTotal,
                amountStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              textAlign: TextAlign.end,
            ),
      trailingAction: IconButton.filledTonal(
        tooltip: 'حذف',
        onPressed: _removeItem,
        icon: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
    );
  }
}

class _CartTotals extends StatelessWidget {
  final CartQuoteState quoteState;

  const _CartTotals({required this.quoteState});

  @override
  Widget build(BuildContext context) {
    final quote = quoteState.quote;
    final l10n = AppLocalizations.of(context)!;

    if (quote == null) {
      return AppTotalsPanel(
        error: Text(
          quoteState.error == null
              ? l10n.unableToPrepareCheckoutTotal
              : ErrorMapper.userMessage(quoteState.error!),
          style: const TextStyle(color: AppColors.error, fontSize: 13),
        ),
      );
    }

    return AppTotalsPanel(
      rows: [
        AppSignedAmountRow(label: l10n.subtotal, value: quote.subtotal),
        if (quote.discountTotal > 0)
          AppSignedAmountRow(
            label: l10n.discount,
            value: quote.discountTotal,
            isDiscount: true,
          ),
        AppSignedAmountRow(label: l10n.vat, value: quote.taxTotal),
      ],
      totalLabel: Text(
        l10n.total.toUpperCase(),
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      totalValue: Text.rich(
        PosFormatters.amountRich(
          quote.grandTotal,
          amountStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _PayButton extends StatelessWidget {
  final Cart cart;
  final CartQuoteState quoteState;

  const _PayButton({required this.cart, required this.quoteState});

  @override
  Widget build(BuildContext context) {
    final quote = quoteState.quote;
    final l10n = AppLocalizations.of(context)!;

    return AppBottomPrimaryAction(
      onPressed: cart.isEmpty || quote == null
          ? null
          : () async {
              final result = await showDialog<Object?>(
                context: context,
                barrierDismissible: false,
                requestFocus: false,
                builder: (context) => PaymentDialog(cart: cart),
              );

              if (!context.mounted) return;

              if (result is! PaymentDialogResult || !result.completed) {
                return;
              }

              if (result.openInvoice && result.saleId != null) {
                context.push(AppRoutes.invoicePath(result.saleId!));
              }
            },
      customColor: AppColors.payButton,
      icon: Icons.payment,
      label: quote == null
          ? l10n.pay
          : l10n.payAmount(PosFormatters.amount(quote.grandTotal)),
      labelWidget: quote == null
          ? null
          : Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${l10n.pay} '),
                  PosFormatters.amountRich(
                    quote.grandTotal,
                    amountStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
