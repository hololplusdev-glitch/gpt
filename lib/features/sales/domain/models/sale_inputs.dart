import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/core/services/pricing/pricing_engine.dart';

class SaleLineInput {
  final String itemId;
  final String unitId;
  final String itemName;
  final String unitName;
  final double? unitSize;
  final String? barcode;
  final double quantity;
  final double unitPrice;
  final double taxRate;
  final DiscountType? discountType;
  final double? discountValue;
  final double discountAmount;
  final bool isPriceOverridden;
  final bool allowDiscount;
  final String priceSource;
  final String? notes;

  const SaleLineInput({
    required this.itemId,
    required this.unitId,
    required this.itemName,
    required this.unitName,
    this.unitSize,
    this.barcode,
    required this.quantity,
    required this.unitPrice,
    this.taxRate = 0.0,
    this.discountType,
    this.discountValue,
    this.discountAmount = 0.0,
    this.isPriceOverridden = false,
    this.allowDiscount = false,
    required this.priceSource,
    this.notes,
  });

  Map<String, dynamic> toHeldOrderSnapshotJson() => {
    'itemId': itemId,
    'unitId': unitId,
    'itemName': itemName,
    'unitName': unitName,
    'unitSize': unitSize,
    'barcode': barcode,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'taxRate': taxRate,
    'discountType': discountType?.code,
    'discountValue': discountValue,
    'discountAmount': discountAmount,
    'isPriceOverridden': isPriceOverridden,
    'allowDiscount': allowDiscount,
    'priceSource': priceSource,
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
      discountAmount: discountAmount,
      taxRate: taxRate,
    );
  }
}

extension SaleLineInputListPricingMapper on Iterable<SaleLineInput> {
  List<PricingLineInput> toPricingLineInputs() {
    return map((line) => line.toPricingLineInput()).toList();
  }
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
