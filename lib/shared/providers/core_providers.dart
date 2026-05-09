import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_flutter/core/config/runtime_config_repository.dart';
import 'package:pos_flutter/core/network/api_client.dart';
import 'package:pos_flutter/core/network/network_models.dart';
import 'package:pos_flutter/core/persistence/daos/active_pos_session_dao.dart';
import 'package:pos_flutter/core/persistence/daos/audit_dao.dart';
import 'package:pos_flutter/core/persistence/daos/auth_dao.dart';
import 'package:pos_flutter/core/persistence/daos/catalog_dao.dart';
import 'package:pos_flutter/core/persistence/daos/invoice_print_history_dao.dart';
import 'package:pos_flutter/core/persistence/daos/master_data_dao.dart';
import 'package:pos_flutter/core/persistence/daos/payment_profile_dao.dart';
import 'package:pos_flutter/core/persistence/daos/print_job_dao.dart';
import 'package:pos_flutter/core/persistence/daos/printer_profile_dao.dart';
import 'package:pos_flutter/core/persistence/daos/sales_dao.dart';
import 'package:pos_flutter/core/persistence/daos/shift_dao.dart';
import 'package:pos_flutter/core/persistence/daos/sync_dao.dart';
import 'package:pos_flutter/core/persistence/database.dart';
import 'package:pos_flutter/core/services/master_data/master_data_mapper.dart';
import 'package:pos_flutter/core/services/readiness/catalog_readiness_service.dart';
import 'package:pos_flutter/core/persistence/pos_config_repository.dart';
import 'package:pos_flutter/core/services/invoice_number_service.dart';
import 'package:pos_flutter/core/services/master_data/master_data_sync_service.dart';
import 'package:pos_flutter/core/services/permission_service.dart';
import 'package:pos_flutter/core/services/pos_devices/payment_profile_service.dart';
import 'package:pos_flutter/core/services/pos_devices/print_job_processor.dart';
import 'package:pos_flutter/core/services/pos_devices/print_job_service.dart';
import 'package:pos_flutter/core/services/pos_devices/print_queue.dart';
import 'package:pos_flutter/core/services/pos_devices/printer_adapter_factory.dart';
import 'package:pos_flutter/core/services/pos_devices/printer_profile_service.dart';
import 'package:pos_flutter/core/services/pos_devices/runtime_platform.dart';
import 'package:pos_flutter/core/services/invoices/invoice_archive_repository.dart';
import 'package:pos_flutter/core/services/invoices/invoice_document_builder.dart';
import 'package:pos_flutter/core/services/invoices/invoice_pdf_exporter.dart';
import 'package:pos_flutter/core/services/installation/app_installation_service.dart';
import 'package:pos_flutter/core/services/sync/db_sync_service.dart';
import 'package:pos_flutter/core/services/sync/upload_queue.dart';
import 'package:pos_flutter/core/services/time/clock.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final apiClientProvider = Provider<LocalApiClient>((ref) {
  return LocalApiClient();
});

final syncProfileProvider = FutureProvider<SyncProfile?>((ref) async {
  return (await ref.watch(runtimeConfigRepositoryProvider).loadSetupConfig())
      .syncProfile;
});

final activePosSessionDaoProvider = Provider<ActivePosSessionDao>((ref) {
  return ActivePosSessionDao(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  );
});

final activePosSessionProvider = StreamProvider<ActivePosSession?>((ref) {
  return ref.watch(activePosSessionDaoProvider).watchActive();
});

final activeUserProvider = Provider<ActivePosSession>((ref) {
  final session = ref.watch(activePosSessionProvider).valueOrNull;
  if (session == null) throw StateError('Active POS session is not selected.');
  return session;
});

final activeMachineProvider = Provider<ActivePosSession>((ref) {
  final session = ref.watch(activePosSessionProvider).valueOrNull;
  if (session == null) throw StateError('Active POS session is not selected.');
  return session;
});

final authDaoProvider = Provider<AuthDao>((ref) {
  return AuthDao(ref.watch(databaseProvider));
});

final catalogDaoProvider = Provider<CatalogDao>((ref) {
  return CatalogDao(ref.watch(databaseProvider));
});

final masterDataDaoProvider = Provider<MasterDataDao>((ref) {
  return MasterDataDao(ref.watch(databaseProvider));
});

final shiftDaoProvider = Provider<ShiftDao>((ref) {
  return ShiftDao(ref.watch(databaseProvider));
});

final salesDaoProvider = Provider<SalesDao>((ref) {
  return SalesDao(ref.watch(databaseProvider));
});

final syncDaoProvider = Provider<SyncDao>((ref) {
  return SyncDao(ref.watch(databaseProvider), clock: ref.watch(clockProvider));
});

final auditDaoProvider = Provider<AuditDao>((ref) {
  return AuditDao(ref.watch(databaseProvider), clock: ref.watch(clockProvider));
});

final printerProfileDaoProvider = Provider<PrinterProfileDao>((ref) {
  return PrinterProfileDao(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  );
});

final paymentProfileDaoProvider = Provider<PaymentProfileDao>((ref) {
  return PaymentProfileDao(ref.watch(databaseProvider));
});

final printJobDaoProvider = Provider<PrintJobDao>((ref) {
  return PrintJobDao(ref.watch(databaseProvider));
});

final invoicePrintHistoryDaoProvider = Provider<InvoicePrintHistoryDao>((ref) {
  return InvoicePrintHistoryDao(ref.watch(databaseProvider));
});

final posConfigRevisionProvider = StateProvider<int>((ref) => 0);

final posConfigProvider = Provider<PosConfigRepository>((ref) {
  return PosConfigRepository(
    ref.watch(databaseProvider),
    onChanged: () {
      ref.read(posConfigRevisionProvider.notifier).state++;
    },
  );
});

final appInstallationServiceProvider = Provider<AppInstallationService>((ref) {
  return AppInstallationService(
    db: ref.watch(databaseProvider),
  );
});

final clockProvider = Provider<Clock>((ref) {
  return const SystemClock();
});

final businessDateServiceProvider = Provider<BusinessDateService>((ref) {
  return BusinessDateService(clock: ref.watch(clockProvider));
});

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService(ref.watch(authDaoProvider));
});

final invoiceNumberServiceProvider = Provider<InvoiceNumberService>((ref) {
  return InvoiceNumberService(
    ref.watch(salesDaoProvider),
  );
});

final uploadQueueProvider = Provider<UploadQueue>((ref) {
  return const UploadQueue();
});

final dbSyncServiceProvider = Provider<DbSyncService>((ref) {
  return DbSyncService(
    syncDao: ref.watch(syncDaoProvider),
    auditDao: ref.watch(auditDaoProvider),
    apiClient: ref.watch(apiClientProvider),
  );
});

final masterDataMapperProvider = Provider<MasterDataMapper>((ref) {
  return MasterDataMapper();
});

final masterDataSyncServiceProvider = Provider<MasterDataSyncService>((ref) {
  return MasterDataSyncService(
    apiClient: ref.watch(apiClientProvider),
    masterDataDao: ref.watch(masterDataDaoProvider),
    auditDao: ref.watch(auditDaoProvider),
    mapper: ref.watch(masterDataMapperProvider),
    clock: ref.watch(clockProvider),
  );
});

final appPlatformProvider = Provider((ref) => currentAppPlatform());

final printerAdapterFactoryProvider = Provider<PrinterAdapterFactory>((ref) {
  return PrinterAdapterFactory(platform: ref.watch(appPlatformProvider));
});

final printerProfileServiceProvider = Provider<PrinterProfileService>((ref) {
  return PrinterProfileService(
    dao: ref.watch(printerProfileDaoProvider),
    adapterFactory: ref.watch(printerAdapterFactoryProvider),
  );
});

final paymentProfileServiceProvider = Provider<PaymentProfileService>((ref) {
  return PaymentProfileService(dao: ref.watch(paymentProfileDaoProvider));
});

final invoiceDocumentBuilderProvider = Provider<InvoiceDocumentBuilder>((ref) {
  return InvoiceDocumentBuilder(
    salesDao: ref.watch(salesDaoProvider),
    archiveRepository: InvoiceArchiveRepository(
      db: ref.watch(databaseProvider),
    ),
  );
});

final invoicePdfExporterProvider = Provider<InvoicePdfExporter>((ref) {
  return const InvoicePdfExporter();
});

final printQueueProvider = Provider<PrintQueue>((ref) {
  return PrintQueue(
    printerProfileDao: ref.watch(printerProfileDaoProvider),
  );
});

final printJobServiceProvider = Provider<PrintJobService>((ref) {
  return PrintJobService(
    printJobDao: ref.watch(printJobDaoProvider),
    printerProfileDao: ref.watch(printerProfileDaoProvider),
    clock: ref.watch(clockProvider),
  );
});

final printJobProcessorProvider = Provider<PrintJobProcessor>((ref) {
  return PrintJobProcessor(
    printJobDao: ref.watch(printJobDaoProvider),
    printerProfileDao: ref.watch(printerProfileDaoProvider),
    adapterFactory: ref.watch(printerAdapterFactoryProvider),
    printHistoryDao: ref.watch(invoicePrintHistoryDaoProvider),
  );
});

final printerProfilesProvider = StreamProvider((ref) {
  return ref.watch(printerProfileDaoProvider).watchAll();
});

final activePaymentProfileProvider = StreamProvider((ref) {
  return ref.watch(paymentProfileDaoProvider).watchActive();
});

final manualPaymentProfileProvider = StreamProvider((ref) {
  return ref.watch(paymentProfileDaoProvider).watchManualProfile();
});

final retryablePrintJobsProvider = StreamProvider((ref) {
  return ref.watch(printJobDaoProvider).watchRetryable();
});

final catalogReadinessServiceProvider = Provider<CatalogReadinessService>((
  ref,
) {
  return CatalogReadinessService(
    catalogDao: ref.watch(catalogDaoProvider),
    activeSession: ref.watch(activePosSessionProvider).valueOrNull,
  );
});

/// WHY: FutureProvider so the router and UI can reactively gate on
/// catalog readiness. Invalidated when config changes (posConfigRevision).
final catalogReadinessProvider = FutureProvider.autoDispose<CatalogReadiness>((
  ref,
) async {
  // Re-evaluate whenever config changes (e.g. after sync).
  ref.watch(posConfigRevisionProvider);
  return ref.watch(catalogReadinessServiceProvider).check();
});

final runtimeConfigRepositoryProvider = Provider<RuntimeConfigRepository>((
  ref,
) {
  return RuntimeConfigRepository();
});
