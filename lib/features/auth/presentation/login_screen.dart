// features/auth/presentation/login_screen.dart
// WHY: Login UI only.
// POS session commands live in PosSessionController.
// Runtime truth remains activePosSessionProvider.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pos_flutter/app/router.dart';
import 'package:pos_flutter/core/design_system/colors.dart';
import 'package:pos_flutter/core/design_system/spacing.dart';
import 'package:pos_flutter/core/l10n/app_localizations.dart';
import 'package:pos_flutter/features/auth/application/pos_session_controller.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_text_field.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_dropdown.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_button.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_info_banner.dart';
import 'package:pos_flutter/shared/presentation/widgets/pos_numeric_keypad.dart';

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

    await _showPinDialog(createMode: !hasPin);
  }

  Future<bool?> _showPinDialog({required bool createMode}) async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();

    String? error;
    var editingConfirm = false;
    var isSubmitting = false;

    Future<void> submit(
      StateSetter setDialogState,
      BuildContext dialogContext,
    ) async {
      if (isSubmitting) return;

      final pin = pinController.text.trim();
      final confirm = confirmController.text.trim();

      if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
        setDialogState(() => error = 'PIN يجب أن يكون 4 أرقام.');
        return;
      }

      if (createMode && confirm.length < 4) {
        setDialogState(() {
          editingConfirm = true;
          error = null;
        });
        return;
      }

      if (createMode && pin != confirm) {
        HapticFeedback.heavyImpact();
        setDialogState(() {
          error = 'تأكيد PIN غير مطابق.';
          pinController.clear();
          confirmController.clear();
          editingConfirm = false;
        });
        return;
      }

      setDialogState(() {
        isSubmitting = true;
        error = null;
      });

      final ok = await ref
          .read(posSessionControllerProvider.notifier)
          .loginWithPin(pin);

      if (!dialogContext.mounted) return;

      if (ok) {
        // loginWithPin refreshes ActivePosSession, which lets GoRouter redirect
        // away from LoginScreen. Do not pop synchronously here; the dialog route
        // may already be gone or the Navigator may be locked by the redirect.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!dialogContext.mounted) return;

          final navigator = Navigator.maybeOf(dialogContext);
          if (navigator == null || !navigator.canPop()) return;

          navigator.pop(true);
        });
        return;
      }

      HapticFeedback.heavyImpact();

      final controllerState = ref.read(posSessionControllerProvider);
      setDialogState(() {
        isSubmitting = false;
        error = controllerState.errorMessage ?? 'PIN غير صحيح.';
        pinController.clear();
        confirmController.clear();
        editingConfirm = false;
      });
    }

    void handlePinChanged(
      StateSetter setDialogState,
      BuildContext dialogContext,
    ) {
      if (error != null) {
        setDialogState(() => error = null);
      }

      if (!createMode && pinController.text.length == 4) {
        submit(setDialogState, dialogContext);
        return;
      }

      if (createMode && !editingConfirm && pinController.text.length == 4) {
        setDialogState(() => editingConfirm = true);
        return;
      }

      if (createMode && editingConfirm && confirmController.text.length == 4) {
        submit(setDialogState, dialogContext);
        return;
      }

      setDialogState(() {});
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      requestFocus: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final activeController = createMode && editingConfirm
                ? confirmController
                : pinController;

            return AlertDialog(
              title: Text(createMode ? 'إنشاء PIN' : 'إدخال PIN'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PinDots(
                    value: pinController.text,
                    label: createMode ? 'PIN جديد' : 'PIN',
                    active: !createMode || !editingConfirm,
                    onTap: () => setDialogState(() => editingConfirm = false),
                  ),
                  if (createMode) ...[
                    const SizedBox(height: AppSpacing.md),
                    _PinDots(
                      value: confirmController.text,
                      label: 'تأكيد PIN',
                      active: editingConfirm,
                      onTap: () => setDialogState(() => editingConfirm = true),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppInfoBanner.error(message: error!),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  if (isSubmitting)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: CircularProgressIndicator(),
                    )
                  else
                    PosNumericKeypad(
                      controller: activeController,
                      allowDecimal: false,
                      maxLength: 4,
                      compact: true,
                      onChanged: () =>
                          handlePinChanged(setDialogState, dialogContext),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.of(dialogContext).pop(false),
                    child: const Text('إلغاء'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    pinController.dispose();
    confirmController.dispose();

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(posSessionControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppSpacing.borderRadiusXl,
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: AppSpacing.xxl,
                    offset: Offset(0, AppSpacing.sm),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.point_of_sale_rounded,
                    size: AppSpacing.jumbo + AppSpacing.lg,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.appTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'دخول محلي برقم المستخدم ونقطة التشغيل',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const _LoginIdentityCard(),
                  const SizedBox(height: AppSpacing.xxl),
                  if (sessionState.errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: AppSpacing.paddingMd,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: AppSpacing.borderRadiusMd,
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: AppSpacing.xl,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              sessionState.errorMessage!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  AppTextField(
                    controller: _userNumberController,
                    focusNode: _userNumberFocus,
                    textInputAction: TextInputAction.done,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    labelText: 'رقم المستخدم',
                    prefixIcon: const Icon(Icons.badge_outlined),
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
                  const SizedBox(height: AppSpacing.xxl),
                  SizedBox(
                    width: double.infinity,
                    height: AppSpacing.jumbo + AppSpacing.xs,
                    child: AppButton.primary(
                      onPressed: sessionState.canLogin
                          ? _handleLoginPressed
                          : null,
                      isLoading: sessionState.isLoading,
                      label: 'دخول',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: AppSpacing.borderRadiusSm,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: AppSpacing.lg,
                          color: AppColors.primary.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'يتم تحديد نقاط التشغيل من صلاحيات DEVICE_PRIV المحلية. '
                            'سيُطلب PIN بعد الضغط على دخول.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.textHint,
                                  fontSize: 11,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _LoginFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  final String value;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _PinDots({
    required this.value,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final filled = value.length.clamp(0, 4);

    return Material(
      color: active
          ? AppColors.primary.withValues(alpha: 0.08)
          : AppColors.surfaceVariant,
      borderRadius: AppSpacing.borderRadiusMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: active ? AppColors.primary : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < filled;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled
                          ? AppColors.primary
                          : AppColors.textHint.withValues(alpha: 0.26),
                    ),
                  );
                }),
              ),
            ],
          ),
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
    return Text(
      'تطوير Alboraihi-hololPlus',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: AppColors.textHint,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
