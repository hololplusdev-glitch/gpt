import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_flutter/core/design_system/colors.dart';
import 'package:pos_flutter/core/design_system/spacing.dart';
import 'package:pos_flutter/core/l10n/app_localizations.dart';
import 'package:pos_flutter/features/setup/application/setup_notifier.dart';
import 'package:pos_flutter/core/network/network_models.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_switch.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_loading.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_text_field.dart';
import 'package:pos_flutter/shared/presentation/widgets/app_button.dart';
import 'package:pos_flutter/shared/presentation/widgets/responsive_row.dart';

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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.paddingLg,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.posSetup,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _stepLabel(l10n),
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _buildStep(setup, l10n),
                      if (_message != null || setup?.errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _message ?? setup!.errorMessage!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        children: [
                          if (_step > 0)
                            TextButton(
                              onPressed: _testing
                                  ? null
                                  : () => setState(() => _step--),
                              child: Text(l10n.back),
                            ),
                          const Spacer(),
                          if (setup?.isLoading ?? false)
                            AppButton.primary(
                              onPressed: null,
                              isLoading: true,
                              label: 'جاري تهيئة بيانات التشغيل',
                            )
                          else
                            AppButton.primary(
                              onPressed: _testing
                                  ? null
                                  : () => _next(setup, l10n),
                              isLoading: _testing,
                              label: _testing
                                  ? 'جاري التحقق من الاتصال...'
                                  : (_step == 2
                                        ? 'بدء تهيئة بيانات التشغيل'
                                        : l10n.next),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _stepLabel(AppLocalizations l10n) {
    return switch (_step) {
      0 => l10n.languageLabel,
      1 => l10n.serverIdentity,
      _ => l10n.initialReadiness,
    };
  }

  Widget _buildStep(SetupState? setup, AppLocalizations l10n) {
    if (_step == 0) {
      return SegmentedButton<String>(
        segments: [
          ButtonSegment(value: 'en', label: Text(l10n.english)),
          ButtonSegment(value: 'ar', label: Text(l10n.arabic)),
        ],
        selected: {setup?.language ?? 'en'},
        onSelectionChanged: (value) {
          ref.read(setupProvider.notifier).setLanguage(value.first);
        },
      );
    }
    if (_step == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // -- URL mode toggle --
          AppSwitchListTile(
            title: l10n.fullUrlMode,
            subtitle: l10n.fullUrlSubtitle,
            value: _useFullUrl,
            onChanged: (value) => setState(() => _useFullUrl = value),
          ),
          const SizedBox(height: AppSpacing.md),

          if (_useFullUrl) ...[
            // -- Full URL input --
            AppTextField(
              controller: _fullUrlController,
              labelText: l10n.apiBaseUrl,
              hintText: l10n.apiBaseUrlExample,
              helperText: l10n.baseUrlHint,
            ),
          ] else ...[
            // -- Host + Port + BasePath --
            ResponsiveRow(
              children: [
                Expanded(
                  flex: 3,
                  child: AppTextField(
                    controller: _hostController,
                    labelText: l10n.hostOrIp,
                  ),
                ),
                AppTextField(
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  labelText: l10n.port,
                  hintText: l10n.optional,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _basePathController,
              labelText: l10n.apiBasePath,
              hintText: l10n.apiBasePathExample,
            ),
            const SizedBox(height: AppSpacing.md),
            AppSwitchListTile(
              title: l10n.https,
              value: _useSsl,
              onChanged: (value) => setState(() => _useSsl = value),
              contentPadding: EdgeInsets.zero,
            ),
          ],
          const SizedBox(height: AppSpacing.md),

          // -- Backend identity fields --
          AppTextField(
            controller: _custCodeController,
            labelText: l10n.customerCode,
          ),
          if (_testing) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: const [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: AppLoading(color: AppColors.primary),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'جاري التحقق من الرابط وكود الشركة...',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }
    final isSyncing = setup?.isLoading ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: AppSpacing.borderRadiusMd,
            border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  (setup?.isSetupComplete ?? false)
                      ? l10n.setupSuccess
                      : 'تم التحقق من الاتصال. ابدأ الآن تحميل بيانات التشغيل للعمل بدون إنترنت.',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ListTile(
          leading: const Icon(Icons.point_of_sale),
          title: Text(l10n.setupPrintersLater),
        ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
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
                onPressed: () => ref.read(setupProvider.notifier).cancelSetup(),
                child: const Text('إيقاف التهيئة'),
              ),
            ),
          ],
        ],
      ),
    );
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
            port: portText.isNotEmpty ? int.tryParse(portText) : null,
            basePath: _basePathController.text.trim(),
            custCode: _custCodeController.text.trim(),
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
