// features/history/presentation/history_screen.dart
// WHY: Lightweight POS sales history. Search by invoice number or product,
// then open invoice details.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pos_flutter/app/router.dart';
import 'package:pos_flutter/core/design_system/colors.dart';
import 'package:pos_flutter/core/design_system/layout.dart';
import 'package:pos_flutter/core/design_system/spacing.dart';
import 'package:pos_flutter/core/errors/app_exception.dart';
import 'package:pos_flutter/core/l10n/app_localizations.dart';
import 'package:pos_flutter/core/services/formatters/pos_formatters.dart';
import 'package:pos_flutter/features/sales/application/sales_service.dart';
import 'package:pos_flutter/shared/models/sales_history.dart';
import 'package:pos_flutter/shared/presentation/presenters/sale_status_presenter.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_empty_state.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_info_banner.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_loading.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_status_chip.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_text_field.dart';

final historySearchQueryProvider = StateProvider.autoDispose<String>((ref) {
  return '';
});

final historySalesProvider = FutureProvider.autoDispose<List<SaleSummary>>((
  ref,
) async {
  final query = ref.watch(historySearchQueryProvider);
  final salesService = ref.watch(salesServiceProvider);

  return salesService.searchSalesHistory(query: query, limit: 100);
});

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(historySearchQueryProvider.notifier).state = value.trim();
    });
  }

  void _applySearch(String value) {
    _debounce?.cancel();
    ref.read(historySearchQueryProvider.notifier).state = value.trim();
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    ref.read(historySearchQueryProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final salesAsync = ref.watch(historySalesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.salesHistory),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(historySalesProvider),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppContentWidth.wide),
          child: Column(
            children: [
              Padding(
                padding: AppSpacing.paddingLg,
                child: _HistorySearchField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onSubmitted: _applySearch,
                  onClear: _clearSearch,
                ),
              ),
              Expanded(
                child: salesAsync.when(
                  data: (sales) => _HistoryResults(sales: sales),
                  loading: () => const AppLoading(),
                  error: (error, _) => Padding(
                    padding: AppSpacing.paddingLg,
                    child: AppInfoBanner.error(
                      message: ErrorMapper.userMessage(error),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistorySearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  const _HistorySearchField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppTextField(
      controller: controller,
      labelText: l10n.searchInvoiceOrProduct,
      prefixIcon: const Icon(Icons.search),
      suffixIcon: IconButton(
        tooltip: l10n.clearFilters,
        icon: const Icon(Icons.clear),
        onPressed: onClear,
      ),
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

class _HistoryResults extends StatelessWidget {
  final List<SaleSummary> sales;

  const _HistoryResults({required this.sales});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (sales.isEmpty) {
      return AppEmptyState(icon: Icons.receipt_long, title: l10n.noSalesFound);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < AppBreakpoints.medium;

        if (compact) {
          return ListView.separated(
            padding: AppSpacing.paddingMd,
            itemCount: sales.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              return _SaleCard(sale: sales[index]);
            },
          );
        }

        return _SalesTable(sales: sales);
      },
    );
  }
}

class _SalesTable extends StatelessWidget {
  final List<SaleSummary> sales;

  const _SalesTable({required this.sales});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scrollbar(
      child: SingleChildScrollView(
        padding: AppSpacing.paddingLg,
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            showCheckboxColumn: false,
            headingRowColor: WidgetStateProperty.all(AppColors.surface),
            columnSpacing: AppSpacing.xl,
            columns: [
              DataColumn(label: Text(l10n.invoice)),
              DataColumn(label: Text(l10n.products)),
              DataColumn(label: Text(l10n.total)),
              DataColumn(label: Text(l10n.date)),
              DataColumn(label: Text(l10n.status)),
            ],
            rows: [
              for (final sale in sales)
                DataRow(
                  onSelectChanged: (_) {
                    context.push(AppRoutes.invoicePath(sale.id));
                  },
                  cells: [
                    DataCell(_InvoiceCell(sale: sale)),
                    DataCell(_ProductsCell(sale: sale)),
                    DataCell(_AmountCell(sale: sale)),
                    DataCell(Text(PosFormatters.dateTime(sale.createdAt))),
                    DataCell(_StatusCell(sale: sale)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  final SaleSummary sale;

  const _SaleCard({required this.sale});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final invoiceNo = _invoiceNo(sale);
    final statusColor = SaleStatusPresenter.color(sale.status);

    return Card(
      child: InkWell(
        onTap: () => context.push(AppRoutes.invoicePath(sale.id)),
        borderRadius: AppSpacing.borderRadiusMd,
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _InvoiceText(invoiceNo: invoiceNo)),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    PosFormatters.amount(sale.grandTotal),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                sale.productSummary.isEmpty ? '-' : sale.productSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      PosFormatters.dateTime(sale.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  AppStatusChip(
                    label: SaleStatusPresenter.label(sale.status, l10n),
                    color: statusColor,
                    icon: SaleStatusPresenter.icon(sale.status),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceCell extends StatelessWidget {
  final SaleSummary sale;

  const _InvoiceCell({required this.sale});

  @override
  Widget build(BuildContext context) {
    return _InvoiceText(invoiceNo: _invoiceNo(sale));
  }
}

class _InvoiceText extends StatelessWidget {
  final String invoiceNo;

  const _InvoiceText({required this.invoiceNo});

  @override
  Widget build(BuildContext context) {
    return Text(
      invoiceNo,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontFamily: 'monospace',
      ),
    );
  }
}

class _ProductsCell extends StatelessWidget {
  final SaleSummary sale;

  const _ProductsCell({required this.sale});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Text(
        sale.productSummary.isEmpty ? '-' : sale.productSummary,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _AmountCell extends StatelessWidget {
  final SaleSummary sale;

  const _AmountCell({required this.sale});

  @override
  Widget build(BuildContext context) {
    return Text(
      PosFormatters.amount(sale.grandTotal),
      style: TextStyle(
        fontWeight: FontWeight.w800,
        color: SaleStatusPresenter.color(sale.status),
      ),
    );
  }
}

class _StatusCell extends StatelessWidget {
  final SaleSummary sale;

  const _StatusCell({required this.sale});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppStatusChip(
      label: SaleStatusPresenter.label(sale.status, l10n),
      color: SaleStatusPresenter.color(sale.status),
      icon: SaleStatusPresenter.icon(sale.status),
    );
  }
}

String _invoiceNo(SaleSummary sale) {
  return sale.localSaleNo.isNotEmpty ? sale.localSaleNo : sale.id;
}
