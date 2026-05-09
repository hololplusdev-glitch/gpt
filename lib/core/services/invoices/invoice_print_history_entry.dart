class InvoicePrintHistoryEntry {
  final String id;
  final String saleId;
  final String invoiceNo;
  final String? printJobId;
  final String? printerProfileId;
  final String? printerName;
  final String? printerRole;
  final String documentType;
  final bool isReprint;
  final int copyNumber;
  final String? reprintReason;
  final String? printedBy;
  final String status;
  final String? failureReason;
  final String? payloadHash;
  final DateTime createdAt;
  final DateTime? printedAt;

  const InvoicePrintHistoryEntry({
    required this.id,
    required this.saleId,
    required this.invoiceNo,
    this.printJobId,
    this.printerProfileId,
    this.printerName,
    this.printerRole,
    required this.documentType,
    required this.isReprint,
    required this.copyNumber,
    this.reprintReason,
    this.printedBy,
    required this.status,
    this.failureReason,
    this.payloadHash,
    required this.createdAt,
    this.printedAt,
  });
}
