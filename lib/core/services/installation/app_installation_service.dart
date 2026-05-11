import 'dart:io';

import 'package:drift/drift.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/core/services/pos_devices/runtime_platform.dart';
import 'package:uuid/uuid.dart';

class AppInstallationService {
  static const _localRowId = 'local';
  static const _uuid = Uuid();

  final AppDatabase _db;

  const AppInstallationService({required AppDatabase db}) : _db = db;

  Future<void> ensureInitialized() async {
    final existing =
        await (_db.select(_db.appInstallation)
              ..orderBy([(row) => OrderingTerm.asc(row.firstInstalledAt)])
              ..limit(1))
            .getSingleOrNull();

    final now = DateTime.now();
    final snapshot = await _buildSnapshot();

    if (existing == null) {
      await _db
          .into(_db.appInstallation)
          .insert(
            AppInstallationCompanion.insert(
              id: _localRowId,
              installationId: _uuid.v4(),
              platform: snapshot.platform,
              deviceName: Value(snapshot.deviceName),
              deviceModel: Value(snapshot.deviceModel),
              osVersion: Value(snapshot.osVersion),
              appVersion: Value(snapshot.appVersion),
              dbSchemaVersion: Value(_db.schemaVersion),
              firstInstalledAt: now,
              lastOpenedAt: now,
              lastTerminalId: Value(snapshot.lastTerminalId),
            ),
          );
      return;
    }

    await (_db.update(
      _db.appInstallation,
    )..where((row) => row.id.equals(existing.id))).write(
      AppInstallationCompanion(
        platform: Value(snapshot.platform),
        deviceName: Value(snapshot.deviceName),
        deviceModel: Value(snapshot.deviceModel),
        osVersion: Value(snapshot.osVersion),
        appVersion: Value(snapshot.appVersion),
        dbSchemaVersion: Value(_db.schemaVersion),
        lastOpenedAt: Value(now),
        lastTerminalId: Value(snapshot.lastTerminalId),
      ),
    );
  }

  Future<_InstallationRuntimeSnapshot> _buildSnapshot() async {
    return _InstallationRuntimeSnapshot(
      platform: currentAppPlatform().code,
      deviceName: _safeDeviceName(),
      deviceModel: null,
      osVersion: _safeOsVersion(),
      appVersion: _compileTimeAppVersion(),
      lastTerminalId: null,
    );
  }

  String? _safeDeviceName() {
    try {
      return _nonEmpty(Platform.localHostname);
    } on Object {
      return null;
    }
  }

  String? _safeOsVersion() {
    try {
      return _nonEmpty(Platform.operatingSystemVersion);
    } on Object {
      return null;
    }
  }

  String? _compileTimeAppVersion() {
    const version = String.fromEnvironment('APP_VERSION');
    return _nonEmpty(version);
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class _InstallationRuntimeSnapshot {
  final String platform;
  final String? deviceName;
  final String? deviceModel;
  final String? osVersion;
  final String? appVersion;
  final String? lastTerminalId;

  const _InstallationRuntimeSnapshot({
    required this.platform,
    required this.deviceName,
    required this.deviceModel,
    required this.osVersion,
    required this.appVersion,
    required this.lastTerminalId,
  });
}
