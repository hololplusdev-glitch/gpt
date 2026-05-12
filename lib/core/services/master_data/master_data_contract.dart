// core/services/master_data/backend_master_data_types.dart
// WHY: Centralized Backend master data type definitions and sync context.
// Extracted from master_data_sync_service.dart for DRY/SRP compliance.

import 'package:holol_POS/core/errors/app_exception.dart';

/// Enumeration of all master data types supported by the POS data download engine.
///
/// SSOT: Most backend data is downloaded tenant-wide by p_type.
/// DEVICE_PRIV is special: it is downloaded per USER because it is keyed by usr_id + mchn_nbr.
enum MasterDataType {
  posMachine('POS_MACHINE'),
  user('USER'),
  devicePrivilege('DEVICE_PRIV'),
  branch('BRANCH'),
  store('STORE'),
  cash('CASH'),
  bank('BANK'),
  creditCardType('CREDIT_CARD_TYPE'),
  priceLevel('PRICE_LEVEL'),
  item('ITEM'),
  itemUnit('ITEM_UNIT'),
  itemPrice('ITEM_PRICE'),
  customer('CUSTOMER');

  const MasterDataType(this.code);

  final String code;

  /// Download order.
  /// DEVICE_PRIV is intentionally excluded here.
  /// It is synced per downloaded user after USER + POS_MACHINE.
  static const syncOrder = [
    user,
    posMachine,
    branch,
    store,
    cash,
    bank,
    creditCardType,
    priceLevel,
    item,
    itemUnit,
    itemPrice,
    customer,
  ];

  /// Types whose failure is fatal and must abort the entire sync.
  static const mandatoryTypes = {user, posMachine};

  /// Types allowed to fail as warnings during first-run setup.
  ///
  /// Keep this policy here, not in SetupNotifier, so master-data behavior has
  /// one owner.
  static const setupWarningTypes = {bank, cash, creditCardType};

  bool get isMandatory => mandatoryTypes.contains(this);

  bool get isSetupWarning => setupWarningTypes.contains(this);

  bool get isHeavyPayload {
    switch (this) {
      case item:
      case itemPrice:
      case customer:
        return true;
      default:
        return false;
    }
  }

  int effectivePageLimit(int configuredLimit) {
    final safeConfigured = configuredLimit <= 0 ? 100 : configuredLimit;
    if (!isHeavyPayload) return safeConfigured;
    return safeConfigured < 100 ? safeConfigured : 100;
  }
}

enum MasterDataSyncMode {
  initial('initial'),
  incremental('incremental'),
  forceFull('force_full');

  const MasterDataSyncMode(this.code);

  final String code;

  /// Default warning policy for each download mode.
  ///
  /// Setup is allowed to finish with non-critical setup table warnings.
  /// Normal incremental/full sync should report failures as failures unless a
  /// caller explicitly overrides the policy.
  Set<MasterDataType> get defaultWarningTypes {
    switch (this) {
      case MasterDataSyncMode.initial:
        return MasterDataType.setupWarningTypes;
      case MasterDataSyncMode.incremental:
      case MasterDataSyncMode.forceFull:
        return const {};
    }
  }
}

enum MasterDataRunStatus {
  running('running'),
  success('success'),
  partial('partial'),
  failed('failed'),
  cancelled('cancelled');

  const MasterDataRunStatus(this.code);

  final String code;
}

enum MasterDataTypeRunStatus {
  running('running'),
  success('success'),
  noChanges('no_changes'),
  failed('failed'),
  skipped('skipped'),
  cancelled('cancelled');

  const MasterDataTypeRunStatus(this.code);

  final String code;

  bool get isFailure => this == failed || this == cancelled;
}

/// Context passed to every data download request.
/// SSOT: backend download is global per tenant/bootstrap user.
/// Runtime machine/store/price filtering happens after login.
class MasterDataSyncContext {
  final String custCode;
  final String bootstrapUserId;
  final String? branchNo;
  final int pageLimit;

  const MasterDataSyncContext({
    required this.custCode,
    this.bootstrapUserId = '1',
    this.branchNo,
    this.pageLimit = 500,
  });

  String get syncUserId => bootstrapUserId;

  String get normalizedCustCode => custCode.trim();

  String get normalizedBootstrapUserId {
    final normalized = bootstrapUserId.trim();
    return normalized.isEmpty ? '1' : normalized;
  }

  String? get normalizedBranchNo {
    final normalized = branchNo?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }

  int effectivePageLimitFor(MasterDataType type) {
    return type.effectivePageLimit(pageLimit);
  }


  MasterDataSyncContext copyWith({
    String? custCode,
    String? bootstrapUserId,
    String? branchNo,
    bool clearBranchNo = false,
    int? pageLimit,
  }) {
    return MasterDataSyncContext(
      custCode: custCode ?? this.custCode,
      bootstrapUserId: bootstrapUserId ?? this.bootstrapUserId,
      branchNo: clearBranchNo ? null : branchNo ?? this.branchNo,
      pageLimit: pageLimit ?? this.pageLimit,
    );
  }

  Map<String, dynamic> queryParameters({
    required MasterDataType type,
    required int offset,
    String? lastUpdate,
  }) {
    final normalizedLastUpdate = lastUpdate?.trim();

    final params = <String, dynamic>{
      'p_type': type.code,
      'p_cust_code': normalizedCustCode,
      'p_usr_id': normalizedBootstrapUserId,
      'p_limit': effectivePageLimitFor(type),
      'p_offset': offset < 0 ? 0 : offset,
    };

    final branch = normalizedBranchNo;
    if (branch != null) {
      params['p_bra_nbr'] = branch;
    }

    if (normalizedLastUpdate != null &&
        normalizedLastUpdate.isNotEmpty &&
        normalizedLastUpdate.toLowerCase() != 'null') {
      params['p_last_update'] = normalizedLastUpdate;
    }

    return params;
  }
) {
    final normalizedLastUpdate = lastUpdate?.trim();

    final params = <String, dynamic>{
      'p_type': type.code,
      'p_cust_code': normalizedCustCode,
      'p_usr_id': normalizedBootstrapUserId,
      'p_limit': effectivePageLimitFor(type),
      'p_offset': offset < 0 ? 0 : offset,
    };

    final branch = normalizedBranchNo;
    if (branch != null) {
      params['p_bra_nbr'] = branch;
    }

    if (normalizedLastUpdate != null &&
        normalizedLastUpdate.isNotEmpty &&
        normalizedLastUpdate.toLowerCase() != 'null') {
      params['p_last_update'] = normalizedLastUpdate;
    }

    return params;
  }
) {
    final params = <String, dynamic>{
      'p_type': type.code,
      'p_cust_code': custCode,
      'p_usr_id': bootstrapUserId,
      'p_limit': pageLimit,
      'p_offset': offset,
    };

    final branch = branchNo?.trim();
    if (branch != null && branch.isNotEmpty) {
      params['p_bra_nbr'] = branch;
    }

    if (lastUpdate != null && lastUpdate.isNotEmpty) {
      params['p_last_update'] = lastUpdate;
    }

    return params;
  }
}

/// Aggregated result from a full syncAll run.
class MasterDataSyncSummary {
  final List<MasterDataTypeResult> results;
  final String? runId;
  final MasterDataSyncMode mode;
  final MasterDataRunStatus status;

  const MasterDataSyncSummary(
    this.results, {
    this.runId,
    this.mode = MasterDataSyncMode.incremental,
    this.status = MasterDataRunStatus.success,
  });

  int get rowCount => results.fold(0, (sum, result) => sum + result.rowsSaved);
  int get rowsReceived =>
      results.fold(0, (sum, result) => sum + result.rowsReceived);
  bool get hasFailures => results.any((result) => result.isFailure);
  bool get allNoChanges =>
      results.isNotEmpty &&
      results.every(
        (result) => result.status == MasterDataTypeRunStatus.noChanges,
      );
  int get failedTypesCount =>
      results.where((result) => result.isFailure).length;

  /// Whether a mandatory type failed, causing
  /// the sync to abort early.
  bool get abortedEarly => results.any(
    (r) => r.isFailure && r.type.isMandatory,
  );
}

/// Result for a single data type sync operation.
class MasterDataTypeResult {
  final MasterDataType type;
  final MasterDataTypeRunStatus status;
  final int rowsReceived;
  final int rowsSaved;
  final int pagesCount;
  final String? serverTime;
  final String? oldServerTime;
  final String? newServerTime;
  final String? sentLastUpdate;
  final String? errorCode;
  final String? error;
  final String? detailsJson;
  final List<String> warnings;

  const MasterDataTypeResult({
    required this.type,
    this.status = MasterDataTypeRunStatus.success,
    int? rowCount,
    int? rowsReceived,
    int? rowsSaved,
    this.pagesCount = 0,
    this.serverTime,
    this.oldServerTime,
    this.newServerTime,
    this.sentLastUpdate,
    this.errorCode,
    this.error,
    this.detailsJson,
    this.warnings = const [],
  }) : rowsReceived = rowsReceived ?? rowCount ?? 0,
       rowsSaved = rowsSaved ?? rowCount ?? 0;

  int get rowCount => rowsSaved;
  bool get isFailure => status.isFailure || error != null;
  bool get hasWarnings => warnings.isNotEmpty;
}

class MasterDataContextException extends SyncException {
  const MasterDataContextException(super.message, {super.code});
}

/// View model for master sync state displayed in UI.
class MasterSyncStateView {
  final String syncType;
  final String? scopeLabel;
  final String? lastSuccessTime;
  final String? lastServerTime;
  final String lastStatus;
  final String? lastError;

  const MasterSyncStateView({
    required this.syncType,
    required this.scopeLabel,
    required this.lastSuccessTime,
    required this.lastServerTime,
    required this.lastStatus,
    required this.lastError,
  });

  String get displayLabel {
    final scope = scopeLabel?.trim();
    if (scope == null || scope.isEmpty) return syncType;
    return '$syncType / $scope';
  }
}
