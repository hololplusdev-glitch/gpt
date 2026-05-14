import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/persistence/daos/active_pos_session_dao.dart';
import 'package:holol_POS/core/persistence/daos/sales_dao.dart';
import 'package:holol_POS/core/persistence/daos/shift_dao.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/core/services/invoice_number_service.dart';
import 'package:holol_POS/core/services/invoices/invoice_document_builder.dart';
import 'package:holol_POS/core/services/sync/outbox_event_factory.dart';
import 'package:holol_POS/core/services/time/clock.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/shared/models/sales_history.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
import 'package:uuid/uuid.dart';
import 'package:holol_POS/shared/refactor/pos_business_rules.dart';

/// Sales history/detail query owner plus post-sale correction commands.
/// Sale completion remains owned by SaleCheckout.
class SalesHistoryService {
  final SalesDao _salesDao;
  final ShiftDao _shiftDao;
  final InvoiceNumberService _invoiceNumberService;
  final InvoiceDocumentBuilder _invoiceDocumentBuilder;
  final OutboxEventFactory _outboxEventFactory;
  final ActivePosSession? _activeSession;
  final Clock _clock;

  const SalesHistoryService({
    required SalesDao salesDao,
    required ShiftDao shiftDao,
    required InvoiceNumberService invoiceNumberService,
    required InvoiceDocumentBuilder invoiceDocumentBuilder,
    required OutboxEventFactory outboxEventFactory,
    required ActivePosSession? activeSession,
    Clock clock = const SystemClock(),
  }) : _salesDao = salesDao,
       _shiftDao = shiftDao,
       _invoiceNumberService = invoiceNumberService,
       _invoiceDocumentBuilder = invoiceDocumentBuilder,
       _outboxEventFactory = outboxEventFactory,
       _activeSession = activeSession,
       _clock = clock;

  static const _uuid = Uuid();

  Future<List<Sale>> getTodaysSales() {
    return _salesDao.getSalesByDate(_clock.now());
  }

  Future<List<SaleSummary>> searchSalesHistory({
    String? query,
    int limit = 100,
  }) {
    return _salesDao.searchSalesHistory(query: query, limit: limit);
  }

  Future<SaleDetail?> getSaleDetail(String saleId) async {
    final sale = await _salesDao.getById(saleId);
    if (sale == null) return null;

    final items = await _salesDao.getSaleLines(saleId);
    final payments = await _salesDao.getSalePayments(saleId);

    return SaleDetail(sale: sale, items: items, payments: payments);
  }

  Future<void> voidSale(String saleId) async {
    final session = PosBusinessGuards.requireActiveSession(
      _activeSession,
      message: 'Select a cashier and POS machine first.',
      code: 'NO_ACTIVE_POS_SESSION',
    );
    final sale = await PosBusinessGuards.requireCompletedNormalSale(
      salesDao: _salesDao,
      saleId: saleId,
    );
    final now = _clock.now();

    if (await _salesDao.hasCompletedReturnForSale(sale.id)) {
      throw const BusinessException(
        'Sale with a completed return cannot be voided.',
        code: 'SALE_HAS_RETURN',
      );
    }

    await _salesDao.voidSaleEnvelope(
      saleId: sale.id,
      voidedAt: now,
      outboxEntry: _outboxEventFactory.saleVoided(
        saleId: sale.id,
        cashierId: session.activeUserId,
        cashierName: session.activeUserName,
        voidedAt: now,
      ),
      auditLogEntry: AuditLogCompanion.insert(
        id: 'AUD_${_uuid.v4()}',
        action: AuditAction.saleVoided.code,
        actorId: session.activeUserId,
        actorName: Value(session.activeUserName),
        targetType: Value(OutboxEntityType.sale.code),
        targetId: Value(sale.id),
        detailsJson: Value(
          jsonEncode({
            'invoiceNo': sale.localSaleNo,
            'grandTotal': sale.grandTotal,
          }),
        ),
        terminalId: session.activeMachineNo,
        createdAt: now,
      ),
    );
  }

  Future<String> returnSale(String saleId) async {
    final session = PosBusinessGuards.requireActiveSession(
      _activeSession,
      message: 'Select a cashier and POS machine first.',
      code: 'NO_ACTIVE_POS_SESSION',
    );
    final shift = await PosBusinessGuards.requireOpenShift(
      shiftDao: _shiftDao,
      session: session,
      message: 'Open a shift before creating a return.',
      code: 'NO_OPEN_SHIFT',
    );
    final original = await PosBusinessGuards.requireCompletedNormalSale(
      salesDao: _salesDao,
      saleId: saleId,
    );

    if (await _salesDao.hasCompletedReturnForSale(original.id)) {
      throw const BusinessException(
        'This sale has already been fully returned.',
        code: 'SALE_ALREADY_RETURNED',
      );
    }

    final now = _clock.now();
    final returnSaleId = 'RET_${_uuid.v4()}';
    final sequenceType = PosBusinessRules.sequenceType(
      session.returnInvoiceSeries,
      fallback: 'return',
    );
    final localInvoiceNo = await _invoiceNumberService.generateNext(
      branchNo: session.activeBranchNo,
      machineNo: session.activeMachineNo,
      sequenceType: sequenceType,
    );
    final idempotencyKey = 'return_${original.id}';

    final originalLines = await _salesDao.getSaleLines(original.id);
    final originalPayments = await _salesDao.getSalePayments(original.id);
    final originalTaxes = await _salesDao.getInvoiceTaxes(original.id);

    final header = SalesCompanion(
      id: Value(returnSaleId),
      localSaleNo: Value(localInvoiceNo),
      idempotencyKey: Value(idempotencyKey),
      type: Value(SaleType.returnSale.code),
      status: Value(SaleStatus.completed.code),
      branchNo: Value(session.activeBranchNo),
      branchYear: Value(session.activeBranchYear),
      terminalId: Value(session.activeMachineNo),
      machineNo: Value(session.activeMachineNo),
      shiftId: Value(shift.id),
      cashierId: Value(session.activeUserId),
      sourceUserId: Value(session.activeUserId),
      cashierNameSnapshot: Value(session.activeUserName),
      customerId: Value(original.customerId),
      customerNameSnapshot: Value(original.customerNameSnapshot),
      customerTaxNumberSnapshot: Value(original.customerTaxNumberSnapshot),
      originalSaleId: Value(original.id),
      storeId: Value(original.storeId),
      priceLevelId: Value(original.priceLevelId),
      useTax: Value(original.useTax),
      priceIncludesTax: Value(original.priceIncludesTax),
      subtotal: Value(original.subtotal),
      discountTotal: Value(original.discountTotal),
      taxTotal: Value(original.taxTotal),
      grandTotal: Value(original.grandTotal),
      paidTotal: Value(original.paidTotal),
      remainingTotal: Value(original.remainingTotal),
      changeTotal: Value(0),
      createdAt: Value(now),
      completedAt: Value(now),
    );

    final lines = [
      for (final line in originalLines)
        SaleLinesCompanion(
          id: Value('TI_${_uuid.v4()}'),
          saleId: Value(returnSaleId),
          itemId: Value(line.itemId),
          unitId: Value(line.unitId),
          barcode: Value(line.barcode),
          itemNameSnapshot: Value(line.itemNameSnapshot),
          unitNameSnapshot: Value(line.unitNameSnapshot),
          qtyScaled: Value(line.qtyScaled),
          qtyScale: Value(line.qtyScale),
          unitPrice: Value(line.unitPrice),
          grossAmount: Value(line.grossAmount),
          lineDiscountType: Value(line.lineDiscountType),
          lineDiscountValue: Value(line.lineDiscountValue),
          lineDiscountAmount: Value(line.lineDiscountAmount),
          taxableAmount: Value(line.taxableAmount),
          taxRate: Value(line.taxRate),
          taxAmount: Value(line.taxAmount),
          lineTotal: Value(line.lineTotal),
          allowDiscountSnapshot: Value(line.allowDiscountSnapshot),
          unitSize: Value(line.unitSize),
          storeId: Value(line.storeId),
          priceLevelId: Value(line.priceLevelId),
          notes: Value(line.notes),
        ),
    ];

    final payments = [
      for (final payment in originalPayments)
        SalePaymentsCompanion(
          id: Value('TP_${_uuid.v4()}'),
          saleId: Value(returnSaleId),
          paymentMethodId: Value(payment.paymentMethodId),
          methodCodeSnapshot: Value(payment.methodCodeSnapshot),
          methodNameSnapshot: Value(payment.methodNameSnapshot),
          methodTypeSnapshot: Value(payment.methodTypeSnapshot),
          isManual: Value(payment.isManual),
          amount: Value(payment.amount),
          cashTendered: Value(payment.cashTendered),
          changeGiven: const Value(0),
          referenceNo: Value(payment.referenceNo),
          bankId: Value(payment.bankId),
          cardTypeId: Value(payment.cardTypeId),
          paymentDeviceRef: Value(payment.paymentDeviceRef),
          authCode: Value(payment.authCode),
          rrn: Value(payment.rrn),
          cardScheme: Value(payment.cardScheme),
          cardLast4: Value(payment.cardLast4),
          status: Value(PaymentStatus.completed.code),
          createdAt: Value(now),
        ),
    ];

    final taxes = [
      for (final tax in originalTaxes)
        SaleTaxSummaryCompanion(
          id: Value('TT_${_uuid.v4()}'),
          saleId: Value(returnSaleId),
          taxRate: Value(tax.taxRate),
          taxableAmount: Value(tax.taxableAmount),
          taxAmount: Value(tax.taxAmount),
        ),
    ];

    await _salesDao.createReturnSaleEnvelope(
      header: header,
      items: lines,
      payments: payments,
      taxes: taxes,
      outboxEntry: _outboxEventFactory.returnCreated(
        saleId: returnSaleId,
        originalSaleId: original.id,
        localInvoiceNo: localInvoiceNo,
        machineNo: session.activeMachineNo,
        branchNo: session.activeBranchNo,
        shiftId: shift.id,
        cashierId: session.activeUserId,
        grandTotal: original.grandTotal,
        completedAt: now,
        idempotencyKey: idempotencyKey,
      ),
      auditLogEntry: AuditLogCompanion.insert(
        id: 'AUD_${_uuid.v4()}',
        action: AuditAction.returnCreated.code,
        actorId: session.activeUserId,
        actorName: Value(session.activeUserName),
        targetType: Value(OutboxEntityType.returnSale.code),
        targetId: Value(returnSaleId),
        detailsJson: Value(
          jsonEncode({
            'originalSaleId': original.id,
            'originalInvoiceNo': original.localSaleNo,
            'returnInvoiceNo': localInvoiceNo,
            'grandTotal': original.grandTotal,
          }),
        ),
        terminalId: session.activeMachineNo,
        createdAt: now,
      ),
    );

    await _invoiceDocumentBuilder.buildForSale(returnSaleId);

    return returnSaleId;
  }

}

class SaleDetail {
  final Sale sale;
  final List<SaleLine> items;
  final List<SalePayment> payments;

  const SaleDetail({
    required this.sale,
    required this.items,
    required this.payments,
  });
}

final salesHistoryServiceProvider = Provider<SalesHistoryService>((ref) {
  return SalesHistoryService(
    salesDao: ref.watch(salesDaoProvider),
    shiftDao: ref.watch(shiftDaoProvider),
    invoiceNumberService: ref.watch(invoiceNumberServiceProvider),
    invoiceDocumentBuilder: ref.watch(invoiceDocumentBuilderProvider),
    outboxEventFactory: ref.watch(outboxEventFactoryProvider),
    activeSession: ref.watch(activePosSessionProvider).valueOrNull,
    clock: ref.watch(clockProvider),
  );
});
