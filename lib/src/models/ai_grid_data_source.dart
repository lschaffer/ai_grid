import 'package:flutter/foundation.dart';
import 'package:trina_grid/trina_grid.dart';
import 'ai_grid_column.dart';

/// Abstract contract for data sources feeding [AiGrid].
///
/// Supports client-side in-memory collections as well as remote/server-side pageable sources.
abstract class AiGridDataSource with ChangeNotifier {
  /// Column definitions for the grid.
  List<AiGridColumn> get columns;

  /// Total count of rows across all pages (or currently loaded rows).
  int get totalRowCount;

  /// Fetches rows to be displayed in the grid.
  Future<List<TrinaRow>> fetchRows();

  /// Retrieves a lightweight JSON sample of rows for LLM contextual awareness.
  Future<List<Map<String, dynamic>>> getSampleData({int limit = 5});
}

/// In-memory client-side data source for [AiGrid].
class LocalAiGridDataSource extends AiGridDataSource {
  @override
  final List<AiGridColumn> columns;
  List<Map<String, dynamic>> _data;
  List<TrinaRow> _cachedRows = [];

  LocalAiGridDataSource({
    required this.columns,
    required List<Map<String, dynamic>> initialData,
  }) : _data = List.from(initialData) {
    _rebuildRows();
  }

  @override
  int get totalRowCount => _data.length;

  /// Direct access to underlying data maps.
  List<Map<String, dynamic>> get data => List.unmodifiable(_data);

  /// Updates or replaces the local dataset and notifies listeners.
  void setData(List<Map<String, dynamic>> newData) {
    _data = List.from(newData);
    _rebuildRows();
    notifyListeners();
  }

  void _rebuildRows() {
    _cachedRows = _data.map((item) {
      final cells = <String, TrinaCell>{};
      for (final col in columns) {
        cells[col.field] = TrinaCell(value: item[col.field]);
      }
      return TrinaRow(cells: cells);
    }).toList();
  }

  @override
  Future<List<TrinaRow>> fetchRows() async {
    return _cachedRows;
  }

  @override
  Future<List<Map<String, dynamic>>> getSampleData({int limit = 5}) async {
    return _data.take(limit).toList();
  }
}


/// Server-side / partial data lazy pagination data source for [AiGrid].
///
/// Fetches and streams data on-demand in pages from a remote backend or database
/// matching TrinaGrid's [TrinaLazyPagination] engine.
class LazyAiGridDataSource extends AiGridDataSource {
  @override
  final List<AiGridColumn> columns;

  /// Callback invoked when a page of data, sorting, or filtering is requested.
  final TrinaLazyPaginationFetch fetch;

  /// Optional function returning total count of records across the entire dataset.
  final int Function()? totalRowCountGetter;

  /// Optional sample data for AI contextual reasoning.
  final List<Map<String, dynamic>>? sampleData;

  /// Whether sorting triggers a new server-side fetch with sortColumn (default: true).
  final bool fetchWithSorting;

  /// Whether filtering triggers a new server-side fetch with filterRows (default: true).
  final bool fetchWithFiltering;

  LazyAiGridDataSource({
    required this.columns,
    required this.fetch,
    this.totalRowCountGetter,
    this.sampleData,
    this.fetchWithSorting = true,
    this.fetchWithFiltering = true,
  });

  @override
  int get totalRowCount => totalRowCountGetter?.call() ?? 0;

  @override
  Future<List<TrinaRow>> fetchRows() async {
    // Handled dynamically by TrinaLazyPagination
    return <TrinaRow>[];
  }

  @override
  Future<List<Map<String, dynamic>>> getSampleData({int limit = 5}) async {
    if (sampleData != null && sampleData!.isNotEmpty) {
      return sampleData!.take(limit).toList();
    }
    try {
      final initialRes = await fetch(
        TrinaLazyPaginationRequest(page: 1, pageSize: limit),
      );
      return initialRes.rows.take(limit).map((r) {
        final map = <String, dynamic>{};
        for (final entry in r.cells.entries) {
          map[entry.key] = entry.value.value;
        }
        return map;
      }).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }
}
