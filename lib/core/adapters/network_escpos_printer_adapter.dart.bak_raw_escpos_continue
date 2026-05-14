import 'dart:io';

import 'package:holol_POS/core/adapters/printer_adapter.dart';
import 'package:holol_POS/core/services/invoices/invoice_document.dart';
import 'package:holol_POS/core/services/receipts/receipt_raster_renderer.dart';
import 'package:holol_POS/core/services/pos_devices/printer_profile_service.dart';
import 'package:holol_POS/core/services/pos_devices/printer_test_document.dart';
import 'package:holol_POS/shared/models/enums.dart';

/// Network ESC/POS printer adapter.
///
/// Transport only:
/// - no receipt layout decisions
/// - no QR/content injection
/// - no Arabic/code-page branch
class NetworkEscPosPrinterAdapter implements PrinterAdapter {
  final ReceiptRasterRenderer _renderer;

  const NetworkEscPosPrinterAdapter({
    ReceiptRasterRenderer renderer = const ReceiptRasterRenderer(),
  }) : _renderer = renderer;

  @override
  bool isSupportedOnCurrentPlatform(PrinterProfile profile) {
    return profile.connectionType == PrinterConnectionType.networkIp.code &&
        profile.driverType == PrinterDriverType.escpos.code;
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
    final host = profile.ipAddress?.trim();
    final port = profile.port ?? 9100;

    if (host == null || host.isEmpty) {
      return const PrinterAdapterResult.failure(
        'Printer IP address is required.',
      );
    }

    Socket? socket;

    try {
      socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );

      socket.add(await _buildReceiptBytes(profile, document));
      await socket.flush();
      await socket.close();

      return const PrinterAdapterResult.success();
    } catch (_) {
      socket?.destroy();

      return const PrinterAdapterResult.failure(
        'Unable to connect to printer.',
      );
    }
  }

  Future<List<int>> _buildReceiptBytes(
    PrinterProfile profile,
    InvoiceDocument document,
  ) async {
    return [
      ..._initializePrinter(),
      ...await _renderer.renderEscPosRaster(
        document,
        paperWidthMm: profile.paperWidthMm,
      ),
      ..._lineFeed(3),
      ..._cutPaper(),
    ];
  }

  List<int> _initializePrinter() => const [0x1B, 0x40];

  List<int> _lineFeed(int count) => List<int>.filled(count, 0x0A);

  List<int> _cutPaper() => const [0x1D, 0x56, 0x41, 0x00];
}
