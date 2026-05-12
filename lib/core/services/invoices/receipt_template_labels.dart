import 'package:holol_POS/core/l10n/app_localizations.dart';

class ReceiptTemplateLabels {
  final String taxNumber;
  final String simplifiedTaxInvoice;
  final String Function(String invoiceNo) receiptInvoiceTitle;
  final String terminal;
  final String cashier;
  final String customer;
  final String date;
  final String unitPrice;
  final String quantity;
  final String discount;
  final String subtotal;
  final String tax;
  final String total;
  final String reference;
  final String paymentMethod;
  final String amount;
  final String change;

  const ReceiptTemplateLabels({
    required this.taxNumber,
    required this.simplifiedTaxInvoice,
    required this.receiptInvoiceTitle,
    required this.terminal,
    required this.cashier,
    required this.customer,
    required this.date,
    required this.unitPrice,
    required this.quantity,
    required this.discount,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.reference,
    required this.paymentMethod,
    required this.amount,
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
      date: l10n.date,
      unitPrice: l10n.unitPrice,
      quantity: l10n.quantity,
      discount: l10n.discount,
      subtotal: l10n.subtotal,
      tax: l10n.tax,
      total: l10n.total,
      reference: l10n.reference,
      paymentMethod: l10n.paymentMethod,
      amount: l10n.amount,
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
      date = 'التاريخ',
      unitPrice = 'السعر',
      quantity = 'الكمية',
      discount = 'الخصم',
      subtotal = 'المجموع',
      tax = 'الضريبة',
      total = 'الإجمالي',
      reference = 'المرجع',
      paymentMethod = 'طريقة الدفع',
      amount = 'المبلغ',
      change = 'الباقي';

  static String _arReceiptInvoiceTitle(String invoiceNo) => 'فاتورة $invoiceNo';
}
