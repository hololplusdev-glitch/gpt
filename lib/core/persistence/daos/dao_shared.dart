import 'dart:convert';

abstract final class DaoText {
  static String? clean(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
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
