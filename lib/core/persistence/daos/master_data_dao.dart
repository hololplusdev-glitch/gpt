import 'package:drift/drift.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/core/services/master_data/master_data_contract.dart';
import 'package:holol_POS/core/services/master_data/master_data_mapper.dart';
import 'package:holol_POS/core/persistence/daos/dao_shared.dart';

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

  Future<String?> lastServerTime(
    String typeCode, {
    required MasterDataSyncContext context,
  }) async {
    final syncKey = DaoMasterDataScope.key(typeCode, context);
    final row = await (_db.select(
      _db.scopedSyncState,
    )..where((state) => state.syncKey.equals(syncKey))).getSingleOrNull();
    return row?.lastServerTime;
  }

  Future<void> saveSyncState(
    String typeCode, {
    required MasterDataSyncContext context,
    required String status,
    required DateTime now,
    String? serverTime,
    String? error,
  }) async {
    final syncKey = DaoMasterDataScope.key(typeCode, context);
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
            scopeJson: Value(DaoMasterDataScope.toJson(context)),
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

  Future<List<PosUser>> listDownloadedPosUsers() {
    return (_db.select(_db.posUsers)
          ..where(
            (user) =>
                user.isActive.equals(true) & user.canLoginPos.equals(true),
          )
          ..orderBy([(user) => OrderingTerm.asc(user.id)]))
        .get();
  }

  Future<bool> hasMinimumSetupSeed({required String bootstrapUserId}) async {
    final normalizedBootstrapUserId = bootstrapUserId.trim();

    if (normalizedBootstrapUserId.isEmpty) {
      return false;
    }

    final setupUser =
        await (_db.select(_db.posUsers)..where(
              (user) =>
                  user.isActive.equals(true) &
                  (user.id.equals(normalizedBootstrapUserId) |
                      user.sourceUserId.equals(normalizedBootstrapUserId)),
            ))
            .getSingleOrNull();

    if (setupUser == null) {
      return false;
    }

    final setupUserIds = <String>{
      setupUser.id.trim(),
      if (setupUser.sourceUserId != null) setupUser.sourceUserId!.trim(),
    }..removeWhere((value) => value.isEmpty);

    final devicePrivilege =
        await (_db.select(_db.posUserMachineAccess)
              ..where(
                (row) =>
                    row.canUseMachine.equals(true) &
                    row.userId.isIn(setupUserIds.toList()),
              )
              ..limit(1))
            .getSingleOrNull();

    if (devicePrivilege == null) {
      return false;
    }

    final machine =
        await (_db.select(_db.posMachines)..where(
              (machine) => machine.machineNo.equals(devicePrivilege.machineNo),
            ))
            .getSingleOrNull();

    return machine != null;
  }

  Future<int> countCustomers() async {
    final rows = await (_db.select(
      _db.customers,
    )..where((row) => row.inactive.equals(false))).get();

    return rows.length;
  }

  Future<int> countDevicePrivileges() async {
    final rows = await (_db.select(
      _db.posUserMachineAccess,
    )..where((row) => row.canUseMachine.equals(true))).get();

    return rows.length;
  }

  Future<void> deleteDevicePrivilegesForUser({required String userId}) async {
    await (_db.delete(
      _db.posUserMachineAccess,
    )..where((row) => row.userId.equals(userId))).go();
  }

  Future<void> clearMasterDataCache({bool clearRunLogs = false}) async {
    await _db.transaction(() async {
      if (clearRunLogs) {
        await _db.delete(_db.masterSyncPageRuns).go();
        await _db.delete(_db.masterSyncTypeRuns).go();
        await _db.delete(_db.masterSyncRuns).go();
      }
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

  Future<List<ScopedSyncStateView>> getScopedSyncStates() async {
    final rows = await (_db.select(
      _db.scopedSyncState,
    )..orderBy([(state) => OrderingTerm.asc(state.type)])).get();
    return rows
        .map(
          (row) => ScopedSyncStateView(
            syncType: row.type,
            scopeLabel: DaoMasterDataScope.label(row.type, row.scopeJson),
            lastSuccessTime: row.lastSuccessTime,
            lastServerTime: row.lastServerTime,
            lastStatus: row.lastStatus,
            lastError: row.lastError,
          ),
        )
        .toList();
  }
}
