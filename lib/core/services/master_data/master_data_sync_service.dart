import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/network/api_client.dart';
import 'package:holol_POS/core/persistence/daos/audit_dao.dart';
import 'package:holol_POS/core/persistence/daos/master_data_dao.dart';
import 'package:holol_POS/core/services/master_data/master_data_mapper.dart';
import 'package:holol_POS/core/services/master_data/master_data_contract.dart';

import 'package:holol_POS/core/services/time/clock.dart';
import 'package:holol_POS/core/network/network_models.dart';
import 'package:holol_POS/shared/models/enums.dart';

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

  int _latencyMsSince(DateTime startedAt) {
    final value = _clock.now().difference(startedAt).inMilliseconds;
    return value < 0 ? 0 : value;
  }

  Future<HealthCheckResult> checkConnection(SyncProfile profile) async {
    final startedAt = _clock.now();
    try {
      _apiClient.configure(profile);
      final baseUrl = _apiClient.debugBaseUrl;
      if (baseUrl.endsWith(ApiPaths.data)) {
        return HealthCheckResult(
          status: HealthStatus.degraded,
          service: 'Backend API',
          error: 'API baseUrl must not end with /data.',
          latencyMs: _latencyMsSince(startedAt),
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

      final data = _responseMapOrNull(response.data);
      if (data == null) {
        return HealthCheckResult(
          status: HealthStatus.degraded,
          service: 'Backend API',
          error: 'Response was not a JSON object.',
          latencyMs: _latencyMsSince(startedAt),
          checkedAt: _clock.now(),
        );
      }

      final status = _responseStatus(data);
      if (!_isKnownResponseStatus(status)) {
        return HealthCheckResult(
          status: HealthStatus.degraded,
          service: 'Backend API',
          error: 'Unexpected response status.',
          latencyMs: _latencyMsSince(startedAt),
          checkedAt: _clock.now(),
        );
      }

      if (_isErrorResponse(status)) {
        return HealthCheckResult(
          status: HealthStatus.degraded,
          service: 'Backend API',
          error: _responseErrorMessage(data, fallback: 'API rejected request'),
          latencyMs: _latencyMsSince(startedAt),
          checkedAt: _clock.now(),
        );
      }
      return HealthCheckResult(
        status: HealthStatus.ok,
        service: 'Backend API',
        latencyMs: _latencyMsSince(startedAt),
        checkedAt: _clock.now(),
      );
    } catch (e) {
      return HealthCheckResult(
        status: HealthStatus.degraded,
        service: 'Backend API',
        error: ErrorMapper.userMessage(e),
        latencyMs: _latencyMsSince(startedAt),
        checkedAt: _clock.now(),
      );
    }
  }

  Map<String, dynamic>? _responseMapOrNull(dynamic body) {
    if (body is! Map) return null;
    return Map<String, dynamic>.from(body);
  }

  String _responseStatus(Map<String, dynamic> data) {
    return _cleanResponseText(data['status']).toUpperCase();
  }

  bool _isKnownResponseStatus(String status) {
    return status == 'OK' || status == 'ERROR';
  }

  bool _isErrorResponse(String status) {
    return status == 'ERROR';
  }

  String _responseErrorMessage(
    Map<String, dynamic> data, {
    required String fallback,
  }) {
    final message = _firstCleanResponseText([
      data['message'],
      data['error'],
      data['details'],
    ]);
    return message.isEmpty ? fallback : message;
  }

  String _firstCleanResponseText(Iterable<Object?> values) {
    for (final value in values) {
      final text = _cleanResponseText(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _cleanResponseText(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
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
      if (type.isMandatory) {
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
      }

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

        final totalPrivileges = await _masterDataDao.countDevicePrivileges();

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
    final hasLocalSeed = await _hasLocalSeedForIncremental(type, context);
    final sentLastUpdate =
        mode == MasterDataSyncMode.incremental && hasLocalSeed
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
          page = await _fetchPageAdaptive(
            context: context,
            type: type,
            offset: offset,
            limit: context.effectivePageLimitFor(type),
            lastUpdate: sentLastUpdate,
            cancelHandle: cancelHandle,
            warnings: warnings,
          );
        } catch (error) {
          final pageFailureMessage = _pageFailureMessage(
            error: error,
            type: type,
            pageNo: pageNo,
            offset: offset,
            limit: context.effectivePageLimitFor(type),
            lastUpdate: sentLastUpdate,
          );

          await _insertPageRun(
            id: _newId('md_page'),
            typeRunId: typeRunId,
            type: type,
            pageNo: pageNo,
            offset: offset,
            limit: context.effectivePageLimitFor(type),
            durationMs: _clock.now().difference(pageStartedAt).inMilliseconds,
            status: MasterDataTypeRunStatus.failed,
            errorMessage: pageFailureMessage,
          );

          throw SyncException(pageFailureMessage, code: _errorCode(error));
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

        final limit = page.limit > 0
            ? page.limit
            : context.effectivePageLimitFor(type);
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

  String _pageFailureMessage({
    required Object error,
    required MasterDataType type,
    required int pageNo,
    required int offset,
    required int limit,
    required String? lastUpdate,
  }) {
    final details = <String>[
      type.code,
      'page=$pageNo',
      'offset=$offset',
      'limit=$limit',
      if (lastUpdate != null && lastUpdate.trim().isNotEmpty)
        'lastUpdate=${lastUpdate.trim()}',
    ].join(' ');

    return '$details: ${ErrorMapper.userMessage(error)}';
  }

  Future<bool> _hasLocalSeedForIncremental(
    MasterDataType type,
    MasterDataSyncContext context,
  ) async {
    switch (type) {
      case MasterDataType.customer:
        return await _masterDataDao.countCustomers() > 0;
      default:
        return true;
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
    final users = await _masterDataDao.listDownloadedPosUsers();
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
      if (type.isMandatory) {
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

  Future<_MasterDataPage> _fetchPageAdaptive({
    required MasterDataSyncContext context,
    required MasterDataType type,
    required int offset,
    required int limit,
    required String? lastUpdate,
    MasterDataSyncCancelHandle? cancelHandle,
    List<String>? warnings,
  }) async {
    try {
      return await _fetchPageWithLimit(
        context: context,
        type: type,
        offset: offset,
        limit: limit,
        lastUpdate: lastUpdate,
        cancelHandle: cancelHandle,
      );
    } catch (error) {
      if (!_isInvalidJsonPageError(error)) {
        rethrow;
      }

      if (limit <= 1) {
        throw SyncException(
          '${type.code} offset=$offset limit=1 returned invalid JSON.',
          code: 'BACKEND_INVALID_JSON',
          originalError: error,
        );
      }

      final leftLimit = limit ~/ 2;
      final rightLimit = limit - leftLimit;
      final rightOffset = offset + leftLimit;

      warnings?.add(
        '${type.code} offset=$offset limit=$limit returned invalid JSON; '
        'recovered by split into $leftLimit + $rightLimit.',
      );

      final left = await _fetchPageAdaptive(
        context: context,
        type: type,
        offset: offset,
        limit: leftLimit,
        lastUpdate: lastUpdate,
        cancelHandle: cancelHandle,
        warnings: warnings,
      );

      final right = await _fetchPageAdaptive(
        context: context,
        type: type,
        offset: rightOffset,
        limit: rightLimit,
        lastUpdate: lastUpdate,
        cancelHandle: cancelHandle,
        warnings: warnings,
      );

      return _mergeAdaptivePages(
        left: left,
        right: right,
        requestedLimit: limit,
      );
    }
  }

  Future<_MasterDataPage> _fetchPageWithLimit({
    required MasterDataSyncContext context,
    required MasterDataType type,
    required int offset,
    required int limit,
    required String? lastUpdate,
    MasterDataSyncCancelHandle? cancelHandle,
  }) async {
    final effectiveContext = context.copyWith(pageLimit: limit);

    return _fetchPage(
      context: effectiveContext,
      type: type,
      offset: offset,
      lastUpdate: lastUpdate,
      cancelHandle: cancelHandle,
    );
  }

  _MasterDataPage _mergeAdaptivePages({
    required _MasterDataPage left,
    required _MasterDataPage right,
    required int requestedLimit,
  }) {
    final mergedItems = <Map<String, dynamic>>[...left.items, ...right.items];

    final serverTime = left.serverTime ?? right.serverTime;
    final total = right.total > 0 ? right.total : left.total;

    return _MasterDataPage(
      items: mergedItems,
      total: total,
      limit: requestedLimit,
      hasMore: right.hasMore,
      serverTime: serverTime,
    );
  }

  bool _isInvalidJsonPageError(Object error) {
    final text = _errorDiagnosticText(error).toLowerCase();

    if (text.contains('formatexception')) return true;
    if (text.contains('unexpected character')) return true;
    if (text.contains('unexpected end')) return true;
    if (text.contains('syntaxerror')) return true;

    return text.contains('json') &&
        (text.contains('parse') ||
            text.contains('parser') ||
            text.contains('malformed') ||
            text.contains('invalid'));
  }

  String _errorDiagnosticText(Object error) {
    if (error is AppException) {
      return [
        error.code,
        error.message,
        error.originalError,
      ].where((value) => value != null).join(' | ');
    }

    return error.toString();
  }

  Future<Response<dynamic>> _getPageResponseWithRetry({
    required Map<String, dynamic> queryParams,
    MasterDataSyncCancelHandle? cancelHandle,
  }) async {
    const maxAttempts = 3;
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (cancelHandle?.isCancelled ?? false) {
        throw const SyncException(
          'Sync was cancelled by user.',
          code: 'CANCELLED',
        );
      }

      try {
        return await _apiClient.get<dynamic>(
          ApiPaths.data,
          queryParameters: queryParams,
          cancelToken: cancelHandle?._token,
        );
      } catch (error) {
        lastError = error;

        // Invalid JSON is deterministic for this exact payload/range.
        // Do not retry the same broken response. Let _fetchPageAdaptive split
        // the broken range immediately.
        if (_isInvalidJsonPageError(error)) {
          rethrow;
        }

        if (!_isRetryablePageFetchError(error) || attempt == maxAttempts) {
          rethrow;
        }

        await Future<void>.delayed(
          Duration(milliseconds: 350 * attempt * attempt),
        );
      }
    }

    throw lastError ??
        const SyncException(
          'Master data page request failed.',
          code: 'MASTER_DATA_PAGE_REQUEST_FAILED',
        );
  }

  bool _isRetryablePageFetchError(Object error) {
    if (error is! AppException) return false;

    final code = error.code ?? '';
    if (code == 'CANCELLED') return false;

    if (code == 'NETWORK_ERROR' || code == 'UNKNOWN_NETWORK_ERROR') {
      return true;
    }

    if (code.startsWith('HTTP_')) {
      final status = int.tryParse(code.substring(5));
      if (status == null) return false;
      return status == 408 || status == 429 || status >= 500;
    }

    return false;
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
        'API baseUrl must not end with /data. The client appends /data.',
        code: 'MASTER_DATA_INVALID_BASE_URL',
      );
    }

    final response = await _getPageResponseWithRetry(
      queryParams: queryParams,
      cancelHandle: cancelHandle,
    );

    return _parseMasterDataPageResponse(
      body: response.data,
      type: type,
      offset: offset,
      requestedLimit: context.effectivePageLimitFor(type),
    );
  }

  _MasterDataPage _parseMasterDataPageResponse({
    required dynamic body,
    required MasterDataType type,
    required int offset,
    required int requestedLimit,
  }) {
    final data = _responseMapOrNull(body);
    if (data == null) {
      throw const SyncException(
        'Master data response was not a JSON object.',
        code: 'MASTER_DATA_INVALID_RESPONSE',
      );
    }

    final status = _responseStatus(data);
    if (!_isKnownResponseStatus(status)) {
      throw SyncException(
        'Unexpected response status: "$status". Expected OK or ERROR.',
        code: 'MASTER_DATA_INVALID_STATUS',
      );
    }

    if (_isErrorResponse(status)) {
      final errorCode = _pageResponseErrorCode(
        data,
        fallback: 'MASTER_DATA_API_ERROR',
      );
      final errorMessage = _responseErrorMessage(
        data,
        fallback: 'Master data API rejected the request.',
      );

      if (type == MasterDataType.devicePrivilege &&
          errorCode == 'NO_MACHINE_PRIV') {
        return _MasterDataPage(
          items: const [],
          serverTime: _clock.now().toIso8601String(),
          hasMore: false,
          limit: requestedLimit,
          total: 0,
        );
      }

      throw SyncException(errorMessage, code: errorCode);
    }

    _validatePageResponseType(data, type);

    final items = _pageItems(data);
    final pagination = _pagePagination(data);

    final limit =
        _pageInt(
          pagination['limit'] ??
              pagination['page_limit'] ??
              pagination['pageLimit'] ??
              data['limit'] ??
              data['page_limit'] ??
              data['pageLimit'],
        ) ??
        requestedLimit;

    if (limit <= 0) {
      throw const SyncException(
        'Master data response returned invalid page limit.',
        code: 'MASTER_DATA_INVALID_PAGINATION',
      );
    }

    final total =
        _pageInt(
          pagination['total'] ??
              pagination['total_rows'] ??
              pagination['totalRows'] ??
              data['total'] ??
              data['total_rows'] ??
              data['totalRows'],
        ) ??
        items.length;

    final hasMore = _pageHasMore(
      pagination: pagination,
      data: data,
      offset: offset,
      limit: limit,
      itemCount: items.length,
      total: total,
    );

    return _MasterDataPage(
      items: items,
      serverTime: _pageServerTime(data),
      hasMore: hasMore,
      limit: limit,
      total: total,
    );
  }

  void _validatePageResponseType(
    Map<String, dynamic> data,
    MasterDataType expectedType,
  ) {
    final responseType = _cleanResponseText(data['type']).toUpperCase();

    // Some backend responses may omit type. If present, it must match.
    if (responseType.isEmpty) return;

    if (responseType != expectedType.code) {
      throw SyncException(
        'Master data response type mismatch. Expected ${expectedType.code}, got $responseType.',
        code: 'MASTER_DATA_TYPE_MISMATCH',
      );
    }
  }

  List<Map<String, dynamic>> _pageItems(Map<String, dynamic> data) {
    dynamic raw = data['items'] ?? data['rows'] ?? data['data'];

    if (raw is Map) {
      raw = raw['items'] ?? raw['rows'] ?? raw['data'];
    }

    if (raw is! List) {
      throw const SyncException(
        'Master data response did not contain a valid items list.',
        code: 'MASTER_DATA_INVALID_ITEMS',
      );
    }

    final items = <Map<String, dynamic>>[];

    for (var index = 0; index < raw.length; index++) {
      final row = raw[index];
      if (row is! Map) {
        throw SyncException(
          'Master data item at index $index was not a JSON object.',
          code: 'MASTER_DATA_INVALID_ITEM_ROW',
        );
      }

      items.add(Map<String, dynamic>.from(row));
    }

    return items;
  }

  Map<String, dynamic> _pagePagination(Map<String, dynamic> data) {
    final raw = data['pagination'] ?? data['page'] ?? data['paging'];

    if (raw == null) return const {};
    if (raw is! Map) {
      throw const SyncException(
        'Master data pagination was not a JSON object.',
        code: 'MASTER_DATA_INVALID_PAGINATION',
      );
    }

    return Map<String, dynamic>.from(raw);
  }

  String _pageServerTime(Map<String, dynamic> data) {
    final value = _firstCleanResponseText([
      data['server_time'],
      data['serverTime'],
      data['server_timestamp'],
      data['serverTimestamp'],
    ]);

    return value.isEmpty ? _clock.now().toIso8601String() : value;
  }

  bool _pageHasMore({
    required Map<String, dynamic> pagination,
    required Map<String, dynamic> data,
    required int offset,
    required int limit,
    required int itemCount,
    required int total,
  }) {
    final explicit = _pageBool(
      pagination['has_more'] ??
          pagination['hasMore'] ??
          pagination['has_next'] ??
          pagination['hasNext'] ??
          data['has_more'] ??
          data['hasMore'] ??
          data['has_next'] ??
          data['hasNext'],
    );

    if (explicit != null) return explicit;

    if (total > 0) {
      return offset + itemCount < total;
    }

    // No explicit pagination signal. Stop safely to avoid infinite loops.
    return false;
  }

  int? _pageInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();

    final text = _cleanResponseText(value);
    if (text.isEmpty) return null;

    return int.tryParse(text);
  }

  bool? _pageBool(Object? value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = _cleanResponseText(value).toLowerCase();
    if (text.isEmpty) return null;

    if (text == 'true' ||
        text == 't' ||
        text == 'yes' ||
        text == 'y' ||
        text == '1') {
      return true;
    }

    if (text == 'false' ||
        text == 'f' ||
        text == 'no' ||
        text == 'n' ||
        text == '0') {
      return false;
    }

    return null;
  }

  String _pageResponseErrorCode(
    Map<String, dynamic> data, {
    required String fallback,
  }) {
    final value = _firstCleanResponseText([
      data['code'],
      data['error_code'],
      data['errorCode'],
    ]);

    return value.isEmpty ? fallback : value;
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
