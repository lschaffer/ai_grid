import 'dart:math' as math;
import 'package:intl/intl.dart';
import '../fitgrid/fitgrid_table.dart';

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
  final double width;
  final double minWidth;
  final bool isGroupable;
  final bool isSortable;
  final bool isFilterable;
  final bool enableEditingMode;
  final AiGridAggregateType aggregateType;
  final String? numberFormat;
  final List<String>? selectOptions;

  const AiGridColumn({
    required this.field,
    required this.title,
    this.type = AiGridColumnType.text,
    this.width = 160.0,
    this.minWidth = 80.0,
    this.isGroupable = true,
    this.isSortable = true,
    this.isFilterable = true,
    this.enableEditingMode = false,
    this.aggregateType = AiGridAggregateType.none,
    this.numberFormat,
    this.selectOptions,
  });

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
      final nf = NumberFormat(numberFormat ?? defaultFmt);

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
    if (enableEditingMode) {
      editor = FitGridEditor<Map<String, dynamic>>(
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

    return FitGridColumn<Map<String, dynamic>>(
      id: field,
      label: title,
      value: (row) => _formatDisplayValue(row[field]),
      width: width > 0 ? FitGridColumnWidth.fixed(width) : const FitGridColumnWidth.auto(),
      alignment: alignment,
      sortable: isSortable,
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
        'aggregateType': aggregateType.name,
      };
}
