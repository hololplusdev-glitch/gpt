// features/auth/presentation/login_screen.dart
// WHY: Login UI only.
// POS session commands live in PosSessionController.
// Runtime truth remains activePosSessionProvider.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:holol_POS/app/router.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/spacing.dart';
import 'package:holol_POS/core/l10n/app_localizations.dart';
import 'package:holol_POS/features/auth/application/pos_session_controller.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
import 'package:holol_POS/shared/presentation/widgets/app_text_field.dart';
import 'package:holol_POS/shared/presentation/widgets/app_dropdown.dart';
import 'package:holol_POS/shared/presentation/widgets/app_info_banner.dart';
import 'package:holol_POS/shared/presentation/dialogs/app_dialog.dart';
import 'package:holol_POS/shared/presentation/widgets/app_numeric_keypad.dart';

final loginIdentityCardProvider = FutureProvider.autoDispose<LoginIdentityInfo>(
  (ref) async {
    final db = ref.watch(databaseProvider);
    final branch = await (db.select(
      db.branchProfile,
    )..limit(1)).getSingleOrNull();

    final companyName = _cleanIdentityText(
      _firstNonEmpty([branch?.commercialName, branch?.nameAr, branch?.name]),
    );

    final branchName = _cleanIdentityText(
      _firstNonEmpty([branch?.nameAr, branch?.name]),
    );

    return LoginIdentityInfo(companyName: companyName, branchName: branchName);
  },
);

class LoginIdentityInfo {
  final String? companyName;
  final String? branchName;

  const LoginIdentityInfo({
    required this.companyName,
    required this.branchName,
  });
}

String? _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
  }

  return null;
}

bool _shouldAutoFocusPosInput(BuildContext context) {
  final media = MediaQuery.maybeOf(context);
  return media != null && media.size.width >= 700;
}

String? _cleanIdentityText(String? value) {
  final trimmed = value?.trim();

  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  final cleaned = trimmed
      .replaceAll(
        RegExp(
          r'\b(oracle|erp|backend|source|sync\s*provider)\b',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(RegExp(r'(Oracle|ORACLE|oracle|أوراكل|اوراكل)'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (cleaned.isEmpty) {
    return null;
  }

  return cleaned;
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _userNumberController = TextEditingController();
  final _userNumberFocus = FocusNode();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _shouldAutoFocusPosInput(context)) {
        _userNumberFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _userNumberController.dispose();
    _userNumberFocus.dispose();
    super.dispose();
  }

  bool _handleOwnerShortcut(String value) {
    if (value.trim() != '1111') return false;

    ref.read(posSessionControllerProvider.notifier).clearError();
    _userNumberController.clear();
    context.go(AppRoutes.ownerConsole);
    return true;
  }

  Future<void> _handleLoginPressed() async {
    if (_handleOwnerShortcut(_userNumberController.text)) {
      return;
    }

    final controller = ref.read(posSessionControllerProvider.notifier);
    final state = ref.read(posSessionControllerProvider);

    if (!state.canLogin) {
      controller.clearError();
      return;
    }

    final hasPin = await controller.hasLocalPinForResolvedUser();

    if (!mounted) return;

    final pin = await _showPinDialog(createMode: !hasPin);

    if (pin == null) return;

    await controller.loginWithPin(pin);
  }

  Future<String?> _showPinDialog({required bool createMode}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      requestFocus: false,
      builder: (context) => _PinEntryDialog(createMode: createMode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(posSessionControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 600;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? AppSpacing.sm : AppSpacing.lg,
              vertical: isCompact ? 0 : AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isCompact ? double.infinity : 480,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Gradient Banner ──
                  if (!isCompact) const SizedBox(height: AppSpacing.lg),
                  Container(
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
                          child: const Icon(
                            Icons.point_of_sale_rounded,
                            color: AppColors.onPrimary,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          l10n.appTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.onPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'دخول محلي برقم المستخدم ونقطة التشغيل',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.onPrimary.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── Card Body ──
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(
                      isCompact ? AppSpacing.lg : AppSpacing.xxl,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      boxShadow: AppSpacing.shadowMd,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _LoginIdentityCard(),
                        const SizedBox(height: AppSpacing.lg),
                        if (sessionState.errorMessage != null) ...[
                          AppInfoBanner.error(
                            message: sessionState.errorMessage!,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        // ── User Number ──
                        AppTextField(
                          controller: _userNumberController,
                          focusNode: _userNumberFocus,
                          textInputAction: TextInputAction.done,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          labelText: 'رقم المستخدم',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          suffixIcon: sessionState.isResolvingUser
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : sessionState.resolvedUser != null
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppColors.success,
                                )
                              : null,
                          onChanged: (value) {
                            if (_handleOwnerShortcut(value)) return;
                            ref
                                .read(posSessionControllerProvider.notifier)
                                .resolveUserNumber(value);
                          },
                          onSubmitted: (value) {
                            if (_handleOwnerShortcut(value)) return;
                            if (sessionState.canLogin) _handleLoginPressed();
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // ── Machine Selection ──
                        AppDropdown<String>(
                          key: ValueKey(
                            '${sessionState.resolvedUser?.id}:${sessionState.selectedMachineNo}:${sessionState.machineChoices.length}',
                          ),
                          value: sessionState.selectedMachineNo,
                          labelText: 'نقطة التشغيل',
                          hintText: sessionState.isResolvingUser
                              ? 'جاري البحث...'
                              : sessionState.machineChoices.isEmpty
                              ? 'أدخل رقم المستخدم أولًا'
                              : 'اختر نقطة التشغيل',
                          prefixIcon: const Icon(Icons.storefront_outlined),
                          items: sessionState.machineChoices
                              .map(
                                (choice) => DropdownMenuItem<String>(
                                  value: choice.machineNo,
                                  child: Text(choice.label),
                                ),
                              )
                              .toList(),
                          onChanged: sessionState.machineChoices.length <= 1
                              ? null
                              : (value) => ref
                                    .read(posSessionControllerProvider.notifier)
                                    .selectMachine(value),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // ── Numeric Keypad (touch screens) ──
                        AppNumericKeypad(
                          controller: _userNumberController,
                          maxLength: 6,
                          onSubmit: sessionState.canLogin
                              ? _handleLoginPressed
                              : null,
                          submitLabel: 'دخول',
                          submitIcon: Icons.login,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // ── Info ──
                        AppInfoBanner.info(
                          message: isCompact
                              ? 'سيُطلب PIN بعد الضغط على دخول.'
                              : 'يتم تحديد نقاط التشغيل من صلاحيات DEVICE_PRIV المحلية. سيُطلب PIN بعد الضغط على دخول.',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const _LoginFooter(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinEntryDialog extends StatefulWidget {
  final bool createMode;

  const _PinEntryDialog({required this.createMode});

  @override
  State<_PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<_PinEntryDialog> {
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
      setState(() => _error = 'PIN يجب أن يكون 4 أرقام.');
      return;
    }

    if (widget.createMode && pin != confirm) {
      setState(() => _error = 'تأكيد PIN غير مطابق.');
      return;
    }

    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.createMode ? 'إنشاء PIN' : 'إدخال PIN',
      icon: Icons.lock_outline,
      confirmLabel: null,
      cancelLabel: 'إلغاء',
      onCancel: () => Navigator.of(context).pop(),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── PIN Display ──
            _PinDotsDisplay(
              length: _pinController.text.length,
              maxLength: 4,
              label: widget.createMode ? 'PIN جديد' : 'PIN',
            ),
            if (widget.createMode) ...[
              const SizedBox(height: AppSpacing.md),
              _PinDotsDisplay(
                length: _confirmController.text.length,
                maxLength: 4,
                label: 'تأكيد PIN',
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppInfoBanner.error(message: _error!),
            ],
            const SizedBox(height: AppSpacing.lg),
            // ── Keypad ──
            AppNumericKeypad(
              controller: widget.createMode && _pinController.text.length >= 4
                  ? _confirmController
                  : _pinController,
              maxLength: 4,
              onSubmit: _submit,
              submitLabel: widget.createMode ? 'حفظ ودخول' : 'دخول',
              submitIcon: Icons.lock_open,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginIdentityCard extends ConsumerWidget {
  const _LoginIdentityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(loginIdentityCardProvider).valueOrNull;

    final companyName = identity?.companyName?.isNotEmpty == true
        ? identity!.companyName!
        : 'اسم الشركة غير محدد';

    final branchName = identity?.branchName?.isNotEmpty == true
        ? identity!.branchName!
        : 'الفرع غير محدد';

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
            child: const Icon(
              Icons.storefront_outlined,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companyName,
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
                  branchName,
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

class _LoginFooter extends StatelessWidget {
  const _LoginFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(color: AppColors.border.withValues(alpha: 0.5)),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.code, size: 14, color: AppColors.textHint),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'تطوير Alboraihi-hololPlus',
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

class _PinDotsDisplay extends StatelessWidget {
  final int length;
  final int maxLength;
  final String label;

  const _PinDotsDisplay({
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
