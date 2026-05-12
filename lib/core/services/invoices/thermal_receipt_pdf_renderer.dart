import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:holol_POS/core/services/invoices/invoice_document.dart';
import 'package:holol_POS/core/services/invoices/receipt_template_labels.dart';
import 'package:holol_POS/core/services/invoices/thermal_raster_renderer.dart';

class ThermalReceiptPdfRenderer {
  final ReceiptTemplateLabels labels;

  const ThermalReceiptPdfRenderer({
    this.labels = const ReceiptTemplateLabels.ar(),
  });

  Future<Uint8List> render(
    InvoiceDocument document, {
    required int paperWidthMm,
  }) async {
    final receiptImage = await ThermalRasterRenderer(
      labels: labels,
    ).renderImage(document, paperWidthMm: paperWidthMm);

    if (receiptImage.pngBytes.isEmpty) {
      throw StateError('Thermal receipt image is empty.');
    }

    final pageFormat = _pageFormatForImage(receiptImage);
    final imageProvider = pw.MemoryImage(receiptImage.pngBytes);

    final pdf = pw.Document(
      title: document.localInvoiceNo,
      author: document.seller.name,
      subject: document.invoiceTypeLabel,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (_) {
          return pw.Image(
            imageProvider,
            width: pageFormat.width,
            height: pageFormat.height,
            fit: pw.BoxFit.fill,
          );
        },
      ),
    );

    return pdf.save();
  }

  PdfPageFormat _pageFormatForImage(ThermalReceiptRasterImage image) {
    final width = image.paperWidthMm * PdfPageFormat.mm;
    final height = width * image.heightPx / image.widthPx;
    return PdfPageFormat(width, height);
  }

  PdfPageFormat pageFormatForWidth(
    int paperWidthMm, {
    int itemCount = 1,
    int paymentCount = 1,
    bool hasNotes = false,
    bool hasNotice = false,
  }) {
    final width = paperWidthMm * PdfPageFormat.mm;
    final rows = itemCount.clamp(1, 80) + paymentCount.clamp(0, 20);
    final heightMm =
        150 + (rows * 12) + (hasNotes ? 14 : 0) + (hasNotice ? 14 : 0);
    return PdfPageFormat(width, heightMm.clamp(180, 900) * PdfPageFormat.mm);
  }
}
