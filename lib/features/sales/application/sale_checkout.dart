import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/core/persistence/daos/active_pos_session_dao.dart';
import 'package:holol_POS/core/persistence/daos/catalog_dao.dart';
import 'package:holol_POS/core/persistence/daos/sales_dao.dart';
import 'package:holol_POS/core/persistence/daos/shift_dao.dart';
import 'package:holol_POS/core/persistence/pos_config_repository.dart';
import 'package:holol_POS/core/services/invoice_number_service.dart';
import 'package:holol_POS/core/services/invoices/invoice_document_builder.dart';
import 'package:holol_POS/core/services/pos_devices/payment_profile_service.dart';
import 'package:holol_POS/core/services/pos_devices/print_job_processor.dart';
import 'package:holol_POS/core/services/pos_devices/print_queue.dart';
import 'package:holol_POS/core/services/sync/outbox_event_factory.dart';
import 'package:holol_POS/core/services/time/clock.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
import 'package:holol_POS/shared/refactor/pos_payment_draft.dart';

/// Adapter فقط. مسار البيع/الدفع/الفاتورة الفعلي داخل shared/refactor.
class SaleCheckout {
  final PosSaleCheckoutWorkflow _workflow;

  SaleCheckout({
    required SalesDao salesDao,
    required ShiftDao shiftDao,
    required CatalogDao catalogDao,
    required PosConfigRepository config,
    required InvoiceNumberService invoiceNumberService,
    required InvoiceDocumentBuilder invoiceDocumentBuilder,
    required OutboxEventFactory outboxEventFactory,
    required PrintQueue printQueue,
    required PrintJobProcessor printJobProcessor,
    required PaymentProfileService paymentProfileService,
    required ActivePosSession? activeSession,
    Clock clock = const SystemClock(),
  }) : _workflow = PosSaleCheckoutWorkflow(
         salesDao: salesDao,
         shiftDao: shiftDao,
         catalogDao: catalogDao,
         config: config,
         invoiceNumberService: invoiceNumberService,
         invoiceDocumentBuilder: invoiceDocumentBuilder,
         outboxEventFactory: outboxEventFactory,
         printQueue: printQueue,
         printJobProcessor: printJobProcessor,
         paymentProfileService: paymentProfileService,
         activeSession: activeSession,
         clock: clock,
       );

  Future<SaleCheckoutResult> complete(SaleCheckoutRequest request) {
    return _workflow.complete(request);
  }
}

typedef SaleCheckoutRequest = PosSaleCheckoutRequest;
typedef SaleCheckoutResult = PosSaleCheckoutResult;
typedef SaleCheckoutException = PosSaleCheckoutException;

final saleCheckoutProvider = Provider<SaleCheckout>((ref) {
  return SaleCheckout(
    salesDao: ref.watch(salesDaoProvider),
    shiftDao: ref.watch(shiftDaoProvider),
    catalogDao: ref.watch(catalogDaoProvider),
    config: ref.watch(posConfigProvider),
    invoiceNumberService: ref.watch(invoiceNumberServiceProvider),
    invoiceDocumentBuilder: ref.watch(invoiceDocumentBuilderProvider),
    outboxEventFactory: ref.watch(outboxEventFactoryProvider),
    printQueue: ref.watch(printQueueProvider),
    printJobProcessor: ref.watch(printJobProcessorProvider),
    paymentProfileService: ref.watch(paymentProfileServiceProvider),
    activeSession: ref.watch(activePosSessionProvider).valueOrNull,
    clock: ref.watch(clockProvider),
  );
});
