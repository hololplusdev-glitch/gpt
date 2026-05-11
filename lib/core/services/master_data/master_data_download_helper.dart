import 'package:pos_flutter/core/errors/app_exception.dart';
import 'package:pos_flutter/core/network/network_models.dart';
import 'package:pos_flutter/core/services/master_data/master_data_contract.dart';
import 'package:pos_flutter/core/services/master_data/master_data_sync_service.dart';
import 'package:pos_flutter/core/services/readiness/catalog_readiness_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';

class MasterDataDownloadResult {
  final MasterDataSyncSummary summary;
  final CatalogReadiness readiness;
  final List<MasterDataTypeResult> fatalFailures;
  final List<MasterDataTypeResult> warningFailures;
  final List<String> readinessWarnings;

  const MasterDataDownloadResult({
    required this.summary,
    required this.readiness,
    required this.fatalFailures,
    required this.warningFailures,
    required this.readinessWarnings,
  });

  MasterDataSyncSummary get summaryWithReadinessWarnings {
    if (readinessWarnings.isEmpty) return summary;
    final updatedResults = summary.results.map((result) {
      if (result.type != MasterDataType.itemPrice) return result;
      return MasterDataTypeResult(
        type: result.type,
        status: result.status,
        rowsReceived: result.rowsReceived,
        rowsSaved: result.rowsSaved,
        pagesCount: result.pagesCount,
        serverTime: result.serverTime,
        oldServerTime: result.oldServerTime,
        newServerTime: result.newServerTime,
        sentLastUpdate: result.sentLastUpdate,
        errorCode: result.errorCode,
        error: result.error,
        detailsJson: result.detailsJson,
        warnings: [...result.warnings, ...readinessWarnings],
      );
    }).toList();
    return MasterDataSyncSummary(
      updatedResults,
      runId: summary.runId,
      mode: summary.mode,
      status: summary.status,
    );
  }

  String warningFailureSummary() {
    if (warningFailures.isEmpty) return '';
    return warningFailures.map((result) => result.type.code).join(', ');
  }
}

class MasterDataDownloadHelper {
  final MasterDataSyncService _syncService;
  final CatalogReadinessService _readinessService;

  const MasterDataDownloadHelper({
    required MasterDataSyncService syncService,
    required CatalogReadinessService readinessService,
  }) : _syncService = syncService,
       _readinessService = readinessService;

  Future<MasterDataDownloadResult> download({
    required SyncProfile syncProfile,
    required MasterDataSyncMode mode,
    MasterDataSyncCancelHandle? cancelHandle,
    void Function(MasterDataSyncProgress)? onProgress,
    Set<MasterDataType> warningTypes = const {},
    bool requireReady = false,
    bool throwOnFatalFailures = false,
  }) async {
    final summary = await _syncService.syncAll(
      MasterDataSyncContext(
        custCode: syncProfile.custCode.trim(),
        bootstrapUserId: syncProfile.bootstrapUserId.trim().isEmpty
            ? '1'
            : syncProfile.bootstrapUserId.trim(),
        pageLimit: syncProfile.pageLimit,
      ),
      mode: mode,
      cancelHandle: cancelHandle,
      onProgress: onProgress,
    );
    final failed = summary.results.where((result) => result.isFailure).toList();
    final warningFailures = failed
        .where((result) => warningTypes.contains(result.type))
        .toList();
    final fatalFailures = failed
        .where((result) => !warningTypes.contains(result.type))
        .toList();
    if (throwOnFatalFailures && fatalFailures.isNotEmpty) {
      final details = fatalFailures
          .map((result) {
            final reason = result.error?.trim();
            final code = result.errorCode?.trim();
            final suffix = [
              if (code != null && code.isNotEmpty) code,
              if (reason != null && reason.isNotEmpty) reason,
            ].join(' - ');
            return suffix.isEmpty
                ? result.type.code
                : '${result.type.code}: $suffix';
          })
          .join(' | ');

      throw SyncException(
        'فشل تحديث بيانات التشغيل: $details',
        code: 'MASTER_DATA_DOWNLOAD_FAILED',
      );
    }

    final readiness = await _readinessService.check();
    if (requireReady && !readiness.isReady) {
      throw SyncException(
        'Catalog data is incomplete. Download master data again.',
        code: 'CATALOG_INCOMPLETE',
      );
    }

    return MasterDataDownloadResult(
      summary: summary,
      readiness: readiness,
      fatalFailures: fatalFailures,
      warningFailures: warningFailures,
      readinessWarnings: readiness.syncWarnings,
    );
  }
}

final masterDataDownloadHelperProvider = Provider<MasterDataDownloadHelper>((
  ref,
) {
  return MasterDataDownloadHelper(
    syncService: ref.watch(masterDataSyncServiceProvider),
    readinessService: ref.watch(catalogReadinessServiceProvider),
  );
});
