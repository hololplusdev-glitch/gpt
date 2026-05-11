import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:pos_flutter/core/errors/app_exception.dart';
import 'package:pos_flutter/core/network/api_client.dart';
import 'package:pos_flutter/core/persistence/daos/audit_dao.dart';
import 'package:pos_flutter/core/persistence/daos/master_data_dao.dart';
import 'package:pos_flutter/core/services/master_data/backend_value_reader.dart';
import 'package:pos_flutter/core/services/master_data/master_data_mapper.dart';
import 'package:pos_flutter/core/services/master_data/master_data_contract.dart';

import 'package:pos_flutter/core/services/time/clock.dart';
import 'package:pos_flutter/core/network/network_models.dart';
import 'package:pos_flutter/shared/models/enums.dart';

// Types are in master_data_contract.dart

class MasterDataSyncCancelHandle {
  final CancelToken _token;
  MasterDataSyncCancelHandle() : _token = CancelToken();
  bool get isCancelled => _token.isCancelled;
  void cancel([String? reason]) => _token.cancel(reason);
}

class MasterDataSyncProgress {
  final String typeCode;
  final String typeLabel;
  final int currentSection;
  final int totalSections;
  final double sectionProgress;
  final int currentPage;
  final int totalPages;

  const MasterDataSyncProgress({
    required this.typeCode,
    required this.typeLabel,
    required this.currentSection,
    required this.totalSections,
    required this.sectionProgress,
    required this.currentPage,
    required this.totalPages,
  });
}

class MasterDataSyncService {
  static int _idSequence = 0;

  final LocalApiClient _apiClient;
  final MasterDataDao _masterDataDao;
  final AuditDao _auditDao;
  final Clock _clock;
  final MasterDataMapper _mapper;

  const MasterDataSyncService({
    required LocalApiClient apiClient,
    required MasterDataDao masterDataDao,
    required AuditDao auditDao,
    required MasterDataMapper mapper,
    Clock clock = const SystemClock(),
  }) : _apiClient = apiClient,
       _masterDataDao = masterDataDao,
       _auditDao = auditDao,
       _mapper = mapper,
       _clock = clock;

  MasterDataSyncCancelHandle createCancelHandle() =>
      MasterDataSyncCancelHandle();

  Future<HealthCheckResult> checkConnection(SyncProfile profile) async {
    try {
      _apiClient.configure(profile);
      final baseUrl = _apiClient.debugBaseUrl;
      if (baseUrl.endsWith(ApiPaths.data)) {
        return HealthCheckResult(
          status: HealthStatus.degraded,
          service: 'Backend API',
          error: 'API baseUrl must not end with /data.',
          latencyMs: 0,
          checkedAt: _clock.now(),
        );
      }

      final context = MasterDataSyncContext(
        custCode: profile.custCode.trim(),
        bootstrapUserId: profile.bootstrapUserId.trim().isEmpty
            ? '1'
            : profile.bootstrapUserId.trim(),
        pageLimit: 1,
      );
      final queryParams = context.queryParameters(
        type: MasterDataType.posMachine,
        offset: 0,
        lastUpdate: null,
      );

      final response = await _apiClient.get<dynamic>(
        ApiPaths.data,
        queryParameters: queryParams,
      );

      final body = response.data;
      if (body is! Map) {
        return HealthCheckResult(
          status: HealthStatus.degraded,
          service: 'Backend API',
          error: 'Response was not a JSON object.',
          latencyMs: 0,
          checkedAt: _clock.now(),
        );
      }
      final data = Map<String, dynamic>.from(body);
      final status = data['status']?.toString().toUpperCase();
      if (status != 'OK' && status != 'ERROR') {
        return HealthCheckResult(
          status: HealthStatus.degraded,
          service: 'Backend API',
          error: 'Unexpected response status.',
          latencyMs: 0,
          checkedAt: _clock.now(),
        );
      }
      if (status == 'ERROR') {
        final errorMsg = data['message']?.toString() ?? 'API rejected request';
        return HealthCheckResult(
          status: HealthStatus.degraded,
          service: 'Backend API',
          error: errorMsg,
          latencyMs: 0,
          checkedAt: _clock.now(),
        );
      }
      return HealthCheckResult(
        status: HealthStatus.ok,
        service: 'Backend API',
        latencyMs: 0,
        checkedAt: _clock.now(),
      );
    } catch (e) {
      return HealthCheckResult(
        status: HealthStatus.degraded,
        service: 'Backend API',
        error: ErrorMapper.userMessage(e),
        latencyMs: 0,
        checkedAt: _clock.now(),
      );
    }
  }

  Future<MasterDataSyncSummary> syncAll(
    MasterDataSyncContext context, {
    MasterDataSyncMode mode = MasterDataSyncMode.incremental,
    MasterDataSyncCancelHandle? cancelHandle,
    void Function(MasterDataSyncProgress)? onProgress,
  }) async {
    // WHY: Pre-flight validation — only tenant and bootstrap user are required.
    // Runtime machine/store/price-level filtering happens locally after login.
    _validateSyncContext(context);

    final results = <MasterDataTypeResult>[];
    final runId = _newId('md_run');
    final startedAt = _clock.now();
    var totalSteps = MasterDataType.syncOrder.length;
    await _insertRun(runId: runId, mode: mode, context: context, at: startedAt);
    var cancelled = false;

    for (final type in MasterDataType.syncOrder) {
      if (cancelHandle?.isCancelled ?? false) {
        cancelled = true;
        results.add(
          MasterDataTypeResult(
            type: type,
            status: MasterDataTypeRunStatus.cancelled,
            errorCode: 'CANCELLED',
            error: 'Sync was cancelled by user.',
          ),
        );
        break;
      }

      onProgress?.call(
        MasterDataSyncProgress(
          typeCode: type.code,
          typeLabel: type.name,
          currentSection: results.length,
          totalSections: totalSteps,
          sectionProgress: 0.0,
          currentPage: 1,
          totalPages: 1,
        ),
      );

      final result = await syncType(
        context,
        type,
        mode: mode,
        runId: runId,
        cancelHandle: cancelHandle,
        onTypeProgress: (progress, currentPage, totalPages) {
          onProgress?.call(
            MasterDataSyncProgress(
              typeCode: type.code,
              typeLabel: type.name,
              currentSection: results.length,
              totalSections: totalSteps,
              sectionProgress: progress,
              currentPage: currentPage,
              totalPages: totalPages,
            ),
          );
        },
      );
      results.add(result);
      // WHY: Mandatory types must succeed AND return rows — abort sync otherwise.
      if (MasterDataType.mandatoryTypes.contains(type)) {
        if (result.isFailure) {
          // Ensure the result reflects the failure if it was only empty rows.
          if (result.error == null && result.rowCount == 0) {
            results[results.length - 1] = MasterDataTypeResult(
              type: type,
              rowCount: 0,
              serverTime: result.serverTime,
              error: '${type.code} returned 0 rows — setup incomplete.',
            );
          }
          break;
        }
      } else if (result.isFailure) {}

      if (type == MasterDataType.posMachine && !result.isFailure) {
        final devicePrivilegeResults =
            await _syncDevicePrivilegesForDownloadedUsers(
              context,
              mode: mode,
              runId: runId,
              cancelHandle: cancelHandle,
              onProgress: onProgress,
              completedSectionsBeforeDevicePriv: results.length,
              totalSectionsWithoutDevicePriv: MasterDataType.syncOrder.length,
              onTotalSectionsResolved: (value) => totalSteps = value,
            );

        results.addAll(devicePrivilegeResults);

        final totalPrivileges = await _masterDataDao.countDevicePrivileges(
          context.custCode,
        );

        if (totalPrivileges == 0) {
          results.add(
            const MasterDataTypeResult(
              type: MasterDataType.devicePrivilege,
              status: MasterDataTypeRunStatus.failed,
              errorCode: 'NO_DEVICE_PRIVILEGES',
              error: 'No DEVICE_PRIV rows were downloaded for any POS user.',
            ),
          );
          break;
        }
      }
    }

    onProgress?.call(
      MasterDataSyncProgress(
        typeCode: MasterDataType.posMachine.code,
        typeLabel: MasterDataType.posMachine.name,
        currentSection: totalSteps,
        totalSections: totalSteps,
        sectionProgress: 1.0,
        currentPage: 1,
        totalPages: 1,
      ),
    );
    final runStatus = _runStatusFor(results, cancelled: cancelled);
    await _finishRun(
      runId: runId,
      status: runStatus,
      startedAt: startedAt,
      results: results,
    );
    await _writeSyncAudit(
      runId: runId,
      mode: mode,
      context: context,
      startedAt: startedAt,
      status: runStatus,
      results: results,
    );

    return MasterDataSyncSummary(
      results,
      runId: runId,
      mode: mode,
      status: runStatus,
    );
  }

  Future<MasterDataTypeResult> syncType(
    MasterDataSyncContext context,
    MasterDataType type, {
    MasterDataSyncMode mode = MasterDataSyncMode.incremental,
    String? runId,
    MasterDataSyncCancelHandle? cancelHandle,
    void Function(double progress, int currentPage, int totalPages)?
    onTypeProgress,
  }) async {
    _validateSyncContext(context);
    final ownsRun = runId == null;
    final effectiveRunId = runId ?? _newId('md_run');
    final runStartedAt = _clock.now();
    if (ownsRun) {
      await _insertRun(
        runId: effectiveRunId,
        mode: mode,
        context: context,
        at: runStartedAt,
      );
    }

    final result = await _syncTypeIntoRun(
      context,
      type,
      mode: mode,
      runId: effectiveRunId,
      cancelHandle: cancelHandle,
      onTypeProgress: onTypeProgress,
    );

    if (ownsRun) {
      final status = _runStatusFor([result]);
      await _finishRun(
        runId: effectiveRunId,
        status: status,
        startedAt: runStartedAt,
        results: [result],
      );
      await _writeSyncAudit(
        runId: effectiveRunId,
        mode: mode,
        context: context,
        startedAt: runStartedAt,
        status: status,
        results: [result],
      );
    }
    return result;
  }

  Future<MasterDataTypeResult> _syncTypeIntoRun(
    MasterDataSyncContext context,
    MasterDataType type, {
    required MasterDataSyncMode mode,
    required String runId,
    MasterDataSyncCancelHandle? cancelHandle,
    void Function(double progress, int currentPage, int totalPages)?
    onTypeProgress,
  }) async {
    final oldServerTime = await _lastServerTime(type, context);
    final sentLastUpdate = mode == MasterDataSyncMode.incremental
        ? oldServerTime
        : null;
    final typeRunId = _newId('md_type');
    final startedAt = _clock.now();
    await _insertTypeRun(
      id: typeRunId,
      runId: runId,
      type: type,
      oldServerTime: oldServerTime,
      sentLastUpdate: sentLastUpdate,
      at: startedAt,
    );

    var offset = 0;
    var totalRows = 0;
    var pagesCount = 0;
    String? firstServerTime;
    final rows = <Map<String, dynamic>>[];
    final warnings = <String>[];

    try {
      _validateTypeRequestContext(type, context);

      while (true) {
        if (cancelHandle?.isCancelled ?? false) {
          throw const SyncException(
            'Sync was cancelled by user.',
            code: 'CANCELLED',
          );
        }

        final pageNo = pagesCount + 1;
        final pageStartedAt = _clock.now();
        late _MasterDataPage page;
        try {
          page = await _fetchPage(
            context: context,
            type: type,
            offset: offset,
            lastUpdate: sentLastUpdate,
            cancelHandle: cancelHandle,
          );
        } catch (error) {
          await _insertPageRun(
            id: _newId('md_page'),
            typeRunId: typeRunId,
            type: type,
            pageNo: pageNo,
            offset: offset,
            limit: context.pageLimit,
            durationMs: _clock.now().difference(pageStartedAt).inMilliseconds,
            status: MasterDataTypeRunStatus.failed,
            errorMessage: ErrorMapper.userMessage(error),
          );
          rethrow;
        }

        pagesCount++;
        if (firstServerTime == null) {
          firstServerTime = page.serverTime;
        } else if (firstServerTime != page.serverTime) {
          warnings.add(
            'server_time changed between pages; using first page server_time.',
          );
        }

        rows.addAll(page.items);
        totalRows += page.items.length;

        final limit = page.limit > 0 ? page.limit : context.pageLimit;
        final totalPages = page.total > 0 && limit > 0
            ? (page.total / limit).ceil()
            : pageNo;
        final progress = page.total > 0
            ? (totalRows / page.total).clamp(0.0, 1.0)
            : 1.0;
        onTypeProgress?.call(progress, pageNo, totalPages);

        await _insertPageRun(
          id: _newId('md_page'),
          typeRunId: typeRunId,
          type: type,
          pageNo: pageNo,
          offset: offset,
          limit: limit,
          paginationTotal: page.total,
          hasMore: page.hasMore ? 'Y' : 'N',
          rowsReceived: page.items.length,
          serverTime: page.serverTime,
          durationMs: _clock.now().difference(pageStartedAt).inMilliseconds,
          status: MasterDataTypeRunStatus.success,
        );

        if (!page.hasMore) break;
        offset += limit;
      }

      final plan = _mapper.mapRows(
        type: type,
        context: context,
        rows: rows,
        cachedAt: _clock.now(),
      );

      _validateContextRowsMapped(type, plan, context);
      await _validateZeroRowsForMode(
        type: type,
        context: context,
        mode: mode,
        rows: rows,
        warnings: warnings,
      );

      final status = rows.isEmpty
          ? MasterDataTypeRunStatus.noChanges
          : MasterDataTypeRunStatus.success;

      await _masterDataDao.runInTransaction(() async {
        if (type == MasterDataType.devicePrivilege &&
            mode == MasterDataSyncMode.forceFull) {
          await _masterDataDao.deleteDevicePrivilegesForUser(
            custCode: context.custCode,
            userId: context.syncUserId,
          );
        }

        if (!plan.isEmpty) {
          await _masterDataDao.persistPlanInCurrentTransaction(plan);
        }
        await _saveSyncState(
          type,
          context,
          status: status.code,
          serverTime: firstServerTime,
        );
      });

      final detailsJson = warnings.isEmpty
          ? null
          : jsonEncode(<String, dynamic>{'warnings': warnings});
      await _finishTypeRun(
        id: typeRunId,
        status: status,
        rowsReceived: totalRows,
        rowsSaved: rows.length,
        pagesCount: pagesCount,
        newServerTime: firstServerTime,
        detailsJson: detailsJson,
      );
      return MasterDataTypeResult(
        type: type,
        status: status,
        rowsReceived: totalRows,
        rowsSaved: rows.length,
        pagesCount: pagesCount,
        serverTime: firstServerTime,
        oldServerTime: oldServerTime,
        newServerTime: firstServerTime,
        sentLastUpdate: sentLastUpdate,
        detailsJson: detailsJson,
        warnings: List.unmodifiable(warnings),
      );
    } catch (error) {
      final status = _isCancellation(error)
          ? MasterDataTypeRunStatus.cancelled
          : MasterDataTypeRunStatus.failed;
      final message = ErrorMapper.userMessage(error);
      final code = _errorCode(error);
      await _saveSyncState(type, context, status: status.code, error: message);
      await _finishTypeRun(
        id: typeRunId,
        status: status,
        rowsReceived: totalRows,
        rowsSaved: 0,
        pagesCount: pagesCount,
        newServerTime: null,
        errorCode: code,
        errorMessage: message,
        detailsJson: warnings.isEmpty
            ? null
            : jsonEncode(<String, dynamic>{'warnings': warnings}),
      );
      return MasterDataTypeResult(
        type: type,
        status: status,
        rowsReceived: totalRows,
        rowsSaved: 0,
        pagesCount: pagesCount,
        serverTime: firstServerTime,
        oldServerTime: oldServerTime,
        newServerTime: null,
        sentLastUpdate: sentLastUpdate,
        errorCode: code,
        error: message,
        detailsJson: warnings.isEmpty
            ? null
            : jsonEncode(<String, dynamic>{'warnings': warnings}),
        warnings: List.unmodifiable(warnings),
      );
    }
  }

  Future<List<MasterDataTypeResult>> _syncDevicePrivilegesForDownloadedUsers(
    MasterDataSyncContext context, {
    required MasterDataSyncMode mode,
    required String runId,
    MasterDataSyncCancelHandle? cancelHandle,
    void Function(MasterDataSyncProgress)? onProgress,
    required int completedSectionsBeforeDevicePriv,
    required int totalSectionsWithoutDevicePriv,
    void Function(int totalSections)? onTotalSectionsResolved,
  }) async {
    final users = await _masterDataDao.listDownloadedPosUsers(context.custCode);
    final results = <MasterDataTypeResult>[];

    if (users.isEmpty) {
      return const [
        MasterDataTypeResult(
          type: MasterDataType.devicePrivilege,
          status: MasterDataTypeRunStatus.failed,
          errorCode: 'NO_USERS_FOR_DEVICE_PRIV',
          error: 'USER returned no active POS users to sync DEVICE_PRIV.',
        ),
      ];
    }

    final totalSections = totalSectionsWithoutDevicePriv + users.length;
    onTotalSectionsResolved?.call(totalSections);

    for (var index = 0; index < users.length; index++) {
      final user = users[index];

      if (cancelHandle?.isCancelled ?? false) {
        results.add(
          const MasterDataTypeResult(
            type: MasterDataType.devicePrivilege,
            status: MasterDataTypeRunStatus.cancelled,
            errorCode: 'CANCELLED',
            error: 'DEVICE_PRIV per-user sync was cancelled.',
          ),
        );
        break;
      }

      final userSection = completedSectionsBeforeDevicePriv + index;

      onProgress?.call(
        MasterDataSyncProgress(
          typeCode: MasterDataType.devicePrivilege.code,
          typeLabel:
              'صلاحيات نقاط التشغيل للمستخدم ${user.id} (${index + 1}/${users.length})',
          currentSection: userSection,
          totalSections: totalSections,
          sectionProgress: 0.0,
          currentPage: 1,
          totalPages: 1,
        ),
      );

      final userContext = context.copyWith(
        bootstrapUserId: user.id,
        branchNo: user.branchNo,
      );

      final result = await syncType(
        userContext,
        MasterDataType.devicePrivilege,
        mode: MasterDataSyncMode.forceFull,
        runId: runId,
        cancelHandle: cancelHandle,
        onTypeProgress: (progress, currentPage, totalPages) {
          onProgress?.call(
            MasterDataSyncProgress(
              typeCode: MasterDataType.devicePrivilege.code,
              typeLabel:
                  'صلاحيات نقاط التشغيل للمستخدم ${user.id} (${index + 1}/${users.length})',
              currentSection: userSection,
              totalSections: totalSections,
              sectionProgress: progress,
              currentPage: currentPage,
              totalPages: totalPages,
            ),
          );
        },
      );

      if (result.errorCode == 'NO_MACHINE_PRIV') {
        results.add(
          MasterDataTypeResult(
            type: MasterDataType.devicePrivilege,
            status: MasterDataTypeRunStatus.noChanges,
            rowsReceived: 0,
            rowsSaved: 0,
            errorCode: null,
            error: null,
            warnings: ['No POS machine privileges for user ${user.id}.'],
          ),
        );
      } else {
        results.add(result);
      }

      onProgress?.call(
        MasterDataSyncProgress(
          typeCode: MasterDataType.devicePrivilege.code,
          typeLabel:
              'صلاحيات نقاط التشغيل للمستخدم ${user.id} (${index + 1}/${users.length})',
          currentSection: userSection,
          totalSections: totalSections,
          sectionProgress: 1.0,
          currentPage: 1,
          totalPages: 1,
        ),
      );
    }

    return results;
  }

  /// WHY: Pre-flight validation — ensures all required Backend identity params
  /// are present before the sync loop begins. A clear local error is far more
  /// debuggable than a remote 400/500 with opaque Backend error codes.
  void _validateSyncContext(MasterDataSyncContext context) {
    final missing = <String>[];
    if (context.custCode.trim().isEmpty) missing.add('p_cust_code');
    if (context.syncUserId.trim().isEmpty) missing.add('p_usr_id');
    if (missing.isNotEmpty) {
      throw SyncException(
        'Master data sync aborted — missing required params: '
        '${missing.join(', ')}. Complete POS setup first.',
        code: 'MASTER_DATA_MISSING_PARAMS',
      );
    }
  }

  void _validateTypeRequestContext(
    MasterDataType type,
    MasterDataSyncContext context,
  ) {
    // SSOT: all p_type downloads are global for the tenant/bootstrap user.
    // Never require runtime machine/store/price-level context here.
  }

  void _validateContextRowsMapped(
    MasterDataType type,
    MasterDataPersistencePlan plan,
    MasterDataSyncContext context,
  ) {
    if (plan.isEmpty) return;

    if (type == MasterDataType.posMachine && plan.posMachines.isEmpty) {
      throw const SyncException(
        'POS_MACHINE returned no machine profiles.',
        code: 'MASTER_DATA_MACHINE_NOT_FOUND',
      );
    }
  }

  Future<void> _validateZeroRowsForMode({
    required MasterDataType type,
    required MasterDataSyncContext context,
    required MasterDataSyncMode mode,
    required List<Map<String, dynamic>> rows,
    required List<String> warnings,
  }) async {
    if (rows.isNotEmpty) return;

    if (mode == MasterDataSyncMode.initial ||
        mode == MasterDataSyncMode.forceFull) {
      if (MasterDataType.mandatoryTypes.contains(type)) {
        throw SyncException(
          '${type.code} returned 0 rows; this type is mandatory for ${mode.code} sync.',
          code: 'MASTER_DATA_MANDATORY_EMPTY',
        );
      }
      return;
    }

    // Incremental no-change is valid for tenant-wide bootstrap downloads.
    // Login/readiness will validate whether the cached data can run POS offline.
  }

  Future<_MasterDataPage> _fetchPage({
    required MasterDataSyncContext context,
    required MasterDataType type,
    required int offset,
    required String? lastUpdate,
    MasterDataSyncCancelHandle? cancelHandle,
  }) async {
    final queryParams = context.queryParameters(
      type: type,
      offset: offset,
      lastUpdate: lastUpdate,
    );

    // WHY: Validate baseUrl doesn't end with /data to prevent /data/data.
    final baseUrl = _apiClient.debugBaseUrl;
    if (baseUrl.endsWith(ApiPaths.data)) {
      throw const SyncException(
        'API baseUrl must not end with /data. '
        'The sync engine appends /data automatically.',
        code: 'MASTER_DATA_BAD_BASE_URL',
      );
    }

    final response = await _apiClient.get<dynamic>(
      ApiPaths.data,
      queryParameters: queryParams,
      cancelToken: cancelHandle?._token,
    );
    final body = response.data;

    if (body is! Map) {
      throw SyncException(
        'Master data response was not a JSON object.',
        code: 'MASTER_DATA_INVALID_RESPONSE',
      );
    }

    final data = Map<String, dynamic>.from(body);
    final status = data['status']?.toString().toUpperCase();
    final responseType = data['type']?.toString().toUpperCase();
    final serverTime = data['server_time']?.toString();

    // WHY: status must be OK or ERROR — anything else is a contract violation.
    if (status != 'OK' && status != 'ERROR') {
      throw SyncException(
        'Unexpected response status: "$status". Expected OK or ERROR.',
        code: 'MASTER_DATA_INVALID_STATUS',
      );
    }

    if (status == 'ERROR') {
      final errorCode = data['code']?.toString() ?? 'MASTER_DATA_API_ERROR';
      final errorMsg =
          data['message']?.toString() ??
          'Master data API rejected the request.';

      if (type == MasterDataType.devicePrivilege &&
          errorCode == 'NO_MACHINE_PRIV') {
        return _MasterDataPage(
          items: const [],
          serverTime: _clock.now().toIso8601String(),
          hasMore: false,
          limit: context.pageLimit,
          total: 0,
        );
      }

      throw SyncException(errorMsg, code: errorCode);
    }

    // WHY: response.type must be present and match the requested p_type.
    if (responseType == null || responseType != type.code) {
      throw SyncException(
        'response.type=$responseType does not match requested p_type=${type.code}.',
        code: 'TYPE_MISMATCH',
      );
    }

    if (serverTime == null || serverTime.isEmpty) {
      throw SyncException(
        '${type.code} response is missing required server_time.',
        code: 'MASTER_DATA_MISSING_SERVER_TIME',
      );
    }

    final itemsValue = data['items'];
    // WHY: items must be an array — anything else is a contract violation.
    if (status == 'OK' && itemsValue != null && itemsValue is! List) {
      throw const SyncException(
        'response.items must be an array.',
        code: 'MASTER_DATA_INVALID_ITEMS',
      );
    }
    final items = itemsValue is List
        ? itemsValue
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList()
        : <Map<String, dynamic>>[];

    // WHY: pagination block is mandatory when status == OK.
    final paginationRaw = data['pagination'];
    if (paginationRaw == null) {
      throw SyncException(
        '${type.code} response is missing required pagination block.',
        code: 'MISSING_PAGINATION',
      );
    }
    if (paginationRaw is! Map) {
      throw SyncException(
        '${type.code} pagination block must be a JSON object.',
        code: 'MISSING_PAGINATION',
      );
    }
    final pagination = Map<String, dynamic>.from(paginationRaw);

    // WHY: has_more must be strictly Y or N — unexpected values are a contract violation.
    final hasMoreRaw = pagination['has_more']?.toString().toUpperCase();
    if (hasMoreRaw != 'Y' && hasMoreRaw != 'N') {
      throw SyncException(
        'pagination.has_more="$hasMoreRaw" is not Y/N for ${type.code}.',
        code: 'INVALID_HAS_MORE',
      );
    }

    return _MasterDataPage(
      items: items,
      serverTime: serverTime,
      hasMore: BackendValueReader.parseBool(pagination['has_more']),
      limit: BackendValueReader.parseInt(pagination['limit']) ?? items.length,
      total: BackendValueReader.parseInt(pagination['total']) ?? 0,
    );
  }

  String _newId(String prefix) {
    final seq = _idSequence++;
    return '${prefix}_${_clock.now().microsecondsSinceEpoch}_$seq';
  }

  MasterDataRunStatus _runStatusFor(
    List<MasterDataTypeResult> results, {
    bool cancelled = false,
  }) {
    if (cancelled ||
        results.any(
          (result) => result.status == MasterDataTypeRunStatus.cancelled,
        )) {
      return MasterDataRunStatus.cancelled;
    }
    final failures = results.where((result) => result.isFailure).toList();
    if (failures.isEmpty) return MasterDataRunStatus.success;
    final mandatoryFailure = failures.any(
      (result) => MasterDataType.mandatoryTypes.contains(result.type),
    );
    return mandatoryFailure
        ? MasterDataRunStatus.failed
        : MasterDataRunStatus.partial;
  }

  bool _isCancellation(Object error) {
    return error is SyncException && error.code == 'CANCELLED' ||
        error is DioException && error.type == DioExceptionType.cancel;
  }

  String? _errorCode(Object error) {
    if (error is AppException) return error.code;
    if (error is DioException && error.type == DioExceptionType.cancel) {
      return 'CANCELLED';
    }
    return null;
  }

  Future<void> _insertRun({
    required String runId,
    required MasterDataSyncMode mode,
    required MasterDataSyncContext context,
    required DateTime at,
  }) async {
    await _masterDataDao.insertRun(
      runId: runId,
      modeCode: mode.code,
      tenantCode: context.custCode,
      userId: context.syncUserId,
      branchNo: '',
      terminalNo: '',
      at: at,
    );
  }

  Future<void> _finishRun({
    required String runId,
    required MasterDataRunStatus status,
    required DateTime startedAt,
    required List<MasterDataTypeResult> results,
  }) async {
    final failed = results.where((result) => result.isFailure).toList();
    final details = <String, dynamic>{
      'types': results.map(_typeResultJson).toList(),
    };
    await _masterDataDao.finishRun(
      runId: runId,
      statusCode: status.code,
      finishedAt: _clock.now(),
      totalRowsReceived: results.fold(
        0,
        (sum, result) => sum + result.rowsReceived,
      ),
      totalRowsSaved: results.fold(0, (sum, result) => sum + result.rowsSaved),
      failedTypesCount: failed.length,
      errorSummary: failed
          .map((result) => '${result.type.code}: ${result.error}')
          .join('; '),
      detailsJson: jsonEncode(details),
    );
  }

  Future<void> _insertTypeRun({
    required String id,
    required String runId,
    required MasterDataType type,
    required String? oldServerTime,
    required String? sentLastUpdate,
    required DateTime at,
  }) async {
    await _masterDataDao.insertTypeRun(
      id: id,
      runId: runId,
      typeCode: type.code,
      oldServerTime: oldServerTime,
      sentLastUpdate: sentLastUpdate,
      at: at,
    );
  }

  Future<void> _finishTypeRun({
    required String id,
    required MasterDataTypeRunStatus status,
    required int rowsReceived,
    required int rowsSaved,
    required int pagesCount,
    required String? newServerTime,
    String? errorCode,
    String? errorMessage,
    String? detailsJson,
  }) async {
    await _masterDataDao.finishTypeRun(
      id: id,
      statusCode: status.code,
      rowsReceived: rowsReceived,
      rowsSaved: rowsSaved,
      pagesCount: pagesCount,
      finishedAt: _clock.now(),
      newServerTime: newServerTime,
      errorCode: errorCode,
      errorMessage: errorMessage,
      detailsJson: detailsJson,
    );
  }

  Future<void> _insertPageRun({
    required String id,
    required String typeRunId,
    required MasterDataType type,
    required int pageNo,
    required int offset,
    required int limit,
    int? paginationTotal,
    String? hasMore,
    int rowsReceived = 0,
    String? serverTime,
    int? durationMs,
    required MasterDataTypeRunStatus status,
    String? errorMessage,
  }) async {
    await _masterDataDao.insertPageRun(
      id: id,
      typeRunId: typeRunId,
      typeCode: type.code,
      pageNo: pageNo,
      offset: offset,
      limit: limit,
      paginationTotal: paginationTotal,
      hasMore: hasMore,
      rowsReceived: rowsReceived,
      serverTime: serverTime,
      durationMs: durationMs,
      statusCode: status.code,
      errorMessage: errorMessage,
    );
  }

  Future<void> _writeSyncAudit({
    required String runId,
    required MasterDataSyncMode mode,
    required MasterDataSyncContext context,
    required DateTime startedAt,
    required MasterDataRunStatus status,
    required List<MasterDataTypeResult> results,
  }) async {
    final details = <String, dynamic>{
      'mode': mode.code,
      'custCode': context.custCode,
      'usrId': context.syncUserId,
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': _clock.now().toIso8601String(),
      'status': status.code,
      'totalRowsReceived': results.fold(
        0,
        (sum, result) => sum + result.rowsReceived,
      ),
      'failedTypesCount': results.where((result) => result.isFailure).length,
      'types': results.map(_typeResultJson).toList(),
    };
    final action = status == MasterDataRunStatus.success
        ? AuditAction.syncSucceeded
        : AuditAction.syncFailed;
    await _auditDao.log(
      id: _newId('audit_md_sync'),
      action: action,
      actorId: context.syncUserId,
      targetType: 'master_data_sync',
      targetId: runId,
      detailsJson: jsonEncode(details),
      terminalId: '',
      timestamp: _clock.now(),
    );
  }

  Map<String, dynamic> _typeResultJson(MasterDataTypeResult result) {
    return <String, dynamic>{
      'pType': result.type.code,
      'status': result.status.code,
      'rowsReceived': result.rowsReceived,
      'rowsSaved': result.rowsSaved,
      'pagesCount': result.pagesCount,
      'oldServerTime': result.oldServerTime,
      'newServerTime': result.newServerTime,
      'sentLastUpdate': result.sentLastUpdate,
      'errorCode': result.errorCode,
      'errorMessage': result.error,
      'warnings': result.warnings,
    };
  }

  Future<String?> _lastServerTime(
    MasterDataType type,
    MasterDataSyncContext context,
  ) async {
    return _masterDataDao.lastServerTime(type.code, context: context);
  }

  Future<void> _saveSyncState(
    MasterDataType type,
    MasterDataSyncContext context, {
    required String status,
    String? serverTime,
    String? error,
  }) async {
    await _masterDataDao.saveSyncState(
      type.code,
      context: context,
      status: status,
      now: _clock.now(),
      serverTime: serverTime,
      error: error,
    );
  }
}

class _MasterDataPage {
  final List<Map<String, dynamic>> items;
  final String? serverTime;
  final bool hasMore;
  final int limit;
  final int total;

  const _MasterDataPage({
    required this.items,
    required this.serverTime,
    required this.hasMore,
    required this.limit,
    required this.total,
  });
}
