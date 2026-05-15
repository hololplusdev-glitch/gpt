abstract final class CoreText {
  static String? clean(Object? value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }

    return text;
  }

  static String cleanOrEmpty(Object? value) {
    return clean(value) ?? '';
  }

  static String firstUseful(Iterable<Object?> values) {
    for (final value in values) {
      final text = clean(value);
      if (text != null) return text;
    }

    return '';
  }
}
