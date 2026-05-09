abstract final class BackendValueReader {
  static String? text(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static bool parseBool(Object? value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().trim().toUpperCase();
    return text == 'Y' || text == 'YES' || text == 'TRUE' || text == '1';
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
