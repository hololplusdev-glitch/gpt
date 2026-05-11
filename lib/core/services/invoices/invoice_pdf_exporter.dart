import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:holol_POS/core/l10n/app_localizations.dart';
import 'package:holol_POS/core/services/formatters/pos_formatters.dart';
import 'package:holol_POS/core/services/invoices/invoice_document.dart';
import 'package:holol_POS/core/services/invoices/invoice_pdf_fonts.dart';

class InvoicePdfLabels {
  final String Function(String invoiceNo) pdfInvoiceTitle;
  final String invoiceSubject;
  final String simplifiedTaxInvoice;
  final String taxNumber;
  final String commercialRegistration;
  final String date;
  final String cashier;
  final String terminal;
  final String customer;
  final String item;
  final String quantity;
  final String unitPrice;
  final String total;
  final String beforeTaxTotal;
  final String discount;
  final String vat;
  final String paid;
  final String change;
  final String paymentMethod;
  final String reference;
  final String amount;

  const InvoicePdfLabels({
    required this.pdfInvoiceTitle,
    required this.invoiceSubject,
    required this.simplifiedTaxInvoice,
    required this.taxNumber,
    required this.commercialRegistration,
    required this.date,
    required this.cashier,
    required this.terminal,
    required this.customer,
    required this.item,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.beforeTaxTotal,
    required this.discount,
    required this.vat,
    required this.paid,
    required this.change,
    required this.paymentMethod,
    required this.reference,
    required this.amount,
  });

  factory InvoicePdfLabels.fromL10n(AppLocalizations l10n) {
    return InvoicePdfLabels(
      pdfInvoiceTitle: l10n.pdfInvoiceTitle,
      invoiceSubject: l10n.invoiceTypeSales,
      simplifiedTaxInvoice: l10n.simplifiedTaxInvoice,
      taxNumber: l10n.taxNumber,
      commercialRegistration: l10n.commercialRegistration,
      date: l10n.date,
      cashier: l10n.cashierRole,
      terminal: l10n.terminal,
      customer: l10n.customer,
      item: l10n.item,
      quantity: l10n.quantity,
      unitPrice: l10n.unitPrice,
      total: l10n.total,
      beforeTaxTotal: l10n.beforeTaxTotal,
      discount: l10n.discount,
      vat: l10n.vat,
      paid: l10n.paid,
      change: l10n.change,
      paymentMethod: l10n.paymentMethod,
      reference: l10n.reference,
      amount: l10n.amount,
    );
  }

  const InvoicePdfLabels.ar()
    : pdfInvoiceTitle = _arPdfInvoiceTitle,
      invoiceSubject = 'فاتورة مبيعات',
      simplifiedTaxInvoice = 'فاتورة ضريبية مبسطة',
      taxNumber = 'الرقم الضريبي',
      commercialRegistration = 'السجل التجاري',
      date = 'التاريخ',
      cashier = 'الكاشير',
      terminal = 'الجهاز',
      customer = 'العميل',
      item = 'الصنف',
      quantity = 'الكمية',
      unitPrice = 'سعر الوحدة',
      total = 'الإجمالي',
      beforeTaxTotal = 'المجموع قبل الضريبة',
      discount = 'الخصم',
      vat = 'ضريبة القيمة المضافة',
      paid = 'المدفوع',
      change = 'الباقي',
      paymentMethod = 'طريقة الدفع',
      reference = 'المرجع',
      amount = 'المبلغ';

  static String _arPdfInvoiceTitle(String invoiceNo) => 'فاتورة $invoiceNo';
}

class InvoicePdfExporter {
  const InvoicePdfExporter();

  Future<File> save(
    InvoiceDocument document, {
    InvoicePdfLabels labels = const InvoicePdfLabels.ar(),
  }) async {
    final outputDir = await _invoiceDownloadsDirectory();
    await outputDir.create(recursive: true);

    final safeNo = _safeInvoiceNo(document.localInvoiceNo);
    final file = await _nextAvailableFile(outputDir, 'invoice_$safeNo', 'pdf');

    final pdf = pw.Document(
      title: labels.pdfInvoiceTitle(document.localInvoiceNo),
      author: document.seller.name,
      subject: labels.invoiceSubject,
    );
    final fonts = await InvoicePdfFonts.load();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(28),
          textDirection: pw.TextDirection.rtl,
        ),
        build: (context) => [
          _header(document, fonts, labels),
          pw.SizedBox(height: 16),
          _meta(document, fonts, labels),
          pw.SizedBox(height: 16),
          _items(document, fonts, labels),
          pw.SizedBox(height: 16),
          _totals(document, fonts, labels),
          pw.SizedBox(height: 16),
          _payments(document, fonts, labels),
        ],
      ),
    );

    await file.writeAsBytes(await pdf.save(), flush: true);
    return file;
  }

  Future<Directory> _invoiceDownloadsDirectory() async {
    final fallback = await getApplicationDocumentsDirectory();

    try {
      Directory? downloads;

      if (Platform.isAndroid) {
        downloads = Directory('/storage/emulated/0/Download');
      } else {
        downloads = await getDownloadsDirectory();
      }

      if (downloads == null) {
        return Directory(
          '${fallback.path}${Platform.pathSeparator}POS_Invoices',
        );
      }

      final publicDir = Directory(
        '${downloads.path}${Platform.pathSeparator}POS_Invoices',
      );

      await publicDir.create(recursive: true);

      return publicDir;
    } catch (_) {
      return Directory('${fallback.path}${Platform.pathSeparator}POS_Invoices');
    }
  }

  String _safeInvoiceNo(String invoiceNo) {
    return invoiceNo.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
  }

  Future<File> _nextAvailableFile(
    Directory dir,
    String baseName,
    String extension,
  ) async {
    var file = File('${dir.path}${Platform.pathSeparator}$baseName.$extension');

    if (!await file.exists()) {
      return file;
    }

    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '_');

    file = File(
      '${dir.path}${Platform.pathSeparator}${baseName}_$stamp.$extension',
    );

    return file;
  }

  pw.Widget _header(
    InvoiceDocument document,
    InvoicePdfFontSet fonts,
    InvoicePdfLabels labels,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              document.seller.name,
              style: fonts.style(fontSize: 18, isBold: true),
            ),
            pw.Text(document.branch.name, style: fonts.style()),
            if (document.branch.taxNumber?.isNotEmpty == true)
              pw.Text(
                '${labels.taxNumber}: ${document.branch.taxNumber}',
                style: fonts.style(),
              ),
            if (document.branch.commercialRegistration?.isNotEmpty == true)
              pw.Text(
                '${labels.commercialRegistration}: ${document.branch.commercialRegistration}',
                style: fonts.style(),
              ),
            if (document.branch.address?.isNotEmpty == true)
              pw.Text(document.branch.address!, style: fonts.style()),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              labels.simplifiedTaxInvoice,
              style: fonts.style(fontSize: 16, isBold: true),
            ),
            pw.Text(document.localInvoiceNo, style: fonts.style()),
            if (document.copyInfo.isCopy)
              pw.Text(document.copyInfo.label, style: fonts.style()),
            if (document.qrPayload?.isNotEmpty == true) ...[
              pw.SizedBox(height: 8),
              pw.BarcodeWidget(
                data: document.qrPayload!,
                barcode: pw.Barcode.qrCode(),
                width: 86,
                height: 86,
                drawText: false,
              ),
            ],
          ],
        ),
      ],
    );
  }

  pw.Widget _meta(
    InvoiceDocument document,
    InvoicePdfFontSet fonts,
    InvoicePdfLabels labels,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        _row(
          labels.date,
          PosFormatters.dateTime(document.invoiceDateTime),
          fonts,
        ),
        _row(labels.cashier, document.cashier.name, fonts),
        _row(labels.terminal, document.terminal.terminalId, fonts),
        _row(labels.customer, document.customer?.name ?? '-', fonts),
      ],
    );
  }

  pw.Widget _items(
    InvoiceDocument document,
    InvoicePdfFontSet fonts,
    InvoicePdfLabels labels,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: const {
        0: pw.FlexColumnWidth(4),
        1: pw.FlexColumnWidth(1.4),
        2: pw.FlexColumnWidth(1.6),
        3: pw.FlexColumnWidth(1.8),
      },
      children: [
        _headerRow([
          labels.item,
          labels.quantity,
          labels.unitPrice,
          labels.total,
        ], fonts),
        for (final line in document.lines)
          pw.TableRow(
            children: [
              _cell('${line.itemName}\n${line.unitName ?? ''}', fonts),
              _cell(line.display.quantity, fonts),
              _cell(line.display.unitPrice, fonts),
              _cell(line.display.lineTotal, fonts),
            ],
          ),
      ],
    );
  }

  pw.Widget _totals(
    InvoiceDocument document,
    InvoicePdfFontSet fonts,
    InvoicePdfLabels labels,
  ) {
    final t = document.totals;
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 260,
        child: pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            _row(labels.beforeTaxTotal, t.displaySubtotal, fonts),
            _row(labels.discount, t.displayDiscountTotal, fonts),
            _row(labels.vat, t.displayTaxTotal, fonts),
            _row(labels.total, t.displayNetTotal, fonts, bold: true),
            _row(labels.paid, t.displayPaidTotal, fonts),
            _row(labels.change, t.displayChangeAmount, fonts),
          ],
        ),
      ),
    );
  }

  pw.Widget _payments(
    InvoiceDocument document,
    InvoicePdfFontSet fonts,
    InvoicePdfLabels labels,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        _headerRow([
          labels.paymentMethod,
          labels.reference,
          labels.amount,
        ], fonts),
        for (final payment in document.payments)
          pw.TableRow(
            children: [
              _cell(payment.displayMethod, fonts),
              _cell(payment.referenceNo ?? '-', fonts),
              _cell(payment.displayAmount, fonts),
            ],
          ),
      ],
    );
  }

  pw.TableRow _headerRow(List<String> values, InvoicePdfFontSet fonts) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: values
          .map((value) => _cell(value, fonts, style: fonts.style(isBold: true)))
          .toList(),
    );
  }

  pw.TableRow _row(
    String label,
    String value,
    InvoicePdfFontSet fonts, {
    bool bold = false,
  }) {
    final style = bold ? fonts.style(isBold: true) : null;
    return pw.TableRow(
      children: [
        _cell(label, fonts, style: style),
        _cell(value, fonts, style: style),
      ],
    );
  }

  pw.Widget _cell(
    String value,
    InvoicePdfFontSet fonts, {
    pw.TextStyle? style,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(value, style: style ?? fonts.style(fontSize: 9)),
    );
  }
}
