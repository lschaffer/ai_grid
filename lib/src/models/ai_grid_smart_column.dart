import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../fitgrid/fitgrid_table.dart';
import 'ai_grid_column.dart';

/// Status of AI generation for an individual smart cell.
enum AiGridSmartCellStatus {
  /// Generation has not started yet.
  idle,

  /// LLM evaluation is currently in progress for this cell.
  generating,

  /// Cell value was successfully synthesized by the AI.
  generated,

  /// Evaluation failed or encountered an error.
  error,
}

/// An AI-synthesized column in [AiGrid] whose values are evaluated on-demand
/// by an LLM based on row context and a prompt template.
///
/// Example:
/// ```dart
/// AiGridSmartColumn(
///   field: 'sentiment',
///   title: 'AI Sentiment',
///   promptTemplate: "Classify customer sentiment of '{feedback}' as Positive, Neutral, or Negative",
///   options: ['Positive', 'Neutral', 'Negative'],
///   autoExecute: true,
/// )
/// ```
class AiGridSmartColumn extends AiGridColumn {
  /// Prompt template containing `{fieldName}` interpolation variables.
  ///
  /// Example: `"Rate urgency from 1 to 5 for issue: '{issue_description}'"`
  final String promptTemplate;

  /// Optional list of predefined output categories or discrete options
  /// (e.g. `['Positive', 'Neutral', 'Negative']` or `['P1', 'P2', 'P3', 'P4']`).
  final List<String>? options;

  /// Whether to automatically trigger batch generation upon grid load or column attach.
  final bool autoExecute;

  /// Custom local heuristic/fallback evaluator invoked when offline or when
  /// no LLM credentials are configured.
  final FutureOr<dynamic> Function(Map<String, dynamic> row)? localEvaluator;

  /// Custom accent color for the AI sparkle indicator icon/badge.
  final Color? sparkleColor;

  const AiGridSmartColumn({
    required super.field,
    required super.title,
    required this.promptTemplate,
    this.options,
    this.autoExecute = false,
    this.localEvaluator,
    this.sparkleColor,
    super.type = AiGridColumnType.text,
    super.width = 170,
    super.minWidth = 100,
    super.maxWidth,
    super.isGroupable = true,
    super.isSortable = true,
    super.isFilterable = true,
    super.editable = true,
    super.cellStyle,
    super.cellColor,
    super.cellBuilder,
    super.visual,
    super.numberFormat,
    super.aggregateType,
    super.required,
    super.validator,
    super.onChanged,
    super.editorBuilder,
    super.editorIndex,
    super.editorOptions,
    super.editorType,
    super.enableEditingMode,
    super.resizable,
    super.columnWidth,
  });

  /// Interpolates `{field}` placeholders in [promptTemplate] using row values.
  String formatPrompt(Map<String, dynamic> row) {
    var result = promptTemplate;
    for (final entry in row.entries) {
      final key = entry.key;
      final val = entry.value?.toString() ?? '';
      result = result.replaceAll('{$key}', val);
      // Also match case-insensitively without braces
      result = result.replaceAll('{${key.toLowerCase()}}', val);
    }
    return result;
  }

  /// Copies this smart column with updated properties.
  AiGridSmartColumn copySmartColumnWith({
    String? field,
    String? title,
    String? promptTemplate,
    List<String>? options,
    bool? autoExecute,
    FutureOr<dynamic> Function(Map<String, dynamic> row)? localEvaluator,
    Color? sparkleColor,
    AiGridColumnType? type,
    double? width,
    double? minWidth,
    double? maxWidth,
    bool? resizable,
    bool? isGroupable,
    bool? isSortable,
    bool? isFilterable,
    bool? editable,
    AiGridAggregateType? aggregateType,
    String? numberFormat,
    TextStyle? Function(dynamic value, Map<String, dynamic> row)? cellStyle,
    Color? Function(dynamic value, Map<String, dynamic> row)? cellColor,
    FitGridCellBuilder<Map<String, dynamic>>? cellBuilder,
    FitGridCellVisual<Map<String, dynamic>>? visual,
  }) {
    return AiGridSmartColumn(
      field: field ?? this.field,
      title: title ?? this.title,
      promptTemplate: promptTemplate ?? this.promptTemplate,
      options: options ?? this.options,
      autoExecute: autoExecute ?? this.autoExecute,
      localEvaluator: localEvaluator ?? this.localEvaluator,
      sparkleColor: sparkleColor ?? this.sparkleColor,
      type: type ?? this.type,
      width: width ?? this.width,
      minWidth: minWidth ?? this.minWidth,
      maxWidth: maxWidth ?? this.maxWidth,
      resizable: resizable ?? this.resizable,
      isGroupable: isGroupable ?? this.isGroupable,
      isSortable: isSortable ?? this.isSortable,
      isFilterable: isFilterable ?? this.isFilterable,
      editable: editable ?? this.editable,
      aggregateType: aggregateType ?? this.aggregateType,
      numberFormat: numberFormat ?? this.numberFormat,
      cellStyle: cellStyle ?? this.cellStyle,
      cellColor: cellColor ?? this.cellColor,
      cellBuilder: cellBuilder ?? this.cellBuilder,
      visual: visual ?? this.visual,
    );
  }
}
