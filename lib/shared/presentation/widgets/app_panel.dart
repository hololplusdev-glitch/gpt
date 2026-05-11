// shared/presentation/widgets/app_panel.dart
// WHY: Unified surface container, replacing:
//   - invoice_preview_screen._Panel (Container + surface + padding)
//   - Various ad-hoc Container wrappers with surface color and padding.
//
// Provides consistent visual treatment for content panels across the app.

import 'package:flutter/material.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/spacing.dart';

/// A simple surface panel with consistent padding and optional title.
///
/// Use for grouping related content in detail/preview screens.
/// For sections with icon headers and actions, prefer [AppSectionCard].
class AppPanel extends StatelessWidget {
  final Widget child;

  /// Optional title displayed above the child content.
  final String? title;

  /// Padding inside the panel. Defaults to [AppSpacing.paddingLg].
  final EdgeInsetsGeometry padding;

  /// Background color. Defaults to [AppColors.surface].
  final Color color;

  const AppPanel({
    super.key,
    required this.child,
    this.title,
    this.padding = AppSpacing.paddingLg,
    this.color = AppColors.surface,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      color: color,
      child: title == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                child,
              ],
            ),
    );
  }
}
