import 'package:drift/drift.dart';
import 'package:pos_flutter/core/persistence/database.dart'
    hide InvoiceDocument;
import 'package:pos_flutter/core/services/invoices/invoice_document.dart';
import 'package:pos_flutter/core/services/invoices/invoice_validation_service.dart';
import 'package:pos_flutter/core/services/time/clock.dart';

class InvoiceArchiveRepository {
  final AppDatabase _db;
  final Clock _clock;

  const InvoiceArchiveRepository({
    required AppDatabase db,
    Clock clock = const SystemClock(),
  }) : _db = db,
       _clock = clock;

  Future<void> persistIfMissing({
    required InvoiceDocument document,
    required String auditHash,
    required InvoiceValidationResult validation,
  }) async {
    final existing = await (_db.select(
      _db.invoiceDocuments,
    )..where((doc) => doc.saleId.equals(document.saleId))).getSingleOrNull();
    final existingHash = existing?.hash;
    if (existingHash != null && existingHash.isNotEmpty) return;

    await _db
        .into(_db.invoiceDocuments)
        .insertOnConflictUpdate(
          InvoiceDocumentsCompanion.insert(
            id: 'DOC_${document.saleId}',
            saleId: document.saleId,
            snapshotJson: Value(document.toJsonString()),
            hash: Value(auditHash),
            archivedAt: Value(_clock.now()),
            validationStatus: Value(validation.isValid ? 'valid' : 'invalid'),
            validationError: Value(validation.message),
          ),
        );
  }

  Future<InvoiceDocument?> loadOriginal(String saleId) async {
    final row = await (_db.select(
      _db.invoiceDocuments,
    )..where((doc) => doc.saleId.equals(saleId))).getSingleOrNull();
    final snapshot = row?.snapshotJson;
    if (snapshot == null || snapshot.isEmpty) return null;
    return InvoiceDocument.fromJsonString(snapshot);
  }

  Future<String?> hashForSale(String saleId) async {
    final row = await (_db.select(
      _db.invoiceDocuments,
    )..where((doc) => doc.saleId.equals(saleId))).getSingleOrNull();
    final value = row?.hash;
    return value == null || value.isEmpty ? null : value;
  }
}
