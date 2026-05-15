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
import 'package:holol_POS/shared/presentation/widgets/app_button.dart';
import 'package:holol_POS/shared/presentation/widgets/app_loading.dart';
import 'package:holol_POS/shared/refactor/pos_ui_widgets.dart';
import 'package:holol_POS/shared/presentation/dialogs/app_dialog.dart';

/// Shows a thermal receipt image preview in a dialog.
///
/// [saleId] is used to build the InvoiceDocument via [InvoiceOutputActions].
/// The receipt PNG is rendered through [InvoiceOutputActions].
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
      final pngBytes = await widget.outputActions.renderOriginalReceiptPng(
        widget.saleId,
        paperWidthMm: 80,
      );

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
    return AppDialog(
      title: 'معاينة الفاتورة',
      icon: Icons.receipt_long,
      maxWidth: 420,
      onClose: () => Navigator.of(context).pop(),
      contentPadding: EdgeInsets.zero,
      content: _buildBody(),
      footer: Row(
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
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xxxl),
        child: AppLoading(),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.error),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: AppReceiptImageFrame(bytes: _pngBytes!),
    );
  }
}
