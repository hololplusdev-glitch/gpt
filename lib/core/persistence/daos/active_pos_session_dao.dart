import 'package:drift/drift.dart';
import 'package:pos_flutter/core/persistence/database.dart';
import 'package:pos_flutter/core/services/time/clock.dart';
import 'package:uuid/uuid.dart';

class ActivePosSessionDao {
  final AppDatabase _db;
  final Clock _clock;

  const ActivePosSessionDao(
    this._db, {
    Clock clock = const SystemClock(),
  }) : _clock = clock;

  static const _uuid = Uuid();

  Stream<ActivePosSession?> watchActive() {
    return (_db.select(_db.activePosSessions)
          ..where((row) => row.id.equals(1)))
        .watchSingleOrNull();
  }

  Future<ActivePosSession?> getActive() {
    return (_db.select(_db.activePosSessions)
          ..where((row) => row.id.equals(1)))
        .getSingleOrNull();
  }

  Future<List<PosUser>> listCashiers() {
    return (_db.select(_db.posUsers)
          ..where((row) => row.isActive.equals(true) & row.canLoginPos.equals(true))
          ..orderBy([(row) => OrderingTerm.asc(row.displayName)]))
        .get();
  }

  Future<List<PosUserMachineAccessData>> listAllowedMachinesForUser({
    required String custCode,
    required String userId,
  }) {
    return (_db.select(_db.posUserMachineAccess)
          ..where(
            (row) =>
                row.custCode.equals(custCode) &
                row.userId.equals(userId) &
                row.canUseMachine.equals(true),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.machineNo)]))
        .get();
  }

  Future<PosMachine?> getMachine({
    required String custCode,
    required String machineNo,
  }) {
    return (_db.select(_db.posMachines)..where(
          (row) =>
              row.custCode.equals(custCode) & row.machineNo.equals(machineNo),
        ))
        .getSingleOrNull();
  }

  Future<ActivePosSession> startSession({
    required PosUser user,
    required PosMachine machine,
    required bool priceIncludesTax,
  }) async {
    final storeId = machine.storeId?.trim();
    final priceLevelId = machine.priceLevelId?.trim();
    final branchNo = machine.branchNo?.trim();
    if (storeId == null || storeId.isEmpty) {
      throw StateError('Selected POS machine has no default store.');
    }
    if (priceLevelId == null || priceLevelId.isEmpty) {
      throw StateError('Selected POS machine has no price level.');
    }
    if (branchNo == null || branchNo.isEmpty) {
      throw StateError('Selected POS machine has no branch number.');
    }

    final now = _clock.now();
    final companion = ActivePosSessionsCompanion(
      id: const Value(1),
      sessionId: Value('SESS_${_uuid.v4()}'),
      custCode: Value(machine.custCode),
      activeUserId: Value(user.id),
      activeUserName: Value(user.displayName),
      activeMachineNo: Value(machine.machineNo),
      activeMachineName: Value(machine.name ?? machine.machineNo),
      activeBranchNo: Value(branchNo),
      activeBranchYear: Value(machine.branchYear),
      activeStoreId: Value(storeId),
      activePriceLevelId: Value(priceLevelId),
      activeUseTax: Value(machine.useTax),
      activeDefaultBankId: Value(machine.defaultBankId),
      activeDefaultCardTypeId: Value(machine.defaultCardTypeId),
      cashId: Value(machine.cashId),
      accountId: Value(user.accountId),
      costCenterId: Value(user.costCenterId),
      printerName: Value(machine.printerName),
      priceIncludesTax: Value(priceIncludesTax),
      loginAt: Value(now),
    );
    await _db.into(_db.activePosSessions).insertOnConflictUpdate(companion);
    final session = await getActive();
    if (session == null) {
      throw StateError('Failed to create active POS session.');
    }
    return session;
  }

  Future<void> clearActive() async {
    await _db.delete(_db.activePosSessions).go();
  }
}
