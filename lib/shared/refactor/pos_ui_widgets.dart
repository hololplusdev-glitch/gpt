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
import 'dart:typed_data';

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
                child: Icon(icon, color: AppColors.onPrimary, size: 22),
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
          : IconButton(icon: const Icon(Icons.close), onPressed: onClear),
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

class AppPageScaffold extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget body;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Color backgroundColor;

  const AppPageScaffold({
    super.key,
    required this.title,
    required this.icon,
    required this.body,
    this.onBack,
    this.actions = const [],
    this.backgroundColor = AppColors.background,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          AppPageHeader(
            title: title,
            icon: icon,
            onBack: onBack,
            actions: actions,
          ),
          Expanded(child: body),
        ],
      ),
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

class AppPageHeaderWithBottom extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget bottom;

  const AppPageHeaderWithBottom({
    super.key,
    required this.title,
    required this.icon,
    required this.bottom,
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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Column(
            children: [
              Row(
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
                    child: Icon(icon, color: AppColors.onPrimary, size: 22),
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
              const SizedBox(height: AppSpacing.md),
              bottom,
            ],
          ),
        ),
      ),
    );
  }
}

class AppHeaderSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onClear;
  final String? clearTooltip;

  const AppHeaderSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
    this.onSubmitted,
    this.clearTooltip,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        style: const TextStyle(color: AppColors.onPrimary, fontSize: 14),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.12),
          hintText: hintText,
          hintStyle: TextStyle(
            color: AppColors.onPrimary.withValues(alpha: 0.5),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: AppColors.onPrimary.withValues(alpha: 0.6),
          ),
          suffixIcon: IconButton(
            tooltip: clearTooltip,
            icon: Icon(
              Icons.clear,
              color: AppColors.onPrimary.withValues(alpha: 0.6),
            ),
            onPressed: onClear,
          ),
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
              color: AppColors.onPrimary.withValues(alpha: 0.3),
            ),
          ),
        ),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
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

class AppCashierSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onScanPressed;

  const AppCashierSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onChanged,
    this.onSubmitted,
    this.onScanPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: SizedBox(
        height: AppSpacing.jumbo,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(color: AppColors.onPrimary, fontSize: 14),
          textInputAction: TextInputAction.done,
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
            suffixIcon: onScanPressed != null
                ? IconButton(
                    icon: Icon(
                      Icons.qr_code_scanner,
                      color: AppColors.onPrimary.withValues(alpha: 0.7),
                      size: AppSpacing.xl,
                    ),
                    tooltip: AppLocalizations.of(context)!.scanBarcode,
                    onPressed: onScanPressed,
                  )
                : null,
          ),
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
        ),
      ),
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

class AppDialogHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onClose;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry? borderRadius;

  const AppDialogHeader({
    super.key,
    required this.title,
    required this.icon,
    this.onClose,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: borderRadius,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.onPrimary, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.onPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
          if (onClose != null) ...[
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              icon: const Icon(
                Icons.close,
                color: AppColors.onPrimary,
                size: 20,
              ),
              onPressed: onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
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

class AppDialogHeaderWithAmount extends StatelessWidget {
  final String title;
  final IconData icon;
  final double amount;
  final VoidCallback? onClose;
  final EdgeInsetsGeometry padding;

  const AppDialogHeaderWithAmount({
    super.key,
    required this.title,
    required this.icon,
    required this.amount,
    this.onClose,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.onPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.onPrimary),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.onPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text.rich(
            PosFormatters.amountRich(
              amount,
              amountStyle: TextStyle(
                color: AppColors.onPrimary.withValues(alpha: 0.9),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (onClose != null) ...[
            const SizedBox(width: AppSpacing.md),
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: const Icon(Icons.close, color: AppColors.onPrimary),
              onPressed: onClose,
            ),
          ],
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
