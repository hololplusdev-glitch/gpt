import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/shared/models/enums.dart';

class PricingEngine {
  const PricingEngine();

  CheckoutQuote calculateQuote({
    required List<PricingLineInput> lines,
    required double taxRate,
    required bool useTax,
    required bool priceIncludesTax,
  }) {
    if (lines.isEmpty) {
      throw const PricingException('No items to price.');
    }

    var subtotal = 0.0;
    var lineDiscountTotal = 0.0;
    var taxTotal = 0.0;
    var lineTotalSum = 0.0;
    final pricedLines = <PricedLine>[];

    for (final line in lines) {
      final pricedLine = calculateLine(
        itemId: line.itemId,
        unitId: line.unitId,
        unitPrice: line.unitPrice,
        quantity: line.quantity,
        discountType: line.discountType,
        discountValue: line.discountValue,
        allowDiscount: line.allowDiscount,
        taxRate: useTax ? (line.taxRate ?? taxRate) : 0.0,
        priceIncludesTax: priceIncludesTax,
      );

      subtotal = roundAmount(subtotal + pricedLine.grossAmount);
      lineDiscountTotal = roundAmount(
        lineDiscountTotal + pricedLine.discountAmount,
      );
      taxTotal = roundAmount(taxTotal + pricedLine.taxAmount);
      lineTotalSum = roundAmount(lineTotalSum + pricedLine.lineTotal);
      pricedLines.add(pricedLine);
    }

    return CheckoutQuote(
      lines: pricedLines,
      subtotal: subtotal,
      lineDiscountTotal: lineDiscountTotal,
      discountTotal: roundAmount(lineDiscountTotal),
      taxTotal: taxTotal,
      grandTotal: roundAmount(lineTotalSum),
      roundingDelta: 0.0,
    );
  }

  PricedLine calculateLine({
    String? itemId,
    String? unitId,
    required double unitPrice,
    required double quantity,
    DiscountType? discountType,
    double? discountValue,
    bool allowDiscount = true,
    required double taxRate,
    required bool priceIncludesTax,
  }) {
    if (quantity <= 0) {
      throw const PricingException('Quantity must be greater than zero.');
    }

    if (unitPrice < 0) {
      throw const PricingException('Unit price cannot be negative.');
    }

    if (taxRate < 0) {
      throw const PricingException('Tax rate cannot be negative.');
    }

    final grossAmount = roundAmount(unitPrice * quantity);
    final resolvedDiscountAmount = calculateDiscountAmount(
      grossAmount: grossAmount,
      discountType: discountType,
      discountValue: discountValue,
      allowDiscount: allowDiscount,
    );

    final discountedAmount = roundAmount(grossAmount - resolvedDiscountAmount);
    if (discountedAmount < 0) {
      throw const PricingException('Discount exceeds line gross amount.');
    }

    final taxableAmount = priceIncludesTax && taxRate > 0
        ? roundAmount(discountedAmount / (1 + taxRate / 100))
        : discountedAmount;

    final taxAmount = taxRate <= 0
        ? 0.0
        : priceIncludesTax
        ? roundAmount(discountedAmount - taxableAmount)
        : roundAmount(taxableAmount * taxRate / 100);

    final lineTotal = priceIncludesTax
        ? discountedAmount
        : roundAmount(taxableAmount + taxAmount);

    return PricedLine(
      itemId: itemId,
      unitId: unitId,
      grossAmount: grossAmount,
      discountAmount: resolvedDiscountAmount,
      taxableAmount: taxableAmount,
      taxAmount: taxAmount,
      lineTotal: lineTotal,
    );
  }

  double calculateDiscountAmount({
    required double grossAmount,
    DiscountType? discountType,
    double? discountValue,
    bool allowDiscount = true,
  }) {
    final value = discountValue ?? 0.0;

    if (value < 0) {
      throw const PricingException('Discount cannot be negative.');
    }

    if (discountType == null || value == 0) {
      return 0.0;
    }

    if (!allowDiscount) {
      throw const PricingException('Discount is not allowed for this item.');
    }

    final requestedAmount = switch (discountType) {
      DiscountType.percentage => grossAmount * (value / 100),
      DiscountType.fixed => value,
    };

    final amount = roundAmount(requestedAmount);

    if (amount > grossAmount) {
      throw const PricingException('Discount exceeds line gross amount.');
    }

    return amount;
  }

  static double roundAmount(double value) =>
      double.parse(value.toStringAsFixed(2));
}

class PricingLineInput {
  final String? itemId;
  final String? unitId;
  final double unitPrice;
  final double quantity;
  final DiscountType? discountType;
  final double? discountValue;
  final bool allowDiscount;
  final double? taxRate;

  const PricingLineInput({
    this.itemId,
    this.unitId,
    required this.unitPrice,
    required this.quantity,
    this.discountType,
    this.discountValue,
    this.allowDiscount = true,
    this.taxRate,
  });
}

class CheckoutQuote {
  final List<PricedLine> lines;
  final double subtotal;
  final double lineDiscountTotal;
  final double discountTotal;
  final double taxTotal;
  final double grandTotal;
  final double roundingDelta;

  const CheckoutQuote({
    required this.lines,
    required this.subtotal,
    required this.lineDiscountTotal,
    required this.discountTotal,
    required this.taxTotal,
    required this.grandTotal,
    required this.roundingDelta,
  });
}

class PricedLine {
  final String? itemId;
  final String? unitId;
  final double grossAmount;
  final double discountAmount;
  final double taxableAmount;
  final double taxAmount;
  final double lineTotal;

  const PricedLine({
    this.itemId,
    this.unitId,
    required this.grossAmount,
    required this.discountAmount,
    required this.taxableAmount,
    required this.taxAmount,
    required this.lineTotal,
  });
}

class PricingException extends BusinessException {
  const PricingException(super.message) : super(code: 'pricing_error');
}
