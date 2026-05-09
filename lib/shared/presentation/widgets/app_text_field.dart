import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_flutter/core/design_system/spacing.dart';

/// A unified text field component enforcing the SSOT for input styling.
/// Automatically inherits styles from `AppTheme` but allows specific overrides safely.
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool isDense;
  final bool readOnly;
  final bool enabled;
  final bool obscureText;
  final int maxLines;
  final String? errorText;
  final TextAlign textAlign;
  final TextStyle? style;
  final bool autofocus;
  final String? prefixText;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  const AppTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.helperText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.isDense = false,
    this.readOnly = false,
    this.enabled = true,
    this.obscureText = false,
    this.maxLines = 1,
    this.errorText,
    this.textAlign = TextAlign.start,
    this.style,
    this.autofocus = false,
    this.prefixText,
    this.textInputAction,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      readOnly: readOnly,
      enabled: enabled,
      obscureText: obscureText,
      maxLines: maxLines,
      textAlign: textAlign,
      style: style,
      autofocus: autofocus,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      // The decoration inherits the central inputDecorationTheme from theme.dart
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
        errorText: errorText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        prefixText: prefixText,
        isDense: isDense,
        // Override content padding only if dense is required
        contentPadding: isDense ? AppSpacing.paddingSm : null,
      ),
    );
  }
}
