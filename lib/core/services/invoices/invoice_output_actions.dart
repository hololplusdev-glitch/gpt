import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_flutter/core/persistence/daos/print_job_dao.dart';
import 'package:pos_flutter/core/services/invoices/invoice_document.dart';
import 'package:pos_flutter/core/services/invoices/invoice_document_builder.dart';
import 'package:pos_flutter/core/services/invoices/invoice_pdf_exporter.dart';
import 'package:pos_flutter/core/services/pos_devices/print_job_processor.dart';
import 'package:pos_flutter/core/services/pos_devices/print_job_service.dart';
import 'package:pos_flutter/core/services/pos_devices/print_queue.dart';
import 'package:pos_flutter/core/services/time/clock.dart';
import 'package:pos_flutter/shared/models/enums.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';
import 'package:share_plus/share_plus.dart';

class InvoiceOutputActions {
  final InvoiceDocumentBuilder _documentBuilder;
  final InvoicePdfExporter _pdfExporter;
  final PrintQueue _printQueue;
  final PrintJobService _printJobService;
  final PrintJobProcessor _printJobProcessor;
  final PrintJobDao _printJobDao;
  final Clock _clock;

  const InvoiceOutputActions({
    required InvoiceDocumentBuilder documentBuilder,
    required InvoicePdfExporter pdfExporter,
    required PrintQueue printQueue,
    required PrintJobService printJobService,
    required PrintJobProcessor printJobProcessor,
    required PrintJobDao printJobDao,
    Clock clock = const SystemClock(),
  }) : _documentBuilder = documentBuilder,
       _pdfExporter = pdfExporter,
       _printQueue = printQueue,
       _printJobService = printJobService,
       _printJobProcessor = printJobProcessor,
       _printJobDao = printJobDao,
       _clock = clock;

  Future<InvoiceDocument> getOrCreateOriginal(String saleId) {
    return _documentBuilder.getOrCreateOriginal(saleId);
  }

  Future<InvoicePrintResult> printOriginal(
    String saleId, {
    String? createdBy,
    bool requireAutoPrint = false,
  }) async {
    final originalJobs = await _printJobDao.getOriginalJobs(saleId);

    final hasPrintedOriginal = originalJobs.any(
      (job) => job.status == PrintJobStatus.printed.code,
    );

    if (hasPrintedOriginal) {
      return reprint(saleId, createdBy: createdBy);
    }

    final retryableOriginalJobIds = originalJobs
        .where(
          (job) =>
              (job.status == PrintJobStatus.pending.code ||
                  job.status == PrintJobStatus.failed.code) &&
              job.attempts < job.maxAttempts,
        )
        .map((job) => job.id)
        .toList();

    if (retryableOriginalJobIds.isNotEmpty) {
      return _processJobs(retryableOriginalJobIds);
    }

    final document = await getOrCreateOriginal(saleId);
    final jobIds = await _printQueue.enqueueInvoiceReceipt(
      document: document,
      createdAt: _clock.now(),
      createdBy: createdBy,
      requireAutoPrint: requireAutoPrint,
    );

    return _processJobs(jobIds);
  }

  Future<InvoicePrintResult> reprint(String saleId, {String? createdBy}) async {
    final original = await getOrCreateOriginal(saleId);
    final copyNumber = await _printJobService.nextCopyNumber(saleId);

    final copy = original.copyWithCopyInfo(
      InvoiceCopyInfo.reprint(copyNumber: copyNumber),
    );

    final jobIds = await _printQueue.enqueueInvoiceReceipt(
      document: copy,
      createdAt: _clock.now(),
      createdBy: createdBy,
      documentType: PrintDocumentType.invoiceReceiptCopy,
    );

    return _processJobs(jobIds);
  }

  Future<File> savePdf(String saleId) async {
    final document = await getOrCreateOriginal(saleId);
    return _pdfExporter.save(document);
  }

  Future<File> sharePdf(String saleId) async {
    final document = await getOrCreateOriginal(saleId);
    final file = await _pdfExporter.save(document);

    await Share.shareXFiles([
      XFile(
        file.path,
        mimeType: 'application/pdf',
        name: 'invoice-${document.localInvoiceNo}.pdf',
      ),
    ], text: 'فاتورة ${document.localInvoiceNo}');

    return file;
  }

  Future<InvoicePrintResult> _processJobs(List<String> jobIds) async {
    if (jobIds.isEmpty) {
      return const InvoicePrintResult(
        total: 0,
        failed: 1,
        noEligiblePrinter: true,
        message: 'لا توجد طابعة مفعلة.',
      );
    }

    final result = await _printJobProcessor.processJobIds(jobIds);

    if (result.total == 0) {
      return const InvoicePrintResult(
        total: 0,
        failed: 1,
        noEligiblePrinter: true,
        message: 'لا توجد طابعة مفعلة.',
      );
    }

    if (result.failed > 0) {
      return InvoicePrintResult(
        total: result.total,
        failed: result.failed,
        message: 'تم حفظ الفاتورة، لكن فشلت الطباعة.',
      );
    }

    return InvoicePrintResult(
      total: result.total,
      failed: result.failed,
      message: 'تم إرسال الفاتورة للطباعة.',
    );
  }
}

class InvoicePrintResult {
  final int total;
  final int failed;
  final bool noEligiblePrinter;
  final String? message;

  const InvoicePrintResult({
    required this.total,
    required this.failed,
    this.noEligiblePrinter = false,
    this.message,
  });

  int get succeeded => total - failed;

  bool get hasFailures {
    return noEligiblePrinter || total == 0 || failed > 0;
  }
}

final invoiceOutputActionsProvider = Provider<InvoiceOutputActions>((ref) {
  return InvoiceOutputActions(
    documentBuilder: ref.watch(invoiceDocumentBuilderProvider),
    pdfExporter: ref.watch(invoicePdfExporterProvider),
    printQueue: ref.watch(printQueueProvider),
    printJobService: ref.watch(printJobServiceProvider),
    printJobProcessor: ref.watch(printJobProcessorProvider),
    printJobDao: ref.watch(printJobDaoProvider),
    clock: ref.watch(clockProvider),
  );
});
