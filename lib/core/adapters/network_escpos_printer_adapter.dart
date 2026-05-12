import 'dart:convert';
import 'dart:io';

import 'package:holol_POS/core/adapters/printer_adapter.dart';
import 'package:holol_POS/core/services/invoices/invoice_document.dart';
import 'package:holol_POS/core/services/invoices/thermal_raster_renderer.dart';
import 'package:holol_POS/core/services/pos_devices/printer_profile_service.dart';
import 'package:holol_POS/core/services/pos_devices/printer_test_document.dart';
import 'package:holol_POS/shared/models/enums.dart';

/// Network ESC/POS printer adapter.
///
/// SSOT:
/// - Invoice shape is owned by ThermalRasterRenderer.
/// - This adapter is transport only: socket + ESC/POS init/QR/cut.
/// - No text receipt branch.
/// - No arabicMode layout switching.
/// - Network ESC/POS always prints the unified raster receipt.
class NetworkEscPosPrinterAdapter implements PrinterAdapter {
  final ThermalRasterRenderer _renderer;

  const NetworkEscPosPrinterAdapter({
    ThermalRasterRenderer renderer = const ThermalRasterRenderer(),
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
    ReceiptPayload payload,
  ) async {
    return [
      ..._initializePrinter(),
      ...await _renderer.renderEscPosRaster(
        payload,
        paperWidthMm: profile.paperWidthMm,
      ),
      ..._lineFeed(1),
      ..._nativeQrBytes(payload.qrPayload),
      ..._lineFeed(2),
      ..._cutPaper(),
    ];
  }

  List<int> _initializePrinter() {
    return const [0x1B, 0x40];
  }

  List<int> _lineFeed(int count) {
    return List<int>.filled(count, 0x0A);
  }

  List<int> _cutPaper() {
    return const [0x1D, 0x56, 0x41, 0x00];
  }

  List<int> _nativeQrBytes(String? payload) {
    final normalized = payload?.trim();
    if (normalized == null || normalized.isEmpty) return const [];

    final data = utf8.encode(normalized);
    final length = data.length + 3;

    return [
      // Center align.
      0x1B,
      0x61,
      0x01,

      // Select QR model 2.
      0x1D,
      0x28,
      0x6B,
      0x04,
      0x00,
      0x31,
      0x41,
      0x32,
      0x00,

      // QR module size.
      0x1D,
      0x28,
      0x6B,
      0x03,
      0x00,
      0x31,
      0x43,
      0x06,

      // QR error correction.
      0x1D,
      0x28,
      0x6B,
      0x03,
      0x00,
      0x31,
      0x45,
      0x31,

      // Store QR data.
      0x1D,
      0x28,
      0x6B,
      length & 0xFF,
      (length >> 8) & 0xFF,
      0x31,
      0x50,
      0x30,
      ...data,

      // Print QR.
      0x1D,
      0x28,
      0x6B,
      0x03,
      0x00,
      0x31,
      0x51,
      0x30,

      // Left align.
      0x1B,
      0x61,
      0x00,
    ];
  }
}
