import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:uuid/uuid.dart';

/// Final upload owner.
/// Backing storage: existing OutboxEvents table.
/// Payload here is only pointer metadata. Full upload payload must be built
/// from Sales/SaleLines/SalePayments/SaleTaxSummary when upload runs.
class UploadQueue {
  static const _uuid = Uuid();

  const UploadQueue();

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
    return OutboxEventsCompanion(
      id: Value('OBX_${_uuid.v4()}'),
      eventType: Value(OutboxEventType.saleCreated.code),
      entityType: Value(OutboxEntityType.sale.code),
      entityId: Value(saleId),
      payloadJson: Value(
        jsonEncode({
          'saleId': saleId,
          'localSaleNo': localInvoiceNo,
          'machineNo': machineNo,
          'branchNo': branchNo,
          'shiftId': shiftId,
          'cashierId': cashierId,
          'grandTotal': grandTotal,
          'completedAt': completedAt.toIso8601String(),
        }),
      ),
      status: Value(OutboxStatus.pending.code),
      createdAt: Value(completedAt),
      idempotencyKey: Value(idempotencyKey),
    );
  }

  OutboxEventsCompanion saleVoided({
    required String saleId,
    required String cashierId,
    required String cashierName,
    required DateTime voidedAt,
  }) {
    return OutboxEventsCompanion(
      id: Value('OBX_${_uuid.v4()}'),
      eventType: Value(OutboxEventType.saleVoided.code),
      entityType: Value(OutboxEntityType.sale.code),
      entityId: Value(saleId),
      payloadJson: Value(
        jsonEncode({
          'saleId': saleId,
          'cashierId': cashierId,
          'cashierName': cashierName,
          'voidedAt': voidedAt.toIso8601String(),
        }),
      ),
      status: Value(OutboxStatus.pending.code),
      createdAt: Value(voidedAt),
      idempotencyKey: Value('void_$saleId'),
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
    return OutboxEventsCompanion(
      id: Value('OBX_${_uuid.v4()}'),
      eventType: Value(OutboxEventType.returnCreated.code),
      entityType: Value(OutboxEntityType.returnSale.code),
      entityId: Value(saleId),
      payloadJson: Value(
        jsonEncode({
          'saleId': saleId,
          'originalSaleId': originalSaleId,
          'localSaleNo': localInvoiceNo,
          'machineNo': machineNo,
          'branchNo': branchNo,
          'shiftId': shiftId,
          'cashierId': cashierId,
          'grandTotal': grandTotal,
          'completedAt': completedAt.toIso8601String(),
        }),
      ),
      status: Value(OutboxStatus.pending.code),
      createdAt: Value(completedAt),
      idempotencyKey: Value(idempotencyKey),
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
    return OutboxEventsCompanion.insert(
      id: 'OBX_${_uuid.v4()}',
      eventType: OutboxEventType.shiftOpened.code,
      entityType: OutboxEntityType.shift.code,
      entityId: localId,
      payloadJson: jsonEncode({
        'localId': localId,
        'machineNo': machineNo,
        'cashierId': cashierId,
        'cashierName': cashierName,
        'openingCash': openingCash,
        'openedAt': openedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      }),
      status: OutboxStatus.pending.code,
      createdAt: openedAt,
      idempotencyKey: idempotencyKey,
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
    return OutboxEventsCompanion.insert(
      id: 'OBX_${_uuid.v4()}',
      eventType: OutboxEventType.shiftClosed.code,
      entityType: OutboxEntityType.shift.code,
      entityId: localId,
      payloadJson: jsonEncode({
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
      }),
      status: OutboxStatus.pending.code,
      createdAt: closedAt,
      idempotencyKey: 'shift_close_$localId',
    );
  }

  OutboxEventsCompanion shiftExtended({
    required String localId,
    required int extendedByMinutes,
    required DateTime newExpiry,
    required DateTime extendedAt,
  }) {
    return OutboxEventsCompanion.insert(
      id: 'OBX_${_uuid.v4()}',
      eventType: OutboxEventType.shiftExtended.code,
      entityType: OutboxEntityType.shift.code,
      entityId: localId,
      payloadJson: jsonEncode({
        'localId': localId,
        'extendedByMinutes': extendedByMinutes,
        'newExpiry': newExpiry.toIso8601String(),
        'extendedAt': extendedAt.toIso8601String(),
      }),
      status: OutboxStatus.pending.code,
      createdAt: extendedAt,
      idempotencyKey: 'shift_extend_$localId',
    );
  }
}
