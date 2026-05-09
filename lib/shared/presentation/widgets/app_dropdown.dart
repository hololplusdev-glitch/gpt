import 'package:flutter/material.dart';
import 'package:pos_flutter/core/design_system/colors.dart';

/// A unified dropdown field enforcing the SSOT for input styling.
class AppDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final bool isExpanded;
  final String? errorText;

  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.isExpanded = true,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      isExpanded: isExpanded,
      icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        errorText: errorText,
        prefixIcon: prefixIcon,
        // The rest of the styling is inherited from AppTheme.
      ),
    );
  }
}

/// A smaller inline dropdown without form field decorations.
class AppInlineDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  const AppInlineDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isDense: true,
        iconSize: 18,
        icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.bold,
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}
