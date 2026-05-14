// features/cashier/presentation/dialogs/thermal_receipt_preview_dialog.dart
// WHY: After completing a sale, show a quick thermal-receipt-style preview
// in a dialog so the cashier can verify the receipt without leaving the POS.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:holol_POS/app/router.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/spacing.dart';
import 'package:holol_POS/core/services/invoices/invoice_output_actions.dart';
import 'package:holol_POS/core/services/receipts/receipt_raster_renderer.dart';
import 'package:holol_POS/shared/presentation/widgets/app_button.dart';
import 'package:holol_POS/shared/presentation/widgets/app_loading.dart';
import 'package:holol_POS/shared/refactor/pos_ui_widgets.dart';

/// Shows a thermal receipt image preview in a dialog.
///
/// [saleId] is used to build the InvoiceDocument via [InvoiceOutputActions].
/// The receipt is rendered as a PNG image using [ReceiptRasterRenderer].
Future<void> showThermalReceiptPreview({
  required BuildContext context,
  required String saleId,
  required InvoiceOutputActions outputActions,
}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) =>
        _ThermalReceiptDialog(saleId: saleId, outputActions: outputActions),
  );
}

class _ThermalReceiptDialog extends StatefulWidget {
  final String saleId;
  final InvoiceOutputActions outputActions;

  const _ThermalReceiptDialog({
    required this.saleId,
    required this.outputActions,
  });

  @override
  State<_ThermalReceiptDialog> createState() => _ThermalReceiptDialogState();
}

class _ThermalReceiptDialogState extends State<_ThermalReceiptDialog> {
  Uint8List? _pngBytes;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _renderReceipt();
  }

  Future<void> _renderReceipt() async {
    try {
      final document = await widget.outputActions.getOrCreateOriginal(
        widget.saleId,
      );
      final renderer = const ReceiptRasterRenderer();
      // Use 80mm paper for a good preview resolution
      final pngBytes = await renderer.renderPng(document, paperWidthMm: 80);

      if (!mounted) return;
      setState(() {
        _pngBytes = pngBytes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppSpacing.borderRadiusLg,
          boxShadow: AppSpacing.shadowLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppDialogHeader(
              title: 'معاينة الفاتورة',
              icon: Icons.receipt_long,
              onClose: () => Navigator.of(context).pop(),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppSpacing.lg),
                topRight: Radius.circular(AppSpacing.lg),
              ),
            ),
            // ── Body ──
            Flexible(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.xxxl),
                      child: AppLoading(),
                    )
                  : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.lg,
                      ),
                      child: AppReceiptImageFrame(bytes: _pngBytes!),
                    ),
            ),
            // ── Actions ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton.outlined(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icons.check,
                      label: 'إغلاق',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton.primary(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push(AppRoutes.invoicePath(widget.saleId));
                      },
                      icon: Icons.open_in_new,
                      label: 'التفاصيل الكاملة',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
