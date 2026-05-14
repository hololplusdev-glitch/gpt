import 'package:flutter/material.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/spacing.dart';

enum AppBannerType { info, success, warning, error }

/// A unified info/warning/error banner enforcing SSOT for contextual messages.
///
/// Features a strong left accent border for quick visual identification
/// of message type — a modern pattern seen in premium admin UIs.
class AppInfoBanner extends StatelessWidget {
  final String message;
  final AppBannerType type;
  final IconData? icon;

  const AppInfoBanner({
    super.key,
    required this.message,
    this.type = AppBannerType.info,
    this.icon,
  });

  const AppInfoBanner.error({super.key, required this.message, this.icon})
    : type = AppBannerType.error;

  const AppInfoBanner.success({super.key, required this.message, this.icon})
    : type = AppBannerType.success;

  const AppInfoBanner.warning({super.key, required this.message, this.icon})
    : type = AppBannerType.warning;

  const AppInfoBanner.info({super.key, required this.message, this.icon})
    : type = AppBannerType.info;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      AppBannerType.info => AppColors.info,
      AppBannerType.success => AppColors.success,
      AppBannerType.warning => AppColors.warning,
      AppBannerType.error => AppColors.error,
    };
    final bgColor = switch (type) {
      AppBannerType.info => AppColors.infoBg,
      AppBannerType.success => AppColors.successBg,
      AppBannerType.warning => AppColors.warningBg,
      AppBannerType.error => AppColors.errorBg,
    };
    final effectiveIcon =
        icon ??
        switch (type) {
          AppBannerType.info => Icons.info_outline,
          AppBannerType.success => Icons.check_circle_outline,
          AppBannerType.warning => Icons.warning_amber_outlined,
          AppBannerType.error => Icons.error_outline,
        };

    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppSpacing.borderRadiusMd,
        // WHY: Left accent border is a premium visual pattern that
        // makes banner type immediately scannable.
        border: Border(
          left: BorderSide(color: color, width: 3.5),
          top: BorderSide(color: color.withValues(alpha: 0.15)),
          right: BorderSide(color: color.withValues(alpha: 0.15)),
          bottom: BorderSide(color: color.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(effectiveIcon, color: color, size: AppSpacing.xl),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
