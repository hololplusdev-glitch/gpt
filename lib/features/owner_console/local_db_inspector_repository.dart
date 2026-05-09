import 'package:drift/drift.dart';
import 'package:pos_flutter/core/persistence/database.dart';

class LocalDbInspectorRepository {
  LocalDbInspectorRepository(this.db);

  final AppDatabase db;

  Future<List<InspectorTableInfo>> listTables() async {
    final rows = await db.customSelect('''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table'
        AND name NOT LIKE 'sqlite_%'
        AND name NOT LIKE 'drift_%'
      ORDER BY name ASC
    ''').get();

    final tables = <InspectorTableInfo>[];

    for (final row in rows) {
      final name = row.data['name'] as String;
      final count = await countRows(tableName: name);
      tables.add(
        InspectorTableInfo(
          name: name,
          title: _titleForTable(name),
          rowCount: count,
          category: _categoryForTable(name),
          icon: _iconForTable(name),
        ),
      );
    }

    return tables;
  }

  String _titleForTable(String tableName) {
    final normalized = tableName.toLowerCase();

    const exact = {
      'sales': 'المبيعات',
      'sale_lines': 'بنود المبيعات',
      'sale_payments': 'دفعات المبيعات',
      'sale_tax_summaries': 'ملخص ضرائب المبيعات',
      'invoice_documents': 'الفواتير المؤرشفة',
      'invoice_print_logs': 'سجل طباعة الفواتير',
      'print_jobs': 'أوامر الطباعة',
      'print_history': 'سجل الطباعة',
      'shifts': 'الشفتات',
      'cash_movements': 'حركات النقد',
      'held_orders': 'الطلبات المعلقة',
      'outbox': 'Outbox / المزامنة الصادرة',
      'sync_runs': 'عمليات المزامنة',
      'audit_logs': 'سجل التدقيق',
      'items': 'الأصناف',
      'item_barcodes': 'باركود الأصناف',
      'item_units': 'وحدات الأصناف',
      'item_prices': 'أسعار الأصناف',
      'customers': 'العملاء',
      'users': 'المستخدمون',
      'payment_methods': 'طرق الدفع',
      'banks': 'البنوك',
      'card_types': 'أنواع البطاقات',
      'stores': 'المخازن',
      'printer_profiles': 'إعدادات الطابعات',
      'pos_devices': 'أجهزة نقاط البيع',
      'pos_config': 'إعدادات نقطة البيع',
    };

    if (exact.containsKey(normalized)) {
      return exact[normalized]!;
    }

    return tableName
        .replaceAll('_', ' ')
        .split(' ')
        .map((part) {
          if (part.isEmpty) return part;
          return '${part[0].toUpperCase()}${part.substring(1)}';
        })
        .join(' ');
  }

  String _categoryForTable(String tableName) {
    final name = tableName.toLowerCase();

    if (name.contains('sale') ||
        name.contains('invoice') ||
        name.contains('payment')) {
      return 'المبيعات والفواتير';
    }

    if (name.contains('shift') ||
        name.contains('cash') ||
        name.contains('held')) {
      return 'الشفتات والنقد';
    }

    if (name.contains('print') ||
        name.contains('device') ||
        name.contains('printer')) {
      return 'الأجهزة والطباعة';
    }

    if (name.contains('sync') || name.contains('outbox')) {
      return 'المزامنة';
    }

    if (name.contains('audit')) {
      return 'التدقيق';
    }

    if (name.contains('item') ||
        name.contains('price') ||
        name.contains('barcode') ||
        name.contains('unit') ||
        name.contains('store')) {
      return 'البيانات الأساسية';
    }

    if (name.contains('user') ||
        name.contains('customer') ||
        name.contains('auth')) {
      return 'المستخدمون والعملاء';
    }

    return 'النظام';
  }

  String _iconForTable(String tableName) {
    final name = tableName.toLowerCase();

    if (name.contains('sale')) return '🧾';
    if (name.contains('invoice')) return '📄';
    if (name.contains('payment')) return '💳';
    if (name.contains('shift')) return '🕘';
    if (name.contains('cash')) return '💵';
    if (name.contains('print') || name.contains('printer')) return '🖨️';
    if (name.contains('sync') || name.contains('outbox')) return '🔁';
    if (name.contains('audit')) return '🧷';
    if (name.contains('item')) return '📦';
    if (name.contains('price')) return '🏷️';
    if (name.contains('barcode')) return '▦';
    if (name.contains('user')) return '👤';
    if (name.contains('customer')) return '👥';
    if (name.contains('device')) return '🖥️';

    return '📋';
  }

  Future<List<InspectorColumnInfo>> listColumns(String tableName) async {
    final safeTable = _quoteIdentifier(tableName);

    final rows = await db.customSelect('PRAGMA table_info($safeTable)').get();

    return rows.map((row) {
      final data = row.data;
      return InspectorColumnInfo(
        name: data['name'] as String,
        type: data['type'] as String? ?? '',
        isPrimaryKey: data['pk'] == 1,
        notNull: data['notnull'] == 1,
      );
    }).toList();
  }

  Future<int> countRows({
    required String tableName,
    String? search,
    List<String>? searchColumns,
  }) async {
    final safeTable = _quoteIdentifier(tableName);
    final columns = await listColumns(tableName);
    final where = _buildSearchWhere(
      search: search,
      columns: _validSearchColumns(columns, searchColumns),
    );

    final row = await db.customSelect('''
      SELECT COUNT(*) AS total
      FROM $safeTable
      ${where.sql}
      ''', variables: where.variables).getSingle();

    return (row.data['total'] as int?) ?? 0;
  }

  Future<List<Map<String, Object?>>> readRows({
    required String tableName,
    int limit = 50,
    int offset = 0,
    String? orderBy,
    bool descending = true,
    String? search,
    List<String>? searchColumns,
  }) async {
    if (limit <= 0 || limit > 500) {
      throw ArgumentError('Invalid limit: $limit');
    }

    if (offset < 0) {
      throw ArgumentError('Invalid offset: $offset');
    }

    final safeTable = _quoteIdentifier(tableName);
    final columns = await listColumns(tableName);
    final columnNames = columns.map((column) => column.name).toSet();

    final safeOrderBy = orderBy != null && columnNames.contains(orderBy)
        ? _quoteIdentifier(orderBy)
        : null;

    final orderClause = safeOrderBy == null
        ? ''
        : 'ORDER BY $safeOrderBy ${descending ? 'DESC' : 'ASC'}';

    final where = _buildSearchWhere(
      search: search,
      columns: _validSearchColumns(columns, searchColumns),
    );

    final rows = await db
        .customSelect(
          '''
      SELECT *
      FROM $safeTable
      ${where.sql}
      $orderClause
      LIMIT ? OFFSET ?
      ''',
          variables: [
            ...where.variables,
            Variable.withInt(limit),
            Variable.withInt(offset),
          ],
        )
        .get();

    return rows.map((row) => Map<String, Object?>.from(row.data)).toList();
  }

  List<String> _validSearchColumns(
    List<InspectorColumnInfo> columns,
    List<String>? requested,
  ) {
    final existing = columns.map((column) => column.name).toSet();

    if (requested == null || requested.isEmpty) {
      return columns.map((column) => column.name).toList();
    }

    return requested.where(existing.contains).toList();
  }

  _SearchWhere _buildSearchWhere({
    required String? search,
    required List<String> columns,
  }) {
    final query = search?.trim();
    if (query == null || query.isEmpty || columns.isEmpty) {
      return const _SearchWhere(sql: '', variables: []);
    }

    final like = '%$query%';
    final parts = columns
        .map((column) => 'CAST(${_quoteIdentifier(column)} AS TEXT) LIKE ?')
        .join(' OR ');

    return _SearchWhere(
      sql: 'WHERE ($parts)',
      variables: List.generate(
        columns.length,
        (_) => Variable.withString(like),
      ),
    );
  }

  String _quoteIdentifier(String value) {
    final validIdentifier = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');
    if (!validIdentifier.hasMatch(value)) {
      throw ArgumentError('Invalid SQLite identifier: $value');
    }

    return '"$value"';
  }
}

class InspectorTableInfo {
  const InspectorTableInfo({
    required this.name,
    required this.title,
    required this.rowCount,
    required this.category,
    required this.icon,
  });

  final String name;
  final String title;
  final int rowCount;
  final String category;
  final String icon;
}

class InspectorColumnInfo {
  const InspectorColumnInfo({
    required this.name,
    required this.type,
    required this.isPrimaryKey,
    required this.notNull,
  });

  final String name;
  final String type;
  final bool isPrimaryKey;
  final bool notNull;
}

class _SearchWhere {
  const _SearchWhere({required this.sql, required this.variables});

  final String sql;
  final List<Variable> variables;
}

Map<String, Object?> inspectorRowToJsonFriendly(Map<String, Object?> row) {
  return row.map((key, value) {
    return MapEntry(key, inspectorValueToJsonFriendly(value));
  });
}

Object? inspectorValueToJsonFriendly(Object? value) {
  if (value == null) return null;

  if (value is DateTime) {
    return value.toIso8601String();
  }

  if (value is Uint8List) {
    return 'BLOB(${value.length} bytes)';
  }

  if (value is BigInt) {
    return value.toString();
  }

  return value;
}
