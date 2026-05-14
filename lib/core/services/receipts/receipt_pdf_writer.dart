import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:holol_POS/core/services/invoices/invoice_document.dart';
import 'package:holol_POS/core/services/receipts/receipt_raster_renderer.dart';

class ReceiptPdfDocument {
  final Uint8List bytes;
  final PdfPageFormat pageFormat;

  const ReceiptPdfDocument({required this.bytes, required this.pageFormat});
}

class ReceiptPdfWriter {
  final ReceiptRasterRenderer rasterRenderer;

  const ReceiptPdfWriter({this.rasterRenderer = const ReceiptRasterRenderer()});

  /// Builds a PDF for saving/sharing.
  ///
  /// This PDF is only a file container. It does not own any invoice layout.
  /// The receipt visual is still produced only by ReceiptRasterRenderer.
  Future<Uint8List> renderSharePdf(
    InvoiceDocument document, {
    required int paperWidthMm,
  }) async {
    return (await renderShareDocument(
      document,
      paperWidthMm: paperWidthMm,
    )).bytes;
  }

  Future<ReceiptPdfDocument> renderShareDocument(
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

    final pageFormat = PdfPageFormat.a4;
    const margin = 24.0;

    final maxW = pageFormat.width - (margin * 2);
    final maxH = pageFormat.height - (margin * 2);

    final naturalW = receipt.paperWidthMm * PdfPageFormat.mm;
    final naturalH = naturalW * receipt.heightPx / receipt.widthPx;

    final scale = math.min(1.0, math.min(maxW / naturalW, maxH / naturalH));
    final targetW = naturalW * scale;
    final targetH = naturalH * scale;

    final imageProvider = pw.MemoryImage(receipt.pngBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
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

    return ReceiptPdfDocument(bytes: await pdf.save(), pageFormat: pageFormat);
  }

  /// Builds a PDF for OS-defined thermal receipt printers.
  ///
  /// This is used only by SystemPrinterAdapter.
  /// The page size follows the receipt width and rendered receipt height.
  Future<ReceiptPdfDocument> renderSystemPrintDocument(
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
      subject: 'Thermal POS Receipt Print',
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

    return ReceiptPdfDocument(bytes: await pdf.save(), pageFormat: pageFormat);
  }
}
