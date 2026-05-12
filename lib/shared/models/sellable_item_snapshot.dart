class SellableItemSnapshot {
  final String itemId;
  final String unitId;
  final String itemName;
  final String unitName;
  final String? barcode;
  final double unitPrice;
  final double taxRate;
  final bool allowDiscount;

  const SellableItemSnapshot({
    required this.itemId,
    required this.unitId,
    required this.itemName,
    required this.unitName,
    this.barcode,
    required this.unitPrice,
    this.taxRate = 0.0,
    this.allowDiscount = false,
  });
}
