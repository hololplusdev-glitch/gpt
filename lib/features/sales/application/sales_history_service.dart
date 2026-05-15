import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/core/persistence/daos/active_pos_session_dao.dart';
import 'package:holol_POS/core/persistence/daos/sales_dao.dart';
import 'package:holol_POS/core/persistence/daos/shift_dao.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/core/services/invoice_number_service.dart';
import 'package:holol_POS/core/services/invoices/invoice_document_builder.dart';
import 'package:holol_POS/core/services/sync/outbox_event_factory.dart';
import 'package:holol_POS/core/services/time/clock.dart';
import 'package:holol_POS/shared/models/sales_history.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
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

  PosSalesHistoryWorkflow get _workflow => PosSalesHistoryWorkflow(
    salesDao: _salesDao,
    shiftDao: _shiftDao,
    invoiceNumberService: _invoiceNumberService,
    invoiceDocumentBuilder: _invoiceDocumentBuilder,
    outboxEventFactory: _outboxEventFactory,
    activeSession: _activeSession,
    clock: _clock,
  );

  Future<List<Sale>> getTodaysSales() {
    return _salesDao.getSalesByDate(_clock.now());
  }

  Future<List<SaleSummary>> searchSalesHistory({
    String? query,
    int limit = 100,
  }) {
    return _workflow.searchSalesHistory(query: query, limit: limit);
  }

  Future<SaleDetail?> getSaleDetail(String saleId) async {
    final detail = await _workflow.getSaleDetail(saleId);
    if (detail == null) return null;

    return SaleDetail(
      sale: detail.sale,
      items: detail.items,
      payments: detail.payments,
    );
  }

  Future<void> voidSale(String saleId) {
    return _workflow.voidSale(saleId);
  }

  Future<String> returnSale(String saleId) {
    return _workflow.returnSale(saleId);
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
