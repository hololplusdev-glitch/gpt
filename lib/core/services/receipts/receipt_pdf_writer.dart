import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:holol_POS/core/services/invoices/invoice_document.dart';
import 'package:holol_POS/core/services/receipts/receipt_raster_renderer.dart';

class ReceiptPdfWriter {
  final ReceiptRasterRenderer rasterRenderer;

  const ReceiptPdfWriter({this.rasterRenderer = const ReceiptRasterRenderer()});

  /// Saves the exact receipt visual inside an A4 container.
  ///
  /// The receipt itself remains the single POS receipt design.
  /// A4 is only a distribution container for save/share/system-print flows.
  Future<Uint8List> renderA4(
    InvoiceDocument document, {
    required int paperWidthMm,
  }) async {
    final receipt = await rasterRenderer.renderImage(
      document,
      paperWidthMm: paperWidthMm,
    );

    if (receipt.pngBytes.isEmpty) {
      throw StateError('Receipt image is empty.');
    }

    final pdf = pw.Document(
      title: document.localInvoiceNo,
      author: document.seller.name,
      subject: 'POS Receipt',
    );

    final page = PdfPageFormat.a4;
    const margin = 24.0;

    final maxW = page.width - (margin * 2);
    final maxH = page.height - (margin * 2);

    final naturalW = receipt.paperWidthMm * PdfPageFormat.mm;
    final naturalH = naturalW * receipt.heightPx / receipt.widthPx;

    final scale = math.min(1.0, math.min(maxW / naturalW, maxH / naturalH));

    final targetW = naturalW * scale;
    final targetH = naturalH * scale;

    final imageProvider = pw.MemoryImage(receipt.pngBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: page,
        margin: const pw.EdgeInsets.all(margin),
        build: (_) {
          return pw.Align(
            alignment: pw.Alignment.topCenter,
            child: pw.Image(
              imageProvider,
              width: targetW,
              height: targetH,
              fit: pw.BoxFit.fill,
            ),
          );
        },
      ),
    );

    return pdf.save();
  }
}
