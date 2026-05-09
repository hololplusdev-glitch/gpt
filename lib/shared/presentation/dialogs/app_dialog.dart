import 'package:flutter/material.dart';
import 'package:pos_flutter/core/design_system/colors.dart';
import 'package:pos_flutter/core/design_system/spacing.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_button.dart';

/// A unified dialog component to replace manual showDialog + AlertDialog calls.
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

  static Future<T?> show<T>({
    required BuildContext context,
    required AppDialog dialog,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => dialog,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusXl),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: AppSpacing.paddingXl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    color: confirmColor ?? AppColors.primary,
                    size: 28,
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
            DefaultTextStyle(
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: AppColors.textSecondary),
              child: content,
            ),
            const SizedBox(height: AppSpacing.xl),
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
