// core/design_system/typography.dart
// WHY: Consistent text styles across the app. All font weights, sizes,
// and letter-spacing are centralized here. The actual font family is
// applied via GoogleFonts in theme.dart — this file defines the scale.

import 'package:flutter/material.dart';
import 'package:pos_flutter/core/design_system/colors.dart';

/// Kasir Pro typography scale.
///
/// Uses a modular type scale with balanced weight distribution.
/// Font family (Cairo for Arabic, Inter fallback for Latin) is applied
/// at the ThemeData level via [GoogleFonts], not repeated here (DRY).
abstract final class AppTypography {
  // ─── Display / Headers ─────────────────────────────────
  static const TextStyle displayLarge = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.15,
    letterSpacing: -0.5,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.3,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  // ─── Titles ────────────────────────────────────────────
  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.35,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // ─── Body text ─────────────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.55,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.45,
  );

  // ─── Labels (buttons, chips, badges) ───────────────────
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
  );

  // ─── POS-specific styles ───────────────────────────────

  /// Large price display on cart total — bold and eye-catching.
  static const TextStyle priceDisplay = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  /// Cart item price.
  static const TextStyle priceBody = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// Receipt number / transaction ID — monospace for alignment.
  static const TextStyle monoMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    fontFamily: 'JetBrains Mono',
    fontFamilyFallback: ['Courier New', 'monospace'],
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );

  /// Numpad / keypad digits — large and readable.
  static const TextStyle numpad = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  /// Overline / section headers.
  static const TextStyle overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 1.2,
  );
}
