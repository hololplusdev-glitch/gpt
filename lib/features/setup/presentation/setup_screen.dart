import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/spacing.dart';
import 'package:holol_POS/core/l10n/app_localizations.dart';
import 'package:holol_POS/features/setup/application/setup_notifier.dart';
import 'package:holol_POS/core/network/network_models.dart';
import 'package:holol_POS/shared/presentation/widgets/app_switch.dart';
import 'package:holol_POS/shared/presentation/widgets/app_loading.dart';
import 'package:holol_POS/shared/presentation/widgets/app_text_field.dart';
import 'package:holol_POS/shared/presentation/widgets/app_button.dart';
import 'package:holol_POS/shared/presentation/widgets/app_info_banner.dart';
import 'package:holol_POS/shared/presentation/widgets/responsive_row.dart';
import 'package:holol_POS/shared/presentation/dialogs/app_dialog.dart';
import 'package:holol_POS/shared/refactor/pos_ui_widgets.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  int _step = 0;
  bool _useFullUrl = true;
  final _fullUrlController = TextEditingController(
    text: 'https://2481.extrasolutionscloud.com/ords/erp/pos-api/v1',
  );
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _basePathController = TextEditingController(
    text: '/ords/erp/pos-api/v1',
  );
  // WHY: Pre-filled with test defaults for faster first-run testing.
  // These are NOT production constants — users can freely edit them.
  final _custCodeController = TextEditingController(text: '1001');
  bool _useSsl = true;
  bool _testing = false;
  String? _message;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _fullUrlController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _basePathController.dispose();
    _custCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(setupProvider).valueOrNull;
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
                maxWidth: isCompact ? double.infinity : 780,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Gradient Banner ──
                  if (!isCompact) const SizedBox(height: AppSpacing.lg),
                  AppSetupBanner(step: _step, l10n: l10n),
                  // ── Stepper Dots ──
                  AppStepperIndicator(currentStep: _step),
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: KeyedSubtree(
                            key: ValueKey(_step),
                            child: _buildStep(setup, l10n),
                          ),
                        ),
                        if (_message != null ||
                            setup?.errorMessage != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          AppInfoBanner.error(
                            message: _message ?? setup!.errorMessage!,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        AppSetupBottomActions(
                          isCompact: isCompact,
                          showBack: _step > 0,
                          canGoBack: !_testing,
                          isSetupLoading: setup?.isLoading ?? false,
                          isTesting: _testing,
                          primaryLabel: _testing
                              ? 'جاري التحقق من الاتصال...'
                              : (_step == 2
                                    ? 'بدء تهيئة بيانات التشغيل'
                                    : l10n.next),
                          onBack: () => setState(() => _step--),
                          onPrimary: () => _next(setup, l10n),
                          backLabel: l10n.back,
                        ),
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

  Widget _buildStep(SetupState? setup, AppLocalizations l10n) {
    if (_step == 0) {
      final selected = setup?.language ?? 'en';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'اختر لغة واجهة التطبيق',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppLanguageCard(
                  label: 'English',
                  subtitle: 'Use English interface',
                  icon: '🇺🇸',
                  isSelected: selected == 'en',
                  onTap: () =>
                      ref.read(setupProvider.notifier).setLanguage('en'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppLanguageCard(
                  label: 'العربية',
                  subtitle: 'استخدام الواجهة العربية',
                  icon: '🇸🇦',
                  isSelected: selected == 'ar',
                  onTap: () =>
                      ref.read(setupProvider.notifier).setLanguage('ar'),
                ),
              ),
            ],
          ),
        ],
      );
    }
    if (_step == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Section: Connection Mode ──
          AppSectionLabel(icon: Icons.link, label: l10n.fullUrlMode),
          const SizedBox(height: AppSpacing.sm),
          AppSwitchListTile(
            title: l10n.fullUrlMode,
            subtitle: l10n.fullUrlSubtitle,
            value: _useFullUrl,
            onChanged: (value) => setState(() => _useFullUrl = value),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Section: Server URL ──
          AppSectionLabel(
            icon: Icons.dns_outlined,
            label: _useFullUrl ? l10n.apiBaseUrl : l10n.hostOrIp,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_useFullUrl) ...[
            AppTextField(
              controller: _fullUrlController,
              labelText: l10n.apiBaseUrl,
              hintText: l10n.apiBaseUrlExample,
              helperText: l10n.baseUrlHint,
              prefixIcon: const Icon(Icons.language),
            ),
          ] else ...[
            ResponsiveRow(
              children: [
                Expanded(
                  flex: 3,
                  child: AppTextField(
                    controller: _hostController,
                    labelText: l10n.hostOrIp,
                    prefixIcon: const Icon(Icons.computer),
                  ),
                ),
                AppTextField(
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  labelText: l10n.port,
                  hintText: l10n.optional,
                  prefixIcon: const Icon(Icons.tag),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _basePathController,
              labelText: l10n.apiBasePath,
              hintText: l10n.apiBasePathExample,
              prefixIcon: const Icon(Icons.folder_outlined),
            ),
            const SizedBox(height: AppSpacing.md),
            AppSwitchListTile(
              title: l10n.https,
              value: _useSsl,
              onChanged: (value) => setState(() => _useSsl = value),
              contentPadding: EdgeInsets.zero,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),

          // ── Section: Company Code ──
          AppSectionLabel(icon: Icons.business, label: l10n.customerCode),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _custCodeController,
            labelText: l10n.customerCode,
            prefixIcon: const Icon(Icons.badge_outlined),
          ),

          // ── Testing Indicator ──
          if (_testing) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: AppSpacing.borderRadiusMd,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: const [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: AppLoading(color: AppColors.primary),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'جاري التحقق من الرابط وكود الشركة...',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }
    final isSyncing = setup?.isLoading ?? false;
    final isComplete = setup?.isSetupComplete ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Success Card ──
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: AppColors.successGradient,
            borderRadius: AppSpacing.borderRadiusLg,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  isComplete
                      ? l10n.setupSuccess
                      : 'تم التحقق من الاتصال بنجاح!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isSyncing) ...[
          const SizedBox(height: AppSpacing.lg),
          // ── Feature list ──
          AppReadinessFeature(
            icon: Icons.cloud_download_outlined,
            title: 'تحميل بيانات التشغيل',
            subtitle: 'المنتجات والأسعار والعملاء',
          ),
          AppReadinessFeature(
            icon: Icons.wifi_off_outlined,
            title: 'العمل بدون إنترنت',
            subtitle: 'بعد التحميل يمكنك العمل offline',
          ),
          AppReadinessFeature(
            icon: Icons.print_outlined,
            title: l10n.setupPrintersLater,
            subtitle: 'يمكن إعدادها بعد التهيئة',
          ),
        ],
        if (isSyncing) ...[
          const SizedBox(height: AppSpacing.xxl),
          _buildSyncDashboard(setup, l10n),
        ],
      ],
    );
  }

  Widget _buildSyncDashboard(SetupState? setup, AppLocalizations l10n) {
    final progress = setup?.syncProgress ?? 0.0;
    final percent = (progress * 100).clamp(0, 100).toInt();
    final status = setup?.syncStatus ?? l10n.preparing;
    final isDone = percent == 100;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(
          color: isDone
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.primary.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: (isDone ? AppColors.success : AppColors.primary).withValues(
              alpha: 0.05,
            ),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: MediaQuery.sizeOf(context).width < 600
                    ? double.infinity
                    : 360,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDone ? l10n.setupSuccess : 'تحميل بيانات التشغيل',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: isDone ? AppColors.success : AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      status,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  if (!isDone &&
                      setup?.syncPagination != null &&
                      setup!.syncPagination!.isNotEmpty) ...[
                    Text(
                      setup.syncPagination!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDone ? AppColors.success : AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$percent%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.surfaceVariant,
              color: isDone ? AppColors.success : AppColors.primary,
              minHeight: 12,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isDone) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: AppLoading(color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'يرجى عدم إغلاق التطبيق أثناء التهيئة',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else ...[
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 16,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  l10n.setupSuccess,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          if (!isDone) ...[
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(
                onPressed: _confirmCancelSetup,
                child: const Text('إيقاف التهيئة'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmCancelSetup() async {
    final shouldCancel = await AppDialog.show<bool>(
      context: context,
      dialog: AppDialog.warning(
        title: 'إيقاف التهيئة؟',
        content: const Text(
          'سيتم إيقاف التحميل وحذف أي بيانات جزئية تم تنزيلها. يمكنك إعادة التهيئة من جديد.',
        ),
        confirmLabel: 'إيقاف التهيئة',
        cancelLabel: 'متابعة التحميل',
      ),
    );

    if (shouldCancel == true) {
      ref.read(setupProvider.notifier).cancelSetup();
    }
  }

  Future<void> _next(SetupState? setup, AppLocalizations l10n) async {
    if (_step == 0) {
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      setState(() {
        _testing = true;
        _message = null;
      });
      try {
        final SyncProfile profile;
        if (_useFullUrl) {
          // WHY: Full URL mode — parse URL and auto-strip /data suffix.
          final url = _fullUrlController.text.trim();
          if (url.isEmpty) {
            setState(() {
              _testing = false;
              _message = l10n.enterApiBaseUrl;
            });
            return;
          }
          profile = SyncProfile.fromUrl(
            url,
            custCode: _custCodeController.text.trim(),
          );
        } else {
          final portText = _portController.text.trim();
          profile = SyncProfile(
            host: _hostController.text.trim(),
            custCode: _custCodeController.text.trim(),
            port: portText.isNotEmpty ? int.tryParse(portText) : null,
            basePath: _basePathController.text.trim(),
            useSsl: _useSsl,
          );
        }

        final result = await ref
            .read(setupProvider.notifier)
            .saveConnection(profile);
        if (result.isHealthy) {
          setState(() {
            _step = 2;
            _testing = false;
            _message = null;
          });
        } else {
          setState(() {
            _testing = false;
            _message = l10n.serverCheckFailedFixConnection;
          });
        }
      } catch (e) {
        setState(() {
          _testing = false;
          _message = l10n.setupUnexpectedError;
        });
      }
      return;
    }

    // Step 2: Finish button
    setState(() => _message = null);
    await ref.read(setupProvider.notifier).completeSetup();
  }
}
