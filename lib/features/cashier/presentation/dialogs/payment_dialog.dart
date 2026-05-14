import 'dart:async';

import 'package:flutter/material.dart';
import 'package:holol_POS/core/services/invoices/invoice_output_actions.dart';
import 'package:holol_POS/features/cashier/presentation/dialogs/thermal_receipt_preview_dialog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/spacing.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/l10n/app_localizations.dart';
import 'package:holol_POS/core/services/formatters/pos_formatters.dart';
import 'package:holol_POS/features/cashier/application/product_providers.dart';
import 'package:holol_POS/features/cashier/domain/models/cart.dart';
import 'package:holol_POS/features/sales/application/sale_checkout.dart';
import 'package:holol_POS/features/sales/domain/models/sale_inputs.dart';
import 'package:holol_POS/shared/models/customer.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/shared/presentation/widgets/app_button.dart';
import 'package:holol_POS/shared/presentation/widgets/app_info_banner.dart';
import 'package:holol_POS/shared/presentation/widgets/app_loading.dart';
import 'package:holol_POS/shared/presentation/widgets/app_text_field.dart';
import 'package:uuid/uuid.dart';
import 'package:holol_POS/shared/refactor/pos_payment_draft.dart';
import 'package:holol_POS/core/services/pricing/pricing_engine.dart';
import 'package:holol_POS/shared/refactor/pos_ui_widgets.dart';

class PaymentDialog extends ConsumerStatefulWidget {
  final Cart cart;

  const PaymentDialog({super.key, required this.cart});

  @override
  ConsumerState<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<PaymentDialog> {
  final _customerSearchController = TextEditingController();
  final _lineAmountController = TextEditingController();
  Timer? _customerSearchDebounce;

  final String _checkoutAttemptId = 'CHK_${const Uuid().v4()}';
  final PaymentDraftController _paymentDraft = PaymentDraftController();

  List<PaymentDraftLine> get _paymentLines => _paymentDraft.lines;
  SaleTenderKind? get _activeLineKind => _paymentDraft.activeLineKind;
  String? get _editingLineId => _paymentDraft.editingLineId;
  String? get _lineInputError => _paymentDraft.lineInputError;

  String? _selectedCustomerId;
  String? _selectedCustomerName;
  String? _selectedCustomerTaxNumber;

  CheckoutQuote? _quote;
  PaymentMethodType _completedPaymentMethodType = PaymentMethodType.cash;

  bool _initialized = false;
  bool _isProcessing = false;
  bool _isComplete = false;

  String? _errorMessage;
  String? _invoiceNo;
  String? _saleId;

  double get _totalAmount => _quote?.grandTotal ?? 0.0;

  PaymentDraftTotals get _paymentTotals => _paymentDraft.totals(_totalAmount);

  double get _actualPaidAmount => _paymentTotals.actualPaidAmount;
  double get _creditAmount => _paymentTotals.creditAmount;
  double get _remainingAmount => _paymentTotals.remainingAmount;
  double get _change => _paymentTotals.change;
  bool get _hasCreditLine => _paymentTotals.hasCreditLine;

  bool get _canConfirm {
    if (_isProcessing) return false;
    return PaymentDraftRules.validateBeforeSubmit(
          quoteReady: _quote != null,
          hasPaymentLines: _paymentLines.isNotEmpty,
          remainingAmount: _remainingAmount,
          hasCreditLine: _hasCreditLine,
          selectedCustomerId: _selectedCustomerId,
          quoteNotReadyMessage: '',
          emptyPaymentMessage: '',
          remainingNotCoveredMessage: '',
          creditRequiresCustomerMessage: '',
        ) ==
        null;
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
  }

  @override
  void dispose() {
    _customerSearchDebounce?.cancel();
    _customerSearchController.dispose();
    _lineAmountController.dispose();
    super.dispose();
  }

  void _scheduleCustomerSearch(String value) {
    _customerSearchDebounce?.cancel();
    _customerSearchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      ref.read(customerSearchQueryProvider.notifier).state = value.trim();
    });
  }

  void _selectCustomer(Customer customer) {
    setState(() {
      _selectedCustomerId = customer.id;
      _selectedCustomerName = customer.name;
      _selectedCustomerTaxNumber = customer.taxNumber;
      _customerSearchController.text = customer.name;
      _errorMessage = null;
    });
  }

  void _removeLine(String id) {
    setState(() {
      _paymentDraft.removeLine(id);
      _errorMessage = null;
    });
  }

  void _selectLineKind(SaleTenderKind kind, [PaymentDraftLine? existing]) {
    final selection = _paymentDraft.selectLineKind(
      kind: kind,
      totalAmount: _totalAmount,
      existing: existing,
    );

    if (!selection.canSelect) return;

    setState(() {
      _lineAmountController.text = selection.amountText;
      _errorMessage = null;
    });

    if (selection.autoSubmit) {
      _submitInlineLine(showErrors: false, updateText: true);
    }
  }

  double _availableFor(PaymentDraftLine? existing) {
    return _paymentDraft.availableFor(
      totalAmount: _totalAmount,
      existing: existing,
    );
  }

  bool _submitInlineLine({bool showErrors = true, bool updateText = false}) {
    final result = _paymentDraft.submitInlineLine(
      rawInputText: _lineAmountController.text,
      totalAmount: _totalAmount,
      showErrors: showErrors,
      updateText: updateText,
    );

    setState(() {
      if (result.amountText != null) {
        _lineAmountController.text = result.amountText!;
      }
      if (result.success) {
        _errorMessage = null;
      }
    });

    return result.success;
  }

  List<SalePaymentIntent> _buildPaymentIntents() {
    return _paymentDraft.buildPaymentIntents();
  }

  String? _validatePaymentBeforeSubmit() {
    return _paymentDraft.validateBeforeSubmit(
      quoteReady: _quote != null,
      totalAmount: _totalAmount,
      selectedCustomerId: _selectedCustomerId,
      quoteNotReadyMessage: AppLocalizations.of(
        context,
      )!.unableToPrepareCheckoutTotal,
      emptyPaymentMessage: 'أدخل طريقة دفع واحدة على الأقل.',
      remainingNotCoveredMessage: 'المبلغ المتبقي غير مغطى.',
      creditRequiresCustomerMessage: 'البيع الآجل يتطلب اختيار عميل.',
    );
  }

  Future<void> _processPayment() async {
    final l10n = AppLocalizations.of(context)!;
    final validationMessage = _validatePaymentBeforeSubmit();

    if (validationMessage != null) {
      setState(() => _errorMessage = validationMessage);
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
              paymentIntents: _buildPaymentIntents(),
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
          width: isCompact ? double.infinity : 680,
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
    final customers = ref.watch(customerSearchResultsProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 600
                ? AppSpacing.lg
                : AppSpacing.xl,
          ),
          decoration: const BoxDecoration(gradient: AppColors.headerGradient),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.onPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.payment, color: AppColors.onPrimary),
              ),
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
              Text.rich(
                PosFormatters.amountRich(
                  _totalAmount,
                  amountStyle: TextStyle(
                    color: AppColors.onPrimary.withValues(alpha: 0.9),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
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
                _buildPaymentSummary(),
                const SizedBox(height: AppSpacing.lg),
                _buildPaymentLines(),
                const SizedBox(height: AppSpacing.lg),
                _buildSmartActions(),
                if (_activeLineKind != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _buildInlineLineEditor(),
                ],
                if (_hasCreditLine) ...[
                  const SizedBox(height: AppSpacing.lg),
                  customers.when(
                    data: _buildCustomerSearch,
                    loading: () => const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: AppLoading(),
                    ),
                    error: (error, _) => AppInfoBanner.error(
                      message: ErrorMapper.userMessage(error),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                AppCompleteButton(
                  isProcessing: _isProcessing,
                  enabled: _canConfirm,
                  label: 'إتمام الدفع',
                  onPressed: _processPayment,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSummary() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  'إجمالي الفاتورة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text.rich(
                  PosFormatters.amountRich(
                    _totalAmount,
                    amountStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.xl),
            AppPaymentSummaryRow(
              label: 'المدفوع فعليًا',
              value: _actualPaidAmount,
            ),
            const SizedBox(height: AppSpacing.xs),
            AppPaymentSummaryRow(label: 'الآجل', value: _creditAmount),
            const SizedBox(height: AppSpacing.xs),
            AppPaymentSummaryRow(label: 'المتبقي', value: _remainingAmount),
            const SizedBox(height: AppSpacing.xs),
            AppPaymentSummaryRow(label: 'الراجع', value: _change),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentLines() {
    if (_paymentLines.isEmpty) {
      return const AppInfoBanner(
        message: 'اختر طريقة دفع لإضافة سطر دفع.',
        type: AppBannerType.info,
      );
    }

    return Column(
      children: [
        for (final line in _paymentLines) ...[
          AppPaymentLineTile(
            line: line,
            onEdit: () => _selectLineKind(line.kind, line),
            onDelete: () => _removeLine(line.id),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _buildSmartActions() {
    final remaining = _remainingAmount;
    if (remaining <= 0.01) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Text(
          'اختر طريقة الدفع',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppPaymentMethodButton(
                icon: Icons.payments_outlined,
                label: 'كاش',
                subtitleWidget: Text.rich(
                  PosFormatters.amountRich(
                    remaining,
                    amountStyle: TextStyle(
                      fontSize: 11,
                      color: AppColors.success.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                color: AppColors.success,
                onPressed: _isProcessing
                    ? null
                    : () => _selectLineKind(SaleTenderKind.cash),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppPaymentMethodButton(
                icon: Icons.credit_card,
                label: 'شبكة',
                subtitleWidget: Text.rich(
                  PosFormatters.amountRich(
                    remaining,
                    amountStyle: TextStyle(
                      fontSize: 11,
                      color: AppColors.info.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                color: AppColors.info,
                onPressed: _isProcessing
                    ? null
                    : () => _selectLineKind(SaleTenderKind.network),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppPaymentMethodButton(
                icon: Icons.person_outline,
                label: 'آجل',
                subtitleWidget: Text.rich(
                  PosFormatters.amountRich(
                    remaining,
                    amountStyle: TextStyle(
                      fontSize: 11,
                      color: AppColors.warning.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                color: AppColors.warning,
                onPressed: _isProcessing
                    ? null
                    : () => _selectLineKind(SaleTenderKind.credit),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInlineLineEditor() {
    final kind = _activeLineKind!;
    final existing = _editingLineId == null
        ? null
        : _paymentLines.where((line) => line.id == _editingLineId).firstOrNull;
    final available = _availableFor(existing);
    final (icon, title, label) = switch (kind) {
      SaleTenderKind.cash => (
        Icons.payments_outlined,
        'دفع كاش',
        'المبلغ المستلم',
      ),
      SaleTenderKind.network => (Icons.credit_card, 'دفع شبكة', 'المبلغ'),
      SaleTenderKind.credit => (Icons.person_outline, 'دفع آجل', 'المبلغ'),
    };

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text.rich(
                  PosFormatters.amountRich(
                    available,
                    amountStyle: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _lineAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              labelText: label,
              prefixIcon: Icon(icon),
              onChanged: (_) =>
                  _submitInlineLine(showErrors: false, updateText: false),
              onSubmitted: (_) => _submitInlineLine(updateText: true),
            ),
            if (_lineInputError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AppInfoBanner.error(message: _lineInputError!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSearch(List<Customer> customers) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTextField(
          controller: _customerSearchController,
          labelText: '${l10n.customer} *',
          prefixIcon: const Icon(Icons.search),
          textInputAction: TextInputAction.search,
          onChanged: _scheduleCustomerSearch,
          onSubmitted: (value) {
            _customerSearchDebounce?.cancel();
            ref.read(customerSearchQueryProvider.notifier).state = value.trim();
          },
        ),
        if (_selectedCustomerName != null) ...[
          const SizedBox(height: AppSpacing.sm),
          AppInfoBanner(
            message:
                '${_selectedCustomerName!}${_selectedCustomerTaxNumber == null ? '' : ' - ${_selectedCustomerTaxNumber!}'}',
            type: AppBannerType.info,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        if (customers.isEmpty)
          AppInfoBanner(
            message: _customerSearchController.text.trim().isEmpty
                ? 'ابحث باسم العميل أو الجوال أو الرقم الضريبي.'
                : 'لا توجد نتائج مطابقة.',
            type: AppBannerType.info,
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: customers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final customer = customers[index];
                final selected = customer.id == _selectedCustomerId;
                final subtitleParts = [
                  if (customer.phone?.trim().isNotEmpty == true)
                    customer.phone!.trim(),
                  if (customer.taxNumber?.trim().isNotEmpty == true)
                    customer.taxNumber!.trim(),
                ];

                return ListTile(
                  dense: true,
                  leading: Icon(
                    selected ? Icons.check_circle : Icons.person_outline,
                    color: selected ? AppColors.success : null,
                  ),
                  title: Text(
                    customer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: subtitleParts.isEmpty
                      ? null
                      : Text(subtitleParts.join(' - ')),
                  onTap: () => _selectCustomer(customer),
                );
              },
            ),
          ),
      ],
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
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 48,
              color: AppColors.success,
            ),
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
          if (_change > 0) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: AppSpacing.borderRadiusMd,
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.currency_exchange, color: AppColors.info),
                  const SizedBox(width: AppSpacing.sm),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${l10n.change}: '),
                        PosFormatters.amountRich(
                          _change,
                          amountStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
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

    final outputActions = ref.read(invoiceOutputActionsProvider);
    showThermalReceiptPreview(
      context: context,
      saleId: id,
      outputActions: outputActions,
    );
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
