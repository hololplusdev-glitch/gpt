import 'dart:convert';

class InvoiceDocument {
  final int schemaVersion;
  final String saleId;
  final String localInvoiceNo;
  final DateTime invoiceDateTime;
  final String invoiceTypeLabel;
  final String statusCode;
  final String statusLabel;
  final String syncStatusLabel;
  final InvoiceSellerInfo seller;
  final InvoiceBranchInfo branch;
  final InvoiceTerminalInfo terminal;
  final InvoiceCashierInfo cashier;
  final InvoiceCustomerInfo? customer;
  final List<InvoiceLineDocument> lines;
  final List<InvoiceTaxDocument> taxSummary;
  final List<InvoicePaymentDocument> payments;
  final InvoiceTotalsDocument totals;
  final InvoiceCopyInfo copyInfo;
  final String? printStatusLabel;
  final String? qrPayload;
  final String? auditHash;
  final String? validationStatus;
  final String? validationMessage;
  final String? notes;
  final String? arabicPrintNotice;

  const InvoiceDocument({
    this.schemaVersion = 1,
    required this.saleId,
    required this.localInvoiceNo,
    required this.invoiceDateTime,
    required this.invoiceTypeLabel,
    required this.statusCode,
    required this.statusLabel,
    required this.syncStatusLabel,
    required this.seller,
    required this.branch,
    required this.terminal,
    required this.cashier,
    required this.customer,
    required this.lines,
    required this.taxSummary,
    required this.payments,
    required this.totals,
    this.copyInfo = const InvoiceCopyInfo.original(),
    this.printStatusLabel,
    this.qrPayload,
    this.auditHash,
    this.validationStatus,
    this.validationMessage,
    this.notes,
    this.arabicPrintNotice,
  });

  bool get isCopy => copyInfo.isCopy;

  InvoiceDocument copyWith({
    int? schemaVersion,
    String? saleId,
    String? localInvoiceNo,
    DateTime? invoiceDateTime,
    String? invoiceTypeLabel,
    String? statusCode,
    String? statusLabel,
    String? syncStatusLabel,
    InvoiceSellerInfo? seller,
    InvoiceBranchInfo? branch,
    InvoiceTerminalInfo? terminal,
    InvoiceCashierInfo? cashier,
    InvoiceCustomerInfo? customer,
    List<InvoiceLineDocument>? lines,
    List<InvoiceTaxDocument>? taxSummary,
    List<InvoicePaymentDocument>? payments,
    InvoiceTotalsDocument? totals,
    InvoiceCopyInfo? copyInfo,
    String? printStatusLabel,
    String? qrPayload,
    String? auditHash,
    String? validationStatus,
    String? validationMessage,
    String? notes,
    String? arabicPrintNotice,
  }) {
    return InvoiceDocument(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      saleId: saleId ?? this.saleId,
      localInvoiceNo: localInvoiceNo ?? this.localInvoiceNo,
      invoiceDateTime: invoiceDateTime ?? this.invoiceDateTime,
      invoiceTypeLabel: invoiceTypeLabel ?? this.invoiceTypeLabel,
      statusCode: statusCode ?? this.statusCode,
      statusLabel: statusLabel ?? this.statusLabel,
      syncStatusLabel: syncStatusLabel ?? this.syncStatusLabel,
      seller: seller ?? this.seller,
      branch: branch ?? this.branch,
      terminal: terminal ?? this.terminal,
      cashier: cashier ?? this.cashier,
      customer: customer ?? this.customer,
      lines: lines ?? this.lines,
      taxSummary: taxSummary ?? this.taxSummary,
      payments: payments ?? this.payments,
      totals: totals ?? this.totals,
      copyInfo: copyInfo ?? this.copyInfo,
      printStatusLabel: printStatusLabel ?? this.printStatusLabel,
      qrPayload: qrPayload ?? this.qrPayload,
      auditHash: auditHash ?? this.auditHash,
      validationStatus: validationStatus ?? this.validationStatus,
      validationMessage: validationMessage ?? this.validationMessage,
      notes: notes ?? this.notes,
      arabicPrintNotice: arabicPrintNotice ?? this.arabicPrintNotice,
    );
  }

  InvoiceDocument copyWithCopyInfo(InvoiceCopyInfo copyInfo) {
    return copyWith(copyInfo: copyInfo);
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'saleId': saleId,
    'localInvoiceNo': localInvoiceNo,
    'invoiceDateTime': invoiceDateTime.toIso8601String(),
    'invoiceTypeLabel': invoiceTypeLabel,
    'statusCode': statusCode,
    'statusLabel': statusLabel,
    'syncStatusLabel': syncStatusLabel,
    'seller': seller.toJson(),
    'branch': branch.toJson(),
    'terminal': terminal.toJson(),
    'cashier': cashier.toJson(),
    'customer': customer?.toJson(),
    'lines': lines.map((line) => line.toJson()).toList(),
    'taxSummary': taxSummary.map((tax) => tax.toJson()).toList(),
    'payments': payments.map((payment) => payment.toJson()).toList(),
    'totals': totals.toJson(),
    'copyInfo': copyInfo.toJson(),
    'printStatusLabel': printStatusLabel,
    'qrPayload': qrPayload,
    'auditHash': auditHash,
    'validationStatus': validationStatus,
    'validationMessage': validationMessage,
    'notes': notes,
    'arabicPrintNotice': arabicPrintNotice,
  };

  String toJsonString() => jsonEncode(toJson());

  factory InvoiceDocument.fromJsonString(String source) {
    return InvoiceDocument.fromJson(jsonDecode(source) as Map<String, dynamic>);
  }

  factory InvoiceDocument.fromJson(Map<String, dynamic> json) {
    return InvoiceDocument(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      saleId: json['saleId'] as String,
      localInvoiceNo: json['localInvoiceNo'] as String,
      invoiceDateTime: DateTime.parse(json['invoiceDateTime'] as String),
      invoiceTypeLabel: json['invoiceTypeLabel'] as String? ?? 'Sales invoice',
      statusCode: json['statusCode'] as String? ?? '',
      statusLabel: json['statusLabel'] as String? ?? '',
      syncStatusLabel: json['syncStatusLabel'] as String? ?? '',
      seller: InvoiceSellerInfo.fromJson(
        json['seller'] as Map<String, dynamic>,
      ),
      branch: InvoiceBranchInfo.fromJson(
        json['branch'] as Map<String, dynamic>,
      ),
      terminal: InvoiceTerminalInfo.fromJson(
        json['terminal'] as Map<String, dynamic>,
      ),
      cashier: InvoiceCashierInfo.fromJson(
        json['cashier'] as Map<String, dynamic>,
      ),
      customer: json['customer'] == null
          ? null
          : InvoiceCustomerInfo.fromJson(
              json['customer'] as Map<String, dynamic>,
            ),
      lines: (json['lines'] as List<dynamic>)
          .map(
            (line) =>
                InvoiceLineDocument.fromJson(line as Map<String, dynamic>),
          )
          .toList(),
      taxSummary: (json['taxSummary'] as List<dynamic>? ?? const [])
          .map(
            (tax) => InvoiceTaxDocument.fromJson(tax as Map<String, dynamic>),
          )
          .toList(),
      payments: (json['payments'] as List<dynamic>)
          .map(
            (payment) => InvoicePaymentDocument.fromJson(
              payment as Map<String, dynamic>,
            ),
          )
          .toList(),
      totals: InvoiceTotalsDocument.fromJson(
        json['totals'] as Map<String, dynamic>,
      ),
      copyInfo: json['copyInfo'] == null
          ? const InvoiceCopyInfo.original()
          : InvoiceCopyInfo.fromJson(json['copyInfo'] as Map<String, dynamic>),
      printStatusLabel: json['printStatusLabel'] as String?,
      qrPayload: json['qrPayload'] as String?,
      auditHash: json['auditHash'] as String?,
      validationStatus: json['validationStatus'] as String?,
      validationMessage: json['validationMessage'] as String?,
      notes: json['notes'] as String?,
      arabicPrintNotice: json['arabicPrintNotice'] as String?,
    );
  }
}

class InvoiceSellerInfo {
  final String name;
  final String? taxNumber;
  final String? commercialRegistration;
  final String? address;
  final String? phone;

  const InvoiceSellerInfo({
    required this.name,
    this.taxNumber,
    this.commercialRegistration,
    this.address,
    this.phone,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'taxNumber': taxNumber,
    'commercialRegistration': commercialRegistration,
    'address': address,
    'phone': phone,
  };

  factory InvoiceSellerInfo.fromJson(Map<String, dynamic> json) {
    return InvoiceSellerInfo(
      name: json['name'] as String,
      taxNumber: json['taxNumber'] as String?,
      commercialRegistration: json['commercialRegistration'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
    );
  }
}

class InvoiceBranchInfo {
  final String id;
  final String name;
  final String? taxNumber;
  final String? commercialRegistration;
  final String? city;
  final String? address;
  final String? branchNumber;
  final String? branchYear;

  const InvoiceBranchInfo({
    required this.id,
    required this.name,
    this.taxNumber,
    this.commercialRegistration,
    this.city,
    this.address,
    this.branchNumber,
    this.branchYear,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'taxNumber': taxNumber,
    'commercialRegistration': commercialRegistration,
    'city': city,
    'address': address,
    'branchNumber': branchNumber,
    'branchYear': branchYear,
  };

  factory InvoiceBranchInfo.fromJson(Map<String, dynamic> json) {
    return InvoiceBranchInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      taxNumber: json['taxNumber'] as String?,
      commercialRegistration: json['commercialRegistration'] as String?,
      city: json['city'] as String?,
      address: json['address'] as String?,
      branchNumber: json['branchNumber'] as String?,
      branchYear: json['branchYear'] as String?,
    );
  }
}

class InvoiceTerminalInfo {
  final String terminalId;
  final String? machineNumber;
  final String? storeId;
  final String? priceLevelId;
  final bool useTax;

  const InvoiceTerminalInfo({
    required this.terminalId,
    this.machineNumber,
    this.storeId,
    this.priceLevelId,
    required this.useTax,
  });

  Map<String, dynamic> toJson() => {
    'terminalId': terminalId,
    'machineNumber': machineNumber,
    'storeId': storeId,
    'priceLevelId': priceLevelId,
    'useTax': useTax,
  };

  factory InvoiceTerminalInfo.fromJson(Map<String, dynamic> json) {
    return InvoiceTerminalInfo(
      terminalId: json['terminalId'] as String,
      machineNumber: json['machineNumber'] as String?,
      storeId: json['storeId'] as String?,
      priceLevelId: json['priceLevelId'] as String?,
      useTax: json['useTax'] as bool? ?? true,
    );
  }
}

class InvoiceCashierInfo {
  final String userId;
  final String name;

  const InvoiceCashierInfo({required this.userId, required this.name});

  Map<String, dynamic> toJson() => {'userId': userId, 'name': name};

  factory InvoiceCashierInfo.fromJson(Map<String, dynamic> json) {
    return InvoiceCashierInfo(
      userId: json['userId'] as String,
      name: json['name'] as String,
    );
  }
}

class InvoiceCustomerInfo {
  final String? id;
  final String name;
  final String? taxNumber;

  const InvoiceCustomerInfo({this.id, required this.name, this.taxNumber});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'taxNumber': taxNumber,
  };

  factory InvoiceCustomerInfo.fromJson(Map<String, dynamic> json) {
    return InvoiceCustomerInfo(
      id: json['id'] as String?,
      name: json['name'] as String,
      taxNumber: json['taxNumber'] as String?,
    );
  }
}

class InvoiceLineDocument {
  final String itemId;
  final String itemName;
  final String? unitId;
  final String? unitName;
  final double? unitSize;
  final String? barcode;
  final double quantity;
  final double unitPrice;
  final double lineSubtotal;
  final String? discountType;
  final double? discountValue;
  final double discountAmount;
  final double taxRate;
  final double taxAmount;
  final double lineTotal;
  final bool allowDiscount;
  final bool priceOverridden;
  final String? storeId;
  final String? priceLevelId;
  final InvoiceLineDisplay display;

  const InvoiceLineDocument({
    required this.itemId,
    required this.itemName,
    this.unitId,
    this.unitName,
    this.unitSize,
    this.barcode,
    required this.quantity,
    required this.unitPrice,
    required this.lineSubtotal,
    this.discountType,
    this.discountValue,
    required this.discountAmount,
    required this.taxRate,
    required this.taxAmount,
    required this.lineTotal,
    required this.allowDiscount,
    required this.priceOverridden,
    this.storeId,
    this.priceLevelId,
    required this.display,
  });

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'itemName': itemName,
    'unitId': unitId,
    'unitName': unitName,
    'unitSize': unitSize,
    'barcode': barcode,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'lineSubtotal': lineSubtotal,
    'discountType': discountType,
    'discountValue': discountValue,
    'discountAmount': discountAmount,
    'taxRate': taxRate,
    'taxAmount': taxAmount,
    'lineTotal': lineTotal,
    'allowDiscount': allowDiscount,
    'priceOverridden': priceOverridden,
    'storeId': storeId,
    'priceLevelId': priceLevelId,
    'display': display.toJson(),
  };

  factory InvoiceLineDocument.fromJson(Map<String, dynamic> json) {
    return InvoiceLineDocument(
      itemId: json['itemId'] as String,
      itemName: json['itemName'] as String,
      unitId: json['unitId'] as String?,
      unitName: json['unitName'] as String?,
      unitSize: (json['unitSize'] as num?)?.toDouble(),
      barcode: json['barcode'] as String?,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unitPrice'] as num).toDouble(),
      lineSubtotal: (json['lineSubtotal'] as num).toDouble(),
      discountType: json['discountType'] as String?,
      discountValue: (json['discountValue'] as num?)?.toDouble(),
      discountAmount: (json['discountAmount'] as num).toDouble(),
      taxRate: (json['taxRate'] as num).toDouble(),
      taxAmount: (json['taxAmount'] as num).toDouble(),
      lineTotal: (json['lineTotal'] as num).toDouble(),
      allowDiscount: json['allowDiscount'] as bool? ?? false,
      priceOverridden: json['priceOverridden'] as bool? ?? false,
      storeId: json['storeId'] as String?,
      priceLevelId: json['priceLevelId'] as String?,
      display: InvoiceLineDisplay.fromJson(
        json['display'] as Map<String, dynamic>,
      ),
    );
  }
}

class InvoiceLineDisplay {
  final String quantity;
  final String unitPrice;
  final String lineSubtotal;
  final String discountAmount;
  final String taxRate;
  final String taxAmount;
  final String lineTotal;

  const InvoiceLineDisplay({
    required this.quantity,
    required this.unitPrice,
    required this.lineSubtotal,
    required this.discountAmount,
    required this.taxRate,
    required this.taxAmount,
    required this.lineTotal,
  });

  Map<String, dynamic> toJson() => {
    'quantity': quantity,
    'unitPrice': unitPrice,
    'lineSubtotal': lineSubtotal,
    'discountAmount': discountAmount,
    'taxRate': taxRate,
    'taxAmount': taxAmount,
    'lineTotal': lineTotal,
  };

  factory InvoiceLineDisplay.fromJson(Map<String, dynamic> json) {
    return InvoiceLineDisplay(
      quantity: json['quantity'] as String,
      unitPrice: json['unitPrice'] as String,
      lineSubtotal: json['lineSubtotal'] as String,
      discountAmount: json['discountAmount'] as String,
      taxRate: json['taxRate'] as String,
      taxAmount: json['taxAmount'] as String,
      lineTotal: json['lineTotal'] as String,
    );
  }
}

class InvoiceTaxDocument {
  final double taxRate;
  final double taxableAmount;
  final double taxAmount;
  final String displayRate;
  final String displayTaxableAmount;
  final String displayTaxAmount;

  const InvoiceTaxDocument({
    required this.taxRate,
    required this.taxableAmount,
    required this.taxAmount,
    required this.displayRate,
    required this.displayTaxableAmount,
    required this.displayTaxAmount,
  });

  Map<String, dynamic> toJson() => {
    'taxRate': taxRate,
    'taxableAmount': taxableAmount,
    'taxAmount': taxAmount,
    'displayRate': displayRate,
    'displayTaxableAmount': displayTaxableAmount,
    'displayTaxAmount': displayTaxAmount,
  };

  factory InvoiceTaxDocument.fromJson(Map<String, dynamic> json) {
    return InvoiceTaxDocument(
      taxRate: (json['taxRate'] as num).toDouble(),
      taxableAmount: (json['taxableAmount'] as num).toDouble(),
      taxAmount: (json['taxAmount'] as num).toDouble(),
      displayRate: json['displayRate'] as String,
      displayTaxableAmount: json['displayTaxableAmount'] as String,
      displayTaxAmount: json['displayTaxAmount'] as String,
    );
  }
}

class InvoicePaymentDocument {
  final String paymentMethodId;
  final String paymentMethodCode;
  final String methodName;
  final String? methodType;
  final double amount;
  final double? cashTendered;
  final double? changeGiven;
  final String? referenceNo;
  final String? bankId;
  final String? cardTypeId;
  final bool manualRecord;
  final String displayMethod;
  final String displayAmount;

  const InvoicePaymentDocument({
    required this.paymentMethodId,
    required this.paymentMethodCode,
    required this.methodName,
    this.methodType,
    required this.amount,
    this.cashTendered,
    this.changeGiven,
    this.referenceNo,
    this.bankId,
    this.cardTypeId,
    required this.manualRecord,
    required this.displayMethod,
    required this.displayAmount,
  });

  Map<String, dynamic> toJson() => {
    'paymentMethodId': paymentMethodId,
    'paymentMethodCode': paymentMethodCode,
    'methodName': methodName,
    'methodType': methodType,
    'amount': amount,
    'cashTendered': cashTendered,
    'changeGiven': changeGiven,
    'referenceNo': referenceNo,
    'bankId': bankId,
    'cardTypeId': cardTypeId,
    'manualRecord': manualRecord,
    'displayMethod': displayMethod,
    'displayAmount': displayAmount,
  };

  factory InvoicePaymentDocument.fromJson(Map<String, dynamic> json) {
    return InvoicePaymentDocument(
      paymentMethodId: json['paymentMethodId'] as String,
      paymentMethodCode: json['paymentMethodCode'] as String,
      methodName: json['methodName'] as String,
      methodType: json['methodType'] as String?,
      amount: (json['amount'] as num).toDouble(),
      cashTendered: (json['cashTendered'] as num?)?.toDouble(),
      changeGiven: (json['changeGiven'] as num?)?.toDouble(),
      referenceNo: json['referenceNo'] as String?,
      bankId: json['bankId'] as String?,
      cardTypeId: json['cardTypeId'] as String?,
      manualRecord: json['manualRecord'] as bool? ?? false,
      displayMethod: json['displayMethod'] as String,
      displayAmount: json['displayAmount'] as String,
    );
  }
}

class InvoiceTotalsDocument {
  final double subtotal;
  final double discountTotal;
  final double taxTotal;
  final double netTotal;
  final double paidTotal;
  final double remainingTotal;
  final double changeAmount;
  final String displaySubtotal;
  final String displayDiscountTotal;
  final String displayTaxTotal;
  final String displayNetTotal;
  final String displayPaidTotal;
  final String displayRemainingTotal;
  final String displayChangeAmount;

  const InvoiceTotalsDocument({
    required this.subtotal,
    required this.discountTotal,
    required this.taxTotal,
    required this.netTotal,
    required this.paidTotal,
    required this.remainingTotal,
    required this.changeAmount,
    required this.displaySubtotal,
    required this.displayDiscountTotal,
    required this.displayTaxTotal,
    required this.displayNetTotal,
    required this.displayPaidTotal,
    required this.displayRemainingTotal,
    required this.displayChangeAmount,
  });

  Map<String, dynamic> toJson() => {
    'subtotal': subtotal,
    'discountTotal': discountTotal,
    'taxTotal': taxTotal,
    'netTotal': netTotal,
    'paidTotal': paidTotal,
    'remainingTotal': remainingTotal,
    'changeAmount': changeAmount,
    'displaySubtotal': displaySubtotal,
    'displayDiscountTotal': displayDiscountTotal,
    'displayTaxTotal': displayTaxTotal,
    'displayNetTotal': displayNetTotal,
    'displayPaidTotal': displayPaidTotal,
    'displayRemainingTotal': displayRemainingTotal,
    'displayChangeAmount': displayChangeAmount,
  };

  factory InvoiceTotalsDocument.fromJson(Map<String, dynamic> json) {
    return InvoiceTotalsDocument(
      subtotal: (json['subtotal'] as num).toDouble(),
      discountTotal: (json['discountTotal'] as num).toDouble(),
      taxTotal: (json['taxTotal'] as num).toDouble(),
      netTotal: (json['netTotal'] as num).toDouble(),
      paidTotal: (json['paidTotal'] as num).toDouble(),
      remainingTotal: (json['remainingTotal'] as num).toDouble(),
      changeAmount: (json['changeAmount'] as num).toDouble(),
      displaySubtotal: json['displaySubtotal'] as String,
      displayDiscountTotal: json['displayDiscountTotal'] as String,
      displayTaxTotal: json['displayTaxTotal'] as String,
      displayNetTotal: json['displayNetTotal'] as String,
      displayPaidTotal: json['displayPaidTotal'] as String,
      displayRemainingTotal: json['displayRemainingTotal'] as String,
      displayChangeAmount: json['displayChangeAmount'] as String,
    );
  }
}

class InvoiceCopyInfo {
  final bool isCopy;
  final int copyNumber;
  final String label;

  const InvoiceCopyInfo({
    required this.isCopy,
    required this.copyNumber,
    required this.label,
  });

  const InvoiceCopyInfo.original()
    : isCopy = false,
      copyNumber = 0,
      label = 'Original';

  factory InvoiceCopyInfo.reprint({required int copyNumber}) {
    return InvoiceCopyInfo(
      isCopy: true,
      copyNumber: copyNumber,
      label: 'Reprint / نسخة رقم $copyNumber',
    );
  }

  Map<String, dynamic> toJson() => {
    'isCopy': isCopy,
    'copyNumber': copyNumber,
    'label': label,
  };

  factory InvoiceCopyInfo.fromJson(Map<String, dynamic> json) {
    return InvoiceCopyInfo(
      isCopy: json['isCopy'] as bool? ?? false,
      copyNumber: json['copyNumber'] as int? ?? 0,
      label: json['label'] as String? ?? 'Original',
    );
  }
}
