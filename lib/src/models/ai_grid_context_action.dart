import 'package:flutter/material.dart';

import '../controllers/ai_grid_controller.dart';

/// Callback invoked when a contextual action is triggered.
typedef AiGridContextActionHandler = Future<void> Function(
  BuildContext context,
  AiGridController controller,
  Map<String, dynamic> row,
  int rowIndex,
  String? columnField,
);

/// A contextual action available via cell/row right-click or long-press.
class AiGridContextAction {
  /// Unique identifier for this action (e.g. 'ask_ai', 'filter_similar', 'custom_export').
  final String id;

  /// Human-readable label displayed in the context menu.
  final String label;

  /// Optional icon displayed alongside the label.
  final IconData? icon;

  /// Whether this action is powered by AI (renders a subtle sparkle badge).
  final bool isAiAction;

  /// Whether this is a destructive action (renders in danger / error color).
  final bool isDestructive;

  /// Optional predicate determining if this action is visible for the given row and column.
  final bool Function(Map<String, dynamic> row, String? columnField)? isVisible;

  /// Execution handler for this action.
  final AiGridContextActionHandler onExecute;

  const AiGridContextAction({
    required this.id,
    required this.label,
    this.icon,
    this.isAiAction = false,
    this.isDestructive = false,
    this.isVisible,
    required this.onExecute,
  });
}

/// Configuration for the contextual menu system across desktop right-click and mobile long-press.
class AiGridContextMenuConfiguration {
  /// Whether the context menu is enabled on right-click / long-press.
  final bool enabled;

  /// Whether built-in AI contextual actions (Ask AI, Draft Message, Explain Outlier) are included.
  final bool enableAiActions;

  /// Whether standard clipboard copy actions (Copy Cell, Copy Row JSON) are included.
  final bool enableClipboardActions;

  /// Whether row editing / deleting actions are included if editing is enabled on the grid.
  final bool enableEditingActions;

  /// Whether the 1-click "Filter Similar Records" action is included.
  final bool enableFilterSimilar;

  /// Additional developer-defined custom contextual actions.
  final List<AiGridContextAction> customActions;

  /// Optional callback invoked after any context action is executed.
  final void Function(String actionId, Map<String, dynamic> row)?
  onActionExecuted;

  const AiGridContextMenuConfiguration({
    this.enabled = true,
    this.enableAiActions = true,
    this.enableClipboardActions = true,
    this.enableEditingActions = true,
    this.enableFilterSimilar = true,
    this.customActions = const [],
    this.onActionExecuted,
  });

  AiGridContextMenuConfiguration copyWith({
    bool? enabled,
    bool? enableAiActions,
    bool? enableClipboardActions,
    bool? enableEditingActions,
    bool? enableFilterSimilar,
    List<AiGridContextAction>? customActions,
    void Function(String actionId, Map<String, dynamic> row)? onActionExecuted,
  }) {
    return AiGridContextMenuConfiguration(
      enabled: enabled ?? this.enabled,
      enableAiActions: enableAiActions ?? this.enableAiActions,
      enableClipboardActions:
          enableClipboardActions ?? this.enableClipboardActions,
      enableEditingActions: enableEditingActions ?? this.enableEditingActions,
      enableFilterSimilar: enableFilterSimilar ?? this.enableFilterSimilar,
      customActions: customActions ?? this.customActions,
      onActionExecuted: onActionExecuted ?? this.onActionExecuted,
    );
  }
}
