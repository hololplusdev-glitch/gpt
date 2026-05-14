// features/sync/presentation/sync_monitor_screen.dart
// WHY: Separates Backend master-data download visibility from the upload outbox.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/layout.dart';
import 'package:holol_POS/core/design_system/spacing.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/l10n/app_localizations.dart';
import 'package:holol_POS/core/services/master_data/master_data_contract.dart';
import 'package:holol_POS/core/services/master_data/master_data_download_helper.dart';
import 'package:holol_POS/core/services/master_data/master_data_sync_service.dart';
import 'package:holol_POS/features/setup/application/setup_notifier.dart';
import 'package:holol_POS/shared/presentation/widgets/app_info_banner.dart';
import 'package:holol_POS/shared/presentation/widgets/app_loading.dart';
import 'package:holol_POS/shared/presentation/widgets/app_metric_card.dart';
import 'package:holol_POS/shared/presentation/widgets/app_section_card.dart';
import 'package:holol_POS/shared/presentation/widgets/app_button.dart';
import 'package:holol_POS/shared/presentation/widgets/responsive_row.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
import 'package:holol_POS/shared/refactor/pos_runtime_state.dart';

final syncCountsProvider = FutureProvider.autoDispose<_SyncCounts>((ref) async {
  final syncDao = ref.watch(syncDaoProvider);
  final pending = await syncDao.getPendingCount();
  final failed = await syncDao.getProblemCount();
  final synced = await syncDao.getUploadedCount();
  return _SyncCounts(pending: pending, failed: failed, synced: synced);
});

final scopedSyncStateProvider =
    FutureProvider.autoDispose<List<ScopedSyncStateView>>((ref) async {
      return ref.watch(masterDataDaoProvider).getScopedSyncStates();
    });

class _SyncCounts {
  final int pending;
  final int failed;
  final int synced;

  const _SyncCounts({
    required this.pending,
    required this.failed,
    required this.synced,
  });
}

class SyncMonitorScreen extends ConsumerStatefulWidget {
  const SyncMonitorScreen({super.key});

  @override
  ConsumerState<SyncMonitorScreen> createState() => _SyncMonitorScreenState();
}

class _SyncMonitorScreenState extends ConsumerState<SyncMonitorScreen> {
  bool _isSyncing = false;
  String? _lastResult;
  bool _lastResultIsError = false;
  MasterDataSyncSummary? _lastSummary;
  MasterDataSyncProgress? _progress;
  MasterDataSyncCancelHandle? _cancelToken;

  Future<void> _downloadMasterData() async {
    final l10n = AppLocalizations.of(context)!;
    final cancelToken = MasterDataSyncCancelHandle();
    setState(() {
      _isSyncing = true;
      _lastResult = null;
      _lastResultIsError = false;
      _lastSummary = null;
      _progress = null;
      _cancelToken = cancelToken;
    });

    try {
      final syncProfile = ref.read(setupProvider).value?.syncProfile;
      if (syncProfile == null) {
        setState(() {
          _isSyncing = false;
          _lastResult = l10n.syncNotConfigured;
          _lastResultIsError = true;
          _cancelToken = null;
        });
        return;
      }

      final download = await ref
          .read(masterDataDownloadHelperProvider)
          .download(
            syncProfile: syncProfile,
            mode: MasterDataSyncMode.incremental,
            cancelHandle: cancelToken,
            onProgress: (progress) {
              if (!mounted) return;
              setState(() {
                _progress = progress;
              });
            },
          );

      if (!mounted) return;

      if (!mounted) return;

      final result = download.summary;
      final failed = download.fatalFailures;
      final readinessWarnings = download.readinessWarnings;
      final resultMessage = result.allNoChanges
          ? 'تم فحص بيانات التشغيل، لا توجد تغييرات جديدة.'
          : failed.isNotEmpty
          ? l10n.masterDataDownloadSummary(result.rowCount, failed.length)
          : l10n.masterDataDownloadSummary(result.rowCount, 0);
      setState(() {
        _isSyncing = false;
        _lastSummary = download.summary;
        _lastResult = readinessWarnings.isEmpty
            ? resultMessage
            : '$resultMessage\n${readinessWarnings.join('\n')}';
        _lastResultIsError = failed.isNotEmpty || readinessWarnings.isNotEmpty;
        _progress = null;
        _cancelToken = null;
      });
      ref.invalidate(scopedSyncStateProvider);
      PosRuntimeStateInvalidator.invalidateMasterDataDownloadProviders(ref);
    } catch (e) {
      if (!mounted) return;
      final isCancelled = e is AppException && e.code == 'CANCELLED';
      setState(() {
        _isSyncing = false;
        _lastResult = isCancelled
            ? 'Download cancelled by user.'
            : ErrorMapper.userMessage(e);
        _lastResultIsError = true;
        _progress = null;
        _cancelToken = null;
      });
      ref.invalidate(scopedSyncStateProvider);
    }
  }

  void _cancelDownload() {
    _cancelToken?.cancel('User cancelled master data download.');
  }

  @override
  void dispose() {
    _cancelToken?.cancel('Sync monitor disposed.');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final countsAsync = ref.watch(syncCountsProvider);
    final stateAsync = ref.watch(scopedSyncStateProvider);

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
                      child: const Icon(
                        Icons.sync,
                        color: AppColors.onPrimary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      l10n.syncMonitor,
                      style: const TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Body ──
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppContentWidth.wide,
                ),
                child: ListView(
                  padding: AppSpacing.paddingXl,
                  children: [
                    _buildMasterDownloadSection(l10n),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildUploadSection(l10n, countsAsync),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildStateSection(stateAsync),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterDownloadSection(AppLocalizations l10n) {
    final progress = _progress;
    return AppSectionCard(
      title: 'تحديث بيانات التشغيل',
      icon: Icons.cloud_download_outlined,
      action: _isSyncing
          ? AppButton.text(
              onPressed: _cancelDownload,
              icon: Icons.cancel_outlined,
              label: 'إيقاف التحديث',
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (progress != null) ...[
            Text(
              progress.typeCode == MasterDataType.devicePrivilege.code
                  ? progress.typeLabel
                  : 'تحميل ${progress.typeCode}${progress.totalPages > 1 ? ' — صفحة ${progress.currentPage}/${progress.totalPages}' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(value: progress.sectionProgress),
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(value: progress.totalProgress),
            const SizedBox(height: AppSpacing.md),
          ],
          SizedBox(
            width: double.infinity,
            height: 56,
            child: AppButton.primary(
              onPressed: _isSyncing ? null : _downloadMasterData,
              isLoading: _isSyncing,
              icon: Icons.cloud_download,
              label: _isSyncing ? l10n.downloading : l10n.downloadMasterData,
            ),
          ),
          if (_lastResult != null) ...[
            const SizedBox(height: AppSpacing.lg),
            AppInfoBanner(
              message: _lastResult!,
              type: _lastResultIsError
                  ? AppBannerType.warning
                  : AppBannerType.success,
            ),
          ],
          if (_lastSummary != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _buildResultsTable(_lastSummary!.results),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadSection(
    AppLocalizations l10n,
    AsyncValue<_SyncCounts> countsAsync,
  ) {
    return AppSectionCard(
      title: 'رفع الفواتير المعلقة',
      icon: Icons.cloud_upload_outlined,
      child: Column(
        children: [
          countsAsync.when(
            data: (counts) => ResponsiveRow(
              breakpoint: AppBreakpoints.medium,
              children: [
                AppMetricCard(
                  label: l10n.pendingUpload,
                  value: '${counts.pending}',
                  color: AppColors.warning,
                  icon: Icons.hourglass_empty,
                ),
                AppMetricCard(
                  label: l10n.uploadFailed,
                  value: '${counts.failed}',
                  color: AppColors.error,
                  icon: Icons.error_outline,
                ),
                AppMetricCard(
                  label: l10n.uploaded,
                  value: '${counts.synced}',
                  color: AppColors.success,
                  icon: Icons.cloud_done,
                ),
              ],
            ),
            loading: () => const AppLoading(),
            error: (e, _) =>
                AppInfoBanner.error(message: ErrorMapper.userMessage(e)),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: AppButton.outlined(
              onPressed: null,
              icon: Icons.cloud_upload_outlined,
              label: l10n.pendingInvoiceUploadUnavailable,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsTable(List<MasterDataTypeResult> results) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('النوع')),
          DataColumn(label: Text('الحالة')),
          DataColumn(label: Text('الصفوف')),
          DataColumn(label: Text('آخر وقت سابق')),
          DataColumn(label: Text('آخر وقت جديد')),
          DataColumn(label: Text('الخطأ')),
          DataColumn(label: Text('التحذيرات')),
        ],
        rows: results
            .map(
              (result) => DataRow(
                cells: [
                  DataCell(Text(result.type.code)),
                  DataCell(Text(result.status.code)),
                  DataCell(Text('${result.rowsReceived}')),
                  DataCell(Text(result.oldServerTime ?? '-')),
                  DataCell(Text(result.newServerTime ?? '-')),
                  DataCell(Text(result.error ?? '-')),
                  DataCell(
                    Text(
                      result.warnings.isEmpty
                          ? '-'
                          : result.warnings.join('\n'),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildStateSection(AsyncValue<List<ScopedSyncStateView>> stateAsync) {
    return AppSectionCard(
      title: 'حالة تحديث بيانات التشغيل',
      icon: Icons.history,
      child: stateAsync.when(
        data: (rows) {
          if (rows.isEmpty) {
            return const Text(
              'لا توجد حالة تحديث بيانات تشغيل بعد.',
              style: TextStyle(color: AppColors.textSecondary),
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('النوع')),
                DataColumn(label: Text('الحالة')),
                DataColumn(label: Text('آخر وقت من السيرفر')),
                DataColumn(label: Text('آخر نجاح')),
                DataColumn(label: Text('آخر خطأ')),
              ],
              rows: rows
                  .map(
                    (row) => DataRow(
                      cells: [
                        DataCell(Text(row.syncType)),
                        DataCell(Text(row.lastStatus)),
                        DataCell(Text(row.lastServerTime ?? '-')),
                        DataCell(Text(row.lastSuccessTime ?? '-')),
                        DataCell(Text(row.lastError ?? '-')),
                      ],
                    ),
                  )
                  .toList(),
            ),
          );
        },
        loading: () => const AppLoading(),
        error: (e, _) =>
            AppInfoBanner.error(message: ErrorMapper.userMessage(e)),
      ),
    );
  }
}
