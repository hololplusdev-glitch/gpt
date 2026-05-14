import 'package:flutter/material.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/spacing.dart';
import 'package:holol_POS/shared/presentation/widgets/app_button.dart';

/// A unified dialog component to replace manual showDialog + AlertDialog calls.
///
/// Features:
/// - Consistent border radius, padding, and icon treatment (SSOT)
/// - Icon is rendered inside a colored circle background for visual weight
/// - Animated entrance via [AppDialog.show] (scale + fade)
/// - Pre-built factories for common patterns: warning, error, confirm
class AppDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final String? confirmLabel;
  final String? cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final Color? confirmColor;
  final IconData? icon;
  final List<Widget>? actions;

  final bool isConfirmLoading;
  final bool isConfirmDisabled;

  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmLabel,
    this.cancelLabel,
    this.onConfirm,
    this.onCancel,
    this.confirmColor,
    this.icon,
    this.actions,
    this.isConfirmLoading = false,
    this.isConfirmDisabled = false,
  });

  /// Pre-built factory for a Warning/Delete dialog
  factory AppDialog.warning({
    Key? key,
    required String title,
    required Widget content,
    required String confirmLabel,
    String? cancelLabel,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool isConfirmLoading = false,
  }) {
    return AppDialog(
      key: key,
      title: title,
      content: content,
      icon: Icons.warning_amber_rounded,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      onConfirm: onConfirm,
      onCancel: onCancel,
      confirmColor: AppColors.error,
      isConfirmLoading: isConfirmLoading,
    );
  }

  /// Pre-built factory for an Error dialog
  factory AppDialog.error({
    Key? key,
    required String title,
    required Widget content,
    String? cancelLabel,
  }) {
    return AppDialog(
      key: key,
      title: title,
      content: content,
      icon: Icons.error_outline,
      cancelLabel: cancelLabel,
    );
  }

  /// Pre-built factory for a Confirmation dialog with success styling
  factory AppDialog.confirm({
    Key? key,
    required String title,
    required Widget content,
    required String confirmLabel,
    String? cancelLabel,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool isConfirmLoading = false,
  }) {
    return AppDialog(
      key: key,
      title: title,
      content: content,
      icon: Icons.help_outline,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      onConfirm: onConfirm,
      onCancel: onCancel,
      isConfirmLoading: isConfirmLoading,
    );
  }

  /// Shows the dialog with an animated entrance (scale + fade).
  static Future<T?> show<T>({
    required BuildContext context,
    required AppDialog dialog,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: AppSpacing.durationMd,
      pageBuilder: (context, animation, secondaryAnimation) => dialog,
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: AppSpacing.curveBounce,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(opacity: curvedAnimation, child: child),
        );
      },
    );
  }

  /// The accent color for the icon — derived from confirmColor or primary.
  Color get _accentColor => confirmColor ?? AppColors.primary;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusXl),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: AppSpacing.paddingXl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Icon + Title row ────────────────────────
            Row(
              children: [
                if (icon != null) ...[
                  // WHY: Colored circle background gives the icon visual weight
                  // and makes dialog intent immediately obvious.
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: _accentColor, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // ─── Content ─────────────────────────────────
            DefaultTextStyle(
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              child: content,
            ),
            const SizedBox(height: AppSpacing.xl),

            // ─── Actions ─────────────────────────────────
            if (actions != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions!
                    .map(
                      (w) => Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.md),
                        child: w,
                      ),
                    )
                    .toList(),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (cancelLabel != null) ...[
                    Expanded(
                      child: AppButton.text(
                        label: cancelLabel!,
                        onPressed:
                            onCancel ?? () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  if (confirmLabel != null)
                    Expanded(
                      child: AppButton.primary(
                        label: confirmLabel!,
                        onPressed: isConfirmDisabled
                            ? null
                            : (onConfirm ??
                                  () => Navigator.of(context).pop(true)),
                        customColor: confirmColor,
                        isLoading: isConfirmLoading,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
