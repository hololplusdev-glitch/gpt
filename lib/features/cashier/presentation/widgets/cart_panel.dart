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
import 'package:holol_POS/features/cashier/application/cart_quote_provider.dart';
import 'package:holol_POS/features/cashier/presentation/dialogs/payment_dialog.dart';
import 'package:holol_POS/shared/presentation/utils/app_snackbar.dart';
import 'package:holol_POS/shared/presentation/widgets/app_button.dart';
import 'package:holol_POS/shared/presentation/widgets/app_empty_state.dart';
import 'package:holol_POS/shared/presentation/widgets/key_value_row.dart';

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

    final confirmed = await showDialog<bool>(
      context: context,
      requestFocus: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('مسح السلة'),
          content: Text(
            cart.items.length == 1
                ? 'سيتم حذف الصنف الموجود في السلة.'
                : 'سيتم حذف جميع الأصناف الموجودة في السلة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('مسح السلة'),
            ),
          ],
        );
      },
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
                  l10n.cartWithCount(cart.totalItemCount),
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
                      final lineTotal = _lineTotalForItem(item, quoteState);

                      return _CartItemTile(
                        item: item,
                        officialLineTotal: lineTotal,
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

class _CartItemTile extends ConsumerWidget {
  final CartItem item;
  final double? officialLineTotal;

  const _CartItemTile({required this.item, this.officialLineTotal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    Future<void> changeQuantity(double quantity) async {
      try {
        await ref
            .read(cartProvider.notifier)
            .changeQuantityWithPricing(item.itemId, item.unitId, quantity);
      } catch (error) {
        if (!context.mounted) return;
        AppSnackbar.showError(context, ErrorMapper.userMessage(error));
      }
    }

    void removeItem() {
      ref.read(cartProvider.notifier).removeItem(item.itemId, item.unitId);
    }

    final lineTotal = officialLineTotal ?? item.unitPrice * item.quantity;

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(
        begin: AppColors.success.withValues(alpha: 0.3),
        end: Colors.transparent,
      ),
      duration: const Duration(milliseconds: 800),
      builder: (context, color, child) {
        return Container(
          color: color,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: child,
        );
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 420;

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${PosFormatters.amount(item.unitPrice)} x ${PosFormatters.quantity(item.quantity)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (item.discountAmount > 0)
                  Text(
                    l10n.discountAmountLabel(
                      PosFormatters.amount(item.discountAmount),
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.success,
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _QtyButton(
                      icon: Icons.remove,
                      onTap: () => changeQuantity(item.quantity - 1),
                    ),
                    Container(
                      width: 44,
                      alignment: Alignment.center,
                      child: Text(
                        PosFormatters.quantity(item.quantity),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _QtyButton(
                      icon: Icons.add,
                      onTap: () => changeQuantity(item.quantity + 1),
                    ),
                    const Spacer(),
                    Text.rich(
                      PosFormatters.amountRich(
                        lineTotal,
                        amountStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                      ),
                      textAlign: TextAlign.end,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton(
                      tooltip: 'حذف',
                      onPressed: removeItem,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${PosFormatters.amount(item.unitPrice)} x ${PosFormatters.quantity(item.quantity)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (item.discountAmount > 0)
                      Text(
                        l10n.discountAmountLabel(
                          PosFormatters.amount(item.discountAmount),
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.success,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _QtyButton(
                    icon: Icons.remove,
                    onTap: () => changeQuantity(item.quantity - 1),
                  ),
                  Container(
                    width: 36,
                    alignment: Alignment.center,
                    child: Text(
                      PosFormatters.quantity(item.quantity),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _QtyButton(
                    icon: Icons.add,
                    onTap: () => changeQuantity(item.quantity + 1),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text.rich(
                    PosFormatters.amountRich(
                      lineTotal,
                      amountStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                    ),
                    textAlign: TextAlign.end,
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: removeItem,
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: AppSpacing.borderRadiusSm,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusSm,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 24, color: AppColors.textPrimary),
        ),
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

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: AppColors.surface,
      child: quote == null
          ? Text(
              quoteState.error == null
                  ? l10n.unableToPrepareCheckoutTotal
                  : ErrorMapper.userMessage(quoteState.error!),
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            )
          : Column(
              children: [
                _CartAmountRow(label: l10n.subtotal, value: quote.subtotal),
                if (quote.discountTotal > 0)
                  _CartAmountRow(
                    label: l10n.discount,
                    value: quote.discountTotal,
                    isDiscount: true,
                  ),
                _CartAmountRow(label: l10n.vat, value: quote.taxTotal),
                const Divider(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.total.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text.rich(
                      PosFormatters.amountRich(
                        quote.grandTotal,
                        amountStyle: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _CartAmountRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isDiscount;

  const _CartAmountRow({
    required this.label,
    required this.value,
    this.isDiscount = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isDiscount) {
      return KeyValueRow.discount(
        label: label,
        value: PosFormatters.amount(value),
      );
    }

    return KeyValueRow(label: label, value: PosFormatters.amount(value));
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

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: AppButton.primary(
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
        ),
      ),
    );
  }
}

double? _lineTotalForItem(CartItem item, CartQuoteState quoteState) {
  final quote = quoteState.quote;
  if (quote == null) return null;

  for (final line in quote.lines) {
    if (line.itemId == item.itemId && line.unitId == item.unitId) {
      return line.lineTotal;
    }
  }

  return null;
}
