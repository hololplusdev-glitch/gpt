import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_flutter/core/errors/app_exception.dart';
import 'package:pos_flutter/core/network/network_models.dart';
import 'package:pos_flutter/core/services/master_data/master_data_contract.dart';
import 'package:pos_flutter/core/services/master_data/master_data_download_helper.dart';
import 'package:pos_flutter/core/services/master_data/master_data_sync_service.dart';
import 'package:pos_flutter/features/auth/application/pos_session_controller.dart';
import 'package:pos_flutter/features/shift/application/shift_controller.dart';
import 'package:pos_flutter/features/sync/application/master_data_provider_invalidation.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';

class SetupState {
  final bool isSetupComplete;
  final bool isLoading;
  final String? errorMessage;
  final SyncProfile? syncProfile;
  final String language;
  final HealthCheckResult? lastHealthCheck;
  final double syncProgress;
  final String? syncStatus;
  final String? syncPagination;

  const SetupState({
    this.isSetupComplete = false,
    this.isLoading = false,
    this.errorMessage,
    this.syncProfile,
    this.language = 'en',
    this.lastHealthCheck,
    this.syncProgress = 0.0,
    this.syncStatus,
    this.syncPagination,
  });

  bool get hasConnection => syncProfile != null;

  SetupState copyWith({
    bool? isSetupComplete,
    bool? isLoading,
    String? errorMessage,
    SyncProfile? syncProfile,
    String? language,
    HealthCheckResult? lastHealthCheck,
    double? syncProgress,
    String? syncStatus,
    String? syncPagination,
    bool clearError = false,
    bool clearConnection = false,
    bool clearSync = false,
  }) {
    return SetupState(
      isSetupComplete: isSetupComplete ?? this.isSetupComplete,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      syncProfile: clearConnection ? null : (syncProfile ?? this.syncProfile),
      language: language ?? this.language,
      lastHealthCheck: lastHealthCheck ?? this.lastHealthCheck,
      syncProgress: clearSync ? 0.0 : (syncProgress ?? this.syncProgress),
      syncStatus: clearSync ? null : (syncStatus ?? this.syncStatus),
      syncPagination: clearSync
          ? null
          : (syncPagination ?? this.syncPagination),
    );
  }
}

class SetupNotifier extends AsyncNotifier<SetupState> {
  MasterDataSyncCancelHandle? _cancelToken;

  @override
  Future<SetupState> build() async {
    final repo = ref.read(runtimeConfigRepositoryProvider);
    final config = await repo.loadSetupConfig();
    var isComplete = config.isSetupComplete;

    if (config.syncProfile != null) {
      ref.read(apiClientProvider).configure(config.syncProfile!);
      await ref.read(posConfigProvider).initialize();
    } else if (isComplete) {
      isComplete = false;
      await repo.setSetupComplete(false);
    }

    return SetupState(
      isSetupComplete: isComplete,
      syncProfile: config.syncProfile,
      language: config.language,
    );
  }

  Future<HealthCheckResult> saveConnection(SyncProfile profile) async {
    state = AsyncData(state.value!.copyWith(isLoading: true, clearError: true));
    if (profile.custCode.trim().isEmpty) {
      throw StateError('Customer code is required.');
    }

    final apiClient = ref.read(apiClientProvider);
    apiClient.configure(profile);
    final healthResult = await ref
        .read(masterDataSyncServiceProvider)
        .checkConnection(profile);

    await ref.read(runtimeConfigRepositoryProvider).saveSyncProfile(profile);
    ref.invalidate(syncProfileProvider);

    state = AsyncData(
      state.value!.copyWith(
        isLoading: false,
        syncProfile: profile.copyWith(
          isValidated: healthResult.isHealthy,
          lastValidatedAt: ref.read(clockProvider).now(),
        ),
        lastHealthCheck: healthResult,
      ),
    );
    return healthResult;
  }

  Future<void> setLanguage(String lang) async {
    await ref.read(runtimeConfigRepositoryProvider).setLanguage(lang);
    state = AsyncData(state.value!.copyWith(language: lang));
  }

  Future<void> completeSetup() async {
    state = AsyncData(
      state.value!.copyWith(
        isLoading: true,
        clearError: true,
        syncProgress: 0.0,
        syncStatus: 'جاري تجهيز التهيئة...',
        syncPagination: null,
      ),
    );
    _cancelToken = MasterDataSyncCancelHandle();

    try {
      final syncProfile = state.value!.syncProfile;
      if (syncProfile == null || syncProfile.custCode.trim().isEmpty) {
        throw StateError('Customer code is required.');
      }

      final configRepo = ref.read(posConfigProvider);
      await configRepo.seedDefaults();
      await configRepo.initialize();
      await ref.read(masterDataDaoProvider).clearMasterDataCache();

      final download = await ref
          .read(masterDataDownloadHelperProvider)
          .download(
            syncProfile: syncProfile,
            mode: MasterDataSyncMode.initial,
            cancelHandle: _cancelToken,
            requireReady: false,
            throwOnFatalFailures: true,
            warningTypes: _setupWarningTypes,
            onProgress: (progress) {
              final totalSections = progress.totalSections <= 0
                  ? 1
                  : progress.totalSections;
              final overallProgress =
                  ((progress.currentSection + progress.sectionProgress) /
                          totalSections)
                      .clamp(0.0, 1.0);
              final paginationStr = progress.totalPages > 1
                  ? 'صفحة ${progress.currentPage} من ${progress.totalPages}'
                  : '';
              final label =
                  progress.typeCode == MasterDataType.devicePrivilege.code
                  ? progress.typeLabel
                  : 'تحميل ${progress.typeCode}';
              state = AsyncData(
                state.value!.copyWith(
                  syncProgress: overallProgress,
                  syncStatus: label,
                  syncPagination: paginationStr,
                ),
              );
            },
          );

      await _verifySetupUserExists(syncProfile.bootstrapUserId.trim());
      final warningSummary = download.warningFailureSummary();
      invalidateMasterDataDownloadProviders(ref);
      await ref.read(runtimeConfigRepositoryProvider).setSetupComplete(true);
      state = AsyncData(
        state.value!.copyWith(
          isSetupComplete: true,
          isLoading: false,
          syncProgress: 1.0,
          syncStatus: warningSummary.isEmpty
              ? 'اكتملت تهيئة بيانات التشغيل'
              : 'اكتملت مع تحذيرات: $warningSummary',
        ),
      );
    } catch (e) {
      final isCancelled = e is AppException && e.code == 'CANCELLED';

      // Setup download must be atomic from the user's perspective.
      // If first-run setup fails or is cancelled, discard partial master data.
      try {
        await ref.read(masterDataDaoProvider).clearMasterDataCache();
        await ref.read(activePosSessionDaoProvider).clearActive();
        invalidateMasterDataDownloadProviders(ref);
        ref.invalidate(activePosSessionProvider);
        ref.invalidate(posSessionControllerProvider);
        ref.invalidate(shiftControllerProvider);
        ref.invalidate(catalogReadinessProvider);
      } catch (_) {
        // Keep the original setup error visible. Cache cleanup failure is secondary.
      }

      state = AsyncData(
        state.value!.copyWith(
          isLoading: false,
          isSetupComplete: false,
          clearSync: true,
          errorMessage: isCancelled
              ? 'تم إيقاف التهيئة. لم يتم اعتماد البيانات الجزئية.'
              : 'فشلت التهيئة ولم يتم اعتماد البيانات الجزئية: ${ErrorMapper.userMessage(e)}',
        ),
      );
    } finally {
      _cancelToken = null;
    }
  }

  void cancelSetup() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('User cancelled setup sync.');
    }
  }

  Future<void> resetSetup() async {
    final repo = ref.read(runtimeConfigRepositoryProvider);
    await repo.resetSetupStatus();
    await repo.clearSyncProfile();
    await ref.read(activePosSessionDaoProvider).clearActive();
    ref.read(apiClientProvider).clearConfiguration();
    ref.invalidate(syncProfileProvider);
    ref.invalidate(activePosSessionProvider);
    ref.invalidate(posSessionControllerProvider);
    ref.invalidate(shiftControllerProvider);
    ref.invalidate(catalogReadinessProvider);
    state = AsyncData(
      SetupState(language: state.valueOrNull?.language ?? 'en'),
    );
  }

  Future<void> _verifySetupUserExists(String usrId) async {
    final exists = await ref.read(masterDataDaoProvider).setupUserExists(usrId);
    if (!exists) {
      throw SyncException(
        'Bootstrap user was not found in synced users.',
        code: 'SETUP_USER_NOT_SYNCED',
      );
    }
  }

  static const _setupWarningTypes = {
    MasterDataType.bank,
    MasterDataType.cash,
    MasterDataType.creditCardType,
  };
}

final setupProvider = AsyncNotifierProvider<SetupNotifier, SetupState>(
  SetupNotifier.new,
);

final isSetupCompleteProvider = Provider<bool>((ref) {
  return ref.watch(setupProvider).valueOrNull?.isSetupComplete ?? false;
});
