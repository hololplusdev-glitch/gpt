import 'package:flutter/material.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/spacing.dart';

/// Centralized utility for showing snackbars.
/// Enforces consistent styling, durations, and behavior across the app.
///
/// Features:
/// - Dismiss current snackbar before showing new one (prevents stacking)
/// - Colored background with matching icon and text
/// - Rounded corners + floating behavior
/// - Uses design system tokens exclusively (SSOT)
abstract class AppSnackbar {
  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.check_circle_outline,
      backgroundColor: AppColors.successBg,
      accentColor: AppColors.success,
    );
  }

  static void showError(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.error_outline,
      backgroundColor: AppColors.errorBg,
      accentColor: AppColors.error,
      duration: const Duration(seconds: 5),
    );
  }

  static void showInfo(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.info_outline,
      backgroundColor: AppColors.infoBg,
      accentColor: AppColors.info,
    );
  }

  static void showWarning(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.warning_amber_rounded,
      backgroundColor: AppColors.warningBg,
      accentColor: AppColors.warning,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
    required Color accentColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Dismiss any currently showing snackbars
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: AppSpacing.paddingLg,
        padding: EdgeInsets.zero,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
        content: Container(
          padding: AppSpacing.paddingMd,
          decoration: BoxDecoration(
            borderRadius: AppSpacing.borderRadiusMd,
            // WHY: Left accent border matches AppInfoBanner pattern for
            // visual consistency across all notification types.
            border: Border(left: BorderSide(color: accentColor, width: 3.5)),
          ),
          child: Row(
            children: [
              Icon(icon, color: accentColor, size: 22),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        duration: duration,
      ),
    );
  }
}
