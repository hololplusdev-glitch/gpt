import 'dart:convert';

import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:uuid/uuid.dart';

/// Builds local outbox events for future upload.
///
/// This class does not process the queue. Upload execution remains owned by
/// DbSyncService / SyncDao.
class OutboxEventFactory {
  static const _uuid = Uuid();

  const OutboxEventFactory();

  OutboxEventsCompanion _event({
    required OutboxEventType eventType,
    required OutboxEntityType entityType,
    required String entityId,
    required Map<String, dynamic> payload,
    required DateTime createdAt,
    required String idempotencyKey,
  }) {
    return OutboxEventsCompanion.insert(
      id: 'OBX_${_uuid.v4()}',
      eventType: eventType.code,
      entityType: entityType.code,
      entityId: entityId,
      payloadJson: jsonEncode(payload),
      status: OutboxStatus.pending.code,
      createdAt: createdAt,
      idempotencyKey: idempotencyKey,
    );
  }

  OutboxEventsCompanion saleCreated({
    required String saleId,
    required String localInvoiceNo,
    required String machineNo,
    required String branchNo,
    required String shiftId,
    required String cashierId,
    required double grandTotal,
    required DateTime completedAt,
    required String idempotencyKey,
  }) {
    return _event(
      eventType: OutboxEventType.saleCreated,
      entityType: OutboxEntityType.sale,
      entityId: saleId,
      createdAt: completedAt,
      idempotencyKey: idempotencyKey,
      payload: {
        'saleId': saleId,
        'localSaleNo': localInvoiceNo,
        'machineNo': machineNo,
        'branchNo': branchNo,
        'shiftId': shiftId,
        'cashierId': cashierId,
        'grandTotal': grandTotal,
        'completedAt': completedAt.toIso8601String(),
      },
    );
  }

  OutboxEventsCompanion saleVoided({
    required String saleId,
    required String cashierId,
    required String cashierName,
    required DateTime voidedAt,
  }) {
    return _event(
      eventType: OutboxEventType.saleVoided,
      entityType: OutboxEntityType.sale,
      entityId: saleId,
      createdAt: voidedAt,
      idempotencyKey: 'void_$saleId',
      payload: {
        'saleId': saleId,
        'cashierId': cashierId,
        'cashierName': cashierName,
        'voidedAt': voidedAt.toIso8601String(),
      },
    );
  }

  OutboxEventsCompanion returnCreated({
    required String saleId,
    required String originalSaleId,
    required String localInvoiceNo,
    required String machineNo,
    required String branchNo,
    required String shiftId,
    required String cashierId,
    required double grandTotal,
    required DateTime completedAt,
    required String idempotencyKey,
  }) {
    return _event(
      eventType: OutboxEventType.returnCreated,
      entityType: OutboxEntityType.returnSale,
      entityId: saleId,
      createdAt: completedAt,
      idempotencyKey: idempotencyKey,
      payload: {
        'saleId': saleId,
        'originalSaleId': originalSaleId,
        'localSaleNo': localInvoiceNo,
        'machineNo': machineNo,
        'branchNo': branchNo,
        'shiftId': shiftId,
        'cashierId': cashierId,
        'grandTotal': grandTotal,
        'completedAt': completedAt.toIso8601String(),
      },
    );
  }

  OutboxEventsCompanion shiftOpened({
    required String localId,
    required String machineNo,
    required String cashierId,
    required String cashierName,
    required double openingCash,
    required DateTime openedAt,
    required DateTime expiresAt,
    required String idempotencyKey,
  }) {
    return _event(
      eventType: OutboxEventType.shiftOpened,
      entityType: OutboxEntityType.shift,
      entityId: localId,
      createdAt: openedAt,
      idempotencyKey: idempotencyKey,
      payload: {
        'localId': localId,
        'machineNo': machineNo,
        'cashierId': cashierId,
        'cashierName': cashierName,
        'openingCash': openingCash,
        'openedAt': openedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      },
    );
  }

  OutboxEventsCompanion shiftClosed({
    required String localId,
    required String machineNo,
    required String cashierId,
    required String cashierName,
    required double expectedCash,
    required double actualCash,
    required double difference,
    required double grossSales,
    required double netSales,
    required double cashSales,
    required double cardSales,
    required double otherSales,
    required double cashReturns,
    required double totalDiscounts,
    required double totalTaxes,
    required double totalReturns,
    required double totalVoids,
    required int saleCount,
    required DateTime closedAt,
  }) {
    return _event(
      eventType: OutboxEventType.shiftClosed,
      entityType: OutboxEntityType.shift,
      entityId: localId,
      createdAt: closedAt,
      idempotencyKey: 'shift_close_$localId',
      payload: {
        'localId': localId,
        'machineNo': machineNo,
        'cashierId': cashierId,
        'cashierName': cashierName,
        'expectedCash': expectedCash,
        'actualCash': actualCash,
        'difference': difference,
        'grossSales': grossSales,
        'netSales': netSales,
        'cashSales': cashSales,
        'cardSales': cardSales,
        'otherSales': otherSales,
        'cashReturns': cashReturns,
        'totalDiscounts': totalDiscounts,
        'totalTaxes': totalTaxes,
        'totalReturns': totalReturns,
        'totalVoids': totalVoids,
        'saleCount': saleCount,
        'closedAt': closedAt.toIso8601String(),
      },
    );
  }

  OutboxEventsCompanion shiftExtended({
    required String localId,
    required int extendedByMinutes,
    required DateTime newExpiry,
    required DateTime extendedAt,
  }) {
    return _event(
      eventType: OutboxEventType.shiftExtended,
      entityType: OutboxEntityType.shift,
      entityId: localId,
      createdAt: extendedAt,
      idempotencyKey: 'shift_extend_$localId',
      payload: {
        'localId': localId,
        'extendedByMinutes': extendedByMinutes,
        'newExpiry': newExpiry.toIso8601String(),
        'extendedAt': extendedAt.toIso8601String(),
      },
    );
  }
}
