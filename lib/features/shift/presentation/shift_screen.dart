// features/shift/presentation/shift_screen.dart
// WHY: Shift gate + shift dashboard.
// Runtime SSOT: ActivePosSession.openShiftId.
// This screen never decides current shift from ShiftState.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pos_flutter/app/router.dart';
import 'package:pos_flutter/core/design_system/colors.dart';
import 'package:pos_flutter/core/design_system/layout.dart';
import 'package:pos_flutter/core/design_system/spacing.dart';
import 'package:pos_flutter/core/l10n/app_localizations.dart';
import 'package:pos_flutter/core/persistence/daos/active_pos_session_dao.dart';
import 'package:pos_flutter/core/services/formatters/pos_formatters.dart';
import 'package:pos_flutter/features/auth/application/pos_session_controller.dart';
import 'package:pos_flutter/features/shift/application/shift_controller.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_button.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_info_banner.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_text_field.dart';
import 'package:pos_flutter/shared/presentation/widgets/key_value_row.dart';
import 'package:pos_flutter/shared/presentation/widgets/pos_numeric_keypad.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';

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

    final openShiftId = activeSession?.openShiftId?.trim();
    final hasOpenShift = openShiftId != null && openShiftId.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(hasOpenShift ? 'الشفت الحالي' : l10n.openShift),
        actions: [
          if (hasOpenShift)
            TextButton.icon(
              onPressed: actionState.isLoading
                  ? null
                  : () => context.go(AppRoutes.cashier),
              icon: const Icon(Icons.point_of_sale),
              label: Text(l10n.backToPos),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.paddingLg,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppContentWidth.narrow,
              ),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxxl),
                  child: activeSession == null
                      ? _buildNoSessionView(l10n)
                      : hasOpenShift
                      ? dashboardAsync.when(
                          data: (dashboard) {
                            if (dashboard == null) {
                              return _buildMissingShiftView(actionState, l10n);
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
                        )
                      : _buildOpenShiftView(actionState, activeSession, l10n),
                ),
              ),
            ),
          ),
        ),
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
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildLoadErrorView(Object error) {
    return AppInfoBanner.error(message: error.toString());
  }

  Widget _buildMissingShiftView(
    ShiftCommandState actionState,
    AppLocalizations l10n,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ShiftHeroIcon(icon: Icons.warning_amber, color: AppColors.error),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'تعذر تحميل الشفت الحالي.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'الجلسة تشير إلى شفت غير موجود. سجل خروج ثم ادخل مرة أخرى.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        if (actionState.errorMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppInfoBanner.error(message: actionState.errorMessage!),
        ],
        const SizedBox(height: AppSpacing.xl),
        AppButton.primary(
          onPressed: () => context.go(AppRoutes.login),
          icon: Icons.login,
          label: l10n.login,
        ),
      ],
    );
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
        const SizedBox(height: AppSpacing.md),
        PosNumericKeypad(
          controller: _openingCashController,
          allowDecimal: true,
          decimalPlaces: 2,
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
        _MoneyRow(label: 'إيداعات الصندوق', value: dashboard.cashIn),
        _MoneyRow(label: 'مصروفات الصندوق', value: dashboard.cashOut),
        _MoneyRow(label: 'مردودات كاش', value: dashboard.cashRefund),
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
        PosNumericKeypad(
          controller: _actualCashController,
          allowDecimal: true,
          decimalPlaces: 2,
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
    final cashDouble = double.tryParse(cashText) ?? 0;

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
    final cashDouble = double.tryParse(cashText) ?? 0;

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

class _ShiftHeroIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _ShiftHeroIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: AppSpacing.paddingLg,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppSpacing.borderRadiusLg,
        ),
        child: Icon(icon, color: color, size: AppSpacing.jumbo),
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
      readOnly: true,
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
