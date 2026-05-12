import 'package:holol_POS/core/persistence/daos/invoice_print_history_dao.dart';
import 'package:holol_POS/core/persistence/daos/print_job_dao.dart';
import 'package:holol_POS/core/persistence/daos/printer_profile_dao.dart';
import 'package:holol_POS/core/persistence/database.dart' hide InvoiceDocument;
import 'package:holol_POS/core/services/invoices/invoice_document.dart';
import 'package:holol_POS/core/services/invoices/invoice_print_history_entry.dart';
import 'package:holol_POS/core/services/pos_devices/printer_adapter_factory.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/core/services/time/clock.dart';
import 'package:uuid/uuid.dart';

class PrintJobProcessor {
  final PrintJobDao _printJobDao;
  final PrinterProfileDao _printerProfileDao;
  final PrinterAdapterFactory _adapterFactory;
  final InvoicePrintHistoryDao _printHistoryDao;
  final Clock _clock;

  static const _uuid = Uuid();

  const PrintJobProcessor({
    required PrintJobDao printJobDao,
    required PrinterProfileDao printerProfileDao,
    required PrinterAdapterFactory adapterFactory,
    required InvoicePrintHistoryDao printHistoryDao,
    Clock clock = const SystemClock(),
  }) : _printJobDao = printJobDao,
       _printerProfileDao = printerProfileDao,
       _adapterFactory = adapterFactory,
       _printHistoryDao = printHistoryDao,
       _clock = clock;

  Future<void> processRetryableJobs() async {
    final jobs = await _printJobDao.getRetryable();
    for (final job in jobs) {
      if (job.attempts >= job.maxAttempts) continue;
      await processJob(job);
    }
  }

  Future<PrintBatchResult> processJobIds(List<String> jobIds) async {
    final jobs = await _printJobDao.getByIds(jobIds);
    final jobById = {for (final job in jobs) job.id: job};
    var failed = 0;
    var processed = 0;
    for (final id in jobIds) {
      final job = jobById[id];
      if (job == null) continue;
      processed++;
      final result = await processJob(job);
      if (!result.success) failed++;
    }
    return PrintBatchResult(total: processed, failed: failed);
  }

  Future<PrintJobProcessResult> processJob(PrintJob job) async {
    if (job.status == PrintJobStatus.printed.code ||
        job.status == PrintJobStatus.cancelled.code) {
      return const PrintJobProcessResult.success();
    }

    final claimed = await _printJobDao.claimForPrinting(job.id);
    if (claimed == null) {
      return const PrintJobProcessResult.success();
    }

    try {
      final payload = InvoiceDocument.fromJsonString(
        claimed.payloadSnapshotJson,
      );
      final printer = await _printerProfileDao.getById(
        claimed.printerProfileId,
      );
      if (printer == null || !printer.enabled) {
        const error = 'Printer profile is missing or disabled.';
        await _printJobDao.markFailed(claimed.id, error);
        await _recordHistory(job: claimed, document: payload, error: error);
        return const PrintJobProcessResult.failure(error);
      }

      final adapter = _adapterFactory.forProfile(printer);
      for (var i = 0; i < printer.copies; i++) {
        final result = await adapter.print(printer, payload);
        if (!result.success) {
          await _printJobDao.markFailed(
            claimed.id,
            result.errorMessage ?? 'Print failed.',
          );
          await _recordHistory(
            job: claimed,
            document: payload,
            printer: printer,
            error: result.errorMessage ?? 'Print failed.',
          );
          return PrintJobProcessResult.failure(
            result.errorMessage ?? 'Print failed.',
          );
        }
      }

      await _printJobDao.markPrinted(claimed.id);
      await _recordHistory(job: claimed, document: payload, printer: printer);
      return const PrintJobProcessResult.success();
    } catch (error, stackTrace) {
      final message =
          "Print job could not be processed: $error\n${stackTrace.toString().split('\n').take(3).join('\n')}";
      await _printJobDao.markFailed(claimed.id, message);
      try {
        final payload = InvoiceDocument.fromJsonString(
          claimed.payloadSnapshotJson,
        );
        await _recordHistory(job: claimed, document: payload, error: message);
      } catch (_) {
        // Payload may be corrupt; the job error is still stored above.
      }
      return PrintJobProcessResult.failure(message);
    }
  }

  Future<void> _recordHistory({
    required PrintJob job,
    required InvoiceDocument document,
    PrinterProfile? printer,
    String? error,
  }) async {
    final now = _clock.now();
    await _printHistoryDao.insert(
      InvoicePrintHistoryEntry(
        id: 'IPH_${_uuid.v4()}',
        saleId: document.saleId,
        invoiceNo: document.localInvoiceNo,
        printJobId: job.id,
        printerProfileId: printer?.id ?? job.printerProfileId,
        printerName: printer?.name,
        printerRole: printer?.role ?? job.printerRoleSnapshot,
        documentType: job.documentType,
        isReprint: document.copyInfo.isCopy,
        copyNumber: document.copyInfo.copyNumber,
        printedBy: job.createdBy,
        status: error == null
            ? PrintJobStatus.printed.code
            : PrintJobStatus.failed.code,
        failureReason: error,
        payloadHash: document.auditHash,
        createdAt: now,
        printedAt: error == null ? now : null,
      ),
    );
  }
}

class PrintBatchResult {
  final int total;
  final int failed;

  const PrintBatchResult({required this.total, required this.failed});

  bool get hasFailures => failed > 0;
}

class PrintJobProcessResult {
  final bool success;
  final String? errorMessage;

  const PrintJobProcessResult._({required this.success, this.errorMessage});

  const PrintJobProcessResult.success() : this._(success: true);

  const PrintJobProcessResult.failure(String errorMessage)
    : this._(success: false, errorMessage: errorMessage);
}
