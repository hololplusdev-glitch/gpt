// core/design_system/colors.dart
// WHY: Centralized color palette prevents ad-hoc color usage in widgets.
// Designed with a modern, premium aesthetic — deep navy primary with
// vibrant emerald accents for a sophisticated retail experience.

import 'package:flutter/material.dart';

/// Kasir Pro application color palette.
///
/// Curated for a premium feel with high-contrast readability
/// in retail environments with varying lighting conditions.
/// Uses HSL-tuned colors instead of generic Material defaults.
abstract final class AppColors {
  // ─── Primary (Deep Slate Navy — modern, premium, authoritative) ─────
  static const Color primary = Color(0xFF0F172A);
  static const Color primaryLight = Color(0xFF1E293B);
  static const Color primaryDark = Color(0xFF020617);
  static const Color onPrimary = Color(0xFFF8FAFC);

  // ─── Secondary (Vibrant Emerald — growth, success, action) ─────────
  static const Color secondary = Color(0xFF059669);
  static const Color secondaryLight = Color(0xFF34D399);
  static const Color secondaryDark = Color(0xFF047857);
  static const Color onSecondary = Colors.white;

  // ─── Accent (Royal Violet — premium highlights, badges) ────────────
  static const Color accent = Color(0xFF7C3AED);
  static const Color accentLight = Color(0xFFA78BFA);
  static const Color onAccent = Colors.white;

  // ─── Brand Gradient endpoints (for headers, buttons, splash) ───────
  static const Color gradientStart = Color(0xFF0F172A);
  static const Color gradientMid = Color(0xFF1E3A5F);
  static const Color gradientEnd = Color(0xFF059669);

  // ─── Gradient presets (SSOT for gradient usage) ────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    colors: [gradientStart, gradientMid, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Status colors (tuned for clarity) ─────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorBg = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoBg = Color(0xFFDBEAFE);

  // ─── Surface / Background (warm neutral tones) ─────────────────────
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  static const Color cardSurface = Colors.white;
  static const Color shadow = Color(0x1A0F172A);
  static const Color shadowMd = Color(0x290F172A);

  // ─── Glassmorphism / Frosted tokens ────────────────────────────────
  static const Color glassWhite = Color(0x99FFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color glassOverlay = Color(0x0DFFFFFF);

  // ─── Shimmer / Loading animation tokens ────────────────────────────
  static const Color shimmerBase = Color(0xFFE2E8F0);
  static const Color shimmerHighlight = Color(0xFFF8FAFC);

  // ─── Text (balanced contrast hierarchy) ────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textHint = Color(0xFF94A3B8);
  static const Color textOnDark = Color(0xFFF8FAFC);
  static const Color textDisabled = Color(0xFFCBD5E1);

  // ─── Borders / Dividers ────────────────────────────────────────────
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);
  static const Color divider = Color(0xFFF1F5F9);

  // ─── Cart / Sale specific ───────────────────────────────────
  static const Color cartBackground = Color(0xFFFAFAFC);
  static const Color cartItemHover = Color(0xFFEFF6FF);
  static const Color payButton = Color(0xFF059669);
  static const Color payButtonPressed = Color(0xFF047857);
  static const Color holdButton = Color(0xFFD97706);
  static const Color voidColor = Color(0xFFDC2626);
  static const Color returnColor = Color(0xFFEA580C);

  // ─── Interactive states ────────────────────────────────────────────
  static const Color focusRing = Color(0xFF3B82F6);
  static const Color hoverOverlay = Color(0x0A0F172A);
  static const Color pressedOverlay = Color(0x140F172A);
  static const Color selectedBg = Color(0xFFEFF6FF);

  // ─── Dark mode overrides (prepared for future dark theme) ──────────
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkCardSurface = Color(0xFF334155);
}
