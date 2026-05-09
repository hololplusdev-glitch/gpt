import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pos_flutter/app/router.dart';
import 'package:pos_flutter/core/design_system/colors.dart';
import 'package:pos_flutter/core/design_system/layout.dart';
import 'package:pos_flutter/core/design_system/spacing.dart';
import 'package:pos_flutter/core/errors/app_exception.dart';
import 'package:pos_flutter/core/l10n/app_localizations.dart';
import 'package:pos_flutter/core/services/formatters/pos_formatters.dart';
import 'package:pos_flutter/core/services/invoices/invoice_document.dart';
import 'package:pos_flutter/core/services/invoices/invoice_output_coordinator.dart';
import 'package:pos_flutter/core/services/invoices/invoice_print_history_entry.dart';
import 'package:pos_flutter/features/auth/application/auth_notifier.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';
import 'package:pos_flutter/shared/presentation/presenters/printer_status_presenter.dart';
import 'package:pos_flutter/shared/presentation/presenters/sale_status_presenter.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_info_banner.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_panel.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_status_chip.dart';
import 'package:pos_flutter/shared/presentation/widgets/key_value_row.dart';
import 'package:pos_flutter/shared/presentation/utils/app_snackbar.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_button.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_loading.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_text_field.dart';
import 'package:pos_flutter/shared/presentation/dialogs/app_dialog.dart';

final invoiceDocumentProvider = FutureProvider.autoDispose
    .family<InvoiceDocument, String>((ref, id) {
      return ref
          .watch(invoiceOutputCoordinatorProvider)
          .getOrCreateOriginal(id);
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
      appBar: AppBar(
        title: Text(l10n.receipt),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(invoiceDocumentProvider(saleId)),
          ),
        ],
      ),
      body: documentAsync.when(
        loading: () => const AppLoading(),
        error: (error, _) => Center(
          child: Padding(
            padding: AppSpacing.paddingLg,
            child: AppInfoBanner.error(message: ErrorMapper.userMessage(error)),
          ),
        ),
        data: (document) => _InvoicePreview(document: document),
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
      color: AppColors.surface,
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
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(document.branch.name),
                if (document.branch.taxNumber?.isNotEmpty == true)
                  Text('Tax No: ${document.branch.taxNumber}'),
                if (document.branch.address?.isNotEmpty == true)
                  Text(document.branch.address!),
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
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SelectableText(document.localInvoiceNo),
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
          label: 'Save PDF',
        ),
        AppButton.outlined(
          onPressed: () => _share(context, ref),
          icon: Icons.share,
          label: 'Share',
        ),
        AppButton.outlined(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: document.localInvoiceNo));
            AppSnackbar.showSuccess(context, 'Invoice number copied');
          },
          icon: Icons.copy,
          label: 'Copy number',
        ),
        AppButton.text(
          onPressed: () => context.go(AppRoutes.cashier),
          icon: Icons.point_of_sale,
          label: 'New sale',
        ),
      ],
    );
  }

  Future<void> _print(
    BuildContext context,
    WidgetRef ref, {
    required bool reprint,
  }) async {
    final output = ref.read(invoiceOutputCoordinatorProvider);
    final auth = ref.read(authProvider).session;
    final reason = reprint ? await _askReprintReason(context) : null;
    if (reprint && reason == null) return;
    final result = reprint
        ? await output.reprint(
            document.saleId,
            reason: reason,
            createdBy: auth?.userId ?? document.cashier.userId,
          )
        : await output.printOriginal(
            document.saleId,
            createdBy: auth?.userId ?? document.cashier.userId,
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

  Future<String?> _askReprintReason(BuildContext context) async {
    final controller = TextEditingController();
    final result = await AppDialog.show<String>(
      context: context,
      dialog: AppDialog(
        title: 'Reprint reason',
        content: AppTextField(
          controller: controller,
          autofocus: true,
          labelText: 'Reason (optional)',
          hintText: 'Customer copy, printer failure...',
        ),
        cancelLabel: 'Cancel',
        confirmLabel: 'Reprint',
        onConfirm: () => Navigator.of(context).pop(controller.text.trim()),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _savePdf(BuildContext context, WidgetRef ref) async {
    final file = await ref
        .read(invoiceOutputCoordinatorProvider)
        .savePdf(document.saleId);
    if (context.mounted) {
      AppSnackbar.showSuccess(context, 'Saved PDF: ${file.path}');
    }
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(invoiceOutputCoordinatorProvider)
          .sharePdf(document.saleId);
    } catch (error) {
      if (context.mounted) {
        AppSnackbar.showError(context, 'Share failed.');
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
          _InfoTile('Date', PosFormatters.dateTime(document.invoiceDateTime)),
          _InfoTile('Cashier', document.cashier.name),
          _InfoTile('Terminal', document.terminal.terminalId),
          _InfoTile('Machine', document.terminal.machineNumber ?? '-'),
          _InfoTile('Customer', document.customer?.name ?? '-'),
          _InfoTile('Print', document.printStatusLabel ?? '-'),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Items',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
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
                Text(
                  line.display.lineTotal,
                  style: const TextStyle(fontWeight: FontWeight.w700),
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
      child: Column(
        children: [
          KeyValueRow(label: 'Subtotal', value: totals.displaySubtotal),
          KeyValueRow(label: 'Discount', value: totals.displayDiscountTotal),
          KeyValueRow(label: 'VAT/Tax', value: totals.displayTaxTotal),
          const Divider(),
          KeyValueRow(
            label: 'Net total',
            value: totals.displayNetTotal,
            strong: true,
          ),
          KeyValueRow(label: 'Paid', value: totals.displayPaidTotal),
          KeyValueRow(label: 'Change', value: totals.displayChangeAmount),
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
      title: 'Payments',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final payment in document.payments)
            KeyValueRow(
              label: payment.referenceNo == null
                  ? payment.displayMethod
                  : '${payment.displayMethod} - Ref ${payment.referenceNo}',
              value: payment.displayAmount,
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
      title: 'Audit',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyValueRow(
            label: 'Validation',
            value: document.validationStatus ?? 'unknown',
          ),
          if (document.validationMessage?.isNotEmpty == true)
            KeyValueRow(
              label: 'Validation note',
              value: document.validationMessage!,
            ),
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
          return const AppPanel(child: Text('No print history yet.'));
        }
        return AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Print history',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final row in rows) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.isReprint
                            ? 'Reprint copy ${row.copyNumber}'
                            : 'Original print',
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
