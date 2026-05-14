import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:holol_POS/core/services/invoices/invoice_document.dart';

class ReceiptFileWriter {
  const ReceiptFileWriter();

  Future<File> savePdfBytes(
    InvoiceDocument document,
    Uint8List pdfBytes,
  ) async {
    if (pdfBytes.isEmpty) {
      throw StateError('Cannot save an empty receipt PDF.');
    }

    final outputDir = await _invoiceDownloadsDirectory();
    await outputDir.create(recursive: true);

    final safeNo = _safeInvoiceNo(document.localInvoiceNo);
    final file = await _nextAvailableFile(outputDir, 'invoice_$safeNo', 'pdf');

    await file.writeAsBytes(pdfBytes, flush: true);
    return file;
  }

  Future<Directory> _invoiceDownloadsDirectory() async {
    final fallback = await getApplicationDocumentsDirectory();

    try {
      Directory? downloads;

      if (Platform.isAndroid) {
        downloads = Directory('/storage/emulated/0/Download');
      } else {
        downloads = await getDownloadsDirectory();
      }

      if (downloads == null) {
        return Directory(
          '${fallback.path}${Platform.pathSeparator}POS_Invoices',
        );
      }

      final publicDir = Directory(
        '${downloads.path}${Platform.pathSeparator}POS_Invoices',
      );

      await publicDir.create(recursive: true);
      return publicDir;
    } catch (_) {
      return Directory('${fallback.path}${Platform.pathSeparator}POS_Invoices');
    }
  }

  String _safeInvoiceNo(String invoiceNo) {
    return invoiceNo.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
  }

  Future<File> _nextAvailableFile(
    Directory dir,
    String baseName,
    String extension,
  ) async {
    var file = File('${dir.path}${Platform.pathSeparator}$baseName.$extension');

    if (!await file.exists()) {
      return file;
    }

    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '_');

    return File(
      '${dir.path}${Platform.pathSeparator}${baseName}_$stamp.$extension',
    );
  }
}
