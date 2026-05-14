import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/network/network_models.dart';
import 'package:holol_POS/core/services/master_data/master_data_contract.dart';
import 'package:holol_POS/core/services/master_data/master_data_sync_service.dart';
import 'package:holol_POS/features/auth/application/pos_session_controller.dart';
import 'package:holol_POS/features/shift/application/shift_controller.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
import 'package:holol_POS/shared/refactor/pos_runtime_state.dart';

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

  SetupState get _currentState => PosRuntimeStateInvalidator.requireAsyncValue(
    state,
    message: 'Setup state is not ready.',
  );

  @override
  Future<SetupState> build() async {
    final repo = ref.read(runtimeConfigRepositoryProvider);
    final config = await repo.loadSetupConfig();
    var isComplete = config.isSetupComplete;

    if (config.syncProfile != null) {
      ref.read(apiClientProvider).configure(config.syncProfile!);
      await ref.read(posConfigProvider).initialize();

      if (isComplete) {
        final hasSeed = await ref
            .read(masterDataDaoProvider)
            .hasMinimumSetupSeed(
              bootstrapUserId: config.syncProfile!.bootstrapUserId,
            );

        if (!hasSeed) {
          isComplete = false;
          await repo.setSetupComplete(false);
          await ref.read(activePosSessionDaoProvider).clearActive();
          PosRuntimeStateInvalidator.invalidateSetupRuntime(
            ref,
            posSessionControllerProvider: posSessionControllerProvider,
            shiftControllerProvider: shiftControllerProvider,
          );
        }
      }
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
    if (profile.custCode.trim().isEmpty) {
      state = AsyncData(
        _currentState.copyWith(
          isLoading: false,
          errorMessage: 'Customer code is required.',
        ),
      );
      throw StateError('Customer code is required.');
    }

    state = AsyncData(
      _currentState.copyWith(isLoading: true, clearError: true),
    );

    try {
      final apiClient = ref.read(apiClientProvider);
      apiClient.configure(profile);
      final healthResult = await ref
          .read(masterDataSyncServiceProvider)
          .checkConnection(profile);

      await ref.read(runtimeConfigRepositoryProvider).saveSyncProfile(profile);
      ref.invalidate(syncProfileProvider);

      state = AsyncData(
        _currentState.copyWith(
          isLoading: false,
          syncProfile: profile.copyWith(
            isValidated: healthResult.isHealthy,
            lastValidatedAt: ref.read(clockProvider).now(),
          ),
          lastHealthCheck: healthResult,
        ),
      );
      return healthResult;
    } catch (e) {
      state = AsyncData(
        _currentState.copyWith(
          isLoading: false,
          errorMessage: ErrorMapper.userMessage(e),
        ),
      );
      rethrow;
    }
  }

  Future<void> setLanguage(String lang) async {
    await ref.read(runtimeConfigRepositoryProvider).setLanguage(lang);
    state = AsyncData(
      PosRuntimeStateInvalidator.requireAsyncValue(
        state,
        message: 'Setup state is not ready.',
      ).copyWith(language: lang),
    );
  }

  Future<void> completeSetup() async {
    state = AsyncData(
      PosRuntimeStateInvalidator.requireAsyncValue(
        state,
        message: 'Setup state is not ready.',
      ).copyWith(
        isLoading: true,
        clearError: true,
        syncProgress: 0.0,
        syncStatus: 'جاري تجهيز التهيئة...',
        syncPagination: null,
      ),
    );

    _cancelToken = MasterDataSyncCancelHandle();

    try {
      final syncProfile = PosRuntimeStateInvalidator.requireAsyncValue(
        state,
        message: 'Setup state is not ready.',
      ).syncProfile;

      if (syncProfile == null || syncProfile.custCode.trim().isEmpty) {
        throw StateError('Customer code is required.');
      }

      final warningSummary =
          await PosMasterDataRuntimeWorkflow.completeInitialSetup(
            ref: ref,
            syncProfile: syncProfile,
            cancelHandle: _cancelToken!,
            posSessionControllerProvider: posSessionControllerProvider,
            shiftControllerProvider: shiftControllerProvider,
            onProgress: (snapshot) {
              state = AsyncData(
                PosRuntimeStateInvalidator.requireAsyncValue(
                  state,
                  message: 'Setup state is not ready.',
                ).copyWith(
                  syncProgress: snapshot.progress,
                  syncStatus: snapshot.status,
                  syncPagination: snapshot.pagination,
                ),
              );
            },
          );

      state = AsyncData(
        PosRuntimeStateInvalidator.requireAsyncValue(
          state,
          message: 'Setup state is not ready.',
        ).copyWith(
          isSetupComplete: true,
          isLoading: false,
          syncProgress: 1.0,
          syncStatus: warningSummary.isEmpty
              ? 'اكتملت تهيئة بيانات التشغيل'
              : 'اكتملت مع تحذيرات: $warningSummary',
        ),
      );
    } catch (e) {
      final isCancelled = PosMasterDataRuntimeWorkflow.isCancelled(e);

      try {
        await PosMasterDataRuntimeWorkflow.cleanupFailedInitialSetup(
          ref: ref,
          posSessionControllerProvider: posSessionControllerProvider,
          shiftControllerProvider: shiftControllerProvider,
        );
      } catch (_) {
        // Keep the original setup error visible. Cache cleanup failure is secondary.
      }

      state = AsyncData(
        PosRuntimeStateInvalidator.requireAsyncValue(
          state,
          message: 'Setup state is not ready.',
        ).copyWith(
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
    await PosMasterDataRuntimeWorkflow.resetSetup(
      ref: ref,
      posSessionControllerProvider: posSessionControllerProvider,
      shiftControllerProvider: shiftControllerProvider,
    );

    state = AsyncData(
      SetupState(language: state.valueOrNull?.language ?? 'en'),
    );
  }
}

final setupProvider = AsyncNotifierProvider<SetupNotifier, SetupState>(
  SetupNotifier.new,
);
