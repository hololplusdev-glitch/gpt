// features/shift/presentation/shift_screen.dart
// WHY: Shift management UI - open/close shift with cash amounts.
// Enforces the business rule: no selling without an open shift.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pos_flutter/app/router.dart';
import 'package:pos_flutter/core/design_system/colors.dart';
import 'package:pos_flutter/core/design_system/layout.dart';
import 'package:pos_flutter/core/design_system/spacing.dart';
import 'package:pos_flutter/core/l10n/app_localizations.dart';
import 'package:pos_flutter/core/services/formatters/pos_formatters.dart';
import 'package:pos_flutter/features/auth/application/auth_notifier.dart';
import 'package:pos_flutter/features/shift/application/shift_notifier.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_info_banner.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_button.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_text_field.dart';
import 'package:pos_flutter/shared/presentation/widgets/key_value_row.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';

class ShiftScreen extends ConsumerStatefulWidget {
  const ShiftScreen({super.key});

  @override
  ConsumerState<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends ConsumerState<ShiftScreen> {
  final _cashController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isClosing = false;

  @override
  void dispose() {
    _cashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shiftState = ref.watch(shiftProvider);
    final authState = ref.watch(authProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(shiftState.hasOpenShift ? l10n.closeShift : l10n.openShift),
        actions: [
          if (shiftState.hasOpenShift)
            TextButton.icon(
              onPressed: () => context.go(AppRoutes.cashier),
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
                  child: shiftState.hasOpenShift
                      ? _buildCloseShiftView(shiftState, authState, l10n)
                      : _buildOpenShiftView(shiftState, authState, l10n),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOpenShiftView(
    ShiftState shiftState,
    AuthState authState,
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
          l10n.cashierNameLabel(
            authState.session?.displayName ?? l10n.unknownCashier,
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xxl),
        _AmountField(
          controller: _cashController,
          label: l10n.openingCashSar,
          hintText: l10n.zeroAmountHint,
          autofocus: true,
        ),
        if (shiftState.errorMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppInfoBanner.error(message: shiftState.errorMessage!),
        ],
        const SizedBox(height: AppSpacing.xxl),
        SizedBox(
          height: AppSpacing.jumbo + AppSpacing.sm,
          child: AppButton.primary(
            onPressed: shiftState.isLoading
                ? null
                : () => _openShift(authState),
            isLoading: shiftState.isLoading,
            icon: Icons.play_arrow,
            label: shiftState.isLoading ? l10n.openingShift : l10n.openShift,
          ),
        ),
      ],
    );
  }

  Widget _buildCloseShiftView(
    ShiftState shiftState,
    AuthState authState,
    AppLocalizations l10n,
  ) {
    final shift = shiftState.activeShift!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ShiftHeroIcon(icon: Icons.lock_clock, color: AppColors.warning),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.closeShift,
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
        const SizedBox(height: AppSpacing.lg),
        KeyValueRow(
          label: l10n.openingCash,
          value: PosFormatters.amount(shift.openingCash),
          verticalPadding: AppSpacing.xs,
        ),

        // WHY: Blind Close Policy
        // Gross Sales is intentionally hidden here to prevent cashiers from knowing
        // the exact expected cash in drawer, enforcing an honest manual count.
        Container(
          margin: const EdgeInsets.only(top: AppSpacing.md),
          padding: AppSpacing.paddingMd,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: AppSpacing.borderRadiusSm,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.security,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Blind Close: Expected sales are hidden for security.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: AppSpacing.xxxl),
        _AmountField(
          controller: _cashController,
          enabled: !shiftState.isLoading && !_isClosing,
          label: l10n.actualCashInDrawerSar,
          hintText: l10n.zeroAmountHint,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _notesController,
          enabled: !shiftState.isLoading && !_isClosing,
          maxLines: 2,
          labelText: l10n.closingNotesOptional,
          prefixIcon: const Icon(Icons.notes_outlined),
        ),
        if (shiftState.errorMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppInfoBanner.error(message: shiftState.errorMessage!),
        ],
        const SizedBox(height: AppSpacing.xxl),
        SizedBox(
          height: AppSpacing.jumbo + AppSpacing.sm,
          child: AppButton.warning(
            onPressed: shiftState.isLoading || _isClosing
                ? null
                : () => _closeShift(authState),
            isLoading: shiftState.isLoading,
            icon: Icons.stop,
            label: shiftState.isLoading ? l10n.closingShift : l10n.closeShift,
          ),
        ),
      ],
    );
  }

  Future<void> _openShift(AuthState authState) async {
    final cashText = _cashController.text.trim();
    final cashDouble = double.tryParse(cashText) ?? 0;
    final session = authState.session;
    if (session == null) {
      return;
    }

    final success = await ref
        .read(shiftProvider.notifier)
        .openShift(
          terminalId: ref.read(activeMachineProvider).activeMachineNo,
          cashierId: session.userId,
          cashierName: session.displayName,
          openingCash: cashDouble,
        );

    if (success && mounted) {
      context.go(AppRoutes.cashier);
    }
  }

  Future<void> _closeShift(AuthState authState) async {
    setState(() => _isClosing = true);
    final cashText = _cashController.text.trim();
    final cashDouble = double.tryParse(cashText) ?? 0;
    final session = authState.session;
    if (session == null) {
      if (mounted) {
        setState(() => _isClosing = false);
      }
      return;
    }

    final success = await ref
        .read(shiftProvider.notifier)
        .closeShift(
          actualCash: cashDouble,
          cashierId: session.userId,
          cashierName: session.displayName,
          terminalId: ref.read(activeMachineProvider).activeMachineNo,
          closingNotes: _notesController.text.trim(),
        );

    if (mounted) {
      setState(() => _isClosing = false);
      if (success) {
        context.go(AppRoutes.login);
      }
    }
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
