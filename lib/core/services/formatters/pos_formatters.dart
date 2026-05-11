import 'package:intl/intl.dart';
import 'package:holol_POS/shared/models/enums.dart';

class PosFormatters {
  const PosFormatters._();

  static final DateFormat _dateTime = DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat _dateOnly = DateFormat('yyyy-MM-dd');
  static final DateFormat _timeOnly = DateFormat('HH:mm');

  static const String saudiRiyalSymbol = '\uE900';

  static String amount(num value) =>
      '${value.toStringAsFixed(2)} $saudiRiyalSymbol';

  static String quantity(num value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  static String dateTime(DateTime value) => _dateTime.format(value.toLocal());

  static String dateOnly(DateTime value) => _dateOnly.format(value.toLocal());

  static String timeOnly(DateTime value) => _timeOnly.format(value.toLocal());

  static String dateRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) return '';
    if (start == null) return _dateOnly.format(end!.toLocal());
    if (end == null) return _dateOnly.format(start.toLocal());
    final inclusiveEnd = end.subtract(const Duration(days: 1));
    final startText = _dateOnly.format(start.toLocal());
    final endText = _dateOnly.format(inclusiveEnd.toLocal());
    return startText == endText ? startText : '$startText - $endText';
  }

  static String percent(num value) => '${value.toStringAsFixed(2)}%';

  static String saleStatusLabel(
    String statusCode, {
    String completed = 'مكتمل',
    String synced = 'مكتمل',
    String voided = 'ملغي',
    String refunded = 'مرتجع',
    String draft = 'مسودة',
  }) {
    if (statusCode == 'synced') return synced;
    return switch (SaleStatus.fromCode(statusCode)) {
      SaleStatus.completed => completed,
      SaleStatus.voided => voided,
      SaleStatus.refunded => refunded,
      SaleStatus.draft => draft,
      null => statusCode,
    };
  }

  static String saleSyncStatusLabel(String syncStatusCode) {
    return switch (syncStatusCode) {
      'pending' => 'محفوظة محليًا - رفع الفواتير غير مهيأ بعد',
      'failed' => 'محفوظة محليًا - بانتظار واجهة Backend upload',
      'uploaded' => 'تم الرفع',
      'blocked' => 'محفوظة محليًا - لا توجد واجهة رفع',
      _ => 'محفوظة محليًا',
    };
  }
}
