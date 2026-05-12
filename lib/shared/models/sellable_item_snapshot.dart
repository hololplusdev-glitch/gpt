class SellableItemSnapshot {
  final String itemId;
  final String unitId;
  final String itemName;
  final String unitName;
  final double? unitSize;
  final String? barcode;
  final double unitPrice;
  final double taxRate;
  final bool allowDiscount;
  final bool useQtyFraction;

  const SellableItemSnapshot({
    required this.itemId,
    required this.unitId,
    required this.itemName,
    required this.unitName,
    this.unitSize,
    this.barcode,
    required this.unitPrice,
    this.taxRate = 0.0,
    this.allowDiscount = false,
    this.useQtyFraction = false,
  });
}
