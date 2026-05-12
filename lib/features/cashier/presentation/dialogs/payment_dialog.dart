import 'dart:async';

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
import 'package:holol_POS/shared/presentation/widgets/app_info_banner.dart';
import 'package:holol_POS/shared/presentation/widgets/app_loading.dart';
import 'package:holol_POS/shared/presentation/widgets/app_text_field.dart';
import 'package:uuid/uuid.dart';

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
  final List<_PaymentDraftLine> _paymentLines = [];
  SaleTenderKind? _activeLineKind;
  String? _editingLineId;
  String? _lineInputError;

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

  double get _actualPaidAmount => PricingEngine.roundAmount(
    _paymentLines
        .where((line) => line.kind != SaleTenderKind.credit)
        .fold(0.0, (sum, line) => sum + line.amount),
  );

  double get _creditAmount => PricingEngine.roundAmount(
    _paymentLines
        .where((line) => line.kind == SaleTenderKind.credit)
        .fold(0.0, (sum, line) => sum + line.amount),
  );

  double get _arrangedAmount =>
      PricingEngine.roundAmount(_actualPaidAmount + _creditAmount);

  double get _remainingAmount {
    final remaining = PricingEngine.roundAmount(_totalAmount - _arrangedAmount);
    return remaining > 0.01 ? remaining : 0.0;
  }

  double get _change => PricingEngine.roundAmount(
    _paymentLines.fold(0.0, (sum, line) => sum + line.change),
  );

  bool get _hasCreditLine =>
      _paymentLines.any((line) => line.kind == SaleTenderKind.credit);

  bool get _canConfirm {
    if (_quote == null || _paymentLines.isEmpty || _isProcessing) return false;
    if (_remainingAmount > 0.01) return false;
    if (_hasCreditLine &&
        (_selectedCustomerId == null || _selectedCustomerId!.trim().isEmpty)) {
      return false;
    }
    return true;
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

  double _parseMoney(String text) {
    final normalized = text.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return 0.0;
    return double.tryParse(normalized) ?? double.nan;
  }

  void _scheduleCustomerSearch(String value) {
    _customerSearchDebounce?.cancel();
    _customerSearchDebounce = Timer(const Duration(milliseconds: 275), () {
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
      _paymentLines.removeWhere((line) => line.id == id);
      if (_editingLineId == id) {
        _activeLineKind = null;
        _editingLineId = null;
        _lineAmountController.clear();
        _lineInputError = null;
      }
      _errorMessage = null;
    });
  }

  void _selectLineKind(SaleTenderKind kind, [_PaymentDraftLine? existing]) {
    final available = _availableFor(existing);
    if (available <= 0) return;

    setState(() {
      _activeLineKind = kind;
      _editingLineId = existing?.id;
      _lineInputError = null;
      _lineAmountController.text =
          (kind == SaleTenderKind.cash
                  ? existing?.tenderedAmount ?? available
                  : existing?.amount ?? available)
              .toStringAsFixed(2);
    });

    if (existing == null && kind != SaleTenderKind.cash) {
      _submitInlineLine();
    }
  }

  double _availableFor(_PaymentDraftLine? existing) {
    return PricingEngine.roundAmount(
      _remainingAmount + (existing?.amount ?? 0),
    );
  }

  void _upsertLine(_PaymentDraftLine line, _PaymentDraftLine? existing) {
    setState(() {
      if (existing == null) {
        _paymentLines.add(line);
      } else {
        final index = _paymentLines.indexWhere(
          (item) => item.id == existing.id,
        );
        if (index >= 0) {
          _paymentLines[index] = line.copyWith(id: existing.id);
        }
      }
      _errorMessage = null;
    });
  }

  void _submitInlineLine() {
    final kind = _activeLineKind;
    if (kind == null) return;

    final existing = _editingLineId == null
        ? null
        : _paymentLines.where((line) => line.id == _editingLineId).firstOrNull;
    final available = _availableFor(existing);
    final input = PricingEngine.roundAmount(
      _parseMoney(_lineAmountController.text),
    );

    if (input.isNaN || input <= 0) {
      setState(
        () => _lineInputError =
            'ط£ط¯ط®ظ„ ظ…ط¨ظ„ط؛ظ‹ط§ طµط­ظٹط­ظ‹ط§ ط£ظƒط¨ط± ظ…ظ† طµظپط±.',
      );
      return;
    }

    if (kind != SaleTenderKind.cash && input - available > 0.01) {
      setState(
        () => _lineInputError =
            'ط§ظ„ظ…ط¨ظ„ط؛ ظ„ط§ ظٹظ…ظƒظ† ط£ظ† ظٹطھط¬ط§ظˆط² ط§ظ„ظ…طھط¨ظ‚ظٹ.',
      );
      return;
    }

    final amount = kind == SaleTenderKind.cash && input > available
        ? available
        : input;
    final line = _PaymentDraftLine(
      id: existing?.id ?? const Uuid().v4(),
      kind: kind,
      amount: PricingEngine.roundAmount(amount),
      tenderedAmount: kind == SaleTenderKind.cash ? input : amount,
    );

    _upsertLine(line, existing);
    setState(() {
      _activeLineKind = kind;
      _editingLineId = line.id;
      _lineInputError = null;
      _lineAmountController.text = line.tenderedAmount.toStringAsFixed(2);
    });
  }

  List<SalePaymentIntent> _buildPaymentIntents() {
    return _paymentLines
        .map(
          (line) => SalePaymentIntent(
            kind: line.kind,
            amount: line.amount,
            tenderedAmount: line.kind == SaleTenderKind.cash
                ? line.tenderedAmount
                : line.amount,
          ),
        )
        .toList(growable: false);
  }

  String? _validatePaymentBeforeSubmit() {
    if (_quote == null) {
      return AppLocalizations.of(context)!.unableToPrepareCheckoutTotal;
    }

    if (_paymentLines.isEmpty) {
      return 'ط£ط¯ط®ظ„ ط·ط±ظٹظ‚ط© ط¯ظپط¹ ظˆط§ط­ط¯ط© ط¹ظ„ظ‰ ط§ظ„ط£ظ‚ظ„.';
    }

    if (_remainingAmount > 0.01) {
      return 'ط§ظ„ظ…ط¨ظ„ط؛ ط§ظ„ظ…طھط¨ظ‚ظٹ ط؛ظٹط± ظ…ط؛ط·ظ‰.';
    }

    if (_hasCreditLine &&
        (_selectedCustomerId == null || _selectedCustomerId!.trim().isEmpty)) {
      return 'ط§ظ„ط¨ظٹط¹ ط§ظ„ط¢ط¬ظ„ ظٹطھط·ظ„ط¨ ط§ط®طھظٹط§ط± ط¹ظ…ظٹظ„.';
    }

    return null;
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
                _CompleteButton(
                  isProcessing: _isProcessing,
                  enabled: _canConfirm,
                  label: 'ط¥طھظ…ط§ظ… ط§ظ„ط¯ظپط¹',
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppSpacing.borderRadiusMd,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            _SummaryRow(
              label: 'ط¥ط¬ظ…ط§ظ„ظٹ ط§ظ„ظپط§طھظˆط±ط©',
              value: _totalAmount,
            ),
            const Divider(height: AppSpacing.lg),
            _SummaryRow(
              label: 'ط§ظ„ظ…ط¯ظپظˆط¹ ظپط¹ظ„ظٹظ‹ط§',
              value: _actualPaidAmount,
            ),
            const SizedBox(height: AppSpacing.sm),
            _SummaryRow(label: 'ط§ظ„ط¢ط¬ظ„', value: _creditAmount),
            const SizedBox(height: AppSpacing.sm),
            _SummaryRow(label: 'ط§ظ„ظ…طھط¨ظ‚ظٹ', value: _remainingAmount),
            const SizedBox(height: AppSpacing.sm),
            _SummaryRow(label: 'ط§ظ„ط±ط§ط¬ط¹', value: _change),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentLines() {
    if (_paymentLines.isEmpty) {
      return const AppInfoBanner(
        message: 'ط§ط®طھط± ط·ط±ظٹظ‚ط© ط¯ظپط¹ ظ„ط¥ط¶ط§ظپط© ط³ط·ط± ط¯ظپط¹.',
        type: AppBannerType.info,
      );
    }

    return Column(
      children: [
        for (final line in _paymentLines) ...[
          _PaymentLineTile(
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

    final prefix = _paymentLines.isEmpty ? '' : 'ط£ظƒظ…ظ„ ';

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      alignment: WrapAlignment.center,
      children: [
        AppButton.outlined(
          onPressed: _isProcessing
              ? null
              : () => _selectLineKind(SaleTenderKind.cash),
          icon: Icons.payments_outlined,
          label: '${prefix}ظƒط§ط´ ${PosFormatters.amount(remaining)}',
        ),
        AppButton.outlined(
          onPressed: _isProcessing
              ? null
              : () => _selectLineKind(SaleTenderKind.network),
          icon: Icons.credit_card,
          label: '${prefix}ط´ط¨ظƒط© ${PosFormatters.amount(remaining)}',
        ),
        AppButton.outlined(
          onPressed: _isProcessing
              ? null
              : () => _selectLineKind(SaleTenderKind.credit),
          icon: Icons.person_outline,
          label: '${prefix}ط¢ط¬ظ„ ${PosFormatters.amount(remaining)}',
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
        'ط¯ظپط¹ ظƒط§ط´',
        'ط§ظ„ظ…ط¨ظ„ط؛ ط§ظ„ظ…ط³طھظ„ظ…',
      ),
      SaleTenderKind.network => (
        Icons.credit_card,
        'ط¯ظپط¹ ط´ط¨ظƒط©',
        'ط§ظ„ظ…ط¨ظ„ط؛',
      ),
      SaleTenderKind.credit => (
        Icons.person_outline,
        'ط¯ظپط¹ ط¢ط¬ظ„',
        'ط§ظ„ظ…ط¨ظ„ط؛',
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppSpacing.borderRadiusMd,
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
              onSubmitted: (_) => _submitInlineLine(),
            ),
            if (_lineInputError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AppInfoBanner.error(message: _lineInputError!),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppButton.outlined(
                    onPressed: _isProcessing
                        ? null
                        : () {
                            setState(() {
                              _activeLineKind = null;
                              _editingLineId = null;
                              _lineAmountController.clear();
                              _lineInputError = null;
                            });
                          },
                    label: 'ط¥ط؛ظ„ط§ظ‚',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton.primary(
                    onPressed: _isProcessing ? null : _submitInlineLine,
                    label: existing == null ? 'ط¥ط¶ط§ظپط©' : 'طھط­ط¯ظٹط«',
                  ),
                ),
              ],
            ),
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
                ? 'ط§ط¨ط­ط« ط¨ط§ط³ظ… ط§ظ„ط¹ظ…ظٹظ„ ط£ظˆ ط§ظ„ط¬ظˆط§ظ„ ط£ظˆ ط§ظ„ط±ظ‚ظ… ط§ظ„ط¶ط±ظٹط¨ظٹ.'
                : 'ظ„ط§ طھظˆط¬ط¯ ظ†طھط§ط¦ط¬ ظ…ط·ط§ط¨ظ‚ط©.',
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
        ? 'طھظ… طھط³ط¬ظٹظ„ ط§ظ„ط¨ظٹط¹ ط§ظ„ط¢ط¬ظ„'
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
          if (_change > 0) ...[
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

class _PaymentDraftLine {
  final String id;
  final SaleTenderKind kind;
  final double amount;
  final double tenderedAmount;

  const _PaymentDraftLine({
    required this.id,
    required this.kind,
    required this.amount,
    required this.tenderedAmount,
  });

  double get change {
    if (kind != SaleTenderKind.cash) return 0.0;
    final value = PricingEngine.roundAmount(tenderedAmount - amount);
    return value > 0 ? value : 0.0;
  }

  _PaymentDraftLine copyWith({
    String? id,
    SaleTenderKind? kind,
    double? amount,
    double? tenderedAmount,
  }) {
    return _PaymentDraftLine(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      amount: amount ?? this.amount,
      tenderedAmount: tenderedAmount ?? this.tenderedAmount,
    );
  }
}

class _PaymentLineTile extends StatelessWidget {
  final _PaymentDraftLine line;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PaymentLineTile({
    required this.line,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, title) = switch (line.kind) {
      SaleTenderKind.cash => (Icons.payments_outlined, 'ظƒط§ط´'),
      SaleTenderKind.network => (Icons.credit_card, 'ط´ط¨ظƒط©'),
      SaleTenderKind.credit => (Icons.person_outline, 'ط¢ط¬ظ„'),
    };

    final subtitle = line.kind == SaleTenderKind.cash && line.change > 0
        ? 'ط§ظ„ظ…ط³طھظ„ظ… ${PosFormatters.amount(line.tenderedAmount)} - ط§ظ„ط±ط§ط¬ط¹ ${PosFormatters.amount(line.change)}'
        : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppSpacing.borderRadiusMd,
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: Wrap(
          spacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text.rich(
              PosFormatters.amountRich(
                line.amount,
                amountStyle: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'طھط¹ط¯ظٹظ„',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'ط­ط°ظپ',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text.rich(
          PosFormatters.amountRich(
            value,
            amountStyle: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _CompleteButton extends StatelessWidget {
  final bool isProcessing;
  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  const _CompleteButton({
    required this.isProcessing,
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.jumbo + AppSpacing.sm,
      child: AppButton.primary(
        onPressed: !enabled || isProcessing ? null : onPressed,
        customColor: AppColors.payButton,
        isLoading: isProcessing,
        label: label,
      ),
    );
  }
}
