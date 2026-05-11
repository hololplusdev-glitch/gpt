import 'package:flutter/material.dart';
import 'package:holol_POS/core/design_system/spacing.dart';

class AppStatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const AppStatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: icon == null ? null : Icon(icon, size: AppSpacing.lg),
      label: Text(label),
      side: BorderSide(color: color),
      labelStyle: TextStyle(color: color, fontSize: 12),
      visualDensity: VisualDensity.compact,
    );
  }
}
