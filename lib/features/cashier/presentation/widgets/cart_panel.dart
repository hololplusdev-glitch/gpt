// features/cashier/presentation/widgets/cart_panel.dart
// Cart panel displaying items, totals, and action buttons.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:holol_POS/shared/presentation/widgets/key_value_row.dart';
import 'package:holol_POS/shared/presentation/dialogs/app_dialog.dart';

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
                      final lineTotal = _lineTotalForItem(item, quoteState);
                      final discountAmount = _lineDiscountForItem(
                        item,
                        quoteState,
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

    final raw = _discountController.text.trim();
    if (raw.isEmpty) {
      _clearDiscount();
      return;
    }

    final value = double.tryParse(raw.replaceAll(',', '.'));
    final gross = item.unitPrice * item.quantity;
    if (value == null || value < 0) {
      setState(() => _discountError = 'أدخل خصمًا صحيحًا.');
      return;
    }
    if (_discountType == DiscountType.percentage && value > 100) {
      setState(() => _discountError = 'النسبة لا تتجاوز 100%.');
      return;
    }
    if (_discountType == DiscountType.fixed && value > gross) {
      setState(() => _discountError = 'الخصم لا يتجاوز إجمالي السطر.');
      return;
    }

    try {
      ref
          .read(cartProvider.notifier)
          .applyLineDiscount(
            item.itemId,
            item.unitId,
            type: _discountType,
            value: value,
          );
      setState(() => _discountError = null);
    } catch (error) {
      AppSnackbar.showError(context, ErrorMapper.userMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lineTotal =
        widget.officialLineTotal ?? item.unitPrice * item.quantity;

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
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: isCompact ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _InlineAmountChip(
                    label: 'السعر',
                    value: item.unitPrice,
                    enabled: false,
                  ),
                  Text(
                    'x ${PosFormatters.quantity(item.quantity)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if ((widget.officialDiscountAmount ?? 0) > 0)
                    Text(
                      l10n.discountAmountLabel(
                        PosFormatters.amount(
                          widget.officialDiscountAmount ?? 0,
                        ),
                      ),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.success),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _InlineDiscountEditor(
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
            ],
          );

          final quantityControls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QtyButton(
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
              _QtyButton(
                icon: Icons.add,
                onTap: () => _changeQuantity(item.quantity + 1),
              ),
            ],
          );

          final totalAndDelete = Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text.rich(
                PosFormatters.amountRich(
                  lineTotal,
                  amountStyle: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                textAlign: TextAlign.end,
              ),
              const SizedBox(height: AppSpacing.sm),
              IconButton.filledTonal(
                tooltip: 'حذف',
                onPressed: _removeItem,
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
              ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                details,
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [quantityControls, const Spacer(), totalAndDelete],
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: details),
              const SizedBox(width: AppSpacing.md),
              quantityControls,
              const SizedBox(width: AppSpacing.md),
              totalAndDelete,
            ],
          );
        },
      ),
    );
  }
}

class _InlineAmountChip extends StatelessWidget {
  final String label;
  final double value;
  final bool enabled;

  const _InlineAmountChip({
    required this.label,
    required this.value,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: enabled ? AppColors.surface : AppColors.surfaceVariant,
        borderRadius: AppSpacing.borderRadiusSm,
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label ',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            Text.rich(
              PosFormatters.amountRich(
                value,
                amountStyle: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineDiscountEditor extends StatelessWidget {
  final TextEditingController controller;
  final DiscountType type;
  final bool enabled;
  final String? error;
  final ValueChanged<DiscountType> onTypeChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onClear;

  const _InlineDiscountEditor({
    required this.controller,
    required this.type,
    required this.enabled,
    required this.error,
    required this.onTypeChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 112,
              height: 40,
              child: TextField(
                controller: controller,
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onSubmitted(),
                decoration: InputDecoration(
                  labelText: enabled ? 'الخصم' : 'الخصم معطل',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SegmentedButton<DiscountType>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: DiscountType.percentage, label: Text('%')),
                ButtonSegment(value: DiscountType.fixed, label: Text('مبلغ')),
              ],
              selected: {type},
              onSelectionChanged: enabled
                  ? (value) => onTypeChanged(value.first)
                  : null,
            ),
            IconButton(
              tooltip: 'مسح الخصم',
              onPressed: enabled ? onClear : null,
              icon: const Icon(Icons.backspace_outlined),
            ),
          ],
        ),
        if (!enabled)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'هذا الصنف لا يسمح بالخصم',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textHint),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              error!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ),
      ],
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
      return KeyValueRow(
        label: label,
        valueColor: AppColors.success,
        value: '-${PosFormatters.amount(value)}',
        valueWidget: Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: '-'),
              PosFormatters.amountRich(
                value,
                amountStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return KeyValueRow(
      label: label,
      value: PosFormatters.amount(value),
      valueWidget: Text.rich(
        PosFormatters.amountRich(
          value,
          amountStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
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

double? _lineDiscountForItem(CartItem item, CartQuoteState quoteState) {
  final quote = quoteState.quote;
  if (quote == null) return null;

  for (final line in quote.lines) {
    if (line.itemId == item.itemId && line.unitId == item.unitId) {
      return line.discountAmount;
    }
  }

  return null;
}
