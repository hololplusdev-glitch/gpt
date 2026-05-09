import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pos_flutter/core/persistence/database.dart';
import 'package:pos_flutter/shared/models/enums.dart';
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
    String? supervisorId,
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
          'supervisorId': supervisorId,
          'voidedAt': voidedAt.toIso8601String(),
        }),
      ),
      status: Value(OutboxStatus.pending.code),
      createdAt: Value(voidedAt),
      idempotencyKey: Value('void_$saleId'),
    );
  }
}
