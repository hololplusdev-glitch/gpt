import 'package:drift/drift.dart';
import 'package:pos_flutter/core/persistence/database.dart';
import 'package:pos_flutter/core/services/invoices/invoice_print_history_entry.dart';

class InvoicePrintHistoryDao {
  final AppDatabase _db;

  const InvoicePrintHistoryDao(this._db);

  Future<void> insert(InvoicePrintHistoryEntry entry) async {
    await _db
        .into(_db.printHistory)
        .insert(
          PrintHistoryCompanion(
            id: Value(entry.id),
            saleId: Value(entry.saleId),
            invoiceNo: Value(entry.invoiceNo),
            printJobId: Value(entry.printJobId),
            printerProfileId: Value(entry.printerProfileId),
            printerNameSnapshot: Value(entry.printerName),
            printerRoleSnapshot: Value(entry.printerRole),
            documentType: Value(entry.documentType),
            isReprint: Value(entry.isReprint),
            copyNumber: Value(entry.copyNumber),
            reprintReason: Value(entry.reprintReason),
            printedBy: Value(entry.printedBy),
            status: Value(entry.status),
            failureReason: Value(entry.failureReason),
            payloadHash: Value(entry.payloadHash),
            createdAt: Value(entry.createdAt),
            printedAt: Value(entry.printedAt),
          ),
        );
  }

  Future<List<InvoicePrintHistoryEntry>> getForSale(String saleId) async {
    final rows =
        await (_db.select(_db.printHistory)
              ..where((entry) => entry.saleId.equals(saleId))
              ..orderBy([(entry) => OrderingTerm.desc(entry.createdAt)]))
            .get();
    return rows.map(_entryFromData).toList();
  }
}

InvoicePrintHistoryEntry _entryFromData(PrintHistoryData row) {
  return InvoicePrintHistoryEntry(
    id: row.id,
    saleId: row.saleId,
    invoiceNo: row.invoiceNo,
    printJobId: _clean(row.printJobId),
    printerProfileId: _clean(row.printerProfileId),
    printerName: _clean(row.printerNameSnapshot),
    printerRole: _clean(row.printerRoleSnapshot),
    documentType: row.documentType,
    isReprint: row.isReprint,
    copyNumber: row.copyNumber,
    reprintReason: _clean(row.reprintReason),
    printedBy: _clean(row.printedBy),
    status: row.status,
    failureReason: _clean(row.failureReason),
    payloadHash: _clean(row.payloadHash),
    createdAt: row.createdAt,
    printedAt: row.printedAt,
  );
}

String? _clean(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
