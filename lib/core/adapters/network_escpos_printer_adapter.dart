import 'dart:convert';
import 'dart:io';

import 'package:holol_POS/core/adapters/printer_adapter.dart';
import 'package:holol_POS/core/services/invoices/invoice_document.dart';
import 'package:holol_POS/core/services/pos_devices/printer_profile_service.dart';
import 'package:holol_POS/core/services/invoices/receipt_template_renderer.dart';
import 'package:holol_POS/core/services/invoices/thermal_raster_renderer.dart';
import 'package:holol_POS/core/services/pos_devices/printer_test_document.dart';
import 'package:holol_POS/shared/models/enums.dart';

class NetworkEscPosPrinterAdapter implements PrinterAdapter {
  final ReceiptTemplateRenderer _renderer;
  final ThermalRasterRenderer _rasterRenderer;

  const NetworkEscPosPrinterAdapter({
    ReceiptTemplateRenderer renderer = const ReceiptTemplateRenderer(),
    ThermalRasterRenderer rasterRenderer = const ThermalRasterRenderer(),
  }) : _renderer = renderer,
       _rasterRenderer = rasterRenderer;

  @override
  bool isSupportedOnCurrentPlatform(PrinterProfile profile) {
    return profile.connectionType == PrinterConnectionType.networkIp.code &&
        profile.driverType == PrinterDriverType.escpos.code;
  }

  @override
  Future<PrinterAdapterResult> test(PrinterProfile profile) async {
    return print(profile, buildPrinterTestDocument());
  }

  @override
  Future<PrinterAdapterResult> print(
    PrinterProfile profile,
    InvoiceDocument payload,
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
      socket.add(await _buildReceiptBytes(profile, payload));
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
    final buffer = StringBuffer()
      ..writeln('\x1B@')
      ..write(
        profile.arabicMode == ArabicPrintMode.raster.code
            ? ''
            : _renderer.renderThermalText(
                payload,
                paperWidthMm: profile.paperWidthMm,
              ),
      );
    if (profile.arabicMode == ArabicPrintMode.raster.code) {
      return [
        ...utf8.encode('\x1B@'),
        ...await _rasterRenderer.renderEscPosRaster(
          payload,
          paperWidthMm: profile.paperWidthMm,
        ),
        ..._nativeQrBytes(payload.qrPayload),
        ...utf8.encode('\n\n\x1DVA\x00'),
      ];
    }
    buffer.writeln('\n');
    final bytes = <int>[
      ...utf8.encode(buffer.toString()),
      ..._nativeQrBytes(payload.qrPayload),
      ...utf8.encode('\n'),
    ];
    bytes.addAll(utf8.encode('\x1DVA\x00'));
    return bytes;
  }

  List<int> _nativeQrBytes(String? payload) {
    if (payload == null || payload.isEmpty) return const [];
    final data = utf8.encode(payload);
    final length = data.length + 3;
    return [
      0x1B,
      0x61,
      0x01,
      0x1D,
      0x28,
      0x6B,
      0x04,
      0x00,
      0x31,
      0x41,
      0x32,
      0x00,
      0x1D,
      0x28,
      0x6B,
      0x03,
      0x00,
      0x31,
      0x43,
      0x06,
      0x1D,
      0x28,
      0x6B,
      0x03,
      0x00,
      0x31,
      0x45,
      0x31,
      0x1D,
      0x28,
      0x6B,
      length & 0xFF,
      (length >> 8) & 0xFF,
      0x31,
      0x50,
      0x30,
      ...data,
      0x1D,
      0x28,
      0x6B,
      0x03,
      0x00,
      0x31,
      0x51,
      0x30,
      0x1B,
      0x61,
      0x00,
    ];
  }
}
