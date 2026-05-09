class SalesHistoryFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? invoiceNo;
  final String? cashierId;
  final String? paymentMethodCode;
  final int limit;

  const SalesHistoryFilter({
    this.startDate,
    this.endDate,
    this.invoiceNo,
    this.cashierId,
    this.paymentMethodCode,
    this.limit = 100,
  });
}

class SaleSummary {
  final String id;
  final String localSaleNo;
  final String status;
  final double grandTotal;
  final DateTime createdAt;
  final String cashierId;
  final String? paymentMethodLabel;
  final String productSummary;

  const SaleSummary({
    required this.id,
    required this.localSaleNo,
    required this.status,
    required this.grandTotal,
    required this.createdAt,
    required this.cashierId,
    this.paymentMethodLabel,
    this.productSummary = '',
  });
}
