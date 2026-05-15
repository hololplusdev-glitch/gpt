import 'package:holol_POS/core/utils/text_normalizer.dart';

abstract final class BackendValueReader {
  static String? text(Object? value) {
    return CoreText.clean(value);
  }

  static bool parseBool(Object? value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value.toString().trim().toUpperCase();
    if (text.isEmpty) return fallback;

    const truthy = {'Y', 'YES', 'TRUE', 'T', '1', 'ACTIVE', 'ENABLED'};
    const falsy = {'N', 'NO', 'FALSE', 'F', '0', 'INACTIVE', 'DISABLED'};

    if (truthy.contains(text)) return true;
    if (falsy.contains(text)) return false;
    return fallback;
  }

  static int? parseInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? parseDecimal(Object? value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }
}
