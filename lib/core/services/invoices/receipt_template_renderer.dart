import 'package:holol_POS/core/l10n/app_localizations.dart';
import 'package:holol_POS/core/services/formatters/pos_formatters.dart';
import 'package:holol_POS/core/services/invoices/invoice_document.dart';

class ReceiptTemplateLabels {
  final String taxNumber;
  final String simplifiedTaxInvoice;
  final String Function(String invoiceNo) receiptInvoiceTitle;
  final String terminal;
  final String cashier;
  final String customer;
  final String discount;
  final String subtotal;
  final String tax;
  final String total;
  final String reference;
  final String change;

  const ReceiptTemplateLabels({
    required this.taxNumber,
    required this.simplifiedTaxInvoice,
    required this.receiptInvoiceTitle,
    required this.terminal,
    required this.cashier,
    required this.customer,
    required this.discount,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.reference,
    required this.change,
  });

  factory ReceiptTemplateLabels.fromL10n(AppLocalizations l10n) {
    return ReceiptTemplateLabels(
      taxNumber: l10n.taxNumber,
      simplifiedTaxInvoice: l10n.simplifiedTaxInvoice,
      receiptInvoiceTitle: l10n.pdfInvoiceTitle,
      terminal: l10n.terminal,
      cashier: l10n.cashierRole,
      customer: l10n.customer,
      discount: l10n.discount,
      subtotal: l10n.subtotal,
      tax: l10n.tax,
      total: l10n.total,
      reference: l10n.reference,
      change: l10n.change,
    );
  }

  const ReceiptTemplateLabels.ar()
    : taxNumber = 'الرقم الضريبي',
      simplifiedTaxInvoice = 'فاتورة ضريبية مبسطة',
      receiptInvoiceTitle = _arReceiptInvoiceTitle,
      terminal = 'الجهاز',
      cashier = 'الكاشير',
      customer = 'العميل',
      discount = 'الخصم',
      subtotal = 'المجموع',
      tax = 'الضريبة',
      total = 'الإجمالي',
      reference = 'المرجع',
      change = 'الباقي';

  static String _arReceiptInvoiceTitle(String invoiceNo) => 'فاتورة $invoiceNo';
}

class ReceiptTemplateRenderer {
  const ReceiptTemplateRenderer();

  String renderThermalText(
    InvoiceDocument document, {
    required int paperWidthMm,
    ReceiptTemplateLabels labels = const ReceiptTemplateLabels.ar(),
    bool includeTechnicalStatus = false,
  }) {
    final width = paperWidthMm == 58 ? 32 : 42;

    final b = StringBuffer()
      ..writeln(_center(document.seller.name, width))
      ..writeln(_center(document.branch.name, width));

    final taxNumber = document.seller.taxNumber ?? document.branch.taxNumber;
    if (taxNumber?.isNotEmpty == true) {
      b.writeln(_center('${labels.taxNumber}: $taxNumber', width));
    }

    b
      ..writeln(_center(labels.simplifiedTaxInvoice, width))
      ..writeln(
        _center(labels.receiptInvoiceTitle(document.localInvoiceNo), width),
      );

    if (document.copyInfo.isCopy) {
      b.writeln(_center(document.copyInfo.label, width));
    }

    b
      ..writeln(PosFormatters.dateTime(document.invoiceDateTime))
      ..writeln('${labels.terminal}: ${document.terminal.terminalId}')
      ..writeln('${labels.cashier}: ${document.cashier.name}');

    if (document.customer?.name.isNotEmpty == true) {
      b.writeln('${labels.customer}: ${document.customer!.name}');
    }

    b.writeln(_rule(width));

    for (final line in document.lines) {
      _writeWrapped(b, line.itemName, width);
      b.writeln(
        _row(
          '${line.display.quantity} ${line.unitName ?? ''} x ${line.display.unitPrice}',
          line.display.lineTotal,
          width,
        ),
      );

      if (line.discountAmount > 0) {
        b.writeln(_row(labels.discount, line.display.discountAmount, width));
      }
    }

    b
      ..writeln(_rule(width))
      ..writeln(_row(labels.subtotal, document.totals.displaySubtotal, width))
      ..writeln(
        _row(labels.discount, document.totals.displayDiscountTotal, width),
      )
      ..writeln(_row(labels.tax, document.totals.displayTaxTotal, width))
      ..writeln(_rule(width, char: '='))
      ..writeln(_row(labels.total, document.totals.displayNetTotal, width))
      ..writeln(_rule(width));

    for (final payment in document.payments) {
      b.writeln(_row(payment.displayMethod, payment.displayAmount, width));

      if (payment.referenceNo?.isNotEmpty == true) {
        _writeWrapped(b, '${labels.reference}: ${payment.referenceNo}', width);
      }
    }

    if (document.totals.changeAmount > 0) {
      b.writeln(
        _row(labels.change, document.totals.displayChangeAmount, width),
      );
    }

    if (document.notes?.isNotEmpty == true) {
      b
        ..writeln(_rule(width))
        ..write(_wrapped(document.notes!, width).join('\n'))
        ..writeln();
    }

    if (includeTechnicalStatus) {
      b
        ..writeln(_rule(width))
        ..writeln(document.syncStatusLabel);

      if (document.arabicPrintNotice?.isNotEmpty == true) {
        _writeWrapped(b, document.arabicPrintNotice!, width);
      }
    }

    b.writeln(_rule(width));

    return b.toString();
  }

  String _row(String left, String right, int width) {
    final leftWidth = width - right.length - 1;
    if (leftWidth <= 0) return _clip('$left $right', width);
    return '${_clip(left, leftWidth).padRight(leftWidth)} $right';
  }

  String _center(String value, int width) {
    if (value.length >= width) return value;
    final left = ((width - value.length) / 2).floor();
    return ''.padRight(left) + value;
  }

  String _rule(int width, {String char = '-'}) {
    return ''.padRight(width, char);
  }

  String _clip(String value, int width) {
    if (value.length <= width) return value;
    return value.substring(0, width);
  }

  void _writeWrapped(StringBuffer buffer, String value, int width) {
    for (final line in _wrapped(value, width)) {
      buffer.writeln(line);
    }
  }

  List<String> _wrapped(String value, int width) {
    final normalized = value.trim();
    if (normalized.isEmpty) return const [''];

    final lines = <String>[];
    final words = normalized.split(RegExp(r'\s+'));
    var current = '';

    for (final word in words) {
      if (word.length > width) {
        if (current.isNotEmpty) {
          lines.add(current);
          current = '';
        }

        for (var start = 0; start < word.length; start += width) {
          final end = (start + width).clamp(0, word.length);
          lines.add(word.substring(start, end));
        }
        continue;
      }

      final next = current.isEmpty ? word : '$current $word';
      if (next.length <= width) {
        current = next;
      } else {
        lines.add(current);
        current = word;
      }
    }

    if (current.isNotEmpty) lines.add(current);
    return lines;
  }
}
