import 'package:drift/drift.dart';
import 'package:pos_flutter/core/persistence/database.dart';
import 'package:pos_flutter/core/services/time/clock.dart';
import 'package:uuid/uuid.dart';

/// Public POS runtime facade. The table stores only pointers; this model is
/// derived from the active row + POS user + POS machine + machine access.
class ActivePosSession {
  final String? sessionId;
  final String custCode;
  final String activeUserId;
  final String activeUserName;
  final String activeMachineNo;
  final String activeMachineName;
  final String activeBranchNo;
  final String? activeBranchYear;
  final String activeStoreId;
  final String activePriceLevelId;
  final bool activeUseTax;
  final String? activeDefaultBankId;
  final String? activeDefaultCardTypeId;
  final String? cashId;
  final String? accountId;
  final String? costCenterId;
  final String? printerName;
  final bool priceIncludesTax;
  final String? openShiftId;
  final DateTime loginAt;

  const ActivePosSession({
    required this.sessionId,
    required this.custCode,
    required this.activeUserId,
    required this.activeUserName,
    required this.activeMachineNo,
    required this.activeMachineName,
    required this.activeBranchNo,
    required this.activeBranchYear,
    required this.activeStoreId,
    required this.activePriceLevelId,
    required this.activeUseTax,
    required this.activeDefaultBankId,
    required this.activeDefaultCardTypeId,
    required this.cashId,
    required this.accountId,
    required this.costCenterId,
    required this.printerName,
    required this.priceIncludesTax,
    required this.openShiftId,
    required this.loginAt,
  });

  // Temporary compatibility for UI files while auth screens are thinned out.
  String get userId => activeUserId;
  String get username => activeUserId;
  String get displayName => activeUserName;
  String get sessionLogId => sessionId ?? '';
  bool get isSupervisor => false;
  Set<String> get permissionCodes => const <String>{};
}

class ActivePosSessionDao {
  final AppDatabase _db;
  final Clock _clock;

  const ActivePosSessionDao(
    this._db, {
    Clock clock = const SystemClock(),
  }) : _clock = clock;

  static const _uuid = Uuid();

  Stream<ActivePosSession?> watchActive() {
    return (_db.select(_db.activePosSessions)..where((row) => row.id.equals(1)))
        .watchSingleOrNull()
        .asyncMap((_) => getActive());
  }

  Future<ActivePosSession?> getActive() async {
    final row = await (_db.select(_db.activePosSessions)
          ..where((row) => row.id.equals(1)))
        .getSingleOrNull();
    if (row == null) return null;
    return _derive(row);
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
          (row) => row.custCode.equals(custCode) & row.machineNo.equals(machineNo),
        ))
        .getSingleOrNull();
  }

  Future<ActivePosSession> startSession({
    required PosUser user,
    required PosMachine machine,
  }) async {
    _validateUser(user);
    _validateMachine(machine);
    if (user.custCode != machine.custCode) {
      throw StateError('Selected user and POS machine belong to different tenants.');
    }
    final allowed = await _canUseMachine(
      custCode: user.custCode,
      userId: user.id,
      machineNo: machine.machineNo,
    );
    if (!allowed) {
      throw StateError('User is not allowed to use this POS machine.');
    }

    final now = _clock.now();
    await _db.into(_db.activePosSessions).insertOnConflictUpdate(
          ActivePosSessionsCompanion(
            id: const Value(1),
            sessionId: Value('SESS_${_uuid.v4()}'),
            custCode: Value(user.custCode),
            activeUserId: Value(user.id),
            activeMachineNo: Value(machine.machineNo),
            openShiftId: const Value(null),
            loginAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    final session = await getActive();
    if (session == null) throw StateError('Failed to create active POS session.');
    return session;
  }

  Future<void> attachOpenShift(String shiftId) async {
    await (_db.update(_db.activePosSessions)..where((row) => row.id.equals(1)))
        .write(ActivePosSessionsCompanion(openShiftId: Value(shiftId), updatedAt: Value(_clock.now())));
  }

  Future<void> clearOpenShift(String shiftId) async {
    final row = await (_db.select(_db.activePosSessions)..where((row) => row.id.equals(1))).getSingleOrNull();
    if (row == null || row.openShiftId != shiftId) return;
    await (_db.update(_db.activePosSessions)..where((row) => row.id.equals(1)))
        .write(ActivePosSessionsCompanion(openShiftId: const Value(null), updatedAt: Value(_clock.now())));
  }

  Future<void> clearActive() async {
    await _db.delete(_db.activePosSessions).go();
  }

  Future<ActivePosSession> _derive(ActivePosSessionRow row) async {
    final user = await (_db.select(_db.posUsers)
          ..where((u) => u.custCode.equals(row.custCode) & u.id.equals(row.activeUserId)))
        .getSingleOrNull();
    final machine = await getMachine(custCode: row.custCode, machineNo: row.activeMachineNo);
    if (user == null) throw StateError('Active POS session user no longer exists.');
    if (machine == null) throw StateError('Active POS session machine no longer exists.');
    _validateUser(user);
    _validateMachine(machine);
    final allowed = await _canUseMachine(custCode: row.custCode, userId: row.activeUserId, machineNo: row.activeMachineNo);
    if (!allowed) throw StateError('Active POS session machine access is no longer valid.');

    return ActivePosSession(
      sessionId: row.sessionId,
      custCode: row.custCode,
      activeUserId: user.id,
      activeUserName: user.displayName,
      activeMachineNo: machine.machineNo,
      activeMachineName: machine.name ?? machine.machineNo,
      activeBranchNo: machine.branchNo!.trim(),
      activeBranchYear: machine.branchYear,
      activeStoreId: machine.storeId!.trim(),
      activePriceLevelId: machine.priceLevelId!.trim(),
      activeUseTax: machine.useTax,
      activeDefaultBankId: machine.defaultBankId,
      activeDefaultCardTypeId: machine.defaultCardTypeId,
      cashId: machine.cashId,
      accountId: user.accountId,
      costCenterId: user.costCenterId,
      printerName: machine.printerName,
      priceIncludesTax: machine.priceIncludesTax,
      openShiftId: row.openShiftId,
      loginAt: row.loginAt,
    );
  }

  Future<bool> _canUseMachine({required String custCode, required String userId, required String machineNo}) async {
    final access = await (_db.select(_db.posUserMachineAccess)
          ..where((row) =>
              row.custCode.equals(custCode) &
              row.userId.equals(userId) &
              row.machineNo.equals(machineNo) &
              row.canUseMachine.equals(true)))
        .getSingleOrNull();
    return access != null;
  }

  void _validateUser(PosUser user) {
    if (!user.isActive || !user.canLoginPos) throw StateError('User is not authorized for POS login.');
  }

  void _validateMachine(PosMachine machine) {
    if (!machine.isActive) throw StateError('Selected POS machine is inactive.');
    final storeId = machine.storeId?.trim();
    final priceLevelId = machine.priceLevelId?.trim();
    final branchNo = machine.branchNo?.trim();
    if (storeId == null || storeId.isEmpty) throw StateError('Selected POS machine has no default store.');
    if (priceLevelId == null || priceLevelId.isEmpty) throw StateError('Selected POS machine has no price level.');
    if (branchNo == null || branchNo.isEmpty) throw StateError('Selected POS machine has no branch number.');
  }
}
