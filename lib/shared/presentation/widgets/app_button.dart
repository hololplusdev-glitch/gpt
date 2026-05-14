import 'package:flutter/material.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/spacing.dart';
import 'package:holol_POS/shared/presentation/widgets/app_loading.dart';

enum AppButtonType { primary, secondary, outlined, text }

/// A unified button component enforcing the SSOT for interactions.
///
/// Wraps Material buttons with a subtle scale-on-press micro-animation
/// for tactile feedback. All visual properties are derived from [AppTheme].
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
    final isEnabled = onPressed != null && !isLoading;
    final child = _ButtonContent(
      label: label,
      icon: icon,
      isLoading: isLoading,
      type: type,
    );

    Widget button;

    switch (type) {
      case AppButtonType.primary:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: customColor != null
              ? ElevatedButton.styleFrom(backgroundColor: customColor)
              : null,
          child: child,
        );

      case AppButtonType.secondary:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: customColor ?? AppColors.secondary,
            foregroundColor: AppColors.onSecondary,
          ),
          child: child,
        );

      case AppButtonType.outlined:
        button = OutlinedButton(
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
        button = TextButton(
          onPressed: isLoading ? null : onPressed,
          style: customColor != null
              ? TextButton.styleFrom(foregroundColor: customColor)
              : null,
          child: child,
        );
    }

    // WHY: Scale-on-press micro-animation gives premium tactile feedback.
    // Disabled/loading buttons don't animate.
    if (!isEnabled) return button;
    return _PressableWrapper(child: button);
  }
}

/// Wraps a widget to provide a subtle scale-down on press.
class _PressableWrapper extends StatefulWidget {
  final Widget child;

  const _PressableWrapper({required this.child});

  @override
  State<_PressableWrapper> createState() => _PressableWrapperState();
}

class _PressableWrapperState extends State<_PressableWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppSpacing.durationFast,
      lowerBound: 0,
      upperBound: 1,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: AppSpacing.curveSnap),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(scale: _scale.value, child: child);
        },
        child: widget.child,
      ),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isLoading;
  final AppButtonType type;

  const _ButtonContent({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        width: AppSpacing.xl,
        height: AppSpacing.xl,
        child: AppLoading.small(
          centered: false,
          color: type == AppButtonType.primary
              ? AppColors.onPrimary.withValues(alpha: 0.7)
              : null,
        ),
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
