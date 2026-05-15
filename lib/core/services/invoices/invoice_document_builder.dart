// core/services/invoices/invoice_document_builder.dart
// WHY: Builds a frozen InvoiceDocument from persisted Sale data.
// Reads from SalesDao, archives via InvoiceArchiveRepository.

import 'package:holol_POS/core/l10n/app_localizations.dart';
import 'package:holol_POS/core/persistence/daos/sales_dao.dart';
import 'package:holol_POS/core/persistence/database.dart'
    show Sale, SaleTaxSummaryCompanion;
import 'package:holol_POS/core/services/formatters/pos_formatters.dart';
import 'package:holol_POS/core/services/invoices/invoice_archive_repository.dart';
import 'package:holol_POS/core/services/invoices/invoice_audit_hasher.dart';
import 'package:holol_POS/core/services/invoices/invoice_document.dart';
import 'package:holol_POS/core/services/invoices/invoice_validation_service.dart';
import 'package:holol_POS/core/services/invoices/qr_payload_builder.dart';
import 'package:holol_POS/features/sales/domain/models/sale_inputs.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/core/persistence/daos/dao_shared.dart';
import 'package:holol_POS/shared/refactor/pos_business_rules.dart';

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
      arabicPrintNotice = 'تتم طباعة العربية كصورة Raster لضمان وضوح النص.';
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
    if (archived != null) {
      return _withOperationalLabels(archived, labels);
    }
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
    if (archived != null) {
      return _withOperationalLabels(archived, labels);
    }

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

    final syncStatusLabel = await _syncStatusLabel(
      sale.id,
      saleType: sale.type,
    );

    var document = InvoiceDocument(
      saleId: sale.id,
      localInvoiceNo: sale.localSaleNo,
      invoiceDateTime: sale.completedAt ?? sale.createdAt,
      invoiceTypeLabel: labels.invoiceTypeSales,
      statusCode: sale.status,
      statusLabel: PosFormatters.saleStatusLabel(sale.status),
      syncStatusLabel: syncStatusLabel,
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
        name: DaoText.clean(sale.cashierNameSnapshot) ?? sale.cashierId,
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

  Future<InvoiceDocument> buildFromCheckoutSnapshot({
    required String saleId,
    required String localInvoiceNo,
    required DateTime invoiceDateTime,
    required String statusCode,
    required String syncStatusCode,
    required String terminalId,
    required String? machineNo,
    required String? branchNo,
    required String? branchYear,
    required String? storeId,
    required String? priceLevelId,
    required bool useTax,
    required String cashierId,
    required String? cashierName,
    required String? customerId,
    required String? customerName,
    required String? customerTaxNumber,
    required List<SaleLineInput> lines,
    required PosCheckoutQuote quote,
    required List<SalePaymentInput> payments,
    required double paidTotal,
    required double remainingTotal,
    required double changeTotal,
    required List<SaleTaxSummaryCompanion> taxes,
    String? notes,
    InvoiceDocumentLabels labels = const InvoiceDocumentLabels.ar(),
  }) async {
    final branch = await _loadBranchFromContext(
      terminalId: terminalId,
      branchNo: branchNo,
      branchYear: branchYear,
    );
    final seller = _sellerFromBranch(branch);

    final invoiceLines = <InvoiceLineDocument>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final priced = quote.lines[i];
      invoiceLines.add(
        InvoiceLineDocument(
          itemId: line.itemId,
          itemName: line.itemName,
          unitId: line.unitId,
          unitName: DaoText.clean(line.unitName),
          unitSize: line.unitSize,
          barcode: DaoText.clean(line.barcode),
          quantity: line.quantity,
          unitPrice: line.unitPrice,
          lineSubtotal: priced.grossAmount,
          discountType: line.discountType?.code,
          discountValue: line.discountValue,
          discountAmount: priced.discountAmount,
          taxRate: line.taxRate,
          taxAmount: priced.taxAmount,
          lineTotal: priced.lineTotal,
          allowDiscount: line.allowDiscount,
          priceOverridden: false,
          storeId: DaoText.clean(storeId),
          priceLevelId: DaoText.clean(priceLevelId),
          display: InvoiceLineDisplay(
            quantity: PosFormatters.quantity(line.quantity),
            unitPrice: PosFormatters.amount(line.unitPrice),
            lineSubtotal: PosFormatters.amount(priced.grossAmount),
            discountAmount: PosFormatters.amount(priced.discountAmount),
            taxRate: PosFormatters.percent(line.taxRate),
            taxAmount: PosFormatters.amount(priced.taxAmount),
            lineTotal: PosFormatters.amount(priced.lineTotal),
          ),
        ),
      );
    }

    final invoiceTaxes = taxes.map((tax) {
      final rate = tax.taxRate.value;
      final taxableAmount = tax.taxableAmount.value;
      final taxAmount = tax.taxAmount.value;
      return InvoiceTaxDocument(
        taxRate: rate,
        taxableAmount: taxableAmount,
        taxAmount: taxAmount,
        displayRate: PosFormatters.percent(rate),
        displayTaxableAmount: PosFormatters.amount(taxableAmount),
        displayTaxAmount: PosFormatters.amount(taxAmount),
      );
    }).toList();

    final invoicePayments = payments
        .map(PosInvoiceDocumentRules.fromPaymentInput)
        .toList(growable: false);

    var document = InvoiceDocument(
      saleId: saleId,
      localInvoiceNo: localInvoiceNo,
      invoiceDateTime: invoiceDateTime,
      invoiceTypeLabel: labels.invoiceTypeSales,
      statusCode: statusCode,
      statusLabel: PosFormatters.saleStatusLabel(statusCode),
      syncStatusLabel: PosFormatters.saleSyncStatusLabel(syncStatusCode),
      seller: seller,
      branch: branch,
      terminal: InvoiceTerminalInfo(
        terminalId: terminalId,
        machineNumber: machineNo,
        storeId: storeId,
        priceLevelId: priceLevelId,
        useTax: useTax,
      ),
      cashier: InvoiceCashierInfo(
        userId: cashierId,
        name: DaoText.clean(cashierName) ?? cashierId,
      ),
      customer: _customerFromValues(
        customerId,
        customerName,
        customerTaxNumber,
      ),
      lines: invoiceLines,
      taxSummary: invoiceTaxes,
      payments: invoicePayments,
      totals: InvoiceTotalsDocument(
        subtotal: quote.subtotal,
        discountTotal: quote.discountTotal,
        taxTotal: quote.taxTotal,
        netTotal: quote.grandTotal,
        paidTotal: paidTotal,
        remainingTotal: remainingTotal,
        changeAmount: changeTotal,
        displaySubtotal: PosFormatters.amount(quote.subtotal),
        displayDiscountTotal: PosFormatters.amount(quote.discountTotal),
        displayTaxTotal: PosFormatters.amount(quote.taxTotal),
        displayNetTotal: PosFormatters.amount(quote.grandTotal),
        displayPaidTotal: PosFormatters.amount(paidTotal),
        displayRemainingTotal: PosFormatters.amount(remainingTotal),
        displayChangeAmount: PosFormatters.amount(changeTotal),
      ),
      copyInfo: const InvoiceCopyInfo.original(),
      printStatusLabel: labels.printStatusPending,
      notes: notes,
      arabicPrintNotice: labels.arabicPrintNotice,
    );

    document = document.copyWith(qrPayload: _qrPayloadBuilder.build(document));
    final validation = _validationService.validate(document);
    final auditHash = _auditHasher.hash(document);
    return document.copyWith(
      auditHash: auditHash,
      validationStatus: validation.isValid ? 'valid' : 'invalid',
      validationMessage: validation.message,
    );
  }

  Future<InvoiceDocument> _withOperationalLabels(
    InvoiceDocument document,
    InvoiceDocumentLabels labels,
  ) async {
    return document.copyWith(
      printStatusLabel: await _printStatus(document.saleId, labels),
      syncStatusLabel: await _syncStatusLabel(document.saleId),
    );
  }

  Future<String> _syncStatusLabel(String saleId, {String? saleType}) async {
    final type = saleType ?? (await _salesDao.getById(saleId))?.type;
    final entityType = PosInvoiceDocumentRules.syncEntityTypeForSaleType(type);
    final status =
        await _salesDao.getEntityOutboxStatus(
          entityType: entityType,
          entityId: saleId,
        ) ??
        OutboxStatus.pending.code;

    return PosFormatters.saleSyncStatusLabel(status);
  }

  Future<InvoiceBranchInfo> _loadBranch(Sale sale) async {
    final branch = await _salesDao.getInvoiceBranch(sale);
    final name =
        DaoText.clean(branch?.commercialName) ??
        DaoText.clean(branch?.nameAr) ??
        DaoText.clean(branch?.name) ??
        sale.branchNo ??
        '';
    final address = [
      DaoText.clean(branch?.address),
      DaoText.clean(branch?.streetName),
      DaoText.clean(branch?.buildingNo),
      DaoText.clean(branch?.postalZone),
    ].whereType<String>().where((v) => v.isNotEmpty).join(' ');
    return InvoiceBranchInfo(
      id: sale.branchNo ?? '',
      name: name,
      taxNumber: DaoText.clean(branch?.taxNumber),
      commercialRegistration: DaoText.clean(branch?.commercialRegistrationNo),
      city: DaoText.clean(branch?.cityName),
      address: address.isEmpty ? null : address,
      branchNumber: sale.branchNo ?? DaoText.clean(branch?.branchNo),
      branchYear: sale.branchYear ?? DaoText.clean(branch?.branchYear),
    );
  }

  Future<InvoiceBranchInfo> _loadBranchFromContext({
    required String terminalId,
    required String? branchNo,
    required String? branchYear,
  }) async {
    final branch = await _salesDao.getInvoiceBranchByContext(
      terminalId: terminalId,
      branchNo: branchNo,
    );
    final name =
        DaoText.clean(branch?.commercialName) ??
        DaoText.clean(branch?.nameAr) ??
        DaoText.clean(branch?.name) ??
        branchNo ??
        terminalId;
    final address = [
      DaoText.clean(branch?.address),
      DaoText.clean(branch?.streetName),
      DaoText.clean(branch?.buildingNo),
      DaoText.clean(branch?.postalZone),
    ].whereType<String>().where((v) => v.isNotEmpty).join(' ');
    return InvoiceBranchInfo(
      id: branchNo ?? '',
      name: name,
      taxNumber: DaoText.clean(branch?.taxNumber),
      commercialRegistration: DaoText.clean(branch?.commercialRegistrationNo),
      city: DaoText.clean(branch?.cityName),
      address: address.isEmpty ? null : address,
      branchNumber: branchNo ?? DaoText.clean(branch?.branchNo),
      branchYear: branchYear ?? DaoText.clean(branch?.branchYear),
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
      final quantity = _quantityFromScaled(line.qtyScaled, line.qtyScale);
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
        unitName: DaoText.clean(line.unitNameSnapshot),
        unitSize: line.unitSize,
        barcode: DaoText.clean(line.barcode),
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
        priceOverridden: false,
        storeId: DaoText.clean(line.storeId),
        priceLevelId: DaoText.clean(line.priceLevelId),
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

  double _quantityFromScaled(int qtyScaled, int qtyScale) {
    final scale = qtyScale <= 0 ? 1 : qtyScale;
    return qtyScaled / scale;
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
    return rows
        .map(
          (row) => PosInvoiceDocumentRules.fromStoredPayment(
            saleId: saleId,
            payment: row.payment,
            method: row.method,
          ),
        )
        .toList(growable: false);
  }

  Future<String> _printStatus(
    String saleId,
    InvoiceDocumentLabels labels,
  ) async {
    final jobs = await _salesDao.getSalePrintJobs(saleId);
    if (jobs.isEmpty) return labels.printStatusNotPrinted;
    if (jobs.any(DaoPrintJobPolicy.isPrinted)) {
      return labels.printStatusPrinted;
    }
    if (jobs.any(DaoPrintJobPolicy.isFailed)) {
      return labels.printStatusFailed;
    }
    return labels.printStatusPending;
  }

  InvoiceCustomerInfo? _customer(Sale sale) {
    final name = DaoText.clean(sale.customerNameSnapshot);
    if (name == null && sale.customerId == null) return null;
    return InvoiceCustomerInfo(
      id: sale.customerId,
      name: name ?? sale.customerId ?? '',
      taxNumber: DaoText.clean(sale.customerTaxNumberSnapshot),
    );
  }

  InvoiceCustomerInfo? _customerFromValues(
    String? id,
    String? name,
    String? taxNumber,
  ) {
    final cleanName = DaoText.clean(name);
    final cleanId = DaoText.clean(id);
    if (cleanName == null && cleanId == null) return null;
    return InvoiceCustomerInfo(
      id: cleanId,
      name: cleanName ?? cleanId ?? '',
      taxNumber: DaoText.clean(taxNumber),
    );
  }
}
