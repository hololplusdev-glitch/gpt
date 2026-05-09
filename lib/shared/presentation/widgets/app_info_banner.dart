import 'package:flutter/material.dart';
import 'package:pos_flutter/core/design_system/colors.dart';
import 'package:pos_flutter/core/design_system/spacing.dart';

enum AppBannerType { info, success, warning, error }

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
        color: color.withValues(alpha: 0.1),
        borderRadius: AppSpacing.borderRadiusSm,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(effectiveIcon, color: color, size: AppSpacing.xl),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
