import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import '../fitgrid/fitgrid_table.dart';
import 'ai_grid_editing_options.dart';

/// Data type of an AiGrid column.
enum AiGridColumnType {
  text,
  number,
  currency,
  date,
  datetime,
  boolean,
  select,
  sparkline,
}

/// Aggregate calculation type for column footers and group summaries.
enum AiGridAggregateType {
  none,
  sum,
  average,
  min,
  max,
  count,
}

/// Represents a column in the [AiGrid].
class AiGridColumn {
  final String field;
  final String title;
  final AiGridColumnType type;
  final double? width;
  final double minWidth;
  final double? maxWidth;
  final FitGridColumnWidth? columnWidth;
  final bool resizable;
  final bool isGroupable;
  final bool isSortable;
  final bool isFilterable;

  /// Whether this column is editable. If omitted, falls back to [enableEditingMode].
  final bool? editable;

  /// Legacy property for editing. Prefer using [editable].
  final bool enableEditingMode;

  /// Layout order of this column in [AiGridEditMode.form]. Columns with lower indices appear first.
  final int? editorIndex;

  /// Explicit input widget type to use when editing this column. Defaults to matching [type].
  final AiGridEditorType? editorType;

  /// Optional parameters for the editor (e.g. min, max, step, placeholder, or custom options).
  final Map<String, dynamic>? editorOptions;

  /// Validation function that returns an error message if [value] is invalid, or null if valid.
  final String? Function(dynamic value)? validator;

  /// Whether a value is mandatory. Empty values fail with "`title` is required".
  final bool required;

  /// Called whenever the value of this column changes during editing.
  final void Function(dynamic value, Map<String, dynamic> draftRow)? onChanged;

  /// Bespoke editor widget builder for custom input controls.
  final Widget Function(
    BuildContext context,
    dynamic value,
    ValueChanged<dynamic> onChanged,
  )? editorBuilder;

  final AiGridAggregateType aggregateType;
  final String? numberFormat;
  final List<String>? selectOptions;

  /// Optional custom widget cell builder.
  final FitGridCellBuilder<Map<String, dynamic>>? cellBuilder;

  /// A chart painted directly on canvas into each cell of this column: a data bar, a progress track or a sparkline.
  final FitGridCellVisual<Map<String, dynamic>>? visual;

  /// Per-cell text style override for conditional formatting.
  final TextStyle? Function(dynamic value, Map<String, dynamic> row)? cellStyle;

  /// Per-cell text color override for conditional formatting.
  final Color? Function(dynamic value, Map<String, dynamic> row)? cellColor;

  const AiGridColumn({
    required this.field,
    required this.title,
    this.type = AiGridColumnType.text,
    this.width,
    this.minWidth = 80.0,
    this.maxWidth,
    this.columnWidth,
    this.resizable = true,
    this.isGroupable = true,
    this.isSortable = true,
    this.isFilterable = true,
    this.editable,
    this.enableEditingMode = false,
    this.editorIndex,
    this.editorType,
    this.editorOptions,
    this.validator,
    this.required = false,
    this.onChanged,
    this.editorBuilder,
    this.aggregateType = AiGridAggregateType.none,
    this.numberFormat,
    this.selectOptions,
    this.cellBuilder,
    this.visual,
    this.cellStyle,
    this.cellColor,
  });

  /// Creates a horizontal data bar visual behind the cell's text.
  static FitGridCellVisual<Map<String, dynamic>> dataBar({
    num? Function(Map<String, dynamic> row)? valueOf,
    num? min,
    num? max,
    Color? color,
    Color? negativeColor,
    bool showText = true,
  }) =>
      FitGridCellVisual.bar(
        valueOf ?? (row) => null,
        min: min,
        max: max,
        color: color,
        negativeColor: negativeColor,
        showText: showText,
      );

  /// Creates a progress track visual filled to a fraction between 0 and 1.
  static FitGridCellVisual<Map<String, dynamic>> progress({
    required double? Function(Map<String, dynamic> row) fractionOf,
    Color? color,
    bool showText = true,
  }) =>
      FitGridCellVisual.progress(
        fractionOf,
        color: color,
        showText: showText,
      );

  /// Creates a sparkline visual through a series of values, scaled to the cell.
  static FitGridCellVisual<Map<String, dynamic>> sparkline({
    required List<num> Function(Map<String, dynamic> row) valuesOf,
    Color? color,
    bool filled = true,
  }) =>
      FitGridCellVisual.sparkline(
        valuesOf,
        color: color,
        filled: filled,
      );

  /// Whether this column can be edited.
  bool get isEditable => editable ?? enableEditingMode;

  /// Runs the [required] check, then [validator]. Returns an error or null.
  String? validate(dynamic value) {
    if (required &&
        (value == null || (value is String && value.trim().isEmpty))) {
      return '$title is required';
    }
    return validator?.call(value);
  }

  /// Converts this [AiGridColumn] into a [FitGridColumn] used by the underlying engine.
  FitGridColumn<Map<String, dynamic>> toFitGridColumn() {
    FitGridAlignment alignment = FitGridAlignment.start;
    if (type == AiGridColumnType.number || type == AiGridColumnType.currency) {
      alignment = FitGridAlignment.end;
    } else if (type == AiGridColumnType.boolean) {
      alignment = FitGridAlignment.center;
    }

    FitGridFilterSpec<Map<String, dynamic>>? filterSpec;
    if (isFilterable) {
      switch (type) {
        case AiGridColumnType.number:
        case AiGridColumnType.currency:
          filterSpec = FitGridFilterSpec.number((r) => _extractNum(r[field]));
          break;
        case AiGridColumnType.date:
        case AiGridColumnType.datetime:
          filterSpec = FitGridFilterSpec.date((r) => _extractDate(r[field]));
          break;
        case AiGridColumnType.select:
          filterSpec = FitGridFilterSpec.values(options: selectOptions);
          break;
        case AiGridColumnType.boolean:
          filterSpec = const FitGridFilterSpec.values(options: ['true', 'false']);
          break;
        case AiGridColumnType.text:
          filterSpec = const FitGridFilterSpec.text();
          break;
        case AiGridColumnType.sparkline:
          break;
      }
    }

    FitGridAggregate<Map<String, dynamic>>? aggregateFunc;
    String? footLabel;
    if (aggregateType != AiGridAggregateType.none) {
      final isCount = aggregateType == AiGridAggregateType.count;
      final defaultFmt = isCount ? '#,###' : '#,###.##';
      var rawFmt = numberFormat ?? defaultFmt;
      if (isCount && rawFmt.contains('Total:')) {
        rawFmt = rawFmt.replaceAll('Total:', '').trim();
      }
      final nf = NumberFormat(rawFmt);

      footLabel = switch (aggregateType) {
        AiGridAggregateType.sum => 'Total: ',
        AiGridAggregateType.average => 'Avg: ',
        AiGridAggregateType.min => 'Min: ',
        AiGridAggregateType.max => 'Max: ',
        AiGridAggregateType.count => 'Count: ',
        AiGridAggregateType.none => null,
      };

      aggregateFunc = (List<Map<String, dynamic>> rows) {
        if (rows.isEmpty) return '0';
        if (aggregateType == AiGridAggregateType.count) {
          return nf.format(rows.length);
        }
        final nums = <num>[];
        for (final r in rows) {
          final n = _extractNum(r[field]);
          if (n != null) nums.add(n);
        }
        if (nums.isEmpty) return '0';
        num val = 0;
        switch (aggregateType) {
          case AiGridAggregateType.sum:
            val = nums.reduce((a, b) => a + b);
            break;
          case AiGridAggregateType.average:
            val = nums.reduce((a, b) => a + b) / nums.length;
            break;
          case AiGridAggregateType.min:
            val = nums.reduce(math.min);
            break;
          case AiGridAggregateType.max:
            val = nums.reduce(math.max);
            break;
          case AiGridAggregateType.count:
          case AiGridAggregateType.none:
            break;
        }
        if (type == AiGridColumnType.currency) {
          return '\$${nf.format(val)}';
        }
        return nf.format(val);
      };
    }

    FitGridEditor<Map<String, dynamic>>? editor;
    if (isEditable) {
      FitGridEditorBuilder<Map<String, dynamic>>? effectiveBuilder =
          editorBuilder != null
              ? (context, session) => editorBuilder!(
                    context,
                    session.row[field] ?? session.initialText,
                    (val) {
                      session.commit(val?.toString() ?? '');
                    },
                  )
              : null;

      if (effectiveBuilder == null) {
        if (editorType == AiGridEditorType.boolean ||
            type == AiGridColumnType.boolean) {
          effectiveBuilder = (context, session) {
            final raw = session.row[field];
            final boolVal =
                raw == true || raw?.toString().toLowerCase() == 'true';
            return Center(
              child: Checkbox(
                value: boolVal,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) {
                  session.commit(v.toString());
                },
              ),
            );
          };
        } else if (editorType == AiGridEditorType.select ||
            type == AiGridColumnType.select) {
          final options = <String>[];
          if (selectOptions != null) {
            options.addAll(selectOptions!);
          } else if (editorOptions?['items'] is List) {
            for (final item in editorOptions!['items'] as List) {
              options.add(item.toString());
            }
          }

          if (options.isNotEmpty) {
            effectiveBuilder = (context, session) {
              final currentStr =
                  session.row[field]?.toString() ?? session.initialText;
              final effectiveVal =
                  options.contains(currentStr) ? currentStr : null;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.centerLeft,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isDense: true,
                    isExpanded: true,
                    value: effectiveVal,
                    items: options
                        .map((opt) => DropdownMenuItem(
                              value: opt,
                              child: Text(opt,
                                  style: const TextStyle(fontSize: 12)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        session.commit(v);
                      }
                    },
                  ),
                ),
              );
            };
          }
        } else if (editorType == AiGridEditorType.date ||
            editorType == AiGridEditorType.dateTime ||
            type == AiGridColumnType.date) {
          final isDateTime = editorType == AiGridEditorType.dateTime;
          effectiveBuilder = (context, session) {
            final currentVal = session.row[field];
            String dateStr = '';
            if (currentVal is DateTime) {
              dateStr = isDateTime
                  ? DateFormat('yyyy-MM-dd HH:mm').format(currentVal)
                  : DateFormat('yyyy-MM-dd').format(currentVal);
            } else if (currentVal != null && currentVal.toString().isNotEmpty) {
              dateStr = currentVal.toString();
            } else if (session.initialText.isNotEmpty) {
              dateStr = session.initialText;
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.centerLeft,
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
                      final formatted =
                          DateFormat('yyyy-MM-dd HH:mm').format(dt);
                      session.commit(formatted);
                    } else {
                      final formatted =
                          DateFormat('yyyy-MM-dd').format(picked);
                      session.commit(formatted);
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
          };
        }
      }

      editor = FitGridEditor<Map<String, dynamic>>(
        initialText: (row) => row[field]?.toString() ?? '',
        validator: (validator != null || required)
            ? (row, text) => validate(text)
            : null,
        builder: effectiveBuilder,
        onCommit: (row, index, text) {
          if (type == AiGridColumnType.number ||
              type == AiGridColumnType.currency) {
            row[field] =
                num.tryParse(text.replaceAll(RegExp(r'[^0-9.-]'), '')) ?? text;
          } else if (type == AiGridColumnType.boolean) {
            row[field] = text.toLowerCase() == 'true';
          } else {
            row[field] = text;
          }
          onChanged?.call(row[field], row);
        },
      );
    }

    FitGridCellVisual<Map<String, dynamic>>? effectiveVisual = visual;
    if (effectiveVisual == null && type == AiGridColumnType.sparkline) {
      effectiveVisual = FitGridCellVisual.sparkline(
        (row) {
          final raw = row[field];
          if (raw is List) {
            return raw
                .map((e) => e is num ? e : num.tryParse(e.toString()) ?? 0)
                .toList();
          }
          return const <num>[];
        },
      );
    }

    FitGridCellStyle<Map<String, dynamic>>? effectiveCellStyle;
    if (cellStyle != null || cellColor != null) {
      effectiveCellStyle = (row, index) {
        final val = row[field];
        TextStyle? style = cellStyle?.call(val, row);
        if (cellColor != null) {
          final c = cellColor!(val, row);
          if (c != null) {
            style = (style ?? const TextStyle()).copyWith(color: c);
          }
        }
        return style;
      };
    }

    final effectiveWidth = columnWidth ??
        (!resizable && width != null && width! > 0
            ? FitGridColumnWidth.fixed(width!)
            : FitGridColumnWidth.auto(min: minWidth, max: maxWidth));

    return FitGridColumn<Map<String, dynamic>>(
      id: field,
      label: title,
      value: (row) => _formatDisplayValue(row[field]),
      width: effectiveWidth,
      alignment: alignment,
      sortable: isSortable,
      resizable: resizable,
      sortValue: (row) => _sortValueOf(row[field]),
      filter: filterSpec,
      aggregate: aggregateFunc,
      footerLabel: footLabel,
      editor: editor,
      cellBuilder: cellBuilder,
      visual: effectiveVisual,
      cellStyle: effectiveCellStyle,
    );
  }

  /// Formats a raw field value into human-readable text according to column type and numberFormat.
  String formatDisplayValue(dynamic raw) => _formatDisplayValue(raw);

  String _formatDisplayValue(dynamic raw) {
    if (raw == null) return '';
    if (type == AiGridColumnType.sparkline) {
      if (raw is List) return raw.join(', ');
      return raw.toString();
    }
    if (type == AiGridColumnType.currency) {
      final n = _extractNum(raw);
      if (n != null) {
        final nf = NumberFormat(numberFormat ?? '#,###.##');
        return '\$${nf.format(n)}';
      }
    } else if (type == AiGridColumnType.number && numberFormat != null) {
      final n = _extractNum(raw);
      if (n != null) {
        return NumberFormat(numberFormat).format(n);
      }
    } else if (type == AiGridColumnType.date && raw is DateTime) {
      return DateFormat('yyyy-MM-dd').format(raw);
    } else if (type == AiGridColumnType.datetime && raw is DateTime) {
      return DateFormat('yyyy-MM-dd HH:mm').format(raw);
    }
    return raw.toString();
  }

  Object? _sortValueOf(dynamic raw) {
    if (raw == null) return null;
    if (type == AiGridColumnType.number || type == AiGridColumnType.currency) {
      return _extractNum(raw);
    }
    if (type == AiGridColumnType.date || type == AiGridColumnType.datetime) {
      return _extractDate(raw);
    }
    if (type == AiGridColumnType.boolean) {
      return raw is bool ? raw : (raw.toString().toLowerCase() == 'true');
    }
    return raw.toString();
  }

  num? _extractNum(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw;
    final cleaned = raw.toString().replaceAll(RegExp(r'[^0-9.-]'), '');
    return num.tryParse(cleaned);
  }

  DateTime? _extractDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }

  AiGridColumn copyWith({
    String? field,
    String? title,
    AiGridColumnType? type,
    double? width,
    double? minWidth,
    double? maxWidth,
    FitGridColumnWidth? columnWidth,
    bool? resizable,
    bool? isGroupable,
    bool? isSortable,
    bool? isFilterable,
    bool? editable,
    bool? enableEditingMode,
    int? editorIndex,
    AiGridEditorType? editorType,
    Map<String, dynamic>? editorOptions,
    String? Function(dynamic value)? validator,
    bool? required,
    void Function(dynamic value, Map<String, dynamic> draftRow)? onChanged,
    Widget Function(
      BuildContext context,
      dynamic value,
      ValueChanged<dynamic> onChanged,
    )? editorBuilder,
    AiGridAggregateType? aggregateType,
    String? numberFormat,
    List<String>? selectOptions,
    FitGridCellBuilder<Map<String, dynamic>>? cellBuilder,
    FitGridCellVisual<Map<String, dynamic>>? visual,
    TextStyle? Function(dynamic value, Map<String, dynamic> row)? cellStyle,
    Color? Function(dynamic value, Map<String, dynamic> row)? cellColor,
  }) {
    return AiGridColumn(
      field: field ?? this.field,
      title: title ?? this.title,
      type: type ?? this.type,
      width: width ?? this.width,
      minWidth: minWidth ?? this.minWidth,
      maxWidth: maxWidth ?? this.maxWidth,
      columnWidth: columnWidth ?? this.columnWidth,
      resizable: resizable ?? this.resizable,
      isGroupable: isGroupable ?? this.isGroupable,
      isSortable: isSortable ?? this.isSortable,
      isFilterable: isFilterable ?? this.isFilterable,
      editable: editable ?? this.editable,
      enableEditingMode: enableEditingMode ?? this.enableEditingMode,
      editorIndex: editorIndex ?? this.editorIndex,
      editorType: editorType ?? this.editorType,
      editorOptions: editorOptions ?? this.editorOptions,
      validator: validator ?? this.validator,
      required: required ?? this.required,
      onChanged: onChanged ?? this.onChanged,
      editorBuilder: editorBuilder ?? this.editorBuilder,
      aggregateType: aggregateType ?? this.aggregateType,
      numberFormat: numberFormat ?? this.numberFormat,
      selectOptions: selectOptions ?? this.selectOptions,
      cellBuilder: cellBuilder ?? this.cellBuilder,
      visual: visual ?? this.visual,
      cellStyle: cellStyle ?? this.cellStyle,
      cellColor: cellColor ?? this.cellColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiGridColumn &&
          runtimeType == other.runtimeType &&
          field == other.field &&
          title == other.title &&
          type == other.type &&
          width == other.width &&
          minWidth == other.minWidth &&
          maxWidth == other.maxWidth &&
          editable == other.editable &&
          required == other.required &&
          editorType == other.editorType &&
          numberFormat == other.numberFormat &&
          isSortable == other.isSortable &&
          isGroupable == other.isGroupable &&
          isFilterable == other.isFilterable;

  @override
  int get hashCode => Object.hash(
        field,
        title,
        type,
        width,
        minWidth,
        maxWidth,
        editable,
        required,
        editorType,
        numberFormat,
        isSortable,
        isGroupable,
        isFilterable,
      );

  Map<String, dynamic> toJson() => {
        'field': field,
        'title': title,
        'type': type.name,
        'isGroupable': isGroupable,
        'isSortable': isSortable,
        'isFilterable': isFilterable,
        'editable': isEditable,
        'required': required,
        if (maxWidth != null) 'max_width': maxWidth,
        'editorIndex': editorIndex,
        'aggregateType': aggregateType.name,
      };
}
