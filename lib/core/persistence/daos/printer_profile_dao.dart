import 'package:drift/drift.dart';
import 'package:pos_flutter/core/persistence/database.dart';
import 'package:pos_flutter/shared/models/enums.dart';
import 'package:pos_flutter/core/services/time/clock.dart';

class PrinterProfileDao {
  final AppDatabase _db;

  final Clock _clock;

  PrinterProfileDao(this._db, {Clock clock = const SystemClock()})
    : _clock = clock;

  Stream<List<PrinterProfile>> watchAll() {
    return (_db.select(_db.printerProfiles)..orderBy([
          (p) => OrderingTerm.asc(p.role),
          (p) => OrderingTerm.asc(p.name),
        ]))
        .watch();
  }

  Future<List<PrinterProfile>> getAll() {
    return (_db.select(_db.printerProfiles)..orderBy([
          (p) => OrderingTerm.asc(p.role),
          (p) => OrderingTerm.asc(p.name),
        ]))
        .get();
  }

  Future<List<PrinterProfile>> getByRole(PrinterRole role) {
    return (_db.select(_db.printerProfiles)
          ..where((p) => p.role.equals(role.code))
          ..orderBy([
            (p) => OrderingTerm.desc(p.isDefault),
            (p) => OrderingTerm.asc(p.name),
          ]))
        .get();
  }

  Future<PrinterProfile?> getById(String id) {
    return (_db.select(
      _db.printerProfiles,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  Future<PrinterProfile?> getActiveByRole(PrinterRole role) {
    return (_db.select(_db.printerProfiles)
          ..where(
            (p) =>
                p.role.equals(role.code) &
                p.enabled.equals(true) &
                p.isDefault.equals(true),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> upsertForRole({
    required PrinterProfilesCompanion profile,
    required PrinterRole role,
    required bool makeDefault,
  }) async {
    await _db.transaction(() async {
      if (makeDefault) {
        await (_db.update(
          _db.printerProfiles,
        )..where((p) => p.role.equals(role.code))).write(
          PrinterProfilesCompanion(
            isDefault: const Value(false),
            updatedAt: Value(_clock.now()),
          ),
        );
      }
      await _db.into(_db.printerProfiles).insertOnConflictUpdate(profile);
    });
  }

  Future<void> delete(String id) {
    return (_db.delete(
      _db.printerProfiles,
    )..where((p) => p.id.equals(id))).go();
  }

  Future<void> setEnabled(String id, bool enabled) {
    return (_db.update(
      _db.printerProfiles,
    )..where((p) => p.id.equals(id))).write(
      PrinterProfilesCompanion(
        enabled: Value(enabled),
        updatedAt: Value(_clock.now()),
      ),
    );
  }

  Future<void> saveTestResult({
    required String id,
    required bool success,
    String? error,
  }) {
    return (_db.update(
      _db.printerProfiles,
    )..where((p) => p.id.equals(id))).write(
      PrinterProfilesCompanion(
        lastTestStatus: Value(success ? 'ready' : 'failed'),
        lastTestAt: Value(_clock.now()),
        lastError: Value<String?>(success ? null : error),
        updatedAt: Value(_clock.now()),
      ),
    );
  }

  Future<void> saveLastError(String id, String? error) {
    return (_db.update(
      _db.printerProfiles,
    )..where((p) => p.id.equals(id))).write(
      PrinterProfilesCompanion(
        lastError: Value(error),
        updatedAt: Value(_clock.now()),
      ),
    );
  }
}
