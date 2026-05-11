import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_flutter/core/design_system/colors.dart';
import 'package:pos_flutter/core/design_system/spacing.dart';
import 'package:pos_flutter/core/errors/app_exception.dart';
import 'package:pos_flutter/core/l10n/app_localizations.dart';
import 'package:pos_flutter/core/services/formatters/pos_formatters.dart';
import 'package:pos_flutter/core/services/pricing/pricing_engine.dart';
import 'package:pos_flutter/features/cashier/domain/models/cart.dart';
import 'package:pos_flutter/features/cashier/application/cart_quote_provider.dart';
import 'package:pos_flutter/features/sales/application/sale_checkout.dart';
import 'package:pos_flutter/features/cashier/application/product_providers.dart';
import 'package:pos_flutter/features/cashier/domain/models/payment_method_option.dart';
import 'package:pos_flutter/shared/models/customer.dart';
import 'package:pos_flutter/shared/models/enums.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_button.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_dropdown.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_info_banner.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_loading.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_text_field.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';
import 'package:uuid/uuid.dart';

class PaymentDialog extends ConsumerStatefulWidget {
  final Cart cart;

  const PaymentDialog({super.key, required this.cart});

  @override
  ConsumerState<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<PaymentDialog> {
  final _tenderedController = TextEditingController();
  final _referenceController = TextEditingController();
  final String _checkoutAttemptId = 'CHK_${const Uuid().v4()}';

  String? _selectedPaymentMethodId;
  String? _selectedCustomerId;
  String? _selectedCustomerName;
  String? _selectedCustomerTaxNumber;

  CheckoutQuote? _quote;
  double _change = 0.0;

  PaymentMethodType _completedPaymentMethodType = PaymentMethodType.cash;

  bool _initialized = false;
  bool _isProcessing = false;
  bool _isComplete = false;

  String? _errorMessage;
  String? _invoiceNo;
  String? _saleId;

  double get _totalAmount => _quote?.grandTotal ?? 0.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) return;
    _initialized = true;

    final l10n = AppLocalizations.of(context)!;
    final quoteState = ref.read(cartQuoteProvider);

    _quote = quoteState.quote;
    _errorMessage = quoteState.quote == null
        ? quoteState.error == null
              ? l10n.unableToPrepareCheckoutTotal
              : ErrorMapper.userMessage(quoteState.error!)
        : null;

    _tenderedController.text = _totalAmount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _tenderedController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    final l10n = AppLocalizations.of(context)!;

    if (_quote == null) {
      setState(() => _errorMessage ??= l10n.unableToPrepareCheckoutTotal);
      return;
    }

    final methods = await ref.read(paymentMethodsProvider.future);
    if (!mounted) return;

    final method = _selectedPaymentMethod(methods);
    if (method == null) {
      setState(() => _errorMessage = l10n.noActivePaymentMethodConfigured);
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final result = await ref
          .read(saleCheckoutProvider)
          .complete(
            SaleCheckoutRequest(
              cart: widget.cart,
              checkoutAttemptId: _checkoutAttemptId,
              paymentMethod: method,
              tenderedText: _tenderedController.text,
              reference: _referenceController.text,
              customerId: _selectedCustomerId,
              customerName: _selectedCustomerName,
              customerTaxNumber: _selectedCustomerTaxNumber,
            ),
          );

      if (!mounted) return;

      ref.read(cartProvider.notifier).clearCart();

      setState(() {
        _invoiceNo = result.invoiceNo;
        _saleId = result.saleId;
        _completedPaymentMethodType = result.selectedPaymentType;
        _change = result.change;
        _isProcessing = false;
        _isComplete = true;
      });
    } on BusinessException catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = l10n.paymentCouldNotBeCompleted;
      });
    }
  }

  PaymentMethodOption? _selectedPaymentMethod(
    List<PaymentMethodOption> methods,
  ) {
    if (methods.isEmpty) return null;

    final selectedId = _selectedPaymentMethodId;
    if (selectedId != null) {
      for (final method in methods) {
        if (method.id == selectedId) return method;
      }
    }

    final session = ref.read(activePosSessionProvider).valueOrNull;
    if (session != null) {
      for (final id in [
        session.activeDefaultBankId ?? '',
        session.activeDefaultCardTypeId ?? '',
        session.cashId ?? '',
      ]) {
        if (id.isEmpty) continue;

        for (final method in methods) {
          if (method.id == id) return method;
        }
      }
    }

    return methods.firstWhere(
      (method) => method.type.isCash,
      orElse: () => methods.first,
    );
  }

  void _cancelBeforeCompletion() {
    if (_isProcessing) return;

    if (_isComplete) {
      _finishPayment();
      return;
    }

    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _cancelBeforeCompletion();
      },
      child: Dialog(
        insetPadding: AppSpacing.paddingLg,
        child: Container(
          width: size.width > 700 ? 560 : size.width,
          constraints: BoxConstraints(
            maxHeight: size.height - AppSpacing.xxl * 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppSpacing.borderRadiusLg,
          ),
          clipBehavior: Clip.antiAlias,
          child: _isComplete ? _buildCompletionView() : _buildPaymentView(),
        ),
      ),
    );
  }

  Widget _buildPaymentView() {
    final l10n = AppLocalizations.of(context)!;
    final methods = ref.watch(paymentMethodsProvider);
    final customers = ref.watch(customersProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          color: AppColors.primary,
          child: Row(
            children: [
              const Icon(Icons.payment, color: AppColors.onPrimary),
              const SizedBox(width: AppSpacing.md),
              Text(
                l10n.payment,
                style: const TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: l10n.cancel,
                icon: const Icon(Icons.close, color: AppColors.onPrimary),
                onPressed: _isProcessing ? null : _cancelBeforeCompletion,
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_errorMessage != null) ...[
                  AppInfoBanner.error(message: _errorMessage!),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Text(
                  PosFormatters.amount(_totalAmount),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                customers.when(
                  data: _buildCustomerSelector,
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: AppSpacing.lg),
                methods.when(
                  data: _buildPaymentControls,
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: AppLoading(),
                  ),
                  error: (error, _) => AppInfoBanner.error(
                    message: ErrorMapper.userMessage(error),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerSelector(List<Customer> customers) {
    if (customers.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;

    return AppDropdown<String>(
      value: _selectedCustomerId ?? '',
      labelText: l10n.customer,
      prefixIcon: const Icon(Icons.person_outline),
      items: [
        DropdownMenuItem(value: '', child: Text(l10n.noCustomer)),
        for (final customer in customers)
          DropdownMenuItem(
            value: customer.id,
            child: Text(customer.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) {
        Customer? selected;

        for (final customer in customers) {
          if (customer.id == value) {
            selected = customer;
            break;
          }
        }

        setState(() {
          _selectedCustomerId = selected?.id;
          _selectedCustomerName = selected?.name;
          _selectedCustomerTaxNumber = selected?.taxNumber;
        });
      },
    );
  }

  Widget _buildPaymentControls(List<PaymentMethodOption> methods) {
    final l10n = AppLocalizations.of(context)!;
    final selected = _selectedPaymentMethod(methods);

    if (selected == null) {
      return AppInfoBanner.error(message: l10n.noActivePaymentMethodConfigured);
    }

    final profile = ref.watch(activePaymentProfileProvider).valueOrNull;

    final requirements = checkoutPaymentRequirements(
      resolveCheckoutPaymentMethod(selected),
      paymentProfileRequiresReference: profile?.requireReference ?? false,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          alignment: WrapAlignment.center,
          children: [
            for (final method in methods)
              _MethodButton(
                icon: _paymentMethodIcon(method.type),
                label: method.name,
                isSelected: selected.id == method.id,
                onTap: () {
                  setState(() {
                    _selectedPaymentMethodId = method.id;
                    _referenceController.clear();

                    if (method.type.isCash) {
                      _tenderedController.text = _totalAmount.toStringAsFixed(
                        2,
                      );
                    }
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        if (selected.type.isCash) ...[
          AppTextField(
            controller: _tenderedController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            labelText: l10n.amountTenderedSar,
            prefixText: '${l10n.currency} ',
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _QuickAmountButton(
                label: l10n.exact,
                onTap: () {
                  _tenderedController.text = _totalAmount.toStringAsFixed(2);
                },
              ),
              for (final amount in [5, 10, 20, 50, 100, 200, 500])
                if (amount.toDouble() >= _totalAmount)
                  _QuickAmountButton(
                    label: '$amount',
                    onTap: () {
                      _tenderedController.text = amount.toStringAsFixed(2);
                    },
                  ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (requirements.showsReference) ...[
          AppTextField(
            controller: _referenceController,
            textInputAction: TextInputAction.done,
            labelText: requirements.requiresReference
                ? '${l10n.paymentReference} *'
                : l10n.paymentReference,
            prefixIcon: const Icon(Icons.confirmation_number_outlined),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        SizedBox(
          width: double.infinity,
          height: AppSpacing.jumbo + AppSpacing.sm,
          child: AppButton.primary(
            onPressed: _isProcessing ? null : _processPayment,
            customColor: AppColors.payButton,
            isLoading: _isProcessing,
            label: _processButtonLabel(selected.type, l10n),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionView() {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle,
            size: AppSpacing.jumbo + AppSpacing.xxl,
            color: AppColors.success,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.paymentSuccessful,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          if (_invoiceNo != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.invoiceNumberLabel(_invoiceNo!),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (_completedPaymentMethodType.isCash && _change > 0) ...[
            AppInfoBanner(
              message: '${l10n.change}: ${PosFormatters.amount(_change)}',
              type: AppBannerType.info,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.center,
            children: [
              AppButton.outlined(
                onPressed: _openInvoice,
                icon: Icons.receipt_long,
                label: l10n.viewInvoice,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: AppSpacing.jumbo + AppSpacing.sm,
            child: AppButton.primary(
              onPressed: _finishPayment,
              icon: Icons.check,
              label: l10n.doneNewSale,
            ),
          ),
        ],
      ),
    );
  }

  void _finishPayment() {
    final id = _saleId;

    Navigator.of(context).pop(PaymentDialogResult.completed(saleId: id));
  }

  void _openInvoice() {
    final id = _saleId;
    if (id == null) return;

    Navigator.of(
      context,
    ).pop(PaymentDialogResult.completed(saleId: id, openInvoice: true));
  }

  IconData _paymentMethodIcon(PaymentMethodType type) {
    return switch (type) {
      PaymentMethodType.cash => Icons.payments_outlined,
      PaymentMethodType.manualCard => Icons.credit_card,
      PaymentMethodType.integratedCard => Icons.credit_card,
      PaymentMethodType.bankTransfer => Icons.account_balance,
      PaymentMethodType.customerCredit => Icons.person_outline,
      PaymentMethodType.cheque => Icons.receipt_long,
      PaymentMethodType.wallet => Icons.account_balance_wallet_outlined,
    };
  }

  String _processButtonLabel(PaymentMethodType type, AppLocalizations l10n) {
    if (type.isCash) return l10n.completePayment;
    if (type.isManualCard) return l10n.recordCardPayment;
    if (type == PaymentMethodType.bankTransfer) return l10n.recordBankPayment;
    return l10n.recordPayment;
  }
}

class PaymentDialogResult {
  final bool completed;
  final String? saleId;
  final bool openInvoice;

  const PaymentDialogResult._({
    required this.completed,
    this.saleId,
    this.openInvoice = false,
  });

  const PaymentDialogResult.completed({
    required String? saleId,
    bool openInvoice = false,
  }) : this._(completed: true, saleId: saleId, openInvoice: openInvoice);
}

class _MethodButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MethodButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSpacing.jumbo * 3,
      child: Material(
        color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
        borderRadius: AppSpacing.borderRadiusMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppSpacing.borderRadiusMd,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? AppColors.onPrimary
                      : AppColors.textPrimary,
                  size: AppSpacing.xxl,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.onPrimary
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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

class _QuickAmountButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickAmountButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(AppSpacing.jumbo, AppSpacing.jumbo),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      child: Text(label),
    );
  }
}
