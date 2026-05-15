// features/auth/presentation/login_screen.dart
// WHY: Login UI only.
// POS session commands live in PosSessionController.
// Runtime truth remains activePosSessionProvider.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/spacing.dart';
import 'package:holol_POS/core/l10n/app_localizations.dart';
import 'package:holol_POS/features/auth/application/pos_session_controller.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
import 'package:holol_POS/shared/presentation/widgets/app_text_field.dart';
import 'package:holol_POS/shared/presentation/widgets/app_dropdown.dart';
import 'package:holol_POS/shared/presentation/widgets/app_info_banner.dart';
import 'package:holol_POS/shared/presentation/widgets/app_numeric_keypad.dart';
import 'package:holol_POS/shared/refactor/pos_ui_widgets.dart';

final loginIdentityCardProvider = FutureProvider.autoDispose<LoginIdentityInfo>(
  (ref) async {
    final db = ref.watch(databaseProvider);
    final branch = await (db.select(
      db.branchProfile,
    )..limit(1)).getSingleOrNull();

    final companyName = PosLoginIdentityText.clean(
      PosLoginIdentityText.firstNonEmpty([
        branch?.commercialName,
        branch?.nameAr,
        branch?.name,
      ]),
    );

    final branchName = PosLoginIdentityText.clean(
      PosLoginIdentityText.firstNonEmpty([branch?.nameAr, branch?.name]),
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

bool _shouldAutoFocusPosInput(BuildContext context) {
  final media = MediaQuery.maybeOf(context);
  return media != null && media.size.width >= 700;
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

    // Listen to controller changes from BOTH physical keyboard and touch keypad
    _userNumberController.addListener(_onUserNumberChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _shouldAutoFocusPosInput(context)) {
        _userNumberFocus.requestFocus();
      }
    });
  }

  void _onUserNumberChanged() {
    final value = _userNumberController.text;
    ref.read(posSessionControllerProvider.notifier).resolveUserNumber(value);
  }

  @override
  void dispose() {
    _userNumberController.removeListener(_onUserNumberChanged);
    _userNumberController.dispose();
    _userNumberFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLoginPressed() async {
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
      builder: (context) => AppPinEntryDialog(createMode: createMode),
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
                  if (!isCompact) const SizedBox(height: AppSpacing.lg),
                  AppLoginBanner(
                    title: l10n.appTitle,
                    subtitle: 'دخول محلي برقم المستخدم ونقطة التشغيل',
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
                          onChanged: (_) {
                            // Handled by _onUserNumberChanged listener
                          },
                          onSubmitted: (value) {
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
                        const AppBrandFooter(text: 'تطوير Alboraihi-hololPlus'),
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

    return AppIdentityCard(title: companyName, subtitle: branchName);
  }
}
