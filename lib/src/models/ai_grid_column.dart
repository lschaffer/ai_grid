import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import '../fitgrid/fitgrid_table.dart';
import 'ai_grid_editing_options.dart';

/// Data type of an AiGrid column.
enum AiGridColumnType {
  text,
  number,
  currency,
  date,
  boolean,
  select,
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

  /// Bespoke editor widget builder for custom input controls.
  final Widget Function(
    BuildContext context,
    dynamic value,
    ValueChanged<dynamic> onChanged,
  )? editorBuilder;

  final AiGridAggregateType aggregateType;
  final String? numberFormat;
  final List<String>? selectOptions;

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
    this.editorBuilder,
    this.aggregateType = AiGridAggregateType.none,
    this.numberFormat,
    this.selectOptions,
  });

  /// Whether this column can be edited.
  bool get isEditable => editable ?? enableEditingMode;

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
      editor = FitGridEditor<Map<String, dynamic>>(
        validator: validator != null ? (row, text) => validator!(text) : null,
        builder: editorBuilder != null
            ? (context, session) => editorBuilder!(
                  context,
                  session.row[field] ?? session.initialText,
                  (val) {
                    session.commit(val?.toString() ?? '');
                  },
                )
            : null,
        onCommit: (row, index, text) {
          if (type == AiGridColumnType.number || type == AiGridColumnType.currency) {
            row[field] = num.tryParse(text.replaceAll(RegExp(r'[^0-9.-]'), '')) ?? text;
          } else if (type == AiGridColumnType.boolean) {
            row[field] = text.toLowerCase() == 'true';
          } else {
            row[field] = text;
          }
        },
      );
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
    );
  }

  String _formatDisplayValue(dynamic raw) {
    if (raw == null) return '';
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
    }
    return raw.toString();
  }

  Object? _sortValueOf(dynamic raw) {
    if (raw == null) return null;
    if (type == AiGridColumnType.number || type == AiGridColumnType.currency) {
      return _extractNum(raw);
    }
    if (type == AiGridColumnType.date) {
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

  Map<String, dynamic> toJson() => {
        'field': field,
        'title': title,
        'type': type.name,
        'isGroupable': isGroupable,
        'isSortable': isSortable,
        'isFilterable': isFilterable,
        'editable': isEditable,
        'editorIndex': editorIndex,
        'aggregateType': aggregateType.name,
      };
}
