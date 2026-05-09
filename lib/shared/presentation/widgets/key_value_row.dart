// shared/presentation/widgets/key_value_row.dart
// WHY: Unified label-value pair display, replacing:
//   - cart_panel amount rows
//   - invoice_preview_screen._TotalRow (label + String value)
//   - invoice_preview_screen._Info (label + value, vertical)
//   - shift_screen._InfoRow (label + value)
//   - pos_devices_screen._ReadinessTile (label + value via ListTile)
//
// Single Source of Truth for all "label → value" UI patterns.

import 'package:flutter/widgets.dart';
import 'package:pos_flutter/core/design_system/colors.dart';
import 'package:pos_flutter/core/design_system/spacing.dart';

/// A horizontal row displaying a label and value pair.
///
/// Supports visual emphasis (bold, larger text) and color overrides
/// for semantic rows (discount = green, error = red, grand total = bold).
class KeyValueRow extends StatelessWidget {
  final String label;
  final String value;

  /// Whether this row is emphasized (grand total, header amount).
  final bool strong;

  /// Optional color override for the value text.
  final Color? valueColor;

  /// Optional color override for the label text.
  final Color? labelColor;

  /// Vertical padding between rows. Defaults to [AppSpacing.xxs].
  final double verticalPadding;

  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.strong = false,
    this.valueColor,
    this.labelColor,
    this.verticalPadding = AppSpacing.xxs,
  });

  /// Convenience factory for discount rows (prefixed with '-', green).
  factory KeyValueRow.discount({
    Key? key,
    required String label,
    required String value,
  }) {
    return KeyValueRow(
      key: key,
      label: label,
      value: '-$value',
      valueColor: AppColors.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: strong ? 18 : 13,
      fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
      color:
          labelColor ??
          (strong ? AppColors.textPrimary : AppColors.textSecondary),
    );

    final valueStyle = TextStyle(
      fontSize: strong ? 18 : 13,
      fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
      color: valueColor ?? AppColors.textPrimary,
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}
