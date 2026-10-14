import 'package:intl/intl.dart';
import 'package:draggable_overlay_window/draggable_overlay_window.dart';
import 'package:material_ui/material_ui.dart';
import '../config/ai_grid_config.dart';
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
  });

  @override
  State<AiGrid> createState() => _AiGridState();
}

class _AiGridState extends State<AiGrid> {
  late AiGridController _controller;
  late FitGridController<Map<String, dynamic>> _fitController;
  late final DraggableWindowController _draggableWindowController;
  bool _internalController = false;
  bool _isLoading = true;

  AiGridEditMode? _lastEditMode;
  int? _lastEditingRowIndex;
  AiGridActionColumnPosition? _lastActionPos;
  bool? _lastAllowUpdating;
  bool? _lastAllowDeleting;

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
    _fitController = FitGridController<Map<String, dynamic>>(
      columns: fitColumns,
      rows: const [],
      selectionMode: FitGridSelectionMode.multiple,
    );

    for (final col in widget.dataSource.columns) {
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
    } else if (!_controller.showAiAssistant && _draggableWindowController.isVisible) {
      _draggableWindowController.hide();
    }
  }

  @override
  void didUpdateWidget(covariant AiGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dataSource != oldWidget.dataSource) {
      oldWidget.dataSource.removeListener(_onDataSourceChanged);
      widget.dataSource.addListener(_onDataSourceChanged);
      _fitController.columns.columns = _buildFitColumns();
      _controller.attach(
        fitController: _fitController,
        columns: widget.dataSource.columns,
        dataSource: widget.dataSource,
        notify: false,
      );
      _loadData();
    }
    if (widget.editingOptions != oldWidget.editingOptions && widget.editingOptions != null) {
      _controller.setEditingOptions(widget.editingOptions!, notify: false);
      _fitController.columns.columns = _buildFitColumns();
    }
  }

  @override
  void dispose() {
    widget.dataSource.removeListener(_onDataSourceChanged);
    _controller.removeListener(_syncAiAssistantWindowState);
    _controller.removeListener(_onControllerStateChangedForAutoSave);
    _controller.removeListener(_onControllerChangedForEditing);
    _draggableWindowController.dispose();
    _fitController.dispose();
    if (_internalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onControllerChangedForEditing() {
    final opts = _controller.editingOptions;
    if (_lastEditMode != opts.mode ||
        _lastEditingRowIndex != _controller.editingRowIndex ||
        _lastActionPos != opts.actionColumnPosition ||
        _lastAllowUpdating != opts.allowUpdating ||
        _lastAllowDeleting != opts.allowDeleting) {
      _lastEditMode = opts.mode;
      _lastEditingRowIndex = _controller.editingRowIndex;
      _lastActionPos = opts.actionColumnPosition;
      _lastAllowUpdating = opts.allowUpdating;
      _lastAllowDeleting = opts.allowDeleting;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fitController.columns.columns = _buildFitColumns();
        }
      });
    }
  }

  List<FitGridColumn<Map<String, dynamic>>> _buildFitColumns() {
    final opts = _controller.editingOptions;
    final isRowMode = opts.enabled && opts.mode == AiGridEditMode.row;
    final isFormMode = opts.enabled && opts.mode == AiGridEditMode.form;

    final columns = widget.dataSource.columns.map((c) {
      if (isRowMode && c.isEditable) {
        return _buildRowEditableColumn(c);
      }
      return c.toFitGridColumn();
    }).toList();

    if ((isRowMode || isFormMode) &&
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
    final isLeft = _controller.editingOptions.actionColumnPosition ==
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
                    await _controller.saveEdit();
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
                    child: Icon(Icons.delete_outline,
                        size: 18, color: Colors.redAccent),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  FitGridColumn<Map<String, dynamic>> _buildRowEditableColumn(AiGridColumn col) {
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
        final error = _controller.validationErrors[col.field] ?? col.validate(val);

        Widget editor;

        if (col.editorBuilder != null) {
          final custom = col.editorBuilder!(
            context,
            val,
            (newVal) => _controller.updateDraftValue(col.field, newVal),
          );
          editor = Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: error != null ? Colors.redAccent : Colors.transparent,
                width: error != null ? 1.5 : 1.0,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: custom,
          );
        } else if (col.editorType == AiGridEditorType.boolean ||
            col.type == AiGridColumnType.boolean) {
          final boolVal = val == true;
          editor = Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: error != null ? Colors.redAccent : Colors.transparent,
                width: error != null ? 1.5 : 1.0,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Checkbox(
                value: boolVal,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) => _controller.updateDraftValue(col.field, v),
              ),
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

          editor = Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: error != null ? Colors.redAccent : Colors.grey.shade400,
                width: error != null ? 1.5 : 1.0,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: DropdownButton<String>(
              isDense: true,
              isExpanded: true,
              underline: const SizedBox(),
              value: effectiveVal,
              items: options
                  .map((opt) => DropdownMenuItem(
                        value: opt,
                        child: Text(opt, style: const TextStyle(fontSize: 12)),
                      ))
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

          editor = Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: error != null ? Colors.redAccent : Colors.grey.shade400,
                width: error != null ? 1.5 : 1.0,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: InkWell(
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDateTime
                        ? Icons.access_time_outlined
                        : Icons.calendar_today_outlined,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      dateStr.isNotEmpty ? dateStr : 'Select',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          // Text / Number / Currency
          final isNum = col.editorType == AiGridEditorType.number ||
              col.type == AiGridColumnType.number ||
              col.editorType == AiGridEditorType.currency ||
              col.type == AiGridColumnType.currency;

          final initial = val?.toString() ?? '';

          editor = TextFormField(
            key: ValueKey('inline_${col.field}_${_controller.editingRowIndex}'),
            initialValue: initial,
            style: const TextStyle(fontSize: 12),
            keyboardType: isNum
                ? const TextInputType.numberWithOptions(decimal: true, signed: true)
                : TextInputType.text,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              border: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(4)),
                borderSide: BorderSide(
                  color: error != null ? Colors.redAccent : Colors.grey.shade400,
                  width: error != null ? 1.5 : 1.0,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(4)),
                borderSide: BorderSide(
                  color: error != null ? Colors.redAccent : Colors.grey.shade400,
                  width: error != null ? 1.5 : 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(4)),
                borderSide: BorderSide(
                  color: error != null
                      ? Colors.redAccent
                      : Theme.of(context).colorScheme.primary,
                  width: 1.5,
                ),
              ),
            ),
            onChanged: (newText) {
              if (isNum) {
                final parsed = num.tryParse(newText.replaceAll(RegExp(r'[^0-9.-]'), ''));
                _controller.updateDraftValue(col.field, parsed ?? (newText.isEmpty ? null : newText));
              } else {
                _controller.updateDraftValue(col.field, newText.isEmpty ? null : newText);
              }
            },
          );
        }

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
            child: editor,
          );
        }

        return editor;
      },
    );
  }

  void _onDataSourceChanged() {
    _loadData();
  }

  FitGridEditTrigger get _editTrigger {
    final opts = _controller.editingOptions;
    return opts.enabled && opts.allowUpdating && opts.mode == AiGridEditMode.cell
        ? FitGridEditTrigger.singleTap
        : FitGridEditTrigger.programmatic;
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
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final effectiveTheme = widget.theme ??
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
                  color: isDark ? colorScheme.surface : AiGridTheme.backgroundLight,
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: () {
                  final isLlmConfigured = widget.aiConfig?.isLlmConfigured ??
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
          ),
        if (widget.enableAiAssistant && isLlmConfigured) ...[
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerHighest
                  : const Color(0xFFF1F5F9),
              border: Border(
                bottom: BorderSide(color: borderColor, width: 1),
              ),
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
            child: AiGridAssistantPanel(
              controller: _controller,
              aiConfig: widget.aiConfig,
              onSendPrompt: widget.onAiPrompt,
              isFullScreen: true,
              embeddedInWindow: false,
            ),
          )
        else ...[
          AiGridGroupPanel(controller: _controller),
          Expanded(
            child: FitGrid<Map<String, dynamic>>(
              controller: _fitController,
              theme: gridTheme,
              showFilterRow: _controller.showColumnFilterRow,
              showColumnMenu: true,
              columnMenuBuilder: (context, column, defaults) =>
                  _buildColumnMenu(context, column, defaults),
              reorderableColumns: true,
              resizableColumns: true,
              multiSort: true,
              editTrigger: _editTrigger,
              paginated: widget.enablePagination || widget.pageSize != null,
              pageSize: widget.pageSize ?? 40,
              onRowDoubleTap: (row, rowIndex) {
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
            ),
          ),
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
            content: AiGridAssistantPanel(
              controller: _controller,
              aiConfig: widget.aiConfig,
              onSendPrompt: widget.onAiPrompt,
              embeddedInWindow: true,
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
            ),
          AiGridGroupPanel(controller: _controller),
          Expanded(
            child: FitGrid<Map<String, dynamic>>(
              controller: _fitController,
              theme: gridTheme,
              showFilterRow: _controller.showColumnFilterRow,
              showColumnMenu: true,
              columnMenuBuilder: (context, column, defaults) =>
                  _buildColumnMenu(context, column, defaults),
              reorderableColumns: true,
              resizableColumns: true,
              multiSort: true,
              editTrigger: _editTrigger,
              paginated: widget.enablePagination || widget.pageSize != null,
              pageSize: widget.pageSize ?? 40,
              onRowDoubleTap: (row, rowIndex) {
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
            ),
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<void>> _buildColumnMenu(
    BuildContext context,
    FitGridColumn<Map<String, dynamic>> column,
    List<PopupMenuEntry<void>> defaults,
  ) {
    if (column.id == '__actions__') {
      final isLeft = _controller.editingOptions.actionColumnPosition ==
          AiGridActionColumnPosition.left;
      PopupMenuItem<void> pinItem(String label, IconData icon,
              AiGridActionColumnPosition pos, bool enabled) =>
          PopupMenuItem<void>(
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
        pinItem('Pin to start', Icons.keyboard_double_arrow_left,
            AiGridActionColumnPosition.left, !isLeft),
        pinItem('Pin to end', Icons.keyboard_double_arrow_right,
            AiGridActionColumnPosition.right, isLeft),
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
              isGrouped ? 'Ungroup by ${column.label}' : 'Group by ${column.label}',
            ),
          ),
        ],
      ),
    );

    return [
      groupItem,
      const PopupMenuDivider(),
      ...defaults,
    ];
  }
}
