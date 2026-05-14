import 'package:printing/printing.dart';
import 'package:holol_POS/core/adapters/printer_adapter.dart';
import 'package:holol_POS/core/services/invoices/invoice_document.dart';
import 'package:holol_POS/core/services/receipts/receipt_pdf_writer.dart';
import 'package:holol_POS/core/services/pos_devices/printer_profile_service.dart';
import 'package:holol_POS/core/services/pos_devices/printer_test_document.dart';
import 'package:holol_POS/shared/models/enums.dart';

/// Adapter for thermal receipt printers installed in the operating system.
///
/// Transport only:
/// - no receipt layout decisions
/// - no content injection
/// - no save/share PDF behavior
class SystemPrinterAdapter implements PrinterAdapter {
  final ReceiptPdfWriter _writer;

  const SystemPrinterAdapter({
    ReceiptPdfWriter writer = const ReceiptPdfWriter(),
  }) : _writer = writer;

  @override
  bool isSupportedOnCurrentPlatform(PrinterProfile profile) {
    return profile.connectionType == PrinterConnectionType.systemPrinter.code &&
        profile.driverType == PrinterDriverType.systemPrinter.code;
  }

  @override
  Future<PrinterAdapterResult> test(PrinterProfile profile) {
    return print(profile, buildPrinterTestDocument());
  }

  @override
  Future<PrinterAdapterResult> print(
    PrinterProfile profile,
    InvoiceDocument document,
  ) async {
    final configuredPrinter = await _configuredPrinter(profile);

    if (configuredPrinter == null) {
      return const PrinterAdapterResult.failure(
        'Configured system thermal printer is not available.',
      );
    }

    try {
      final printPdf = await _writer.renderSystemPrintDocument(
        document,
        paperWidthMm: profile.paperWidthMm,
      );

      final printed = await Printing.directPrintPdf(
        printer: configuredPrinter,
        name: document.localInvoiceNo,
        format: printPdf.pageFormat,
        usePrinterSettings: true,
        onLayout: (_) async => printPdf.bytes,
      );

      if (!printed) {
        return const PrinterAdapterResult.failure('Print was cancelled.');
      }

      return const PrinterAdapterResult.success();
    } catch (_) {
      return const PrinterAdapterResult.failure(
        'Unable to print using the configured system thermal printer.',
      );
    }
  }

  Future<Printer?> _configuredPrinter(PrinterProfile profile) async {
    final info = await Printing.info();
    if (!info.canListPrinters || !info.directPrint) return null;

    final configuredUrl = profile.systemPrinterUrl;
    final configuredName = profile.systemPrinterName;

    if ((configuredUrl == null || configuredUrl.isEmpty) &&
        (configuredName == null || configuredName.isEmpty)) {
      return null;
    }

    final printers = await Printing.listPrinters();

    for (final printer in printers) {
      if (!printer.isAvailable) continue;

      if (configuredUrl != null && printer.url == configuredUrl) {
        return printer;
      }

      if (configuredName != null && printer.name == configuredName) {
        return printer;
      }
    }

    return null;
  }
}
