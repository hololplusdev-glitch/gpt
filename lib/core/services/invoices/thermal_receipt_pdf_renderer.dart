import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:holol_POS/core/services/invoices/invoice_document.dart';
import 'package:holol_POS/core/services/invoices/invoice_pdf_fonts.dart';
import 'package:holol_POS/core/services/invoices/receipt_template_renderer.dart';

class ThermalReceiptPdfRenderer {
  final ReceiptTemplateRenderer _textRenderer;

  const ThermalReceiptPdfRenderer({
    ReceiptTemplateRenderer textRenderer = const ReceiptTemplateRenderer(),
  }) : _textRenderer = textRenderer;

  Future<Uint8List> render(
    InvoiceDocument document, {
    required int paperWidthMm,
  }) async {
    final lines = _textRenderer
        .renderThermalText(
          document,
          paperWidthMm: paperWidthMm,
          includeTechnicalStatus: false,
        )
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    final hasQr = document.qrPayload?.trim().isNotEmpty == true;
    final format = pageFormatForWidth(
      paperWidthMm,
      lineCount: lines.length + (hasQr ? 16 : 0),
    );

    final fonts = await InvoicePdfFonts.load();

    final pdf = pw.Document(
      title: 'Receipt ${document.localInvoiceNo}',
      author: document.seller.name,
      subject: 'Thermal receipt',
    );

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.all(3 * PdfPageFormat.mm),
        build: (context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                for (final line in lines)
                  _receiptLine(line, fonts, paperWidthMm),
                if (hasQr) ...[
                  pw.SizedBox(height: 8),
                  pw.Center(
                    child: pw.BarcodeWidget(
                      data: document.qrPayload!.trim(),
                      barcode: pw.Barcode.qrCode(),
                      width: paperWidthMm == 58 ? 92 : 112,
                      height: paperWidthMm == 58 ? 92 : 112,
                      drawText: false,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _receiptLine(
    String line,
    InvoicePdfFontSet fonts,
    int paperWidthMm,
  ) {
    final hasArabic = _hasArabic(line);

    return pw.Text(
      line,
      textDirection: hasArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      textAlign: hasArabic ? pw.TextAlign.right : pw.TextAlign.left,
      style: fonts.style(fontSize: paperWidthMm == 58 ? 7.5 : 8.5),
    );
  }

  PdfPageFormat pageFormatForWidth(int paperWidthMm, {int lineCount = 24}) {
    final width = paperWidthMm * PdfPageFormat.mm;
    final lineHeight = paperWidthMm == 58 ? 3.9 : 4.3;
    final heightMm = (lineCount * lineHeight + 18).clamp(80, 900).toDouble();
    return PdfPageFormat(width, heightMm * PdfPageFormat.mm);
  }

  bool _hasArabic(String value) => RegExp(r'[\u0600-\u06FF]').hasMatch(value);
}
