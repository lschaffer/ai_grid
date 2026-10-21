import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:draggable_overlay_window/draggable_overlay_window.dart';
import 'package:material_ui/material_ui.dart';
import 'package:dart_mcp_core/dart_mcp_core.dart';

import '../config/ai_grid_config.dart';
import '../mcp/ai_grid_tools.dart';
import '../config/ai_grid_settings_storage.dart';
import '../controllers/ai_grid_controller.dart';
import '../fitgrid/fitgrid_table.dart';
import '../models/ai_grid_column.dart';
import '../models/ai_grid_data_source.dart';
import '../models/ai_grid_editing_options.dart';
import '../theme/ai_grid_theme.dart';
import 'ai_grid_assistant_panel.dart';
import 'ai_grid_group_panel.dart';
import 'ai_grid_toolbar.dart';
import 'ai_grid_pivot_chart.dart';

/// An intelligent DataGrid widget for Flutter powered by [FitGrid].
///
/// Combines high-performance canvas virtualization, hierarchical grouping,
/// inline column filtering, aggregate summary footers, global search,
/// and native AI assistant capabilities with responsive desktop (floating window)
/// and mobile (tab/full-screen view with dropdown actions) layouts.
class AiGrid extends StatefulWidget {
  final AiGridDataSource dataSource;
  final AiGridController? controller;
  final bool showToolbar;
  final bool enableAiAssistant;
  final AiGridConfig? aiConfig;
  final FitGridThemeData? theme;

  /// Optional configuration for backwards-compatibility.
  final dynamic configuration;
  final Future<void> Function(String prompt)? onAiPrompt;

  /// Whether client-side pagination should be enabled by default.
  final bool enablePagination;

  /// Page size if pagination is enabled.
  final int? pageSize;

  /// Whether to show the total number of rows in the pagination footer.
  final bool showTotalRows;

  /// Whether to display the "Go to Page" button in the pagination footer.
  final bool enableGotoPage;

  /// Whether changes to column visibility, grouping, sorting, and filters
  /// are automatically saved and restored when the grid initializes.
  final bool autoSave;

  /// Unique key used to persist grid settings when [autoSave] is true.
  final String persistenceKey;

  /// Optional initial settings map to apply when grid is loaded.
  final Map<String, dynamic>? initialSettings;

  /// Callback triggered whenever grid settings change.
  final void Function(Map<String, dynamic> settings)? onSettingsChanged;

  /// Optional editing configuration supporting cell, row, and form (popup) editing modes.
  final AiGridEditingOptions? editingOptions;

  /// Optional callback invoked when a row is double-tapped.
  final void Function(Map<String, dynamic> row, int rowIndex)? onRowDoubleTap;

  const AiGrid({
    super.key,
    required this.dataSource,
    this.controller,
    this.showToolbar = true,
    this.enableAiAssistant = true,
    this.aiConfig,
    this.theme,
    this.configuration,
    this.onAiPrompt,
    this.enablePagination = false,
    this.pageSize,
    this.showTotalRows = true,
    this.enableGotoPage = true,
    this.autoSave = false,
    this.persistenceKey = 'ai_grid_default_settings',
    this.initialSettings,
    this.onSettingsChanged,
    this.editingOptions,
    this.onRowDoubleTap,
    this.columnGroups,
    this.dynamicGrid = false,
    this.assistantBuilder,
  });

  /// Whether to enable dynamic DataGrid datasource management.
  final bool dynamicGrid;

  /// Optional custom assistant widget builder (e.g. for plugging in FlutterUiMcp).
  final Widget Function(
    BuildContext context,
    AiGridController controller,
    List<McpLocalTool> tools,
  )?
  assistantBuilder;

  /// Optional column groups (banded headers) to display above column headers.
  final List<FitGridColumnGroup>? columnGroups;

  @override
  State<AiGrid> createState() => _AiGridState();
}

class _AiGridState extends State<AiGrid> {
  late AiGridController _controller;
  late FitGridController<Map<String, dynamic>> _fitController;
  late final DraggableWindowController _draggableWindowController;
  bool _internalController = false;
  bool _isLoading = true;
  double _pivotSplitRatio = 0.60;
  double? _splitDragStartPos;
  double? _splitDragStartRatio;
  bool _isDraggingSplitter = false;

  AiGridEditMode? _lastEditMode;
  int? _lastEditingRowIndex;
  AiGridActionColumnPosition? _lastActionPos;
  bool? _lastAllowUpdating;
  bool? _lastAllowDeleting;
  List<AiGridColumn>? _lastColumns;

  List<AiGridColumn> get _effectiveColumns {
    if (_controller.columns.isNotEmpty) {
      return _controller.columns;
    }
    if (_controller.dataSource != null &&
        _controller.dataSource!.columns.isNotEmpty) {
      return _controller.dataSource!.columns;
    }
    return widget.dataSource.columns;
  }

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = AiGridController();
      _internalController = true;
    }
    if (widget.editingOptions != null) {
      _controller.setEditingOptions(widget.editingOptions!, notify: false);
    }

    _lastEditMode = _controller.editingOptions.mode;
    _lastEditingRowIndex = _controller.editingRowIndex;
    _lastActionPos = _controller.editingOptions.actionColumnPosition;
    _lastAllowUpdating = _controller.editingOptions.allowUpdating;
    _lastAllowDeleting = _controller.editingOptions.allowDeleting;

    final fitColumns = _buildFitColumns();
    _lastColumns = List.of(_effectiveColumns);
    _fitController = FitGridController<Map<String, dynamic>>(
      columns: fitColumns,
      rows: const [],
      selectionMode: FitGridSelectionMode.multiple,
    );

    for (final col in _effectiveColumns) {
      if (col.width != null && col.width! > 0) {
        _fitController.columns.setWidth(col.field, col.width!);
      }
    }

    if (widget.pageSize != null || widget.enablePagination) {
      _fitController.pagination.enabled = true;
      _fitController.pagination.pageSize = widget.pageSize ?? 40;
    }

    _controller.attach(
      fitController: _fitController,
      columns: widget.dataSource.columns,
      dataSource: widget.dataSource,
      notify: false,
    );

    _draggableWindowController = DraggableWindowController(
      initialPosition: const Offset(360, 60),
      initialSize: const Size(420, 540),
    );

    _controller.addListener(_syncAiAssistantWindowState);
    _controller.addListener(_onControllerStateChangedForAutoSave);
    _controller.addListener(_onControllerChangedForEditing);
    _controller.addListener(_onControllerChanged);
    if (_controller.showAiAssistant && widget.enableAiAssistant) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _draggableWindowController.show();
      });
    }

    _loadData();
    widget.dataSource.addListener(_onDataSourceChanged);
  }

  bool _hasRestoredSettings = false;

  void _restoreInitialSettingsIfNeeded() {
    if (_hasRestoredSettings) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        if (widget.initialSettings != null) {
          _controller.restoreSettings(widget.initialSettings!);
        } else if (widget.autoSave) {
          final saved =
              await AiGridSettingsStorage.loadAsync(widget.persistenceKey) ??
              AiGridSettingsStorage.load(widget.persistenceKey);
          if (saved != null && mounted) {
            _controller.restoreSettings(saved);
          }
        }
      } finally {
        _hasRestoredSettings = true;
      }
    });
  }

  void _onControllerStateChangedForAutoSave() {
    if (!_hasRestoredSettings || !_controller.isAttached) return;
    final current = _controller.exportSettings();
    widget.onSettingsChanged?.call(current);
    if (widget.autoSave) {
      AiGridSettingsStorage.save(widget.persistenceKey, current);
    }
  }

  void _syncAiAssistantWindowState() {
    if (_controller.showAiAssistant && !_draggableWindowController.isVisible) {
      _draggableWindowController.show();
    } else if (!_controller.showAiAssistant &&
        _draggableWindowController.isVisible) {
      _draggableWindowController.hide();
    }
  }

  @override
  void didUpdateWidget(covariant AiGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dataSource != oldWidget.dataSource) {
      oldWidget.dataSource.removeListener(_onDataSourceChanged);
      widget.dataSource.addListener(_onDataSourceChanged);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fitController.columns.columns = _buildFitColumns();
        _lastColumns = List.of(_effectiveColumns);
        _controller.attach(
          fitController: _fitController,
          columns: _effectiveColumns,
          dataSource: widget.dataSource,
          notify: false,
        );
        _loadData();
      });
    }
    if (widget.editingOptions != oldWidget.editingOptions &&
        widget.editingOptions != null) {
      _controller.setEditingOptions(widget.editingOptions!, notify: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fitController.columns.columns = _buildFitColumns();
        }
      });
    }
  }

  @override
  void dispose() {
    widget.dataSource.removeListener(_onDataSourceChanged);
    _controller.removeListener(_syncAiAssistantWindowState);
    _controller.removeListener(_onControllerStateChangedForAutoSave);
    _controller.removeListener(_onControllerChangedForEditing);
    _controller.removeListener(_onControllerChanged);
    _draggableWindowController.dispose();
    _fitController.dispose();
    if (_internalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onControllerChangedForEditing() {
    final opts = _controller.editingOptions;
    final currentCols = _effectiveColumns;
    final columnsChanged =
        _lastColumns == null ||
        _lastColumns!.length != currentCols.length ||
        !listEquals(_lastColumns, currentCols);

    if (_lastEditMode != opts.mode ||
        _lastEditingRowIndex != _controller.editingRowIndex ||
        _lastActionPos != opts.actionColumnPosition ||
        _lastAllowUpdating != opts.allowUpdating ||
        _lastAllowDeleting != opts.allowDeleting ||
        columnsChanged) {
      _lastEditMode = opts.mode;
      _lastEditingRowIndex = _controller.editingRowIndex;
      _lastActionPos = opts.actionColumnPosition;
      _lastAllowUpdating = opts.allowUpdating;
      _lastAllowDeleting = opts.allowDeleting;
      _lastColumns = List.of(currentCols);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fitController.columns.columns = _buildFitColumns();
        }
      });
    }
  }

  List<FitGridColumn<Map<String, dynamic>>> _buildFitColumns() {
    if (_controller.isPivotActive) {
      return _controller.columns.map((c) => c.toFitGridColumn()).toList();
    }
    final isReadonly = _controller.activeDynamicDatasource?.isReadonly ?? false;
    final opts = _controller.editingOptions;
    final isEditingEffective = opts.enabled && !isReadonly;
    final isRowMode = isEditingEffective && opts.mode == AiGridEditMode.row;
    final isFormMode = isEditingEffective && opts.mode == AiGridEditMode.form;

    final columns = _effectiveColumns.map((c) {
      if (isRowMode && c.isEditable && !isReadonly) {
        return _buildRowEditableColumn(c);
      }
      return c.toFitGridColumn();
    }).toList();

    if (isEditingEffective &&
        (isRowMode || isFormMode) &&
        (opts.allowUpdating || opts.allowDeleting)) {
      final actionCol = _buildActionColumn();
      if (opts.actionColumnPosition == AiGridActionColumnPosition.left) {
        columns.insert(0, actionCol);
      } else {
        columns.add(actionCol);
      }
    }

    return columns;
  }

  FitGridColumn<Map<String, dynamic>> _buildActionColumn() {
    final isLeft =
        _controller.editingOptions.actionColumnPosition ==
        AiGridActionColumnPosition.left;

    return FitGridColumn<Map<String, dynamic>>(
      id: '__actions__',
      label: 'Actions',
      width: const FitGridColumnWidth.fixed(100.0),
      freeze: isLeft ? FitGridFreeze.start : FitGridFreeze.end,
      resizable: false,
      sortable: false,
      reorderable: false,
      hideable: false,
      searchable: false,
      alignment: FitGridAlignment.center,
      value: (_) => '',
      cellBuilder: (context, row, rowIndex) {
        final isEditing =
            _controller.isEditingRow && _controller.editingRowIndex == rowIndex;

        if (isEditing) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Tooltip(
                message: 'Save',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () async {
                    final err = await _controller.saveEdit();
                    if (err != null && context.mounted) {
                      _showValidationErrorsDialog(context);
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.check, size: 18, color: Colors.green),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Cancel',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () {
                    _controller.cancelEdit();
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 18, color: Colors.red),
                  ),
                ),
              ),
            ],
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_controller.editingOptions.allowUpdating)
              Tooltip(
                message: 'Edit',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () {
                    if (_controller.editingOptions.mode ==
                        AiGridEditMode.form) {
                      _controller.showEditDialog(context, rowIndex: rowIndex);
                    } else {
                      _controller.startEdit(rowIndex);
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.edit_outlined, size: 18),
                  ),
                ),
              ),
            if (_controller.editingOptions.allowUpdating &&
                _controller.editingOptions.allowDeleting)
              const SizedBox(width: 6),
            if (_controller.editingOptions.allowDeleting)
              Tooltip(
                message: 'Delete',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () async {
                    if (await _confirmDelete(context)) {
                      await _controller.deleteRow(rowIndex);
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  FitGridColumn<Map<String, dynamic>> _buildRowEditableColumn(
    AiGridColumn col,
  ) {
    final base = col.toFitGridColumn();
    return base.copyWith(
      cellBuilder: (context, row, rowIndex) {
        final isEditingThisRow =
            _controller.isEditingRow && _controller.editingRowIndex == rowIndex;
        if (isEditingThisRow) {
          return _buildInlineCellEditor(context, col);
        }
        if (col.cellBuilder != null) {
          return col.cellBuilder!(context, row, rowIndex);
        }
        return Text(
          col.formatDisplayValue(row[col.field]),
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }

  Widget _buildInlineCellEditor(BuildContext context, AiGridColumn col) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final val = _controller.draftRow?[col.field];
        final error =
            _controller.validationErrors[col.field] ?? col.validate(val);
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        Widget editor;

        if (col.editorBuilder != null) {
          final custom = col.editorBuilder!(
            context,
            val,
            (newVal) => _controller.updateDraftValue(col.field, newVal),
          );
          editor = custom;
        } else if (col.editorType == AiGridEditorType.boolean ||
            col.type == AiGridColumnType.boolean) {
          final boolVal = val == true;
          editor = Center(
            child: Checkbox(
              value: boolVal,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (v) => _controller.updateDraftValue(col.field, v),
            ),
          );
        } else if (col.editorType == AiGridEditorType.select ||
            col.type == AiGridColumnType.select) {
          final options = <String>[];
          if (col.selectOptions != null) {
            options.addAll(col.selectOptions!);
          } else if (col.editorOptions?['items'] is List) {
            for (final item in col.editorOptions!['items'] as List) {
              options.add(item.toString());
            }
          }
          final currentStr = val?.toString();
          final effectiveVal = options.contains(currentStr) ? currentStr : null;

          editor = DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isDense: true,
              isExpanded: true,
              value: effectiveVal,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
              ),
              items: options
                  .map(
                    (opt) => DropdownMenuItem(
                      value: opt,
                      child: Text(
                        opt,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => _controller.updateDraftValue(col.field, v),
            ),
          );
        } else if (col.editorType == AiGridEditorType.date ||
            col.editorType == AiGridEditorType.dateTime ||
            col.type == AiGridColumnType.date) {
          final currentVal = val;
          final isDateTime = col.editorType == AiGridEditorType.dateTime;
          String dateStr = '';
          if (currentVal is DateTime) {
            dateStr = isDateTime
                ? DateFormat('yyyy-MM-dd HH:mm').format(currentVal)
                : DateFormat('yyyy-MM-dd').format(currentVal);
          } else if (currentVal != null) {
            dateStr = currentVal.toString();
          }

          editor = InkWell(
            onTap: () async {
              DateTime initDate = DateTime.now();
              if (currentVal is DateTime) {
                initDate = currentVal;
              } else if (currentVal != null) {
                final p = DateTime.tryParse(currentVal.toString());
                if (p != null) initDate = p;
              }
              final picked = await showDatePicker(
                context: context,
                initialDate: initDate,
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                if (isDateTime) {
                  if (!context.mounted) return;
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(initDate),
                  );
                  final dt = DateTime(
                    picked.year,
                    picked.month,
                    picked.day,
                    pickedTime?.hour ?? 0,
                    pickedTime?.minute ?? 0,
                  );
                  final formatted = DateFormat('yyyy-MM-dd HH:mm').format(dt);
                  _controller.updateDraftValue(col.field, formatted);
                } else {
                  final formatted = DateFormat('yyyy-MM-dd').format(picked);
                  _controller.updateDraftValue(col.field, formatted);
                }
              }
            },
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dateStr.isNotEmpty ? dateStr : 'Select date',
                    style: TextStyle(
                      fontSize: 13,
                      color: dateStr.isNotEmpty
                          ? (isDark ? Colors.white : Colors.black87)
                          : theme.hintColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  isDateTime
                      ? Icons.access_time_outlined
                      : Icons.calendar_today_outlined,
                  size: 15,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          );
        } else {
          // Text / Number / Currency
          final isNum =
              col.editorType == AiGridEditorType.number ||
              col.type == AiGridColumnType.number ||
              col.editorType == AiGridEditorType.currency ||
              col.type == AiGridColumnType.currency;

          final initial = val?.toString() ?? '';

          editor = TextFormField(
            key: ValueKey('inline_${col.field}_${_controller.editingRowIndex}'),
            initialValue: initial,
            autofocus:
                _controller.editingRowIndex != null &&
                _effectiveColumns.indexWhere((c) => c.isEditable) ==
                    _effectiveColumns.indexOf(col),
            showCursor: true,
            cursorColor: theme.colorScheme.primary,
            cursorWidth: 1.5,
            cursorRadius: const Radius.circular(1),
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white : Colors.black87,
            ),
            keyboardType: isNum
                ? const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  )
                : TextInputType.text,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
            ),
            onChanged: (newText) {
              if (isNum) {
                final parsed = num.tryParse(
                  newText.replaceAll(RegExp(r'[^0-9.-]'), ''),
                );
                _controller.updateDraftValue(
                  col.field,
                  parsed ?? (newText.isEmpty ? null : newText),
                );
              } else {
                _controller.updateDraftValue(
                  col.field,
                  newText.isEmpty ? null : newText,
                );
              }
            },
          );
        }

        final cellBackground = error != null
            ? Colors.red.withValues(alpha: isDark ? 0.2 : 0.08)
            : (isDark
                  ? theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    )
                  : const Color(0xFFFBFDFF));

        Widget styledCell = Focus(
          child: Builder(
            builder: (focusCtx) {
              final isFocused = Focus.of(focusCtx).hasFocus;
              final borderSideColor = error != null
                  ? Colors.redAccent
                  : isFocused
                  ? theme.colorScheme.primary
                  : (isDark ? Colors.white24 : Colors.grey.shade300);

              return Container(
                width: double.infinity,
                height: double.infinity,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cellBackground,
                  border: Border.all(
                    color: borderSideColor,
                    width: error != null || isFocused ? 1.5 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: editor,
              );
            },
          ),
        );

        if (error != null) {
          return Tooltip(
            message: error,
            preferBelow: false,
            waitDuration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: Colors.red.shade900,
              borderRadius: BorderRadius.circular(4),
            ),
            textStyle: const TextStyle(color: Colors.white, fontSize: 11),
            child: styledCell,
          );
        }

        return styledCell;
      },
    );
  }

  void _onDataSourceChanged() {
    _loadData();
  }

  FitGridEditTrigger get _editTrigger {
    final opts = _controller.editingOptions;
    return opts.enabled &&
            opts.allowUpdating &&
            opts.mode == AiGridEditMode.cell
        ? FitGridEditTrigger.singleTap
        : FitGridEditTrigger.programmatic;
  }

  Future<void> _showValidationErrorsDialog(BuildContext context) async {
    final errors = _controller.validationErrors;
    if (errors.isEmpty) return;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        title: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              'Validation Errors (${errors.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Please resolve the following errors before saving:',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: errors.entries.map((entry) {
                      final col = _effectiveColumns.firstWhere(
                        (c) => c.field == entry.key,
                        orElse: () =>
                            AiGridColumn(field: entry.key, title: entry.key),
                      );
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.red.withValues(alpha: 0.15)
                              : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark
                                ? Colors.redAccent.withValues(alpha: 0.3)
                                : const Color(0xFFFECACA),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Colors.redAccent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '${col.title}: ',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextSpan(
                                      text: entry.value,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.red.shade200
                                            : Colors.red.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
        title: const Text('Delete record'),
        content: const Text('Are you sure you want to delete this record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _loadData() async {
    if (!_isLoading && mounted) {
      setState(() => _isLoading = true);
    }
    final rows = await widget.dataSource.fetchRows();
    if (mounted) {
      setState(() {
        _fitController.data.rows = rows;
        _isLoading = false;
      });
      _restoreInitialSettingsIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final effectiveTheme =
        widget.theme ??
        (widget.configuration is FitGridThemeData
            ? widget.configuration as FitGridThemeData
            : AiGridTheme.createThemeFromContext(context));

    final borderColor = isDark
        ? colorScheme.outlineVariant.withAlpha(80)
        : AiGridTheme.borderColor;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 650;

            return Material(
              type: MaterialType.transparency,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? colorScheme.surface
                      : AiGridTheme.backgroundLight,
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: () {
                  final isLlmConfigured =
                      widget.aiConfig?.isLlmConfigured ??
                      (AiGridEnvLoader.createLlmConfigFromEnv()?.isConfigured ??
                          false);
                  return isMobile
                      ? _buildMobileLayout(
                          context,
                          isDark,
                          colorScheme,
                          borderColor,
                          effectiveTheme,
                          isLlmConfigured,
                        )
                      : _buildDesktopLayout(
                          context,
                          isDark,
                          colorScheme,
                          effectiveTheme,
                          isLlmConfigured,
                        );
                }(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
    Color borderColor,
    FitGridThemeData gridTheme,
    bool isLlmConfigured,
  ) {
    return Column(
      children: [
        if (widget.showToolbar)
          AiGridToolbar(
            controller: _controller,
            enableAiAssistant: widget.enableAiAssistant,
            isLlmConfigured: isLlmConfigured,
            hideIfNoLlm: widget.aiConfig?.hideAiAssistantIfNoLlm ?? false,
            onRefresh: _loadData,
            dynamicGrid: widget.dynamicGrid,
          ),
        if (widget.enableAiAssistant && isLlmConfigured) ...[
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerHighest
                  : const Color(0xFFF1F5F9),
              border: Border(bottom: BorderSide(color: borderColor, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _controller.setAiAssistantVisible(false),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: !_controller.showAiAssistant
                                ? colorScheme.primary
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.table_chart_outlined,
                            size: 15,
                            color: !_controller.showAiAssistant
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Data Grid',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: !_controller.showAiAssistant
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: !_controller.showAiAssistant
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _controller.setAiAssistantVisible(true),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _controller.showAiAssistant
                                ? colorScheme.primary
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 15,
                            color: _controller.showAiAssistant
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'AI Assistant',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _controller.showAiAssistant
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: _controller.showAiAssistant
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_controller.showAiAssistant && widget.enableAiAssistant)
          Expanded(
            child: widget.assistantBuilder != null
                ? widget.assistantBuilder!(
                    context,
                    _controller,
                    AiGridSkill.createTools(_controller),
                  )
                : AiGridAssistantPanel(
                    controller: _controller,
                    aiConfig: widget.aiConfig,
                    onSendPrompt: widget.onAiPrompt,
                    isFullScreen: true,
                    embeddedInWindow: false,
                    dynamicGrid: widget.dynamicGrid,
                  ),
          )
        else ...[
          AiGridGroupPanel(controller: _controller),
          Expanded(child: _buildGrid(context, gridTheme)),
        ],
      ],
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
    FitGridThemeData gridTheme,
    bool isLlmConfigured,
  ) {
    return OverlayWindowStack(
      windows: [
        if (widget.enableAiAssistant && isLlmConfigured)
          DraggableOverlayWindow(
            key: ValueKey(_draggableWindowController.windowId),
            controller: _draggableWindowController,
            title: 'AI Assistant',
            icon: Icons.auto_awesome,
            onClose: () => _controller.setAiAssistantVisible(false),
            config: DraggableWindowConfig(
              initialWidth: 420.0,
              initialHeight: 540.0,
              minWidth: 320.0,
              minHeight: 280.0,
              maxWidth: 900.0,
              maxHeight: 900.0,
              borderRadius: 12.0,
              elevation: 10.0,
              focusedElevation: 18.0,
              windowBackgroundColor: isDark
                  ? colorScheme.surfaceContainerHigh
                  : Colors.white,
              headerBackgroundColor: isDark
                  ? colorScheme.surfaceContainerHighest
                  : const Color(0xFFF1F5F9),
              borderColor: isDark
                  ? colorScheme.outlineVariant.withAlpha(90)
                  : AiGridTheme.borderColor,
              focusedBorderColor: colorScheme.primary,
              headerIconColor: colorScheme.primary,
              headerButtonsColor: colorScheme.onSurfaceVariant,
              headerTextStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'Segoe UI',
              ),
              resizable: true,
              enableScrolling: false,
              contentPadding: EdgeInsets.zero,
            ),
            content: widget.assistantBuilder != null
                ? widget.assistantBuilder!(
                    context,
                    _controller,
                    AiGridSkill.createTools(_controller),
                  )
                : AiGridAssistantPanel(
                    controller: _controller,
                    aiConfig: widget.aiConfig,
                    onSendPrompt: widget.onAiPrompt,
                    embeddedInWindow: true,
                    dynamicGrid: widget.dynamicGrid,
                  ),
          ),
      ],
      child: Column(
        children: [
          if (widget.showToolbar)
            AiGridToolbar(
              controller: _controller,
              enableAiAssistant: widget.enableAiAssistant,
              isLlmConfigured: isLlmConfigured,
              hideIfNoLlm: widget.aiConfig?.hideAiAssistantIfNoLlm ?? false,
              onRefresh: _loadData,
              dynamicGrid: widget.dynamicGrid,
            ),
          AiGridGroupPanel(controller: _controller),
          Expanded(child: _buildGrid(context, gridTheme)),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, FitGridThemeData gridTheme) {
    if (widget.dynamicGrid && (_fitController.columns.columns.isEmpty)) {
      final theme = Theme.of(context);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.table_chart_outlined,
              size: 52,
              color: theme.colorScheme.outline.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 14),
            Text(
              'No table loaded yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Attach a file in chat, paste tabular data (Ctrl+V), or click "+ New Datasource".',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.outline),
            ),
          ],
        ),
      );
    }

    final isReadonly =
        _controller.activeDynamicDatasource?.isReadonly ?? false;
    final effectiveEditTrigger = (_controller.isPivotActive ||
            isReadonly ||
            !_controller.editingOptions.enabled)
        ? FitGridEditTrigger.programmatic
        : _editTrigger;

    final gridWidget = FitGrid<Map<String, dynamic>>(
      controller: _fitController,
      theme: gridTheme,
      columnGroups: _controller.isPivotActive
          ? _controller.pivotColumnGroups
          : (widget.columnGroups ?? const <FitGridColumnGroup>[]),
      showFilterRow:
          !_controller.isPivotActive && _controller.showColumnFilterRow,
      showColumnMenu: true,
      columnMenuBuilder: (context, column, defaults) =>
          _buildColumnMenu(context, column, defaults),
      reorderableColumns: true,
      resizableColumns: true,
      multiSort: true,
      editTrigger: effectiveEditTrigger,
      paginated: widget.enablePagination || widget.pageSize != null,
      pageSize: widget.pageSize ?? 40,
      onRowDoubleTap: (row, rowIndex) {
        if (_controller.isPivotActive || isReadonly) return;
        if (widget.onRowDoubleTap != null) {
          widget.onRowDoubleTap!(row, rowIndex);
        } else if (_controller.editingOptions.enabled &&
            _controller.editingOptions.allowUpdating) {
          if (_controller.editingOptions.mode == AiGridEditMode.form) {
            _controller.showEditDialog(context, rowIndex: rowIndex);
          } else if (_controller.editingOptions.mode == AiGridEditMode.row) {
            _controller.startEdit(rowIndex);
          }
        }
      },
    );

    if (_controller.isPivotActive &&
        _controller.pivotConfig?.showChart == true &&
        _controller.pivotChartData != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;

          if (isWide) {
            final totalWidth = constraints.maxWidth;
            const splitterWidth = 8.0;
            final availableWidth = (totalWidth - splitterWidth).clamp(
              0.0,
              double.infinity,
            );
            final minGridWidth = 200.0;
            final minChartWidth = 200.0;
            final minRatio = availableWidth > (minGridWidth + minChartWidth)
                ? (minGridWidth / availableWidth)
                : 0.20;
            final maxRatio = availableWidth > (minGridWidth + minChartWidth)
                ? ((availableWidth - minChartWidth) / availableWidth)
                : 0.80;

            final effectiveRatio = _pivotSplitRatio.clamp(minRatio, maxRatio);
            final gridWidth = availableWidth * effectiveRatio;
            final chartWidth = (availableWidth - gridWidth).clamp(
              0.0,
              availableWidth,
            );

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: gridWidth, child: gridWidget),
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (details) {
                      setState(() {
                        _isDraggingSplitter = true;
                        _splitDragStartPos = details.globalPosition.dx;
                        _splitDragStartRatio = effectiveRatio;
                      });
                    },
                    onHorizontalDragUpdate: (details) {
                      if (_splitDragStartPos != null &&
                          _splitDragStartRatio != null &&
                          availableWidth > 0) {
                        final dx =
                            details.globalPosition.dx - _splitDragStartPos!;
                        final newRatio =
                            (_splitDragStartRatio! + (dx / availableWidth))
                                .clamp(minRatio, maxRatio);
                        setState(() {
                          _pivotSplitRatio = newRatio;
                        });
                      }
                    },
                    onHorizontalDragEnd: (_) {
                      setState(() {
                        _isDraggingSplitter = false;
                        _splitDragStartPos = null;
                        _splitDragStartRatio = null;
                      });
                    },
                    onHorizontalDragCancel: () {
                      setState(() {
                        _isDraggingSplitter = false;
                        _splitDragStartPos = null;
                        _splitDragStartRatio = null;
                      });
                    },
                    child: Container(
                      width: splitterWidth,
                      decoration: BoxDecoration(
                        color: _isDraggingSplitter
                            ? (isDark
                                  ? const Color(0xFF37373D)
                                  : const Color(0xFFE2E8F0))
                            : (isDark
                                  ? const Color(0xFF252526)
                                  : const Color(0xFFF1F5F9)),
                        border: Border(
                          left: BorderSide(
                            color: _isDraggingSplitter
                                ? theme.colorScheme.primary.withValues(
                                    alpha: 0.5,
                                  )
                                : (isDark
                                      ? const Color(0xFF333333)
                                      : const Color(0xFFE2E8F0)),
                          ),
                          right: BorderSide(
                            color: _isDraggingSplitter
                                ? theme.colorScheme.primary.withValues(
                                    alpha: 0.5,
                                  )
                                : (isDark
                                      ? const Color(0xFF333333)
                                      : const Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 2,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _isDraggingSplitter
                                ? theme.colorScheme.primary
                                : (isDark
                                      ? Colors.grey[600]
                                      : Colors.grey[400]),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: chartWidth,
                  child: AiGridPivotChart(
                    data: _controller.pivotChartData!,
                    chartType: _controller.pivotConfig!.chartType,
                    onChartTypeChanged: (type) =>
                        _controller.setPivotChartType(type),
                    onClose: () => _controller.togglePivotChart(false),
                  ),
                ),
              ],
            );
          } else {
            final totalHeight = constraints.maxHeight;
            const splitterHeight = 8.0;
            final availableHeight = (totalHeight - splitterHeight).clamp(
              0.0,
              double.infinity,
            );
            final minGridHeight = 140.0;
            final minChartHeight = 140.0;
            final minRatio = availableHeight > (minGridHeight + minChartHeight)
                ? (minGridHeight / availableHeight)
                : 0.20;
            final maxRatio = availableHeight > (minGridHeight + minChartHeight)
                ? ((availableHeight - minChartHeight) / availableHeight)
                : 0.80;

            final effectiveRatio = _pivotSplitRatio.clamp(minRatio, maxRatio);
            final gridHeight = availableHeight * effectiveRatio;
            final chartHeight = (availableHeight - gridHeight).clamp(
              0.0,
              availableHeight,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: gridHeight, child: gridWidget),
                MouseRegion(
                  cursor: SystemMouseCursors.resizeRow,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: (details) {
                      setState(() {
                        _isDraggingSplitter = true;
                        _splitDragStartPos = details.globalPosition.dy;
                        _splitDragStartRatio = effectiveRatio;
                      });
                    },
                    onVerticalDragUpdate: (details) {
                      if (_splitDragStartPos != null &&
                          _splitDragStartRatio != null &&
                          availableHeight > 0) {
                        final dy =
                            details.globalPosition.dy - _splitDragStartPos!;
                        final newRatio =
                            (_splitDragStartRatio! + (dy / availableHeight))
                                .clamp(minRatio, maxRatio);
                        setState(() {
                          _pivotSplitRatio = newRatio;
                        });
                      }
                    },
                    onVerticalDragEnd: (_) {
                      setState(() {
                        _isDraggingSplitter = false;
                        _splitDragStartPos = null;
                        _splitDragStartRatio = null;
                      });
                    },
                    onVerticalDragCancel: () {
                      setState(() {
                        _isDraggingSplitter = false;
                        _splitDragStartPos = null;
                        _splitDragStartRatio = null;
                      });
                    },
                    child: Container(
                      height: splitterHeight,
                      decoration: BoxDecoration(
                        color: _isDraggingSplitter
                            ? (isDark
                                  ? const Color(0xFF37373D)
                                  : const Color(0xFFE2E8F0))
                            : (isDark
                                  ? const Color(0xFF252526)
                                  : const Color(0xFFF1F5F9)),
                        border: Border(
                          top: BorderSide(
                            color: _isDraggingSplitter
                                ? theme.colorScheme.primary.withValues(
                                    alpha: 0.5,
                                  )
                                : (isDark
                                      ? const Color(0xFF333333)
                                      : const Color(0xFFE2E8F0)),
                          ),
                          bottom: BorderSide(
                            color: _isDraggingSplitter
                                ? theme.colorScheme.primary.withValues(
                                    alpha: 0.5,
                                  )
                                : (isDark
                                      ? const Color(0xFF333333)
                                      : const Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 36,
                          height: 2,
                          decoration: BoxDecoration(
                            color: _isDraggingSplitter
                                ? theme.colorScheme.primary
                                : (isDark
                                      ? Colors.grey[600]
                                      : Colors.grey[400]),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: chartHeight,
                  child: AiGridPivotChart(
                    data: _controller.pivotChartData!,
                    chartType: _controller.pivotConfig!.chartType,
                    onChartTypeChanged: (type) =>
                        _controller.setPivotChartType(type),
                    onClose: () => _controller.togglePivotChart(false),
                  ),
                ),
              ],
            );
          }
        },
      );
    }

    return gridWidget;
  }

  List<PopupMenuEntry<void>> _buildColumnMenu(
    BuildContext context,
    FitGridColumn<Map<String, dynamic>> column,
    List<PopupMenuEntry<void>> defaults,
  ) {
    if (column.id == '__actions__') {
      final isLeft =
          _controller.editingOptions.actionColumnPosition ==
          AiGridActionColumnPosition.left;
      PopupMenuItem<void> pinItem(
        String label,
        IconData icon,
        AiGridActionColumnPosition pos,
        bool enabled,
      ) => PopupMenuItem<void>(
        enabled: enabled,
        onTap: () => _controller.setEditingOptions(
          _controller.editingOptions.copyWith(actionColumnPosition: pos),
        ),
        child: Row(
          children: [
            SizedBox(width: 28, child: Icon(icon, size: 18)),
            Text(label),
          ],
        ),
      );
      return [
        pinItem(
          'Pin to start',
          Icons.keyboard_double_arrow_left,
          AiGridActionColumnPosition.left,
          !isLeft,
        ),
        pinItem(
          'Pin to end',
          Icons.keyboard_double_arrow_right,
          AiGridActionColumnPosition.right,
          isLeft,
        ),
      ];
    }
    final isGrouped = _controller.activeGrouping.contains(column.id);
    final groupItem = PopupMenuItem<void>(
      onTap: () {
        if (isGrouped) {
          _controller.removeGroup(column.id);
        } else {
          _controller.addGroup(column.id);
        }
      },
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Icon(
              isGrouped ? Icons.layers_clear_outlined : Icons.layers_outlined,
              size: 18,
            ),
          ),
          Flexible(
            child: Text(
              isGrouped
                  ? 'Ungroup by ${column.label}'
                  : 'Group by ${column.label}',
            ),
          ),
        ],
      ),
    );

    final entries = <PopupMenuEntry<void>>[groupItem];

    // Column Editor dialog for dynamic grid (enabled only for not read-only grid)
    final activeDynamic = _controller.activeDynamicDatasource;
    final isDynamic = widget.dynamicGrid || activeDynamic != null;
    final isNotReadonly = activeDynamic == null ? true : !activeDynamic.isReadonly;

    if (isDynamic && isNotReadonly) {
      entries.add(
        PopupMenuItem<void>(
          onTap: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _controller.showColumnEditorDialog(context, field: column.id);
            });
          },
          child: Row(
            children: [
              const SizedBox(
                width: 28,
                child: Icon(Icons.tune_rounded, size: 18),
              ),
              Flexible(
                child: Text('Edit Column "${column.label}"'),
              ),
            ],
          ),
        ),
      );
      entries.add(
        PopupMenuItem<void>(
          onTap: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _controller.showColumnsEditorDialog(context);
            });
          },
          child: const Row(
            children: [
              SizedBox(
                width: 28,
                child: Icon(Icons.view_column_rounded, size: 18),
              ),
              Flexible(
                child: Text('Edit All Columns...'),
              ),
            ],
          ),
        ),
      );
    }

    entries.add(const PopupMenuDivider());
    entries.addAll(defaults);
    return entries;
  }
}
