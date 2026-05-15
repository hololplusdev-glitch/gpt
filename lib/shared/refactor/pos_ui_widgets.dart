import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/spacing.dart';
import 'package:holol_POS/core/services/formatters/pos_formatters.dart';
import 'package:holol_POS/features/sales/domain/models/sale_inputs.dart';
import 'package:holol_POS/shared/presentation/widgets/app_text_field.dart';
import 'package:holol_POS/shared/presentation/widgets/key_value_row.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/core/l10n/app_localizations.dart';
import 'package:holol_POS/shared/presentation/widgets/app_button.dart';
import 'package:holol_POS/shared/refactor/pos_payment_draft.dart';
import 'package:holol_POS/shared/presentation/widgets/app_panel.dart';
import 'package:holol_POS/shared/presentation/widgets/app_status_chip.dart';
import 'package:holol_POS/shared/presentation/dialogs/app_dialog.dart';
import 'package:holol_POS/shared/presentation/widgets/app_numeric_keypad.dart';
import 'package:holol_POS/shared/presentation/widgets/app_info_banner.dart';

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
          child: Icon(widget.icon, color: widget.color, size: widget.iconSize),
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

  const CountRow({super.key, required this.label, required this.value});

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
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
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
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
    );
  }
}

class AppSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Color? iconColor;
  final VoidCallback? onTap;

  const AppSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chevronIcon = Directionality.of(context) == TextDirection.rtl
        ? Icons.chevron_left
        : Icons.chevron_right;

    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.textSecondary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing ?? (onTap != null ? Icon(chevronIcon) : null),
      onTap: onTap,
    );
  }
}

class AppStatusDot extends StatefulWidget {
  final HealthStatus status;

  const AppStatusDot({super.key, required this.status});

  @override
  State<AppStatusDot> createState() => _AppStatusDotState();
}

class _AppStatusDotState extends State<AppStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    if (widget.status == HealthStatus.ok) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AppStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.status == HealthStatus.ok && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (widget.status != HealthStatus.ok && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _colorForStatus(HealthStatus status) {
    return switch (status) {
      HealthStatus.ok => AppColors.success,
      HealthStatus.degraded => AppColors.warning,
      HealthStatus.down => AppColors.error,
      HealthStatus.unknown => AppColors.textHint,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForStatus(widget.status);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glowOpacity = widget.status == HealthStatus.ok
            ? 0.15 + (_controller.value * 0.2)
            : 0.0;

        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: glowOpacity),
          ),
          child: child,
        );
      },
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class AppSetupBottomActions extends StatelessWidget {
  final bool isCompact;
  final bool showBack;
  final bool canGoBack;
  final bool isSetupLoading;
  final bool isTesting;
  final String primaryLabel;
  final String backLabel;
  final VoidCallback onBack;
  final VoidCallback onPrimary;

  const AppSetupBottomActions({
    super.key,
    required this.isCompact,
    required this.showBack,
    required this.canGoBack,
    required this.isSetupLoading,
    required this.isTesting,
    required this.primaryLabel,
    required this.backLabel,
    required this.onBack,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final primary = AppButton.primary(
      onPressed: isTesting || isSetupLoading ? null : onPrimary,
      isLoading: isTesting || isSetupLoading,
      label: isSetupLoading ? 'جاري تهيئة بيانات التشغيل' : primaryLabel,
    );

    final back = TextButton(
      onPressed: showBack && canGoBack ? onBack : null,
      child: Text(backLabel),
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          primary,
          if (showBack) ...[const SizedBox(height: AppSpacing.sm), back],
        ],
      );
    }

    return Row(children: [if (showBack) back, const Spacer(), primary]);
  }
}

class AppSetupBanner extends StatelessWidget {
  final int step;
  final AppLocalizations l10n;

  const AppSetupBanner({super.key, required this.step, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (step) {
      0 => l10n.languageLabel,
      1 => l10n.serverIdentity,
      _ => l10n.initialReadiness,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.onPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.rocket_launch_outlined,
              color: AppColors.onPrimary,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.posSetup,
                  style: const TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.onPrimary.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppStepperIndicator extends StatelessWidget {
  final int currentStep;
  final List<String> labels;

  const AppStepperIndicator({
    super.key,
    required this.currentStep,
    this.labels = const ['اللغة', 'الخادم', 'التشغيل'],
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    for (var i = 0; i < labels.length; i++) {
      children.add(_dot(i, labels[i]));
      if (i < labels.length - 1) {
        children.add(_line(i));
      }
    }

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.xl,
      ),
      child: Row(children: children),
    );
  }

  Widget _dot(int step, String label) {
    final isDone = currentStep > step;
    final isActive = currentStep == step;
    final color = isDone
        ? AppColors.success
        : isActive
        ? AppColors.primary
        : AppColors.border;

    return Expanded(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDone || isActive ? color : AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Text(
                      '${step + 1}',
                      style: TextStyle(
                        color: isActive ? Colors.white : color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? AppColors.textPrimary : AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(int afterStep) {
    final done = currentStep > afterStep;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
        color: done ? AppColors.success : AppColors.border,
      ),
    );
  }
}

class AppLanguageCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final String icon;
  final bool isSelected;
  final VoidCallback onTap;

  const AppLanguageCard({
    super.key,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusLg,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.06)
                : AppColors.surface,
            borderRadius: AppSpacing.borderRadiusLg,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppSectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const AppSectionLabel({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class AppReadinessFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const AppReadinessFeature({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppBrandMark extends StatelessWidget {
  final String label;

  const AppBrandMark({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.point_of_sale,
          color: AppColors.onPrimary,
          size: AppSpacing.xxl,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.onPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class AppTopBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const AppTopBarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppSpacing.borderRadiusMd,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: AppColors.onPrimary.withValues(alpha: 0.06),
              borderRadius: AppSpacing.borderRadiusMd,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: AppColors.onPrimary.withValues(alpha: 0.85),
                  size: 20,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.onPrimary.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppCashierBadge extends StatelessWidget {
  final String cashierName;

  const AppCashierBadge({super.key, required this.cashierName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.onPrimary.withValues(alpha: 0.1),
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(color: AppColors.onPrimary.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              color: AppColors.onPrimary,
              size: 16,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              cashierName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.onPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppLogoutButton extends StatelessWidget {
  final VoidCallback onPressed;

  const AppLogoutButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return IconButton(
      icon: Icon(
        Icons.logout,
        color: AppColors.onPrimary.withValues(alpha: 0.7),
        size: AppSpacing.xl,
      ),
      tooltip: l10n.logout,
      onPressed: onPressed,
    );
  }
}

class AppPaymentSummaryRow extends StatelessWidget {
  final String label;
  final double value;

  const AppPaymentSummaryRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text.rich(
          PosFormatters.amountRich(
            value,
            amountStyle: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class AppCompleteButton extends StatelessWidget {
  final bool isProcessing;
  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  const AppCompleteButton({
    super.key,
    required this.isProcessing,
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.jumbo + AppSpacing.sm,
      child: AppButton.primary(
        onPressed: !enabled || isProcessing ? null : onPressed,
        customColor: AppColors.payButton,
        isLoading: isProcessing,
        label: label,
      ),
    );
  }
}

class AppPaymentMethodButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget subtitleWidget;
  final Color color;
  final VoidCallback? onPressed;

  const AppPaymentMethodButton({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitleWidget,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppSpacing.borderRadiusLg,
        child: AnimatedContainer(
          duration: AppSpacing.durationFast,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: disabled
                ? AppColors.surfaceVariant
                : color.withValues(alpha: 0.08),
            borderRadius: AppSpacing.borderRadiusLg,
            border: Border.all(
              color: disabled
                  ? AppColors.border
                  : color.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: disabled ? AppColors.textHint : color,
                size: 24,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: disabled ? AppColors.textHint : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              DefaultTextStyle(
                style: TextStyle(
                  color: disabled ? AppColors.textHint : color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                child: subtitleWidget,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum AppOverflowAction {
  hold,
  heldOrders,
  shift,
  history,
  sync,
  devices,
  settings,
}

class AppOverflowActions extends StatelessWidget {
  final VoidCallback onHold;
  final VoidCallback onHeldOrders;
  final VoidCallback onShift;
  final VoidCallback onHistory;
  final VoidCallback onSync;
  final VoidCallback onDevices;
  final VoidCallback onSettings;

  const AppOverflowActions({
    super.key,
    required this.onHold,
    required this.onHeldOrders,
    required this.onShift,
    required this.onHistory,
    required this.onSync,
    required this.onDevices,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopupMenuButton<AppOverflowAction>(
      tooltip: 'المزيد',
      icon: Icon(
        Icons.more_vert,
        color: AppColors.onPrimary.withValues(alpha: 0.8),
      ),
      onSelected: (action) {
        switch (action) {
          case AppOverflowAction.hold:
            onHold();
          case AppOverflowAction.heldOrders:
            onHeldOrders();
          case AppOverflowAction.shift:
            onShift();
          case AppOverflowAction.history:
            onHistory();
          case AppOverflowAction.sync:
            onSync();
          case AppOverflowAction.devices:
            onDevices();
          case AppOverflowAction.settings:
            onSettings();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: AppOverflowAction.hold,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.pause_circle_outline),
            title: Text(l10n.hold),
          ),
        ),
        const PopupMenuItem(
          value: AppOverflowAction.heldOrders,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.restore_page_outlined),
            title: Text('الطلبات المعلقة'),
          ),
        ),
        const PopupMenuItem(
          value: AppOverflowAction.shift,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.analytics_outlined),
            title: Text('الشفت'),
          ),
        ),
        PopupMenuItem(
          value: AppOverflowAction.history,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.history),
            title: Text(l10n.salesHistory),
          ),
        ),
        PopupMenuItem(
          value: AppOverflowAction.sync,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.sync),
            title: Text(l10n.syncMonitor),
          ),
        ),
        PopupMenuItem(
          value: AppOverflowAction.devices,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.devices),
            title: Text(l10n.posDevices),
          ),
        ),
        PopupMenuItem(
          value: AppOverflowAction.settings,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.settings),
            title: Text(l10n.settings),
          ),
        ),
      ],
    );
  }
}

class AppPaymentLineTile extends StatelessWidget {
  final PaymentDraftLine line;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AppPaymentLineTile({
    super.key,
    required this.line,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, title) = switch (line.kind) {
      SaleTenderKind.cash => (Icons.payments_outlined, 'كاش'),
      SaleTenderKind.network => (Icons.credit_card, 'شبكة'),
      SaleTenderKind.credit => (Icons.person_outline, 'آجل'),
    };

    final subtitleWidget = line.kind == SaleTenderKind.cash && line.change > 0
        ? Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'المستلم '),
                PosFormatters.amountRich(line.tenderedAmount),
                const TextSpan(text: ' - الراجع '),
                PosFormatters.amountRich(line.change),
              ],
            ),
            style: const TextStyle(fontSize: 12),
          )
        : null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(color: AppColors.border),
        boxShadow: AppSpacing.shadowSm,
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: subtitleWidget,
        trailing: Wrap(
          spacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text.rich(
              PosFormatters.amountRich(
                line.amount,
                amountStyle: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'تعديل',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'حذف',
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: AppColors.error,
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class AppReceiptImageFrame extends StatelessWidget {
  final Uint8List bytes;
  final double? maxWidth;
  final FilterQuality filterQuality;

  const AppReceiptImageFrame({
    super.key,
    required this.bytes,
    this.maxWidth,
    this.filterQuality = FilterQuality.high,
  });

  @override
  Widget build(BuildContext context) {
    final image = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppSpacing.borderRadiusSm,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppSpacing.borderRadiusSm,
        child: Image.memory(bytes, filterQuality: filterQuality),
      ),
    );

    return Center(
      child: maxWidth == null
          ? image
          : ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth!),
              child: image,
            ),
    );
  }
}

class AppHeaderCountBadge extends StatelessWidget {
  final int count;
  final String? tooltip;

  const AppHeaderCountBadge({super.key, required this.count, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: AppSpacing.borderRadiusSm,
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );

    if (tooltip == null || tooltip!.trim().isEmpty) {
      return badge;
    }

    return Tooltip(message: tooltip!, child: badge);
  }
}

class AppBottomSheetHandle extends StatelessWidget {
  final Color color;
  final double width;
  final double height;

  const AppBottomSheetHandle({
    super.key,
    this.color = AppColors.border,
    this.width = 44,
    this.height = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class AppRoundedBottomSheetFrame extends StatelessWidget {
  final Widget child;
  final double topRadius;
  final Color backgroundColor;
  final EdgeInsetsGeometry handlePadding;

  const AppRoundedBottomSheetFrame({
    super.key,
    required this.child,
    this.topRadius = AppSpacing.lg,
    this.backgroundColor = AppColors.surface,
    this.handlePadding = const EdgeInsets.only(top: AppSpacing.sm),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: backgroundColor,
            padding: handlePadding,
            child: const AppBottomSheetHandle(),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class AppChangeNoticeBox extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;

  const AppChangeNoticeBox({
    super.key,
    required this.label,
    required this.value,
    this.icon = Icons.currency_exchange,
    this.color = AppColors.info,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$label: '),
                PosFormatters.amountRich(
                  value,
                  amountStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class AppAmountChip extends StatelessWidget {
  final String label;
  final double value;
  final bool enabled;

  const AppAmountChip({
    super.key,
    required this.label,
    required this.value,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: enabled ? AppColors.surface : AppColors.surfaceVariant,
        borderRadius: AppSpacing.borderRadiusSm,
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label ',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            Text.rich(
              PosFormatters.amountRich(
                value,
                amountStyle: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppSquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color backgroundColor;
  final Color iconColor;
  final double size;
  final double iconSize;

  const AppSquareIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.backgroundColor = AppColors.surfaceVariant,
    this.iconColor = AppColors.textPrimary,
    this.size = 44,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: backgroundColor,
      borderRadius: AppSpacing.borderRadiusSm,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusSm,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: iconColor),
        ),
      ),
    );

    if (tooltip == null || tooltip!.trim().isEmpty) {
      return button;
    }

    return Tooltip(message: tooltip!, child: button);
  }
}

class AppSignedAmountRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isDiscount;

  const AppSignedAmountRow({
    super.key,
    required this.label,
    required this.value,
    this.isDiscount = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isDiscount) {
      return KeyValueRow(
        label: label,
        valueColor: AppColors.success,
        value: '-${PosFormatters.amount(value)}',
        valueWidget: Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: '-'),
              PosFormatters.amountRich(
                value,
                amountStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return KeyValueRow(
      label: label,
      value: PosFormatters.amount(value),
      valueWidget: Text.rich(
        PosFormatters.amountRich(
          value,
          amountStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class AppInlineDiscountEditor extends StatelessWidget {
  final TextEditingController controller;
  final DiscountType type;
  final bool enabled;
  final String? error;
  final ValueChanged<DiscountType> onTypeChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onClear;

  const AppInlineDiscountEditor({
    super.key,
    required this.controller,
    required this.type,
    required this.enabled,
    required this.error,
    required this.onTypeChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 112,
              height: 40,
              child: TextField(
                controller: controller,
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onSubmitted(),
                decoration: InputDecoration(
                  labelText: enabled ? 'الخصم' : 'الخصم معطل',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SegmentedButton<DiscountType>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: DiscountType.percentage, label: Text('%')),
                ButtonSegment(value: DiscountType.fixed, label: Text('مبلغ')),
              ],
              selected: {type},
              onSelectionChanged: enabled
                  ? (value) => onTypeChanged(value.first)
                  : null,
            ),
            IconButton(
              tooltip: 'مسح الخصم',
              onPressed: enabled ? onClear : null,
              icon: const Icon(Icons.backspace_outlined),
            ),
          ],
        ),
        if (!enabled)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'هذا الصنف لا يسمح بالخصم',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textHint),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              error!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}

class AppReadinessTile extends StatelessWidget {
  final String label;
  final String value;
  final Widget? leading;
  final Widget? trailing;
  final bool dense;

  const AppReadinessTile({
    super.key,
    required this.label,
    required this.value,
    this.leading,
    this.trailing,
    this.dense = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: dense,
      leading: leading,
      title: Text(label),
      trailing:
          trailing ??
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class AppSuccessHero extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  const AppSuccessHero({
    super.key,
    this.icon = Icons.check_circle,
    this.color = AppColors.success,
    this.size = 80,
    this.iconSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

class AppMonospaceValueText extends StatelessWidget {
  final String value;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextStyle? style;

  const AppMonospaceValueText({
    super.key,
    required this.value,
    this.maxLines,
    this.overflow,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: maxLines,
      overflow: overflow,
      style:
          style ??
          const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'monospace'),
    );
  }
}

class AppSummaryCard extends StatelessWidget {
  final Widget title;
  final Widget? amount;
  final Widget? subtitle;
  final Widget? meta;
  final Widget? status;
  final Widget? actions;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool enabled;

  const AppSummaryCard({
    super.key,
    required this.title,
    this.amount,
    this.subtitle,
    this.meta,
    this.status,
    this.actions,
    this.onTap,
    this.padding = AppSpacing.paddingLg,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: title),
              if (amount != null) ...[
                const SizedBox(width: AppSpacing.md),
                amount!,
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.sm),
            subtitle!,
          ],
          if (meta != null || status != null || actions != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (meta != null) Expanded(child: meta!),
                if (meta == null) const Spacer(),
                if (status != null) status!,
                if (actions != null) actions!,
              ],
            ),
          ],
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(color: AppColors.border),
        boxShadow: AppSpacing.shadowSm,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppSpacing.borderRadiusMd,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: AppSpacing.borderRadiusMd,
          child: content,
        ),
      ),
    );
  }
}

class AppActionsWrap extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final WrapAlignment alignment;

  const AppActionsWrap({
    super.key,
    required this.children,
    this.spacing = AppSpacing.sm,
    this.runSpacing = AppSpacing.sm,
    this.alignment = WrapAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      alignment: alignment,
      children: children,
    );
  }
}

class AppKeyValuePanel extends StatelessWidget {
  final String? title;
  final List<Widget> rows;
  final Widget? extra;
  final EdgeInsetsGeometry? padding;

  const AppKeyValuePanel({
    super.key,
    this.title,
    required this.rows,
    this.extra,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      title: title,
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...rows,
            if (extra != null) ...[
              const SizedBox(height: AppSpacing.sm),
              extra!,
            ],
          ],
        ),
      ),
    );
  }
}

class AppStatusHistoryEntry {
  final String title;
  final String? subtitle;
  final String statusLabel;
  final Color statusColor;
  final IconData? statusIcon;
  final String? error;
  final String? note;

  const AppStatusHistoryEntry({
    required this.title,
    this.subtitle,
    required this.statusLabel,
    required this.statusColor,
    this.statusIcon,
    this.error,
    this.note,
  });
}

class AppStatusHistoryList extends StatelessWidget {
  final String? title;
  final List<AppStatusHistoryEntry> entries;
  final Widget? empty;
  final bool showDividers;

  const AppStatusHistoryList({
    super.key,
    this.title,
    required this.entries,
    this.empty,
    this.showDividers = true,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return AppPanel(
        title: title,
        child: empty ?? const Text('لا توجد بيانات.'),
      );
    }

    return AppPanel(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            _AppStatusHistoryRow(entry: entries[i]),
            if (showDividers && i < entries.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}

class _AppStatusHistoryRow extends StatelessWidget {
  final AppStatusHistoryEntry entry;

  const _AppStatusHistoryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              AppStatusChip(
                label: entry.statusLabel,
                color: entry.statusColor,
                icon: entry.statusIcon,
              ),
            ],
          ),
          if (entry.subtitle?.isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              entry.subtitle!,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
          if (entry.note?.isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              entry.note!,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
          if (entry.error?.isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(entry.error!, style: const TextStyle(color: AppColors.error)),
          ],
        ],
      ),
    );
  }
}

class AppDeviceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? status;
  final List<Widget> actions;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;
  final VoidCallback? onTap;

  const AppDeviceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.status,
    this.actions = const [],
    this.switchValue,
    this.onSwitchChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final trailingChildren = <Widget>[
      if (status != null) status!,
      ...actions,
      if (switchValue != null)
        Switch(value: switchValue!, onChanged: onSwitchChanged),
    ];

    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
      trailing: trailingChildren.isEmpty
          ? null
          : Wrap(
              spacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: trailingChildren,
            ),
    );
  }
}

class AppSelectableChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const AppSelectableChip({
    super.key,
    required this.label,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppSpacing.durationFast,
      curve: AppSpacing.curveDefault,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
        borderRadius: AppSpacing.borderRadiusLg,
        boxShadow: isSelected ? AppSpacing.shadowSm : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppSpacing.borderRadiusLg,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppSpacing.borderRadiusLg,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.onPrimary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppEmptyDiagnostic extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final Color backgroundColor;

  const AppEmptyDiagnostic({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color = AppColors.warning,
    this.backgroundColor = AppColors.warningBg,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXl,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: color),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (subtitle?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.sm),
              SelectableText(
                subtitle!,
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppCatalogItemCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final Widget? unitControl;
  final Widget? price;
  final String? statusText;
  final Color? statusColor;
  final bool isEmpty;
  final bool isLoading;
  final bool isError;
  final VoidCallback? onTap;
  final String placeholderAsset;

  const AppCatalogItemCard({
    super.key,
    required this.title,
    this.imageUrl,
    this.unitControl,
    this.price,
    this.statusText,
    this.statusColor,
    this.isEmpty = false,
    this.isLoading = false,
    this.isError = false,
    this.onTap,
    this.placeholderAsset = 'assets/images/placeholder.jpg',
  });

  @override
  Widget build(BuildContext context) {
    final isInteractive = onTap != null && !isLoading && !isError;

    return Container(
      decoration: BoxDecoration(
        color: isEmpty ? AppColors.surfaceVariant : AppColors.cardSurface,
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(color: AppColors.border),
        boxShadow: isInteractive ? AppSpacing.shadowSm : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppSpacing.borderRadiusMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppSpacing.borderRadiusMd,
          hoverColor: AppColors.cartItemHover,
          child: Padding(
            padding: AppSpacing.paddingMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Center(
                    child: ClipRRect(
                      borderRadius: AppSpacing.borderRadiusSm,
                      child: _CatalogItemImage(
                        imageUrl: imageUrl,
                        isEmpty: isEmpty,
                        placeholderAsset: placeholderAsset,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                    color: isEmpty ? AppColors.textHint : AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                if (isLoading)
                  const LinearProgressIndicator(minHeight: 2)
                else if (statusText != null && statusText!.isNotEmpty)
                  Text(
                    statusText!,
                    style: TextStyle(
                      color: statusColor ?? AppColors.error,
                      fontSize: 12,
                      fontWeight: isEmpty ? FontWeight.bold : FontWeight.w600,
                    ),
                  )
                else ...[
                  if (unitControl != null) unitControl!,
                  if (price != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    price!,
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogItemImage extends StatelessWidget {
  final String? imageUrl;
  final bool isEmpty;
  final String placeholderAsset;

  const _CatalogItemImage({
    required this.imageUrl,
    required this.isEmpty,
    required this.placeholderAsset,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    final placeholder = Opacity(
      opacity: isEmpty ? 0.5 : 1.0,
      child: Image.asset(
        placeholderAsset,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      ),
    );

    if (!hasImage) return placeholder;

    return Image.network(
      imageUrl!,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.contain,
      color: isEmpty ? Colors.white.withValues(alpha: 0.5) : null,
      colorBlendMode: isEmpty ? BlendMode.modulate : null,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}

class AppLineItemTile extends StatelessWidget {
  final Widget title;
  final List<Widget> chips;
  final Widget? editor;
  final Widget quantityControls;
  final Widget amount;
  final Widget? trailingAction;
  final bool highlightOnBuild;
  final double compactBreakpoint;
  final EdgeInsetsGeometry padding;

  const AppLineItemTile({
    super.key,
    required this.title,
    this.chips = const [],
    this.editor,
    required this.quantityControls,
    required this.amount,
    this.trailingAction,
    this.highlightOnBuild = true,
    this.compactBreakpoint = 420,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < compactBreakpoint;

        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            if (chips.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: chips,
              ),
            ],
            if (editor != null) ...[
              const SizedBox(height: AppSpacing.sm),
              editor!,
            ],
          ],
        );

        final amountAndAction = Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            amount,
            if (trailingAction != null) ...[
              const SizedBox(height: AppSpacing.sm),
              trailingAction!,
            ],
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              details,
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [quantityControls, const Spacer(), amountAndAction],
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: details),
            const SizedBox(width: AppSpacing.md),
            quantityControls,
            const SizedBox(width: AppSpacing.md),
            amountAndAction,
          ],
        );
      },
    );

    if (!highlightOnBuild) {
      return Padding(padding: padding, child: content);
    }

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(
        begin: AppColors.success.withValues(alpha: 0.3),
        end: Colors.transparent,
      ),
      duration: const Duration(milliseconds: 800),
      builder: (context, color, child) {
        return Container(color: color, padding: padding, child: child);
      },
      child: content,
    );
  }
}

class AppTotalsPanel extends StatelessWidget {
  final List<Widget> rows;
  final Widget? error;
  final Widget? totalLabel;
  final Widget? totalValue;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final double dividerHeight;

  const AppTotalsPanel({
    super.key,
    this.rows = const [],
    this.error,
    this.totalLabel,
    this.totalValue,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.backgroundColor = AppColors.surface,
    this.dividerHeight = AppSpacing.lg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      color: backgroundColor,
      child: error != null
          ? error!
          : Column(
              children: [
                ...rows,
                if (totalLabel != null && totalValue != null) ...[
                  Divider(height: dividerHeight),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [totalLabel!, totalValue!],
                  ),
                ],
              ],
            ),
    );
  }
}

class AppBottomPrimaryAction extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final Widget? labelWidget;
  final IconData? icon;
  final Color? customColor;
  final bool isLoading;
  final double height;
  final EdgeInsetsGeometry? padding;

  const AppBottomPrimaryAction({
    super.key,
    required this.onPressed,
    required this.label,
    this.labelWidget,
    this.icon,
    this.customColor,
    this.isLoading = false,
    this.height = 58,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePadding =
        padding ??
        EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
        );

    return Container(
      padding: effectivePadding,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: AppButton.primary(
          onPressed: onPressed,
          customColor: customColor,
          icon: icon,
          label: label,
          labelWidget: labelWidget,
          isLoading: isLoading,
        ),
      ),
    );
  }
}

class AppMenuActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;

  const AppMenuActionRow({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: AppSpacing.xl),
        const SizedBox(width: AppSpacing.md),
        Flexible(child: Text(label)),
      ],
    );
  }
}

class AppBottomDockBar extends StatelessWidget {
  final VoidCallback? onTap;
  final String badgeText;
  final String label;
  final String value;
  final IconData trailingIcon;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  const AppBottomDockBar({
    super.key,
    required this.onTap,
    required this.badgeText,
    required this.label,
    required this.value,
    this.trailingIcon = Icons.keyboard_arrow_up,
    this.margin = const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.lg,
    ),
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: AppSpacing.borderRadiusLg,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.onPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.onPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(trailingIcon, color: AppColors.onPrimary, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class AppOverlayLoadingState extends StatelessWidget {
  final Color backgroundColor;
  final Color? progressColor;
  final double size;
  final double strokeWidth;

  const AppOverlayLoadingState({
    super.key,
    this.backgroundColor = Colors.black87,
    this.progressColor,
    this.size = 28,
    this.strokeWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      alignment: Alignment.center,
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: strokeWidth,
          color: progressColor,
        ),
      ),
    );
  }
}

class AppCenteredMessageState extends StatelessWidget {
  final String message;
  final Color backgroundColor;
  final Color textColor;
  final EdgeInsetsGeometry padding;
  final TextStyle? style;
  final IconData? icon;

  const AppCenteredMessageState({
    super.key,
    required this.message,
    this.backgroundColor = Colors.black87,
    this.textColor = Colors.white,
    this.padding = AppSpacing.paddingLg,
    this.style,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle =
        style ?? TextStyle(color: textColor, fontWeight: FontWeight.w600);

    return Container(
      color: backgroundColor,
      alignment: Alignment.center,
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: textColor, size: 32),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(message, textAlign: TextAlign.center, style: effectiveStyle),
        ],
      ),
    );
  }
}

class AppScanWindowOverlay extends StatelessWidget {
  final Rect scanWindow;
  final Color overlayColor;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;

  const AppScanWindowOverlay({
    super.key,
    required this.scanWindow,
    this.overlayColor = Colors.black54,
    this.borderColor = AppColors.primary,
    this.borderWidth = 2,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(overlayColor, BlendMode.srcOut),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Positioned.fromRect(
                rect: scanWindow,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned.fromRect(
          rect: scanWindow,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor.withValues(alpha: 0.7),
                width: borderWidth,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AppFeedbackToast extends StatelessWidget {
  final String message;
  final bool isError;
  final Duration duration;
  final Color? successColor;
  final Color? errorColor;

  const AppFeedbackToast({
    super.key,
    required this.message,
    required this.isError,
    this.duration = const Duration(milliseconds: 200),
    this.successColor,
    this.errorColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? (errorColor ?? AppColors.error)
        : (successColor ?? AppColors.success);

    return AnimatedOpacity(
      opacity: 1.0,
      duration: duration,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.9),
          borderRadius: AppSpacing.borderRadiusMd,
        ),
        child: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class AppLoginBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const AppLoginBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.point_of_sale_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.onPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: AppColors.onPrimary, size: 36),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.onPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.onPrimary.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class AppIdentityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const AppIdentityCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.storefront_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppBrandFooter extends StatelessWidget {
  final String text;
  final IconData icon;

  const AppBrandFooter({super.key, required this.text, this.icon = Icons.code});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(color: AppColors.border.withValues(alpha: 0.5)),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: AppColors.textHint),
            const SizedBox(width: AppSpacing.xs),
            Text(
              text,
              style: TextStyle(
                color: AppColors.textHint,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class AppPinEntryDialog extends StatefulWidget {
  final bool createMode;
  final String createTitle;
  final String enterTitle;
  final String cancelLabel;
  final String newPinLabel;
  final String pinLabel;
  final String confirmPinLabel;
  final String createSubmitLabel;
  final String enterSubmitLabel;
  final String invalidPinMessage;
  final String mismatchPinMessage;

  const AppPinEntryDialog({
    super.key,
    required this.createMode,
    this.createTitle = 'إنشاء PIN',
    this.enterTitle = 'إدخال PIN',
    this.cancelLabel = 'إلغاء',
    this.newPinLabel = 'PIN جديد',
    this.pinLabel = 'PIN',
    this.confirmPinLabel = 'تأكيد PIN',
    this.createSubmitLabel = 'حفظ ودخول',
    this.enterSubmitLabel = 'دخول',
    this.invalidPinMessage = 'PIN يجب أن يكون 4 أرقام.',
    this.mismatchPinMessage = 'تأكيد PIN غير مطابق.',
  });

  @override
  State<AppPinEntryDialog> createState() => _AppPinEntryDialogState();
}

class _AppPinEntryDialogState extends State<AppPinEntryDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();

  String? _error;

  @override
  void initState() {
    super.initState();
    _pinController.addListener(_onInputChanged);
    _confirmController.addListener(_onInputChanged);
  }

  void _onInputChanged() => setState(() {});

  @override
  void dispose() {
    _pinController.removeListener(_onInputChanged);
    _confirmController.removeListener(_onInputChanged);
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();

    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() => _error = widget.invalidPinMessage);
      return;
    }

    if (widget.createMode && pin != confirm) {
      setState(() => _error = widget.mismatchPinMessage);
      return;
    }

    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.createMode ? widget.createTitle : widget.enterTitle,
      icon: Icons.lock_outline,
      confirmLabel: null,
      cancelLabel: widget.cancelLabel,
      onCancel: () => Navigator.of(context).pop(),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppPinDotsDisplay(
              length: _pinController.text.length,
              maxLength: 4,
              label: widget.createMode ? widget.newPinLabel : widget.pinLabel,
            ),
            if (widget.createMode) ...[
              const SizedBox(height: AppSpacing.md),
              AppPinDotsDisplay(
                length: _confirmController.text.length,
                maxLength: 4,
                label: widget.confirmPinLabel,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppInfoBanner.error(message: _error!),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppNumericKeypad(
              controller: widget.createMode && _pinController.text.length >= 4
                  ? _confirmController
                  : _pinController,
              maxLength: 4,
              onSubmit: _submit,
              submitLabel: widget.createMode
                  ? widget.createSubmitLabel
                  : widget.enterSubmitLabel,
              submitIcon: Icons.lock_open,
            ),
          ],
        ),
      ),
    );
  }
}

class AppDataTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final String? badgeText;
  final VoidCallback? onTap;
  final double width;
  final EdgeInsetsGeometry padding;

  const AppDataTile({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.badgeText,
    this.onTap,
    this.width = 260,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: padding,
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (badgeText != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(badgeText!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppPaginationBar extends StatelessWidget {
  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final String previousTooltip;
  final String nextTooltip;
  final EdgeInsetsGeometry padding;
  final double compactBreakpoint;

  const AppPaginationBar({
    super.key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.previousTooltip,
    required this.nextTooltip,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.compactBreakpoint = 360,
  });

  @override
  Widget build(BuildContext context) {
    final info = Text(label, overflow: TextOverflow.ellipsis);

    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: previousTooltip,
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: nextTooltip,
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );

    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < compactBreakpoint) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                Align(alignment: Alignment.centerRight, child: controls),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: info),
              controls,
            ],
          );
        },
      ),
    );
  }
}

class AppRowDetailsSheet extends StatelessWidget {
  final String title;
  final List<MapEntry<String, Object?>> entries;
  final String Function(Object? value) formatValue;
  final VoidCallback onCopy;
  final VoidCallback onClose;
  final String copyTooltip;
  final String closeTooltip;
  final ScrollController? controller;

  const AppRowDetailsSheet({
    super.key,
    required this.title,
    required this.entries,
    required this.formatValue,
    required this.onCopy,
    required this.onClose,
    required this.copyTooltip,
    required this.closeTooltip,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: AppBottomSheetHandle(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: copyTooltip,
                onPressed: onCopy,
                icon: const Icon(Icons.copy),
              ),
              IconButton(
                tooltip: closeTooltip,
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            controller: controller,
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = entries[index];

              return ListTile(
                title: Text(entry.key),
                subtitle: SelectableText(formatValue(entry.value)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class AppSurfaceSection extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color? borderColor;
  final BorderRadiusGeometry borderRadius;

  AppSurfaceSection({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.backgroundColor = AppColors.surfaceVariant,
    this.borderColor,
    BorderRadiusGeometry? borderRadius,
  }) : borderRadius = borderRadius ?? AppSpacing.borderRadiusLg;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class AppSelectableListTile extends StatelessWidget {
  final bool selected;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final IconData selectedIcon;
  final IconData unselectedIcon;
  final Color selectedColor;
  final bool dense;

  const AppSelectableListTile({
    super.key,
    required this.selected,
    required this.title,
    this.subtitle,
    this.onTap,
    this.selectedIcon = Icons.check_circle,
    this.unselectedIcon = Icons.person_outline,
    this.selectedColor = AppColors.success,
    this.dense = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: dense,
      leading: Icon(
        selected ? selectedIcon : unselectedIcon,
        color: selected ? selectedColor : null,
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null ? null : Text(subtitle!),
      onTap: onTap,
    );
  }
}
