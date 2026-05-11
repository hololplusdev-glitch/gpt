import 'package:holol_POS/core/services/invoices/invoice_document.dart';

class InvoiceValidationService {
  const InvoiceValidationService();

  InvoiceValidationResult validate(InvoiceDocument document) {
    final errors = <String>[];
    final lineSubtotal = document.lines.fold<double>(
      0.0,
      (sum, line) => sum + line.lineSubtotal,
    );
    final lineDiscount = document.lines.fold<double>(
      0.0,
      (sum, line) => sum + line.discountAmount,
    );
    final lineTax = document.lines.fold<double>(
      0.0,
      (sum, line) => sum + line.taxAmount,
    );
    final lineTotal = document.lines.fold<double>(
      0.0,
      (sum, line) => sum + line.lineTotal,
    );
    final paymentTotal = document.payments.fold<double>(
      0.0,
      (sum, payment) => sum + payment.amount,
    );

    _expect('subtotal', lineSubtotal, document.totals.subtotal, errors);
    if (lineDiscount > document.totals.discountTotal) {
      errors.add('line discounts exceed invoice discount total');
    }
    _expect('tax total', lineTax, document.totals.taxTotal, errors);
    final invoiceLevelDiscount = document.totals.discountTotal > lineDiscount
        ? document.totals.discountTotal - lineDiscount
        : 0.0;
    _expect(
      'net total',
      lineTotal - invoiceLevelDiscount,
      document.totals.netTotal,
      errors,
    );
    _expect('paid total', paymentTotal, document.totals.paidTotal, errors);

    if (document.totals.changeAmount < 0 ||
        document.totals.remainingTotal < 0 ||
        document.totals.netTotal < 0) {
      errors.add('invoice contains unexpected negative totals');
    }

    return InvoiceValidationResult(errors);
  }

  void _expect(
    String label,
    double actual,
    double expected,
    List<String> errors,
  ) {
    if ((actual - expected).abs() > 0.01) {
      errors.add('$label mismatch: expected $expected, got $actual');
    }
  }
}

class InvoiceValidationResult {
  final List<String> errors;

  const InvoiceValidationResult(this.errors);

  bool get isValid => errors.isEmpty;

  String? get message => isValid ? null : errors.join('; ');
}
