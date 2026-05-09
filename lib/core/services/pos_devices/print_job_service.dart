import 'package:pos_flutter/core/persistence/daos/print_job_dao.dart';
import 'package:pos_flutter/core/persistence/database.dart' show PrintJob;
export 'package:pos_flutter/core/persistence/database.dart' show PrintJob;

/// Retry/status shell only.
/// PrintJobs are built/enqueued by PrintQueue.
/// Print execution is handled by PrintJobProcessor.
class PrintJobService {
  final PrintJobDao _printJobDao;

  const PrintJobService({
    required PrintJobDao printJobDao,
  }) : _printJobDao = printJobDao;

  Stream<List<PrintJob>> watchRetryableJobs() => _printJobDao.watchRetryable();

  Future<List<PrintJob>> getRetryableJobs() => _printJobDao.getRetryable();

  Future<int> nextCopyNumber(String saleId) async {
    return await _printJobDao.countPrintedCopies(saleId) + 1;
  }

  Future<void> retryFailedJob(String jobId) => _printJobDao.markPending(jobId);
}
