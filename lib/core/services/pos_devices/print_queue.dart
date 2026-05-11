import 'package:drift/drift.dart';
import 'package:holol_POS/core/persistence/daos/print_job_dao.dart';
import 'package:holol_POS/core/persistence/daos/printer_profile_dao.dart';
import 'package:holol_POS/core/persistence/database.dart' hide InvoiceDocument;
import 'package:holol_POS/core/services/invoices/invoice_document.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:uuid/uuid.dart';

/// Final PrintJobs owner.
/// Backing storage: existing PrintJobs table.
///
/// Checkout may ask for PrintJobsCompanion so sale + outbox + print job can be
/// persisted in a wider transaction.
/// Manual print/reprint may enqueue directly here.
/// Print execution remains in PrintJobProcessor only.
class PrintQueue {
  static const _uuid = Uuid();

  final PrintJobDao _printJobDao;
  final PrinterProfileDao _printerProfileDao;

  const PrintQueue({
    required PrintJobDao printJobDao,
    required PrinterProfileDao printerProfileDao,
  }) : _printJobDao = printJobDao,
       _printerProfileDao = printerProfileDao;

  Future<List<PrintJobsCompanion>> invoiceReceipt({
    required InvoiceDocument document,
    required DateTime createdAt,
    required String? createdBy,
    PrintDocumentType documentType = PrintDocumentType.invoiceReceipt,
    bool requireAutoPrint = true,
    String? preferredPrinterName,
  }) async {
    final printer = await _eligibleCashierPrinter(
      requireAutoPrint: requireAutoPrint,
      preferredPrinterName: preferredPrinterName,
    );

    if (printer == null) return const [];

    return [
      _newJob(
        id: 'PJ_${_uuid.v4()}',
        saleId: document.saleId,
        printer: printer,
        documentType: documentType,
        payloadSnapshotJson: document.toJsonString(),
        createdAt: createdAt,
        createdBy: createdBy,
      ),
    ];
  }

  Future<List<String>> enqueueInvoiceReceipt({
    required InvoiceDocument document,
    required DateTime createdAt,
    required String? createdBy,
    PrintDocumentType documentType = PrintDocumentType.invoiceReceipt,
    bool requireAutoPrint = false,
    String? preferredPrinterName,
  }) async {
    final printer = await _eligibleCashierPrinter(
      requireAutoPrint: requireAutoPrint,
      preferredPrinterName: preferredPrinterName,
    );

    if (printer == null) return const [];

    final jobId = 'PJ_${_uuid.v4()}';

    await _printJobDao.insert(
      _newJob(
        id: jobId,
        saleId: document.saleId,
        printer: printer,
        documentType: documentType,
        payloadSnapshotJson: document.toJsonString(),
        createdAt: createdAt,
        createdBy: createdBy,
      ),
    );

    return [jobId];
  }

  Future<PrinterProfile?> _eligibleCashierPrinter({
    required bool requireAutoPrint,
    String? preferredPrinterName,
  }) async {
    final normalizedPrinterName = preferredPrinterName?.trim();

    if (normalizedPrinterName != null && normalizedPrinterName.isNotEmpty) {
      final preferred = await _printerProfileDao.getActiveByName(
        normalizedPrinterName,
      );

      if (preferred == null) return null;
      if (requireAutoPrint && !preferred.autoPrint) return null;

      return preferred;
    }

    final printer = await _printerProfileDao.getActiveByRole(
      PrinterRole.cashier,
    );

    if (printer == null) return null;
    if (requireAutoPrint && !printer.autoPrint) return null;

    return printer;
  }

  PrintJobsCompanion _newJob({
    required String id,
    required String saleId,
    required PrinterProfile printer,
    required PrintDocumentType documentType,
    required String payloadSnapshotJson,
    required DateTime createdAt,
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
      createdAt: Value(createdAt),
      createdBy: Value(createdBy),
    );
  }
}
