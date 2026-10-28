import 'dart:convert';
import 'dart:math' as math;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../fitgrid/fitgrid_table.dart';
import '../models/ai_grid_column.dart';
import '../models/ai_grid_conditional_format.dart';
import '../models/ai_grid_range_summary.dart';
import '../models/ai_grid_master_detail.dart';
import '../models/ai_grid_data_source.dart';
import '../models/ai_grid_editing_options.dart';
import '../models/ai_grid_pivot.dart';
import '../config/ai_grid_dynamic_storage.dart';
import '../models/ai_grid_dynamic_datasource.dart';
import '../widgets/ai_grid_column_editor_dialog.dart';
import '../widgets/ai_grid_columns_editor_dialog.dart';
import '../widgets/ai_grid_form_dialog.dart';
import '../widgets/ai_grid_pivot_chart.dart';
import '../config/ai_grid_config.dart';
import '../models/ai_grid_smart_column.dart';
import '../models/ai_grid_smart_column_runner.dart';

/// Controller coordinating grid state, grouping, filtering, sorting,
/// column visibility, and introspection for AI Assistant tools.
class AiGridController extends ChangeNotifier {
  FitGridController<Map<String, dynamic>>? _fitController;
  AiGridDataSource? _dataSource;
  List<AiGridColumn> _columns = [];
  AiGridDynamicDescriptor? _activeDynamicDatasource;

  /// Active dynamic datasource descriptor if currently bound to a dynamic dataset.
  AiGridDynamicDescriptor? get activeDynamicDatasource => _activeDynamicDatasource;

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

  AiGridEditingOptions _editingOptions = const AiGridEditingOptions();
  int? _editingRowIndex;
  Map<String, dynamic>? _draftRow;
  bool _isAddingRow = false;
  final Map<String, String> _validationErrors = {};
  final Map<String, Map<int, AiGridSmartCellStatus>> _smartCellStatus = {};
  bool _isGeneratingSmartColumns = false;

  /// Whether an AI smart column evaluation batch is currently in progress.
  bool get isGeneratingSmartColumns => _isGeneratingSmartColumns;

  /// All smart columns currently defined in the grid.
  List<AiGridSmartColumn> get smartColumns =>
      _columns.whereType<AiGridSmartColumn>().toList();

  /// Whether the specified [field] is an [AiGridSmartColumn].
  bool isSmartColumn(String field) =>
      _columns.any((c) => c.field == field && c is AiGridSmartColumn);

  /// Gets the current generation status of a smart column cell.
  AiGridSmartCellStatus getSmartCellStatus(String field, int rowIndex) {
    return _smartCellStatus[field]?[rowIndex] ?? AiGridSmartCellStatus.idle;
  }

  /// Empty placeholder row shown in the grid while adding in row mode.
  Map<String, dynamic>? _pendingNewRow;

  /// Removes the row-mode placeholder row (if any) from the grid data.
  /// Returns the view index it occupied, or -1.
  int _discardPendingRow() {
    final pending = _pendingNewRow;
    _pendingNewRow = null;
    if (pending == null || _fitController == null) return -1;
    final viewIdx = _fitController!.data.view.indexOf(pending);
    final allRows = List<Map<String, dynamic>>.from(_fitController!.data.rows)
      ..remove(pending);
    _fitController!.data.rows = allRows;
    return viewIdx;
  }

  /// Current editing options configured for this grid.
  AiGridEditingOptions get editingOptions => _editingOptions;
  set editingOptions(AiGridEditingOptions options) => setEditingOptions(options);

  /// Index of the row currently being edited in row/form mode, or null.
  int? get editingRowIndex => _editingRowIndex;

  /// In-progress draft values for the currently edited or added row.
  Map<String, dynamic>? get draftRow => _draftRow;

  /// Whether a brand-new row is currently being added.
  bool get isAddingRow => _isAddingRow;

  /// Whether any row is currently in an active edit or add session.
  bool get isEditingRow => _editingRowIndex != null || _isAddingRow;

  /// Validation error messages keyed by column field name.
  Map<String, String> get validationErrors => Map.unmodifiable(_validationErrors);

  /// Updates the editing options and notifies listeners.
  void setEditingOptions(AiGridEditingOptions options, {bool notify = true}) {
    if (_editingOptions == options) return;
    if (options.mode != _editingOptions.mode && isEditingRow) {
      _discardPendingRow();
      _editingRowIndex = null;
      _isAddingRow = false;
      _draftRow = null;
      _validationErrors.clear();
    }
    _editingOptions = options;
    if (notify) {
      notifyListeners();
    }
  }

  final List<AiGridEditEvent> _editEvents = [];

  /// Historical log of editing events.
  List<AiGridEditEvent> get editEvents => List.unmodifiable(_editEvents);

  /// Records an editing event in the event history.
  void logEditEvent(AiGridEditEvent event) {
    _editEvents.add(event);
    if (_editEvents.length > 500) {
      _editEvents.removeAt(0);
    }
    notifyListeners();
  }

  /// Clears all recorded editing events.
  void clearEditEvents() {
    _editEvents.clear();
    notifyListeners();
  }

  final List<AiGridConditionalFormat> _conditionalFormats = [];

  /// Active conditional formatting rules.
  List<AiGridConditionalFormat> get conditionalFormats =>
      List.unmodifiable(_conditionalFormats);

  /// Adds or updates a conditional formatting rule and updates the grid.
  void addConditionalFormat(AiGridConditionalFormat format) {
    _conditionalFormats.removeWhere((f) => f.id == format.id);
    _conditionalFormats.add(format);
    _syncEffectiveColumns();
    notifyListeners();
  }

  /// Removes a conditional formatting rule by [id].
  void removeConditionalFormat(String id) {
    _conditionalFormats.removeWhere((f) => f.id == id);
    _syncEffectiveColumns();
    notifyListeners();
  }

  /// Clears all conditional formatting rules or rules matching [field].
  void clearConditionalFormats([String? field]) {
    if (field != null) {
      _conditionalFormats.removeWhere((f) => f.field == field);
    } else {
      _conditionalFormats.clear();
    }
    _syncEffectiveColumns();
    notifyListeners();
  }

  /// Resolves row background color for conditional formatting.
  Color? resolveRowColor(Map<String, dynamic> row, int rowIndex) {
    for (final fmt in _conditionalFormats) {
      if (fmt.type == AiGridFormatType.highlight &&
          fmt.applyToRow &&
          fmt.backgroundColor != null) {
        final val = fmt.field == '*' ? row : row[fmt.field];
        if (fmt.matches(val, row)) {
          return fmt.backgroundColor;
        }
      }
    }
    return null;
  }

  /// Builds a [FitGridColumn] from an [AiGridColumn], applying any active dynamic conditional formats.
  FitGridColumn<Map<String, dynamic>> buildFitGridColumn(AiGridColumn col) {
    var effectiveCol = col;
    final fieldFormats =
        _conditionalFormats.where((f) => f.field == col.field).toList();
    if (fieldFormats.isNotEmpty) {
      final barFormat = fieldFormats
          .where((f) => f.type == AiGridFormatType.dataBar)
          .firstOrNull;
      final highlightFormats = fieldFormats
          .where((f) => f.type == AiGridFormatType.highlight)
          .toList();
      final colorScaleFormat = fieldFormats
          .where((f) => f.type == AiGridFormatType.colorScale)
          .firstOrNull;

      FitGridCellVisual<Map<String, dynamic>>? visual = col.visual;
      if (visual == null && barFormat != null) {
        visual = FitGridCellVisual.bar(
          (row) {
            final v = row[col.field];
            if (v is num) return v;
            if (v != null) return num.tryParse(v.toString());
            return null;
          },
          min: barFormat.min,
          max: barFormat.max,
          color: barFormat.positiveColor,
          negativeColor: barFormat.negativeColor,
          showText: barFormat.showText,
        );
      }

      TextStyle? Function(dynamic value, Map<String, dynamic> row)? cellStyle =
          col.cellStyle;
      if (highlightFormats.isNotEmpty || colorScaleFormat != null) {
        final existingStyle = cellStyle;
        cellStyle = (val, row) {
          TextStyle? base = existingStyle?.call(val, row);
          for (final h in highlightFormats) {
            if (h.matches(val, row)) {
              base = (base ?? const TextStyle()).copyWith(
                color: h.textColor,
                fontWeight: h.fontWeight,
                backgroundColor: h.applyToRow ? null : h.backgroundColor,
              );
            }
          }
          if (colorScaleFormat != null && val is num) {
            final min = colorScaleFormat.min ?? 0;
            final max = colorScaleFormat.max ?? 100;
            final interpolated =
                colorScaleFormat.interpolateColor(val, min, max);
            if (interpolated != null) {
              base = (base ?? const TextStyle()).copyWith(color: interpolated);
            }
          }
          return base;
        };
      }

      effectiveCol = col.copyWith(
        visual: visual,
        cellStyle: cellStyle,
      );
    }

    // Smart column visual styling & inline sparkle indicator
    if (col is AiGridSmartColumn && effectiveCol.cellBuilder == null) {
      final smartCol = col;
      effectiveCol = effectiveCol.copyWith(
        cellBuilder: (context, row, rowIndex) {
          final status = getSmartCellStatus(smartCol.field, rowIndex);
          final val = row[smartCol.field];
          final valStr = val?.toString() ?? '';
          final theme = Theme.of(context);
          final sparkleColor = smartCol.sparkleColor ?? const Color(0xFF8B5CF6);

          if (status == AiGridSmartCellStatus.generating) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: sparkleColor,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Synthesizing...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.hintColor,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          }

          if (valStr.isEmpty) {
            return InkWell(
              onTap: () => runSmartColumnForCell(rowIndex, smartCol.field),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_outlined,
                        size: 12, color: sparkleColor.withValues(alpha: 0.8)),
                    const SizedBox(width: 4),
                    Text(
                      'Generate',
                      style: TextStyle(
                        fontSize: 11,
                        color: sparkleColor.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final style = smartCol.cellStyle?.call(val, row) ??
              theme.textTheme.bodyMedium?.copyWith(fontSize: 12);

          return Tooltip(
            message: 'AI Synthesized • Prompt: "${smartCol.promptTemplate}"',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 12, color: sparkleColor),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    smartCol.formatDisplayValue(val),
                    style: style,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return effectiveCol.toFitGridColumn();
  }

  /// Adds an AI smart column to the grid. If [autoRun] is true, triggers prompt evaluation.
  void addSmartColumn(
    AiGridSmartColumn column, {
    bool autoRun = true,
    AiGridConfig? aiConfig,
  }) {
    final existingIndex = _columns.indexWhere((c) => c.field == column.field);
    if (existingIndex >= 0) {
      _columns[existingIndex] = column;
    } else {
      _columns.add(column);
    }
    _syncEffectiveColumns();
    notifyListeners();
    if (autoRun) {
      runSmartColumns(field: column.field, aiConfig: aiConfig);
    }
  }

  /// Evaluates AI smart columns across all rows in the dataset.
  /// If [field] is specified, only that smart column is evaluated.
  /// If [force] is true, re-evaluates rows even if values already exist.
  Future<void> runSmartColumns({
    String? field,
    bool force = false,
    AiGridConfig? aiConfig,
  }) async {
    final targets =
        smartColumns.where((c) => field == null || c.field == field).toList();
    if (targets.isEmpty) return;

    final allRows = List<Map<String, dynamic>>.from(rows);
    if (allRows.isEmpty) return;

    _isGeneratingSmartColumns = true;
    for (final col in targets) {
      _smartCellStatus.putIfAbsent(col.field, () => {});
      for (var i = 0; i < allRows.length; i++) {
        final existing = allRows[i][col.field];
        if (force || existing == null || existing.toString().trim().isEmpty) {
          _smartCellStatus[col.field]![i] = AiGridSmartCellStatus.generating;
        }
      }
    }
    notifyListeners();

    try {
      final llmConfig =
          aiConfig?.llmConfig ?? AiGridEnvLoader.createLlmConfigFromEnv();

      for (final col in targets) {
        final rowIndices = <int>[];
        for (var i = 0; i < allRows.length; i++) {
          if (_smartCellStatus[col.field]?[i] ==
              AiGridSmartCellStatus.generating) {
            rowIndices.add(i);
          }
        }
        if (rowIndices.isEmpty) continue;

        final batchResults = await AiGridSmartColumnRunner.evaluateBatch(
          column: col,
          rows: allRows,
          rowIndices: rowIndices,
          llmConfig: llmConfig,
        );

        for (final entry in batchResults.entries) {
          final idx = entry.key;
          final value = entry.value;
          allRows[idx][col.field] = value;
          _smartCellStatus[col.field]![idx] = AiGridSmartCellStatus.generated;
        }

        // Apply updated rows back to FitGrid or DataSource
        if (_fitController != null) {
          _fitController!.data.rows = List<Map<String, dynamic>>.from(allRows);
        } else if (_dataSource is LocalAiGridDataSource) {
          (_dataSource as LocalAiGridDataSource).setData(allRows);
        }

        logEditEvent(AiGridEditEvent(
          action: 'smart_column_generated',
          rowIndex: 0,
          message: 'Synthesized ${batchResults.length} values for "${col.title}"',
        ));
      }
    } finally {
      _isGeneratingSmartColumns = false;
      notifyListeners();
    }
  }

  /// Evaluates an AI smart column for a single specific cell.
  Future<void> runSmartColumnForCell(
    int rowIndex,
    String field, {
    AiGridConfig? aiConfig,
  }) async {
    final col = smartColumns.where((c) => c.field == field).firstOrNull;
    if (col == null) return;
    final allRows = List<Map<String, dynamic>>.from(rows);
    if (rowIndex < 0 || rowIndex >= allRows.length) return;

    _smartCellStatus.putIfAbsent(col.field, () => {});
    _smartCellStatus[col.field]![rowIndex] = AiGridSmartCellStatus.generating;
    notifyListeners();

    try {
      final llmConfig =
          aiConfig?.llmConfig ?? AiGridEnvLoader.createLlmConfigFromEnv();
      final results = await AiGridSmartColumnRunner.evaluateBatch(
        column: col,
        rows: allRows,
        rowIndices: [rowIndex],
        llmConfig: llmConfig,
      );

      if (results.containsKey(rowIndex)) {
        allRows[rowIndex][col.field] = results[rowIndex];
        _smartCellStatus[col.field]![rowIndex] = AiGridSmartCellStatus.generated;
      } else {
        _smartCellStatus[col.field]![rowIndex] = AiGridSmartCellStatus.error;
      }

      if (_fitController != null) {
        _fitController!.data.rows = List<Map<String, dynamic>>.from(allRows);
      } else if (_dataSource is LocalAiGridDataSource) {
        (_dataSource as LocalAiGridDataSource).setData(allRows);
      }
    } catch (_) {
      _smartCellStatus[col.field]![rowIndex] = AiGridSmartCellStatus.error;
    } finally {
      notifyListeners();
    }
  }

  /// Clears generated AI values in smart columns and resets cell statuses to idle.
  void clearSmartColumnValues([String? field]) {
    final targets =
        smartColumns.where((c) => field == null || c.field == field).toList();
    if (targets.isEmpty) return;

    final allRows = List<Map<String, dynamic>>.from(rows);
    for (final col in targets) {
      _smartCellStatus.remove(col.field);
      for (final r in allRows) {
        r.remove(col.field);
      }
    }

    if (_fitController != null) {
      _fitController!.data.rows = List<Map<String, dynamic>>.from(allRows);
    } else if (_dataSource is LocalAiGridDataSource) {
      (_dataSource as LocalAiGridDataSource).setData(allRows);
    }
    notifyListeners();
  }

  void _syncEffectiveColumns() {
    if (_fitController == null) return;
    final hidden = hiddenColumns.toSet();
    _fitController!.columns.columns = _columns.map((c) {
      final col = buildFitGridColumn(c);
      if (hidden.contains(c.field)) {
        return col.copyWith(visible: false);
      }
      return col;
    }).toList();
  }

  /// Starts adding a new row, initializing draft values with column defaults or [initialValues].
  void startAdd([Map<String, dynamic>? initialValues]) {
    if (_activeDynamicDatasource?.isReadonly == true) return;
    _discardPendingRow();
    _editingRowIndex = null;
    _isAddingRow = true;
    _validationErrors.clear();
    _draftRow = <String, dynamic>{};
    for (final col in _columns) {
      if (initialValues != null && initialValues.containsKey(col.field)) {
        _draftRow![col.field] = initialValues[col.field];
      } else {
        _draftRow![col.field] = null;
      }
    }

    // Row mode: show an empty record inline at the configured position.
    if (_editingOptions.mode == AiGridEditMode.row && _fitController != null) {
      final placeholder = Map<String, dynamic>.from(_draftRow!);
      final allRows = List<Map<String, dynamic>>.from(_fitController!.data.rows);
      if (_editingOptions.insertRowPosition == AiGridInsertRowPosition.top) {
        allRows.insert(0, placeholder);
      } else {
        allRows.add(placeholder);
      }
      _fitController!.data.rows = allRows;
      _pendingNewRow = placeholder;
      final idx = _fitController!.data.view.indexOf(placeholder);
      _editingRowIndex = idx >= 0 ? idx : null;
    }

    logEditEvent(AiGridEditEvent(
      action: 'startAdd',
      message: 'Started adding a new record',
      data: initialValues,
    ));
    notifyListeners();
  }

  /// Starts editing an existing row at [rowIndex] in row or form mode.
  void startEdit(int rowIndex) {
    if (_activeDynamicDatasource?.isReadonly == true) return;
    if (_fitController == null) return;
    final removedAt = _discardPendingRow();
    if (removedAt >= 0 && removedAt < rowIndex) rowIndex--;
    final rows = _fitController!.data.view;
    if (rowIndex < 0 || rowIndex >= rows.length) return;
    _editingRowIndex = rowIndex;
    _isAddingRow = false;
    _validationErrors.clear();
    final row = rows[rowIndex];
    _draftRow = Map<String, dynamic>.from(row);
    final idVal = row['OrderID'] ?? row['id'] ?? row['ID'] ?? '#$rowIndex';
    logEditEvent(AiGridEditEvent(
      action: 'startEdit',
      rowIndex: rowIndex,
      message: 'Started editing row #$rowIndex ($idVal)',
      data: row,
    ));
    notifyListeners();
  }

  /// Opens the modal popup [AiGridFormDialog] to add a new row (if [rowIndex] is null)
  /// or edit an existing row at [rowIndex].
  Future<bool?> showEditDialog(
    BuildContext context, {
    int? rowIndex,
    Map<String, dynamic>? initialValues,
    String? title,
  }) {
    if (_activeDynamicDatasource?.isReadonly == true) {
      return Future.value(false);
    }
    if (rowIndex != null) {
      startEdit(rowIndex);
    } else {
      startAdd(initialValues);
    }
    return AiGridFormDialog.show(context, controller: this, title: title);
  }

  /// Updates a single column's value in the active edit draft.
  void updateDraftValue(String column, dynamic value) {
    if (_draftRow == null) return;
    final oldVal = _draftRow![column];
    _draftRow![column] = value;
    final col = _columns.where((c) => c.field == column).firstOrNull;
    if (col != null) {
      final err = col.validate(value);
      if (err != null) {
        _validationErrors[column] = err;
      } else {
        _validationErrors.remove(column);
      }
      col.onChanged?.call(value, _draftRow!);
    }
    logEditEvent(AiGridEditEvent(
      action: 'change',
      rowIndex: _editingRowIndex,
      field: column,
      oldValue: oldVal,
      newValue: value,
      message: 'Updated field "$column": ${oldVal ?? "null"} → ${value ?? "null"}',
    ));
    notifyListeners();
  }

  /// Cancels the active editing or adding session and discards draft changes.
  void cancelEdit() {
    final prevIdx = _editingRowIndex;
    final wasAdding = _isAddingRow;
    _discardPendingRow();
    _editingRowIndex = null;
    _isAddingRow = false;
    _draftRow = null;
    _validationErrors.clear();
    logEditEvent(AiGridEditEvent(
      action: 'cancel',
      rowIndex: prevIdx,
      message: wasAdding
          ? 'Cancelled adding new record'
          : 'Cancelled editing row #${prevIdx ?? "unknown"}',
    ));
    notifyListeners();
  }

  /// Validates and saves the active edit or added row.
  /// Returns null on success, or an error message on validation failure.
  Future<String?> saveEdit() async {
    if (_activeDynamicDatasource?.isReadonly == true) return 'Table is read-only';
    if (_draftRow == null || _fitController == null) return null;

    // 1. Column-level validation
    _validationErrors.clear();
    for (final col in _columns) {
      if (col.isEditable) {
        final err = col.validate(_draftRow![col.field]);
        if (err != null) {
          _validationErrors[col.field] = err;
        }
      }
    }
    if (_validationErrors.isNotEmpty) {
      final err = _validationErrors.values.first;
      logEditEvent(AiGridEditEvent(
        action: 'error',
        rowIndex: _editingRowIndex,
        message: 'Validation failed: $err',
      ));
      notifyListeners();
      return err;
    }

    final originalRow = _isAddingRow
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(_fitController!.data.view[_editingRowIndex!]);

    // 2. beforeSave lifecycle hook
    if (_editingOptions.beforeSave != null) {
      final err = await _editingOptions.beforeSave!(originalRow, _draftRow!);
      if (err != null) {
        logEditEvent(AiGridEditEvent(
          action: 'error',
          rowIndex: _editingRowIndex,
          message: 'beforeSave rejected: $err',
        ));
        notifyListeners();
        return err;
      }
    }

    // 3. Commit modified fields via options.commit
    if (_editingOptions.commit != null) {
      for (final entry in _draftRow!.entries) {
        if (_isAddingRow || entry.value != originalRow[entry.key]) {
          _editingOptions.commit!(entry.key, entry.value);
        }
      }
    }

    final isAdding = _isAddingRow;
    final targetIndex = _editingRowIndex;

    // 4. Update data in FitGridController and AiGridDataSource
    final allRows = List<Map<String, dynamic>>.from(_fitController!.data.rows);
    if (_isAddingRow) {
      final newRow = Map<String, dynamic>.from(_draftRow!);
      final pendingIdx =
          _pendingNewRow == null ? -1 : allRows.indexOf(_pendingNewRow!);
      if (pendingIdx >= 0) {
        allRows[pendingIdx] = newRow;
      } else if (_editingOptions.insertRowPosition ==
          AiGridInsertRowPosition.bottom) {
        allRows.add(newRow);
      } else {
        allRows.insert(0, newRow);
      }
      _pendingNewRow = null;
    } else {
      final targetRow = _fitController!.data.view[_editingRowIndex!];
      final globalIndex = allRows.indexOf(targetRow);
      if (globalIndex != -1) {
        allRows[globalIndex] = Map<String, dynamic>.from(_draftRow!);
      }
    }
    _fitController!.data.rows = allRows;
    if (_dataSource is LocalAiGridDataSource) {
      (_dataSource as LocalAiGridDataSource).setData(allRows);
    }
    if (_activeDynamicDatasource != null && !_activeDynamicDatasource!.isReadonly) {
      AiGridDynamicStorage.updateDataRows(_activeDynamicDatasource!.name, allRows);
    }

    final savedRow = Map<String, dynamic>.from(_draftRow!);

    // Reset edit state
    _editingRowIndex = null;
    _isAddingRow = false;
    _draftRow = null;
    _validationErrors.clear();

    logEditEvent(AiGridEditEvent(
      action: 'save',
      rowIndex: targetIndex,
      message: isAdding
          ? 'Successfully added new record'
          : 'Successfully saved row #${targetIndex ?? 0}',
      data: savedRow,
    ));

    // 5. afterSave lifecycle hook
    _editingOptions.afterSave?.call(savedRow);

    notifyListeners();
    return null;
  }

  /// Deletes a row at [rowIndex] after running beforeDelete guard.
  Future<bool> deleteRow(int rowIndex) async {
    if (_activeDynamicDatasource?.isReadonly == true) return false;
    if (_fitController == null) return false;
    final viewRows = _fitController!.data.view;
    if (rowIndex < 0 || rowIndex >= viewRows.length) return false;

    final targetRow = viewRows[rowIndex];

    // 1. beforeDelete hook
    if (_editingOptions.beforeDelete != null) {
      final proceed = await _editingOptions.beforeDelete!(targetRow);
      if (!proceed) return false;
    }

    // 2. Remove row from dataset
    final allRows = List<Map<String, dynamic>>.from(_fitController!.data.rows);
    allRows.remove(targetRow);
    _fitController!.data.rows = allRows;
    if (_dataSource is LocalAiGridDataSource) {
      (_dataSource as LocalAiGridDataSource).setData(allRows);
    }
    if (_activeDynamicDatasource != null && !_activeDynamicDatasource!.isReadonly) {
      AiGridDynamicStorage.updateDataRows(_activeDynamicDatasource!.name, allRows);
    }

    final idVal = targetRow['OrderID'] ?? targetRow['id'] ?? targetRow['ID'] ?? '#$rowIndex';
    logEditEvent(AiGridEditEvent(
      action: 'delete',
      rowIndex: rowIndex,
      message: 'Deleted row #$rowIndex ($idVal)',
      data: targetRow,
    ));

    // 3. afterDelete hook
    _editingOptions.afterDelete?.call(targetRow);

    notifyListeners();
    return true;
  }

  /// Underlying FitGridController if attached.
  FitGridController<Map<String, dynamic>>? get fitController => _fitController;

  /// Compatibility getter for legacy callers.
  dynamic get stateManager => _fitController;

  /// Grid columns defined for this DataGrid.
  List<AiGridColumn> get columns => _columns;

  /// Active dataset rows.
  List<Map<String, dynamic>> get rows {
    if (_fitController != null) {
      return _fitController!.data.rows;
    } else if (_dataSource is LocalAiGridDataSource) {
      return (_dataSource as LocalAiGridDataSource).data;
    }
    return const [];
  }

  /// Active filtered and sorted view rows.
  List<Map<String, dynamic>> get viewRows {
    if (_fitController != null) {
      return _fitController!.data.view;
    } else if (_dataSource is LocalAiGridDataSource) {
      return (_dataSource as LocalAiGridDataSource).data;
    }
    return const [];
  }

  /// Active data source if attached.
  AiGridDataSource? get dataSource => _dataSource;

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
  set showColumnFilterRow(bool value) {
    if (_showColumnFilterRow == value) return;
    _showColumnFilterRow = value;
    notifyListeners();
  }

  /// Whether the top group panel is visible.
  bool get showGroupPanel => _showGroupPanel;
  set showGroupPanel(bool value) {
    if (_showGroupPanel == value) return;
    _showGroupPanel = value;
    notifyListeners();
  }

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
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) {
          notifyListeners();
        }
      });
    } else {
      notifyListeners();
    }
  }

  /// Attaches the controller to the rendered grid controller and data source.
  void attach({
    FitGridController<Map<String, dynamic>>? fitController,
    required List<AiGridColumn> columns,
    required AiGridDataSource dataSource,
    bool notify = false,
  }) {
    if (_fitController != null && _fitController != fitController && fitController != null) {
      _fitController!.data.removeListener(_onFitControllerChanged);
      _fitController!.columns.removeListener(_onFitControllerChanged);
      _fitController!.filter.removeListener(_onFitFilterChanged);
      _fitController!.range.removeListener(_onFitRangeChanged);
      _fitController!.details.removeListener(_onFitDetailsChanged);
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
    _fitController!.range.removeListener(_onFitRangeChanged);
    _fitController!.details.removeListener(_onFitDetailsChanged);
    _fitController!.data.addListener(_onFitControllerChanged);
    _fitController!.columns.addListener(_onFitControllerChanged);
    _fitController!.filter.addListener(_onFitFilterChanged);
    _fitController!.range.addListener(_onFitRangeChanged);
    _fitController!.details.addListener(_onFitDetailsChanged);

    if (_masterDetailOptions?.initiallyExpandedKeys != null) {
      for (final key in _masterDetailOptions!.initiallyExpandedKeys!) {
        _fitController!.details.setExpanded(key, true);
      }
      _previousExpandedKeys = Set<Object>.of(_fitController!.details.expanded);
    }

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

    if (notify) {
      notifyListeners();
    }
  }

  /// Loads a dynamic datasource into the grid, reconfiguring columns and rows.
  void loadDynamicDatasource(
    AiGridDynamicDescriptor descriptor,
    List<AiGridColumn> columns,
    List<Map<String, dynamic>> rows,
  ) {
    _activeDynamicDatasource = descriptor;
    final effectiveColumns = descriptor.isReadonly
        ? columns
            .map((c) => c.copyWith(editable: false, enableEditingMode: false))
            .toList()
        : columns;
    _columns = effectiveColumns;
    _dataSource = LocalAiGridDataSource(
      columns: effectiveColumns,
      initialData: rows,
    );

    if (_fitController != null) {
      _fitController!.columns.columns =
          effectiveColumns.map((c) => c.toFitGridColumn()).toList();
      _fitController!.data.rows = rows;
    } else {
      _fitController = FitGridController<Map<String, dynamic>>(
        columns: effectiveColumns.map((c) => c.toFitGridColumn()).toList(),
        rows: rows,
      );
    }

    // Seed initial column width overrides if declared
    for (final col in _columns) {
      if (col.width != null && col.width! > 0) {
        _fitController!.columns.setWidth(col.field, col.width!);
      }
    }

    _discardPendingRow();
    _editingRowIndex = null;
    _isAddingRow = false;
    _draftRow = null;
    _validationErrors.clear();

    _activeGrouping.clear();
    _activeFilters.clear();
    _activeSortColumn = null;
    _searchQuery = '';
    _hiddenFields.clear();

    AiGridDynamicStorage.setActiveDatasourceName(descriptor.name);
    notifyListeners();
  }

  /// Clears the active dynamic datasource and resets the grid to an empty table (no columns, no rows).
  void clearDynamicDatasource() {
    _discardPendingRow();
    _editingRowIndex = null;
    _isAddingRow = false;
    _draftRow = null;
    _validationErrors.clear();

    _activeDynamicDatasource = null;
    _columns = [];
    _dataSource = LocalAiGridDataSource(
      columns: const [],
      initialData: const [],
    );

    if (_fitController != null) {
      _fitController!.columns.columns = [];
      _fitController!.data.rows = [];
    }

    _activeGrouping.clear();
    _activeFilters.clear();
    _activeSortColumn = null;
    _searchQuery = '';
    _hiddenFields.clear();

    AiGridDynamicStorage.setActiveDatasourceName(null);
    notifyListeners();
  }

  /// Opens the modal popup [AiGridColumnEditorDialog] to edit a column's schema definition.
  /// Only available when the dynamic grid is not read-only.
  Future<bool?> showColumnEditorDialog(
    BuildContext context, {
    required String field,
  }) {
    return AiGridColumnEditorDialog.show(context, controller: this, field: field);
  }

  /// Opens the modal popup [AiGridColumnsEditorDialog] to edit and reorder all grid columns
  /// in an interactive, nested [AiGrid] table.
  /// Only available when the dynamic grid is not read-only.
  Future<bool?> showColumnsEditorDialog(BuildContext context) {
    return AiGridColumnsEditorDialog.show(context, controller: this);
  }

  /// Updates grid column definitions and syncs with the underlying FitGrid.
  void updateColumns(List<AiGridColumn> newColumns, {bool notify = true}) {
    _columns = List<AiGridColumn>.from(newColumns);
    if (_prePivotColumns != null) {
      _prePivotColumns = List<AiGridColumn>.from(_columns);
    }
    if (_dataSource is LocalAiGridDataSource) {
      _dataSource = LocalAiGridDataSource(
        columns: _columns,
        initialData: (_dataSource as LocalAiGridDataSource).data,
      );
    }
    _syncEffectiveColumns();
    if (notify) {
      notifyListeners();
    }
  }

  /// Updates all column definitions for this grid, syncing with the underlying engine,
  /// data source, and persisting updates to [AiGridDynamicStorage] if dynamic and writable.
  Future<bool> updateAllColumns(List<AiGridColumn> newColumns) async {
    _columns = List<AiGridColumn>.from(newColumns);
    if (_prePivotColumns != null) {
      _prePivotColumns = List<AiGridColumn>.from(_columns);
    }

    if (_dataSource is LocalAiGridDataSource) {
      _dataSource = LocalAiGridDataSource(
        columns: _columns,
        initialData: (_dataSource as LocalAiGridDataSource).data,
      );
    }

    _syncEffectiveColumns();
    if (_fitController != null) {
      for (final col in _columns) {
        if (col.width != null && col.width! > 0) {
          _fitController!.columns.setWidth(col.field, col.width!);
        }
      }
    }

    if (_activeDynamicDatasource != null &&
        !_activeDynamicDatasource!.isReadonly) {
      final existingModel =
          await AiGridDynamicStorage.getModel(_activeDynamicDatasource!.name);
      if (existingModel != null) {
        final updatedDynamicCols = _columns
            .map((c) => AiGridDynamicColumnModel.fromAiGridColumn(c))
            .toList();
        final updatedModel =
            existingModel.copyWith(columns: updatedDynamicCols);
        await AiGridDynamicStorage.updateModel(
            _activeDynamicDatasource!.name, updatedModel);
      }
    }

    notifyListeners();
    return true;
  }

  /// Updates the schema definition of column [field] (title/caption, data type,
  /// editability, editor type, required validation rule, and width / maxWidth constraints).
  ///
  /// Reconfigures columns in the active grid controller, data source, and persists
  /// updates to [AiGridDynamicStorage] if bound to an active, writable dynamic datasource.
  Future<bool> updateColumnDefinition({
    required String field,
    required String title,
    required AiGridColumnType type,
    required bool editable,
    required bool required,
    double? width,
    double? maxWidth,
    AiGridEditorType? editorType,
  }) async {
    final colIndex = _columns.indexWhere((c) => c.field == field);
    if (colIndex == -1) return false;
    final oldCol = _columns[colIndex];

    final updatedCol = AiGridColumn(
      field: oldCol.field,
      title: title,
      type: type,
      width: width,
      minWidth: oldCol.minWidth,
      maxWidth: maxWidth,
      resizable: oldCol.resizable,
      isGroupable: oldCol.isGroupable,
      isSortable: oldCol.isSortable,
      isFilterable: oldCol.isFilterable,
      editable: editable,
      enableEditingMode: editable,
      editorIndex: oldCol.editorIndex,
      editorType: editorType,
      editorOptions: oldCol.editorOptions,
      validator: oldCol.validator,
      required: required,
      onChanged: oldCol.onChanged,
      editorBuilder: oldCol.editorBuilder,
      aggregateType: oldCol.aggregateType,
      numberFormat: oldCol.numberFormat,
      selectOptions: oldCol.selectOptions,
      cellBuilder: oldCol.cellBuilder,
    );

    final updatedColumns = List<AiGridColumn>.from(_columns);
    updatedColumns[colIndex] = updatedCol;
    _columns = updatedColumns;

    if (_dataSource is LocalAiGridDataSource) {
      _dataSource = LocalAiGridDataSource(
        columns: updatedColumns,
        initialData: (_dataSource as LocalAiGridDataSource).data,
      );
    }

    if (_fitController != null) {
      _fitController!.columns.columns =
          updatedColumns.map((c) => c.toFitGridColumn()).toList();
      if (width != null && width > 0) {
        _fitController!.columns.setWidth(field, width);
      }
    }

    if (_activeDynamicDatasource != null &&
        !_activeDynamicDatasource!.isReadonly) {
      final existingModel =
          await AiGridDynamicStorage.getModel(_activeDynamicDatasource!.name);
      if (existingModel != null) {
        final updatedDynamicCols = updatedColumns
            .map((c) => AiGridDynamicColumnModel.fromAiGridColumn(c))
            .toList();
        final updatedModel =
            existingModel.copyWith(columns: updatedDynamicCols);
        await AiGridDynamicStorage.updateModel(
            _activeDynamicDatasource!.name, updatedModel);
      }
    }

    notifyListeners();
    return true;
  }

  /// The underlying cell range state, or null when not attached.
  FitGridCellRangeState? get cellRangeState => _fitController?.range;

  /// The active cell range selection rectangle, or null if no cells are selected.
  FitGridCellRange? get selectedCellRange => _fitController?.range.range;

  /// Whether a rectangular cell range is currently selected.
  bool get hasCellRangeSelection => _fitController?.range.isActive ?? false;

  /// Whether more than one cell is currently selected in the active range.
  bool get isMultiCellRangeSelected => _fitController?.range.isMultiCell ?? false;

  /// Selects a rectangular range of cells spanning from ([anchorRow], [anchorColumn])
  /// to ([extentRow], [extentColumn]).
  void selectCellRange({
    required int anchorRow,
    required String anchorColumn,
    required int extentRow,
    required String extentColumn,
    bool notify = true,
  }) {
    if (_fitController == null) return;
    _fitController!.range.range = FitGridCellRange(
      anchorRow: anchorRow,
      anchorColumnId: anchorColumn,
      extentRow: extentRow,
      extentColumnId: extentColumn,
    );
    if (notify) {
      notifyListeners();
    }
  }

  /// Selects a single cell as the active range anchor.
  void selectCell(int row, String columnField, {bool notify = true}) {
    if (_fitController == null) return;
    _fitController!.range.select(row, columnField);
    if (notify) {
      notifyListeners();
    }
  }

  /// Clears the active cell range selection.
  void clearCellRangeSelection({bool notify = true}) {
    if (_fitController == null) return;
    _fitController!.range.clear();
    if (notify) {
      notifyListeners();
    }
  }

  /// Computes summary statistical metrics (Count, Sum, Avg, Min, Max)
  /// for the currently selected cell range. Returns null if no range is active.
  AiGridRangeSummary? calculateSelectedRangeSummary() {
    final range = _fitController?.range.range;
    if (range == null || _fitController == null) return null;

    final displayedCols = _fitController!.columns.columns
        .where((c) => c.visible)
        .map((c) => c.id)
        .toList();
    final colFields = range.columnIdsIn(displayedCols);
    if (colFields.isEmpty) return null;

    final rows = _fitController!.data.view;
    final selectedRows = <Map<String, dynamic>>[];
    for (var r = range.firstRow; r <= range.lastRow && r < rows.length; r++) {
      selectedRows.add(rows[r]);
    }

    return AiGridRangeSummary.fromValues(
      rows: selectedRows,
      columnFields: colFields,
    );
  }

  /// Copies the currently selected rectangular cell range to the system clipboard
  /// as tab-separated values (TSV), compatible with Microsoft Excel, Google Sheets, etc.
  Future<bool> copySelectedRangeToClipboard({bool includeHeaders = false}) async {
    final range = _fitController?.range.range;
    if (range == null || _fitController == null) return false;

    final displayed = _fitController!.columns.columns
        .where((c) => c.visible)
        .toList();
    final colIds = range.columnIdsIn(displayed.map((c) => c.id).toList());
    if (colIds.isEmpty) return false;

    final buffer = StringBuffer();
    if (includeHeaders) {
      final headerTitles = colIds.map((id) {
        final col = displayed.firstWhere(
          (c) => c.id == id,
          orElse: () => displayed.first,
        );
        return col.label;
      }).join('\t');
      buffer.writeln(headerTitles);
    }

    final rows = _fitController!.data.view;
    for (var r = range.firstRow; r <= range.lastRow && r < rows.length; r++) {
      final row = rows[r];
      final line = colIds.map((id) => row[id]?.toString() ?? '').join('\t');
      buffer.writeln(line);
    }

    final text = buffer.toString().trimRight();
    if (text.isEmpty) return false;
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  }

  // ---------------------------------------------------------------------------
  // Master-Detail & Expandable Child Row Operations
  // ---------------------------------------------------------------------------

  AiGridMasterDetailOptions? _masterDetailOptions;
  Set<Object> _previousExpandedKeys = const <Object>{};

  /// Current master-detail options configured on this controller.
  AiGridMasterDetailOptions? get masterDetailOptions => _masterDetailOptions;

  /// Sets master-detail options and synchronizes initial expansion state.
  void setMasterDetailOptions(AiGridMasterDetailOptions? options) {
    if (_masterDetailOptions == options) return;
    _masterDetailOptions = options;
    if (options != null && options.initiallyExpandedKeys != null && _fitController != null) {
      for (final key in options.initiallyExpandedKeys!) {
        _fitController!.details.setExpanded(key, true);
      }
      _previousExpandedKeys = Set<Object>.of(_fitController!.details.expanded);
    }
    notifyListeners();
  }

  /// Whether the master-detail child row expansion is active and enabled.
  bool get isMasterDetailEnabled => _masterDetailOptions?.enabled == true;

  /// Returns the unmodifiable set of keys for currently expanded detail rows.
  Set<Object> get expandedDetailKeys =>
      _fitController?.details.expanded ?? const <Object>{};

  /// Whether any row detail panel is currently expanded.
  bool get hasExpandedDetails => expandedDetailKeys.isNotEmpty;

  /// Number of currently expanded detail panels.
  int get expandedDetailCount => expandedDetailKeys.length;

  /// Resolves the stable key for a given row map.
  Object resolveRowKey(Map<String, dynamic> row) {
    if (_masterDetailOptions?.rowKey != null) {
      return _masterDetailOptions!.rowKey!(row);
    }
    return row['id'] ?? row['order_id'] ?? row['key'] ?? row;
  }

  /// Checks if a row with [rowKey] is currently expanded.
  bool isRowExpanded(Object rowKey) =>
      _fitController?.details.isExpanded(rowKey) ?? false;

  /// Checks if the row at [rowIndex] in the active view is currently expanded.
  bool isRowExpandedAt(int rowIndex) {
    if (_fitController == null) return false;
    final view = _fitController!.data.view;
    if (rowIndex < 0 || rowIndex >= view.length) return false;
    return isRowExpanded(resolveRowKey(view[rowIndex]));
  }

  /// Expands the detail panel for the given [rowKey].
  void expandRow(Object rowKey) {
    if (_fitController == null) return;
    if (_masterDetailOptions?.autoCollapseOthers == true) {
      _fitController!.details.collapseAll();
    }
    _fitController!.details.setExpanded(rowKey, true);
  }

  /// Expands the detail panel for the row at [rowIndex] in the active view.
  void expandRowAt(int rowIndex) {
    if (_fitController == null) return;
    final view = _fitController!.data.view;
    if (rowIndex < 0 || rowIndex >= view.length) return;
    expandRow(resolveRowKey(view[rowIndex]));
  }

  /// Collapses the detail panel for the given [rowKey].
  void collapseRow(Object rowKey) {
    _fitController?.details.setExpanded(rowKey, false);
  }

  /// Collapses the detail panel for the row at [rowIndex] in the active view.
  void collapseRowAt(int rowIndex) {
    if (_fitController == null) return;
    final view = _fitController!.data.view;
    if (rowIndex < 0 || rowIndex >= view.length) return;
    collapseRow(resolveRowKey(view[rowIndex]));
  }

  /// Toggles expansion for the given [rowKey].
  void toggleRowDetail(Object rowKey) {
    if (_fitController == null) return;
    final willExpand = !isRowExpanded(rowKey);
    if (willExpand && _masterDetailOptions?.autoCollapseOthers == true) {
      _fitController!.details.collapseAll();
    }
    _fitController!.details.toggle(rowKey);
  }

  /// Toggles expansion for the row at [rowIndex] in the active view.
  void toggleRowDetailAt(int rowIndex) {
    if (_fitController == null) return;
    final view = _fitController!.data.view;
    if (rowIndex < 0 || rowIndex >= view.length) return;
    toggleRowDetail(resolveRowKey(view[rowIndex]));
  }

  /// Expands all rows in the active view (disabled in accordion mode).
  void expandAllDetails() {
    if (_fitController == null || _masterDetailOptions?.autoCollapseOthers == true) return;
    for (final row in _fitController!.data.view) {
      _fitController!.details.setExpanded(resolveRowKey(row), true);
    }
  }

  /// Collapses all currently expanded row details.
  void collapseAllDetails() {
    _fitController?.details.collapseAll();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _fitController?.data.removeListener(_onFitControllerChanged);
    _fitController?.columns.removeListener(_onFitControllerChanged);
    _fitController?.filter.removeListener(_onFitFilterChanged);
    _fitController?.range.removeListener(_onFitRangeChanged);
    _fitController?.details.removeListener(_onFitDetailsChanged);
    super.dispose();
  }

  void _onFitRangeChanged() {
    if (_disposed) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  void _onFitDetailsChanged() {
    if (_disposed) return;
    final current = _fitController?.details.expanded ?? const <Object>{};

    // Accordion Mode (autoCollapseOthers):
    if (_masterDetailOptions?.autoCollapseOthers == true && current.length > 1) {
      final newlyAdded = current.difference(_previousExpandedKeys);
      if (newlyAdded.isNotEmpty) {
        final keepKey = newlyAdded.last;
        for (final k in List<Object>.from(current)) {
          if (k != keepKey) {
            _fitController?.details.setExpanded(k, false);
          }
        }
      }
    }

    final updated = _fitController?.details.expanded ?? const <Object>{};
    final added = updated.difference(_previousExpandedKeys);
    final removed = _previousExpandedKeys.difference(updated);
    _previousExpandedKeys = Set<Object>.of(updated);

    if (_masterDetailOptions?.onExpansionChanged != null) {
      for (final k in added) {
        _masterDetailOptions!.onExpansionChanged!(k, true);
      }
      for (final k in removed) {
        _masterDetailOptions!.onExpansionChanged!(k, false);
      }
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
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
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) {
          notifyListeners();
        }
      });
    } else {
      notifyListeners();
    }
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

  // ===========================================================================
  // Pivot Table Support
  // ===========================================================================

  AiGridPivotConfig? _pivotConfig;
  List<Map<String, dynamic>>? _prePivotRows;
  List<AiGridColumn>? _prePivotColumns;
  List<String>? _prePivotGrouping;
  PivotChartData? _pivotChartData;
  List<FitGridColumnGroup> _pivotColumnGroups = const [];

  /// Whether the grid is currently displaying in aggregated Pivot Mode.
  bool get isPivotActive => _pivotConfig != null;

  /// Active pivot configuration, or null if in standard grid mode.
  AiGridPivotConfig? get pivotConfig => _pivotConfig;

  /// Active banded column groups generated for pivot mode.
  List<FitGridColumnGroup> get pivotColumnGroups =>
      List.unmodifiable(_pivotColumnGroups);

  /// Computed chart series data derived from the active pivot.
  PivotChartData? get pivotChartData => _pivotChartData;

  /// The original column definitions before pivot mode was activated.
  List<AiGridColumn> get originalColumns => _prePivotColumns ?? _columns;

  /// Transforms the grid on-the-fly into an aggregated Pivot Table.
  void setPivot(AiGridPivotConfig config) {
    if (config.rowFieldIds.isEmpty || config.values.isEmpty) {
      throw ArgumentError('Pivot requires at least one row field and one value field.');
    }

    final sourceRows = _prePivotRows ??
        List<Map<String, dynamic>>.from(
          _fitController?.data.rows ??
              (_dataSource is LocalAiGridDataSource
                  ? (_dataSource as LocalAiGridDataSource).data
                  : const <Map<String, dynamic>>[]),
        );
    if (sourceRows.isEmpty) return;

    _prePivotRows ??= sourceRows;
    _prePivotColumns ??= List<AiGridColumn>.from(_columns);
    _prePivotGrouping ??= List<String>.from(_activeGrouping);

    // Resolve column fields
    final resolvedRowIds = config.rowFieldIds
        .map((f) => _resolveField(f) ?? f)
        .toList();
    final resolvedColIds = config.columnFieldIds
        .map((f) => _resolveField(f) ?? f)
        .toList();

    // 1. Build row dimensions
    final rowDimensions = <FitGridPivotDimension<Map<String, dynamic>>>[
      for (final id in resolvedRowIds)
        FitGridPivotDimension<Map<String, dynamic>>(
          id: id,
          label: _columns.where((c) => c.field == id).firstOrNull?.title ?? id,
          keyOf: (row) => row[id]?.toString() ?? '(blank)',
        ),
    ];

    // 2. Build column dimension (single or composite)
    FitGridPivotDimension<Map<String, dynamic>>? colDimension;
    if (resolvedColIds.length == 1) {
      final colId = resolvedColIds.first;
      colDimension = FitGridPivotDimension<Map<String, dynamic>>(
        id: colId,
        label: _columns.where((c) => c.field == colId).firstOrNull?.title ?? colId,
        keyOf: (row) => row[colId]?.toString() ?? '(blank)',
      );
    } else if (resolvedColIds.length > 1) {
      final compId = resolvedColIds.join('__');
      final compLabel = resolvedColIds
          .map((id) => _columns.where((c) => c.field == id).firstOrNull?.title ?? id)
          .join(' / ');
      colDimension = FitGridPivotDimension<Map<String, dynamic>>(
        id: compId,
        label: compLabel,
        keyOf: (row) => resolvedColIds
            .map((id) => row[id]?.toString() ?? '(blank)')
            .join(' / '),
      );
    }

    // 3. Build value metrics
    final valueDimensions = <FitGridPivotValue<Map<String, dynamic>>>[
      for (final v in config.values) ...[
        () {
          final actualField = _resolveField(v.columnId) ?? v.columnId;
          final col = _columns.where((c) => c.field == actualField).firstOrNull;
          final title = col?.title ?? actualField;
          final effectiveLbl = v.effectiveLabel(title);

          return FitGridPivotValue<Map<String, dynamic>>(
            id: actualField,
            label: effectiveLbl,
            aggregation: v.aggregation.toFitGrid(),
            valueOf: (row) {
              final raw = row[actualField];
              if (raw is num) return raw;
              if (raw == null) return null;
              return num.tryParse(raw.toString().replaceAll(RegExp(r'[^0-9.-]'), ''));
            },
            format: v.format,
          );
        }(),
      ],
    ];

    // 4. Compute fitGridPivot
    final pivotResult = fitGridPivot<Map<String, dynamic>>(
      sourceRows,
      rows: rowDimensions,
      columns: colDimension,
      values: valueDimensions,
      columnTotals: config.showColumnTotals,
    );

    // 5. Convert pivotResult to Map<String, dynamic> rows
    final pivotedRows = <Map<String, dynamic>>[];
    for (final pr in pivotResult.rows) {
      final rowMap = <String, dynamic>{};
      for (var i = 0; i < rowDimensions.length; i++) {
        rowMap[rowDimensions[i].id] = pr.keys[i]?.toString() ?? '(blank)';
      }
      for (final cell in pr.cells.entries) {
        rowMap[cell.key] = cell.value;
      }
      pivotedRows.add(rowMap);
    }

    // 6. Build column groups (banded headers) & new AiGridColumns
    final columnGroups = <FitGridColumnGroup>[];
    final subTitleByColId = <String, String>{};

    if (colDimension != null) {
      final groupsMap = <String, List<String>>{};
      for (final col in pivotResult.columns.skip(rowDimensions.length)) {
        if (col.id.startsWith('total/')) {
          final valId = col.id.substring('total/'.length);
          final valDim = valueDimensions.where((v) => v.id == valId).firstOrNull;
          final subTitle = valDim?.label ?? valId;
          groupsMap.putIfAbsent('Grand Total', () => []).add(col.id);
          subTitleByColId[col.id] = subTitle;
        } else {
          // Format from fitGridPivot: '${columns.id}=${columns.labelOf(heading)}/${value.id}'
          final prefix = '${colDimension.id}=';
          if (col.id.startsWith(prefix)) {
            final rest = col.id.substring(prefix.length);
            final slashIdx = rest.lastIndexOf('/');
            if (slashIdx != -1) {
              final headingLabel = rest.substring(0, slashIdx);
              final valId = rest.substring(slashIdx + 1);
              final valDim = valueDimensions.where((v) => v.id == valId).firstOrNull;
              final subTitle = valDim?.label ?? valId;
              groupsMap.putIfAbsent(headingLabel, () => []).add(col.id);
              subTitleByColId[col.id] = subTitle;
            }
          }
        }
      }

      for (final entry in groupsMap.entries) {
        columnGroups.add(
          FitGridColumnGroup(
            id: entry.key,
            label: entry.key,
            columnIds: entry.value,
          ),
        );
      }
    }
    _pivotColumnGroups = columnGroups;

    final pivotedColumns = <AiGridColumn>[];

    // Row dimension columns (ungrouped, span full double-height header)
    for (var i = 0; i < rowDimensions.length; i++) {
      pivotedColumns.add(
        AiGridColumn(
          field: rowDimensions[i].id,
          title: rowDimensions[i].label,
          width: 140,
          type: AiGridColumnType.text,
        ),
      );
    }

    // Measure / value columns (nested under their column group band)
    for (final col in pivotResult.columns.skip(rowDimensions.length)) {
      final displayTitle = subTitleByColId[col.id] ?? col.label;
      pivotedColumns.add(
        AiGridColumn(
          field: col.id,
          title: displayTitle,
          width: 140,
          type: AiGridColumnType.number,
          aggregateType: AiGridAggregateType.sum,
          cellBuilder: (context, row, rowIndex) {
            final val = row[col.id];
            final isEmpty = val == null || val.toString().isEmpty;
            return Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                isEmpty
                    ? '—'
                    : (val is num
                        ? NumberFormat('#,##0.##').format(val)
                        : val.toString()),
                style: TextStyle(
                  fontSize: 12,
                  color: isEmpty ? Colors.grey[400] : null,
                  fontStyle: isEmpty ? FontStyle.italic : null,
                ),
              ),
            );
          },
        ),
      );
    }

    // 7. Generate chart data
    final categories = <String>[
      for (final pr in pivotResult.rows)
        pr.keys.map((k) => k?.toString() ?? '').join(' - '),
    ];

    final measureColumns = pivotResult.columns.skip(rowDimensions.length).toList();
    final seriesNames = <String>[for (final c in measureColumns) c.label];
    final matrix = <List<num>>[
      for (final c in measureColumns)
        <num>[
          for (final pr in pivotResult.rows)
            pr.cells[c.id] ?? 0,
        ],
    ];

    _pivotChartData = PivotChartData(
      categories: categories,
      seriesNames: seriesNames,
      values: matrix,
    );

    // 8. Apply to controller
    _pivotConfig = config;
    _columns = pivotedColumns;

    if (_fitController != null) {
      _fitController!.columns.columns =
          pivotedColumns.map((c) => c.toFitGridColumn()).toList();
      _fitController!.data.rows = pivotedRows;

      // DevExtreme-style hierarchical grouping when multiple row fields exist
      if (config.groupByRows && rowDimensions.length > 1) {
        final groupFields = rowDimensions
            .take(rowDimensions.length - 1)
            .map((d) => d.id)
            .toList();
        setGrouping(groupFields);
      } else {
        setGrouping([]);
      }
    }

    notifyListeners();
  }

  /// Restores the grid to the original standard editable table.
  void clearPivot() {
    if (!isPivotActive) return;

    final origRows = _prePivotRows;
    final origCols = _prePivotColumns;
    final origGrouping = _prePivotGrouping;

    _pivotConfig = null;
    _pivotColumnGroups = const [];
    _pivotChartData = null;
    _prePivotRows = null;
    _prePivotColumns = null;
    _prePivotGrouping = null;

    if (origCols != null) {
      _columns = origCols;
    }

    if (_fitController != null) {
      if (origCols != null) {
        _fitController!.columns.columns =
            origCols.map((c) => c.toFitGridColumn()).toList();
      }
      if (origRows != null) {
        _fitController!.data.rows = origRows;
      }
      if (origGrouping != null && origGrouping.isNotEmpty) {
        setGrouping(origGrouping);
      } else {
        clearGrouping();
      }
    }

    notifyListeners();
  }

  /// Toggles visibility of the side-by-side pivot chart.
  void togglePivotChart([bool? show]) {
    if (_pivotConfig == null) return;
    _pivotConfig = _pivotConfig!.copyWith(
      showChart: show ?? !_pivotConfig!.showChart,
    );
    notifyListeners();
  }

  /// Updates the active pivot chart visualization type.
  void setPivotChartType(AiGridPivotChartType type) {
    if (_pivotConfig == null) return;
    _pivotConfig = _pivotConfig!.copyWith(chartType: type);
    notifyListeners();
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
      'conditionalFormats':
          _conditionalFormats.map((f) => f.toJson()).toList(),
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

    // 5. Conditional Formats
    if (settings['conditionalFormats'] is List) {
      _conditionalFormats.clear();
      for (final item in settings['conditionalFormats'] as List) {
        if (item is Map<String, dynamic>) {
          _conditionalFormats.add(AiGridConditionalFormat.fromJson(item));
        }
      }
      _syncEffectiveColumns();
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
