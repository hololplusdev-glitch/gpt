import 'dart:convert';

import 'package:holol_POS/core/services/invoices/invoice_document.dart';

class QrPayloadBuilder {
  const QrPayloadBuilder();

  /// Builds a ZATCA-style TLV/base64 payload from InvoiceDocument fields.
  ///
  /// This covers the common tags 1-5 only: seller, VAT number, timestamp,
  /// total, and VAT total. Cryptographic Phase 2 fields are intentionally not
  /// claimed here.
  String build(InvoiceDocument document) {
    final sellerTax =
        document.seller.taxNumber ?? document.branch.taxNumber ?? '';
    return base64Encode([
      ..._tlv(1, document.seller.name),
      ..._tlv(2, sellerTax),
      ..._tlv(3, document.invoiceDateTime.toUtc().toIso8601String()),
      ..._tlv(4, document.totals.netTotal.toStringAsFixed(2)),
      ..._tlv(5, document.totals.taxTotal.toStringAsFixed(2)),
    ]);
  }

  List<int> _tlv(int tag, String value) {
    final bytes = utf8.encode(value);
    if (bytes.length > 255) {
      throw ArgumentError('QR value is too long for tag $tag.');
    }
    return [tag, bytes.length, ...bytes];
  }
}
