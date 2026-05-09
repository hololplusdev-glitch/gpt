import 'package:drift/drift.dart';
import 'package:pos_flutter/core/persistence/database.dart';
import 'package:pos_flutter/core/services/master_data/master_data_mapper.dart';
import 'package:pos_flutter/core/services/master_data/master_data_contract.dart';

class MasterDataDao {
  final AppDatabase _db;

  const MasterDataDao(this._db);

  Future<T> runInTransaction<T>(Future<T> Function() action) {
    return _db.transaction(action);
  }

  Future<void> persistPlan(MasterDataPersistencePlan plan) async {
    await _db.transaction(() async {
      await persistPlanInCurrentTransaction(plan);
    });
  }

  Future<void> persistPlanInCurrentTransaction(
    MasterDataPersistencePlan plan,
  ) async {
    for (final companion in plan.posMachines) {
      await _db.into(_db.posMachines).insertOnConflictUpdate(companion);
    }
    for (final companion in plan.users) {
      await _db.into(_db.posUsers).insertOnConflictUpdate(companion);
    }
    for (final companion in plan.userMachineAccesses) {
      await _db
          .into(_db.posUserMachineAccess)
          .insertOnConflictUpdate(companion);
    }
    for (final companion in plan.branchProfiles) {
      await _db.into(_db.branchProfile).insertOnConflictUpdate(companion);
    }
    for (final companion in plan.stores) {
      await _db.into(_db.stores).insertOnConflictUpdate(companion);
    }
    for (final companion in plan.priceLevels) {
      await _db.into(_db.priceLevels).insertOnConflictUpdate(companion);
    }
    for (final companion in plan.items) {
      await _db.into(_db.items).insertOnConflictUpdate(companion);
    }
    for (final companion in plan.itemUnits) {
      await _db.into(_db.itemUnits).insertOnConflictUpdate(companion);
      if (companion.isDefault.value) {
        await (_db.update(_db.items)
              ..where((item) => item.id.equals(companion.itemId.value)))
            .write(ItemsCompanion(defaultUnitId: companion.sourceUnitId));
      }
    }
    for (final companion in plan.itemBarcodes) {
      await _db.into(_db.itemBarcodes).insertOnConflictUpdate(companion);
    }
    for (final companion in plan.itemPrices) {
      await _db.into(_db.itemPrices).insertOnConflictUpdate(companion);
    }
    for (final companion in plan.customers) {
      await _db.into(_db.customers).insertOnConflictUpdate(companion);
    }
    for (final companion in plan.paymentMethods) {
      await _db.into(_db.paymentMethods).insertOnConflictUpdate(companion);
    }
  }

  Future<TerminalBootstrapDefaults?> loadLocalMachineDefaults({
    required String tenantCode,
    required String terminalNo,
    required String branchNo,
  }) async {
    final row =
        await (_db.select(_db.posMachines)..where(
              (machine) =>
                  machine.custCode.equals(tenantCode) &
                  machine.machineNo.equals(terminalNo),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    return TerminalBootstrapDefaults(
      custCode: row.custCode,
      terminalNo: row.machineNo,
      branchNo: row.branchNo ?? branchNo,
      braYear: row.branchYear,
      defaultStoreId: row.storeId,
      priceLevelId: row.priceLevelId,
      useTax: row.useTax,
      defaultBankId: row.defaultBankId,
      defaultCardTypeId: row.defaultCardTypeId,
      printerName: row.printerName,
    );
  }

  Future<void> saveTerminalProfile({
    required TerminalBootstrapDefaults defaults,
    required String userId,
    required bool priceIncludesTax,
    required DateTime now,
    String? serverTime,
  }) async {
      await _db
        .into(_db.posMachines)
        .insertOnConflictUpdate(
          PosMachinesCompanion(
            id: Value(defaults.terminalNo),
            custCode: Value(defaults.custCode),
            machineNo: Value(defaults.terminalNo),
            name: Value(defaults.terminalNo),
            branchNo: Value(defaults.branchNo),
            branchYear: Value(defaults.braYear),
            storeId: Value(defaults.defaultStoreId),
            cashId: const Value(null),
            priceLevelId: Value(defaults.priceLevelId),
            useTax: Value(defaults.useTax),
            requiresShift: const Value(true),
            priceIncludesTax: Value(priceIncludesTax),
            defaultBankId: Value(defaults.defaultBankId),
            defaultCardTypeId: Value(defaults.defaultCardTypeId),
            lastServerTime: Value(serverTime),
            isActive: const Value(true),
            lastBootstrapAt: Value(now),
            cachedAt: Value(now),
          ),
        );
  }

  Future<bool> hasLocalUsedDevicePrivilege({
    required String tenantCode,
    required String userId,
    required String terminalNo,
  }) async {
    final result =
        await (_db.select(_db.posUserMachineAccess)..where(
              (p) =>
                  p.custCode.equals(tenantCode) &
                  p.userId.equals(userId) &
                  p.machineNo.equals(terminalNo) &
                  p.canUseMachine.equals(true),
            ))
            .getSingleOrNull();
    return result != null;
  }

  Future<int> localPriceCount({String? storeId, String? priceLevelId}) async {
    if (storeId == null ||
        storeId.isEmpty ||
        priceLevelId == null ||
        priceLevelId.isEmpty) {
      return 0;
    }
    final rows =
        await (_db.select(_db.itemPrices)..where(
              (price) =>
                  price.storeId.equals(storeId) &
                  price.priceLevelId.equals(priceLevelId),
            ))
            .get();
    return rows.length;
  }

  Future<String?> lastServerTime(String typeCode, {required String tenantCode}) async {
    final syncKey = '${tenantCode}_$typeCode';
    final row = await (_db.select(
      _db.scopedSyncState,
    )..where((state) => state.syncKey.equals(syncKey))).getSingleOrNull();
    return row?.lastServerTime;
  }

  Future<void> saveSyncState(
    String typeCode, {
    required String tenantCode,
    required String status,
    required DateTime now,
    String? serverTime,
    String? error,
  }) async {
    final syncKey = '${tenantCode}_$typeCode';
    final existing = await (_db.select(
      _db.scopedSyncState,
    )..where((state) => state.syncKey.equals(syncKey))).getSingleOrNull();
    final isSuccessful =
        status == MasterDataTypeRunStatus.success.code ||
        status == MasterDataTypeRunStatus.noChanges.code;
    await _db
        .into(_db.scopedSyncState)
        .insertOnConflictUpdate(
          ScopedSyncStateCompanion(
            syncKey: Value(syncKey),
            type: Value(typeCode),
            scopeJson: Value('{"tenantCode": "$tenantCode"}'),
            lastSuccessTime: Value(
              isSuccessful ? now.toIso8601String() : existing?.lastSuccessTime,
            ),
            lastServerTime: Value(serverTime ?? existing?.lastServerTime),
            lastStatus: Value(status),
            lastError: Value(error),
          ),
        );
  }

  Future<void> insertRun({
    required String runId,
    required String modeCode,
    required String tenantCode,
    required String userId,
    required String branchNo,
    required String terminalNo,
    required DateTime at,
  }) async {
    await _db
        .into(_db.masterSyncRuns)
        .insert(
          MasterSyncRunsCompanion(
            id: Value(runId),
            mode: Value(modeCode),
            status: Value(MasterDataRunStatus.running.code),
            tenantCode: Value(tenantCode),
            sourceUserId: Value(userId),
            branchNo: Value(branchNo),
            machineNo: Value(terminalNo),
            startedAt: Value(at),
          ),
        );
  }

  Future<void> finishRun({
    required String runId,
    required String statusCode,
    required DateTime finishedAt,
    required int totalRowsReceived,
    required int totalRowsSaved,
    required int failedTypesCount,
    String? errorSummary,
    String? detailsJson,
  }) async {
    await (_db.update(
      _db.masterSyncRuns,
    )..where((run) => run.id.equals(runId))).write(
      MasterSyncRunsCompanion(
        status: Value(statusCode),
        finishedAt: Value(finishedAt),
        totalRowsReceived: Value(totalRowsReceived),
        totalRowsSaved: Value(totalRowsSaved),
        failedTypesCount: Value(failedTypesCount),
        errorSummary: Value(errorSummary),
        detailsJson: Value(detailsJson),
      ),
    );
  }

  Future<void> insertTypeRun({
    required String id,
    required String runId,
    required String typeCode,
    required String? oldServerTime,
    required String? sentLastUpdate,
    required DateTime at,
  }) async {
    await _db
        .into(_db.masterSyncTypeRuns)
        .insert(
          MasterSyncTypeRunsCompanion(
            id: Value(id),
            runId: Value(runId),
            syncType: Value(typeCode),
            status: Value(MasterDataTypeRunStatus.running.code),
            oldServerTime: Value(oldServerTime),
            sentLastUpdate: Value(sentLastUpdate),
            startedAt: Value(at),
          ),
        );
  }

  Future<void> finishTypeRun({
    required String id,
    required String statusCode,
    required int rowsReceived,
    required int rowsSaved,
    required int pagesCount,
    required DateTime finishedAt,
    required String? newServerTime,
    String? errorCode,
    String? errorMessage,
    String? detailsJson,
  }) async {
    await (_db.update(
      _db.masterSyncTypeRuns,
    )..where((run) => run.id.equals(id))).write(
      MasterSyncTypeRunsCompanion(
        status: Value(statusCode),
        newServerTime: Value(newServerTime),
        rowsReceived: Value(rowsReceived),
        rowsSaved: Value(rowsSaved),
        pagesCount: Value(pagesCount),
        finishedAt: Value(finishedAt),
        errorCode: Value(errorCode),
        errorMessage: Value(errorMessage),
        detailsJson: Value(detailsJson),
      ),
    );
  }

  Future<void> insertPageRun({
    required String id,
    required String typeRunId,
    required String typeCode,
    required int pageNo,
    required int offset,
    required int limit,
    int? paginationTotal,
    String? hasMore,
    int rowsReceived = 0,
    String? serverTime,
    int? durationMs,
    required String statusCode,
    String? errorMessage,
  }) async {
    await _db
        .into(_db.masterSyncPageRuns)
        .insert(
          MasterSyncPageRunsCompanion(
            id: Value(id),
            typeRunId: Value(typeRunId),
            syncType: Value(typeCode),
            pageNo: Value(pageNo),
            offsetValue: Value(offset),
            limitValue: Value(limit),
            paginationTotal: Value(paginationTotal),
            hasMore: Value(hasMore),
            rowsReceived: Value(rowsReceived),
            serverTime: Value(serverTime),
            durationMs: Value(durationMs),
            status: Value(statusCode),
            errorMessage: Value(errorMessage),
          ),
        );
  }

  Future<void> clearMasterDataCache() async {
    await _db.transaction(() async {
      await _db.delete(_db.scopedSyncState).go();
      await _db.delete(_db.posMachines).go();
      await _db.delete(_db.posUserMachineAccess).go();
      await _db.delete(_db.customers).go();
      await _db.delete(_db.paymentMethods).go();
      await _db.delete(_db.stores).go();
      await _db.delete(_db.priceLevels).go();
      await _db.delete(_db.itemPrices).go();
      await _db.delete(_db.itemBarcodes).go();
      await _db.delete(_db.itemUnits).go();
      await _db.delete(_db.itemGroups).go();
      await _db.delete(_db.items).go();
      await _db.delete(_db.posUsers).go();
      await _db.delete(_db.branchProfile).go();
    });
  }

  Future<bool> setupUserExists(String usrId) async {
    final row =
        await (_db.select(_db.posUsers)..where(
              (user) => user.id.equals(usrId) | user.sourceUserId.equals(usrId),
            ))
            .getSingleOrNull();
    return row != null;
  }

  Future<List<MasterSyncStateView>> getMasterSyncStates() async {
    final rows = await (_db.select(
      _db.scopedSyncState,
    )..orderBy([(state) => OrderingTerm.asc(state.type)])).get();
    return rows
        .map(
          (row) => MasterSyncStateView(
            syncType: row.type,
            lastSuccessTime: row.lastSuccessTime,
            lastServerTime: row.lastServerTime,
            lastStatus: row.lastStatus,
            lastError: row.lastError,
          ),
        )
        .toList();
  }
}
