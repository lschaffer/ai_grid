import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../controllers/ai_grid_controller.dart';
import '../models/ai_grid_column.dart';
import '../models/ai_grid_data_source.dart';
import '../models/ai_grid_editing_options.dart';
import 'ai_grid.dart';

/// Generic columns editor dialog that allows editing and reordering all columns of an
/// [AiGrid] within an interactive, nested [AiGrid] table.
///
/// Restricted to active grids that are not marked as read-only.
class AiGridColumnsEditorDialog extends StatefulWidget {
  final AiGridController controller;

  const AiGridColumnsEditorDialog({super.key, required this.controller});

  /// Opens the [AiGridColumnsEditorDialog] modally.
  /// Returns `true` if changes were saved and applied.
  static Future<bool?> show(
    BuildContext context, {
    required AiGridController controller,
  }) {
    if (controller.activeDynamicDatasource?.isReadonly == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot edit columns on a read-only table.'),
        ),
      );
      return Future.value(false);
    }

    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: const Color(0x80000000),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        Widget content = AiGridColumnsEditorDialog(controller: controller);

        final hasLoc =
            Localizations.of<MaterialLocalizations>(
              dialogContext,
              MaterialLocalizations,
            ) !=
            null;
        if (!hasLoc) {
          content = Localizations(
            locale: const Locale('en', 'US'),
            delegates: const [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            child: content,
          );
        }

        return SafeArea(child: content);
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<AiGridColumnsEditorDialog> createState() =>
      _AiGridColumnsEditorDialogState();
}

class _AiGridColumnsEditorDialogState extends State<AiGridColumnsEditorDialog> {
  late final AiGridController _editorController;
  late final LocalAiGridDataSource _editorDataSource;
  late List<Map<String, dynamic>> _columnRows;

  bool _isSaving = false;

  static const List<String> _availableTypes = [
    'text',
    'number',
    'date',
    'datetime',
    'currency',
    'boolean',
    'select',
  ];

  static String _defaultEditorTypeFor(String type) {
    switch (type.toLowerCase()) {
      case 'number':
        return 'number';
      case 'currency':
        return 'currency';
      case 'date':
        return 'date';
      case 'datetime':
        return 'dateTime';
      case 'boolean':
        return 'boolean';
      case 'select':
        return 'select';
      case 'text':
      default:
        return 'text';
    }
  }

  static List<String> _compatibleEditorTypesFor(String type) {
    switch (type.toLowerCase()) {
      case 'number':
      case 'currency':
        return const ['', 'number', 'currency'];
      case 'date':
        return const ['', 'date', 'dateTime'];
      case 'datetime':
        return const ['', 'dateTime', 'date'];
      case 'boolean':
        return const ['', 'boolean'];
      case 'select':
        return const ['', 'select', 'text'];
      case 'text':
      default:
        return const ['', 'text', 'select'];
    }
  }

  static String _formatEditorTypeName(String key) {
    switch (key.toLowerCase()) {
      case 'text':
        return 'Text Input';
      case 'number':
        return 'Number Input';
      case 'currency':
        return 'Currency (\$)';
      case 'date':
        return 'Date Picker';
      case 'datetime':
        return 'Date & Time';
      case 'boolean':
        return 'Checkbox';
      case 'select':
        return 'Dropdown';
      default:
        return '(Default)';
    }
  }

  @override
  void initState() {
    super.initState();
    _columnRows = widget.controller.columns
        .map((c) => _columnToRow(c))
        .toList();

    _editorDataSource = LocalAiGridDataSource(
      columns: _buildInnerEditorColumns(),
      initialData: _columnRows,
    );

    _editorController = AiGridController();
    _editorController.editingOptions = const AiGridEditingOptions(
      enabled: true,
      mode: AiGridEditMode.cell,
      allowAdding: true,
      allowDeleting: true,
    );
  }

  @override
  void dispose() {
    _editorController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _columnToRow(AiGridColumn col) {
    return {
      'field': col.field,
      'title': col.title,
      'type': col.type.name,
      'editable': col.isEditable,
      'required': col.required,
      'width': col.width != null && col.width! > 0 ? col.width! : null,
      'maxWidth': col.maxWidth != null && col.maxWidth! > 0
          ? col.maxWidth!
          : null,
      'editorType': col.editorType?.name ?? '',
    };
  }

  AiGridColumn _rowToColumn(
    Map<String, dynamic> row, [
    AiGridColumn? originalCol,
  ]) {
    final field = row['field']?.toString().trim() ?? '';
    final title = row['title']?.toString().trim() ?? field;
    final typeStr = row['type']?.toString().toLowerCase();

    AiGridColumnType type = AiGridColumnType.text;
    for (final t in AiGridColumnType.values) {
      if (t.name.toLowerCase() == typeStr) {
        type = t;
        break;
      }
    }

    final isEditable =
        row['editable'] == true ||
        row['editable']?.toString().toLowerCase() == 'true';
    final isRequired =
        row['required'] == true ||
        row['required']?.toString().toLowerCase() == 'true';

    final wVal = row['width'];
    final num? widthNum = wVal is num
        ? wVal
        : num.tryParse(wVal?.toString() ?? '');
    final double? width = (widthNum != null && widthNum > 0)
        ? widthNum.toDouble()
        : null;

    final maxWVal = row['maxWidth'];
    final num? maxWNum = maxWVal is num
        ? maxWVal
        : num.tryParse(maxWVal?.toString() ?? '');
    final double? maxWidth = (maxWNum != null && maxWNum > 0)
        ? maxWNum.toDouble()
        : null;

    AiGridEditorType? editorType;
    final editorTypeStr = row['editorType']?.toString().toLowerCase();
    if (editorTypeStr != null && editorTypeStr.isNotEmpty) {
      for (final e in AiGridEditorType.values) {
        if (e.name.toLowerCase() == editorTypeStr) {
          editorType = e;
          break;
        }
      }
    }

    return AiGridColumn(
      field: field,
      title: title,
      type: type,
      editable: isEditable,
      enableEditingMode: isEditable,
      required: isRequired,
      width: width,
      maxWidth: maxWidth,
      editorType: isEditable ? editorType : null,
      minWidth: originalCol?.minWidth ?? 50.0,
      resizable: originalCol?.resizable ?? true,
      isGroupable: originalCol?.isGroupable ?? true,
      isSortable: originalCol?.isSortable ?? true,
      isFilterable: originalCol?.isFilterable ?? true,
      editorOptions: originalCol?.editorOptions,
      validator: originalCol?.validator,
      onChanged: originalCol?.onChanged,
      editorBuilder: originalCol?.editorBuilder,
      aggregateType: originalCol?.aggregateType ?? AiGridAggregateType.none,
      numberFormat: originalCol?.numberFormat,
      selectOptions: originalCol?.selectOptions,
      cellBuilder: originalCol?.cellBuilder,
    );
  }

  List<AiGridColumn> _buildInnerEditorColumns() {
    return [
      const AiGridColumn(
        field: 'field',
        title: 'Field Identifier',
        width: 140,
        type: AiGridColumnType.text,
        editable: true,
        required: true,
      ),
      const AiGridColumn(
        field: 'title',
        title: 'Caption / Header',
        width: 170,
        type: AiGridColumnType.text,
        editable: true,
        required: true,
      ),
      AiGridColumn(
        field: 'type',
        title: 'Data Type',
        width: 135,
        type: AiGridColumnType.select,
        editable: true,
        cellBuilder: (context, row, rowIndex) {
          final current = row['type']?.toString().toLowerCase() ?? 'text';
          final effective = _availableTypes.contains(current)
              ? current
              : 'text';
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.centerLeft,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: effective,
                isDense: true,
                isExpanded: true,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                items: _availableTypes
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(
                          t == 'datetime'
                              ? 'DateTime'
                              : t[0].toUpperCase() + t.substring(1),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      row['type'] = v;
                      row['editorType'] = _defaultEditorTypeFor(v);
                    });
                  }
                },
              ),
            ),
          );
        },
      ),
      AiGridColumn(
        field: 'editable',
        title: 'Editable',
        width: 85,
        type: AiGridColumnType.boolean,
        editable: true,
        cellBuilder: (context, row, rowIndex) {
          final val =
              row['editable'] == true ||
              row['editable']?.toString().toLowerCase() == 'true';
          return Center(
            child: Checkbox(
              value: val,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (v) {
                setState(() {
                  row['editable'] = v ?? false;
                });
              },
            ),
          );
        },
      ),
      AiGridColumn(
        field: 'required',
        title: 'Required',
        width: 85,
        type: AiGridColumnType.boolean,
        editable: true,
        cellBuilder: (context, row, rowIndex) {
          final val =
              row['required'] == true ||
              row['required']?.toString().toLowerCase() == 'true';
          return Center(
            child: Checkbox(
              value: val,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (v) {
                setState(() {
                  row['required'] = v ?? false;
                });
              },
            ),
          );
        },
      ),
      const AiGridColumn(
        field: 'width',
        title: 'Width (px)',
        width: 100,
        type: AiGridColumnType.number,
        editable: true,
      ),
      const AiGridColumn(
        field: 'maxWidth',
        title: 'Max Width',
        width: 110,
        type: AiGridColumnType.number,
        editable: true,
      ),
      AiGridColumn(
        field: 'editorType',
        title: 'Editor Control',
        width: 140,
        type: AiGridColumnType.select,
        editable: true,
        cellBuilder: (context, row, rowIndex) {
          final current = row['editorType']?.toString().toLowerCase() ?? '';
          final dataType = row['type']?.toString().toLowerCase() ?? 'text';
          final compatible = _compatibleEditorTypesFor(dataType);
          final effective = compatible.contains(current)
              ? current
              : (compatible.isNotEmpty ? compatible.first : '');
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.centerLeft,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: effective,
                isDense: true,
                isExpanded: true,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                items: compatible
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(
                          _formatEditorTypeName(e),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      row['editorType'] = v;
                    });
                  }
                },
              ),
            ),
          );
        },
      ),
      AiGridColumn(
        field: '__actions__',
        title: 'Actions',
        width: 115,
        minWidth: 105,
        resizable: false,
        isSortable: false,
        isFilterable: false,
        isGroupable: false,
        cellBuilder: (context, row, rowIndex) {
          final total = _columnRows.length;
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 16),
                  tooltip: 'Move Up',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 26,
                    minHeight: 26,
                  ),
                  onPressed: rowIndex > 0 ? () => _moveRow(rowIndex, -1) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward, size: 16),
                  tooltip: 'Move Down',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 26,
                    minHeight: 26,
                  ),
                  onPressed: rowIndex < total - 1
                      ? () => _moveRow(rowIndex, 1)
                      : null,
                ),
                const SizedBox(width: 2),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 17,
                    color: Colors.redAccent,
                  ),
                  tooltip: 'Delete Column',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 26,
                    minHeight: 26,
                  ),
                  onPressed: () => _handleDeleteRow(rowIndex),
                ),
              ],
            ),
          );
        },
      ),
    ];
  }

  void _handleAddColumn() {
    final currentRows = List<Map<String, dynamic>>.from(
      _editorController.fitController?.data.rows ?? _columnRows,
    );
    var count = currentRows.length + 1;
    var field = 'column_$count';
    while (currentRows.any((r) => r['field'] == field)) {
      count++;
      field = 'column_$count';
    }

    final newRow = <String, dynamic>{
      'field': field,
      'title': 'Column $count',
      'type': 'text',
      'editable': true,
      'required': false,
      'width': 140,
      'maxWidth': 0,
      'editorType': 'text',
    };

    currentRows.add(newRow);
    _columnRows = currentRows;
    _editorDataSource.setData(currentRows);
    if (_editorController.fitController != null) {
      _editorController.fitController!.data.rows = currentRows;
    }
    setState(() {});
  }

  void _moveRow(int index, int delta) {
    final currentRows = List<Map<String, dynamic>>.from(
      _editorController.fitController?.data.rows ?? _columnRows,
    );
    final target = index + delta;
    if (target < 0 || target >= currentRows.length) return;
    final item = currentRows.removeAt(index);
    currentRows.insert(target, item);

    _columnRows = currentRows;
    _editorDataSource.setData(currentRows);
    if (_editorController.fitController != null) {
      _editorController.fitController!.data.rows = currentRows;
    }
    setState(() {});
  }

  void _handleDeleteRow(int index) {
    final currentRows = List<Map<String, dynamic>>.from(
      _editorController.fitController?.data.rows ?? _columnRows,
    );
    if (currentRows.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one column must remain in the grid.'),
        ),
      );
      return;
    }
    currentRows.removeAt(index);
    _columnRows = currentRows;
    _editorDataSource.setData(currentRows);
    if (_editorController.fitController != null) {
      _editorController.fitController!.data.rows = currentRows;
    }
    setState(() {});
  }

  void _handleReset() {
    _columnRows = widget.controller.columns
        .map((c) => _columnToRow(c))
        .toList();
    _editorDataSource.setData(_columnRows);
    if (_editorController.fitController != null) {
      _editorController.fitController!.data.rows = _columnRows;
    }
    setState(() {});
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      if (_editorController.isEditingRow) {
        final err = await _editorController.saveEdit();
        if (err != null) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Validation error: $err')));
          }
          return;
        }
      }

      final currentRows = List<Map<String, dynamic>>.from(
        _editorController.fitController?.data.rows ?? _columnRows,
      );

      final seenFields = <String>{};
      final newColumns = <AiGridColumn>[];

      for (var i = 0; i < currentRows.length; i++) {
        final row = currentRows[i];
        final field = row['field']?.toString().trim() ?? '';
        final title = row['title']?.toString().trim() ?? '';

        if (field.isEmpty) {
          throw Exception('Row #${i + 1} has an empty field identifier.');
        }
        if (title.isEmpty) {
          throw Exception('Column "$field" has an empty caption / header.');
        }
        if (seenFields.contains(field)) {
          throw Exception('Duplicate field identifier "$field" found.');
        }
        seenFields.add(field);

        final origCol = widget.controller.columns
            .where((c) => c.field == field)
            .firstOrNull;
        newColumns.add(_rowToColumn(row, origCol));
      }

      final success = await widget.controller.updateAllColumns(newColumns);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Updated ${newColumns.length} columns successfully.',
              ),
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update columns.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving columns: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final activeDesc = widget.controller.activeDynamicDatasource;

    final screenSize = MediaQuery.sizeOf(context);
    final dialogWidth = math.min(screenSize.width - 40, 980.0);
    final dialogHeight = math.min(screenSize.height - 56, 620.0);

    final editableCount = _columnRows
        .where(
          (r) => r['editable'] == true || r['editable']?.toString() == 'true',
        )
        .length;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: dialogWidth,
          height: dialogHeight,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E24) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
            border: Border.all(
              color: isDark ? const Color(0xFF33333F) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 14, 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.view_column_rounded,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Columns Editor (Dynamic Schema)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            activeDesc != null
                                ? 'Dataset: ${activeDesc.title} (${_columnRows.length} columns total, $editableCount editable)'
                                : '${_columnRows.length} columns total ($editableCount editable)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // 2. Toolbar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                color: isDark
                    ? const Color(0xFF25252E)
                    : const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text(
                        'Add Column',
                        style: TextStyle(fontSize: 12.5),
                      ),
                      onPressed: _isSaving ? null : _handleAddColumn,
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      icon: const Icon(Icons.restart_alt_rounded, size: 16),
                      label: const Text(
                        'Reset',
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: _isSaving ? null : _handleReset,
                    ),
                    const Spacer(),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Click checkboxes & dropdowns directly, or double-click cells to edit text/width',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF334155),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // 3. Inner Interactive AiGrid Table
              Expanded(
                child: ClipRRect(
                  child: AiGrid(
                    controller: _editorController,
                    dataSource: _editorDataSource,
                    showToolbar: false,
                    enableAiAssistant: false,
                    dynamicGrid: false,
                  ),
                ),
              ),
              const Divider(height: 1),

              // 4. Footer Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Apply & Save All Changes',
                      ),
                      onPressed: _isSaving ? null : _handleSave,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
