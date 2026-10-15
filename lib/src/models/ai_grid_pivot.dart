import 'package:flutter/foundation.dart';
import '../fitgrid/fitgrid_table.dart';

/// Aggregation functions supported in Pivot mode.
enum AiGridPivotAggregation {
  sum,
  count,
  average,
  min,
  max;

  FitGridAggregation toFitGrid() {
    switch (this) {
      case AiGridPivotAggregation.sum:
        return FitGridAggregation.sum;
      case AiGridPivotAggregation.count:
        return FitGridAggregation.count;
      case AiGridPivotAggregation.average:
        return FitGridAggregation.average;
      case AiGridPivotAggregation.min:
        return FitGridAggregation.min;
      case AiGridPivotAggregation.max:
        return FitGridAggregation.max;
    }
  }

  static AiGridPivotAggregation fromString(String? value) {
    if (value == null) return AiGridPivotAggregation.sum;
    switch (value.toLowerCase().trim()) {
      case 'avg':
      case 'average':
        return AiGridPivotAggregation.average;
      case 'count':
        return AiGridPivotAggregation.count;
      case 'min':
        return AiGridPivotAggregation.min;
      case 'max':
        return AiGridPivotAggregation.max;
      case 'sum':
      default:
        return AiGridPivotAggregation.sum;
    }
  }

  String get displayName {
    switch (this) {
      case AiGridPivotAggregation.sum:
        return 'Sum';
      case AiGridPivotAggregation.count:
        return 'Count';
      case AiGridPivotAggregation.average:
        return 'Average';
      case AiGridPivotAggregation.min:
        return 'Min';
      case AiGridPivotAggregation.max:
        return 'Max';
    }
  }
}

/// Pivot chart visualization types.
enum AiGridPivotChartType {
  groupedBar,
  column,
  line,
  pie;

  static AiGridPivotChartType fromString(String? value) {
    if (value == null) return AiGridPivotChartType.groupedBar;
    switch (value.toLowerCase().trim()) {
      case 'column':
      case 'bar':
        return AiGridPivotChartType.column;
      case 'line':
        return AiGridPivotChartType.line;
      case 'pie':
      case 'donut':
        return AiGridPivotChartType.pie;
      case 'groupedbar':
      default:
        return AiGridPivotChartType.groupedBar;
    }
  }

  String get displayName {
    switch (this) {
      case AiGridPivotChartType.groupedBar:
        return 'Grouped Bar';
      case AiGridPivotChartType.column:
        return 'Column Bar';
      case AiGridPivotChartType.line:
        return 'Line Trend';
      case AiGridPivotChartType.pie:
        return 'Pie Chart';
    }
  }
}

/// A value / measure field to aggregate in the pivot table.
@immutable
class AiGridPivotValueConfig {
  const AiGridPivotValueConfig({
    required this.columnId,
    this.aggregation = AiGridPivotAggregation.sum,
    this.label,
    this.format,
  });

  final String columnId;
  final AiGridPivotAggregation aggregation;
  final String? label;
  final String Function(num value)? format;

  String effectiveLabel(String fallbackColumnLabel) {
    if (label != null && label!.trim().isNotEmpty) return label!;
    return '$fallbackColumnLabel (${aggregation.displayName})';
  }

  AiGridPivotValueConfig copyWith({
    String? columnId,
    AiGridPivotAggregation? aggregation,
    String? label,
    String Function(num value)? format,
  }) {
    return AiGridPivotValueConfig(
      columnId: columnId ?? this.columnId,
      aggregation: aggregation ?? this.aggregation,
      label: label ?? this.label,
      format: format ?? this.format,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'columnId': columnId,
        'aggregation': aggregation.name,
        if (label != null) 'label': label,
      };

  factory AiGridPivotValueConfig.fromJson(Map<String, dynamic> json) {
    return AiGridPivotValueConfig(
      columnId: json['columnId'] as String? ?? json['column'] as String? ?? '',
      aggregation: AiGridPivotAggregation.fromString(
        json['aggregation'] as String? ?? json['type'] as String?,
      ),
      label: json['label'] as String?,
    );
  }
}

/// Full configuration for an active pivot transformation.
@immutable
class AiGridPivotConfig {
  const AiGridPivotConfig({
    required this.rowFieldIds,
    this.columnFieldIds = const <String>[],
    required this.values,
    this.showColumnTotals = true,
    this.showRowTotals = true,
    this.showChart = false,
    this.chartType = AiGridPivotChartType.groupedBar,
    this.groupByRows = true,
  });

  final List<String> rowFieldIds;
  final List<String> columnFieldIds;
  final List<AiGridPivotValueConfig> values;
  final bool showColumnTotals;
  final bool showRowTotals;
  final bool showChart;
  final AiGridPivotChartType chartType;

  /// Whether to hierarchically group rows in tree format when multiple row dimensions are selected.
  final bool groupByRows;

  AiGridPivotConfig copyWith({
    List<String>? rowFieldIds,
    List<String>? columnFieldIds,
    List<AiGridPivotValueConfig>? values,
    bool? showColumnTotals,
    bool? showRowTotals,
    bool? showChart,
    AiGridPivotChartType? chartType,
    bool? groupByRows,
  }) {
    return AiGridPivotConfig(
      rowFieldIds: rowFieldIds ?? this.rowFieldIds,
      columnFieldIds: columnFieldIds ?? this.columnFieldIds,
      values: values ?? this.values,
      showColumnTotals: showColumnTotals ?? this.showColumnTotals,
      showRowTotals: showRowTotals ?? this.showRowTotals,
      showChart: showChart ?? this.showChart,
      chartType: chartType ?? this.chartType,
      groupByRows: groupByRows ?? this.groupByRows,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'rowFieldIds': rowFieldIds,
        'columnFieldIds': columnFieldIds,
        'values': values.map((v) => v.toJson()).toList(),
        'showColumnTotals': showColumnTotals,
        'showRowTotals': showRowTotals,
        'showChart': showChart,
        'chartType': chartType.name,
        'groupByRows': groupByRows,
      };

  factory AiGridPivotConfig.fromJson(Map<String, dynamic> json) {
    final rawValues = json['values'] as List<dynamic>? ?? const [];
    return AiGridPivotConfig(
      rowFieldIds: (json['rowFieldIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          (json['rows'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      columnFieldIds: (json['columnFieldIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          (json['columns'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      values: rawValues
          .whereType<Map<String, dynamic>>()
          .map(AiGridPivotValueConfig.fromJson)
          .toList(),
      showColumnTotals: json['showColumnTotals'] as bool? ?? true,
      showRowTotals: json['showRowTotals'] as bool? ?? true,
      showChart: json['showChart'] as bool? ?? false,
      chartType: AiGridPivotChartType.fromString(json['chartType'] as String?),
      groupByRows: json['groupByRows'] as bool? ?? true,
    );
  }
}
