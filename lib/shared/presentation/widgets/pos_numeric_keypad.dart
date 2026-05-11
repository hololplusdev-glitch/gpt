import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_flutter/core/design_system/colors.dart';
import 'package:pos_flutter/core/design_system/spacing.dart';

class PosNumericKeypad extends StatelessWidget {
  final TextEditingController controller;
  final bool allowDecimal;
  final int? maxLength;
  final int decimalPlaces;
  final VoidCallback? onChanged;
  final VoidCallback? onSubmit;
  final String? submitLabel;
  final bool compact;

  const PosNumericKeypad({
    super.key,
    required this.controller,
    this.allowDecimal = false,
    this.maxLength,
    this.decimalPlaces = 2,
    this.onChanged,
    this.onSubmit,
    this.submitLabel,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final keys = allowDecimal
        ? const ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '⌫']
        : const ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'C', '0', '⌫'];

    return Container(
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.55),
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(
          color: AppColors.textHint.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: keys.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: compact ? AppSpacing.xs : AppSpacing.sm,
              crossAxisSpacing: compact ? AppSpacing.xs : AppSpacing.sm,
              childAspectRatio: compact ? 2.35 : 2.05,
            ),
            itemBuilder: (context, index) {
              final key = keys[index];
              final isDelete = key == '⌫';
              final isClear = key == 'C';
              final isUtility = isDelete || isClear;

              return Material(
                color: isUtility ? AppColors.surface : AppColors.cardSurface,
                borderRadius: AppSpacing.borderRadiusMd,
                elevation: isUtility ? 0 : 1,
                child: InkWell(
                  borderRadius: AppSpacing.borderRadiusMd,
                  onTap: () => _handleKey(key),
                  child: Center(
                    child: Text(
                      key,
                      style: TextStyle(
                        color: isUtility
                            ? AppColors.error
                            : AppColors.textPrimary,
                        fontSize: compact ? 20 : 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (onSubmit != null && submitLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.jumbo + AppSpacing.xs,
              child: FilledButton(
                onPressed: onSubmit,
                child: Text(submitLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleKey(String key) {
    HapticFeedback.selectionClick();

    if (key == '⌫') {
      _backspace();
      return;
    }

    if (key == 'C') {
      controller.clear();
      onChanged?.call();
      return;
    }

    _append(key);
  }

  void _append(String value) {
    final current = controller.text.trim();

    if (maxLength != null && current.length >= maxLength!) {
      return;
    }

    if (value == '.') {
      if (!allowDecimal || current.contains('.')) return;
      controller.text = current.isEmpty ? '0.' : '$current.';
      _moveCursorToEnd();
      onChanged?.call();
      return;
    }

    final next = current == '0' ? value : '$current$value';

    if (allowDecimal && next.contains('.')) {
      final decimals = next.split('.').last;
      if (decimals.length > decimalPlaces) return;
    }

    controller.text = next;
    _moveCursorToEnd();
    onChanged?.call();
  }

  void _backspace() {
    final current = controller.text;
    if (current.isEmpty) return;

    controller.text = current.substring(0, current.length - 1);
    _moveCursorToEnd();
    onChanged?.call();
  }

  void _moveCursorToEnd() {
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
  }
}
