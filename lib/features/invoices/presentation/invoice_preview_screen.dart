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
import 'package:holol_POS/core/services/invoices/invoice_document.dart';
import 'package:holol_POS/core/services/invoices/invoice_output_actions.dart';
import 'package:holol_POS/core/services/invoices/invoice_print_history_entry.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
import 'package:holol_POS/shared/presentation/presenters/printer_status_presenter.dart';
import 'package:holol_POS/shared/presentation/widgets/app_info_banner.dart';
import 'package:holol_POS/shared/presentation/widgets/app_panel.dart';
import 'package:holol_POS/shared/presentation/widgets/key_value_row.dart';
import 'package:holol_POS/shared/presentation/utils/app_snackbar.dart';
import 'package:holol_POS/shared/presentation/widgets/app_button.dart';
import 'package:holol_POS/shared/presentation/widgets/app_loading.dart';

import 'package:holol_POS/shared/refactor/pos_ui_widgets.dart';
import 'package:holol_POS/shared/presentation/widgets/app_scaffold.dart';

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
    return AppScaffold(
      title: l10n.receipt,
      icon: Icons.receipt_long,
      onBack: () => Navigator.of(context).pop(),
      actions: [
        IconButton(
          tooltip: l10n.refresh,
          icon: const Icon(Icons.refresh, color: AppColors.onPrimary),
          onPressed: () => ref.invalidate(invoiceDocumentProvider(saleId)),
        ),
      ],
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
            _UnifiedReceiptImage(document: document),
            const SizedBox(height: AppSpacing.md),
            _Actions(document: document),
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

class _UnifiedReceiptImage extends ConsumerWidget {
  final InvoiceDocument document;

  const _UnifiedReceiptImage({required this.document});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outputActions = ref.read(invoiceOutputActionsProvider);

    return AppPanel(
      child: FutureBuilder<Uint8List>(
        future: outputActions.renderReceiptPng(document, paperWidthMm: 80),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: AppLoading(),
            );
          }

          if (snapshot.hasError || snapshot.data == null) {
            return AppInfoBanner.error(
              message: 'تعذر إنشاء معاينة الفاتورة الموحدة.',
            );
          }

          return AppReceiptImageFrame(bytes: snapshot.data!);
        },
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

    return AppActionsWrap(
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
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.showError(context, 'فشلت المشاركة.');
      }
    }
  }
}

class _AuditPanel extends StatelessWidget {
  final InvoiceDocument document;

  const _AuditPanel({required this.document});

  @override
  Widget build(BuildContext context) {
    return AppKeyValuePanel(
      title: 'التدقيق',
      rows: [
        KeyValueRow(
          label: 'التحقق',
          value: document.validationStatus ?? 'غير محدد',
        ),
        if (document.validationMessage?.isNotEmpty == true)
          KeyValueRow(label: 'ملاحظة', value: document.validationMessage!),
      ],
      extra: document.auditHash?.isNotEmpty == true
          ? SelectableText(
              'Hash: ${document.auditHash}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            )
          : null,
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
        return AppStatusHistoryList(
          title: 'سجل الطباعة',
          empty: const Text('لا يوجد سجل طباعة بعد.'),
          entries: [
            for (final row in rows)
              AppStatusHistoryEntry(
                title: row.isReprint
                    ? 'إعادة طباعة نسخة ${row.copyNumber}'
                    : 'طباعة أصلية',
                statusLabel: PrinterStatusPresenter.printJobStatusLabel(
                  row.status,
                ),
                statusColor: PrinterStatusPresenter.printJobStatusColor(
                  row.status,
                ),
                note: row.reprintReason?.isNotEmpty == true
                    ? row.reprintReason
                    : null,
                error: row.failureReason?.isNotEmpty == true
                    ? row.failureReason
                    : null,
              ),
          ],
        );
      },
    );
  }
}

/// WHY: Vertical label-value tile for info grids. Kept private because
/// the wider KeyValueRow covers the horizontal case. This is a specialized
/// layout for the invoice info grid only.
