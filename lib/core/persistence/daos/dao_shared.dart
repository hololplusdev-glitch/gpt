import 'dart:convert';
import 'dart:math';

import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/core/services/master_data/master_data_contract.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:drift/drift.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/utils/text_normalizer.dart';

abstract final class DaoText {
  static String? clean(Object? value) {
    return CoreText.clean(value);
  }

  static String cleanOrEmpty(Object? value) {
    return CoreText.cleanOrEmpty(value);
  }

  static String? firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final cleaned = clean(value);
      if (cleaned != null) return cleaned;
    }
    return null;
  }
}

abstract final class DaoBarcodeRules {
  static List<String> lookupCandidates(String rawCode) {
    final trimmed = rawCode.trim();
    if (trimmed.isEmpty) return const [];

    final candidates = <String>[];

    void add(String value) {
      if (value.isNotEmpty && !candidates.contains(value)) {
        candidates.add(value);
      }
    }

    add(trimmed);
    add(trimmed.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ''));
    add(trimmed.replaceAll(RegExp(r'\s+'), ''));

    final compact = candidates.last;
    if (RegExp(r'^\d{12}$').hasMatch(compact)) {
      add('0$compact');
    }

    return candidates;
  }
}

class DuplicateCatalogBarcodeException implements Exception {
  const DuplicateCatalogBarcodeException();
}

abstract final class DaoShiftCloseSummaryJson {
  static String encode({
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
  }) {
    return jsonEncode({
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
    });
  }
}

abstract final class DaoLocalPinCodec {
  static const String pinPrefix = 'local-pin-v1';

  static void validate(String pin) {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw ArgumentError('PIN must be exactly 4 digits.');
    }
  }

  static String hash(String pin, {required String salt}) {
    final payload = '$salt:$pin';

    var hash = 0xcbf29ce484222325;
    for (final unit in payload.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }

    return '$pinPrefix:$salt:${hash.toRadixString(16)}';
  }

  static String newSalt() {
    final random = Random.secure();
    return List<int>.generate(
      12,
      (_) => random.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

abstract final class DaoProfileStatus {
  static const String ready = 'ready';
  static const String failed = 'failed';

  static String testStatus(bool success) => success ? ready : failed;
}

abstract final class DaoPaymentProfileIds {
  static String manualCard(String userId) => 'manual-card-$userId';
}

abstract final class DaoOutboxSyncPolicy {
  static const String staleUploadingRecoveryMessage =
      'Recovered from stale uploading state.';

  static int compareBySyncPriority(OutboxEvent a, OutboxEvent b) {
    final priorityCompare = syncPriority(a).compareTo(syncPriority(b));
    if (priorityCompare != 0) return priorityCompare;
    return a.createdAt.compareTo(b.createdAt);
  }

  static int syncPriority(OutboxEvent entry) {
    final type = OutboxEventType.fromCode(entry.eventType);

    switch (type) {
      case OutboxEventType.shiftOpened:
        return 10;
      case OutboxEventType.saleCreated:
      case OutboxEventType.returnCreated:
        return 20;
      case OutboxEventType.saleVoided:
        return 30;
      case OutboxEventType.shiftExtended:
        return 40;
      case OutboxEventType.shiftClosed:
        return 50;
      case null:
        return 999;
    }
  }

  static String failureStatus({
    required int retryCount,
    required int maxRetries,
  }) {
    return retryCount >= maxRetries
        ? OutboxStatus.blocked.code
        : OutboxStatus.failed.code;
  }
}

abstract final class DaoMasterDataScope {
  static String key(String typeCode, MasterDataSyncContext context) {
    return '$typeCode::${toJson(context)}';
  }

  static String toJson(MasterDataSyncContext context) {
    return jsonEncode({
      'custCode': context.normalizedCustCode,
      'userId': context.syncUserId,
      if (context.normalizedBranchNo != null)
        'branchNo': context.normalizedBranchNo,
    });
  }

  static String? label(String typeCode, String? scopeJson) {
    if (scopeJson == null || scopeJson.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(scopeJson);
      if (decoded is! Map) return null;

      final userId = decoded['userId']?.toString().trim();
      if (typeCode == MasterDataType.devicePrivilege.code &&
          userId != null &&
          userId.isNotEmpty) {
        return 'usr=$userId';
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}

abstract final class DaoActiveSessionPolicy {
  static bool canLoginUser(PosUser user) {
    return user.isActive && user.canLoginPos;
  }

  static void validateUser(PosUser user) {
    if (!canLoginUser(user)) {
      throw StateError('User is not authorized for POS login.');
    }
  }

  static void validateMachine(PosMachine machine) {
    if (!machine.isActive) {
      throw StateError('Selected POS machine is inactive.');
    }
  }
}

abstract final class DaoPrintJobPolicy {
  static bool isPrinted(PrintJob job) {
    return job.status == PrintJobStatus.printed.code;
  }

  static bool isFailed(PrintJob job) {
    return job.status == PrintJobStatus.failed.code;
  }

  static bool isRetryable(PrintJob job) {
    return (job.status == PrintJobStatus.pending.code ||
            job.status == PrintJobStatus.failed.code) &&
        job.attempts < job.maxAttempts;
  }

  static bool isPrintedOriginal(PrintJob job) {
    return job.documentType == PrintDocumentType.invoiceReceipt.code &&
        job.status == PrintJobStatus.printed.code;
  }

  static bool isPrintedReceiptCopy(PrintJob job) {
    return job.documentType == PrintDocumentType.invoiceReceiptCopy.code &&
        job.status == PrintJobStatus.printed.code;
  }

  static PrintJobsCompanion markPrinted(DateTime printedAt) {
    return PrintJobsCompanion(
      status: Value(PrintJobStatus.printed.code),
      printedAt: Value(printedAt),
      errorMessage: const Value<String?>(null),
    );
  }

  static PrintJobsCompanion markFailed(String error) {
    return PrintJobsCompanion(
      status: Value(PrintJobStatus.failed.code),
      errorMessage: Value(error),
    );
  }

  static PrintJobsCompanion markPending() {
    return PrintJobsCompanion(
      status: Value(PrintJobStatus.pending.code),
      errorMessage: const Value<String?>(null),
    );
  }
}

abstract final class DaoCatalogPricePolicy {
  static BusinessException duplicatePrice({
    required String itemId,
    required String unitId,
  }) {
    return BusinessException(
      'Duplicate item price for item $itemId and unit $unitId.',
      code: 'DUPLICATE_PRICE',
    );
  }
}
