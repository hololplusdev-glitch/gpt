import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:holol_POS/core/services/invoices/invoice_document.dart';
import 'package:holol_POS/core/services/invoices/invoice_pdf_fonts.dart';
import 'package:holol_POS/core/services/invoices/receipt_template_renderer.dart';

class ThermalReceiptPdfRenderer {
  final ReceiptTemplateLabels labels;

  const ThermalReceiptPdfRenderer({
    this.labels = const ReceiptTemplateLabels.ar(),
  });

  Future<Uint8List> render(
    InvoiceDocument document, {
    required int paperWidthMm,
  }) async {
    final fonts = await InvoicePdfFonts.load();

    final pdf = pw.Document(
      title: document.localInvoiceNo,
      author: document.seller.name,
      subject: document.invoiceTypeLabel,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormatForWidth(
          paperWidthMm,
          itemCount: document.lines.length,
          paymentCount: document.payments.length,
          hasNotes: _visible(document.notes),
          hasNotice: _visible(document.arabicPrintNotice),
        ),
        margin: pw.EdgeInsets.all(3 * PdfPageFormat.mm),
        build: (context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _header(document, fonts),
                pw.SizedBox(height: 4),
                _title(document, fonts),
                pw.SizedBox(height: 4),
                _invoiceInfo(document, fonts),
                pw.SizedBox(height: 4),
                _items(document, fonts),
                pw.SizedBox(height: 4),
                _totals(document, fonts),
                if (document.payments.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  _payments(document, fonts),
                ],
                pw.SizedBox(height: 5),
                _statement(document, fonts),
                if (document.qrPayload?.trim().isNotEmpty == true) ...[
                  pw.SizedBox(height: 8),
                  pw.Center(
                    child: pw.BarcodeWidget(
                      data: document.qrPayload!.trim(),
                      barcode: pw.Barcode.qrCode(),
                      width: paperWidthMm == 58 ? 95 : 120,
                      height: paperWidthMm == 58 ? 95 : 120,
                      drawText: false,
                    ),
                  ),
                ],
                if (_visible(document.notes)) ...[
                  pw.SizedBox(height: 6),
                  _note(document.notes!, fonts),
                ],
                if (_visible(document.arabicPrintNotice)) ...[
                  pw.SizedBox(height: 6),
                  _note(document.arabicPrintNotice!, fonts),
                ],
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _header(InvoiceDocument document, InvoicePdfFontSet fonts) {
    final taxNo = _firstVisible([
      document.seller.taxNumber,
      document.branch.taxNumber,
    ]);

    return pw.Container(
      padding: const pw.EdgeInsets.all(7),
      decoration: _box(),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            document.seller.name,
            textAlign: pw.TextAlign.center,
            style: fonts.style(fontSize: 12, isBold: true),
          ),
          if (_visible(document.seller.phone))
            pw.Text(
              document.seller.phone!,
              textDirection: pw.TextDirection.ltr,
              textAlign: pw.TextAlign.center,
              style: fonts.style(fontSize: 8.5, isBold: true),
            ),
          if (_visible(document.branch.address ?? document.seller.address))
            pw.Text(
              (document.branch.address ?? document.seller.address)!,
              textAlign: pw.TextAlign.center,
              style: fonts.style(fontSize: 8),
            ),
          if (_visible(taxNo)) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              labels.taxNumber,
              textAlign: pw.TextAlign.center,
              style: fonts.style(fontSize: 8.5, isBold: true),
            ),
            pw.Text(
              taxNo!,
              textDirection: pw.TextDirection.ltr,
              textAlign: pw.TextAlign.center,
              style: fonts.style(fontSize: 10, isBold: true),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _title(InvoiceDocument document, InvoicePdfFontSet fonts) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      decoration: _box(fill: PdfColors.grey300),
      alignment: pw.Alignment.center,
      child: pw.Text(
        document.invoiceTypeLabel,
        textAlign: pw.TextAlign.center,
        style: fonts.style(fontSize: 9.5, isBold: true),
      ),
    );
  }

  pw.Widget _invoiceInfo(InvoiceDocument document, InvoicePdfFontSet fonts) {
    final rows = <({String label, String value, pw.TextDirection dir})>[
      (
        label: labels.receiptInvoiceTitle(document.localInvoiceNo),
        value: document.localInvoiceNo,
        dir: pw.TextDirection.ltr,
      ),
      (
        label: '',
        value: _date(document.invoiceDateTime),
        dir: pw.TextDirection.ltr,
      ),
      (
        label: '',
        value: _time(document.invoiceDateTime),
        dir: pw.TextDirection.ltr,
      ),
      if (document.customer?.name.isNotEmpty == true)
        (
          label: labels.customer,
          value: document.customer!.name,
          dir: pw.TextDirection.rtl,
        ),
      if (document.customer?.taxNumber?.isNotEmpty == true)
        (
          label: labels.taxNumber,
          value: document.customer!.taxNumber!,
          dir: pw.TextDirection.ltr,
        ),
    ];

    return pw.Table(
      border: pw.TableBorder.all(width: 0.7),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.4),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        for (final row in rows)
          pw.TableRow(
            children: [
              _cell(row.label, fonts, bold: true, align: pw.TextAlign.right),
              _cell(
                row.value,
                fonts,
                bold: true,
                align: pw.TextAlign.center,
                dir: row.dir,
              ),
            ],
          ),
      ],
    );
  }

  pw.Widget _items(InvoiceDocument document, InvoicePdfFontSet fonts) {
    final headerLabels = [labels.unitPrice, labels.quantity, labels.discount, labels.total];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Table(
          border: pw.TableBorder.all(width: 0.7),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                for (final label in headerLabels)
                  _cell(
                    label,
                    fonts,
                    bold: true,
                    align: pw.TextAlign.center,
                    dir: pw.TextDirection.rtl,
                  ),
              ],
            ),
          ],
        ),
        for (final line in document.lines) ...[
          pw.Table(
            border: pw.TableBorder.all(width: 0.7),
            children: [
              pw.TableRow(
                children: [
                  _cell(
                    line.display.unitPrice,
                    fonts,
                    bold: true,
                    align: pw.TextAlign.center,
                    dir: pw.TextDirection.ltr,
                  ),
                  _cell(
                    line.display.quantity,
                    fonts,
                    bold: true,
                    align: pw.TextAlign.center,
                    dir: pw.TextDirection.ltr,
                  ),
                  _cell(
                    line.display.discountAmount,
                    fonts,
                    bold: true,
                    align: pw.TextAlign.center,
                    dir: pw.TextDirection.ltr,
                  ),
                  _cell(
                    line.display.lineTotal,
                    fonts,
                    bold: true,
                    align: pw.TextAlign.center,
                    dir: pw.TextDirection.ltr,
                  ),
                ],
              ),
            ],
          ),
          pw.Container(
            decoration: _box(),
            padding: const pw.EdgeInsets.all(3),
            alignment: pw.Alignment.center,
            child: pw.Text(
              line.itemName,
              textAlign: pw.TextAlign.center,
              style: fonts.style(fontSize: 8, isBold: true),
            ),
          ),
        ],
      ],
    );
  }

  pw.Widget _totals(InvoiceDocument document, InvoicePdfFontSet fonts) {
    final rows = [
      (label: labels.subtotal, value: document.totals.displaySubtotal),
      (label: labels.discount, value: document.totals.displayDiscountTotal),
      (label: labels.tax, value: document.totals.displayTaxTotal),
      (label: labels.total, value: document.totals.displayNetTotal),
      if (document.totals.changeAmount > 0)
        (label: labels.change, value: document.totals.displayChangeAmount),
    ];

    return pw.Table(
      border: pw.TableBorder.all(width: 0.7),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        for (final row in rows)
          pw.TableRow(
            children: [
              _cell(row.label, fonts, bold: true, align: pw.TextAlign.center),
              _cell(
                row.value,
                fonts,
                bold: true,
                align: pw.TextAlign.center,
                dir: pw.TextDirection.ltr,
                size: 10,
              ),
            ],
          ),
      ],
    );
  }

  pw.Widget _payments(InvoiceDocument document, InvoicePdfFontSet fonts) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.7),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        for (final payment in document.payments)
          pw.TableRow(
            children: [
              _cell(
                payment.displayMethod,
                fonts,
                bold: true,
                align: pw.TextAlign.center,
              ),
              _cell(
                payment.displayAmount,
                fonts,
                bold: true,
                align: pw.TextAlign.center,
                dir: pw.TextDirection.ltr,
                size: 10,
              ),
            ],
          ),
      ],
    );
  }

  pw.Widget _statement(InvoiceDocument document, InvoicePdfFontSet fonts) {
    final value = [
      document.localInvoiceNo,
      document.cashier.name,
      document.terminal.terminalId,
    ].where((item) => item.trim().isNotEmpty).join(' • ');

    return pw.Text(
      value,
      textAlign: pw.TextAlign.center,
      style: fonts.style(fontSize: 8.5, isBold: true),
    );
  }

  pw.Widget _note(String value, InvoicePdfFontSet fonts) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      decoration: _box(),
      alignment: pw.Alignment.center,
      child: pw.Text(
        value,
        textAlign: pw.TextAlign.center,
        style: fonts.style(fontSize: 8.5, isBold: true),
      ),
    );
  }

  pw.Widget _cell(
    String value,
    InvoicePdfFontSet fonts, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.right,
    pw.TextDirection dir = pw.TextDirection.rtl,
    double size = 8.5,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      alignment: _alignment(align),
      child: pw.Text(
        value,
        textAlign: align,
        textDirection: dir,
        style: fonts.style(fontSize: size, isBold: bold),
      ),
    );
  }

  pw.Alignment _alignment(pw.TextAlign align) {
    switch (align) {
      case pw.TextAlign.center:
        return pw.Alignment.center;
      case pw.TextAlign.left:
        return pw.Alignment.centerLeft;
      case pw.TextAlign.right:
      default:
        return pw.Alignment.centerRight;
    }
  }

  pw.BoxDecoration _box({PdfColor fill = PdfColors.white}) {
    return pw.BoxDecoration(
      color: fill,
      border: pw.Border.all(width: 0.7),
      borderRadius: pw.BorderRadius.circular(2),
    );
  }

  PdfPageFormat pageFormatForWidth(
    int paperWidthMm, {
    int itemCount = 1,
    int paymentCount = 1,
    bool hasNotes = false,
    bool hasNotice = false,
  }) {
    final width = paperWidthMm * PdfPageFormat.mm;
    final heightMm =
        130 +
        (itemCount * 12) +
        (paymentCount * 6) +
        (hasNotes ? 12 : 0) +
        (hasNotice ? 12 : 0);

    final height = heightMm.clamp(180, 900).toDouble();
    return PdfPageFormat(width, height * PdfPageFormat.mm);
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
}
