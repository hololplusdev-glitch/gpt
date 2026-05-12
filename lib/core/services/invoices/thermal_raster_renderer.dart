import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:holol_POS/core/services/invoices/invoice_document.dart';
import 'package:holol_POS/core/services/invoices/receipt_template_labels.dart';

class ThermalRasterRenderer {
  final ReceiptTemplateLabels labels;

  const ThermalRasterRenderer({this.labels = const ReceiptTemplateLabels.ar()});

  Future<List<int>> renderEscPosRaster(
    InvoiceDocument document, {
    required int paperWidthMm,
  }) async {
    final widthPx = paperWidthMm == 58 ? 384 : 576;

    final painter = _ReceiptPainter(
      document: document,
      labels: labels,
      widthPx: widthPx,
      paperWidthMm: paperWidthMm,
    );

    final heightPx = painter.estimatedHeightPx();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRect(
        Rect.fromLTWH(0, 0, widthPx.toDouble(), heightPx.toDouble()),
        Paint()..color = Colors.white,
      );

    painter.paint(canvas);

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

        if (luminance < 185) {
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
}

class _ReceiptPainter {
  final InvoiceDocument document;
  final ReceiptTemplateLabels labels;
  final int widthPx;
  final int paperWidthMm;

  late final _Text text;

  _ReceiptPainter({
    required this.document,
    required this.labels,
    required this.widthPx,
    required this.paperWidthMm,
  }) {
    text = _Text();
  }

  double get margin => paperWidthMm == 58 ? 10 : 14;
  double get font => paperWidthMm == 58 ? 15 : 18;
  double get small => paperWidthMm == 58 ? 12.5 : 15;
  double get title => paperWidthMm == 58 ? 18 : 22;
  double get rowH => paperWidthMm == 58 ? 30 : 34;

  int estimatedHeightPx() {
    final lineCount = document.lines.length.clamp(1, 80);
    final notesExtra = _visible(document.notes) ? 42 : 0;
    final noticeExtra = _visible(document.arabicPrintNotice) ? 42 : 0;
    final paymentExtra = document.payments.isEmpty
        ? 0
        : (document.payments.length + 1) * 28;

    final height =
        170 +
        42 +
        150 +
        (lineCount * 58) +
        190 +
        paymentExtra +
        notesExtra +
        noticeExtra +
        50;

    return height.clamp(720, 3600).toInt();
  }

  void paint(Canvas canvas) {
    var y = margin;

    y = _header(canvas, y);
    y += 7;

    y = _title(canvas, y);
    y += 7;

    y = _invoiceInfo(canvas, y);
    y += 7;

    y = _items(canvas, y);
    y += 7;

    y = _totals(canvas, y);
    y += 7;

    y = _payments(canvas, y);
    y += 7;

    y = _statement(canvas, y);
    y += 6;

    if (_visible(document.notes)) {
      y = _note(canvas, y, document.notes!);
      y += 6;
    }

    if (_visible(document.arabicPrintNotice)) {
      _note(canvas, y, document.arabicPrintNotice!);
    }
  }

  double _header(Canvas canvas, double y) {
    final h = paperWidthMm == 58 ? 142.0 : 158.0;
    final rect = Rect.fromLTWH(margin, y, widthPx - margin * 2, h);
    _box(canvas, rect);

    var cy = y + 8;

    cy = text.draw(
      canvas,
      document.seller.name,
      Rect.fromLTWH(rect.left + 8, cy, rect.width - 16, 28),
      size: title,
      bold: true,
      align: TextAlign.center,
      dir: TextDirection.rtl,
    );

    if (_visible(document.branch.name) &&
        document.branch.name.trim() != document.seller.name.trim()) {
      cy = text.draw(
        canvas,
        document.branch.name,
        Rect.fromLTWH(rect.left + 8, cy, rect.width - 16, 22),
        size: small + 1,
        bold: true,
        align: TextAlign.center,
        dir: TextDirection.rtl,
      );
    }

    if (_visible(document.seller.phone)) {
      cy = text.draw(
        canvas,
        document.seller.phone!,
        Rect.fromLTWH(rect.left + 8, cy, rect.width - 16, 22),
        size: small,
        bold: true,
        align: TextAlign.center,
        dir: TextDirection.ltr,
      );
    }

    final address = _firstVisible([
      document.branch.address,
      document.branch.city,
      document.seller.address,
    ]);

    if (_visible(address)) {
      cy = text.draw(
        canvas,
        address!,
        Rect.fromLTWH(rect.left + 8, cy, rect.width - 16, 24),
        size: small,
        align: TextAlign.center,
        dir: TextDirection.rtl,
      );
    }

    final taxNo = _firstVisible([
      document.seller.taxNumber,
      document.branch.taxNumber,
    ]);

    if (_visible(taxNo)) {
      cy = text.draw(
        canvas,
        labels.taxNumber,
        Rect.fromLTWH(rect.left + 8, cy + 2, rect.width - 16, 22),
        size: small,
        bold: true,
        align: TextAlign.center,
        dir: TextDirection.rtl,
      );

      text.draw(
        canvas,
        taxNo!,
        Rect.fromLTWH(rect.left + 8, cy, rect.width - 16, 24),
        size: font,
        bold: true,
        align: TextAlign.center,
        dir: TextDirection.ltr,
      );
    }

    return y + h;
  }

  double _title(Canvas canvas, double y) {
    final h = 32.0;
    final rect = Rect.fromLTWH(margin, y, widthPx - margin * 2, h);
    _box(canvas, rect, fill: const Color(0xFFEFEFEF));

    text.draw(
      canvas,
      document.invoiceTypeLabel,
      rect.deflate(4),
      size: font,
      bold: true,
      align: TextAlign.center,
      dir: TextDirection.rtl,
    );

    return y + h;
  }

  double _invoiceInfo(Canvas canvas, double y) {
    final values = <({String label, String value, TextDirection dir})>[
      (
        label: labels.receiptInvoiceTitle(document.localInvoiceNo),
        value: document.localInvoiceNo,
        dir: TextDirection.ltr,
      ),
      (
        label: labels.date,
        value: _date(document.invoiceDateTime),
        dir: TextDirection.ltr,
      ),
      (
        label: '',
        value: _time(document.invoiceDateTime),
        dir: TextDirection.ltr,
      ),
      if (document.customer?.name.isNotEmpty == true)
        (
          label: labels.customer,
          value: document.customer!.name,
          dir: TextDirection.rtl,
        ),
      if (document.customer?.taxNumber?.isNotEmpty == true)
        (
          label: labels.taxNumber,
          value: document.customer!.taxNumber!,
          dir: TextDirection.ltr,
        ),
    ];

    final h = rowH * values.length;
    final rect = Rect.fromLTWH(margin, y, widthPx - margin * 2, h);
    _box(canvas, rect);

    final labelW = rect.width * 0.48;
    final valueW = rect.width - labelW;

    for (var i = 0; i < values.length; i++) {
      final top = y + i * rowH;
      final row = Rect.fromLTWH(margin, top, rect.width, rowH);

      if (i > 0) {
        _line(canvas, Offset(row.left, row.top), Offset(row.right, row.top));
      }

      _line(
        canvas,
        Offset(row.left + labelW, row.top),
        Offset(row.left + labelW, row.bottom),
      );

      text.draw(
        canvas,
        values[i].label,
        Rect.fromLTWH(row.left + 5, row.top + 3, labelW - 10, rowH - 6),
        size: small,
        bold: true,
        align: TextAlign.right,
        dir: TextDirection.rtl,
      );

      text.draw(
        canvas,
        values[i].value,
        Rect.fromLTWH(
          row.left + labelW + 5,
          row.top + 3,
          valueW - 10,
          rowH - 6,
        ),
        size: font,
        bold: true,
        align: TextAlign.center,
        dir: values[i].dir,
      );
    }

    return y + h;
  }

  double _items(Canvas canvas, double y) {
    final w = widthPx - margin * 2;
    final colW = w / 4;

    final headerH = paperWidthMm == 58 ? 32.0 : 36.0;
    final headerRect = Rect.fromLTWH(margin, y, w, headerH);
    final headerLabels = [
      labels.unitPrice,
      labels.quantity,
      labels.discount,
      labels.total,
    ];

    _box(canvas, headerRect, fill: const Color(0xFFEFEFEF));

    for (var i = 0; i < headerLabels.length; i++) {
      final cell = Rect.fromLTWH(margin + i * colW, y, colW, headerH);

      if (i > 0) {
        _line(
          canvas,
          Offset(cell.left, headerRect.top),
          Offset(cell.left, headerRect.bottom),
        );
      }

      text.draw(
        canvas,
        headerLabels[i],
        cell.deflate(3),
        size: paperWidthMm == 58 ? 12.5 : 15,
        bold: true,
        align: TextAlign.center,
        dir: TextDirection.rtl,
      );
    }

    y += headerH;

    for (final line in document.lines) {
      final h = paperWidthMm == 58 ? 58.0 : 64.0;
      final row = Rect.fromLTWH(margin, y, w, h);
      _box(canvas, row);

      final values = [
        line.display.unitPrice,
        line.display.quantity,
        line.display.discountAmount,
        line.display.lineTotal,
      ];

      for (var i = 0; i < values.length; i++) {
        final cell = Rect.fromLTWH(margin + i * colW, y, colW, 26);
        if (i > 0) {
          _line(
            canvas,
            Offset(cell.left, row.top),
            Offset(cell.left, row.bottom),
          );
        }

        text.draw(
          canvas,
          values[i],
          cell.deflate(3),
          size: font,
          bold: true,
          align: TextAlign.center,
          dir: TextDirection.ltr,
        );
      }

      text.draw(
        canvas,
        line.itemName,
        Rect.fromLTWH(margin + 5, y + 28, w - 10, h - 30),
        size: small + 1,
        bold: true,
        align: TextAlign.center,
        dir: TextDirection.rtl,
      );

      y += h;
    }

    return y;
  }

  double _totals(Canvas canvas, double y) {
    final rows = [
      (label: labels.subtotal, value: document.totals.displaySubtotal),
      (label: labels.discount, value: document.totals.displayDiscountTotal),
      (label: labels.tax, value: document.totals.displayTaxTotal),
      (label: labels.total, value: document.totals.displayNetTotal),
      if (document.totals.changeAmount > 0)
        (label: labels.change, value: document.totals.displayChangeAmount),
    ];

    final w = widthPx - margin * 2;
    final valueW = w * 0.34;
    final labelW = w - valueW;
    final h = rowH * rows.length;
    final rect = Rect.fromLTWH(margin, y, w, h);

    _box(canvas, rect);

    for (var i = 0; i < rows.length; i++) {
      final top = y + i * rowH;
      final row = Rect.fromLTWH(margin, top, w, rowH);

      if (i > 0) {
        _line(canvas, Offset(row.left, row.top), Offset(row.right, row.top));
      }

      _line(
        canvas,
        Offset(row.left + labelW, row.top),
        Offset(row.left + labelW, row.bottom),
      );

      text.draw(
        canvas,
        rows[i].label,
        Rect.fromLTWH(row.left + 5, row.top + 3, labelW - 10, rowH - 6),
        size: small + 1,
        bold: true,
        align: TextAlign.center,
        dir: TextDirection.rtl,
      );

      text.draw(
        canvas,
        rows[i].value,
        Rect.fromLTWH(
          row.left + labelW + 5,
          row.top + 3,
          valueW - 10,
          rowH - 6,
        ),
        size: font + 1,
        bold: true,
        align: TextAlign.center,
        dir: TextDirection.ltr,
      );
    }

    return y + h;
  }

  double _payments(Canvas canvas, double y) {
    if (document.payments.isEmpty) return y;

    final w = widthPx - margin * 2;
    final valueW = w * 0.34;
    final labelW = w - valueW;
    final h = rowH * (document.payments.length + 1);
    final rect = Rect.fromLTWH(margin, y, w, h);

    _box(canvas, rect);

    final headerRow = Rect.fromLTWH(margin, y, w, rowH);
    _line(
      canvas,
      Offset(headerRow.left + labelW, headerRow.top),
      Offset(headerRow.left + labelW, headerRow.bottom),
    );
    _line(
      canvas,
      Offset(headerRow.left, headerRow.bottom),
      Offset(headerRow.right, headerRow.bottom),
    );

    text.draw(
      canvas,
      labels.paymentMethod,
      Rect.fromLTWH(
        headerRow.left + 5,
        headerRow.top + 3,
        labelW - 10,
        rowH - 6,
      ),
      size: small + 1,
      bold: true,
      align: TextAlign.center,
      dir: TextDirection.rtl,
    );

    text.draw(
      canvas,
      labels.amount,
      Rect.fromLTWH(
        headerRow.left + labelW + 5,
        headerRow.top + 3,
        valueW - 10,
        rowH - 6,
      ),
      size: small + 1,
      bold: true,
      align: TextAlign.center,
      dir: TextDirection.rtl,
    );

    for (var i = 0; i < document.payments.length; i++) {
      final payment = document.payments[i];
      final top = y + rowH + (i * rowH);
      final row = Rect.fromLTWH(margin, top, w, rowH);

      if (i > 0) {
        _line(canvas, Offset(row.left, row.top), Offset(row.right, row.top));
      }

      _line(
        canvas,
        Offset(row.left + labelW, row.top),
        Offset(row.left + labelW, row.bottom),
      );

      text.draw(
        canvas,
        payment.displayMethod,
        Rect.fromLTWH(row.left + 5, row.top + 3, labelW - 10, rowH - 6),
        size: small + 1,
        bold: true,
        align: TextAlign.center,
        dir: TextDirection.rtl,
      );

      text.draw(
        canvas,
        payment.displayAmount,
        Rect.fromLTWH(
          row.left + labelW + 5,
          row.top + 3,
          valueW - 10,
          rowH - 6,
        ),
        size: font + 1,
        bold: true,
        align: TextAlign.center,
        dir: TextDirection.ltr,
      );
    }

    return y + h;
  }

  double _statement(Canvas canvas, double y) {
    final values = [
      document.localInvoiceNo,
      document.cashier.name,
      document.terminal.terminalId,
    ].where((value) => value.trim().isNotEmpty).join(' • ');

    if (values.isEmpty) return y;

    text.draw(
      canvas,
      values,
      Rect.fromLTWH(margin, y, widthPx - margin * 2, 30),
      size: small + 1,
      bold: true,
      align: TextAlign.center,
      dir: TextDirection.rtl,
    );

    return y + 32;
  }

  double _note(Canvas canvas, double y, String value) {
    final rect = Rect.fromLTWH(margin, y, widthPx - margin * 2, 38);
    _box(canvas, rect);

    text.draw(
      canvas,
      value,
      rect.deflate(5),
      size: small,
      bold: true,
      align: TextAlign.center,
      dir: TextDirection.rtl,
    );

    return y + 38;
  }

  String _date(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year/$month/$day';
  }

  String _time(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  String? _firstVisible(List<String?> values) {
    for (final value in values) {
      if (_visible(value)) return value!.trim();
    }
    return null;
  }

  bool _visible(String? value) => value != null && value.trim().isNotEmpty;

  void _box(Canvas canvas, Rect rect, {Color fill = Colors.white}) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()
        ..color = fill
        ..style = PaintingStyle.fill,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25,
    );
  }

  void _line(Canvas canvas, Offset a, Offset b) {
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = Colors.black
        ..strokeWidth = 1,
    );
  }
}

class _Text {
  double draw(
    Canvas canvas,
    String value,
    Rect rect, {
    required double size,
    bool bold = false,
    TextAlign align = TextAlign.start,
    TextDirection dir = TextDirection.rtl,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: Colors.black,
          fontSize: size,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          height: 1.05,
          fontFamily: _hasArabic(value) ? null : 'monospace',
        ),
      ),
      maxLines: 2,
      textAlign: align,
      textDirection: dir,
      ellipsis: '…',
    )..layout(maxWidth: rect.width);

    final dy =
        rect.top + ((rect.height - painter.height) / 2).clamp(0, rect.height);
    painter.paint(canvas, Offset(rect.left, dy));
    return rect.top + rect.height;
  }

  bool _hasArabic(String value) => RegExp(r'[\u0600-\u06FF]').hasMatch(value);
}
