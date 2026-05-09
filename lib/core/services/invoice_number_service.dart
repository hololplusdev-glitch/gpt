// core/services/invoice_number_service.dart
// WHY: Local invoice numbers are generated with a configurable pattern.
// The official Backend invoice number is only assigned after sync.
// Backend pattern: {CUST}-{BRA}-{MCHN}-{USR}-{SEQ} (zero-padded 4 digits).

import 'package:pos_flutter/core/persistence/daos/sales_dao.dart';
import 'package:pos_flutter/core/services/time/clock.dart';

/// Generates local invoice numbers.
class InvoiceNumberService {
  final SalesDao _salesDao;
  final Clock _clock;

  InvoiceNumberService(
    this._salesDao, {
    Clock clock = const SystemClock(),
  }) : _clock = clock;

  /// Generate next local invoice number for the active POS session.
  Future<String> generateNext({
    required String custCode,
    required String branchNo,
    required String machineNo,
    required String userId,
    String sequenceType = 'sale',
  }) async {
    final seq = await _salesDao.reserveNextInvoiceSequence(
      custCode: custCode,
      branchNo: branchNo,
      machineNo: machineNo,
      userId: userId,
      sequenceType: sequenceType,
      _clock.now(),
    );
    return '$custCode-$branchNo-$machineNo-$userId-${seq.toString().padLeft(6, '0')}';
  }
}
