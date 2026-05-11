import 'package:drift/drift.dart';
import 'package:pos_flutter/core/persistence/database.dart';
import 'package:pos_flutter/core/services/time/clock.dart';
import 'package:uuid/uuid.dart';

/// Public POS runtime facade.
/// The DB row stores only pointers. Runtime values are derived from:
/// USER + DEVICE_PRIV runtime profile + POS_MACHINE.
///
/// Runtime Access Policy:
/// - DEVICE_PRIV.usr_id is treated as download/admin context in this API profile,
///   not as user authorization.
/// - Admin users see all runtime machine profiles.
/// - Normal users see profiles matching USER.defaultStoreId.
/// - Runtime context priority:
///   DEVICE_PRIV profile > POS_MACHINE > USER.
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
}

/// Login choice exposed to UI.
/// UI must not reimplement USER/DEVICE_PRIV/POS_MACHINE policy.
class RuntimeMachineChoice {
  final PosUserMachineAccessData profile;
  final PosMachine machine;

  const RuntimeMachineChoice({
    required this.profile,
    required this.machine,
  });

  String get machineNo => profile.machineNo;

  String get label {
    final terminalName = _firstNonEmptyStatic([
      profile.terminalName,
      machine.name,
      machine.machineNo,
    ])!;

    final storeId = _firstNonEmptyStatic([profile.storeId, machine.storeId]);
    final priceLevelId = _firstNonEmptyStatic([
      profile.priceLevelId,
      machine.priceLevelId,
    ]);

    return [
      terminalName,
      if (storeId != null) 'مخزن $storeId',
      if (priceLevelId != null) 'سعر $priceLevelId',
    ].join(' • ');
  }
}

String? _firstNonEmptyStatic(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return null;
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

  /// Legacy-compatible method name.
  /// Do not use DEVICE_PRIV.userId as authorization.
  /// The effective policy is USER.defaultStoreId/admin against runtime profile store.
  Future<List<PosUserMachineAccessData>> listAllowedMachinesForUser({
    required String custCode,
    required String userId,
  }) async {
    final user = await (_db.select(_db.posUsers)
          ..where(
            (row) => row.custCode.equals(custCode) & row.id.equals(userId),
          ))
        .getSingleOrNull();

    if (user == null) return [];

    final choices = await listRuntimeMachineChoicesForUser(user: user);
    return choices.map((choice) => choice.profile).toList();
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

  Future<List<PosUserMachineAccessData>> _listRuntimeMachineProfiles({
    required String custCode,
  }) {
    return (_db.select(_db.posUserMachineAccess)
          ..where(
            (row) =>
                row.custCode.equals(custCode) &
                row.canUseMachine.equals(true),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.machineNo)]))
        .get();
  }

  Future<PosUserMachineAccessData?> _runtimeMachineProfile({
    required String custCode,
    required String machineNo,
  }) async {
    final rows = await (_db.select(_db.posUserMachineAccess)
          ..where(
            (row) =>
                row.custCode.equals(custCode) &
                row.machineNo.equals(machineNo) &
                row.canUseMachine.equals(true),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.userId)]))
        .get();

    if (rows.isEmpty) return null;

    // In this API profile DEVICE_PRIV.usr_id is the download/admin context.
    // If duplicates exist for a machine, keep the first stable row.
    return rows.first;
  }

  /// SSOT for login machine choices.
  /// Policy:
  /// - Admin sees all active runtime profiles.
  /// - Normal user sees runtime profiles matching USER.defaultStoreId.
  Future<List<RuntimeMachineChoice>> listRuntimeMachineChoicesForUser({
    required PosUser user,
  }) async {
    _validateUser(user);

    final profiles = await _listRuntimeMachineProfiles(custCode: user.custCode);
    final choices = <RuntimeMachineChoice>[];
    final seenMachineNos = <String>{};

    for (final profile in profiles) {
      if (!seenMachineNos.add(profile.machineNo)) {
        continue;
      }

      final machine = await getMachine(
        custCode: user.custCode,
        machineNo: profile.machineNo,
      );

      if (machine == null || !machine.isActive) {
        continue;
      }

      if (_canUserUseRuntimeProfile(
        user: user,
        profile: profile,
        machine: machine,
      )) {
        choices.add(RuntimeMachineChoice(profile: profile, machine: machine));
      }
    }

    return choices;
  }

  Future<ActivePosSession> startSession({
    required PosUser user,
    required PosMachine machine,
  }) async {
    _validateUser(user);
    _validateMachine(machine);

    if (user.custCode != machine.custCode) {
      throw StateError(
        'Selected user and POS machine belong to different tenants.',
      );
    }

    final profile = await _runtimeMachineProfile(
      custCode: user.custCode,
      machineNo: machine.machineNo,
    );

    if (profile == null) {
      throw StateError('Selected POS machine has no runtime profile.');
    }

    if (!_canUserUseRuntimeProfile(
      user: user,
      profile: profile,
      machine: machine,
    )) {
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
    if (session == null) {
      throw StateError('Failed to create active POS session.');
    }

    return session;
  }

  Future<void> attachOpenShift(String shiftId) async {
    await (_db.update(
      _db.activePosSessions,
    )..where((row) => row.id.equals(1))).write(
      ActivePosSessionsCompanion(
        openShiftId: Value(shiftId),
        updatedAt: Value(_clock.now()),
      ),
    );
  }

  Future<void> clearOpenShift(String shiftId) async {
    final row = await _readActiveRow();
    if (row == null || row.openShiftId != shiftId) return;

    await (_db.update(
      _db.activePosSessions,
    )..where((row) => row.id.equals(1))).write(
      ActivePosSessionsCompanion(
        openShiftId: const Value(null),
        updatedAt: Value(_clock.now()),
      ),
    );
  }

  Future<void> clearActive() async {
    await _db.delete(_db.activePosSessions).go();
  }

  Future<ActivePosSession> _derive(ActivePosSessionRow row) async {
    final user = await (_db.select(_db.posUsers)
          ..where(
            (u) =>
                u.custCode.equals(row.custCode) &
                u.id.equals(row.activeUserId),
          ))
        .getSingleOrNull();

    final machine = await getMachine(
      custCode: row.custCode,
      machineNo: row.activeMachineNo,
    );

    if (user == null) {
      throw StateError('Active POS session user no longer exists.');
    }
    if (machine == null) {
      throw StateError('Active POS session machine no longer exists.');
    }

    _validateUser(user);
    _validateMachine(machine);

    final profile = await _runtimeMachineProfile(
      custCode: row.custCode,
      machineNo: row.activeMachineNo,
    );

    if (profile == null) {
      throw StateError('Active POS session runtime profile is no longer valid.');
    }

    if (!_canUserUseRuntimeProfile(
      user: user,
      profile: profile,
      machine: machine,
    )) {
      throw StateError('Active POS session is no longer allowed.');
    }

    final branchNo = _firstNonEmpty([
      profile.branchNo,
      machine.branchNo,
      user.branchNo,
    ]);
    final branchYear = _firstNonEmpty([
      profile.branchYear,
      machine.branchYear,
      user.branchYear,
    ]);
    final storeId = _firstNonEmpty([
      profile.storeId,
      machine.storeId,
      user.defaultStoreId,
    ]);
    final priceLevelId = _firstNonEmpty([
      profile.priceLevelId,
      machine.priceLevelId,
    ]);
    final defaultBankId = _firstNonEmpty([
      profile.defaultBankId,
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
      custCode: row.custCode,
      activeUserId: user.id,
      activeUserName: user.displayName,
      activeMachineNo: machine.machineNo,
      activeMachineName:
          profile.terminalName ?? machine.name ?? machine.machineNo,
      activeBranchNo: branchNo,
      activeBranchYear: branchYear,
      activeStoreId: storeId,
      activePriceLevelId: priceLevelId,
      activeUseTax: profile.useTax ?? machine.useTax,
      activeDefaultBankId: defaultBankId,
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

  bool _canUserUseRuntimeProfile({
    required PosUser user,
    required PosUserMachineAccessData profile,
    required PosMachine machine,
  }) {
    if (_isAdminUser(user)) {
      return true;
    }

    final userStoreId = _trimOrNull(user.defaultStoreId);
    if (userStoreId == null) {
      return false;
    }

    final profileStoreId = _firstNonEmpty([
      profile.storeId,
      machine.storeId,
    ]);

    return profileStoreId == userStoreId;
  }

  bool _isAdminUser(PosUser user) {
    final level = _trimOrNull(user.userLevel);
    return level == '1';
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = _trimOrNull(value);
      if (trimmed != null) return trimmed;
    }
    return null;
  }

  String? _trimOrNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  void _validateUser(PosUser user) {
    if (!user.isActive || !user.canLoginPos) {
      throw StateError('User is not authorized for POS login.');
    }
  }

  void _validateMachine(PosMachine machine) {
    if (!machine.isActive) {
      throw StateError('Selected POS machine is inactive.');
    }
  }
}
