import 'package:drift/drift.dart';
import 'package:holol_POS/core/network/network_models.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/core/services/time/clock.dart';

class RuntimeSetupConfig {
  final bool isSetupComplete;
  final String language;
  final SyncProfile? syncProfile;

  const RuntimeSetupConfig({
    required this.isSetupComplete,
    required this.language,
    this.syncProfile,
  });
}

class RuntimeConfigRepository {
  static const _syncProfileId = 1;
  static const _kLanguage = 'app_language';

  final AppDatabase _db;
  final Clock _clock;

  RuntimeConfigRepository(this._db, {Clock clock = const SystemClock()})
    : _clock = clock;

  Future<RuntimeSetupConfig> loadSetupConfig() async {
    final language = await _loadLanguage();
    final row = await _loadRow();
    final profile = row == null ? null : _profileFromRow(row);

    return RuntimeSetupConfig(
      isSetupComplete: row?.setupCompleted == true && profile != null,
      language: language,
      syncProfile: profile,
    );
  }

  Future<void> saveSyncProfile(SyncProfile profile) async {
    final now = _clock.now();
    final existing = await _loadRow();

    await _db
        .into(_db.syncProfileTable)
        .insertOnConflictUpdate(
          SyncProfileTableCompanion(
            id: const Value(_syncProfileId),
            baseUrl: Value(profile.baseUrl),
            custCode: Value(profile.custCode),
            bootstrapUserId: Value(profile.bootstrapUserId),
            pageLimit: Value(_normalizePageLimit(profile.pageLimit)),
            timeoutSeconds: Value(profile.effectiveTimeoutSeconds),
            isValidated: Value(profile.isValidated),
            lastValidatedAt: Value(profile.lastValidatedAt),
            setupCompleted: Value(
              profile.setupCompleted || (existing?.setupCompleted ?? false),
            ),
            initialSyncCompleted: Value(
              profile.initialSyncCompleted ||
                  (existing?.initialSyncCompleted ?? false),
            ),
            lastFullSyncAt: Value(
              profile.lastFullSyncAt ?? existing?.lastFullSyncAt,
            ),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> setSetupComplete(bool value) async {
    await _updateRow(
      SyncProfileTableCompanion(
        setupCompleted: Value(value),
        updatedAt: Value(_clock.now()),
      ),
    );
  }

  Future<void> setLanguage(String language) async {
    await _db
        .into(_db.terminalLocalSettings)
        .insertOnConflictUpdate(
          TerminalLocalSettingsCompanion(
            key: const Value(_kLanguage),
            value: Value(language),
            updatedAt: Value(_clock.now()),
          ),
        );
  }

  Future<void> resetSetupStatus() async {
    await setSetupComplete(false);
  }

  Future<void> clearSyncProfile() async {
    await (_db.delete(
      _db.syncProfileTable,
    )..where((row) => row.id.equals(_syncProfileId))).go();
  }

  Future<String> _loadLanguage() async {
    final row = await (_db.select(
      _db.terminalLocalSettings,
    )..where((settings) => settings.key.equals(_kLanguage))).getSingleOrNull();
    final language = row?.value.trim();
    return language == null || language.isEmpty ? 'en' : language;
  }

  Future<SyncProfileTableData?> _loadRow() {
    return (_db.select(
      _db.syncProfileTable,
    )..where((row) => row.id.equals(_syncProfileId))).getSingleOrNull();
  }

  Future<void> _updateRow(SyncProfileTableCompanion companion) async {
    await (_db.update(
      _db.syncProfileTable,
    )..where((row) => row.id.equals(_syncProfileId))).write(companion);
  }

  SyncProfile? _profileFromRow(SyncProfileTableData row) {
    if (row.baseUrl.trim().isEmpty || row.custCode.trim().isEmpty) {
      return null;
    }

    return SyncProfile.fromUrl(
      row.baseUrl,
      custCode: row.custCode,
      bootstrapUserId: row.bootstrapUserId,
      pageLimit: _normalizePageLimit(row.pageLimit),
      timeoutSeconds: row.timeoutSeconds ?? 30,
    ).copyWith(
      isValidated: row.isValidated,
      lastValidatedAt: row.lastValidatedAt,
      setupCompleted: row.setupCompleted,
      initialSyncCompleted: row.initialSyncCompleted,
      lastFullSyncAt: row.lastFullSyncAt,
    );
  }

  int _normalizePageLimit(int? value) {
    final limit = value ?? 500;
    if (limit < 500) return 500;
    if (limit > 1000) return 1000;
    return limit;
  }
}
