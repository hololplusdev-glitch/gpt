// shared/presentation/widgets/app_numeric_keypad.dart
// WHY: POS devices are often touch-only screens without physical keyboards.
// This widget provides a visual numeric keypad for entering PINs, user numbers,
// and other numeric inputs on touch-screen POS terminals.

import 'package:flutter/material.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/spacing.dart';

/// A touch-friendly numeric keypad for POS terminals.
///
/// Use with a [TextEditingController] to sync input.
/// [maxLength] limits the number of digits.
/// [onSubmit] fires when the user taps the confirm key.
class AppNumericKeypad extends StatelessWidget {
  final TextEditingController controller;
  final int? maxLength;
  final VoidCallback? onSubmit;
  final String submitLabel;
  final IconData submitIcon;

  const AppNumericKeypad({
    super.key,
    required this.controller,
    this.maxLength,
    this.onSubmit,
    this.submitLabel = 'تأكيد',
    this.submitIcon = Icons.check_circle,
  });

  void _append(String digit) {
    if (maxLength != null && controller.text.length >= maxLength!) return;
    controller.text += digit;
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
  }

  void _backspace() {
    if (controller.text.isEmpty) return;
    controller.text = controller.text.substring(0, controller.text.length - 1);
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
  }

  void _clear() {
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: 1 2 3
        _buildRow(['1', '2', '3']),
        const SizedBox(height: AppSpacing.sm),
        // Row 2: 4 5 6
        _buildRow(['4', '5', '6']),
        const SizedBox(height: AppSpacing.sm),
        // Row 3: 7 8 9
        _buildRow(['7', '8', '9']),
        const SizedBox(height: AppSpacing.sm),
        // Row 4: Clear 0 Backspace
        Row(
          children: [
            Expanded(
              child: _KeypadButton(
                onTap: _clear,
                child: const Text(
                  'مسح',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _DigitButton(digit: '0', onTap: () => _append('0')),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _KeypadButton(
                onTap: _backspace,
                child: const Icon(
                  Icons.backspace_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        if (onSubmit != null) ...[
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: onSubmit,
              icon: Icon(submitIcon),
              label: Text(
                submitLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: AppSpacing.borderRadiusMd,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      children: [
        for (int i = 0; i < digits.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _DigitButton(
              digit: digits[i],
              onTap: () => _append(digits[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _DigitButton extends StatelessWidget {
  final String digit;
  final VoidCallback onTap;

  const _DigitButton({required this.digit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _KeypadButton(
      onTap: onTap,
      child: Text(
        digit,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _KeypadButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: AppSpacing.borderRadiusMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusMd,
        child: Container(height: 56, alignment: Alignment.center, child: child),
      ),
    );
  }
}
