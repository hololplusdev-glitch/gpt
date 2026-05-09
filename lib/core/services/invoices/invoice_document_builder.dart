// core/services/invoices/invoice_document_builder.dart
// WHY: Builds a frozen InvoiceDocument from persisted Sale data.
// Reads from SalesDao, archives via InvoiceArchiveRepository.

import 'package:pos_flutter/core/l10n/app_localizations.dart';
import 'package:pos_flutter/core/persistence/daos/sales_dao.dart';
import 'package:pos_flutter/core/persistence/database.dart' show Sale;
import 'package:pos_flutter/core/services/formatters/pos_formatters.dart';
import 'package:pos_flutter/core/services/invoices/invoice_archive_repository.dart';
import 'package:pos_flutter/core/services/invoices/invoice_audit_hasher.dart';
import 'package:pos_flutter/core/services/invoices/invoice_document.dart';
import 'package:pos_flutter/core/services/invoices/invoice_validation_service.dart';
import 'package:pos_flutter/core/services/invoices/qr_payload_builder.dart';
import 'package:pos_flutter/core/services/payments/payment_method_resolver.dart';
import 'package:pos_flutter/shared/models/enums.dart';

class InvoiceDocumentLabels {
  final String invoiceTypeSales;
  final String printStatusNotPrinted;
  final String printStatusPrinted;
  final String printStatusFailed;
  final String printStatusPending;
  final String arabicPrintNotice;

  const InvoiceDocumentLabels({
    required this.invoiceTypeSales,
    required this.printStatusNotPrinted,
    required this.printStatusPrinted,
    required this.printStatusFailed,
    required this.printStatusPending,
    required this.arabicPrintNotice,
  });

  factory InvoiceDocumentLabels.fromL10n(AppLocalizations l10n) {
    return InvoiceDocumentLabels(
      invoiceTypeSales: l10n.invoiceTypeSales,
      printStatusNotPrinted: l10n.printStatusNotPrinted,
      printStatusPrinted: l10n.printStatusPrinted,
      printStatusFailed: l10n.printStatusFailed,
      printStatusPending: l10n.printStatusPending,
      arabicPrintNotice: l10n.arabicPrintNotice,
    );
  }

  const InvoiceDocumentLabels.ar()
    : invoiceTypeSales = 'فاتورة مبيعات',
      printStatusNotPrinted = 'غير مطبوعة',
      printStatusPrinted = 'تمت الطباعة',
      printStatusFailed = 'فشل الطباعة',
      printStatusPending = 'بانتظار الطباعة',
      arabicPrintNotice =
          'يعتمد دعم النص العربي في ESC/POS على صفحة الترميز في الطابعة.';
}

class InvoiceDocumentBuilder {
  final SalesDao _salesDao;
  final QrPayloadBuilder _qrPayloadBuilder;
  final InvoiceAuditHasher _auditHasher;
  final InvoiceValidationService _validationService;
  final InvoiceArchiveRepository _archiveRepository;

  InvoiceDocumentBuilder({
    required SalesDao salesDao,
    required InvoiceArchiveRepository archiveRepository,
    QrPayloadBuilder qrPayloadBuilder = const QrPayloadBuilder(),
    InvoiceAuditHasher auditHasher = const InvoiceAuditHasher(),
    InvoiceValidationService validationService =
        const InvoiceValidationService(),
  }) : _salesDao = salesDao,
       _qrPayloadBuilder = qrPayloadBuilder,
       _auditHasher = auditHasher,
       _validationService = validationService,
       _archiveRepository = archiveRepository;

  Future<InvoiceDocument> getOrCreateOriginal(
    String saleId, {
    InvoiceDocumentLabels labels = const InvoiceDocumentLabels.ar(),
  }) async {
    final archived = await _archiveRepository.loadOriginal(saleId);
    if (archived != null) return archived;
    return buildForSale(saleId, labels: labels);
  }

  /// Build an InvoiceDocument from a persisted sale.
  Future<InvoiceDocument> buildForSale(
    String saleId, {
    InvoiceCopyInfo copyInfo = const InvoiceCopyInfo.original(),
    InvoiceDocumentLabels labels = const InvoiceDocumentLabels.ar(),
  }) async {
    if (copyInfo.isCopy) {
      final original = await getOrCreateOriginal(saleId, labels: labels);
      return original.copyWith(copyInfo: copyInfo);
    }

    final archived = await _archiveRepository.loadOriginal(saleId);
    if (archived != null) return archived;

    final sale = await _salesDao.getInvoiceSale(saleId);
    if (sale == null) {
      throw StateError('Sale not found: $saleId');
    }

    final branch = await _loadBranch(sale);
    final seller = _sellerFromBranch(branch);
    final lines = await _loadLines(saleId);
    final taxes = await _loadTaxes(saleId);
    final payments = await _loadPayments(saleId);
    final printStatus = await _printStatus(saleId, labels);

    var document = InvoiceDocument(
      saleId: sale.id,
      localInvoiceNo: sale.localSaleNo,
      invoiceDateTime: sale.completedAt ?? sale.createdAt,
      invoiceTypeLabel: labels.invoiceTypeSales,
      statusCode: sale.status,
      statusLabel: PosFormatters.saleStatusLabel(sale.status),
      syncStatusLabel: PosFormatters.saleSyncStatusLabel(sale.syncStatus),
      seller: seller,
      branch: branch,
      terminal: InvoiceTerminalInfo(
        terminalId: sale.terminalId,
        machineNumber: sale.machineNo,
        storeId: sale.storeId,
        priceLevelId: sale.priceLevelId,
        useTax: sale.useTax ?? true,
      ),
      cashier: InvoiceCashierInfo(
        userId: sale.sourceUserId ?? sale.cashierId,
        name: _clean(sale.cashierNameSnapshot) ?? sale.cashierId,
      ),
      customer: _customer(sale),
      lines: lines,
      taxSummary: taxes,
      payments: payments,
      totals: InvoiceTotalsDocument(
        subtotal: sale.subtotal,
        discountTotal: sale.discountTotal,
        taxTotal: sale.taxTotal,
        netTotal: sale.grandTotal,
        paidTotal: sale.paidTotal,
        remainingTotal: sale.remainingTotal,
        changeAmount: sale.changeTotal,
        displaySubtotal: PosFormatters.amount(sale.subtotal),
        displayDiscountTotal: PosFormatters.amount(sale.discountTotal),
        displayTaxTotal: PosFormatters.amount(sale.taxTotal),
        displayNetTotal: PosFormatters.amount(sale.grandTotal),
        displayPaidTotal: PosFormatters.amount(sale.paidTotal),
        displayRemainingTotal: PosFormatters.amount(sale.remainingTotal),
        displayChangeAmount: PosFormatters.amount(sale.changeTotal),
      ),
      copyInfo: copyInfo,
      printStatusLabel: printStatus,
      notes: sale.notes,
      arabicPrintNotice: labels.arabicPrintNotice,
    );

    document = document.copyWith(qrPayload: _qrPayloadBuilder.build(document));

    // Add audit hash + validation
    final validation = _validationService.validate(document);
    final auditHash = _auditHasher.hash(document);
    document = document.copyWith(
      auditHash: auditHash,
      validationStatus: validation.isValid ? 'valid' : 'invalid',
      validationMessage: validation.message,
    );

    if (!document.copyInfo.isCopy) {
      await _archiveRepository.persistIfMissing(
        document: document,
        auditHash: auditHash,
        validation: validation,
      );
    }
    return document;
  }

  Future<InvoiceBranchInfo> _loadBranch(Sale sale) async {
    final branch = await _salesDao.getInvoiceBranch(sale);
    final name =
        _clean(branch?.commercialName) ??
        _clean(branch?.nameAr) ??
        _clean(branch?.name) ??
        sale.branchNo ??
        '';
    final address = [
      _clean(branch?.address),
      _clean(branch?.streetName),
      _clean(branch?.buildingNo),
      _clean(branch?.postalZone),
    ].whereType<String>().where((v) => v.isNotEmpty).join(' ');
    return InvoiceBranchInfo(
      id: sale.branchNo ?? '',
      name: name,
      taxNumber: _clean(branch?.taxNumber),
      commercialRegistration: _clean(branch?.commercialRegistrationNo),
      city: _clean(branch?.cityName),
      address: address.isEmpty ? null : address,
      branchNumber: sale.branchNo ?? _clean(branch?.branchNo),
      branchYear: sale.branchYear ?? _clean(branch?.branchYear),
    );
  }

  InvoiceSellerInfo _sellerFromBranch(InvoiceBranchInfo branch) {
    return InvoiceSellerInfo(
      name: branch.name,
      taxNumber: branch.taxNumber,
      commercialRegistration: branch.commercialRegistration,
      address: branch.address,
    );
  }

  Future<List<InvoiceLineDocument>> _loadLines(String saleId) async {
    final rows = await _salesDao.getInvoiceLines(saleId);
    return rows.map((line) {
      final quantity = line.qtyScaled.toDouble();
      final unitPrice = line.unitPrice;
      final grossAmount = line.grossAmount;
      final discountAmount = line.lineDiscountAmount;
      final taxRate = line.taxRate;
      final taxAmount = line.taxAmount;
      final lineTotal = line.lineTotal;
      return InvoiceLineDocument(
        itemId: line.itemId,
        itemName: line.itemNameSnapshot,
        unitId: line.unitId,
        unitName: _clean(line.unitNameSnapshot),
        unitSize: line.unitSize,
        barcode: _clean(line.barcode),
        quantity: quantity,
        unitPrice: unitPrice,
        lineSubtotal: grossAmount,
        discountType: line.lineDiscountType,
        discountValue: line.lineDiscountValue,
        discountAmount: discountAmount,
        taxRate: taxRate,
        taxAmount: taxAmount,
        lineTotal: lineTotal,
        allowDiscount: line.allowDiscountSnapshot ?? false,
        priceOverridden: line.overrideReason != null,
        storeId: _clean(line.storeId),
        priceLevelId: _clean(line.priceLevelId),
        display: InvoiceLineDisplay(
          quantity: PosFormatters.quantity(quantity),
          unitPrice: PosFormatters.amount(unitPrice),
          lineSubtotal: PosFormatters.amount(grossAmount),
          discountAmount: PosFormatters.amount(discountAmount),
          taxRate: PosFormatters.percent(taxRate),
          taxAmount: PosFormatters.amount(taxAmount),
          lineTotal: PosFormatters.amount(lineTotal),
        ),
      );
    }).toList();
  }

  Future<List<InvoiceTaxDocument>> _loadTaxes(String saleId) async {
    final rows = await _salesDao.getInvoiceTaxes(saleId);
    return rows
        .map(
          (tax) => InvoiceTaxDocument(
            taxRate: tax.taxRate,
            taxableAmount: tax.taxableAmount,
            taxAmount: tax.taxAmount,
            displayRate: PosFormatters.percent(tax.taxRate),
            displayTaxableAmount: PosFormatters.amount(tax.taxableAmount),
            displayTaxAmount: PosFormatters.amount(tax.taxAmount),
          ),
        )
        .toList();
  }

  Future<List<InvoicePaymentDocument>> _loadPayments(String saleId) async {
    final rows = await _salesDao.getInvoicePaymentsWithMethodInfo(saleId);
    return rows.map((row) {
      final payment = row.payment;
      final code = payment.methodCodeSnapshot;
      final type = PaymentMethodResolver.typeFromStored(
        methodCode: code,
        storedTypeCode: (payment.methodTypeSnapshot ?? row.method?.type)
            ?.toString(),
      );
      if (type == null) {
        throw StateError(
          'Unknown payment method type while building invoice for $saleId: $code',
        );
      }
      final manualRecord =
          payment.isManual || PaymentMethodResolver.isManual(type);
      final name = payment.methodNameSnapshot ?? row.method?.name ?? code;
      final amount = payment.amount;
      return InvoicePaymentDocument(
        paymentMethodId: payment.paymentMethodId,
        paymentMethodCode: code,
        methodName: name,
        methodType: type.code,
        amount: amount,
        cashTendered: payment.cashTendered,
        changeGiven: payment.changeGiven,
        referenceNo: _clean(payment.referenceNo),
        bankId: _clean(payment.bankId),
        cardTypeId: _clean(payment.cardTypeId),
        manualRecord: manualRecord,
        displayMethod: PaymentMethodResolver.describe(
          methodCode: code,
          methodName: name,
          type: type,
          manualRecord: manualRecord,
        ),
        displayAmount: PosFormatters.amount(amount),
      );
    }).toList();
  }

  Future<String> _printStatus(
    String saleId,
    InvoiceDocumentLabels labels,
  ) async {
    final jobs = await _salesDao.getSalePrintJobs(saleId);
    if (jobs.isEmpty) return labels.printStatusNotPrinted;
    if (jobs.any((job) => job.status == PrintJobStatus.printed.code)) {
      return labels.printStatusPrinted;
    }
    if (jobs.any((job) => job.status == PrintJobStatus.failed.code)) {
      return labels.printStatusFailed;
    }
    return labels.printStatusPending;
  }

  InvoiceCustomerInfo? _customer(Sale sale) {
    final name = _clean(sale.customerNameSnapshot);
    if (name == null && sale.customerId == null) return null;
    return InvoiceCustomerInfo(
      id: sale.customerId,
      name: name ?? sale.customerId ?? '',
      taxNumber: _clean(sale.customerTaxNumberSnapshot),
    );
  }

  String? _clean(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
