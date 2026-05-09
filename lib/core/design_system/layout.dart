// core/design_system/layout.dart
// WHY: Centralized layout tokens (breakpoints, component sizes, content constraints)
// so screens use a single source of truth instead of scattered magic numbers.

import 'package:flutter/widgets.dart';

/// Responsive breakpoints for layout decisions.
///
/// These replace hardcoded width checks (e.g., `maxWidth < 600`)
/// scattered across feature screens.
abstract final class AppBreakpoints {
  /// Mobile portrait threshold.
  static const double compact = 560;

  /// Tablet / narrow desktop.
  static const double medium = 820;

  /// Desktop / wide layouts.
  static const double expanded = 1100;

  /// WHY: Convenience queries — avoids `MediaQuery.sizeOf(context).width`
  /// boilerplate in every screen that needs responsive branching.
  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;

  static bool isMedium(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= compact &&
      MediaQuery.sizeOf(context).width < expanded;

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= expanded;
}

/// Maximum content widths for centering layouts.
///
/// Replaces hardcoded `BoxConstraints(maxWidth: 920)` and friends
/// scattered across settings, sync monitor, and invoice screens.
abstract final class AppContentWidth {
  /// Narrow forms (login, shift open/close).
  static const double narrow = 560;

  /// Standard settings / detail pages.
  static const double standard = 820;

  /// Wide data screens (history, sync monitor, devices).
  static const double wide = 1100;
}

/// Standard heights for interactive components.
///
/// WHY: Button/input height consistency — avoids `SizedBox(height: 56)`
/// hardcoded throughout feature screens.
abstract final class AppComponentSizes {
  /// Compact buttons (filter bars, inline actions).
  static const double buttonHeightSm = 36;

  /// Standard buttons and inputs.
  static const double buttonHeightMd = 48;

  /// Prominent CTAs (Pay, Open Shift).
  static const double buttonHeightLg = 56;

  /// Touch targets minimum (accessibility).
  static const double touchTarget = 44;

  /// Standard icon size in panels.
  static const double iconMd = 20;

  /// Large icon size for hero sections.
  static const double iconLg = 28;
}
