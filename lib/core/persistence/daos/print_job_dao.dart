import 'package:drift/drift.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/core/services/time/clock.dart';
import 'package:holol_POS/core/persistence/daos/dao_shared.dart';

class PrintJobDao {
  final AppDatabase _db;

  final Clock _clock;

  PrintJobDao(this._db, {Clock clock = const SystemClock()}) : _clock = clock;

  Stream<List<PrintJob>> watchRetryable() {
    return (_db.select(_db.printJobs)
          ..where(
            (j) =>
                (j.status.equals(PrintJobStatus.pending.code) |
                    j.status.equals(PrintJobStatus.failed.code)) &
                j.attempts.isSmallerThan(j.maxAttempts),
          )
          ..orderBy([(j) => OrderingTerm.asc(j.createdAt)]))
        .watch();
  }

  Future<List<PrintJob>> getRetryable() {
    return (_db.select(_db.printJobs)
          ..where(
            (j) =>
                (j.status.equals(PrintJobStatus.pending.code) |
                    j.status.equals(PrintJobStatus.failed.code)) &
                j.attempts.isSmallerThan(j.maxAttempts),
          )
          ..orderBy([(j) => OrderingTerm.asc(j.createdAt)]))
        .get();
  }

  Future<PrintJob?> getById(String id) {
    return (_db.select(
      _db.printJobs,
    )..where((j) => j.id.equals(id))).getSingleOrNull();
  }

  Future<List<PrintJob>> getByIds(List<String> ids) {
    if (ids.isEmpty) return Future.value(const []);
    return (_db.select(_db.printJobs)..where((j) => j.id.isIn(ids))).get();
  }

  Future<PrintJob?> claimForPrinting(String id) async {
    return _db.transaction(() async {
      final job = await getById(id);
      if (job == null) return null;

      final retryable = DaoPrintJobPolicy.isRetryable(job);
      if (!retryable) return null;

      final attempts = job.attempts + 1;
      final updated =
          await (_db.update(_db.printJobs)..where(
                (j) =>
                    j.id.equals(id) &
                    (j.status.equals(PrintJobStatus.pending.code) |
                        j.status.equals(PrintJobStatus.failed.code)) &
                    j.attempts.isSmallerThan(j.maxAttempts),
              ))
              .write(
                PrintJobsCompanion(
                  status: Value(PrintJobStatus.printing.code),
                  attempts: Value(attempts),
                  errorMessage: const Value<String?>(null),
                ),
              );

      if (updated != 1) return null;
      return getById(id);
    });
  }

  Future<List<PrintJob>> getForSale(String saleId) {
    return (_db.select(_db.printJobs)
          ..where((j) => j.saleId.equals(saleId))
          ..orderBy([(j) => OrderingTerm.desc(j.createdAt)]))
        .get();
  }

  Future<int> countPrintedCopies(String saleId) async {
    final jobs = await getForSale(saleId);
    return jobs.where(DaoPrintJobPolicy.isPrintedReceiptCopy).length;
  }

  Future<bool> hasPrintedOriginal(String saleId) async {
    final jobs = await getForSale(saleId);
    return jobs.any(DaoPrintJobPolicy.isPrintedOriginal);
  }

  Future<List<PrintJob>> getOriginalJobs(String saleId) {
    return (_db.select(_db.printJobs)
          ..where(
            (j) =>
                j.saleId.equals(saleId) &
                j.documentType.equals(PrintDocumentType.invoiceReceipt.code),
          )
          ..orderBy([(j) => OrderingTerm.asc(j.createdAt)]))
        .get();
  }

  Future<void> insert(PrintJobsCompanion job) {
    return _db.into(_db.printJobs).insert(job);
  }

  Future<void> insertAll(List<PrintJobsCompanion> jobs) async {
    if (jobs.isEmpty) return;

    await _db.batch((batch) {
      batch.insertAll(_db.printJobs, jobs);
    });
  }

  Future<void> markPrinted(String id) {
    return (_db.update(_db.printJobs)..where((j) => j.id.equals(id))).write(
      DaoPrintJobPolicy.markPrinted(_clock.now()),
    );
  }

  Future<void> markFailed(String id, String error) {
    return (_db.update(_db.printJobs)..where((j) => j.id.equals(id))).write(
      DaoPrintJobPolicy.markFailed(error),
    );
  }

  Future<void> markPending(String id) {
    return (_db.update(
      _db.printJobs,
    )..where((j) => j.id.equals(id))).write(DaoPrintJobPolicy.markPending());
  }
}
