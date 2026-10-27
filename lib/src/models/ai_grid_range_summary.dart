import 'package:flutter/foundation.dart';

/// Summary statistical metrics computed over a rectangular range of selected cells.
@immutable
class AiGridRangeSummary {
  /// Total number of cells selected in the range.
  final int cellCount;

  /// Number of rows covered by the range.
  final int rowCount;

  /// Number of columns covered by the range.
  final int columnCount;

  /// The list of column fields covered in display order.
  final List<String> columnFields;

  /// Sum of all numeric cell values in the range (null if no numeric values).
  final num? sum;

  /// Average (mean) of all numeric cell values in the range (null if no numeric values).
  final double? average;

  /// Minimum numeric value encountered in the range.
  final num? min;

  /// Maximum numeric value encountered in the range.
  final num? max;

  /// Number of numeric cells that contributed to [sum], [average], [min], and [max].
  final int numericCount;

  const AiGridRangeSummary({
    required this.cellCount,
    required this.rowCount,
    required this.columnCount,
    required this.columnFields,
    this.sum,
    this.average,
    this.min,
    this.max,
    this.numericCount = 0,
  });

  /// Computes an [AiGridRangeSummary] from a matrix of row records and column fields.
  factory AiGridRangeSummary.fromValues({
    required List<Map<String, dynamic>> rows,
    required List<String> columnFields,
  }) {
    if (rows.isEmpty || columnFields.isEmpty) {
      return const AiGridRangeSummary(
        cellCount: 0,
        rowCount: 0,
        columnCount: 0,
        columnFields: [],
      );
    }

    final totalCells = rows.length * columnFields.length;
    num currentSum = 0;
    num? currentMin;
    num? currentMax;
    var numCount = 0;

    for (final row in rows) {
      for (final field in columnFields) {
        final val = row[field];
        if (val is num) {
          currentSum += val;
          numCount++;
          if (currentMin == null || val < currentMin) currentMin = val;
          if (currentMax == null || val > currentMax) currentMax = val;
        } else if (val is String) {
          // Attempt parsing numbers formatted with currency symbols or commas
          final sanitized = val.replaceAll(RegExp(r'[^\d.-]'), '');
          final parsed = num.tryParse(sanitized);
          if (parsed != null && sanitized.isNotEmpty) {
            currentSum += parsed;
            numCount++;
            if (currentMin == null || parsed < currentMin) currentMin = parsed;
            if (currentMax == null || parsed > currentMax) currentMax = parsed;
          }
        }
      }
    }

    return AiGridRangeSummary(
      cellCount: totalCells,
      rowCount: rows.length,
      columnCount: columnFields.length,
      columnFields: columnFields,
      sum: numCount > 0 ? currentSum : null,
      average: numCount > 0 ? (currentSum / numCount) : null,
      min: currentMin,
      max: currentMax,
      numericCount: numCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'cellCount': cellCount,
        'rowCount': rowCount,
        'columnCount': columnCount,
        'columnFields': columnFields,
        'sum': sum,
        'average': average,
        'min': min,
        'max': max,
        'numericCount': numericCount,
      };

  @override
  String toString() {
    return 'AiGridRangeSummary(count: $cellCount, sum: $sum, avg: $average, min: $min, max: $max)';
  }
}
