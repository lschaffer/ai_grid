import 'dart:convert';
import 'dart:math' as math;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import '../fitgrid/fitgrid_table.dart';
import '../models/ai_grid_column.dart';
import '../models/ai_grid_data_source.dart';

/// Controller coordinating grid state, grouping, filtering, sorting,
/// column visibility, and introspection for AI Assistant tools.
class AiGridController extends ChangeNotifier {
  FitGridController<Map<String, dynamic>>? _fitController;
  AiGridDataSource? _dataSource;
  List<AiGridColumn> _columns = [];

  List<String> _activeGrouping = [];
  final Map<String, Map<String, dynamic>> _activeFilters = {};
  String? _activeSortColumn;
  bool _isSortDescending = false;
  final Set<String> _hiddenFields = {};
  String _searchQuery = '';
  bool _showColumnFilterRow = true;
  bool _showGroupPanel = true;
  bool _showAiAssistant = false;
  bool _isApplyingFilters = false;

  /// Underlying FitGridController if attached.
  FitGridController<Map<String, dynamic>>? get fitController => _fitController;

  /// Compatibility getter for legacy callers.
  dynamic get stateManager => _fitController;

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

  /// Whether the controller is attached to an active grid controller.
  bool get isAttached => _fitController != null;

  /// Current page number (1-based index).
  int get page => (_fitController?.pagination.pageIndex ?? 0) + 1;

  /// Total number of pages available.
  int get totalPage => _fitController?.pagination.pageCount ?? 1;

  /// Number of rows per page.
  int get pageSize => _fitController?.pagination.pageSize ?? 40;

  /// Whether pagination is currently active on the grid.
  bool get isPaginated => _fitController?.pagination.enabled ?? false;

  /// Navigates to a specific page number (1-based).
  void setPage(int page) {
    if (_fitController != null && _fitController!.pagination.enabled) {
      _fitController!.pagination.pageIndex = (page - 1).clamp(0, totalPage - 1);
      notifyListeners();
    }
  }

  /// Sets the number of rows displayed per page.
  void setPageSize(int size) {
    if (_fitController != null && _fitController!.pagination.enabled) {
      _fitController!.pagination.pageSize = size;
      notifyListeners();
    }
  }

  void _onFitControllerChanged() {
    notifyListeners();
  }

  /// Attaches the controller to the rendered grid controller and data source.
  void attach({
    FitGridController<Map<String, dynamic>>? fitController,
    required List<AiGridColumn> columns,
    required AiGridDataSource dataSource,
  }) {
    if (_fitController != null && _fitController != fitController && fitController != null) {
      _fitController!.data.removeListener(_onFitControllerChanged);
      _fitController!.columns.removeListener(_onFitControllerChanged);
      _fitController!.filter.removeListener(_onFitFilterChanged);
    }
    _fitController = fitController ??
        _fitController ??
        FitGridController<Map<String, dynamic>>(
          columns: columns.map((c) => c.toFitGridColumn()).toList(),
          rows: dataSource is LocalAiGridDataSource ? dataSource.data : const [],
        );
    _columns = columns;
    _dataSource = dataSource;

    // Seed initial column width overrides if declared and not yet overridden
    for (final col in _columns) {
      if (col.width != null && col.width! > 0 && !_fitController!.columns.isResized(col.field)) {
        _fitController!.columns.setWidth(col.field, col.width!);
      }
    }

    _fitController!.data.removeListener(_onFitControllerChanged);
    _fitController!.columns.removeListener(_onFitControllerChanged);
    _fitController!.filter.removeListener(_onFitFilterChanged);
    _fitController!.data.addListener(_onFitControllerChanged);
    _fitController!.columns.addListener(_onFitControllerChanged);
    _fitController!.filter.addListener(_onFitFilterChanged);

    // Reapply active state if pre-configured
    if (_activeGrouping.isNotEmpty) {
      setGrouping(_activeGrouping);
    }
    if (_activeSortColumn != null) {
      sort(_activeSortColumn!, descending: _isSortDescending);
    }
    if (_searchQuery.isNotEmpty) {
      search(_searchQuery);
    }
    if (_hiddenFields.isNotEmpty) {
      for (final col in _columns) {
        if (_hiddenFields.contains(col.field)) {
          _fitController!.columns.setVisible(col.field, false);
        }
      }
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _fitController?.data.removeListener(_onFitControllerChanged);
    _fitController?.columns.removeListener(_onFitControllerChanged);
    _fitController?.filter.removeListener(_onFitFilterChanged);
    super.dispose();
  }

  void _onFitFilterChanged() {
    if (_isApplyingFilters || _fitController == null) return;
    final currentFilters = _fitController!.filter.filters;
    _activeFilters.clear();
    for (final entry in currentFilters.entries) {
      _activeFilters[entry.key] = {
        'operator': entry.value.operator.name,
        'value': entry.value.value ??
            (entry.value.values.isNotEmpty ? entry.value.values.join(', ') : null),
        if (entry.value.value2 != null) 'value2': entry.value.value2,
        if (entry.value.values.isNotEmpty) 'values': entry.value.values.toList(),
      };
    }
    notifyListeners();
  }

  /// Resolves field name flexibly (case-insensitive or title).
  String? _resolveField(String name) {
    final clean = name.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
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
    if (_fitController != null) {
      if (fields.isEmpty) {
        _fitController!.grouping.groups = const [];
      } else {
        _fitController!.grouping.groups = fields.map((f) {
          final actual = _resolveField(f) ?? f;
          final col = _columns.where((c) => c.field == actual).firstOrNull;
          final title = col?.title ?? actual;
          return FitGridGroup<Map<String, dynamic>>(
            keyOf: (row) => row[actual]?.toString() ?? '',
            label: (key, rows) => '$title: $key (${rows.length})',
          );
        }).toList();
        _fitController!.grouping.expandAll();
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

  FitGridFilterOperator _resolveFilterOperator(String operator) {
    final clean = operator.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    return switch (clean) {
      'notequals' || 'neq' || 'ne' || '!=' || '<>' || 'not' =>
        FitGridFilterOperator.notEquals,
      'notcontains' || 'doesnotcontain' || '!contains' || 'exclude' || 'excludes' =>
        FitGridFilterOperator.notContains,
      'equals' || 'eq' || '=' || '==' => FitGridFilterOperator.equals,
      'startswith' => FitGridFilterOperator.startsWith,
      'endswith' => FitGridFilterOperator.endsWith,
      'greaterthan' || 'gt' || '>' => FitGridFilterOperator.greaterThan,
      'greaterthanorequalto' || 'greaterorequal' || 'gte' || '>=' =>
        FitGridFilterOperator.greaterOrEqual,
      'lessthan' || 'lt' || '<' => FitGridFilterOperator.lessThan,
      'lessthanorequalto' || 'lessorequal' || 'lte' || '<=' =>
        FitGridFilterOperator.lessOrEqual,
      'between' => FitGridFilterOperator.between,
      'isempty' => FitGridFilterOperator.isEmpty,
      'isnotempty' => FitGridFilterOperator.isNotEmpty,
      'inlist' || 'oneof' || 'in' || 'or' || 'anyof' || 'either' =>
        FitGridFilterOperator.inList,
      _ => FitGridFilterOperator.contains,
    };
  }

  void _applyActiveFilters() {
    if (_fitController == null) return;
    _isApplyingFilters = true;
    try {
      final activeFields = _activeFilters.keys.toSet();
      // 1. Remove filters in FitGrid that are no longer active in _activeFilters
      for (final existingField in _fitController!.filter.filters.keys.toList()) {
        if (!activeFields.contains(existingField)) {
          _fitController!.filter.setFilter(existingField, null);
        }
      }

      // 2. Set or update all active filters
      for (final entry in _activeFilters.entries) {
        final field = entry.key;
        final opName = (entry.value['operator'] as String?) ?? 'contains';
        final val = entry.value['value'];
        var op = _resolveFilterOperator(opName);

        // Auto-detect OR / IN / list operations
        if (val is Iterable) {
          op = FitGridFilterOperator.inList;
        } else if (val is String &&
            (op == FitGridFilterOperator.contains || op == FitGridFilterOperator.equals)) {
          final trimmed = val.trim();
          if (trimmed.toLowerCase().startsWith('in:') ||
              trimmed.toLowerCase().contains(RegExp(r'\s+or\s+'))) {
            op = FitGridFilterOperator.inList;
          }
        }

        final col = _columns.where((c) => c.field == field).firstOrNull;
        Object? operand = val;
        Set<String> setValues = const <String>{};

        if (op == FitGridFilterOperator.inList) {
          if (val is Iterable) {
            setValues = val
                .map((e) => e.toString().trim())
                .where((s) => s.isNotEmpty)
                .toSet();
          } else if (val is String) {
            var raw = val.trim();
            if (raw.toLowerCase().startsWith('in:')) {
              raw = raw.substring(3).trim();
            } else if (raw.toLowerCase().startsWith('in(') && raw.endsWith(')')) {
              raw = raw.substring(3, raw.length - 1).trim();
            }
            setValues = raw
                .split(RegExp(r'\s*,\s*|\s+or\s+|\|', caseSensitive: false))
                .map((e) => e.trim())
                .where((s) => s.isNotEmpty)
                .toSet();
          } else if (val != null) {
            setValues = {val.toString().trim()};
          }
          operand = setValues.join(', ');
        } else if (col != null) {
          if (col.type == AiGridColumnType.number || col.type == AiGridColumnType.currency) {
            if (val is! num && val != null) {
              operand = num.tryParse(val.toString().replaceAll(RegExp(r'[^0-9.-]'), ''));
            }
          } else if (col.type == AiGridColumnType.date) {
            if (val is! DateTime && val != null) {
              operand = DateTime.tryParse(val.toString());
            }
          }
        }

        _fitController!.filter.setFilter(
          field,
          FitGridColumnFilter(
            operator: op,
            value: operand,
            values: setValues,
          ),
        );
      }
    } finally {
      _isApplyingFilters = false;
    }
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
    _fitController?.filter.setFilter(actualField, null);
    notifyListeners();
  }

  /// Clears all column filters.
  void clearAllFilters() {
    _activeFilters.clear();
    _fitController?.filter.clearColumnFilters();
    notifyListeners();
  }

  /// Performs an in-built mathematical calculation over grid rows without LLM hallucinations.
  Map<String, dynamic> calculate({
    required String field,
    required String operation,
    bool filteredOnly = true,
    String? groupBy,
  }) {
    if (_fitController == null && _dataSource == null) {
      return {'error': 'Grid is not initialized'};
    }

    final actualField = _resolveField(field) ?? field;
    final String columnTitle = _columns
        .where((c) => c.field == actualField)
        .firstOrNull
        ?.title ?? actualField;

    final targetColumn = _columns.where((c) => c.field == actualField).firstOrNull;

    List<Map<String, dynamic>> rows = [];
    if (_fitController != null) {
      rows = filteredOnly ? _fitController!.data.view : _fitController!.data.rows;
    } else if (_dataSource is LocalAiGridDataSource) {
      rows = (_dataSource as LocalAiGridDataSource).data;
    }

    if (groupBy != null && groupBy.isNotEmpty) {
      final actualGroupField = _resolveField(groupBy) ?? groupBy;
      final String groupTitle = _columns
          .where((c) => c.field == actualGroupField)
          .firstOrNull
          ?.title ?? actualGroupField;

      final groups = <dynamic, List<num>>{};
      for (final row in rows) {
        final gVal = row[actualGroupField]?.toString() ?? 'Unknown';
        final val = row[actualField];
        if (val is num) {
          groups.putIfAbsent(gVal, () => []).add(val);
        } else if (val != null) {
          final parsed = num.tryParse(val.toString().replaceAll(RegExp(r'[^0-9.-]'), ''));
          if (parsed != null) {
            groups.putIfAbsent(gVal, () => []).add(parsed);
          }
        }
      }

      final results = <String, dynamic>{};
      for (final entry in groups.entries) {
        results[entry.key.toString()] = _computeStats(entry.value, operation, targetColumn);
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
    for (final row in rows) {
      final val = row[actualField];
      if (val is num) {
        numbers.add(val);
      } else if (val != null) {
        final parsed = num.tryParse(val.toString().replaceAll(RegExp(r'[^0-9.-]'), ''));
        if (parsed != null) numbers.add(parsed);
      }
    }

    final stats = _computeStats(numbers, operation, targetColumn);
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
    AiGridColumn? column,
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

    String formatted = result.toStringAsFixed(2);
    if (column != null && column.type == AiGridColumnType.currency) {
      formatted = '\$${result.toStringAsFixed(2)}';
    }

    return {
      'result': double.parse(result.toStringAsFixed(2)),
      'formatted': formatted,
      'count': numbers.length,
    };
  }

  /// Applies global text search across all columns.
  void search(String query) {
    _searchQuery = query;
    _fitController?.filter.query = query.trim();
    notifyListeners();
  }

  /// Clears global search.
  void clearSearch() {
    search('');
  }

  /// Applies column sorting.
  /// If [append] is true, appends this column as an additional sort level (multi-column sorting).
  void sort(String field, {bool descending = false, bool append = false}) {
    final actual = _resolveField(field) ?? field;
    final dir = descending ? FitGridSortDirection.descending : FitGridSortDirection.ascending;

    if (_fitController != null) {
      if (!append) {
        _fitController!.setSort([FitGridSortKey(actual, dir)]);
      } else {
        final existing = _fitController!.data.sortKeys.where((k) => k.columnId != actual).toList();
        existing.add(FitGridSortKey(actual, dir));
        _fitController!.setSort(existing);
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
    if (sortConfigs.isEmpty) return;

    final keys = <FitGridSortKey>[];
    for (final config in sortConfigs) {
      final field = (config['field'] ?? config['column']) as String?;
      if (field == null) continue;
      final actual = _resolveField(field) ?? field;
      final descending = (config['descending'] as bool?) ?? false;
      keys.add(FitGridSortKey(actual, descending ? FitGridSortDirection.descending : FitGridSortDirection.ascending));
    }

    _fitController?.setSort(keys);

    if (sortConfigs.isNotEmpty) {
      _activeSortColumn = (sortConfigs.first['field'] ?? sortConfigs.first['column']) as String?;
      _isSortDescending = (sortConfigs.first['descending'] as bool?) ?? false;
    }
    notifyListeners();
  }

  /// Returns the current sorted keys.
  List<FitGridSortKey> get sortedColumns => _fitController?.data.sortKeys ?? [];

  /// Clears column sorting.
  void clearSorting() {
    _fitController?.clearSort();
    _activeSortColumn = null;
    _isSortDescending = false;
    notifyListeners();
  }

  /// Sets visibility of a specific column.
  void setColumnVisibility(String field, bool visible) {
    final actual = _resolveField(field) ?? field;
    if (visible) {
      _hiddenFields.remove(actual);
    } else {
      _hiddenFields.add(actual);
    }
    _fitController?.columns.setVisible(actual, visible);
    notifyListeners();
  }

  /// Shows ONLY the specified columns and hides all other columns.
  void showOnlyColumns(List<String> fields) {
    final targetFields = fields.map((f) => _resolveField(f) ?? f).toSet();
    _hiddenFields.clear();
    _hiddenFields.addAll(_columns.map((c) => c.field).where((f) => !targetFields.contains(f)));

    if (_fitController != null) {
      for (final col in _columns) {
        _fitController!.columns.setVisible(col.field, targetFields.contains(col.field));
      }
    }
    notifyListeners();
  }

  /// Sets visibility for multiple columns at once.
  void setColumnsVisibility(Map<String, bool> visibilityMap) {
    for (final entry in visibilityMap.entries) {
      final actual = _resolveField(entry.key) ?? entry.key;
      if (entry.value) {
        _hiddenFields.remove(actual);
      } else {
        _hiddenFields.add(actual);
      }
      _fitController?.columns.setVisible(actual, entry.value);
    }
    notifyListeners();
  }

  /// Restores visibility of all columns.
  void showAllColumns() {
    _hiddenFields.clear();
    _fitController?.columns.showAll();
    notifyListeners();
  }

  /// Returns the list of currently visible column fields.
  List<String> get visibleColumns {
    if (_fitController != null) {
      return _fitController!.columns.visible.map((c) => c.id).toList();
    }
    return _columns.map((c) => c.field).where((f) => !_hiddenFields.contains(f)).toList();
  }

  /// Returns the list of currently hidden column fields.
  List<String> get hiddenColumns {
    if (_fitController != null) {
      return _fitController!.columns.columns.where((c) => !c.visible).map((c) => c.id).toList();
    }
    return _hiddenFields.toList();
  }

  /// Sets an explicit width in pixels for a column.
  void setColumnWidth(String field, double width) {
    final actual = _resolveField(field) ?? field;
    _fitController?.columns.setWidth(actual, width);
    notifyListeners();
  }

  /// Restores a column to its declared width policy (e.g. auto-fitting to content).
  void autoSizeColumn(String field) {
    final actual = _resolveField(field) ?? field;
    _fitController?.columns.autoSize(actual);
    notifyListeners();
  }

  /// Restores all columns to their declared width policies.
  void autoSizeAllColumns() {
    _fitController?.columns.autoSizeAll();
    notifyListeners();
  }

  /// Map of column fields to their explicit width overrides.
  Map<String, double> get columnWidths =>
      _fitController?.columns.widthOverrides ?? const {};

  /// Whether a column currently has a width override instead of following policy.
  bool isColumnResized(String field) {
    final actual = _resolveField(field) ?? field;
    return _fitController?.columns.isResized(actual) ?? false;
  }

  /// Toggles visibility of the inline filter row.
  void toggleFilterRow() {
    _showColumnFilterRow = !_showColumnFilterRow;
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

  /// Exports native [FitGridSavedState] snapshot directly.
  FitGridSavedState? saveLayoutState() => _fitController?.saveState();

  /// Restores native [FitGridSavedState] snapshot directly.
  void restoreLayoutState(FitGridSavedState state) {
    if (_fitController != null) {
      _fitController!.restoreState(state);
      _activeSortColumn = state.sort.isNotEmpty ? state.sort.first.columnId : null;
      _isSortDescending = state.sort.isNotEmpty && state.sort.first.direction == FitGridSortDirection.descending;
      _searchQuery = state.query;
      _hiddenFields.clear();
      _hiddenFields.addAll(state.hiddenColumns);
      notifyListeners();
    }
  }

  /// Exports all current interactive grid settings to a Map.
  /// Uses FitGrid's native [FitGridSavedState] (column widths, order, frozen columns, sorts, filters, search)
  /// combined with AI Grid's grouping and UI toggles.
  Map<String, dynamic> exportSettings() {
    final fitState = _fitController?.saveState().toJson() ?? <String, dynamic>{};

    return {
      ...fitState,
      'groupColumns': List<String>.from(activeGrouping),
      'showColumnFilterRow': _showColumnFilterRow,
      'showGroupPanel': _showGroupPanel,
      // Backwards-compatibility fields for legacy callers and tools
      'visibleColumns': visibleColumns,
      'hiddenColumns': hiddenColumns,
      'sorts': _fitController != null && _fitController!.data.sortKeys.isNotEmpty
          ? _fitController!.data.sortKeys
              .map((k) => {
                    'field': k.columnId,
                    'descending': k.direction == FitGridSortDirection.descending,
                  })
              .toList()
          : (_activeSortColumn != null
              ? [
                  {
                    'field': _activeSortColumn,
                    'descending': _isSortDescending,
                  }
                ]
              : <Map<String, dynamic>>[]),
      'filters': Map<String, dynamic>.from(activeFilters),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Exports all current settings serialized as a JSON string.
  String exportSettingsJson({bool pretty = true}) {
    final encoder = pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder();
    return encoder.convert(exportSettings());
  }

  /// Restores grid state from a saved settings Map.
  /// Seamlessly handles native FitGrid [FitGridSavedState] (order, widths, freezes, sorts, filters)
  /// as well as AI Grid grouping and legacy settings shapes.
  void restoreSettings(Map<String, dynamic> settings) {
    // 1. Native FitGrid state restoration
    if (_fitController != null) {
      try {
        final fitState = FitGridSavedState.fromJson(settings);
        _fitController!.restoreState(fitState);

        if (fitState.sort.isNotEmpty) {
          _activeSortColumn = fitState.sort.first.columnId;
          _isSortDescending = fitState.sort.first.direction == FitGridSortDirection.descending;
        } else if (!settings.containsKey('sorts')) {
          _activeSortColumn = null;
          _isSortDescending = false;
        }

        if (fitState.query.isNotEmpty) {
          _searchQuery = fitState.query;
        }

        if (fitState.hiddenColumns.isNotEmpty) {
          _hiddenFields.clear();
          _hiddenFields.addAll(fitState.hiddenColumns);
        }
      } catch (e) {
        debugPrint('Error restoring FitGridSavedState: $e');
      }
    }

    // 2. Visible/Hidden columns fallback
    if (!settings.containsKey('columnOrder')) {
      if (settings.containsKey('visibleColumns')) {
        final list = (settings['visibleColumns'] as List?)
            ?.map((e) => e.toString())
            .toList();
        if (list != null && list.isNotEmpty) {
          showOnlyColumns(list);
        }
      } else if (settings.containsKey('hiddenColumns')) {
        final hidden = (settings['hiddenColumns'] as List?)
                ?.map((e) => e.toString())
                .toSet() ??
            {};
        final map = <String, bool>{};
        for (final col in _columns) {
          map[col.field] = !hidden.contains(col.field);
        }
        setColumnsVisibility(map);
      }
    }

    // 3. Filters restoration (supports both 'operator' and FitGrid 'op')
    if (settings.containsKey('filters')) {
      final filters = settings['filters'] as Map<String, dynamic>? ?? {};
      clearAllFilters();
      for (final entry in filters.entries) {
        final valMap = entry.value as Map<String, dynamic>?;
        if (valMap != null) {
          final op = (valMap['operator'] ?? valMap['op'])?.toString() ?? 'contains';
          final val = valMap['value'];
          setFilter(entry.key, operator: op, value: val);
        }
      }
    }

    // 4. Sorts restoration
    if (settings.containsKey('sorts')) {
      final sorts = (settings['sorts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (sorts.isNotEmpty) {
        multiSort(sorts);
      } else {
        clearSorting();
      }
    } else if (settings.containsKey('sort')) {
      final sorts = (settings['sort'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (sorts.isNotEmpty) {
        multiSort(sorts.map((s) => {
          'field': s['column'],
          'descending': s['dir'] == 'descending',
        }).toList());
      }
    }

    // 3. Group columns (AI Grid feature)
    if (settings.containsKey('groupColumns')) {
      final groups = (settings['groupColumns'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      if (groups.isNotEmpty || _activeGrouping.isNotEmpty) {
        setGrouping(groups);
      }
    }

    // 4. UI toggles
    if (settings.containsKey('showColumnFilterRow')) {
      _showColumnFilterRow = settings['showColumnFilterRow'] == true;
    }
    if (settings.containsKey('showGroupPanel')) {
      _showGroupPanel = settings['showGroupPanel'] == true;
    }

    notifyListeners();
  }

  /// Restores grid state from a JSON string.
  void restoreSettingsJson(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        restoreSettings(decoded);
      }
    } catch (e) {
      debugPrint('Error restoring grid settings from JSON: $e');
    }
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
      'filteredRowCount': _fitController?.data.length ?? (_dataSource?.totalRowCount ?? 0),
      'visibleColumns': visibleColumns,
      'hiddenColumns': hiddenColumns,
      'sortedColumns': sortedColumns
          .map((k) => {
                'field': k.columnId,
                'descending': k.direction == FitGridSortDirection.descending,
              })
          .toList(),
    };
  }

  /// Fetches sample data rows for LLM context.
  Future<List<Map<String, dynamic>>> getSampleData({int limit = 5}) async {
    if (_dataSource == null) return [];
    return _dataSource!.getSampleData(limit: limit);
  }

  /// Exports current grid data to Excel (.xlsx) using FitGrid's native XLSX encoder,
  /// opening the platform "Save As..." dialog so the user can select destination directory
  /// and filename.
  /// Works across Web, Desktop (Windows, macOS, Linux), and Mobile (Android, iOS).
  Future<String?> export({
    String? fileName,
    bool includeHeaders = true,
    bool selectedOnly = false,
  }) =>
      exportTableWithSaveDialog(
        fileName: fileName,
        includeHeaders: includeHeaders,
        selectedOnly: selectedOnly,
      );

  /// Exports current grid data to Excel (.xlsx) using FitGrid's native XLSX encoder,
  /// opening the platform "Save As..." dialog so the user can select destination directory
  /// and filename.
  /// Works across Web, Desktop (Windows, macOS, Linux), and Mobile (Android, iOS).
  Future<String?> exportTableWithSaveDialog({
    String? fileName,
    bool includeHeaders = true,
    bool selectedOnly = false,
  }) async {
    final fc = _fitController;
    if (fc == null) throw Exception('Grid is not attached yet');

    final exportData = fc.export(
      includeHeaders: includeHeaders,
      selectedOnly: selectedOnly,
    );

    final bytes = fitGridToXlsx(exportData);
    final rawName = (fileName != null && fileName.trim().isNotEmpty)
        ? fileName.trim()
        : 'grid_export_${DateTime.now().millisecondsSinceEpoch}';
    final cleanName = rawName.replaceAll(RegExp(r'\.xlsx$', caseSensitive: false), '');

    try {
      final savedPath = await FileSaver.instance.saveAs(
        name: cleanName,
        bytes: bytes,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
        dialogTitle: 'Export Grid Data to Excel',
      );
      return savedPath;
    } on UnsupportedError catch (e) {
      debugPrint('saveAs unsupported on platform ($e), falling back to saveFile');
      return await FileSaver.instance.saveFile(
        name: cleanName,
        bytes: bytes,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
    } catch (e) {
      debugPrint('saveAs error ($e), falling back to saveFile');
      return await FileSaver.instance.saveFile(
        name: cleanName,
        bytes: bytes,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
    }
  }

  /// Exports current grid data to CSV, TSV, XLSX, or JSON and saves it via FileSaver.
  /// If [useSaveAs] is true, opens the platform "Save As..." dialog so the user
  /// can select an output directory and filename.
  Future<String> exportGrid({
    String format = 'xlsx',
    List<String>? columns,
    bool includeHeaders = true,
    bool ignoreFixedRows = false,
    String separator = ',',
    bool useSaveAs = true,
    String? fileName,
    bool selectedOnly = false,
  }) async {
    final fc = _fitController;
    if (fc == null) throw Exception('Grid is not attached yet');

    final rawName = (fileName != null && fileName.trim().isNotEmpty)
        ? fileName.trim()
        : 'grid_export_${DateTime.now().millisecondsSinceEpoch}';
    final fmt = format.toLowerCase().trim();

    final exportData = fc.export(
      includeHeaders: includeHeaders,
      selectedOnly: selectedOnly,
    );

    Uint8List bytes;
    String extension;
    MimeType mimeType;

    if (fmt == 'xlsx') {
      bytes = fitGridToXlsx(exportData);
      extension = 'xlsx';
      mimeType = MimeType.microsoftExcel;
    } else if (fmt == 'csv') {
      final content = fitGridToCsv(exportData);
      bytes = Uint8List.fromList(utf8.encode(content));
      extension = 'csv';
      mimeType = MimeType.csv;
    } else if (fmt == 'tsv') {
      final content = fitGridToTsv(exportData);
      bytes = Uint8List.fromList(utf8.encode(content));
      extension = 'tsv';
      mimeType = MimeType.text;
    } else if (fmt == 'json') {
      final rows = fc.data.view;
      final jsonStr = const JsonEncoder.withIndent('  ').convert(rows);
      bytes = Uint8List.fromList(utf8.encode(jsonStr));
      extension = 'json';
      mimeType = MimeType.json;
    } else {
      throw Exception('Unsupported export format: $format');
    }

    final cleanName = rawName.replaceAll(RegExp('\\.$extension\$', caseSensitive: false), '');

    if (useSaveAs) {
      try {
        final path = await FileSaver.instance.saveAs(
          name: cleanName,
          bytes: bytes,
          fileExtension: extension,
          mimeType: mimeType,
          dialogTitle: 'Export Grid Data',
        );
        if (path != null && path.isNotEmpty) {
          return path;
        }
      } catch (e) {
        debugPrint('FileSaver.saveAs failed ($e), falling back to saveFile');
      }
    }

    return await FileSaver.instance.saveFile(
      name: cleanName,
      bytes: bytes,
      fileExtension: extension,
      mimeType: mimeType,
    );
  }
}
