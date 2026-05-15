import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/persistence/daos/active_pos_session_dao.dart';
import 'package:holol_POS/core/persistence/daos/audit_dao.dart';
import 'package:holol_POS/core/persistence/daos/catalog_dao.dart';
import 'package:holol_POS/core/persistence/daos/sales_dao.dart';
import 'package:holol_POS/core/persistence/daos/shift_dao.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/core/persistence/pos_config_repository.dart';
import 'package:holol_POS/core/services/time/clock.dart';
import 'package:holol_POS/features/sales/domain/models/sale_inputs.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
import 'package:holol_POS/shared/refactor/pos_business_rules.dart';

/// Held-order owner only.
/// Held orders are stored as cart intent snapshots.
/// Final prices/totals are always recalculated by shared/refactor workflows.
class HeldOrdersService {
  final SalesDao _salesDao;
  final ShiftDao _shiftDao;
  final AuditDao _auditDao;
  final CatalogDao _catalogDao;
  final PosConfigRepository _config;
  final ActivePosSession? _activeSession;
  final Clock _clock;

  HeldOrdersService({
    required SalesDao salesDao,
    required ShiftDao shiftDao,
    required AuditDao auditDao,
    required CatalogDao catalogDao,
    required PosConfigRepository config,
    required ActivePosSession? activeSession,
    Clock clock = const SystemClock(),
  }) : _salesDao = salesDao,
       _shiftDao = shiftDao,
       _auditDao = auditDao,
       _catalogDao = catalogDao,
       _config = config,
       _activeSession = activeSession,
       _clock = clock;

  PosHeldOrdersWorkflow get _workflow => PosHeldOrdersWorkflow(
    salesDao: _salesDao,
    shiftDao: _shiftDao,
    auditDao: _auditDao,
    catalogDao: _catalogDao,
    config: _config,
    activeSession: _activeSession,
    clock: _clock,
    exceptionFactory: SaleException.new,
  );
  PosCheckoutQuote previewQuote({required List<SaleLineInput> lineItems}) {
    return _workflow.previewQuote(lineItems: lineItems);
  }

  Future<String> holdOrder({
    required List<SaleLineInput> items,
    String? customerId,
    String? customerName,
    String? referenceName,
    String? notes,
  }) {
    return _workflow.holdOrder(
      items: items,
      customerId: customerId,
      customerName: customerName,
      referenceName: referenceName,
      notes: notes,
    );
  }

  Future<HeldOrderResumeResult> resumeHeldOrder({
    required String orderId,
  }) async {
    final resumeData = await _workflow.resumeHeldOrder(orderId: orderId);
    return HeldOrderResumeResult(
      lines: resumeData.lines,
      warnings: resumeData.warnings,
    );
  }

  Future<void> cancelHeldOrder({required String orderId}) {
    return _workflow.cancelHeldOrder(orderId: orderId);
  }

  Future<List<HeldOrder>> getCurrentHeldOrders() {
    return _workflow.getCurrentHeldOrders();
  }

  Future<List<HeldOrder>> getHeldOrders(String shiftId) {
    return _workflow.getHeldOrders(shiftId);
  }
}

class HeldOrderResumeResult {
  final List<SaleLineInput> lines;
  final List<String> warnings;

  const HeldOrderResumeResult({required this.lines, this.warnings = const []});
}

class SaleException extends BusinessException {
  const SaleException(super.message) : super(code: 'sale_error');
}

final heldOrdersServiceProvider = Provider<HeldOrdersService>((ref) {
  return HeldOrdersService(
    salesDao: ref.watch(salesDaoProvider),
    shiftDao: ref.watch(shiftDaoProvider),
    auditDao: ref.watch(auditDaoProvider),
    catalogDao: ref.watch(catalogDaoProvider),
    config: ref.watch(posConfigProvider),
    activeSession: ref.watch(activePosSessionProvider).valueOrNull,
    clock: ref.watch(clockProvider),
  );
});
