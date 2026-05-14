// features/history/presentation/history_screen.dart
// WHY: Lightweight POS sales history. Search by invoice number or product,
// then open invoice details.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:holol_POS/app/router.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/layout.dart';
import 'package:holol_POS/core/design_system/spacing.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/l10n/app_localizations.dart';
import 'package:holol_POS/core/services/formatters/pos_formatters.dart';
import 'package:holol_POS/features/sales/application/sales_history_service.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/shared/models/sales_history.dart';
import 'package:holol_POS/shared/presentation/presenters/sale_status_presenter.dart';
import 'package:holol_POS/shared/presentation/utils/app_snackbar.dart';
import 'package:holol_POS/shared/presentation/widgets/app_empty_state.dart';
import 'package:holol_POS/shared/presentation/widgets/app_info_banner.dart';
import 'package:holol_POS/shared/presentation/widgets/app_loading.dart';
import 'package:holol_POS/shared/presentation/widgets/app_status_chip.dart';
import 'package:holol_POS/shared/presentation/dialogs/app_dialog.dart';
import 'package:holol_POS/shared/refactor/pos_ui_widgets.dart';

final historySearchQueryProvider = StateProvider.autoDispose<String>((ref) {
  return '';
});

final historySalesProvider = FutureProvider.autoDispose<List<SaleSummary>>((
  ref,
) async {
  final query = ref.watch(historySearchQueryProvider);
  final salesHistoryService = ref.watch(salesHistoryServiceProvider);

  return salesHistoryService.searchSalesHistory(query: query, limit: 100);
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
      body: Column(
        children: [
          // ── Gradient Header ──
          Container(
            width: double.infinity,
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),
                child: Column(
                  children: [
                    // Title row
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: AppColors.onPrimary,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.receipt_long,
                            color: AppColors.onPrimary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          l10n.salesHistory,
                          style: const TextStyle(
                            color: AppColors.onPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        // Count badge
                        salesAsync.whenOrNull(
                              data: (sales) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xxs,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: AppSpacing.borderRadiusSm,
                                ),
                                child: Text(
                                  '${sales.length}',
                                  style: const TextStyle(
                                    color: AppColors.onPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ) ??
                            const SizedBox.shrink(),
                        const SizedBox(width: AppSpacing.xs),
                        IconButton(
                          tooltip: l10n.refresh,
                          icon: const Icon(
                            Icons.refresh,
                            color: AppColors.onPrimary,
                          ),
                          onPressed: () => ref.invalidate(historySalesProvider),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Search
                    AppHeaderSearchField(
                      controller: _searchController,
                      hintText: l10n.searchInvoiceOrProduct,
                      clearTooltip: l10n.clearFilters,
                      onChanged: _onSearchChanged,
                      onSubmitted: _applySearch,
                      onClear: _clearSearch,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Body ──
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppContentWidth.wide,
                ),
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
            ),
          ),
        ],
      ),
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
              const DataColumn(label: Text('')),
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
                    DataCell(_SaleActions(sale: sale)),
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

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(color: AppColors.border),
        boxShadow: AppSpacing.shadowSm,
      ),
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
                  Text.rich(
                    PosFormatters.amountRich(
                      sale.grandTotal,
                      amountStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
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
                  _SaleActions(sale: sale),
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
    return Text.rich(
      PosFormatters.amountRich(
        sale.grandTotal,
        amountStyle: TextStyle(
          fontWeight: FontWeight.w800,
          color: SaleStatusPresenter.color(sale.status),
        ),
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

class _SaleActions extends ConsumerWidget {
  final SaleSummary sale;

  const _SaleActions({required this.sale});

  bool get _canChange =>
      sale.type == SaleType.sale.code &&
      sale.status == SaleStatus.completed.code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_canChange) return const SizedBox.shrink();

    return PopupMenuButton<_SaleHistoryAction>(
      tooltip: 'إجراءات',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) => _runAction(context, ref, action),
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _SaleHistoryAction.voidSale,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.cancel_outlined),
            title: Text('إلغاء البيع'),
          ),
        ),
        PopupMenuItem(
          value: _SaleHistoryAction.returnSale,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.keyboard_return),
            title: Text('مرتجع كامل'),
          ),
        ),
      ],
    );
  }

  Future<void> _runAction(
    BuildContext context,
    WidgetRef ref,
    _SaleHistoryAction action,
  ) async {
    final isVoid = action == _SaleHistoryAction.voidSale;
    final confirmed = await AppDialog.show<bool>(
      context: context,
      dialog: AppDialog.warning(
        title: isVoid ? 'إلغاء البيع' : 'مرتجع كامل',
        content: Text(_invoiceNo(sale)),
        confirmLabel: 'تأكيد',
        cancelLabel: 'إلغاء',
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final service = ref.read(salesHistoryServiceProvider);
      if (action == _SaleHistoryAction.voidSale) {
        await service.voidSale(sale.id);
      } else {
        await service.returnSale(sale.id);
      }
      ref.invalidate(historySalesProvider);
      if (context.mounted) {
        AppSnackbar.showSuccess(context, 'تم تنفيذ العملية.');
      }
    } catch (error) {
      if (context.mounted) {
        AppSnackbar.showError(context, ErrorMapper.userMessage(error));
      }
    }
  }
}

enum _SaleHistoryAction { voidSale, returnSale }

String _invoiceNo(SaleSummary sale) {
  return sale.localSaleNo.isNotEmpty ? sale.localSaleNo : sale.id;
}
