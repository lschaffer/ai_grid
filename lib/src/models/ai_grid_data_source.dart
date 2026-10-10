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
