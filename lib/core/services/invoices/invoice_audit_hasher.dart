import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:holol_POS/core/services/invoices/invoice_document.dart';

class InvoiceAuditHasher {
  const InvoiceAuditHasher();

  String hash(InvoiceDocument document) {
    final canonical = _canonicalJson(_auditMap(document));
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  Map<String, dynamic> _auditMap(InvoiceDocument document) {
    final json = Map<String, dynamic>.from(document.toJson())
      ..remove('auditHash')
      ..remove('copyInfo')
      ..remove('printStatusLabel')
      ..remove('arabicPrintNotice');
    return json;
  }

  String _canonicalJson(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
    }
    if (value is List) {
      return '[${value.map(_canonicalJson).join(',')}]';
    }
    return jsonEncode(value);
  }
}
