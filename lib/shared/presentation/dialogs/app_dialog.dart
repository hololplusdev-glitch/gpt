import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/layout.dart';
import 'package:holol_POS/core/design_system/spacing.dart';
import 'package:holol_POS/shared/presentation/widgets/app_button.dart';
import 'package:holol_POS/shared/presentation/widgets/app_loading.dart';

/// Unified dialog surface for the whole app.
///
/// This is the SSOT for dialog layout, header, scrolling, footer, sizing,
/// and loading overlay. Feature files should not build `Dialog + Container`
/// frames manually; they should pass content into this component.
class AppDialog extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget content;
  final String? confirmLabel;
  final String? cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final Color? confirmColor;
  final IconData? icon;
  final List<Widget>? actions;
  final Widget? footer;
  final Widget? headerTrailing;
  final VoidCallback? onClose;
  final bool isConfirmLoading;
  final bool isConfirmDisabled;
  final bool loading;
  final bool scrollable;
  final bool fullscreenOnCompact;
  final double maxWidth;
  final double? maxHeight;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? headerPadding;
  final EdgeInsetsGeometry? footerPadding;
  final EdgeInsetsGeometry? insetPadding;
  final CrossAxisAlignment contentCrossAxisAlignment;

  const AppDialog({
    super.key,
    required this.title,
    this.subtitle,
    required this.content,
    this.confirmLabel,
    this.cancelLabel,
    this.onConfirm,
    this.onCancel,
    this.confirmColor,
    this.icon,
    this.actions,
    this.footer,
    this.headerTrailing,
    this.onClose,
    this.isConfirmLoading = false,
    this.isConfirmDisabled = false,
    this.loading = false,
    this.scrollable = false,
    this.fullscreenOnCompact = false,
    this.maxWidth = 420,
    this.maxHeight,
    this.contentPadding,
    this.headerPadding,
    this.footerPadding,
    this.insetPadding,
    this.contentCrossAxisAlignment = CrossAxisAlignment.stretch,
  });

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

  Color get _accentColor => confirmColor ?? AppColors.primary;

  bool get _hasFooter =>
      footer != null ||
      actions != null ||
      cancelLabel != null ||
      confirmLabel != null;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isFullscreen =
        fullscreenOnCompact && size.width < AppBreakpoints.compact;

    final effectiveMaxHeight = isFullscreen
        ? size.height
        : math
              .min(
                maxHeight ?? (size.height - (AppSpacing.xxl * 2)).toDouble(),
                size.height,
              )
              .toDouble();

    final effectiveInsetGeometry =
        insetPadding ?? (isFullscreen ? EdgeInsets.zero : AppSpacing.paddingLg);

    final effectiveInset = effectiveInsetGeometry.resolve(
      Directionality.of(context),
    );

    final effectiveRadius = isFullscreen
        ? BorderRadius.zero
        : AppSpacing.borderRadiusLg;

    final effectiveWidth = isFullscreen
        ? size.width
        : math
              .min(
                maxWidth,
                math.max(0.0, size.width - effectiveInset.horizontal),
              )
              .toDouble();

    final dialogChild = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: effectiveWidth,
        maxHeight: effectiveMaxHeight,
      ),
      child: SizedBox(
        width: effectiveWidth,
        height: isFullscreen ? size.height : null,
        child: ClipRRect(
          borderRadius: effectiveRadius,
          child: Material(
            color: AppColors.surface,
            child: Stack(
              children: [
                Column(
                  mainAxisSize: isFullscreen
                      ? MainAxisSize.max
                      : MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AppDialogTitleBar(
                      title: title,
                      subtitle: subtitle,
                      icon: icon,
                      accentColor: _accentColor,
                      trailing: headerTrailing,
                      onClose: onClose,
                      padding: headerPadding,
                    ),
                    Flexible(child: _content(context)),
                    if (_hasFooter) _footer(context),
                  ],
                ),
                if (loading)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.08),
                      child: const AppLoading(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return Dialog(
      insetPadding: effectiveInset,
      backgroundColor: Colors.transparent,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: dialogChild,
    );
  }

  Widget _content(BuildContext context) {
    final effectivePadding = contentPadding ?? AppSpacing.paddingXl;

    final body = DefaultTextStyle(
      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
        color: AppColors.textSecondary,
        height: 1.5,
      ),
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: contentCrossAxisAlignment,
          children: [content],
        ),
      ),
    );

    if (scrollable) {
      return SingleChildScrollView(padding: effectivePadding, child: body);
    }

    return Padding(padding: effectivePadding, child: body);
  }

  Widget _footer(BuildContext context) {
    final child = footer ?? _defaultActions(context);

    return Container(
      width: double.infinity,
      padding: footerPadding ?? AppSpacing.paddingLg,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: child,
    );
  }

  Widget _defaultActions(BuildContext context) {
    if (actions != null) {
      return Wrap(
        alignment: WrapAlignment.end,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: actions!,
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (cancelLabel != null) ...[
          Expanded(
            child: AppButton.text(
              label: cancelLabel!,
              onPressed: onCancel ?? () => Navigator.of(context).pop(false),
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
                  : (onConfirm ?? () => Navigator.of(context).pop(true)),
              customColor: confirmColor,
              isLoading: isConfirmLoading,
            ),
          ),
      ],
    );
  }
}

class _AppDialogTitleBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color accentColor;
  final Widget? trailing;
  final VoidCallback? onClose;
  final EdgeInsetsGeometry? padding;

  const _AppDialogTitleBar({
    required this.title,
    this.subtitle,
    this.icon,
    required this.accentColor,
    this.trailing,
    this.onClose,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? AppSpacing.paddingLg,
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        boxShadow: AppSpacing.shadowSm,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: AppComponentSizes.touchTarget,
              height: AppComponentSizes.touchTarget,
              decoration: BoxDecoration(
                color: AppColors.onPrimary.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.onPrimary, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onPrimary.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.md),
            DefaultTextStyle.merge(
              style: const TextStyle(color: AppColors.onPrimary),
              child: trailing!,
            ),
          ],
          if (onClose != null) ...[
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: onClose,
              icon: const Icon(Icons.close, color: AppColors.onPrimary),
            ),
          ],
        ],
      ),
    );
  }
}
