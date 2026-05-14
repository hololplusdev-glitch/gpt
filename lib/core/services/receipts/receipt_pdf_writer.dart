import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:holol_POS/core/services/invoices/invoice_document.dart';
import 'package:holol_POS/core/services/receipts/receipt_raster_renderer.dart';

class ReceiptThermalPdf {
  final Uint8List bytes;
  final PdfPageFormat pageFormat;

  const ReceiptThermalPdf({
    required this.bytes,
    required this.pageFormat,
  });
}

class ReceiptPdfWriter {
  final ReceiptRasterRenderer rasterRenderer;

  const ReceiptPdfWriter({
    this.rasterRenderer = const ReceiptRasterRenderer(),
  });

  /// Renders the unified receipt as a thermal-roll PDF.
  ///
  /// This is not a report layout and not a page-container layout.
  /// The PDF page size follows the receipt width and rendered receipt height.
  Future<Uint8List> renderThermalRoll(
    InvoiceDocument document, {
    required int paperWidthMm,
  }) async {
    return (await renderThermalRollDocument(
      document,
      paperWidthMm: paperWidthMm,
    ))
        .bytes;
  }

  Future<ReceiptThermalPdf> renderThermalRollDocument(
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

    final pageWidth = receipt.paperWidthMm * PdfPageFormat.mm;
    final pageHeight = pageWidth * receipt.heightPx / receipt.widthPx;

    final pageFormat = PdfPageFormat(pageWidth, pageHeight);

    final pdf = pw.Document(
      title: document.localInvoiceNo,
      author: document.seller.name,
      subject: 'Thermal POS Receipt',
    );

    final imageProvider = pw.MemoryImage(receipt.pngBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(0),
        build: (_) {
          return pw.Image(
            imageProvider,
            width: pageWidth,
            height: pageHeight,
            fit: pw.BoxFit.fill,
          );
        },
      ),
    );

    return ReceiptThermalPdf(
      bytes: await pdf.save(),
      pageFormat: pageFormat,
    );
  }
}
