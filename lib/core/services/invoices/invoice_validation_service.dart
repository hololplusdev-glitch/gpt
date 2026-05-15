import 'package:holol_POS/core/services/invoices/invoice_document.dart';
import 'package:holol_POS/shared/refactor/pos_business_rules.dart';

class InvoiceValidationService {
  const InvoiceValidationService();

  InvoiceValidationResult validate(InvoiceDocument document) {
    final result = PosInvoiceValidationRules.validate(document);
    return InvoiceValidationResult(result.errors);
  }
}

class InvoiceValidationResult {
  final List<String> errors;

  const InvoiceValidationResult(this.errors);

  bool get isValid => errors.isEmpty;

  String? get message => isValid ? null : errors.join('; ');
}
