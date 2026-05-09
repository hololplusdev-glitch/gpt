import 'package:flutter/material.dart';
import 'package:pos_flutter/core/design_system/colors.dart';
import 'package:pos_flutter/core/l10n/app_localizations.dart';
import 'package:pos_flutter/shared/models/enums.dart';

abstract final class PrinterStatusPresenter {
  static PrinterRole? roleFromName(String? name) => PrinterRole.fromCode(name);

  static IconData roleIcon(PrinterRole? role) {
    return switch (role) {
      PrinterRole.kitchen => Icons.restaurant_outlined,
      PrinterRole.cashier => Icons.receipt_long_outlined,
      null => Icons.receipt_long_outlined,
    };
  }

  static String roleLabel(PrinterRole? role, AppLocalizations l10n) {
    return switch (role) {
      PrinterRole.cashier => l10n.cashierPrinter,
      PrinterRole.kitchen => l10n.kitchenPrinter,
      null => l10n.printer,
    };
  }

  static String printJobStatusLabel(String statusCode) {
    return switch (PrintJobStatus.fromCode(statusCode)) {
      PrintJobStatus.pending => 'Pending',
      PrintJobStatus.printing => 'Printing',
      PrintJobStatus.printed => 'Printed',
      PrintJobStatus.failed => 'Failed',
      PrintJobStatus.cancelled => 'Cancelled',
      null => statusCode,
    };
  }

  static Color printJobStatusColor(String statusCode) {
    return switch (PrintJobStatus.fromCode(statusCode)) {
      PrintJobStatus.printed => AppColors.success,
      PrintJobStatus.failed => AppColors.error,
      PrintJobStatus.cancelled => AppColors.error,
      PrintJobStatus.printing => AppColors.info,
      PrintJobStatus.pending => AppColors.warning,
      null => AppColors.warning,
    };
  }
}
