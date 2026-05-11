import 'package:holol_POS/core/adapters/printer_adapter.dart';
import 'package:holol_POS/core/persistence/database.dart';

class UnsupportedPrinterAdapter implements PrinterAdapter {
  final String reason;

  const UnsupportedPrinterAdapter(this.reason);

  @override
  bool isSupportedOnCurrentPlatform(PrinterProfile profile) => false;

  @override
  Future<PrinterAdapterResult> test(PrinterProfile profile) async {
    return PrinterAdapterResult.failure(reason);
  }

  @override
  Future<PrinterAdapterResult> print(
    PrinterProfile profile,
    ReceiptPayload payload,
  ) async {
    return PrinterAdapterResult.failure(reason);
  }
}
