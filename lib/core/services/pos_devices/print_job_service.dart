import 'package:drift/drift.dart';
import 'package:pos_flutter/core/services/time/clock.dart';
import 'package:pos_flutter/core/persistence/daos/print_job_dao.dart';
import 'package:pos_flutter/core/persistence/daos/printer_profile_dao.dart';
import 'package:pos_flutter/core/persistence/database.dart'
    hide InvoiceDocument;
export 'package:pos_flutter/core/persistence/database.dart' show PrintJob;
import 'package:pos_flutter/core/services/invoices/invoice_document.dart';
import 'package:pos_flutter/shared/models/enums.dart';
import 'package:uuid/uuid.dart';

class PrintJobService {
  final PrintJobDao _printJobDao;
  final PrinterProfileDao _printerProfileDao;
  final Clock _clock;

  static const _uuid = Uuid();

  const PrintJobService({
    required PrintJobDao printJobDao,
    required PrinterProfileDao printerProfileDao,
    Clock clock = const SystemClock(),
  }) : _printJobDao = printJobDao,
       _printerProfileDao = printerProfileDao,
       _clock = clock;

  Stream<List<PrintJob>> watchRetryableJobs() => _printJobDao.watchRetryable();

  Future<List<PrintJob>> getRetryableJobs() => _printJobDao.getRetryable();

  Future<int> nextCopyNumber(String saleId) async {
    return await _printJobDao.countPrintedCopies(saleId) + 1;
  }

  Future<List<String>> enqueueDocument({
    required InvoiceDocument document,
    required String? createdBy,
    PrintDocumentType documentType = PrintDocumentType.invoiceReceipt,
    bool requireAutoPrint = false,
  }) async {
    final printer = await _printerProfileDao.getActiveByRole(
      PrinterRole.cashier,
    );
    if (printer == null) return const [];
    if (requireAutoPrint && !printer.autoPrint) return const [];
    final now = _clock.now();
    final jobId = 'PJ_${_uuid.v4()}';
    await _printJobDao.insert(
      _newJob(
        id: jobId,
        now: now,
        saleId: document.saleId,
        printer: printer,
        documentType: documentType,
        payloadSnapshotJson: document.toJsonString(),
        createdBy: createdBy,
      ),
    );
    return [jobId];
  }

  Future<void> retryFailedJob(String jobId) => _printJobDao.markPending(jobId);

  PrintJobsCompanion _newJob({
    required String id,
    required DateTime now,
    required String saleId,
    required PrinterProfile printer,
    required PrintDocumentType documentType,
    required String payloadSnapshotJson,
    required String? createdBy,
  }) {
    return PrintJobsCompanion(
      id: Value(id),
      saleId: Value(saleId),
      printerProfileId: Value(printer.id),
      printerRoleSnapshot: Value(printer.role),
      documentType: Value(documentType.code),
      status: Value(PrintJobStatus.pending.code),
      attempts: const Value(0),
      maxAttempts: const Value(3),
      payloadSnapshotJson: Value(payloadSnapshotJson),
      createdAt: Value(now),
      createdBy: Value(createdBy),
    );
  }
}
