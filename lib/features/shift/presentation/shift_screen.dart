// features/shift/presentation/shift_screen.dart
// WHY: Shift gate + shift dashboard.
// Runtime SSOT: Shifts table via activeShiftDashboardProvider.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:holol_POS/app/router.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/layout.dart';
import 'package:holol_POS/core/design_system/spacing.dart';
import 'package:holol_POS/core/l10n/app_localizations.dart';
import 'package:holol_POS/core/persistence/daos/active_pos_session_dao.dart';
import 'package:holol_POS/core/services/formatters/pos_formatters.dart';
import 'package:holol_POS/features/auth/application/pos_session_controller.dart';
import 'package:holol_POS/features/shift/application/shift_controller.dart';
import 'package:holol_POS/shared/presentation/widgets/app_button.dart';
import 'package:holol_POS/shared/presentation/widgets/app_info_banner.dart';
import 'package:holol_POS/shared/presentation/widgets/app_text_field.dart';
import 'package:holol_POS/shared/presentation/widgets/key_value_row.dart';
import 'package:holol_POS/shared/presentation/widgets/app_loading.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';

class ShiftScreen extends ConsumerStatefulWidget {
  const ShiftScreen({super.key});

  @override
  ConsumerState<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends ConsumerState<ShiftScreen> {
  final _openingCashController = TextEditingController();
  final _actualCashController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(shiftControllerProvider.notifier).clearError();
    });
  }

  @override
  void dispose() {
    _openingCashController.dispose();
    _actualCashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(shiftControllerProvider);
    final activeSession = ref.watch(activePosSessionProvider).valueOrNull;
    final dashboardAsync = ref.watch(activeShiftDashboardProvider);
    final l10n = AppLocalizations.of(context)!;

    final dashboard = dashboardAsync.valueOrNull;
    final hasOpenShift = dashboard != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Gradient Header ──
          Container(
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
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.onPrimary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        hasOpenShift
                            ? Icons.analytics_outlined
                            : Icons.play_circle_outline,
                        color: AppColors.onPrimary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      hasOpenShift ? 'الشفت الحالي' : l10n.openShift,
                      style: const TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (hasOpenShift)
                      FilledButton.icon(
                        onPressed: actionState.isLoading
                            ? null
                            : () => context.go(AppRoutes.cashier),
                        icon: const Icon(Icons.point_of_sale, size: 18),
                        label: Text(l10n.backToPos),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          foregroundColor: AppColors.onPrimary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // ── Body ──
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: AppSpacing.paddingLg,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppContentWidth.narrow,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppSpacing.borderRadiusLg,
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppSpacing.shadowMd,
                    ),
                    child: activeSession == null
                        ? _buildNoSessionView(l10n)
                        : dashboardAsync.when(
                            data: (dashboard) {
                              if (dashboard == null) {
                                return _buildOpenShiftView(
                                  actionState,
                                  activeSession,
                                  l10n,
                                );
                              }

                              return _buildShiftDashboardView(
                                dashboard,
                                actionState,
                                activeSession,
                                l10n,
                              );
                            },
                            loading: _buildLoadingView,
                            error: (error, _) => _buildLoadErrorView(error),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSessionView(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ShiftHeroIcon(icon: Icons.person_off, color: AppColors.warning),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'لا توجد جلسة تشغيل نشطة.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton.primary(
          onPressed: () => context.go(AppRoutes.login),
          icon: Icons.login,
          label: l10n.login,
        ),
      ],
    );
  }

  Widget _buildLoadingView() {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.xxxl),
      child: AppLoading(),
    );
  }

  Widget _buildLoadErrorView(Object error) {
    return AppInfoBanner.error(message: error.toString());
  }

  Widget _buildOpenShiftView(
    ShiftCommandState actionState,
    ActivePosSession activeSession,
    AppLocalizations l10n,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ShiftHeroIcon(
          icon: Icons.access_time_filled,
          color: AppColors.info,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.openNewShift,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.cashierNameLabel(activeSession.activeUserName),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'نقطة التشغيل: ${activeSession.activeMachineName}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xxl),
        _AmountField(
          controller: _openingCashController,
          label: l10n.openingCashSar,
          hintText: l10n.zeroAmountHint,
          autofocus: false,
          enabled: !actionState.isLoading,
        ),
        if (actionState.errorMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppInfoBanner.error(message: actionState.errorMessage!),
        ],
        const SizedBox(height: AppSpacing.xxl),
        SizedBox(
          height: AppSpacing.jumbo + AppSpacing.sm,
          child: AppButton.primary(
            onPressed: actionState.isLoading ? null : _openShift,
            isLoading: actionState.isLoading,
            icon: Icons.play_arrow,
            label: actionState.isLoading ? l10n.openingShift : l10n.openShift,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton.icon(
          onPressed: actionState.isLoading ? null : _logoutFromShiftGate,
          icon: const Icon(Icons.logout),
          label: const Text('تسجيل الخروج'),
        ),
      ],
    );
  }

  Widget _buildShiftDashboardView(
    ShiftDashboard dashboard,
    ShiftCommandState actionState,
    ActivePosSession activeSession,
    AppLocalizations l10n,
  ) {
    final shift = dashboard.shift;
    final totals = dashboard.totals;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ShiftHeroIcon(icon: Icons.analytics, color: AppColors.success),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'ملخص الشفت الحالي',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.openedAtLabel(PosFormatters.dateTime(shift.openedAt)),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${activeSession.activeUserName} • ${activeSession.activeMachineName}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const Divider(height: AppSpacing.xxxl),
        _SectionTitle('الصندوق'),
        _MoneyRow(label: l10n.openingCash, value: shift.openingCash),
        _MoneyRow(label: 'مبيعات الكاش', value: totals.cashSales),
        const Divider(height: AppSpacing.xl),
        _MoneyRow(
          label: 'المتوقع في الصندوق',
          value: dashboard.expectedCash,
          isStrong: true,
        ),
        const SizedBox(height: AppSpacing.lg),
        _SectionTitle('المبيعات'),
        _CountRow(label: 'عدد الفواتير', value: totals.saleCount),
        _MoneyRow(label: 'إجمالي المبيعات', value: totals.grossSales),
        _MoneyRow(label: 'صافي المبيعات', value: totals.netSales),
        _MoneyRow(label: 'الشبكة / البطاقات', value: totals.cardSales),
        _MoneyRow(label: 'آجل / طرق أخرى', value: totals.otherSales),
        _MoneyRow(label: 'مرتجعات نقدية', value: totals.cashReturns),
        _MoneyRow(label: 'الخصومات', value: totals.totalDiscounts),
        _MoneyRow(label: 'الضريبة', value: totals.totalTaxes),
        _MoneyRow(label: 'المرتجعات', value: totals.totalReturns),
        _MoneyRow(label: 'الملغيات', value: totals.totalVoids),
        const Divider(height: AppSpacing.xxxl),
        _AmountField(
          controller: _actualCashController,
          enabled: !actionState.isLoading,
          label: l10n.actualCashInDrawerSar,
          hintText: l10n.zeroAmountHint,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _notesController,
          enabled: !actionState.isLoading,
          maxLines: 2,
          labelText: l10n.closingNotesOptional,
          prefixIcon: const Icon(Icons.notes_outlined),
        ),
        if (actionState.errorMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppInfoBanner.error(message: actionState.errorMessage!),
        ],
        const SizedBox(height: AppSpacing.xxl),
        SizedBox(
          height: AppSpacing.jumbo + AppSpacing.sm,
          child: AppButton.warning(
            onPressed: actionState.isLoading
                ? null
                : () => _closeShift(shift.id),
            isLoading: actionState.isLoading,
            icon: Icons.stop,
            label: actionState.isLoading ? l10n.closingShift : l10n.closeShift,
          ),
        ),
      ],
    );
  }

  Future<void> _logoutFromShiftGate() async {
    await ref.read(posSessionControllerProvider.notifier).logout();

    if (!mounted) return;

    context.go(AppRoutes.login);
  }

  Future<void> _openShift() async {
    final cashText = _openingCashController.text.trim();
    final cashDouble = cashText.isEmpty ? 0.0 : double.tryParse(cashText);
    if (cashDouble == null || cashDouble < 0) {
      ref
          .read(shiftControllerProvider.notifier)
          .setError('أدخل مبلغ افتتاح صحيح.');
      return;
    }

    final result = await ref
        .read(shiftControllerProvider.notifier)
        .openShift(openingCash: cashDouble);

    if (!mounted) return;

    if (result.success) {
      _openingCashController.clear();
      ref.invalidate(activeShiftDashboardProvider);
      context.go(AppRoutes.cashier);
    }
  }

  Future<void> _closeShift(String shiftId) async {
    final cashText = _actualCashController.text.trim();
    final cashDouble = cashText.isEmpty ? null : double.tryParse(cashText);
    if (cashDouble == null || cashDouble < 0) {
      ref
          .read(shiftControllerProvider.notifier)
          .setError('أدخل النقد الفعلي في الدرج.');
      return;
    }

    final result = await ref
        .read(shiftControllerProvider.notifier)
        .closeShift(
          shiftId: shiftId,
          actualCash: cashDouble,
          closingNotes: _notesController.text.trim(),
        );

    if (!mounted) return;

    if (result.success) {
      _actualCashController.clear();
      _notesController.clear();
      ref.invalidate(activeShiftDashboardProvider);
      context.go(AppRoutes.shift);
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

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

class _MoneyRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isStrong;

  const _MoneyRow({
    required this.label,
    required this.value,
    this.isStrong = false,
  });

  @override
  Widget build(BuildContext context) {
    return KeyValueRow(
      label: label,
      value: PosFormatters.amount(value),
      verticalPadding: AppSpacing.xs,
      strong: isStrong,
      valueColor: isStrong ? AppColors.primary : null,
    );
  }
}

class _CountRow extends StatelessWidget {
  final String label;
  final int value;

  const _CountRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return KeyValueRow(
      label: label,
      value: value.toString(),
      verticalPadding: AppSpacing.xs,
    );
  }
}

class _ShiftHeroIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _ShiftHeroIcon({required this.icon, required this.color});

  @override
  State<_ShiftHeroIcon> createState() => _ShiftHeroIconState();
}

class _ShiftHeroIconState extends State<_ShiftHeroIcon>
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
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(widget.icon, color: widget.color, size: 36),
        ),
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String hintText;
  final bool autofocus;
  final bool enabled;

  const _AmountField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.autofocus = false,
    this.enabled = true,
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
      textAlign: TextAlign.center,
      labelText: label,
      hintText: hintText,
      prefixIcon: const Icon(Icons.payments_outlined),
    );
  }
}
