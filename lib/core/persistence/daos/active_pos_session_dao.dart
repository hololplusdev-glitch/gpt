import 'package:drift/drift.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/core/services/time/clock.dart';
import 'package:uuid/uuid.dart';
import 'package:holol_POS/core/persistence/daos/dao_shared.dart';

/// Public POS runtime facade.
/// The DB row stores only pointers. Runtime values are derived from:
/// USER + DEVICE_PRIV + POS_MACHINE.
///
/// Runtime Access Policy SSOT:
/// - DEVICE_PRIV is the authoritative user-to-machine permission source.
/// - Permission key is: userId + machineNo.
/// - USER.admin/userLevel does not grant all machines inside the app.
/// - USER.defaultStoreId is not a machine permission.
/// - DEVICE_PRIV.def_st/price_lvl/use_tax are runtime settings after permission.
class ActivePosSession {
  final String? sessionId;
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
  final bool autoPrint;
  final String? invoiceSeries;
  final String? returnInvoiceSeries;
  final DateTime loginAt;

  const ActivePosSession({
    required this.sessionId,
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
    required this.autoPrint,
    required this.invoiceSeries,
    required this.returnInvoiceSeries,
    required this.loginAt,
  });
}

class RuntimeMachineChoice {
  final PosUserMachineAccessData privilege;
  final PosMachine machine;

  const RuntimeMachineChoice({required this.privilege, required this.machine});

  String get machineNo => privilege.machineNo;

  String get label {
    final terminalName = DaoText.firstNonEmpty([
      privilege.terminalName,
      machine.name,
      machine.machineNo,
    ])!;

    final storeId = DaoText.firstNonEmpty([privilege.storeId, machine.storeId]);
    final priceLevelId = DaoText.firstNonEmpty([
      privilege.priceLevelId,
      machine.priceLevelId,
    ]);

    return [
      terminalName,
      if (storeId != null) 'مخزن $storeId',
      if (priceLevelId != null) 'سعر $priceLevelId',
    ].join(' • ');
  }
}

class ActivePosSessionDao {
  final AppDatabase _db;
  final Clock _clock;

  const ActivePosSessionDao(this._db, {Clock clock = const SystemClock()})
    : _clock = clock;

  static const _uuid = Uuid();

  Stream<ActivePosSession?> watchActive() {
    return (_db.select(_db.activePosSessions)..where((row) => row.id.equals(1)))
        .watchSingleOrNull()
        .asyncMap((_) => getActive());
  }

  Future<ActivePosSession?> getActive() async {
    final row = await _readActiveRow();
    if (row == null) return null;
    return _derive(row);
  }

  Future<ActivePosSessionRow?> _readActiveRow() {
    return (_db.select(
      _db.activePosSessions,
    )..where((row) => row.id.equals(1))).getSingleOrNull();
  }

  Future<List<PosUser>> listCashiers() {
    return (_db.select(_db.posUsers)
          ..where(
            (row) => row.isActive.equals(true) & row.canLoginPos.equals(true),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.displayName)]))
        .get();
  }

  Future<List<PosUserMachineAccessData>> listAllowedMachinesForUser({
    required String userId,
  }) {
    return (_db.select(_db.posUserMachineAccess)
          ..where(
            (row) => row.userId.equals(userId) & row.canUseMachine.equals(true),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.machineNo)]))
        .get();
  }

  Future<PosMachine?> getMachine({required String machineNo}) {
    return (_db.select(
      _db.posMachines,
    )..where((row) => row.machineNo.equals(machineNo))).getSingleOrNull();
  }

  Future<PosUserMachineAccessData?> _runtimeMachinePrivilege({
    required String userId,
    required String machineNo,
  }) {
    return (_db.select(_db.posUserMachineAccess)..where(
          (row) =>
              row.userId.equals(userId) &
              row.machineNo.equals(machineNo) &
              row.canUseMachine.equals(true),
        ))
        .getSingleOrNull();
  }

  Future<List<RuntimeMachineChoice>> listRuntimeMachineChoicesForUser({
    required PosUser user,
  }) async {
    DaoActiveSessionPolicy.validateUser(user);

    final privileges = await listAllowedMachinesForUser(userId: user.id);

    final choices = <RuntimeMachineChoice>[];
    final seenMachineNos = <String>{};

    for (final privilege in privileges) {
      if (!seenMachineNos.add(privilege.machineNo)) {
        continue;
      }

      final machine = await getMachine(machineNo: privilege.machineNo);

      if (machine == null || !machine.isActive) {
        continue;
      }

      choices.add(RuntimeMachineChoice(privilege: privilege, machine: machine));
    }

    return choices;
  }

  Future<ActivePosSession> startSession({
    required PosUser user,
    required PosMachine machine,
  }) async {
    DaoActiveSessionPolicy.validateUser(user);
    DaoActiveSessionPolicy.validateMachine(machine);

    final privilege = await _runtimeMachinePrivilege(
      userId: user.id,
      machineNo: machine.machineNo,
    );

    if (privilege == null) {
      throw StateError('User is not allowed to use this POS machine.');
    }

    final now = _clock.now();

    await _db
        .into(_db.activePosSessions)
        .insertOnConflictUpdate(
          ActivePosSessionsCompanion(
            id: const Value(1),
            sessionId: Value('SESS_${_uuid.v4()}'),
            activeUserId: Value(user.id),
            activeMachineNo: Value(machine.machineNo),
            loginAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    final session = await getActive();
    if (session == null) {
      throw StateError('Failed to create active POS session.');
    }

    return session;
  }

  Future<void> clearActive() async {
    await _db.delete(_db.activePosSessions).go();
  }

  Future<ActivePosSession> _derive(ActivePosSessionRow row) async {
    final user = await (_db.select(
      _db.posUsers,
    )..where((u) => u.id.equals(row.activeUserId))).getSingleOrNull();

    final machine = await getMachine(machineNo: row.activeMachineNo);

    if (user == null) {
      throw StateError('Active POS session user no longer exists.');
    }
    if (machine == null) {
      throw StateError('Active POS session machine no longer exists.');
    }

    DaoActiveSessionPolicy.validateUser(user);
    DaoActiveSessionPolicy.validateMachine(machine);

    final privilege = await _runtimeMachinePrivilege(
      userId: row.activeUserId,
      machineNo: row.activeMachineNo,
    );

    if (privilege == null) {
      throw StateError('Active POS session privilege is no longer valid.');
    }

    final branchNo = DaoText.firstNonEmpty([
      privilege.branchNo,
      machine.branchNo,
      user.branchNo,
    ]);
    final branchYear = DaoText.firstNonEmpty([
      privilege.branchYear,
      machine.branchYear,
      user.branchYear,
    ]);
    final storeId = DaoText.firstNonEmpty([
      privilege.storeId,
      machine.storeId,
      user.defaultStoreId,
    ]);
    final priceLevelId = DaoText.firstNonEmpty([
      privilege.priceLevelId,
      machine.priceLevelId,
    ]);
    final defaultBankId = DaoText.firstNonEmpty([
      privilege.defaultBankId,
      machine.defaultBankId,
    ]);

    if (branchNo == null) {
      throw StateError('Selected runtime context has no branch number.');
    }
    if (storeId == null) {
      throw StateError('Selected runtime context has no store.');
    }
    if (priceLevelId == null) {
      throw StateError('Selected runtime context has no price level.');
    }

    return ActivePosSession(
      sessionId: row.sessionId,
      activeUserId: user.id,
      activeUserName: user.displayName,
      activeMachineNo: machine.machineNo,
      activeMachineName:
          privilege.terminalName ?? machine.name ?? machine.machineNo,
      activeBranchNo: branchNo,
      activeBranchYear: branchYear,
      activeStoreId: storeId,
      activePriceLevelId: priceLevelId,
      activeUseTax: privilege.useTax ?? machine.useTax,
      activeDefaultBankId: defaultBankId,
      activeDefaultCardTypeId: machine.defaultCardTypeId,
      cashId: machine.cashId ?? user.defaultCashId,
      accountId: user.accountId,
      costCenterId: user.costCenterId,
      printerName: machine.printerName,
      priceIncludesTax: machine.priceIncludesTax,
      autoPrint: machine.autoPrint,
      invoiceSeries: machine.invoiceSeries,
      returnInvoiceSeries: machine.returnInvoiceSeries,
      loginAt: row.loginAt,
    );
  }
}
