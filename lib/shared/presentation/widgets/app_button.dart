import 'package:flutter/material.dart';
import 'package:pos_flutter/core/design_system/colors.dart';
import 'package:pos_flutter/core/design_system/spacing.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_loading.dart';

enum AppButtonType { primary, secondary, outlined, text }

/// A unified button component enforcing the SSOT for interactions.
class AppButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;
  final AppButtonType type;
  final Color? customColor;

  const AppButton.primary({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.customColor,
  }) : type = AppButtonType.primary;

  const AppButton.secondary({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.customColor,
  }) : type = AppButtonType.secondary;

  const AppButton.outlined({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.customColor,
  }) : type = AppButtonType.outlined;

  const AppButton.text({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.customColor,
  }) : type = AppButtonType.text;

  // ---------------------------------------------------------------------------
  // Semantic factories — express intent instead of raw color
  // ---------------------------------------------------------------------------

  /// Destructive action (delete, void, reset). Red color, primary button style.
  const AppButton.danger({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
  }) : type = AppButtonType.primary,
       customColor = AppColors.error;

  /// Caution action (close shift, overwrite). Amber/warning color.
  const AppButton.warning({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
  }) : type = AppButtonType.primary,
       customColor = AppColors.warning;

  /// Positive confirmation (save, complete). Green/success color.
  const AppButton.success({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
  }) : type = AppButtonType.primary,
       customColor = AppColors.success;

  @override
  Widget build(BuildContext context) {
    final child = _ButtonContent(
      label: label,
      icon: icon,
      isLoading: isLoading,
    );

    switch (type) {
      case AppButtonType.primary:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: customColor != null
              ? ElevatedButton.styleFrom(backgroundColor: customColor)
              : null,
          child: child,
        );

      case AppButtonType.secondary:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: customColor ?? AppColors.secondary,
            foregroundColor: AppColors.onSecondary,
          ),
          child: child,
        );

      case AppButtonType.outlined:
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: customColor != null
              ? OutlinedButton.styleFrom(
                  foregroundColor: customColor,
                  side: BorderSide(color: customColor!),
                )
              : null,
          child: child,
        );

      case AppButtonType.text:
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          style: customColor != null
              ? TextButton.styleFrom(foregroundColor: customColor)
              : null,
          child: child,
        );
    }
  }
}

class _ButtonContent extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isLoading;

  const _ButtonContent({
    required this.label,
    required this.icon,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        width: AppSpacing.xl,
        height: AppSpacing.xl,
        child: AppLoading.small(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedWidth = constraints.hasBoundedWidth;

        if (icon == null) {
          return Text(
            label,
            maxLines: 1,
            overflow: hasBoundedWidth
                ? TextOverflow.ellipsis
                : TextOverflow.visible,
            softWrap: false,
            textAlign: TextAlign.center,
          );
        }

        if (hasBoundedWidth) {
          return Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }
}
