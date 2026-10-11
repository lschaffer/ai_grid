import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:trina_grid/trina_grid.dart';

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

  /// Converts this [AiGridColumn] into a [TrinaColumn] used by the underlying engine.
  TrinaColumn toTrinaColumn() {
    TrinaColumnType trinaType;
    switch (type) {
      case AiGridColumnType.number:
        trinaType = TrinaColumnType.number();
        break;
      case AiGridColumnType.currency:
        trinaType = TrinaColumnType.currency(format: numberFormat ?? '#,###.##');
        break;
      case AiGridColumnType.date:
        trinaType = TrinaColumnType.date();
        break;
      case AiGridColumnType.boolean:
        trinaType = TrinaColumnType.boolean();
        break;
      case AiGridColumnType.select:
        trinaType = TrinaColumnType.select(selectOptions ?? []);
        break;
      case AiGridColumnType.text:
        trinaType = TrinaColumnType.text();
        break;
    }

    final isCount = aggregateType == AiGridAggregateType.count;
    final defaultFmt = isCount ? 'Total: #,###' : '#,###.##';

    return TrinaColumn(
      title: title,
      field: field,
      type: trinaType,
      width: width,
      minWidth: minWidth,
      enableEditingMode: enableEditingMode,
      enableSorting: isSortable,
      enableFilterMenuItem: isFilterable,
      enableDropToResize: true,
      enableContextMenu: true,
      footerRenderer: aggregateType != AiGridAggregateType.none
          ? (rendererContext) => TrinaAggregateColumnFooter(
                rendererContext: rendererContext,
                type: _mapToTrinaAggregate(aggregateType),
                numberFormat: NumberFormat(numberFormat ?? defaultFmt),
                alignment: isCount ? Alignment.centerLeft : Alignment.centerRight,
              )
          : null,
    );
  }

  static TrinaAggregateColumnType _mapToTrinaAggregate(AiGridAggregateType type) {
    switch (type) {
      case AiGridAggregateType.sum:
        return TrinaAggregateColumnType.sum;
      case AiGridAggregateType.average:
        return TrinaAggregateColumnType.average;
      case AiGridAggregateType.min:
        return TrinaAggregateColumnType.min;
      case AiGridAggregateType.max:
        return TrinaAggregateColumnType.max;
      case AiGridAggregateType.count:
        return TrinaAggregateColumnType.count;
      case AiGridAggregateType.none:
        return TrinaAggregateColumnType.sum;
    }
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
