import 'dart:io';

import 'package:holol_POS/core/adapters/printer_adapter.dart';
import 'package:holol_POS/core/services/invoices/invoice_document.dart';
import 'package:holol_POS/core/services/pos_devices/printer_profile_service.dart';
import 'package:holol_POS/core/services/pos_devices/printer_test_document.dart';
import 'package:holol_POS/core/services/pos_devices/raw_system_printer_writer.dart';
import 'package:holol_POS/core/services/receipts/receipt_raster_renderer.dart';
import 'package:holol_POS/core/services/receipts/receipt_render_profile.dart';
import 'package:holol_POS/shared/models/enums.dart';

/// Prints to an operating-system-installed thermal printer using RAW ESC/POS.
///
/// The OS printer definition is used only as a transport endpoint. The receipt
/// is rendered as a calibrated thermal raster and sent as ESC/POS bytes, so the
/// OS driver does not resize, crop, or add document margins.
class RawSystemEscPosPrinterAdapter implements PrinterAdapter {
  final ReceiptRasterRenderer _renderer;
  final RawSystemPrinterWriter _writer;

  const RawSystemEscPosPrinterAdapter({
    ReceiptRasterRenderer renderer = const ReceiptRasterRenderer(),
    RawSystemPrinterWriter writer = const RawSystemPrinterWriter(),
  }) : _renderer = renderer,
       _writer = writer;

  @override
  bool isSupportedOnCurrentPlatform(PrinterProfile profile) {
    return Platform.isWindows &&
        profile.connectionType == PrinterConnectionType.systemPrinter.code &&
        (profile.driverType == PrinterDriverType.escpos.code ||
            profile.driverType == PrinterDriverType.systemPrinter.code);
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
    final printerName = profile.systemPrinterName?.trim();
    if (printerName == null || printerName.isEmpty) {
      return const PrinterAdapterResult.failure(
        'System printer name is required.',
      );
    }

    try {
      final bytes = await _buildReceiptBytes(profile, document);
      await _writer.writeRawBytes(
        printerName,
        bytes,
        documentName: document.localInvoiceNo,
      );
      return const PrinterAdapterResult.success();
    } catch (e) {
      return PrinterAdapterResult.failure(
        'Unable to print RAW ESC/POS to the configured system printer: $e',
      );
    }
  }

  Future<List<int>> _buildReceiptBytes(
    PrinterProfile profile,
    InvoiceDocument document,
  ) async {
    final renderProfile = ReceiptRenderProfile.fromPrinterProfile(profile);
    return [
      ..._initializePrinter(),
      ...await _renderer.renderEscPosRaster(document, profile: renderProfile),
      ..._lineFeed(3),
      ..._cutPaper(),
    ];
  }

  List<int> _initializePrinter() => const [0x1B, 0x40];

  List<int> _lineFeed(int count) => List<int>.filled(count, 0x0A);

  List<int> _cutPaper() => const [0x1D, 0x56, 0x41, 0x00];
}
