// core/persistence/pos_config_repository.dart
// WHY: Type-safe accessor for POS config values. All screens read config through
// this service, never by direct DB query. This is the single source of truth
// for local application behavior flags.

import 'package:drift/drift.dart';
import 'package:holol_POS/core/constants/pos_config_keys.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/core/services/time/clock.dart';
import 'package:holol_POS/shared/models/enums.dart';

/// Reads and writes POS config from `terminal_local_settings` table.
class PosConfigRepository {
  final AppDatabase _db;
  final void Function()? _onChanged;
  final Clock _clock;

  /// In-memory cache refreshed on init and writes.
  Map<String, String> _cache = {};

  PosConfigRepository(
    this._db, {
    void Function()? onChanged,
    Clock clock = const SystemClock(),
  }) : _onChanged = onChanged,
       _clock = clock;

  /// Load all config into memory before reading cached values.
  Future<void> initialize() async {
    final rows = await _db.select(_db.terminalLocalSettings).get();
    _cache = {for (final r in rows) r.key: r.value};
    _onChanged?.call();
  }

  // ---------------------------------------------------------------------------
  // Generic accessors
  // ---------------------------------------------------------------------------

  String getString(String key, {String fallback = ''}) {
    return _cache[key] ?? PosConfigDefaults.all[key] ?? fallback;
  }

  bool getBool(String key, {bool fallback = false}) {
    final v = _cache[key] ?? PosConfigDefaults.all[key];
    return v == 'true' || v == '1';
  }

  int getInt(String key, {int fallback = 0}) {
    final v = _cache[key] ?? PosConfigDefaults.all[key];
    return int.tryParse(v ?? '') ?? fallback;
  }

  /// Write a config value.
  Future<void> set(String key, String value) async {
    await _db
        .into(_db.terminalLocalSettings)
        .insertOnConflictUpdate(
          TerminalLocalSettingsCompanion(
            key: Value(key),
            value: Value(value),
            updatedAt: Value(_clock.now()),
          ),
        );
    _cache[key] = value;
    _onChanged?.call();
  }

  /// Seed defaults (only writes keys that don't exist yet).
  Future<void> seedDefaults() async {
    final now = _clock.now();
    for (final entry in PosConfigDefaults.all.entries) {
      if (!_cache.containsKey(entry.key)) {
        await _db
            .into(_db.terminalLocalSettings)
            .insertOnConflictUpdate(
              TerminalLocalSettingsCompanion(
                key: Value(entry.key),
                value: Value(entry.value),
                updatedAt: Value(now),
              ),
            );
      }
    }
    await initialize(); // Refresh cache
  }

  // ---------------------------------------------------------------------------
  // Typed convenience getters
  // ---------------------------------------------------------------------------

  bool get useShift => getBool(PosConfigKeys.useShift, fallback: true);
  bool get useHeldInvoices =>
      getBool(PosConfigKeys.useHeldInvoices, fallback: true);
  int get maxHeldInvoices =>
      getInt(PosConfigKeys.maxHeldInvoices, fallback: 20);
  bool get blockShiftCloseWithHeldInvoices =>
      getBool(PosConfigKeys.blockShiftCloseWithHeldInvoices, fallback: true);
  bool get allowDuplicateItems =>
      getBool(PosConfigKeys.allowDuplicateItemsInCart);
  bool get priceIncludesTax => getBool(PosConfigKeys.priceIncludesTax);
  bool get requireCardReference => getBool(PosConfigKeys.requireCardReference);
  bool get autoPrintAfterSale =>
      getBool(PosConfigKeys.autoPrintAfterSale, fallback: true);
  String get localInvoiceNumberPattern => getString(
    PosConfigKeys.localInvoiceNumberPattern,
    fallback: '{STATION}-{YYYYMMDD}-{SEQ}',
  );
  int get offlineLoginExpiryDays =>
      getInt(PosConfigKeys.offlineLoginExpiryDays, fallback: 30);
  bool get allowOfflineReturns => getBool(PosConfigKeys.allowOfflineReturns);
  SyncMode get syncMode => SyncMode.fromCode(getString(PosConfigKeys.syncMode));
  int get shiftExtendMinutes =>
      getInt(PosConfigKeys.shiftExtendMinutes, fallback: 30);
}
