// features/auth/presentation/login_screen.dart
// WHY: Cashier selection is offline until the Login API is available.

import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_flutter/core/design_system/colors.dart';
import 'package:pos_flutter/core/design_system/spacing.dart';
import 'package:pos_flutter/core/l10n/app_localizations.dart';
import 'package:pos_flutter/features/auth/application/auth_notifier.dart';
import 'package:pos_flutter/features/shift/application/shift_notifier.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_text_field.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_button.dart';

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
  final _usernameController = TextEditingController();
  final _usernameFocus = FocusNode();

  static const _ownerConsoleCommand = 'taha';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _usernameFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _usernameFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSelect() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      return;
    }

    if (username == _ownerConsoleCommand) {
      if (!mounted) return;
      context.go('/owner-console');
      return;
    }

    final authDao = ref.read(authDaoProvider);
    final sessionDao = ref.read(activePosSessionDaoProvider);
    final user = await authDao.findByUsername(username);

    if (user == null) {
      await ref.read(cashierSelectionProvider.notifier).selectCashier(username);
      return;
    }

    final accesses = await sessionDao.listAllowedMachinesForUser(
      custCode: user.custCode,
      userId: user.id,
    );

    if (!mounted) return;

    String? selectedMachineNo;

    if (accesses.length == 1) {
      selectedMachineNo = accesses.single.machineNo;
    } else if (accesses.length > 1) {
      selectedMachineNo = await _chooseMachine(
        accesses.map((e) => e.machineNo).toList(),
      );
      if (selectedMachineNo == null) return;
    } else {
      await ref.read(cashierSelectionProvider.notifier).selectCashier(username);
      return;
    }

    final config = ref.read(posConfigProvider);

    final success = await ref
        .read(cashierSelectionProvider.notifier)
        .selectCashierAndMachine(username, selectedMachineNo);

    if (!mounted || !success) {
      return;
    }

    if (config.useShift) {
      final activeSession = await ref.read(activePosSessionDaoProvider).getActive();
      if (activeSession != null) {
        await ref
            .read(shiftProvider.notifier)
            .loadCurrentShift();
      }
    }

    // Router decides the next page based on ActivePosSession + open shift.
  }

  Future<String?> _chooseMachine(List<String> machineNos) {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Select POS machine'),
          children: [
            for (final machineNo in machineNos)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(machineNo),
                child: Text(machineNo),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cashierSelection = ref.watch(cashierSelectionProvider);
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
                    l10n.cashierSelectionOffline,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.cashierSelectPrompt,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textHint,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const _LoginIdentityCard(),
                  const SizedBox(height: AppSpacing.xxl),
                  if (cashierSelection.errorMessage != null) ...[
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
                              cashierSelection.errorMessage!,
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
                    controller: _usernameController,
                    focusNode: _usernameFocus,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.username],
                    labelText: l10n.userIdOrLoginName,
                    prefixIcon: const Icon(Icons.person_outline),
                    onSubmitted: (_) => _handleSelect(),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  SizedBox(
                    width: double.infinity,
                    height: AppSpacing.jumbo + AppSpacing.xs,
                    child: AppButton.primary(
                      onPressed: cashierSelection.isLoading ? null : _handleSelect,
                      isLoading: cashierSelection.isLoading,
                      label: l10n.selectCashier,
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
                            '${l10n.offlineUsersMustBeSynced}\n'
                            '${l10n.passwordLoginPending}',
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
