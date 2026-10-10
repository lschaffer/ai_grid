import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:trina_grid/trina_grid.dart';
import '../models/ai_grid_column.dart';
import '../models/ai_grid_data_source.dart';

/// Controller coordinating grid state, grouping, filtering, sorting,
/// column visibility, and introspection for AI Assistant tools.
class AiGridController extends ChangeNotifier {
  TrinaGridStateManager? _stateManager;
  AiGridDataSource? _dataSource;
  List<AiGridColumn> _columns = [];

  List<String> _activeGrouping = [];
  final Map<String, Map<String, dynamic>> _activeFilters = {};
  String? _activeSortColumn;
  bool _isSortDescending = false;
  String _searchQuery = '';
  bool _showColumnFilterRow = true;
  bool _showGroupPanel = true;
  bool _showAiAssistant = false;

  /// Underlying TrinaGridStateManager if attached.
  TrinaGridStateManager? get stateManager => _stateManager;

  /// Grid columns defined for this DataGrid.
  List<AiGridColumn> get columns => _columns;

  /// Currently active grouping fields (hierarchical).
  List<String> get activeGrouping => List.unmodifiable(_activeGrouping);

  /// Active column filters keyed by column field name.
  Map<String, Map<String, dynamic>> get activeFilters =>
      Map.unmodifiable(_activeFilters);

  /// Active sort column field name.
  String? get activeSortColumn => _activeSortColumn;

  /// Whether current sort is descending.
  bool get isSortDescending => _isSortDescending;

  /// Active global search query.
  String get searchQuery => _searchQuery;

  /// Whether the inline column filter row is visible.
  bool get showColumnFilterRow => _showColumnFilterRow;

  /// Whether the top group panel is visible.
  bool get showGroupPanel => _showGroupPanel;

  /// Whether the AI Assistant panel is visible.
  bool get showAiAssistant => _showAiAssistant;

  /// Attaches the controller to the rendered grid state.
  void attach({
    TrinaGridStateManager? stateManager,
    required List<AiGridColumn> columns,
    required AiGridDataSource dataSource,
  }) {
    _stateManager = stateManager;
    _columns = columns;
    _dataSource = dataSource;
    notifyListeners();
  }

  /// Resolves field name flexibly (case-insensitive or title).
  String? _resolveField(String name) {
    final clean = name.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    if (_stateManager != null) {
      for (final col in _stateManager!.columns) {
        if (col.field.toLowerCase() == clean ||
            col.field.toLowerCase() == name.toLowerCase() ||
            col.title.toLowerCase().replaceAll(' ', '') == clean ||
            col.title.toLowerCase() == name.toLowerCase()) {
          return col.field;
        }
      }
    }
    for (final col in _columns) {
      if (col.field.toLowerCase() == clean ||
          col.field.toLowerCase() == name.toLowerCase() ||
          col.title.toLowerCase().replaceAll(' ', '') == clean ||
          col.title.toLowerCase() == name.toLowerCase()) {
        return col.field;
      }
    }
    return name;
  }

  /// Sets multi-level hierarchical grouping by column fields.
  void setGrouping(List<String> fields) {
    _activeGrouping = List.from(fields);
    if (_stateManager != null) {
      if (fields.isEmpty) {
        _stateManager!.setRowGroup(null);
      } else {
        final groupColumns = <TrinaColumn>[];
        for (final f in fields) {
          final actual = _resolveField(f) ?? f;
          final c = _stateManager!.columns.firstWhere(
            (col) => col.field == actual,
            orElse: () => _stateManager!.columns.first,
          );
          groupColumns.add(c);
        }
        _stateManager!.setRowGroup(
          TrinaRowGroupByColumnDelegate(
            columns: groupColumns,
            showFirstExpandableIcon: true,
            showCount: true,
            enableCompactCount: true,
          ),
        );
        _stateManager!.expandAllRowGroups();
      }
    }
    notifyListeners();
  }

  /// Adds a column to active grouping.
  void addGroup(String field) {
    final actual = _resolveField(field) ?? field;
    if (!_activeGrouping.contains(actual)) {
      final updated = List<String>.from(_activeGrouping)..add(actual);
      setGrouping(updated);
    }
  }

  /// Removes a column from active grouping.
  void removeGroup(String field) {
    final actual = _resolveField(field) ?? field;
    if (_activeGrouping.contains(actual)) {
      final updated = List<String>.from(_activeGrouping)..remove(actual);
      setGrouping(updated);
    }
  }

  /// Clears all active grouping.
  void clearGrouping() {
    setGrouping([]);
  }

  TrinaFilterType _resolveFilterType(String operator) {
    final clean = operator.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    switch (clean) {
      case 'notequals':
      case 'neq':
      case 'ne':
      case '!=':
      case '<>':
      case 'not':
        return const TrinaFilterTypeNotEquals();
      case 'notcontains':
      case 'doesnotcontain':
      case '!contains':
      case 'exclude':
      case 'excludes':
        return const TrinaFilterTypeDoesNotContain();
      case 'equals':
      case 'eq':
      case '=':
      case '==':
        return const TrinaFilterTypeEquals();
      case 'startswith':
        return const TrinaFilterTypeStartsWith();
      case 'endswith':
        return const TrinaFilterTypeEndsWith();
      case 'greaterthan':
      case 'gt':
      case '>':
        return const TrinaFilterTypeGreaterThan();
      case 'greaterthanorequalto':
      case 'gte':
      case '>=':
        return const TrinaFilterTypeGreaterThanOrEqualTo();
      case 'lessthan':
      case 'lt':
      case '<':
        return const TrinaFilterTypeLessThan();
      case 'lessthanorequalto':
      case 'lte':
      case '<=':
        return const TrinaFilterTypeLessThanOrEqualTo();
      case 'contains':
      default:
        return const TrinaFilterTypeContains();
    }
  }

  void _applyActiveFilters() {
    if (_stateManager == null) return;
    if (_activeFilters.isEmpty) {
      _stateManager!.setFilterWithFilterRows([]);
      return;
    }

    final filterRows = _activeFilters.entries.map((entry) {
      final field = entry.key;
      final op = (entry.value['operator'] as String?) ?? 'contains';
      final val = entry.value['value']?.toString() ?? '';
      return FilterHelper.createFilterRow(
        columnField: field,
        filterType: _resolveFilterType(op),
        filterValue: val,
      );
    }).toList();

    _stateManager!.setFilterWithFilterRows(filterRows);
  }

  /// Applies a column filter programmatically, preserving other active column filters (AND logic).
  void setFilter(
    String field, {
    required String operator,
    required dynamic value,
  }) {
    final actualField = _resolveField(field) ?? field;
    _activeFilters[actualField] = {
      'operator': operator,
      'value': value,
    };
    _applyActiveFilters();
    notifyListeners();
  }

  /// Applies multiple column filters at once joined by AND.
  /// If [replace] is true, existing filters are cleared first.
  void setFilters(
    List<Map<String, dynamic>> filters, {
    bool replace = false,
  }) {
    if (replace) {
      _activeFilters.clear();
    }
    for (final f in filters) {
      final field = (f['column'] ?? f['field']) as String?;
      if (field == null) continue;
      final actualField = _resolveField(field) ?? field;
      final op = (f['operator'] as String?) ?? 'contains';
      final val = f['value'];
      _activeFilters[actualField] = {
        'operator': op,
        'value': val,
      };
    }
    _applyActiveFilters();
    notifyListeners();
  }

  /// Removes filter from a specific column.
  void removeFilter(String field) {
    final actualField = _resolveField(field) ?? field;
    _activeFilters.remove(actualField);
    _applyActiveFilters();
    notifyListeners();
  }

  /// Clears all column filters.
  void clearAllFilters() {
    _activeFilters.clear();
    _stateManager?.clearAllColumnFilters();
    _applyActiveFilters();
    notifyListeners();
  }

  /// Performs an in-built mathematical calculation over grid rows without LLM hallucinations.
  Map<String, dynamic> calculate({
    required String field,
    required String operation,
    bool filteredOnly = true,
    String? groupBy,
  }) {
    if (_stateManager == null && _dataSource == null) {
      return {'error': 'Grid is not initialized'};
    }

    final actualField = _resolveField(field) ?? field;
    final String columnTitle = _stateManager?.columns
            .firstWhere((c) => c.field == actualField,
                orElse: () => _stateManager!.columns.first)
            .title ??
        _columns
            .firstWhere((c) => c.field == actualField,
                orElse: () => _columns.isNotEmpty
                    ? _columns.first
                    : const AiGridColumn(field: '', title: ''))
            .title;

    final TrinaColumn? trinaCol = _stateManager?.columns.firstWhere(
      (c) => c.field == actualField,
      orElse: () => _stateManager!.columns.first,
    );

    if (groupBy != null && groupBy.isNotEmpty) {
      final actualGroupField = _resolveField(groupBy) ?? groupBy;
      final String groupTitle = _stateManager?.columns
              .firstWhere((c) => c.field == actualGroupField,
                  orElse: () => _stateManager!.columns.first)
              .title ??
          _columns
              .firstWhere((c) => c.field == actualGroupField,
                  orElse: () => _columns.isNotEmpty
                      ? _columns.first
                      : const AiGridColumn(field: '', title: ''))
              .title;

      final groups = <dynamic, List<num>>{};

      if (_stateManager != null) {
        final rows = filteredOnly
            ? _stateManager!.refRows
            : _stateManager!.refRows.originalList;
        for (final row in rows) {
          if (row.type.isGroup) continue;
          final gVal = row.cells[actualGroupField]?.value ?? 'Unknown';
          final val = row.cells[actualField]?.value;
          if (val is num) {
            groups.putIfAbsent(gVal, () => []).add(val);
          } else if (val != null) {
            final parsed = num.tryParse(
                val.toString().replaceAll(RegExp(r'[^0-9.-]'), ''));
            if (parsed != null) {
              groups.putIfAbsent(gVal, () => []).add(parsed);
            }
          }
        }
      } else if (_dataSource is LocalAiGridDataSource) {
        final rawRows = (_dataSource as LocalAiGridDataSource).data;
        for (final item in rawRows) {
          final gVal = item[actualGroupField] ?? 'Unknown';
          final val = item[actualField];
          if (val is num) {
            groups.putIfAbsent(gVal, () => []).add(val);
          } else if (val != null) {
            final parsed = num.tryParse(
                val.toString().replaceAll(RegExp(r'[^0-9.-]'), ''));
            if (parsed != null) {
              groups.putIfAbsent(gVal, () => []).add(parsed);
            }
          }
        }
      }

      final results = <String, dynamic>{};
      for (final entry in groups.entries) {
        final nums = entry.value;
        results[entry.key.toString()] = _computeStats(nums, operation, trinaCol);
      }

      return {
        'field': actualField,
        'columnTitle': columnTitle,
        'operation': operation,
        'groupedBy': groupTitle,
        'filteredOnly': filteredOnly,
        'results': results,
        'groups': results,
      };
    }

    final numbers = <num>[];
    if (_stateManager != null) {
      final rows = filteredOnly
          ? _stateManager!.refRows
          : _stateManager!.refRows.originalList;
      for (final row in rows) {
        if (row.type.isGroup) continue;
        final val = row.cells[actualField]?.value;
        if (val is num) {
          numbers.add(val);
        } else if (val != null) {
          final parsed =
              num.tryParse(val.toString().replaceAll(RegExp(r'[^0-9.-]'), ''));
          if (parsed != null) numbers.add(parsed);
        }
      }
    } else if (_dataSource is LocalAiGridDataSource) {
      final rawRows = (_dataSource as LocalAiGridDataSource).data;
      for (final item in rawRows) {
        final val = item[actualField];
        if (val is num) {
          numbers.add(val);
        } else if (val != null) {
          final parsed =
              num.tryParse(val.toString().replaceAll(RegExp(r'[^0-9.-]'), ''));
          if (parsed != null) numbers.add(parsed);
        }
      }
    }

    final stats = _computeStats(numbers, operation, trinaCol);
    return {
      'field': actualField,
      'columnTitle': columnTitle,
      'operation': operation,
      'filteredOnly': filteredOnly,
      'rowCount': numbers.length,
      ...stats,
    };
  }

  Map<String, dynamic> _computeStats(
    List<num> numbers,
    String operation,
    TrinaColumn? column,
  ) {
    if (numbers.isEmpty) {
      return {'result': 0.0, 'formatted': '0', 'count': 0};
    }

    final op = operation.toLowerCase();
    num result;
    if (op.contains('avg') || op.contains('mean') || op.contains('average')) {
      final sum = numbers.reduce((a, b) => a + b);
      result = sum / numbers.length;
    } else if (op.contains('sum') || op.contains('total')) {
      result = numbers.reduce((a, b) => a + b);
    } else if (op.contains('min')) {
      result = numbers.reduce(math.min);
    } else if (op.contains('max')) {
      result = numbers.reduce(math.max);
    } else if (op.contains('count')) {
      result = numbers.length;
    } else if (op.contains('median')) {
      final sorted = List<num>.from(numbers)..sort();
      final middle = sorted.length ~/ 2;
      result = sorted.length.isOdd
          ? sorted[middle]
          : (sorted[middle - 1] + sorted[middle]) / 2;
    } else {
      final sum = numbers.reduce((a, b) => a + b);
      result = sum / numbers.length;
    }

    final formatted = column != null
        ? column.formattedValueForDisplay(result)
        : result.toStringAsFixed(2);
    return {
      'result': double.parse(result.toStringAsFixed(2)),
      'formatted': formatted,
      'count': numbers.length,
    };
  }

  /// Applies global text search across all columns.
  void search(String query) {
    _searchQuery = query;
    if (_stateManager != null) {
      if (query.trim().isEmpty) {
        _stateManager!.setFilterWithFilterRows([]);
      } else {
        final filterRow = FilterHelper.createFilterRow(
          columnField: FilterHelper.filterFieldAllColumns,
          filterType: const TrinaFilterTypeContains(),
          filterValue: query.trim(),
        );
        _stateManager!.setFilterWithFilterRows([filterRow]);
      }
    }
    notifyListeners();
  }

  /// Clears global search.
  void clearSearch() {
    search('');
  }

  /// Applies column sorting.
  /// If [append] is true, appends this column as an additional sort level (multi-column sorting).
  void sort(String field, {bool descending = false, bool append = false}) {
    if (_stateManager != null) {
      final actual = _resolveField(field) ?? field;
      final column = _stateManager!.columns.firstWhere(
        (col) => col.field == actual,
        orElse: () => _stateManager!.columns.first,
      );

      if (descending) {
        _stateManager!.sortDescending(column, append: append);
      } else {
        _stateManager!.sortAscending(column, append: append);
      }
    }

    _activeSortColumn = field;
    _isSortDescending = descending;
    notifyListeners();
  }

  /// Sets column sorting (alias for [sort]).
  void setSorting(String field, {bool descending = false, bool append = false}) =>
      sort(field, descending: descending, append: append);

  /// Applies multi-column sorting with a sequence of sort definitions.
  void multiSort(List<Map<String, dynamic>> sortConfigs) {
    if (_stateManager == null || sortConfigs.isEmpty) return;
    _stateManager!.clearSorting(notify: false);

    for (int i = 0; i < sortConfigs.length; i++) {
      final config = sortConfigs[i];
      final field = (config['field'] ?? config['column']) as String?;
      if (field == null) continue;
      final actual = _resolveField(field) ?? field;
      final descending = (config['descending'] as bool?) ?? false;

      final column = _stateManager!.columns.firstWhere(
        (col) => col.field == actual,
        orElse: () => _stateManager!.columns.first,
      );

      if (descending) {
        _stateManager!.sortDescending(column, append: true, notify: false);
      } else {
        _stateManager!.sortAscending(column, append: true, notify: false);
      }
    }

    _stateManager!.notifyListeners(true, _stateManager!.sortAscending.hashCode);
    if (sortConfigs.isNotEmpty) {
      _activeSortColumn =
          (sortConfigs.first['field'] ?? sortConfigs.first['column']) as String?;
      _isSortDescending =
          (sortConfigs.first['descending'] as bool?) ?? false;
    }
    notifyListeners();
  }

  /// Returns the current sorted columns in order of sort priority.
  List<TrinaColumn> get sortedColumns => _stateManager?.sortedColumns ?? [];

  /// Clears column sorting.
  void clearSorting() {
    _stateManager?.clearSorting();
    _activeSortColumn = null;
    _isSortDescending = false;
    notifyListeners();
  }

  /// Sets visibility of a specific column.
  void setColumnVisibility(String field, bool visible) {
    if (_stateManager != null) {
      final actual = _resolveField(field) ?? field;
      final col = _stateManager!.refColumns.originalList
          .where((c) => c.field == actual)
          .firstOrNull;
      if (col != null) {
        _stateManager!.hideColumn(col, !visible);
        notifyListeners();
      }
    }
  }

  /// Sets visibility for multiple columns at once.
  void setColumnsVisibility(Map<String, bool> visibilityMap) {
    if (_stateManager != null) {
      for (final entry in visibilityMap.entries) {
        final actual = _resolveField(entry.key) ?? entry.key;
        final col = _stateManager!.refColumns.originalList
            .where((c) => c.field == actual)
            .firstOrNull;
        if (col != null) {
          _stateManager!.hideColumn(col, !entry.value, notify: false);
        }
      }
      _stateManager!.notifyListeners(true, _stateManager!.hideColumn.hashCode);
      notifyListeners();
    }
  }

  /// Restores visibility of all columns.
  void showAllColumns() {
    if (_stateManager != null) {
      _stateManager!.hideColumns(_stateManager!.refColumns.originalList, false);
      notifyListeners();
    }
  }

  /// Returns the list of currently visible column fields.
  List<String> get visibleColumns {
    if (_stateManager == null) return _columns.map((c) => c.field).toList();
    return _stateManager!.columns.map((c) => c.field).toList();
  }

  /// Returns the list of currently hidden column fields.
  List<String> get hiddenColumns {
    if (_stateManager == null) return [];
    return _stateManager!.refColumns.originalList
        .where((c) => c.hide)
        .map((c) => c.field)
        .toList();
  }

  /// Toggles visibility of the inline filter row.
  void toggleFilterRow() {
    _showColumnFilterRow = !_showColumnFilterRow;
    _stateManager?.setShowColumnFilter(_showColumnFilterRow);
    notifyListeners();
  }

  /// Alias for [toggleFilterRow].
  void toggleColumnFilterRow() => toggleFilterRow();

  /// Toggles visibility of the top group panel.
  void toggleGroupPanel() {
    _showGroupPanel = !_showGroupPanel;
    notifyListeners();
  }

  /// Toggles visibility of the AI Assistant overlay.
  void toggleAiAssistant() {
    _showAiAssistant = !_showAiAssistant;
    notifyListeners();
  }

  /// Sets visibility of the AI Assistant overlay.
  void setAiAssistantVisible(bool visible) {
    _showAiAssistant = visible;
    notifyListeners();
  }

  /// Resets the grid to its default state.
  void reset() {
    clearGrouping();
    clearAllFilters();
    clearSearch();
    clearSorting();
    showAllColumns();
  }

  /// Generates schema metadata for LLM prompt context.
  Map<String, dynamic> getSchemaSummary() {
    return {
      'columns': _columns.map((c) => c.toJson()).toList(),
      'totalRowCount': _dataSource?.totalRowCount ?? 0,
    };
  }

  /// Generates the current state representation for LLM prompt context.
  Map<String, dynamic> getStateSummary() {
    return {
      'activeGrouping': _activeGrouping,
      'activeFilters': _activeFilters,
      'activeSortColumn': _activeSortColumn,
      'isSortDescending': _isSortDescending,
      'searchQuery': _searchQuery,
      'filteredRowCount': _stateManager?.refRows.length ?? 0,
      'visibleColumns': visibleColumns,
      'hiddenColumns': hiddenColumns,
      'sortedColumns': sortedColumns
          .map((c) => {
                'field': c.field,
                'title': c.title,
                'descending': c.sort.isDescending,
                'priority': c.sortPriority,
              })
          .toList(),
    };
  }

  /// Fetches sample data rows for LLM context.
  Future<List<Map<String, dynamic>>> getSampleData({int limit = 5}) async {
    if (_dataSource == null) return [];
    return _dataSource!.getSampleData(limit: limit);
  }
}
