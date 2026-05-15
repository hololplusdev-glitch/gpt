import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/layout.dart';
import 'package:holol_POS/core/design_system/spacing.dart';
import 'package:holol_POS/core/l10n/app_localizations.dart';
import 'package:holol_POS/shared/presentation/widgets/app_text_field.dart';

enum AppSearchFieldMode { normal, header, barcode, filterable, customer }

enum AppSearchFieldStyle { surface, onHeader }

class AppSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hintText;
  final String? labelText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final VoidCallback? onScanPressed;
  final VoidCallback? onFilterPressed;
  final String? clearTooltip;
  final String? scanTooltip;
  final String? filterTooltip;
  final bool enabled;
  final bool autofocus;
  final AppSearchFieldMode mode;
  final AppSearchFieldStyle style;
  final double? maxWidth;
  final double? height;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;

  const AppSearchField({
    super.key,
    this.controller,
    this.focusNode,
    required this.hintText,
    this.labelText,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.onScanPressed,
    this.onFilterPressed,
    this.clearTooltip,
    this.scanTooltip,
    this.filterTooltip,
    this.enabled = true,
    this.autofocus = false,
    this.mode = AppSearchFieldMode.normal,
    this.style = AppSearchFieldStyle.surface,
    this.maxWidth,
    this.height,
    this.textInputAction,
    this.inputFormatters,
  });

  bool get _isHeaderStyle =>
      style == AppSearchFieldStyle.onHeader ||
      mode == AppSearchFieldMode.header ||
      mode == AppSearchFieldMode.barcode;

  bool get _isBarcodeMode => mode == AppSearchFieldMode.barcode;

  @override
  Widget build(BuildContext context) {
    final resolvedHeight =
        height ??
        (_isHeaderStyle
            ? AppComponentSizes.touchTarget
            : AppComponentSizes.buttonHeightMd);

    final resolvedMaxWidth =
        maxWidth ?? (_isBarcodeMode ? 520.0 : double.infinity);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
      child: SizedBox(
        height: resolvedHeight,
        child: _isHeaderStyle
            ? _buildHeaderField(context)
            : _buildSurfaceField(),
      ),
    );
  }

  Widget _buildSurfaceField() {
    return AppTextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      autofocus: autofocus,
      labelText: labelText,
      hintText: hintText,
      textInputAction: textInputAction ?? TextInputAction.search,
      prefixIcon: const Icon(Icons.search),
      suffixIcon: _buildSurfaceSuffix(),
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }

  Widget? _buildSurfaceSuffix() {
    final buttons = <Widget>[];

    if (onFilterPressed != null) {
      buttons.add(
        IconButton(
          tooltip: filterTooltip,
          icon: const Icon(Icons.tune),
          onPressed: onFilterPressed,
        ),
      );
    }

    if (onScanPressed != null) {
      buttons.add(
        IconButton(
          tooltip: scanTooltip,
          icon: const Icon(Icons.qr_code_scanner),
          onPressed: onScanPressed,
        ),
      );
    }

    if (onClear != null) {
      buttons.add(
        IconButton(
          tooltip: clearTooltip,
          icon: const Icon(Icons.close),
          onPressed: onClear,
        ),
      );
    }

    if (buttons.isEmpty) return null;
    if (buttons.length == 1) return buttons.first;

    return Row(mainAxisSize: MainAxisSize.min, children: buttons);
  }

  Widget _buildHeaderField(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final suffixButtons = <Widget>[];

    if (onFilterPressed != null) {
      suffixButtons.add(
        IconButton(
          tooltip: filterTooltip,
          icon: Icon(
            Icons.tune,
            color: AppColors.onPrimary.withValues(alpha: 0.7),
            size: AppComponentSizes.iconMd,
          ),
          onPressed: onFilterPressed,
        ),
      );
    }

    if (onScanPressed != null) {
      suffixButtons.add(
        IconButton(
          tooltip: scanTooltip ?? l10n?.scanBarcode,
          icon: Icon(
            Icons.qr_code_scanner,
            color: AppColors.onPrimary.withValues(alpha: 0.75),
            size: AppSpacing.xl,
          ),
          onPressed: onScanPressed,
        ),
      );
    }

    if (onClear != null) {
      suffixButtons.add(
        IconButton(
          tooltip: clearTooltip,
          icon: Icon(
            Icons.clear,
            color: AppColors.onPrimary.withValues(alpha: 0.65),
            size: AppComponentSizes.iconMd,
          ),
          onPressed: onClear,
        ),
      );
    }

    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      autofocus: autofocus,
      style: const TextStyle(color: AppColors.onPrimary, fontSize: 14),
      textInputAction:
          textInputAction ??
          (_isBarcodeMode ? TextInputAction.done : TextInputAction.search),
      inputFormatters:
          inputFormatters ?? [FilteringTextInputFormatter.singleLineFormatter],
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.onPrimary.withValues(alpha: 0.15),
        hintText: hintText,
        hintStyle: TextStyle(
          color: AppColors.onPrimary.withValues(alpha: 0.6),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          Icons.search,
          color: AppColors.onPrimary.withValues(alpha: 0.7),
          size: AppSpacing.xl,
        ),
        suffixIcon: suffixButtons.isEmpty
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: suffixButtons),
        contentPadding: AppSpacing.horizontalMd,
        border: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMd,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMd,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMd,
          borderSide: BorderSide(
            color: AppColors.onPrimary.withValues(alpha: 0.4),
          ),
        ),
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}
