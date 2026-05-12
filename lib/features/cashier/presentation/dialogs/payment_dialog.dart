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
  Timer? _customerSearchDebounce;

  final String _checkoutAttemptId = 'CHK_${const Uuid().v4()}';
  final List<_PaymentDraftLine> _paymentLines = [];

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

  double get _paidAmount => PricingEngine.roundAmount(
    _paymentLines.fold(0.0, (sum, line) => sum + line.amount),
  );

  double get _remainingAmount {
    final remaining = PricingEngine.roundAmount(_totalAmount - _paidAmount);
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
      _errorMessage = null;
    });
  }

  Future<void> _addCashLine([_PaymentDraftLine? existing]) async {
    final available = _availableFor(existing);
    final line = await showDialog<_PaymentDraftLine>(
      context: context,
      builder: (context) => _CashLineDialog(
        availableAmount: available,
        existing: existing,
        parseMoney: _parseMoney,
      ),
    );

    if (line == null) return;
    _upsertLine(line, existing);
  }

  Future<void> _addAmountLine(
    SaleTenderKind kind, [
    _PaymentDraftLine? existing,
  ]) async {
    final available = _availableFor(existing);
    if (available <= 0) return;

    if (existing == null &&
        (kind == SaleTenderKind.network || kind == SaleTenderKind.credit)) {
      _upsertLine(
        _PaymentDraftLine(
          id: const Uuid().v4(),
          kind: kind,
          amount: available,
          tenderedAmount: available,
        ),
        existing,
      );
      return;
    }

    final line = await showDialog<_PaymentDraftLine>(
      context: context,
      builder: (context) => _AmountLineDialog(
        kind: kind,
        availableAmount: available,
        existing: existing,
        parseMoney: _parseMoney,
      ),
    );

    if (line == null) return;
    _upsertLine(line, existing);
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
      return 'أدخل طريقة دفع واحدة على الأقل.';
    }

    if (_remainingAmount > 0.01) {
      return 'المبلغ المتبقي غير مغطى.';
    }

    if (_hasCreditLine &&
        (_selectedCustomerId == null || _selectedCustomerId!.trim().isEmpty)) {
      return 'البيع الآجل يتطلب اختيار عميل.';
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppSpacing.borderRadiusMd,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            _SummaryRow(label: 'إجمالي الفاتورة', value: _totalAmount),
            const Divider(height: AppSpacing.lg),
            _SummaryRow(label: 'المدفوع', value: _paidAmount),
            const SizedBox(height: AppSpacing.sm),
            _SummaryRow(label: 'المتبقي', value: _remainingAmount),
            const SizedBox(height: AppSpacing.sm),
            _SummaryRow(label: 'الراجع', value: _change),
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
          _PaymentLineTile(
            line: line,
            onEdit: () => line.kind == SaleTenderKind.cash
                ? _addCashLine(line)
                : _addAmountLine(line.kind, line),
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

    final prefix = _paymentLines.isEmpty ? '' : 'أكمل ';

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      alignment: WrapAlignment.center,
      children: [
        AppButton.outlined(
          onPressed: _isProcessing ? null : () => _addCashLine(),
          icon: Icons.payments_outlined,
          label: '${prefix}كاش',
        ),
        AppButton.outlined(
          onPressed: _isProcessing
              ? null
              : () => _addAmountLine(SaleTenderKind.network),
          icon: Icons.credit_card,
          label: '${prefix}شبكة',
        ),
        AppButton.outlined(
          onPressed: _isProcessing
              ? null
              : () => _addAmountLine(SaleTenderKind.credit),
          icon: Icons.person_outline,
          label: '${prefix}آجل',
        ),
      ],
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
      SaleTenderKind.cash => (Icons.payments_outlined, 'كاش'),
      SaleTenderKind.network => (Icons.credit_card, 'شبكة'),
      SaleTenderKind.credit => (Icons.person_outline, 'آجل'),
    };

    final subtitle = line.kind == SaleTenderKind.cash && line.change > 0
        ? 'المستلم ${PosFormatters.amount(line.tenderedAmount)} - الراجع ${PosFormatters.amount(line.change)}'
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
            Text(
              PosFormatters.amount(line.amount),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            IconButton(
              tooltip: 'تعديل',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'حذف',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _CashLineDialog extends StatefulWidget {
  final double availableAmount;
  final _PaymentDraftLine? existing;
  final double Function(String text) parseMoney;

  const _CashLineDialog({
    required this.availableAmount,
    required this.existing,
    required this.parseMoney,
  });

  @override
  State<_CashLineDialog> createState() => _CashLineDialogState();
}

class _CashLineDialogState extends State<_CashLineDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: (widget.existing?.tenderedAmount ?? widget.availableAmount)
          .toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final tendered = PricingEngine.roundAmount(
      widget.parseMoney(_controller.text),
    );
    if (tendered.isNaN || tendered <= 0) {
      setState(() => _error = 'أدخل مبلغًا صحيحًا أكبر من صفر.');
      return;
    }

    final amount = tendered > widget.availableAmount
        ? widget.availableAmount
        : tendered;

    Navigator.of(context).pop(
      _PaymentDraftLine(
        id: widget.existing?.id ?? const Uuid().v4(),
        kind: SaleTenderKind.cash,
        amount: PricingEngine.roundAmount(amount),
        tenderedAmount: tendered,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('دفع كاش'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppInfoBanner(
            message: 'المتبقي: ${PosFormatters.amount(widget.availableAmount)}',
            type: AppBannerType.info,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            labelText: 'المبلغ المستلم',
            prefixIcon: const Icon(Icons.payments_outlined),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppInfoBanner.error(message: _error!),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('إضافة')),
      ],
    );
  }
}

class _AmountLineDialog extends StatefulWidget {
  final SaleTenderKind kind;
  final double availableAmount;
  final _PaymentDraftLine? existing;
  final double Function(String text) parseMoney;

  const _AmountLineDialog({
    required this.kind,
    required this.availableAmount,
    required this.existing,
    required this.parseMoney,
  });

  @override
  State<_AmountLineDialog> createState() => _AmountLineDialogState();
}

class _AmountLineDialogState extends State<_AmountLineDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: (widget.existing?.amount ?? widget.availableAmount).toStringAsFixed(
        2,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = PricingEngine.roundAmount(
      widget.parseMoney(_controller.text),
    );
    if (amount.isNaN || amount <= 0) {
      setState(() => _error = 'أدخل مبلغًا صحيحًا أكبر من صفر.');
      return;
    }
    if (amount - widget.availableAmount > 0.01) {
      setState(() => _error = 'المبلغ لا يمكن أن يتجاوز المتبقي.');
      return;
    }

    Navigator.of(context).pop(
      _PaymentDraftLine(
        id: widget.existing?.id ?? const Uuid().v4(),
        kind: widget.kind,
        amount: amount,
        tenderedAmount: amount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.kind == SaleTenderKind.network
        ? 'دفع شبكة'
        : 'دفع آجل';
    final icon = widget.kind == SaleTenderKind.network
        ? Icons.credit_card
        : Icons.person_outline;

    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppInfoBanner(
            message: 'المتبقي: ${PosFormatters.amount(widget.availableAmount)}',
            type: AppBannerType.info,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            labelText: 'المبلغ',
            prefixIcon: Icon(icon),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppInfoBanner.error(message: _error!),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('حفظ')),
      ],
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
        Text(
          PosFormatters.amount(value),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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
