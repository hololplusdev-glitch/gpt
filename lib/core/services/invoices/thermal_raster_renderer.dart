import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pos_flutter/core/services/invoices/invoice_document.dart';
import 'package:pos_flutter/core/services/invoices/receipt_template_renderer.dart';

class ThermalRasterRenderer {
  final ReceiptTemplateRenderer _textRenderer;

  const ThermalRasterRenderer({
    ReceiptTemplateRenderer textRenderer = const ReceiptTemplateRenderer(),
  }) : _textRenderer = textRenderer;

  Future<List<int>> renderEscPosRaster(
    InvoiceDocument document, {
    required int paperWidthMm,
  }) async {
    final widthPx = paperWidthMm == 58 ? 384 : 576;
    final lines = _textRenderer
        .renderThermalText(document, paperWidthMm: paperWidthMm)
        .split('\n');
    const lineHeight = 28.0;
    const horizontalPadding = 12.0;
    final heightPx = ((lines.length + 1) * lineHeight).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRect(
        Rect.fromLTWH(0, 0, widthPx.toDouble(), heightPx.toDouble()),
        Paint()..color = Colors.white,
      );

    var y = 8.0;
    for (final line in lines) {
      final painter = TextPainter(
        text: TextSpan(
          text: line,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontFamily: 'monospace',
          ),
        ),
        maxLines: 2,
        textDirection: _hasArabic(line) ? TextDirection.rtl : TextDirection.ltr,
      )..layout(maxWidth: widthPx - (horizontalPadding * 2));
      painter.paint(canvas, Offset(horizontalPadding, y));
      y += lineHeight;
    }

    final image = await recorder.endRecording().toImage(widthPx, heightPx);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) return const [];
    return _encodeRaster(widthPx, heightPx, bytes.buffer.asUint8List());
  }

  List<int> _encodeRaster(int widthPx, int heightPx, Uint8List rgba) {
    final widthBytes = (widthPx + 7) ~/ 8;
    final data = Uint8List(widthBytes * heightPx);
    for (var y = 0; y < heightPx; y++) {
      for (var x = 0; x < widthPx; x++) {
        final offset = (y * widthPx + x) * 4;
        final r = rgba[offset];
        final g = rgba[offset + 1];
        final b = rgba[offset + 2];
        final luminance = (r * 0.299 + g * 0.587 + b * 0.114).round();
        if (luminance < 180) {
          data[y * widthBytes + (x ~/ 8)] |= 0x80 >> (x % 8);
        }
      }
    }
    return [
      0x1D,
      0x76,
      0x30,
      0x00,
      widthBytes & 0xFF,
      (widthBytes >> 8) & 0xFF,
      heightPx & 0xFF,
      (heightPx >> 8) & 0xFF,
      ...data,
    ];
  }

  bool _hasArabic(String value) => RegExp(r'[\u0600-\u06FF]').hasMatch(value);
}
