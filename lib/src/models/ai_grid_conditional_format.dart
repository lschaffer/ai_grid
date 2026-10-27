import 'package:flutter/widgets.dart';

/// Type of conditional formatting applied to cells or rows.
enum AiGridFormatType {
  /// Horizontal bar drawn behind cell text proportional to value.
  dataBar,

  /// Color gradient interpolation across minimum to maximum values.
  colorScale,

  /// Value rule-based highlighting (text color, background color, font weight).
  highlight,
}

/// Represents a conditional formatting rule for an [AiGrid] column or row.
class AiGridConditionalFormat {
  final String id;
  final String field;
  final AiGridFormatType type;

  // --- Data Bar Configuration ---
  final Color? positiveColor;
  final Color? negativeColor;
  final num? min;
  final num? max;
  final bool showText;

  // --- Highlight Configuration ---
  final Color? backgroundColor;
  final Color? textColor;
  final FontWeight? fontWeight;
  final String? operator; // '>', '<', '>=', '<=', '==', '!=', 'contains', 'between'
  final dynamic targetValue;
  final dynamic secondaryValue;
  final bool applyToRow;

  // --- Color Scale Configuration ---
  final Color? minColor;
  final Color? midColor;
  final Color? maxColor;

  /// Optional custom evaluation predicate.
  final bool Function(dynamic value, Map<String, dynamic> row)? customRule;

  const AiGridConditionalFormat({
    required this.id,
    required this.field,
    required this.type,
    this.positiveColor,
    this.negativeColor,
    this.min,
    this.max,
    this.showText = true,
    this.backgroundColor,
    this.textColor,
    this.fontWeight,
    this.operator,
    this.targetValue,
    this.secondaryValue,
    this.applyToRow = false,
    this.minColor,
    this.midColor,
    this.maxColor,
    this.customRule,
  });

  /// Creates a data bar format for numeric columns.
  factory AiGridConditionalFormat.dataBar({
    String? id,
    required String field,
    Color? color,
    Color? negativeColor,
    num? min,
    num? max,
    bool showText = true,
  }) {
    return AiGridConditionalFormat(
      id: id ?? 'databar_$field',
      field: field,
      type: AiGridFormatType.dataBar,
      positiveColor: color,
      negativeColor: negativeColor,
      min: min,
      max: max,
      showText: showText,
    );
  }

  /// Creates a rule-based highlight format for a column or row.
  factory AiGridConditionalFormat.highlight({
    String? id,
    required String field,
    required String operator,
    required dynamic targetValue,
    dynamic secondaryValue,
    Color? backgroundColor,
    Color? textColor,
    FontWeight? fontWeight,
    bool applyToRow = false,
    bool Function(dynamic value, Map<String, dynamic> row)? customRule,
  }) {
    return AiGridConditionalFormat(
      id: id ?? 'highlight_${field}_$operator',
      field: field,
      type: AiGridFormatType.highlight,
      operator: operator,
      targetValue: targetValue,
      secondaryValue: secondaryValue,
      backgroundColor: backgroundColor,
      textColor: textColor,
      fontWeight: fontWeight,
      applyToRow: applyToRow,
      customRule: customRule,
    );
  }

  /// Creates a color scale / heatmap format for numeric columns.
  factory AiGridConditionalFormat.colorScale({
    String? id,
    required String field,
    required Color minColor,
    Color? midColor,
    required Color maxColor,
    num? min,
    num? max,
  }) {
    return AiGridConditionalFormat(
      id: id ?? 'colorscale_$field',
      field: field,
      type: AiGridFormatType.colorScale,
      minColor: minColor,
      midColor: midColor,
      maxColor: maxColor,
      min: min,
      max: max,
    );
  }

  /// Evaluates whether this highlight rule matches a given value and row.
  bool matches(dynamic rawValue, Map<String, dynamic> row) {
    if (customRule != null) {
      return customRule!(rawValue, row);
    }
    if (type != AiGridFormatType.highlight || operator == null) {
      return false;
    }

    if (rawValue == null) return false;

    final numVal = _toNum(rawValue);
    final targetNum = _toNum(targetValue);

    switch (operator!.toLowerCase().trim()) {
      case '>':
        if (numVal != null && targetNum != null) return numVal > targetNum;
        return false;
      case '>=':
        if (numVal != null && targetNum != null) return numVal >= targetNum;
        return false;
      case '<':
        if (numVal != null && targetNum != null) return numVal < targetNum;
        return false;
      case '<=':
        if (numVal != null && targetNum != null) return numVal <= targetNum;
        return false;
      case '==':
      case '=':
      case 'equals':
        if (numVal != null && targetNum != null) return numVal == targetNum;
        return rawValue.toString().toLowerCase() ==
            targetValue.toString().toLowerCase();
      case '!=':
      case '<>':
      case 'notequals':
        if (numVal != null && targetNum != null) return numVal != targetNum;
        return rawValue.toString().toLowerCase() !=
            targetValue.toString().toLowerCase();
      case 'contains':
        return rawValue
            .toString()
            .toLowerCase()
            .contains(targetValue.toString().toLowerCase());
      case 'between':
        final secondNum = _toNum(secondaryValue);
        if (numVal != null && targetNum != null && secondNum != null) {
          final low = targetNum < secondNum ? targetNum : secondNum;
          final high = targetNum < secondNum ? secondNum : targetNum;
          return numVal >= low && numVal <= high;
        }
        return false;
      default:
        return false;
    }
  }

  /// Interpolates a color for [value] on a scale from [minVal] to [maxVal].
  Color? interpolateColor(num value, num minVal, num maxVal) {
    if (minColor == null || maxColor == null) return null;
    if (maxVal <= minVal) return minColor;

    final ratio = ((value - minVal) / (maxVal - minVal)).clamp(0.0, 1.0);

    if (midColor != null) {
      if (ratio <= 0.5) {
        final t = ratio * 2.0;
        return Color.lerp(minColor, midColor, t);
      } else {
        final t = (ratio - 0.5) * 2.0;
        return Color.lerp(midColor, maxColor, t);
      }
    }

    return Color.lerp(minColor, maxColor, ratio);
  }

  static num? _toNum(dynamic val) {
    if (val == null) return null;
    if (val is num) return val;
    return num.tryParse(val.toString().replaceAll(RegExp(r'[^0-9.-]'), ''));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'field': field,
        'type': type.name,
        if (positiveColor != null)
          'positiveColor': '#${positiveColor!.toARGB32().toRadixString(16).padLeft(8, '0')}',
        if (negativeColor != null)
          'negativeColor': '#${negativeColor!.toARGB32().toRadixString(16).padLeft(8, '0')}',
        if (min != null) 'min': min,
        if (max != null) 'max': max,
        'showText': showText,
        if (backgroundColor != null)
          'backgroundColor': '#${backgroundColor!.toARGB32().toRadixString(16).padLeft(8, '0')}',
        if (textColor != null)
          'textColor': '#${textColor!.toARGB32().toRadixString(16).padLeft(8, '0')}',
        if (operator != null) 'operator': operator,
        if (targetValue != null) 'targetValue': targetValue,
        if (secondaryValue != null) 'secondaryValue': secondaryValue,
        'applyToRow': applyToRow,
        if (minColor != null)
          'minColor': '#${minColor!.toARGB32().toRadixString(16).padLeft(8, '0')}',
        if (midColor != null)
          'midColor': '#${midColor!.toARGB32().toRadixString(16).padLeft(8, '0')}',
        if (maxColor != null)
          'maxColor': '#${maxColor!.toARGB32().toRadixString(16).padLeft(8, '0')}',
      };

  factory AiGridConditionalFormat.fromJson(Map<String, dynamic> json) {
    Color? parseColor(dynamic c) {
      if (c == null) return null;
      if (c is int) return Color(c);
      final s = c.toString().replaceFirst('#', '');
      final val = int.tryParse(s, radix: 16);
      if (val == null) return null;
      return Color(s.length <= 6 ? (0xFF000000 | val) : val);
    }

    final typeStr = json['type']?.toString() ?? 'highlight';
    final type = AiGridFormatType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => AiGridFormatType.highlight,
    );

    return AiGridConditionalFormat(
      id: json['id']?.toString() ?? 'fmt_${json['field']}',
      field: json['field']?.toString() ?? '',
      type: type,
      positiveColor: parseColor(json['positiveColor']),
      negativeColor: parseColor(json['negativeColor']),
      min: json['min'] is num ? json['min'] as num : null,
      max: json['max'] is num ? json['max'] as num : null,
      showText: json['showText'] as bool? ?? true,
      backgroundColor: parseColor(json['backgroundColor']),
      textColor: parseColor(json['textColor']),
      operator: json['operator']?.toString(),
      targetValue: json['targetValue'],
      secondaryValue: json['secondaryValue'],
      applyToRow: json['applyToRow'] as bool? ?? false,
      minColor: parseColor(json['minColor']),
      midColor: parseColor(json['midColor']),
      maxColor: parseColor(json['maxColor']),
    );
  }
}
