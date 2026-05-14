import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:holol_POS/app/router.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/l10n/app_localizations.dart';
import 'package:holol_POS/core/constants/app_identity.dart';
import 'package:holol_POS/core/design_system/layout.dart';
import 'package:holol_POS/core/design_system/spacing.dart';
import 'package:holol_POS/features/setup/application/setup_notifier.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/shared/presentation/widgets/app_section_card.dart';
import 'package:holol_POS/shared/presentation/dialogs/app_dialog.dart';

/// WHY: Settings screen is READ-ONLY for connection. Connection editing
/// is only done through Setup (DRY principle). To change connection,
/// the user must Reset Setup and re-run the wizard.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final setupState = ref.watch(setupProvider).valueOrNull;
    final connection = setupState?.syncProfile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l10n.settings)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppContentWidth.standard),
          child: ListView(
            padding: AppSpacing.paddingLg,
            children: [
              AppSectionCard(
                title: l10n.connection,
                icon: Icons.dns,
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.computer,
                      title: l10n.serverConnection,
                      subtitle: connection != null
                          ? connection.baseUrl
                          : l10n.notConfigured,
                      trailing: _StatusDot(
                        status: connection?.isValidated == true
                            ? HealthStatus.ok
                            : connection != null
                            ? HealthStatus.degraded
                            : HealthStatus.unknown,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppSectionCard(
                title: l10n.devices,
                icon: Icons.devices,
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.point_of_sale,
                      title: l10n.posDevices,
                      subtitle: l10n.posDevicesSubtitle,
                      onTap: () {
                        context.push(AppRoutes.posDevices);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppSectionCard(
                title: 'المبيعات',
                icon: Icons.point_of_sale,
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.analytics_outlined,
                      title: 'الشفت الحالي',
                      subtitle: 'عرض ملخص الشفت وإغلاقه',
                      onTap: () {
                        context.push(AppRoutes.shift);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppSectionCard(
                title: l10n.general,
                icon: Icons.tune,
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.language,
                      title: l10n.languageLabel,
                      subtitle: setupState?.language == 'ar'
                          ? l10n.arabic
                          : l10n.english,
                      onTap: () async {
                        final newLang = setupState?.language == 'ar'
                            ? 'en'
                            : 'ar';
                        await ref
                            .read(setupProvider.notifier)
                            .setLanguage(newLang);
                      },
                    ),
                    _SettingsTile(
                      icon: Icons.info_outline,
                      title: l10n.about,
                      subtitle: l10n.versionLabel(AppIdentity.version),
                      onTap: () {
                        showAboutDialog(
                          context: context,
                          applicationName: AppIdentity.appName,
                          applicationVersion: AppIdentity.version,
                          applicationLegalese: AppIdentity.legalese,
                          applicationIcon: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.secondary,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: AppSpacing.borderRadiusMd,
                            ),
                            child: const Icon(
                              Icons.point_of_sale,
                              color: AppColors.onPrimary,
                              size: 28,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppSectionCard(
                title: l10n.dangerZone,
                icon: Icons.warning_amber,
                titleColor: AppColors.error,
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.restart_alt,
                      title: l10n.resetSetup,
                      subtitle: l10n.resetSetupSubtitle,
                      iconColor: AppColors.error,
                      onTap: () async {
                        final confirmed = await AppDialog.show<bool>(
                          context: context,
                          dialog: AppDialog.warning(
                            title: l10n.resetSetupQuestion,
                            content: Text(l10n.resetSetupWarning),
                            confirmLabel: l10n.reset,
                            cancelLabel: l10n.cancel,
                          ),
                        );
                        if (confirmed == true) {
                          await ref.read(setupProvider.notifier).resetSetup();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Color? iconColor;
  final VoidCallback? onTap;

  const _SettingsTile({
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

class _StatusDot extends StatefulWidget {
  final HealthStatus status;

  const _StatusDot({required this.status});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    // Only pulse for active (ok) status.
    if (widget.status == HealthStatus.ok) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _StatusDot oldWidget) {
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

  @override
  Widget build(BuildContext context) {
    final color = switch (widget.status) {
      HealthStatus.ok => AppColors.success,
      HealthStatus.degraded => AppColors.warning,
      HealthStatus.down => AppColors.error,
      HealthStatus.unknown => AppColors.textHint,
    };

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
