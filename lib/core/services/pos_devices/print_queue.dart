import 'package:drift/drift.dart';
import 'package:pos_flutter/core/persistence/daos/printer_profile_dao.dart';
import 'package:pos_flutter/core/persistence/database.dart'
    hide InvoiceDocument;
import 'package:pos_flutter/core/services/invoices/invoice_document.dart';
import 'package:pos_flutter/shared/models/enums.dart';
import 'package:uuid/uuid.dart';

/// Final print queue owner.
/// Backing storage: existing PrintJobs table.
/// Print execution remains outside checkout in PrintJobProcessor.
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
    bool requireAutoPrint = true,
  }) async {
    final printer = await _printerProfileDao.getActiveByRole(
      PrinterRole.cashier,
    );

    if (printer == null) return const [];
    if (requireAutoPrint && !printer.autoPrint) return const [];

    return [
      PrintJobsCompanion(
        id: Value('PJ_${_uuid.v4()}'),
        saleId: Value(document.saleId),
        printerProfileId: Value(printer.id),
        printerRoleSnapshot: Value(printer.role),
        documentType: Value(PrintDocumentType.invoiceReceipt.code),
        status: Value(PrintJobStatus.pending.code),
        attempts: const Value(0),
        maxAttempts: const Value(3),
        payloadSnapshotJson: Value(document.toJsonString()),
        createdAt: Value(createdAt),
        createdBy: Value(createdBy),
      ),
    ];
  }
}
