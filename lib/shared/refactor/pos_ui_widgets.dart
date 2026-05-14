
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/spacing.dart';
import 'package:holol_POS/core/services/formatters/pos_formatters.dart';
import 'package:holol_POS/shared/presentation/widgets/app_text_field.dart';
import 'package:holol_POS/shared/presentation/widgets/key_value_row.dart';

class AppPageHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onBack;
  final List<Widget> actions;

  const AppPageHeader({
    super.key,
    required this.title,
    required this.icon,
    this.onBack,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              if (onBack != null) ...[
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: AppColors.onPrimary,
                  ),
                  onPressed: onBack,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AppColors.onPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.md),
                ...actions,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppHeroIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  const AppHeroIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 80,
    this.iconSize = 36,
  });

  @override
  State<AppHeroIcon> createState() => _AppHeroIconState();
}

class _AppHeroIconState extends State<AppHeroIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppSpacing.durationHero,
    )..forward();
    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: AppSpacing.curveBounce,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.6, end: 1.0).animate(_scaleAnim),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.icon,
            color: widget.color,
            size: widget.iconSize,
          ),
        ),
      ),
    );
  }
}

class AppSectionTitle extends StatelessWidget {
  final String text;

  const AppSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }
}

class AmountRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isStrong;
  final Color? valueColor;
  final EdgeInsetsGeometry? padding;

  const AmountRow({
    super.key,
    required this.label,
    required this.value,
    this.isStrong = false,
    this.valueColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return KeyValueRow(
      label: label,
      value: PosFormatters.amount(value),
      verticalPadding: AppSpacing.xs,
      strong: isStrong,
      valueColor: valueColor ?? (isStrong ? AppColors.primary : null),
    );
  }
}

class CountRow extends StatelessWidget {
  final String label;
  final int value;

  const CountRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return KeyValueRow(
      label: label,
      value: value.toString(),
      verticalPadding: AppSpacing.xs,
    );
  }
}

class AppAmountField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String hintText;
  final bool autofocus;
  final bool enabled;
  final IconData icon;
  final TextAlign textAlign;

  const AppAmountField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    this.autofocus = false,
    this.enabled = true,
    this.icon = Icons.payments_outlined,
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      enabled: enabled,
      readOnly: false,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      textAlign: textAlign,
      labelText: label,
      hintText: hintText,
      prefixIcon: Icon(icon),
    );
  }
}

class AppPinDotsDisplay extends StatelessWidget {
  final int length;
  final int maxLength;
  final String label;

  const AppPinDotsDisplay({
    super.key,
    required this.length,
    required this.maxLength,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(maxLength, (i) {
            final filled = i < length;
            return Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: filled ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class AppSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool enabled;
  final bool autofocus;

  const AppSearchField({
    super.key,
    this.controller,
    required this.hintText,
    this.onChanged,
    this.onClear,
    this.enabled = true,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      labelText: hintText,
      prefixIcon: const Icon(Icons.search),
      suffixIcon: onClear == null
          ? null
          : IconButton(
              icon: const Icon(Icons.close),
              onPressed: onClear,
            ),
      onChanged: onChanged,
    );
  }
}

class AppActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const AppActionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppSpacing.borderRadiusMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusMd,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppSpacing.borderRadiusMd,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class AppSelectableCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  const AppSelectableCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.primary : AppColors.border;
    final backgroundColor = selected
        ? AppColors.primary.withValues(alpha: 0.06)
        : AppColors.surface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusLg,
        child: AnimatedContainer(
          duration: AppSpacing.durationFast,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: AppSpacing.borderRadiusLg,
            border: Border.all(
              color: borderColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                  size: 28,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onTap == null ? null : (_) => onTap!(),
      selectedColor: AppColors.primary.withValues(alpha: 0.12),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textPrimary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.border,
      ),
    );
  }
}
