import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/spacing.dart';
import 'package:holol_POS/core/services/formatters/pos_formatters.dart';
import 'package:holol_POS/shared/presentation/widgets/app_text_field.dart';
import 'package:holol_POS/shared/presentation/widgets/key_value_row.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/core/l10n/app_localizations.dart';
import 'package:holol_POS/shared/presentation/widgets/app_button.dart';

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
