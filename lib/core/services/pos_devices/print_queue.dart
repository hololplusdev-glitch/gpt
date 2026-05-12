import 'package:drift/drift.dart';
import 'package:holol_POS/core/persistence/daos/printer_profile_dao.dart';
import 'package:holol_POS/core/persistence/database.dart' hide InvoiceDocument;
import 'package:holol_POS/core/services/invoices/invoice_document.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:uuid/uuid.dart';

/// Print job factory only.
/// Backing storage remains in PrintJobDao/SalesDao transactions.
/// Print execution remains in PrintJobProcessor only.
class PrintQueue {
  static const _uuid = Uuid();

  final PrinterProfileDao _printerProfileDao;

  const PrintQueue({
    required PrinterProfileDao printerProfileDao,
  }) : _printerProfileDao = printerProfileDao;

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
