// core/persistence/daos/sales_dao.dart
// WHY: Atomic DB access for the entire sales pipeline.
// Sales, lines, payments, taxes, adjustments — all persisted in one call.

import 'package:drift/drift.dart';
import 'package:pos_flutter/core/persistence/database.dart';
import 'package:pos_flutter/core/services/payments/payment_method_resolver.dart';
import 'package:pos_flutter/shared/models/enums.dart';
import 'package:pos_flutter/shared/models/sales_history.dart';

/// Data access for sale persistence and querying.
class SalesDao {
  final AppDatabase _db;

  SalesDao(this._db);

  // ---------------------------------------------------------------------------
  // Atomic Sale Persistence
  // ---------------------------------------------------------------------------

  /// Persist a sale and all related records as one atomic DB transaction.
  Future<void> persistSaleEnvelope({
    required SalesCompanion header,
    required List<SaleLinesCompanion> items,
    required List<SalePaymentsCompanion> payments,
    required AuditLogCompanion auditLogEntry,
    OutboxEventsCompanion? outboxEntry,
    List<SaleTaxSummaryCompanion>? taxes,
    List<SaleAdjustmentsCompanion>? discounts,
  }) async {
    await _db.transaction(() async {
      await _db.into(_db.sales).insert(header);
      for (final item in items) {
        await _db.into(_db.saleLines).insert(item);
      }
      for (final payment in payments) {
        await _db.into(_db.salePayments).insert(payment);
      }
      if (taxes != null) {
        for (final tax in taxes) {
          await _db.into(_db.saleTaxSummary).insert(tax);
        }
      }
      if (discounts != null) {
        for (final discount in discounts) {
          await _db.into(_db.saleAdjustments).insert(discount);
        }
      }
      if (outboxEntry != null) {
        await _db.into(_db.outboxEvents).insert(outboxEntry);
      }
      await _db.into(_db.auditLog).insert(auditLogEntry);
    });
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Get sale by ID.
  Future<Sale?> getById(String saleId) async {
    return (_db.select(
      _db.sales,
    )..where((t) => t.id.equals(saleId))).getSingleOrNull();
  }

  /// Get line items for a sale.
  Future<List<SaleLine>> getSaleLines(String saleId) async {
    return (_db.select(
      _db.saleLines,
    )..where((i) => i.saleId.equals(saleId))).get();
  }

  /// Get payments for a sale.
  Future<List<SalePayment>> getSalePayments(String saleId) async {
    return (_db.select(
      _db.salePayments,
    )..where((p) => p.saleId.equals(saleId))).get();
  }

  /// Alias used by invoice builder.
  Future<Sale?> getInvoiceSale(String saleId) => getById(saleId);

  Future<List<SaleLine>> getInvoiceLines(String saleId) => getSaleLines(saleId);

  Future<List<SaleTaxSummaryData>> getInvoiceTaxes(String saleId) {
    return (_db.select(
      _db.saleTaxSummary,
    )..where((tax) => tax.saleId.equals(saleId))).get();
  }

  Future<List<InvoicePaymentWithMethodInfo>> getInvoicePaymentsWithMethodInfo(
    String saleId,
  ) async {
    final payments =
        await (_db.select(_db.salePayments)
              ..where((p) => p.saleId.equals(saleId))
              ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]))
            .get();
    final methods = await _db.select(_db.paymentMethods).get();
    final methodById = {for (final method in methods) method.id: method};
    return payments
        .map(
          (payment) => InvoicePaymentWithMethodInfo(
            payment: payment,
            method: methodById[payment.paymentMethodId],
          ),
        )
        .toList();
  }

  Future<BranchProfileData?> getInvoiceBranch(Sale sale) {
    final braNbr = sale.branchNo ?? sale.terminalId;
    return (_db.select(_db.branchProfile)..where(
          (branch) =>
              branch.id.equals(sale.branchNo ?? '') |
              branch.branchNo.equals(sale.branchNo ?? '') |
              branch.branchNo.equals(braNbr),
        ))
        .getSingleOrNull();
  }

  Future<List<PrintJob>> getSalePrintJobs(String saleId) {
    return (_db.select(_db.printJobs)
          ..where((job) => job.saleId.equals(saleId))
          ..orderBy([(job) => OrderingTerm.desc(job.createdAt)]))
        .get();
  }

  /// Get sales for a shift.
  Future<List<Sale>> getSalesForShift(String shiftId) async {
    return (_db.select(_db.sales)
          ..where((t) => t.shiftId.equals(shiftId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Get sales by date range.
  Future<List<Sale>> getSalesByDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (_db.select(_db.sales)
          ..where(
            (t) =>
                t.createdAt.isBiggerOrEqualValue(start) &
                t.createdAt.isSmallerThanValue(end),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Get sales filtered by history criteria.
  Future<List<Sale>> getSalesFiltered(SalesHistoryFilter filter) async {
    Set<String>? paymentSaleIds;
    if (filter.paymentMethodCode?.trim().isNotEmpty == true) {
      final code = filter.paymentMethodCode!.trim();
      final payments = await (_db.select(
        _db.salePayments,
      )..where((p) => p.methodCodeSnapshot.equals(code))).get();
      paymentSaleIds = payments.map((p) => p.saleId).toSet();
      if (paymentSaleIds.isEmpty) return [];
    }

    final query = _db.select(_db.sales);
    if (filter.startDate != null) {
      query.where((t) => t.createdAt.isBiggerOrEqualValue(filter.startDate!));
    }
    if (filter.endDate != null) {
      query.where((t) => t.createdAt.isSmallerThanValue(filter.endDate!));
    }
    if (filter.invoiceNo?.trim().isNotEmpty == true) {
      query.where((t) => t.localSaleNo.contains(filter.invoiceNo!.trim()));
    }
    if (filter.cashierId?.trim().isNotEmpty == true) {
      query.where((t) => t.cashierId.equals(filter.cashierId!.trim()));
    }
    if (paymentSaleIds != null) {
      query.where((t) => t.id.isIn(paymentSaleIds!));
    }

    query
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(filter.limit);
    return query.get();
  }

  Future<List<SaleSummary>> searchSalesHistory({
    String? query,
    int limit = 100,
  }) async {
    final cleanQuery = query?.trim();
    final hasQuery = cleanQuery != null && cleanQuery.isNotEmpty;

    Set<String> matchingSaleIdsFromLines = const {};
    if (hasQuery) {
      final matchingLines = await (_db.select(
        _db.saleLines,
      )..where((line) => line.itemNameSnapshot.contains(cleanQuery))).get();

      matchingSaleIdsFromLines = matchingLines
          .map((line) => line.saleId)
          .toSet();
    }

    final salesQuery = _db.select(_db.sales);

    if (hasQuery) {
      salesQuery.where((sale) {
        final invoiceMatch = sale.localSaleNo.contains(cleanQuery);
        final idMatch = sale.id.contains(cleanQuery);

        if (matchingSaleIdsFromLines.isEmpty) {
          return invoiceMatch | idMatch;
        }

        return invoiceMatch | idMatch | sale.id.isIn(matchingSaleIdsFromLines);
      });
    }

    salesQuery
      ..orderBy([(sale) => OrderingTerm.desc(sale.createdAt)])
      ..limit(limit);

    final sales = await salesQuery.get();
    if (sales.isEmpty) return const [];

    final saleIds = sales.map((sale) => sale.id).toSet();

    final lines = await (_db.select(
      _db.saleLines,
    )..where((line) => line.saleId.isIn(saleIds))).get();

    final productNamesBySaleId = <String, List<String>>{};
    for (final line in lines) {
      final name = line.itemNameSnapshot.trim();
      if (name.isEmpty) continue;

      final names = productNamesBySaleId.putIfAbsent(line.saleId, () => []);
      if (!names.contains(name)) {
        names.add(name);
      }
    }

    final paymentLabels = await getPrimaryPaymentLabelsForSales(saleIds);

    return sales.map((sale) {
      return SaleSummary(
        id: sale.id,
        localSaleNo: sale.localSaleNo,
        status: sale.status,
        grandTotal: sale.grandTotal,
        createdAt: sale.createdAt,
        cashierId: sale.cashierId,
        paymentMethodLabel: paymentLabels[sale.id],
        productSummary: _productSummary(productNamesBySaleId[sale.id]),
      );
    }).toList();
  }

  String _productSummary(List<String>? names) {
    if (names == null || names.isEmpty) return '';
    if (names.length <= 3) return names.join(', ');

    final visible = names.take(3).join(', ');
    final remaining = names.length - 3;
    return '$visible +$remaining';
  }

  Future<List<String>> getDistinctCashierIds() async {
    final rows = await (_db.select(
      _db.sales,
    )..orderBy([(t) => OrderingTerm.asc(t.cashierId)])).get();
    return rows
        .map((t) => t.cashierId.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  Future<List<({String code, String label})>>
  getDistinctPaymentMethodsForHistory() async {
    final payments = await _db.select(_db.salePayments).get();
    final methods = await _db.select(_db.paymentMethods).get();
    final methodById = {for (final method in methods) method.id: method};
    final byCode = <String, String>{};
    for (final payment in payments) {
      final code = payment.methodCodeSnapshot.trim();
      if (code.isEmpty) continue;
      byCode[code] =
          _clean(payment.methodNameSnapshot) ??
          methodById[payment.paymentMethodId]?.name ??
          code;
    }
    final entries = byCode.entries
        .map((e) => (code: e.key, label: e.value))
        .toList();
    entries.sort((a, b) => a.label.compareTo(b.label));
    return entries;
  }

  Future<Map<String, String>> getPrimaryPaymentLabelsForSales(
    Iterable<String> saleIds,
  ) async {
    final ids = saleIds.where((id) => id.trim().isNotEmpty).toSet();
    if (ids.isEmpty) return const {};

    final payments =
        await (_db.select(_db.salePayments)
              ..where((payment) => payment.saleId.isIn(ids))
              ..orderBy([(payment) => OrderingTerm.asc(payment.createdAt)]))
            .get();
    final labels = <String, String>{};
    for (final payment in payments) {
      labels.putIfAbsent(
        payment.saleId,
        () =>
            _clean(payment.methodNameSnapshot) ??
            _clean(payment.methodCodeSnapshot) ??
            payment.paymentMethodId,
      );
    }
    return labels;
  }

  /// Shift sales totals for shift closing calculation.
  Future<ShiftSalesTotals> getShiftSalesTotals(String shiftId) async {
    final sales = await getSalesForShift(shiftId);

    var grossSales = 0.0;
    var netSales = 0.0;
    var totalDiscounts = 0.0;
    var totalTaxes = 0.0;
    var totalReturns = 0.0;
    var totalVoids = 0.0;
    var cashSales = 0.0;
    var cardSales = 0.0;
    var otherSales = 0.0;
    int saleCount = 0;

    for (final s in sales) {
      final isSale = s.type == SaleType.sale.code;
      final isReturn = s.type == SaleType.returnSale.code;
      final isVoid = s.status == SaleStatus.voided.code;
      final isCompleted = s.status == SaleStatus.completed.code;

      if (isSale && isCompleted) {
        grossSales += s.grandTotal;
        netSales += s.subtotal;
        totalDiscounts += s.discountTotal;
        totalTaxes += s.taxTotal;
        saleCount++;

        final payments = await getSalePayments(s.id);
        for (final p in payments) {
          final methodType = PaymentMethodResolver.typeFromStored(
            methodCode: p.methodCodeSnapshot,
            storedTypeCode: p.methodTypeSnapshot,
          );
          if (methodType == null) {
            throw StateError(
              'Unknown payment method type in sale ${s.id}: '
              '${p.methodCodeSnapshot}',
            );
          }
          switch (methodType) {
            case PaymentMethodType.cash:
              cashSales += p.amount;
            case PaymentMethodType.manualCard:
            case PaymentMethodType.integratedCard:
              cardSales += p.amount;
            default:
              otherSales += p.amount;
          }
        }
      } else if (isReturn && isCompleted) {
        totalReturns += s.grandTotal;
      } else if (isVoid) {
        totalVoids += s.grandTotal;
      }
    }

    return ShiftSalesTotals(
      grossSales: grossSales,
      netSales: netSales,
      cashSales: cashSales,
      cardSales: cardSales,
      otherSales: otherSales,
      totalDiscounts: totalDiscounts,
      totalTaxes: totalTaxes,
      totalReturns: totalReturns,
      totalVoids: totalVoids,
      saleCount: saleCount,
    );
  }

  /// Void a sale atomically with outbox + audit.
  Future<void> voidSaleEnvelope({
    required String saleId,
    required DateTime voidedAt,
    required OutboxEventsCompanion outboxEntry,
    required AuditLogCompanion auditLogEntry,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.sales)..where((t) => t.id.equals(saleId))).write(
        SalesCompanion(
          status: Value(SaleStatus.voided.code),
          voidedAt: Value(voidedAt),
          syncStatus: Value(OutboxStatus.pending.code),
        ),
      );
      await _db.into(_db.outboxEvents).insert(outboxEntry);
      await _db.into(_db.auditLog).insert(auditLogEntry);
    });
  }

  /// Update sync status for a sale.
  Future<void> updateSyncStatus(
    String saleId,
    OutboxStatus status, {
    String? serverId,
  }) async {
    final companion = SalesCompanion(syncStatus: Value(status.code));
    await (_db.update(
      _db.sales,
    )..where((t) => t.id.equals(saleId))).write(companion);
    if (serverId != null) {
      await (_db.update(_db.sales)..where((t) => t.id.equals(saleId))).write(
        SalesCompanion(serverId: Value(serverId)),
      );
    }
  }

  /// Reserve next invoice sequence number.
  Future<int> reserveNextInvoiceSequence(
    DateTime now, {
    required String custCode,
    required String branchNo,
    required String machineNo,
    required String userId,
    String sequenceType = 'sale',
  }) async {
    final sequenceId = [
      custCode,
      branchNo,
      machineNo,
      userId,
      sequenceType,
    ].join(':');

    return _db.transaction(() async {
      final row =
          await (_db.select(_db.invoiceSequences)..where(
                (s) =>
                    s.custCode.equals(custCode) &
                    s.branchNo.equals(branchNo) &
                    s.machineNo.equals(machineNo) &
                    s.userId.equals(userId) &
                    s.sequenceType.equals(sequenceType),
              ))
              .getSingleOrNull();
      if (row == null) {
        await _db
            .into(_db.invoiceSequences)
            .insert(
              InvoiceSequencesCompanion.insert(
                id: sequenceId,
                custCode: custCode,
                branchNo: branchNo,
                machineNo: machineNo,
                userId: userId,
                sequenceType: Value(sequenceType),
                currentValue: const Value(1),
                updatedAt: now,
              ),
            );
        return 1;
      }

      final next = row.currentValue + 1;
      await (_db.update(
        _db.invoiceSequences,
      )..where((s) => s.id.equals(row.id))).write(
        InvoiceSequencesCompanion(
          currentValue: Value(next),
          updatedAt: Value(now),
        ),
      );
      return next;
    });
  }

  // ---------------------------------------------------------------------------
  // Held Orders
  // ---------------------------------------------------------------------------

  Future<void> holdOrder(HeldOrdersCompanion order) async {
    await _db.into(_db.heldOrders).insert(order);
  }

  Future<List<HeldOrder>> getActiveHeldOrders(String shiftId) async {
    return (_db.select(_db.heldOrders)
          ..where(
            (h) =>
                h.shiftId.equals(shiftId) &
                h.status.equals(HeldOrderStatus.held.code),
          )
          ..orderBy([(h) => OrderingTerm.desc(h.heldAt)]))
        .get();
  }

  Future<List<HeldOrder>> getAllHeldOrders(String machineNo) async {
    return (_db.select(_db.heldOrders)
          ..where(
            (h) =>
                h.machineNo.equals(machineNo) &
                h.status.equals(HeldOrderStatus.held.code),
          )
          ..orderBy([(h) => OrderingTerm.desc(h.heldAt)]))
        .get();
  }

  Future<int> countActiveHeldOrders(String shiftId) async {
    final orders = await getActiveHeldOrders(shiftId);
    return orders.length;
  }

  Future<void> resumeHeldOrder(String orderId, DateTime now) async {
    await (_db.update(
      _db.heldOrders,
    )..where((h) => h.id.equals(orderId))).write(
      HeldOrdersCompanion(
        status: Value(HeldOrderStatus.resumed.code),
        resumedAt: Value(now),
      ),
    );
  }

  Future<void> cancelHeldOrder(String orderId) async {
    await (_db.update(
      _db.heldOrders,
    )..where((h) => h.id.equals(orderId))).write(
      HeldOrdersCompanion(status: Value(HeldOrderStatus.cancelled.code)),
    );
  }

  String? _clean(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}

/// Aggregated shift sales totals.
class ShiftSalesTotals {
  final double grossSales;
  final double netSales;
  final double cashSales;
  final double cardSales;
  final double otherSales;
  final double totalDiscounts;
  final double totalTaxes;
  final double totalReturns;
  final double totalVoids;
  final int saleCount;

  const ShiftSalesTotals({
    required this.grossSales,
    required this.netSales,
    required this.cashSales,
    required this.cardSales,
    required this.otherSales,
    required this.totalDiscounts,
    required this.totalTaxes,
    required this.totalReturns,
    required this.totalVoids,
    required this.saleCount,
  });
}

class InvoicePaymentWithMethodInfo {
  final SalePayment payment;
  final PaymentMethod? method;

  const InvoicePaymentWithMethodInfo({required this.payment, this.method});
}
