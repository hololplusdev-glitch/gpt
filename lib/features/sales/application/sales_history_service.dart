import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/core/persistence/daos/sales_dao.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/core/services/time/clock.dart';
import 'package:holol_POS/shared/models/sales_history.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';

/// Sales history/detail query owner only.
/// Sale completion remains owned by SaleCheckout.
class SalesHistoryService {
  final SalesDao _salesDao;
  final Clock _clock;

  const SalesHistoryService({
    required SalesDao salesDao,
    Clock clock = const SystemClock(),
  }) : _salesDao = salesDao,
       _clock = clock;

  Future<List<Sale>> getTodaysSales() {
    return _salesDao.getSalesByDate(_clock.now());
  }

  Future<List<SaleSummary>> searchSalesHistory({
    String? query,
    int limit = 100,
  }) {
    return _salesDao.searchSalesHistory(query: query, limit: limit);
  }

  Future<List<String>> getDistinctCashierIds() {
    return _salesDao.getDistinctCashierIds();
  }

  Future<List<({String code, String label})>>
  getDistinctPaymentMethodsForHistory() {
    return _salesDao.getDistinctPaymentMethodsForHistory();
  }

  Future<List<SaleSummary>> getSalesFiltered(SalesHistoryFilter filter) async {
    final sales = await _salesDao.getSalesFiltered(filter);
    final paymentLabels = await _salesDao.getPrimaryPaymentLabelsForSales(
      sales.map((sale) => sale.id),
    );

    return sales
        .map(
          (sale) => SaleSummary(
            id: sale.id,
            localSaleNo: sale.localSaleNo,
            status: sale.status,
            grandTotal: sale.grandTotal,
            createdAt: sale.createdAt,
            cashierId: sale.cashierId,
            paymentMethodLabel: paymentLabels[sale.id],
          ),
        )
        .toList();
  }

  Future<SaleDetail?> getSaleDetail(String saleId) async {
    final sale = await _salesDao.getById(saleId);
    if (sale == null) return null;

    final items = await _salesDao.getSaleLines(saleId);
    final payments = await _salesDao.getSalePayments(saleId);

    return SaleDetail(sale: sale, items: items, payments: payments);
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
    clock: ref.watch(clockProvider),
  );
});
