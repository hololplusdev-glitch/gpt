// core/services/invoice_number_service.dart
// WHY: Local invoice numbers are generated with a configurable pattern.
// The official Backend invoice number is only assigned after sync.

import 'package:holol_POS/core/persistence/daos/sales_dao.dart';
import 'package:holol_POS/core/services/time/clock.dart';

/// Generates local invoice numbers.
class InvoiceNumberService {
  final SalesDao _salesDao;
  final Clock _clock;

  InvoiceNumberService(this._salesDao, {Clock clock = const SystemClock()})
    : _clock = clock;

  /// Generate next local invoice number for the active POS session.
  Future<String> generateNext({
    required String branchNo,
    required String machineNo,
    String sequenceType = 'sale',
  }) async {
    final seq = await _salesDao.reserveNextInvoiceSequence(
      _clock.now(),
      branchNo: branchNo,
      machineNo: machineNo,
      sequenceType: sequenceType,
    );
    return '$branchNo-$machineNo-${seq.toString().padLeft(6, '0')}';
  }
}
