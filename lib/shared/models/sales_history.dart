class SaleSummary {
  final String id;
  final String localSaleNo;
  final String type;
  final String status;
  final double grandTotal;
  final DateTime createdAt;
  final String cashierId;
  final String? paymentMethodLabel;
  final String productSummary;

  const SaleSummary({
    required this.id,
    required this.localSaleNo,
    required this.type,
    required this.status,
    required this.grandTotal,
    required this.createdAt,
    required this.cashierId,
    this.paymentMethodLabel,
    this.productSummary = '',
  });
}
