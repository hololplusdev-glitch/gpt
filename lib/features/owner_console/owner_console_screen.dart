import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:holol_POS/core/l10n/app_localizations.dart';
import 'package:holol_POS/features/owner_console/local_db_inspector_repository.dart';
import 'package:holol_POS/shared/presentation/utils/app_snackbar.dart';
import 'package:holol_POS/shared/presentation/widgets/app_loading.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
import 'package:holol_POS/shared/refactor/pos_ui_widgets.dart';

final localDbInspectorRepositoryProvider = Provider<LocalDbInspectorRepository>(
  (ref) {
    return LocalDbInspectorRepository(ref.watch(databaseProvider));
  },
);

class OwnerConsoleScreen extends StatelessWidget {
  const OwnerConsoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ownerConsole),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/login'),
            icon: const Icon(Icons.logout),
            label: Text(l10n.exit),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.ownerTools,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(l10n.ownerConsoleReadOnlyNotice),
                const SizedBox(height: 24),
                AppActionTile(
                  icon: Icons.table_chart_outlined,
                  title: l10n.localTables,
                  subtitle: l10n.localTablesSubtitle,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _LocalTablesMenuScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                AppActionTile(
                  icon: Icons.rule_folder_outlined,
                  title: l10n.diagnosticFilters,
                  subtitle: l10n.diagnosticFiltersSubtitle,
                  onTap: null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocalTablesMenuScreen extends ConsumerStatefulWidget {
  const _LocalTablesMenuScreen();

  @override
  ConsumerState<_LocalTablesMenuScreen> createState() =>
      _LocalTablesMenuScreenState();
}

class _LocalTablesMenuScreenState
    extends ConsumerState<_LocalTablesMenuScreen> {
  bool _loading = false;
  String? _error;
  List<InspectorTableInfo> _tables = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadTables);
  }

  Future<void> _loadTables() async {
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(localDbInspectorRepositoryProvider);
      final tables = await repo.listTables();

      if (!mounted) return;

      setState(() {
        _tables = tables;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = l10n.failedToLoadTables(error.toString()));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Map<String, List<InspectorTableInfo>> _groupTables() {
    final grouped = <String, List<InspectorTableInfo>>{};

    for (final table in _tables) {
      grouped.putIfAbsent(table.category, () => []).add(table);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final grouped = _groupTables();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.localTables),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: _loading ? null : _loadTables,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(grouped),
    );
  }

  Widget _buildBody(Map<String, List<InspectorTableInfo>> grouped) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading && _tables.isEmpty) {
      return const AppLoading();
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }

    if (_tables.isEmpty) {
      return Center(child: Text(l10n.noTables));
    }

    return RefreshIndicator(
      onRefresh: _loadTables,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.selectTableRawData,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          for (final entry in grouped.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Text(
                entry.key,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final table in entry.value)
                  _TableButton(
                    table: table,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _TableRowsScreen(table: table),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TableButton extends StatelessWidget {
  const _TableButton({required this.table, required this.onTap});

  final InspectorTableInfo table;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 260,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Text(table.icon, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        table.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        table.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('${table.rowCount}'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TableRowsScreen extends ConsumerStatefulWidget {
  const _TableRowsScreen({required this.table});

  final InspectorTableInfo table;

  @override
  ConsumerState<_TableRowsScreen> createState() => _TableRowsScreenState();
}

class _TableRowsScreenState extends ConsumerState<_TableRowsScreen> {
  List<InspectorColumnInfo> _columns = [];
  List<Map<String, Object?>> _rows = [];

  String? _sortColumn;
  bool _sortDescending = true;
  bool _loading = false;
  String? _error;

  int _totalRows = 0;
  int _offset = 0;
  final int _limit = 50;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadRows);
  }

  Future<void> _loadRows() async {
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(localDbInspectorRepositoryProvider);
      final columns = await repo.listColumns(widget.table.name);

      final defaultSort = _sortColumn ?? _defaultSortColumn(columns);

      final totalRows = await repo.countRows(tableName: widget.table.name);

      final rows = await repo.readRows(
        tableName: widget.table.name,
        limit: _limit,
        offset: _offset,
        orderBy: defaultSort,
        descending: _sortDescending,
      );

      if (!mounted) return;

      setState(() {
        _columns = columns;
        _sortColumn = defaultSort;
        _totalRows = totalRows;
        _rows = rows;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = l10n.failedToLoadTableRows(error.toString()));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String? _defaultSortColumn(List<InspectorColumnInfo> columns) {
    final names = columns.map((column) => column.name).toSet();

    if (names.contains('created_at')) return 'created_at';
    if (names.contains('createdAt')) return 'createdAt';
    if (names.contains('updated_at')) return 'updated_at';
    if (names.contains('id')) return 'id';

    final primaryKey = columns.where((column) => column.isPrimaryKey).toList();
    if (primaryKey.isNotEmpty) return primaryKey.first.name;

    return columns.isEmpty ? null : columns.first.name;
  }

  void _sortByColumn(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortDescending = !_sortDescending;
      } else {
        _sortColumn = column;
        _sortDescending = true;
      }
      _offset = 0;
    });

    _loadRows();
  }

  void _nextPage() {
    if (_offset + _limit >= _totalRows) return;

    setState(() => _offset += _limit);
    _loadRows();
  }

  void _previousPage() {
    if (_offset <= 0) return;

    setState(() {
      _offset -= _limit;
      if (_offset < 0) _offset = 0;
    });

    _loadRows();
  }

  Future<void> _copyRowJson(Map<String, Object?> row) async {
    final l10n = AppLocalizations.of(context)!;
    final json = const JsonEncoder.withIndent(
      '  ',
    ).convert(inspectorRowToJsonFriendly(row));

    await Clipboard.setData(ClipboardData(text: json));

    if (!mounted) return;

    AppSnackbar.showSuccess(context, l10n.rowCopiedAsJson);
  }

  void _showRowDetails(Map<String, Object?> row) {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.35,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.table.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.copyRowJson,
                        onPressed: () => _copyRowJson(row),
                        icon: const Icon(Icons.copy),
                      ),
                      IconButton(
                        tooltip: l10n.close,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: controller,
                    itemCount: row.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = row.entries.elementAt(index);
                      return ListTile(
                        title: Text(entry.key),
                        subtitle: SelectableText(_formatFullValue(entry.value)),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatCell(Object? value) {
    if (value == null) return 'NULL';

    if (value is Uint8List) {
      return 'BLOB(${value.length})';
    }

    final text = value.toString();
    if (text.length > 80) {
      return '${text.substring(0, 80)}…';
    }

    return text;
  }

  String _formatFullValue(Object? value) {
    if (value == null) return 'NULL';

    if (value is Uint8List) {
      return 'BLOB(${value.length} bytes)';
    }

    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sortColumnIndex = _sortColumn == null
        ? null
        : _columns.indexWhere((column) => column.name == _sortColumn);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.table.title),
            Text(
              widget.table.name,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: _loading ? null : _loadRows,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPaginationBar(),
          const Divider(height: 1),
          Expanded(
            child: Stack(
              children: [
                if (_error != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  )
                else if (_columns.isEmpty && _loading)
                  const AppLoading()
                else if (_rows.isEmpty && !_loading)
                  Center(child: Text(l10n.noRows))
                else
                  Scrollbar(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          sortColumnIndex:
                              sortColumnIndex == null || sortColumnIndex < 0
                              ? null
                              : sortColumnIndex,
                          sortAscending: !_sortDescending,
                          columns: [
                            for (final column in _columns)
                              DataColumn(
                                label: Tooltip(
                                  message:
                                      '${column.name}\n${column.type}'
                                      '${column.isPrimaryKey ? '\nPRIMARY KEY' : ''}'
                                      '${column.notNull ? '\nNOT NULL' : ''}',
                                  child: Text(column.name),
                                ),
                                onSort: (_, __) => _sortByColumn(column.name),
                              ),
                          ],
                          rows: [
                            for (final row in _rows)
                              DataRow(
                                onSelectChanged: (_) => _showRowDetails(row),
                                cells: [
                                  for (final column in _columns)
                                    DataCell(
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 240,
                                        ),
                                        child: Text(
                                          _formatCell(row[column.name]),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_loading)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Color(0x22000000),
                        child: AppLoading(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationBar() {
    final l10n = AppLocalizations.of(context)!;
    final from = _totalRows == 0 ? 0 : _offset + 1;
    final to = (_offset + _rows.length).clamp(0, _totalRows);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final info = Text(
            l10n.rowsRange(widget.table.name, from, to, _totalRows),
            overflow: TextOverflow.ellipsis,
          );

          final controls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: l10n.previousPage,
                onPressed: _offset <= 0 || _loading ? null : _previousPage,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: l10n.nextPage,
                onPressed: _offset + _limit >= _totalRows || _loading
                    ? null
                    : _nextPage,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          );

          if (constraints.maxWidth < 360) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                Align(alignment: Alignment.centerRight, child: controls),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: info),
              controls,
            ],
          );
        },
      ),
    );
  }
}
