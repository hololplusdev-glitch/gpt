import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/network/network_models.dart';
import 'package:holol_POS/core/services/master_data/master_data_contract.dart';
import 'package:holol_POS/core/services/master_data/master_data_sync_service.dart';
import 'package:holol_POS/core/services/readiness/catalog_readiness_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';

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
  String warningFailureSummary() {
    if (warningFailures.isEmpty) return '';
    return warningFailures.map((result) => result.type.code).join(', ');
  }

  String readinessWarningSummary() {
    if (readinessWarnings.isEmpty) return '';
    return readinessWarnings.join(' | ');
  }

  String operationalWarningSummary() {
    final parts = <String>[];

    final typeWarnings = warningFailureSummary();
    if (typeWarnings.isNotEmpty) {
      parts.add('أنواع اكتملت كتحذير: $typeWarnings');
    }

    final readiness = readinessWarningSummary();
    if (readiness.isNotEmpty) {
      parts.add('تحذيرات الجاهزية: $readiness');
    }

    return parts.join(' | ');
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
    Set<MasterDataType>? warningTypes,
    bool requireReady = false,
    bool throwOnFatalFailures = false,
  }) async {
    final effectiveWarningTypes = warningTypes ?? mode.defaultWarningTypes;

    final summary = await _syncService.syncAll(
      MasterDataSyncContext(
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
        .where((result) => effectiveWarningTypes.contains(result.type))
        .toList();
    final fatalFailures = failed
        .where((result) => !effectiveWarningTypes.contains(result.type))
        .toList();
    if (throwOnFatalFailures && fatalFailures.isNotEmpty) {
      throw SyncException(
        'فشل تحديث بيانات التشغيل: ${_failureSummary(fatalFailures)}',
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

  String _failureSummary(List<MasterDataTypeResult> failures) {
    return failures.map(_formatFailure).join(' | ');
  }

  String _formatFailure(MasterDataTypeResult result) {
    final code = _clean(result.errorCode);
    final reason = _clean(result.error);
    final parts = [if (code.isNotEmpty) code, if (reason.isNotEmpty) reason];

    if (parts.isEmpty) return result.type.code;

    return '${result.type.code}: ${parts.join(' - ')}';
  }

  String _clean(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
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
