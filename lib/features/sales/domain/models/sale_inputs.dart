import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/core/services/pricing/pricing_engine.dart';

class SaleLineInput {
  final String itemId;
  final String unitId;
  final String itemName;
  final String unitName;
  final double? unitSize;
  final String? barcode;
  final bool useQtyFraction;
  final double quantity;
  final double unitPrice;
  final double taxRate;
  final DiscountType? discountType;
  final double? discountValue;
  final bool allowDiscount;
  final String? notes;

  const SaleLineInput({
    required this.itemId,
    required this.unitId,
    required this.itemName,
    required this.unitName,
    this.unitSize,
    this.barcode,
    this.useQtyFraction = false,
    required this.quantity,
    required this.unitPrice,
    this.taxRate = 0.0,
    this.discountType,
    this.discountValue,
    this.allowDiscount = false,
    this.notes,
  });

  Map<String, dynamic> toHeldOrderSnapshotJson() => {
    'itemId': itemId,
    'unitId': unitId,
    'itemName': itemName,
    'unitName': unitName,
    'unitSize': unitSize,
    'barcode': barcode,
    'useQtyFraction': useQtyFraction,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'taxRate': taxRate,
    'discountType': discountType?.code,
    'discountValue': discountValue,
    'allowDiscount': allowDiscount,
    'notes': notes,
  };
}

extension SaleLineInputPricingMapper on SaleLineInput {
  PricingLineInput toPricingLineInput() {
    return PricingLineInput(
      itemId: itemId,
      unitId: unitId,
      unitPrice: unitPrice,
      quantity: quantity,
      discountType: discountType,
      discountValue: discountValue,
      allowDiscount: allowDiscount,
      taxRate: taxRate,
    );
  }
}

extension SaleLineInputListPricingMapper on Iterable<SaleLineInput> {
  List<PricingLineInput> toPricingLineInputs() {
    return map((line) => line.toPricingLineInput()).toList();
  }
}

enum SaleTenderKind {
  cash,
  network,
  credit,
}

class SalePaymentIntent {
  final SaleTenderKind kind;

  /// Amount assigned to this payment line.
  final double amount;

  /// Cash tendered amount. Only cash uses this for change calculation.
  final double? tenderedAmount;

  /// Optional manual/reference number.
  final String reference;

  const SalePaymentIntent({
    required this.kind,
    required this.amount,
    this.tenderedAmount,
    this.reference = '',
  });
}

class SalePaymentInput {
  final String paymentMethodId;
  final String paymentMethodCode;
  final String? paymentMethodName;
  final PaymentMethodType paymentMethodType;
  final bool requiresReference;
  final double amount;
  final double? cashTendered;
  final double? changeGiven;
  final String? referenceNo;
  final String? bankId;
  final String? cardTypeId;
  final String? terminalRef;
  final String? authCode;
  final String? rrn;
  final String? cardScheme;
  final String? cardLast4;

  const SalePaymentInput({
    required this.paymentMethodId,
    required this.paymentMethodCode,
    this.paymentMethodName,
    required this.paymentMethodType,
    this.requiresReference = false,
    required this.amount,
    this.cashTendered,
    this.changeGiven,
    this.referenceNo,
    this.bankId,
    this.cardTypeId,
    this.terminalRef,
    this.authCode,
    this.rrn,
    this.cardScheme,
    this.cardLast4,
  });

  PaymentMethodType get resolvedType => paymentMethodType;

  bool get hasReference =>
      (referenceNo?.isNotEmpty ?? false) ||
      (terminalRef?.isNotEmpty ?? false) ||
      (authCode?.isNotEmpty ?? false) ||
      (rrn?.isNotEmpty ?? false);

  bool get hasTerminalApproval =>
      (terminalRef?.isNotEmpty ?? false) ||
      (authCode?.isNotEmpty ?? false) ||
      (rrn?.isNotEmpty ?? false);
}
