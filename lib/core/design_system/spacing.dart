// core/design_system/spacing.dart
// WHY: Consistent spacing scale prevents random padding/margin values.
// Based on a 4px grid system for pixel-perfect alignment across all screens.

import 'package:flutter/material.dart';

/// Kasir Pro spacing scale — based on a 4px base unit.
///
/// All spacing, padding, margin, and border radius values must come from
/// this file. Ad-hoc numeric values in widgets are a code smell.
abstract final class AppSpacing {
  // ─── Spacing scale (4px grid) ──────────────────────────
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double jumbo = 48;
  static const double mega = 64;

  // ─── Premade EdgeInsets ────────────────────────────────
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);
  static const EdgeInsets paddingXxl = EdgeInsets.all(xxl);

  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);

  // ─── Border radius ────────────────────────────────────
  static const double radiusXs = 4;
  static const double radiusSm = 6;
  static const double radiusMd = 10;
  static const double radiusLg = 14;
  static const double radiusXl = 18;
  static const double radiusXxl = 24;
  static const double radiusRound = 100;

  static final BorderRadius borderRadiusXs = BorderRadius.circular(radiusXs);
  static final BorderRadius borderRadiusSm = BorderRadius.circular(radiusSm);
  static final BorderRadius borderRadiusMd = BorderRadius.circular(radiusMd);
  static final BorderRadius borderRadiusLg = BorderRadius.circular(radiusLg);
  static final BorderRadius borderRadiusXl = BorderRadius.circular(radiusXl);
  static final BorderRadius borderRadiusXxl = BorderRadius.circular(radiusXxl);

  // ─── Elevation presets (box shadow consistency) ────────
  static const List<BoxShadow> shadowSm = [
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 8, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x050F172A), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> shadowLg = [
    BoxShadow(color: Color(0x140F172A), blurRadius: 16, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x080F172A), blurRadius: 4, offset: Offset(0, 2)),
  ];

  // ─── Animation durations ──────────────────────────────
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationMd = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);

  // ─── Curves ───────────────────────────────────────────
  static const Curve curveDefault = Curves.easeOutCubic;
  static const Curve curveSpring = Curves.elasticOut;
}
