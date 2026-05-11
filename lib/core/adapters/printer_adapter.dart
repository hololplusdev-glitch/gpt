import 'package:holol_POS/core/persistence/database.dart' hide InvoiceDocument;
import 'package:holol_POS/core/services/invoices/invoice_document.dart';

typedef ReceiptPayload = InvoiceDocument;

class PrinterAdapterResult {
  final bool success;
  final String? errorMessage;

  const PrinterAdapterResult._({required this.success, this.errorMessage});

  const PrinterAdapterResult.success() : this._(success: true);

  const PrinterAdapterResult.failure(String errorMessage)
    : this._(success: false, errorMessage: errorMessage);
}

abstract class PrinterAdapter {
  bool isSupportedOnCurrentPlatform(PrinterProfile profile);

  Future<PrinterAdapterResult> test(PrinterProfile profile);

  Future<PrinterAdapterResult> print(
    PrinterProfile profile,
    InvoiceDocument document,
  );
}
