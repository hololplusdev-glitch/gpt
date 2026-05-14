import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:holol_POS/core/services/invoices/invoice_document.dart';
import 'package:holol_POS/core/services/invoices/receipt_template_labels.dart';
import 'package:holol_POS/core/services/receipts/receipt_render_profile.dart';

class ReceiptRasterImage {
  final int widthPx;
  final int heightPx;
  final int paperWidthMm;
  final Uint8List pngBytes;
  final Uint8List rgbaBytes;

  const ReceiptRasterImage({
    required this.widthPx,
    required this.heightPx,
    required this.paperWidthMm,
    required this.pngBytes,
    required this.rgbaBytes,
  });
}

/// Single visual source of truth for POS receipts.
///
/// This renderer owns the receipt visual contract only.
/// It does not save files, does not talk to printers, and does not decide output format.
class ReceiptRasterRenderer {
  final ReceiptTemplateLabels labels;

  const ReceiptRasterRenderer({this.labels = const ReceiptTemplateLabels.ar()});

  Future<ReceiptRasterImage> renderImage(
    InvoiceDocument document, {
    required int paperWidthMm,
  }) async {
    final profile = ReceiptRenderProfile.thermal(paperWidthMm: paperWidthMm);
    final painter = _ReceiptPainter(
      document: document,
      labels: labels,
      profile: profile,
    );

    final heightPx = painter.measureHeightPx();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRect(
        Rect.fromLTWH(0, 0, profile.widthPx.toDouble(), heightPx.toDouble()),
        Paint()..color = Colors.white,
      );

    painter.paint(canvas);

    final image = await recorder.endRecording().toImage(
      profile.widthPx,
      heightPx,
    );

    final pngBytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final rgbaBytes = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );

    if (pngBytes == null || rgbaBytes == null) {
      throw StateError('Unable to render receipt image.');
    }

    return ReceiptRasterImage(
      widthPx: profile.widthPx,
      heightPx: image.height,
      paperWidthMm: profile.paperWidthMm,
      pngBytes: _copyBytes(pngBytes),
      rgbaBytes: _copyBytes(rgbaBytes),
    );
  }

  Future<Uint8List> renderPng(
    InvoiceDocument document, {
    required int paperWidthMm,
  }) async {
    return (await renderImage(document, paperWidthMm: paperWidthMm)).pngBytes;
  }

  Future<List<int>> renderEscPosRaster(
    InvoiceDocument document, {
    required int paperWidthMm,
  }) async {
    final image = await renderImage(document, paperWidthMm: paperWidthMm);
    return _encodeRasterBands(image);
  }

  static Uint8List _copyBytes(ByteData data) {
    return Uint8List.fromList(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  List<int> _encodeRasterBands(ReceiptRasterImage image) {
    final widthBytes = (image.widthPx + 7) ~/ 8;
    final output = <int>[];
    final profile = ReceiptRenderProfile.thermal(
      paperWidthMm: image.paperWidthMm,
    );

    for (var y0 = 0; y0 < image.heightPx; y0 += profile.rasterBandHeight) {
      final h = (image.heightPx - y0) < profile.rasterBandHeight
          ? (image.heightPx - y0)
          : profile.rasterBandHeight;

      final data = Uint8List(widthBytes * h);

      for (var y = 0; y < h; y++) {
        final sourceY = y0 + y;

        for (var x = 0; x < image.widthPx; x++) {
          final offset = (sourceY * image.widthPx + x) * 4;
          final r = image.rgbaBytes[offset];
          final g = image.rgbaBytes[offset + 1];
          final b = image.rgbaBytes[offset + 2];

          final luminance = (r * 0.299 + g * 0.587 + b * 0.114).round();

          if (luminance < 190) {
            data[y * widthBytes + (x ~/ 8)] |= 0x80 >> (x % 8);
          }
        }
      }

      output.addAll([
        0x1D,
        0x76,
        0x30,
        0x00,
        widthBytes & 0xFF,
        (widthBytes >> 8) & 0xFF,
        h & 0xFF,
        (h >> 8) & 0xFF,
        ...data,
        0x0A,
      ]);
    }

    return output;
  }
}

class _ReceiptPainter {
  final InvoiceDocument document;
  final ReceiptTemplateLabels labels;
  final ReceiptRenderProfile profile;
  final _ReceiptText text = const _ReceiptText();

  _ReceiptPainter({
    required this.document,
    required this.labels,
    required this.profile,
  });

  double get width => profile.widthPx.toDouble();
  double get contentLeft => profile.margin;
  double get contentWidth => width - (profile.margin * 2);
  double get contentRight => contentLeft + contentWidth;

  int measureHeightPx() {
    final measured = _layout(null) + profile.margin;
    return measured.ceil().clamp(640, 30000).toInt();
  }

  void paint(Canvas canvas) {
    _layout(canvas);
  }

  double _layout(Canvas? canvas) {
    var y = profile.margin;

    y = _storeHeader(canvas, y);
    y = _divider(canvas, y + profile.gap, heavy: true);
    y = _receiptTitle(canvas, y + profile.gap);
    y = _meta(canvas, y + profile.gap);
    y = _customer(canvas, y + profile.gap);
    y = _items(canvas, y + profile.gap);
    y = _totals(canvas, y + profile.gap);
    y = _taxSummary(canvas, y + profile.gap);
    y = _payments(canvas, y + profile.gap);
    y = _qr(canvas, y + profile.gap);
    y = _footer(canvas, y + profile.gap);

    return y;
  }

  double _storeHeader(Canvas? canvas, double y) {
    y = _centerText(
      canvas,
      y,
      document.seller.name,
      size: profile.titleFont,
      bold: true,
      maxLines: 3,
    );

    if (_visible(document.branch.name) &&
        document.branch.name.trim() != document.seller.name.trim()) {
      y = _centerText(
        canvas,
        y + 2,
        document.branch.name,
        size: profile.font,
        bold: true,
        maxLines: 2,
      );
    }

    if (_visible(document.seller.phone)) {
      y = _centerText(
        canvas,
        y + 2,
        document.seller.phone!,
        size: profile.smallFont,
        dir: TextDirection.ltr,
      );
    }

    final address = _firstVisible([
      document.branch.address,
      document.branch.city,
      document.seller.address,
    ]);

    if (_visible(address)) {
      y = _centerText(
        canvas,
        y + 2,
        address!,
        size: profile.smallFont,
        maxLines: 3,
      );
    }

    final taxNo = _firstVisible([
      document.seller.taxNumber,
      document.branch.taxNumber,
    ]);

    if (_visible(taxNo)) {
      y = _centerText(
        canvas,
        y + 4,
        '${labels.taxNumber}: $taxNo',
        size: profile.smallFont,
        bold: true,
        maxLines: 2,
      );
    }

    final cr = _firstVisible([
      document.seller.commercialRegistration,
      document.branch.commercialRegistration,
    ]);

    if (_visible(cr)) {
      y = _centerText(
        canvas,
        y + 2,
        'السجل التجاري: $cr',
        size: profile.smallFont,
        maxLines: 2,
      );
    }

    return y;
  }

  double _receiptTitle(Canvas? canvas, double y) {
    final title = document.copyInfo.isCopy
        ? '${labels.simplifiedTaxInvoice} - ${document.copyInfo.label}'
        : labels.simplifiedTaxInvoice;

    final h =
        text.measure(
          title,
          width: contentWidth - 16,
          size: profile.font,
          bold: true,
          align: TextAlign.center,
          maxLines: 3,
        ) +
        16;

    final rect = Rect.fromLTWH(contentLeft, y, contentWidth, h);

    if (canvas != null) {
      _roundBox(canvas, rect);
      text.draw(
        canvas,
        title,
        rect.deflate(8),
        size: profile.font,
        bold: true,
        align: TextAlign.center,
        maxLines: 3,
      );
    }

    return y + h;
  }

  double _meta(Canvas? canvas, double y) {
    final rows = <_KeyValue>[
      _KeyValue('رقم الفاتورة', document.localInvoiceNo, TextDirection.ltr),
      _KeyValue(
        labels.date,
        '${_date(document.invoiceDateTime)} ${_time(document.invoiceDateTime)}',
        TextDirection.ltr,
      ),
      _KeyValue(labels.cashier, document.cashier.name, TextDirection.rtl),
      _KeyValue(
        labels.terminal,
        document.terminal.terminalId,
        TextDirection.ltr,
      ),
    ];

    return _keyValueSection(canvas, y, rows);
  }

  double _customer(Canvas? canvas, double y) {
    final rows = <_KeyValue>[];

    if (document.customer?.name.trim().isNotEmpty == true) {
      rows.add(
        _KeyValue(labels.customer, document.customer!.name, TextDirection.rtl),
      );
    }

    if (document.customer?.taxNumber?.trim().isNotEmpty == true) {
      rows.add(
        _KeyValue(
          labels.taxNumber,
          document.customer!.taxNumber!,
          TextDirection.ltr,
        ),
      );
    }

    if (rows.isEmpty) return y - profile.gap;

    return _keyValueSection(canvas, y, rows);
  }

  double _items(Canvas? canvas, double y) {
    y = _sectionTitle(canvas, y, 'الأصناف');

    for (final line in document.lines) {
      final itemNameHeight = text.measure(
        line.itemName,
        width: contentWidth,
        size: profile.font,
        bold: true,
        maxLines: null,
      );

      final itemMetaLines = <String>[];

      if (_visible(line.unitName)) {
        itemMetaLines.add(line.unitName!);
      }

      if (_visible(line.barcode)) {
        itemMetaLines.add(line.barcode!);
      }

      final metaText = itemMetaLines.join(' • ');
      final hasMeta = metaText.isNotEmpty;

      final metaHeight = hasMeta
          ? text.measure(
              metaText,
              width: contentWidth,
              size: profile.smallFont,
              maxLines: null,
            )
          : 0.0;

      final line2H = text.measure(
        '${line.display.quantity} × ${line.display.unitPrice}',
        width: contentWidth * 0.56,
        size: profile.font,
        bold: true,
        dir: TextDirection.ltr,
      );

      final detailParts = <String>[];

      if (line.discountAmount > 0) {
        detailParts.add('${labels.discount}: ${line.display.discountAmount}');
      }

      if (line.taxAmount > 0) {
        detailParts.add('${labels.tax}: ${line.display.taxAmount}');
      }

      final details = detailParts.join('  |  ');

      final detailsHeight = details.isEmpty
          ? 0.0
          : text.measure(
              details,
              width: contentWidth,
              size: profile.smallFont,
              maxLines: null,
            );

      final blockHeight =
          itemNameHeight +
          (hasMeta ? metaHeight + 2 : 0) +
          line2H +
          (details.isEmpty ? 0 : detailsHeight + 2) +
          14;

      if (canvas != null) {
        final top = y;

        text.draw(
          canvas,
          line.itemName,
          Rect.fromLTWH(contentLeft, y, contentWidth, itemNameHeight),
          size: profile.font,
          bold: true,
          align: TextAlign.right,
          maxLines: null,
        );

        y += itemNameHeight;

        if (hasMeta) {
          text.draw(
            canvas,
            metaText,
            Rect.fromLTWH(contentLeft, y + 2, contentWidth, metaHeight),
            size: profile.smallFont,
            align: TextAlign.right,
            maxLines: null,
          );

          y += metaHeight + 2;
        }

        final rowH = line2H + 4;
        final rightW = contentWidth * 0.56;
        final leftW = contentWidth - rightW;

        text.draw(
          canvas,
          '${line.display.quantity} × ${line.display.unitPrice}',
          Rect.fromLTWH(contentRight - rightW, y + 2, rightW, rowH),
          size: profile.font,
          bold: true,
          align: TextAlign.right,
          dir: TextDirection.ltr,
        );

        text.draw(
          canvas,
          line.display.lineTotal,
          Rect.fromLTWH(contentLeft, y + 2, leftW, rowH),
          size: profile.font,
          bold: true,
          align: TextAlign.left,
          dir: TextDirection.ltr,
        );

        y += rowH;

        if (details.isNotEmpty) {
          text.draw(
            canvas,
            details,
            Rect.fromLTWH(contentLeft, y + 2, contentWidth, detailsHeight),
            size: profile.smallFont,
            align: TextAlign.right,
            maxLines: null,
          );

          y += detailsHeight + 2;
        }

        _dashLine(canvas, y + 6);
        y = top + blockHeight;
      } else {
        y += blockHeight;
      }
    }

    return y;
  }

  double _totals(Canvas? canvas, double y) {
    final t = document.totals;

    final rows = <_KeyValue>[
      _KeyValue(labels.subtotal, t.displaySubtotal, TextDirection.ltr),
      if (t.discountTotal > 0)
        _KeyValue(labels.discount, t.displayDiscountTotal, TextDirection.ltr),
      _KeyValue(labels.tax, t.displayTaxTotal, TextDirection.ltr),
      _KeyValue(labels.total, t.displayNetTotal, TextDirection.ltr, bold: true),
      _KeyValue('المدفوع', t.displayPaidTotal, TextDirection.ltr),
      if (t.remainingTotal > 0)
        _KeyValue(
          'المتبقي',
          t.displayRemainingTotal,
          TextDirection.ltr,
          bold: true,
        ),
      if (t.changeAmount > 0)
        _KeyValue(
          labels.change,
          t.displayChangeAmount,
          TextDirection.ltr,
          bold: true,
        ),
    ];

    return _keyValueSection(canvas, y, rows);
  }

  double _taxSummary(Canvas? canvas, double y) {
    if (document.taxSummary.length <= 1) return y - profile.gap;

    y = _sectionTitle(canvas, y, 'ملخص الضريبة');

    for (final tax in document.taxSummary) {
      final label = '${labels.tax} ${tax.displayRate}';
      final value = '${tax.displayTaxableAmount} / ${tax.displayTaxAmount}';

      y = _keyValueRow(canvas, y, _KeyValue(label, value, TextDirection.ltr));
    }

    return y;
  }

  double _payments(Canvas? canvas, double y) {
    if (document.payments.isEmpty) return y - profile.gap;

    y = _sectionTitle(canvas, y, 'طرق الدفع');

    for (final payment in document.payments) {
      y = _keyValueRow(
        canvas,
        y,
        _KeyValue(
          payment.displayMethod,
          payment.displayAmount,
          TextDirection.ltr,
        ),
      );

      if (_visible(payment.referenceNo)) {
        y = _keyValueRow(
          canvas,
          y,
          _KeyValue(labels.reference, payment.referenceNo!, TextDirection.ltr),
          compact: true,
        );
      }
    }

    return y;
  }

  double _qr(Canvas? canvas, double y) {
    final payload = document.qrPayload?.trim();

    if (payload == null || payload.isEmpty) return y - profile.gap;

    y = _sectionTitle(canvas, y, 'رمز الاستجابة السريعة');

    final qrSize = profile.paperWidthMm <= 58 ? 138.0 : 168.0;
    final left = contentLeft + ((contentWidth - qrSize) / 2);

    if (canvas != null) {
      final quietZone = 10.0;
      final quietRect = Rect.fromLTWH(
        left - quietZone,
        y,
        qrSize + quietZone * 2,
        qrSize + quietZone * 2,
      );

      canvas.drawRect(quietRect, Paint()..color = Colors.white);

      final painter = QrPainter(
        data: payload,
        version: QrVersions.auto,
        gapless: true,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      );

      canvas.save();
      canvas.translate(left, y + quietZone);
      painter.paint(canvas, Size(qrSize, qrSize));
      canvas.restore();
    }

    return y + qrSize + 24;
  }

  double _footer(Canvas? canvas, double y) {
    if (_visible(document.notes)) {
      y = _centerText(
        canvas,
        y,
        document.notes!,
        size: profile.smallFont,
        bold: true,
        maxLines: null,
      );

      y += profile.gap;
    }

    if (_visible(document.arabicPrintNotice)) {
      y = _centerText(
        canvas,
        y,
        document.arabicPrintNotice!,
        size: profile.smallFont,
        maxLines: null,
      );

      y += profile.gap;
    }

    final footer = [
      document.localInvoiceNo,
      document.cashier.name,
      document.terminal.terminalId,
    ].where((value) => value.trim().isNotEmpty).join(' • ');

    if (footer.isNotEmpty) {
      y = _centerText(
        canvas,
        y,
        footer,
        size: profile.smallFont,
        bold: true,
        maxLines: 3,
      );
    }

    y = _centerText(
      canvas,
      y + profile.gap,
      'شكراً لتعاملكم معنا',
      size: profile.smallFont,
      bold: true,
      maxLines: 2,
    );

    return y;
  }

  double _keyValueSection(Canvas? canvas, double y, List<_KeyValue> rows) {
    for (final row in rows) {
      y = _keyValueRow(canvas, y, row);
    }

    return y;
  }

  double _keyValueRow(
    Canvas? canvas,
    double y,
    _KeyValue row, {
    bool compact = false,
  }) {
    final paddingY = compact ? 3.0 : 5.0;
    final labelW = contentWidth * 0.44;
    final valueW = contentWidth - labelW - 8;
    final size = row.bold ? profile.font : profile.smallFont;

    final labelH = text.measure(
      row.label,
      width: labelW,
      size: size,
      bold: row.bold,
      align: TextAlign.right,
      maxLines: null,
    );

    final valueH = text.measure(
      row.value,
      width: valueW,
      size: row.bold ? profile.font : profile.smallFont,
      bold: row.bold,
      align: TextAlign.left,
      dir: row.valueDirection,
      maxLines: null,
    );

    final h = _max(labelH, valueH) + (paddingY * 2);

    if (canvas != null) {
      final top = y + paddingY;

      text.draw(
        canvas,
        row.label,
        Rect.fromLTWH(contentRight - labelW, top, labelW, h),
        size: size,
        bold: row.bold,
        align: TextAlign.right,
        maxLines: null,
      );

      text.draw(
        canvas,
        row.value,
        Rect.fromLTWH(contentLeft, top, valueW, h),
        size: row.bold ? profile.font : profile.smallFont,
        bold: row.bold,
        align: TextAlign.left,
        dir: row.valueDirection,
        maxLines: null,
      );

      _thinLine(canvas, y + h);
    }

    return y + h;
  }

  double _sectionTitle(Canvas? canvas, double y, String title) {
    y = _divider(canvas, y, heavy: true);

    final h =
        text.measure(
          title,
          width: contentWidth,
          size: profile.smallFont,
          bold: true,
          align: TextAlign.center,
          maxLines: 2,
        ) +
        8;

    if (canvas != null) {
      text.draw(
        canvas,
        title,
        Rect.fromLTWH(contentLeft, y + 4, contentWidth, h),
        size: profile.smallFont,
        bold: true,
        align: TextAlign.center,
        maxLines: 2,
      );
    }

    return y + h;
  }

  double _centerText(
    Canvas? canvas,
    double y,
    String value, {
    required double size,
    bool bold = false,
    TextDirection dir = TextDirection.rtl,
    int? maxLines = 2,
  }) {
    final h = text.measure(
      value,
      width: contentWidth,
      size: size,
      bold: bold,
      align: TextAlign.center,
      dir: dir,
      maxLines: maxLines,
    );

    if (canvas != null) {
      text.draw(
        canvas,
        value,
        Rect.fromLTWH(contentLeft, y, contentWidth, h),
        size: size,
        bold: bold,
        align: TextAlign.center,
        dir: dir,
        maxLines: maxLines,
      );
    }

    return y + h;
  }

  double _divider(Canvas? canvas, double y, {bool heavy = false}) {
    if (canvas != null) {
      final paint = Paint()
        ..color = Colors.black
        ..strokeWidth = heavy ? 1.6 : 1.0;

      canvas.drawLine(Offset(contentLeft, y), Offset(contentRight, y), paint);
    }

    return y + (heavy ? 8 : 6);
  }

  void _roundBox(Canvas canvas, Rect rect) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _thinLine(Canvas canvas, double y) {
    canvas.drawLine(
      Offset(contentLeft, y),
      Offset(contentRight, y),
      Paint()
        ..color = Colors.black
        ..strokeWidth = 0.55,
    );
  }

  void _dashLine(Canvas canvas, double y) {
    const dash = 7.0;
    const gap = 5.0;

    var x = contentLeft;

    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 0.8;

    while (x < contentRight) {
      final x2 = x + dash > contentRight ? contentRight : x + dash;

      canvas.drawLine(Offset(x, y), Offset(x2, y), paint);

      x += dash + gap;
    }
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');

    return '$year/$month/$day';
  }

  String _time(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String? _firstVisible(List<String?> values) {
    for (final value in values) {
      if (_visible(value)) return value!.trim();
    }

    return null;
  }

  bool _visible(String? value) => value != null && value.trim().isNotEmpty;

  double _max(double a, double b) => a > b ? a : b;
}

class _KeyValue {
  final String label;
  final String value;
  final TextDirection valueDirection;
  final bool bold;

  const _KeyValue(
    this.label,
    this.value,
    this.valueDirection, {
    this.bold = false,
  });
}

class _ReceiptText {
  const _ReceiptText();

  double measure(
    String value, {
    required double width,
    required double size,
    bool bold = false,
    TextAlign align = TextAlign.right,
    TextDirection dir = TextDirection.rtl,
    int? maxLines = 2,
  }) {
    final painter = _painter(
      value,
      size: size,
      bold: bold,
      align: align,
      dir: dir,
      maxLines: maxLines,
    )..layout(maxWidth: width);

    return painter.height;
  }

  void draw(
    Canvas canvas,
    String value,
    Rect rect, {
    required double size,
    bool bold = false,
    TextAlign align = TextAlign.right,
    TextDirection dir = TextDirection.rtl,
    int? maxLines = 2,
  }) {
    final painter = _painter(
      value,
      size: size,
      bold: bold,
      align: align,
      dir: dir,
      maxLines: maxLines,
    )..layout(maxWidth: rect.width);

    painter.paint(canvas, Offset(rect.left, rect.top));
  }

  TextPainter _painter(
    String value, {
    required double size,
    required bool bold,
    required TextAlign align,
    required TextDirection dir,
    required int? maxLines,
  }) {
    final normalized = value.replaceAll('\uE900', 'ر.س');

    return TextPainter(
      text: TextSpan(
        text: normalized,
        style: TextStyle(
          color: Colors.black,
          fontSize: size,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          height: 1.13,
          fontFamily: _hasArabic(normalized) ? null : 'monospace',
        ),
      ),
      maxLines: maxLines,
      textAlign: align,
      textDirection: dir,
      ellipsis: maxLines == null ? null : '…',
    );
  }

  bool _hasArabic(String value) => RegExp(r'[\u0600-\u06FF]').hasMatch(value);
}
