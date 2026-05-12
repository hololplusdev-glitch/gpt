import 'package:printing/printing.dart';
import 'package:holol_POS/core/adapters/printer_adapter.dart';
import 'package:holol_POS/core/services/invoices/invoice_document.dart';
import 'package:holol_POS/core/services/invoices/thermal_receipt_pdf_renderer.dart';
import 'package:holol_POS/core/services/pos_devices/printer_profile_service.dart';
import 'package:holol_POS/core/services/pos_devices/printer_test_document.dart';
import 'package:holol_POS/shared/models/enums.dart';

/// System printer adapter.
///
/// SSOT:
/// - Invoice shape is owned by ThermalReceiptPdfRenderer.
/// - This adapter is transport only: resolve configured OS printer + directPrintPdf.
/// - It must stay visually aligned with the raster thermal receipt.
class SystemPrinterAdapter implements PrinterAdapter {
  final ThermalReceiptPdfRenderer _renderer;

  const SystemPrinterAdapter({
    ThermalReceiptPdfRenderer renderer = const ThermalReceiptPdfRenderer(),
  }) : _renderer = renderer;

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
        'Configured system printer is not available.',
      );
    }

    try {
      final printed = await Printing.directPrintPdf(
        printer: configuredPrinter,
        name: document.localInvoiceNo,
        format: _renderer.pageFormatForWidth(
          profile.paperWidthMm,
          itemCount: document.lines.length,
          paymentCount: document.payments.length,
          hasNotes: document.notes?.trim().isNotEmpty == true,
          hasNotice: document.arabicPrintNotice?.trim().isNotEmpty == true,
        ),
        usePrinterSettings: true,
        onLayout: (_) {
          return _renderer.render(
            document,
            paperWidthMm: profile.paperWidthMm,
          );
        },
      );

      if (!printed) {
        return const PrinterAdapterResult.failure('Print was cancelled.');
      }

      return const PrinterAdapterResult.success();
    } catch (_) {
      return const PrinterAdapterResult.failure(
        'Unable to print using the configured system printer.',
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
