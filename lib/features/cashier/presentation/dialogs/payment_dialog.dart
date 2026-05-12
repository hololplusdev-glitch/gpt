import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/spacing.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/l10n/app_localizations.dart';
import 'package:holol_POS/core/services/formatters/pos_formatters.dart';
import 'package:holol_POS/core/services/pricing/pricing_engine.dart';
import 'package:holol_POS/features/cashier/application/cart_quote_provider.dart';
import 'package:holol_POS/features/cashier/application/product_providers.dart';
import 'package:holol_POS/features/cashier/domain/models/cart.dart';
import 'package:holol_POS/features/sales/application/sale_checkout.dart';
import 'package:holol_POS/features/sales/domain/models/sale_inputs.dart';
import 'package:holol_POS/shared/models/customer.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/shared/presentation/widgets/app_button.dart';
import 'package:holol_POS/shared/presentation/widgets/app_dropdown.dart';
import 'package:holol_POS/shared/presentation/widgets/app_info_banner.dart';
import 'package:holol_POS/shared/presentation/widgets/app_loading.dart';
import 'package:holol_POS/shared/presentation/widgets/app_text_field.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
import 'package:uuid/uuid.dart';

enum _CheckoutTenderKind { cash, network, credit }

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

  _CheckoutTenderKind _selectedKind = _CheckoutTenderKind.cash;

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

  SaleTenderKind get _saleTenderKind {
    return switch (_selectedKind) {
      _CheckoutTenderKind.cash => SaleTenderKind.cash,
      _CheckoutTenderKind.network => SaleTenderKind.network,
      _CheckoutTenderKind.credit => SaleTenderKind.credit,
    };
  }

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
    _recalculateChange();
  }

  @override
  void dispose() {
    _tenderedController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _recalculateChange() {
    final tendered =
        double.tryParse(_tenderedController.text.trim().replaceAll(',', '.')) ??
        0.0;
    final change = PricingEngine.roundAmount(tendered - _totalAmount);
    _change = change > 0 ? change : 0.0;
  }

  void _selectKind(_CheckoutTenderKind kind) {
    setState(() {
      _selectedKind = kind;
      _errorMessage = null;
      _referenceController.clear();

      if (kind == _CheckoutTenderKind.cash) {
        _tenderedController.text = _totalAmount.toStringAsFixed(2);
        _recalculateChange();
      }
    });
  }

  Future<void> _processPayment() async {
    final l10n = AppLocalizations.of(context)!;

    if (_quote == null) {
      setState(() => _errorMessage ??= l10n.unableToPrepareCheckoutTotal);
      return;
    }

    if (_selectedKind == _CheckoutTenderKind.credit &&
        (_selectedCustomerId == null || _selectedCustomerId!.trim().isEmpty)) {
      setState(() => _errorMessage = 'البيع الآجل يتطلب اختيار عميل.');
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
              paymentIntent: SalePaymentIntent(
                kind: _saleTenderKind,
                tenderedText: _selectedKind == _CheckoutTenderKind.cash
                    ? _tenderedController.text
                    : _totalAmount.toStringAsFixed(2),
                reference: _referenceController.text,
              ),
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
    final isCompact = size.width < 600;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _cancelBeforeCompletion();
      },
      child: Dialog(
        insetPadding: isCompact ? EdgeInsets.zero : AppSpacing.paddingLg,
        child: Container(
          width: isCompact ? double.infinity : 620,
          height: isCompact ? size.height : null,
          constraints: BoxConstraints(
            maxHeight: isCompact
                ? size.height
                : size.height - AppSpacing.xxl * 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: isCompact
                ? BorderRadius.zero
                : AppSpacing.borderRadiusLg,
          ),
          clipBehavior: Clip.antiAlias,
          child: _isComplete ? _buildCompletionView() : _buildPaymentView(),
        ),
      ),
    );
  }

  Widget _buildPaymentView() {
    final l10n = AppLocalizations.of(context)!;
    final customers = ref.watch(customersProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 600
                ? AppSpacing.lg
                : AppSpacing.xl,
          ),
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
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 600
                  ? AppSpacing.lg
                  : AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_errorMessage != null) ...[
                  AppInfoBanner.error(message: _errorMessage!),
                  const SizedBox(height: AppSpacing.lg),
                ],
                const Text(
                  'إجمالي الفاتورة',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text.rich(
                  PosFormatters.amountRich(
                    _totalAmount,
                    amountStyle: TextStyle(
                      fontSize: MediaQuery.sizeOf(context).width < 600
                          ? 32
                          : 38,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _TenderKindSelector(
                  selectedKind: _selectedKind,
                  onSelected: _selectKind,
                ),
                const SizedBox(height: AppSpacing.xl),
                _buildSelectedMethodBody(customers),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedMethodBody(AsyncValue<List<Customer>> customers) {
    return switch (_selectedKind) {
      _CheckoutTenderKind.cash => _buildCashBody(),
      _CheckoutTenderKind.network => _buildNetworkBody(),
      _CheckoutTenderKind.credit => _buildCreditBody(customers),
    };
  }

  Widget _buildCashBody() {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
          autofocus: false,
          onChanged: (_) => setState(_recalculateChange),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_change > 0)
          AppInfoBanner(
            message: '${l10n.change}: ${PosFormatters.amount(_change)}',
            type: AppBannerType.info,
          ),
        const SizedBox(height: AppSpacing.md),
        const SizedBox(height: AppSpacing.xl),
        _CompleteButton(
          isProcessing: _isProcessing,
          label: l10n.completePayment,
          onPressed: _processPayment,
        ),
      ],
    );
  }

  Widget _buildNetworkBody() {
    final profile = ref.watch(activePaymentProfileProvider).valueOrNull;
    final profileMode = PaymentProfileMode.fromCode(profile?.mode);
    final integratedConfigured =
        profile != null &&
        profile.enabled &&
        profileMode == PaymentProfileMode.integrated;
    final integratedReady = profile == null
        ? false
        : ref.read(paymentProfileServiceProvider).integratedAvailable(profile);

    final warning = integratedConfigured && !integratedReady
        ? 'جهاز الدفع غير متصل. سيتم تسجيل عملية شبكة يدويًا مع حفظها كدفعة شبكة.'
        : 'لم يتم تفعيل ربط جهاز الدفع بعد. سيتم تسجيل عملية شبكة يدويًا مع حفظها كدفعة شبكة.';

    const requiresReference = false;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppInfoBanner(message: warning, type: AppBannerType.warning),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _referenceController,
          textInputAction: TextInputAction.done,
          labelText: 'رقم مرجع الشبكة اختياري',
          prefixIcon: const Icon(Icons.confirmation_number_outlined),
        ),
        const SizedBox(height: AppSpacing.xl),
        _CompleteButton(
          isProcessing: _isProcessing,
          label: 'تسجيل دفع شبكة',
          onPressed: _processPayment,
        ),
      ],
    );
  }

  Widget _buildCreditBody(AsyncValue<List<Customer>> customers) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppInfoBanner(
          message:
              'البيع الآجل يتطلب اختيار عميل. سيتم تسجيل كامل المبلغ كرصيد مستحق على العميل.',
          type: AppBannerType.info,
        ),
        const SizedBox(height: AppSpacing.lg),
        customers.when(
          data: _buildCustomerSelector,
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: AppLoading(),
          ),
          error: (error, _) =>
              AppInfoBanner.error(message: ErrorMapper.userMessage(error)),
        ),
        const SizedBox(height: AppSpacing.xl),
        _CompleteButton(
          isProcessing: _isProcessing,
          label: 'إتمام بيع آجل',
          onPressed: _processPayment,
        ),
      ],
    );
  }

  Widget _buildCustomerSelector(List<Customer> customers) {
    if (customers.isEmpty) {
      return AppInfoBanner.error(
        message: 'لا يوجد عملاء محملون. لا يمكن إتمام بيع آجل بدون عميل.',
      );
    }

    final l10n = AppLocalizations.of(context)!;

    return AppDropdown<String>(
      value: _selectedCustomerId ?? '',
      labelText: '${l10n.customer} *',
      prefixIcon: const Icon(Icons.person_outline),
      items: [
        const DropdownMenuItem(value: '', child: Text('اختر العميل')),
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

  Widget _buildCompletionView() {
    final l10n = AppLocalizations.of(context)!;

    final title =
        _completedPaymentMethodType == PaymentMethodType.customerCredit
        ? 'تم تسجيل البيع الآجل'
        : l10n.paymentSuccessful;

    return SingleChildScrollView(
      padding: EdgeInsets.all(
        MediaQuery.sizeOf(context).width < 600
            ? AppSpacing.xl
            : AppSpacing.xxxl,
      ),
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
            title,
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

class _TenderKindSelector extends StatelessWidget {
  final _CheckoutTenderKind selectedKind;
  final ValueChanged<_CheckoutTenderKind> onSelected;

  const _TenderKindSelector({
    required this.selectedKind,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;

    return Wrap(
      spacing: isCompact ? AppSpacing.sm : AppSpacing.md,
      runSpacing: AppSpacing.sm,
      alignment: WrapAlignment.center,
      children: [
        _TenderKindButton(
          icon: Icons.payments_outlined,
          label: 'كاش',
          subtitle: 'نقدي',
          selected: selectedKind == _CheckoutTenderKind.cash,
          onTap: () => onSelected(_CheckoutTenderKind.cash),
        ),
        _TenderKindButton(
          icon: Icons.credit_card,
          label: 'شبكة',
          subtitle: 'جهاز دفع / يدوي',
          selected: selectedKind == _CheckoutTenderKind.network,
          onTap: () => onSelected(_CheckoutTenderKind.network),
        ),
        _TenderKindButton(
          icon: Icons.person_outline,
          label: 'آجل',
          subtitle: 'على حساب عميل',
          selected: selectedKind == _CheckoutTenderKind.credit,
          onTap: () => onSelected(_CheckoutTenderKind.credit),
        ),
      ],
    );
  }
}

class _TenderKindButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _TenderKindButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width < 600
          ? 104
          : AppSpacing.jumbo * 3.3,
      child: Material(
        color: selected ? AppColors.primary : AppColors.surfaceVariant,
        borderRadius: AppSpacing.borderRadiusMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppSpacing.borderRadiusMd,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: MediaQuery.sizeOf(context).width < 600
                  ? AppSpacing.md
                  : AppSpacing.lg,
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: selected ? AppColors.onPrimary : AppColors.textPrimary,
                  size: AppSpacing.xxl,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? AppColors.onPrimary
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? AppColors.onPrimary.withValues(alpha: 0.8)
                        : AppColors.textSecondary,
                    fontSize: 11,
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

class _CompleteButton extends StatelessWidget {
  final bool isProcessing;
  final String label;
  final VoidCallback onPressed;

  const _CompleteButton({
    required this.isProcessing,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.jumbo + AppSpacing.sm,
      child: AppButton.primary(
        onPressed: isProcessing ? null : onPressed,
        customColor: AppColors.payButton,
        isLoading: isProcessing,
        label: label,
      ),
    );
  }
}
