import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:holol_POS/app/router.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/layout.dart';
import 'package:holol_POS/core/design_system/spacing.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/l10n/app_localizations.dart';
import 'package:holol_POS/core/services/formatters/pos_formatters.dart';
import 'package:holol_POS/core/services/invoices/invoice_document.dart';
import 'package:holol_POS/core/services/invoices/invoice_output_actions.dart';
import 'package:holol_POS/core/services/invoices/invoice_print_history_entry.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
import 'package:holol_POS/shared/presentation/presenters/printer_status_presenter.dart';
import 'package:holol_POS/shared/presentation/presenters/sale_status_presenter.dart';
import 'package:holol_POS/shared/presentation/widgets/app_info_banner.dart';
import 'package:holol_POS/shared/presentation/widgets/app_panel.dart';
import 'package:holol_POS/shared/presentation/widgets/app_status_chip.dart';
import 'package:holol_POS/shared/presentation/widgets/key_value_row.dart';
import 'package:holol_POS/shared/presentation/utils/app_snackbar.dart';
import 'package:holol_POS/shared/presentation/widgets/app_button.dart';
import 'package:holol_POS/shared/presentation/widgets/app_loading.dart';

final invoiceDocumentProvider = FutureProvider.autoDispose
    .family<InvoiceDocument, String>((ref, id) {
      return ref.watch(invoiceOutputActionsProvider).getOrCreateOriginal(id);
    });

final invoicePrintHistoryProvider = FutureProvider.autoDispose
    .family<List<InvoicePrintHistoryEntry>, String>((ref, id) {
      return ref.watch(invoicePrintHistoryDaoProvider).getForSale(id);
    });

class InvoicePreviewScreen extends ConsumerWidget {
  final String saleId;

  const InvoicePreviewScreen({super.key, required this.saleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentAsync = ref.watch(invoiceDocumentProvider(saleId));
    final l10n = AppLocalizations.of(context)!;
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
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
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
                      l10n.receipt,
                      style: const TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: l10n.refresh,
                      icon: const Icon(
                        Icons.refresh,
                        color: AppColors.onPrimary,
                      ),
                      onPressed: () =>
                          ref.invalidate(invoiceDocumentProvider(saleId)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Body ──
          Expanded(
            child: documentAsync.when(
              loading: () => const AppLoading(),
              error: (error, _) => Center(
                child: Padding(
                  padding: AppSpacing.paddingLg,
                  child: AppInfoBanner.error(
                    message: ErrorMapper.userMessage(error),
                  ),
                ),
              ),
              data: (document) => _InvoicePreview(document: document),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoicePreview extends ConsumerWidget {
  final InvoiceDocument document;

  const _InvoicePreview({required this.document});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppContentWidth.wide),
        child: ListView(
          padding: AppSpacing.paddingLg,
          children: [
            _Header(document: document),
            const SizedBox(height: AppSpacing.md),
            _Actions(document: document),
            const SizedBox(height: AppSpacing.md),
            _InfoGrid(document: document),
            const SizedBox(height: AppSpacing.md),
            _LinesTable(document: document),
            const SizedBox(height: AppSpacing.md),
            _Totals(document: document),
            const SizedBox(height: AppSpacing.md),
            _Payments(document: document),
            const SizedBox(height: AppSpacing.md),
            _AuditPanel(document: document),
            const SizedBox(height: AppSpacing.md),
            _PrintHistory(saleId: document.saleId),
            const SizedBox(height: AppSpacing.md),
            AppInfoBanner(
              message: document.syncStatusLabel,
              type: AppBannerType.warning,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final InvoiceDocument document;

  const _Header({required this.document});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: AppSpacing.borderRadiusLg,
      ),
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.md,
        alignment: WrapAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.seller.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  document.branch.name,
                  style: TextStyle(
                    color: AppColors.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
                if (document.branch.taxNumber?.isNotEmpty == true)
                  Text(
                    'الرقم الضريبي: ${document.branch.taxNumber}',
                    style: TextStyle(
                      color: AppColors.onPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                if (document.branch.address?.isNotEmpty == true)
                  Text(
                    document.branch.address!,
                    style: TextStyle(
                      color: AppColors.onPrimary.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  document.invoiceTypeLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SelectableText(
                  document.localInvoiceNo,
                  style: TextStyle(
                    color: AppColors.onPrimary.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                AppStatusChip(
                  label: document.statusCode.isEmpty
                      ? document.statusLabel
                      : SaleStatusPresenter.label(
                          document.statusCode,
                          AppLocalizations.of(context)!,
                        ),
                  color: document.statusCode.isEmpty
                      ? AppColors.success
                      : SaleStatusPresenter.color(document.statusCode),
                  icon: document.statusCode.isEmpty
                      ? null
                      : SaleStatusPresenter.icon(document.statusCode),
                ),
                if (document.copyInfo.isCopy) ...[
                  const SizedBox(height: AppSpacing.xs),
                  AppStatusChip(
                    label: document.copyInfo.label,
                    color: AppColors.warning,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  final InvoiceDocument document;

  const _Actions({required this.document});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final printHistory = ref.watch(
      invoicePrintHistoryProvider(document.saleId),
    );
    final hasPrintedOriginal =
        printHistory.valueOrNull?.any(
          (row) => !row.isReprint && row.status == 'printed',
        ) ??
        false;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        if (!hasPrintedOriginal)
          AppButton.primary(
            onPressed: () => _print(context, ref, reprint: false),
            icon: Icons.print,
            label: 'طباعة أصلية',
          ),
        AppButton.outlined(
          onPressed: () => _print(context, ref, reprint: true),
          icon: Icons.history,
          label: hasPrintedOriginal ? 'إعادة طباعة' : 'طباعة نسخة',
        ),
        AppButton.outlined(
          onPressed: () => _savePdf(context, ref),
          icon: Icons.picture_as_pdf,
          label: 'حفظ PDF',
        ),
        AppButton.outlined(
          onPressed: () => _share(context, ref),
          icon: Icons.share,
          label: 'مشاركة',
        ),
        AppButton.outlined(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: document.localInvoiceNo));
            AppSnackbar.showSuccess(context, 'تم نسخ رقم الفاتورة');
          },
          icon: Icons.copy,
          label: 'نسخ الرقم',
        ),
        AppButton.text(
          onPressed: () => context.go(AppRoutes.cashier),
          icon: Icons.point_of_sale,
          label: l10n.backToPos,
        ),
      ],
    );
  }

  Future<void> _print(
    BuildContext context,
    WidgetRef ref, {
    required bool reprint,
  }) async {
    final output = ref.read(invoiceOutputActionsProvider);
    final activeSession = ref.read(activePosSessionProvider).valueOrNull;
    final result = reprint
        ? await output.reprint(
            document.saleId,
            createdBy: activeSession?.activeUserId ?? document.cashier.userId,
          )
        : await output.printOriginal(
            document.saleId,
            createdBy: activeSession?.activeUserId ?? document.cashier.userId,
          );
    if (!context.mounted) return;
    if (result.hasFailures) {
      AppSnackbar.showWarning(
        context,
        result.noEligiblePrinter
            ? 'لا توجد طابعة مفعلة.'
            : 'تم حفظ الفاتورة، لكن فشلت الطباعة.',
      );
    } else {
      AppSnackbar.showSuccess(context, 'تم إرسال الفاتورة للطباعة.');
    }
    ref.invalidate(invoicePrintHistoryProvider(document.saleId));
  }

  Future<void> _savePdf(BuildContext context, WidgetRef ref) async {
    final file = await ref
        .read(invoiceOutputActionsProvider)
        .savePdf(document.saleId);
    if (context.mounted) {
      AppSnackbar.showSuccess(context, 'تم حفظ ملف PDF: ${file.path}');
    }
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(invoiceOutputActionsProvider).sharePdf(document.saleId);
    } catch (error) {
      if (context.mounted) {
        AppSnackbar.showError(context, 'فشلت المشاركة.');
      }
    }
  }
}

class _InfoGrid extends StatelessWidget {
  final InvoiceDocument document;

  const _InfoGrid({required this.document});

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Wrap(
        spacing: AppSpacing.xl,
        runSpacing: AppSpacing.md,
        children: [
          _InfoTile(
            'التاريخ',
            PosFormatters.dateTime(document.invoiceDateTime),
          ),
          _InfoTile('الكاشير', document.cashier.name),
          _InfoTile('الجهاز', document.terminal.terminalId),
          _InfoTile('نقطة التشغيل', document.terminal.machineNumber ?? '-'),
          _InfoTile('العميل', document.customer?.name ?? '-'),
          _InfoTile('حالة الطباعة', document.printStatusLabel ?? '-'),
        ],
      ),
    );
  }
}

class _LinesTable extends StatelessWidget {
  final InvoiceDocument document;

  const _LinesTable({required this.document});

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      title: 'الأصناف',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in document.lines) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.itemName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${line.unitName ?? '-'}  ${line.display.quantity} x ${line.display.unitPrice}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text.rich(
                  PosFormatters.amountRich(
                    line.lineTotal,
                    amountStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.xl),
          ],
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  final InvoiceDocument document;

  const _Totals({required this.document});

  @override
  Widget build(BuildContext context) {
    final totals = document.totals;
    return AppPanel(
      title: 'الملخص',
      child: Column(
        children: [
          KeyValueRow(
            label: 'المجموع قبل الضريبة',
            value: '${totals.displaySubtotal} ر.س',
          ),
          KeyValueRow(
            label: 'الخصم',
            value: '${totals.displayDiscountTotal} ر.س',
          ),
          KeyValueRow(label: 'الضريبة', value: '${totals.displayTaxTotal} ر.س'),
          const Divider(),
          KeyValueRow(
            label: 'الإجمالي',
            value: '${totals.displayNetTotal} ر.س',
            strong: true,
          ),
          KeyValueRow(
            label: 'المدفوع',
            value: '${totals.displayPaidTotal} ر.س',
          ),
          KeyValueRow(
            label: 'الباقي',
            value: '${totals.displayChangeAmount} ر.س',
          ),
        ],
      ),
    );
  }
}

class _Payments extends StatelessWidget {
  final InvoiceDocument document;

  const _Payments({required this.document});

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      title: 'طرق الدفع',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final payment in document.payments)
            KeyValueRow(
              label: payment.referenceNo == null
                  ? payment.displayMethod
                  : '${payment.displayMethod} - مرجع ${payment.referenceNo}',
              value: '${payment.displayAmount} ر.س',
            ),
        ],
      ),
    );
  }
}

class _AuditPanel extends StatelessWidget {
  final InvoiceDocument document;

  const _AuditPanel({required this.document});

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      title: 'التدقيق',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyValueRow(
            label: 'التحقق',
            value: document.validationStatus ?? 'غير محدد',
          ),
          if (document.validationMessage?.isNotEmpty == true)
            KeyValueRow(label: 'ملاحظة', value: document.validationMessage!),
          if (document.auditHash?.isNotEmpty == true)
            SelectableText(
              'Hash: ${document.auditHash}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _PrintHistory extends ConsumerWidget {
  final String saleId;

  const _PrintHistory({required this.saleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(invoicePrintHistoryProvider(saleId));
    return history.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (rows) {
        if (rows.isEmpty) {
          return const AppPanel(child: Text('لا يوجد سجل طباعة بعد.'));
        }
        return AppPanel(
          title: 'سجل الطباعة',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final row in rows) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.isReprint
                            ? 'إعادة طباعة نسخة ${row.copyNumber}'
                            : 'طباعة أصلية',
                      ),
                    ),
                    AppStatusChip(
                      label: PrinterStatusPresenter.printJobStatusLabel(
                        row.status,
                      ),
                      color: PrinterStatusPresenter.printJobStatusColor(
                        row.status,
                      ),
                    ),
                  ],
                ),
                if (row.reprintReason?.isNotEmpty == true)
                  Text(
                    row.reprintReason!,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                if (row.failureReason?.isNotEmpty == true)
                  Text(
                    row.failureReason!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                const Divider(),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// WHY: Vertical label-value tile for info grids. Kept private because
/// the wider KeyValueRow covers the horizontal case. This is a specialized
/// layout for the invoice info grid only.
class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xxs),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
