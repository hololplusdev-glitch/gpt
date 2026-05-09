import 'package:pos_flutter/core/errors/app_exception.dart';
import 'package:pos_flutter/shared/models/enums.dart';

class PricingEngine {
  const PricingEngine();

  CheckoutQuote calculateQuote({
    required List<PricingLineInput> lines,
    required double taxRate,
    required bool useTax,
    required bool priceIncludesTax,
    PricingDiscountInput? invoiceDiscount,
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
        discountAmount: line.discountAmount,
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

    var invoiceDiscountAmount = 0.0;
    if (invoiceDiscount != null) {
      final discountBase = roundAmount(subtotal - lineDiscountTotal);
      invoiceDiscountAmount = switch (invoiceDiscount.type) {
        DiscountType.percentage => roundAmount(
          discountBase * invoiceDiscount.value / 100,
        ),
        DiscountType.fixed => roundAmount(invoiceDiscount.value),
      };
      if (invoiceDiscountAmount < 0 || invoiceDiscountAmount > lineTotalSum) {
        throw const PricingException('Invalid invoice discount amount.');
      }
    }

    final discountTotal = roundAmount(
      lineDiscountTotal + invoiceDiscountAmount,
    );
    final grandTotal = roundAmount(lineTotalSum - invoiceDiscountAmount);

    return CheckoutQuote(
      lines: pricedLines,
      subtotal: subtotal,
      lineDiscountTotal: lineDiscountTotal,
      invoiceDiscountAmount: invoiceDiscountAmount,
      discountTotal: discountTotal,
      taxTotal: taxTotal,
      grandTotal: grandTotal,
      roundingDelta: 0.0,
    );
  }

  PricedLine calculateLine({
    String? itemId,
    String? unitId,
    required double unitPrice,
    required double quantity,
    required double discountAmount,
    required double taxRate,
    required bool priceIncludesTax,
  }) {
    final grossAmount = roundAmount(unitPrice * quantity);
    final discountedAmount = roundAmount(grossAmount - discountAmount);
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
      discountAmount: roundAmount(discountAmount),
      taxableAmount: taxableAmount,
      taxAmount: taxAmount,
      lineTotal: lineTotal,
    );
  }

  static double roundAmount(double value) =>
      double.parse(value.toStringAsFixed(2));
}

class PricingLineInput {
  final String? itemId;
  final String? unitId;
  final double unitPrice;
  final double quantity;
  final double discountAmount;
  final double? taxRate;

  const PricingLineInput({
    this.itemId,
    this.unitId,
    required this.unitPrice,
    required this.quantity,
    this.discountAmount = 0.0,
    this.taxRate,
  });
}

class PricingDiscountInput {
  final DiscountType type;
  final double value;

  const PricingDiscountInput({required this.type, required this.value});
}

class CheckoutQuote {
  final List<PricedLine> lines;
  final double subtotal;
  final double lineDiscountTotal;
  final double invoiceDiscountAmount;
  final double discountTotal;
  final double taxTotal;
  final double grandTotal;
  final double roundingDelta;

  const CheckoutQuote({
    required this.lines,
    required this.subtotal,
    required this.lineDiscountTotal,
    required this.invoiceDiscountAmount,
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
