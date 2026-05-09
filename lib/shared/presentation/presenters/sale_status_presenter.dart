import 'package:flutter/material.dart';
import 'package:pos_flutter/core/design_system/colors.dart';
import 'package:pos_flutter/core/l10n/app_localizations.dart';
import 'package:pos_flutter/shared/models/enums.dart';

abstract final class SaleStatusPresenter {
  static String label(String statusCode, AppLocalizations l10n) {
    if (statusCode == 'synced') return l10n.completed;
    return switch (SaleStatus.fromCode(statusCode)) {
      SaleStatus.completed => l10n.completed,
      SaleStatus.voided => l10n.voided,
      SaleStatus.refunded => l10n.returned,
      SaleStatus.draft => l10n.draft,
      null => statusCode,
    };
  }

  static Color color(String statusCode) {
    if (statusCode == 'synced') return AppColors.success;
    return switch (SaleStatus.fromCode(statusCode)) {
      SaleStatus.completed => AppColors.success,
      SaleStatus.voided => AppColors.voidColor,
      SaleStatus.refunded => AppColors.returnColor,
      SaleStatus.draft => AppColors.textSecondary,
      null => AppColors.textSecondary,
    };
  }

  static IconData icon(String statusCode) {
    if (statusCode == 'synced') return Icons.check_circle_outline;
    return switch (SaleStatus.fromCode(statusCode)) {
      SaleStatus.completed => Icons.check_circle_outline,
      SaleStatus.voided => Icons.cancel_outlined,
      SaleStatus.refunded => Icons.keyboard_return_outlined,
      SaleStatus.draft => Icons.edit_note,
      null => Icons.help_outline,
    };
  }

  static bool countsAsNetSale(String statusCode) {
    return statusCode == SaleStatus.completed.code || statusCode == 'synced';
  }

  static bool isVoidOrReturn(String statusCode) {
    return statusCode == SaleStatus.voided.code ||
        statusCode == SaleStatus.refunded.code;
  }
}
