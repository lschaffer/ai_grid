import 'dart:async';
import 'package:flutter/widgets.dart';

/// Editing mode of the [AiGrid].
enum AiGridEditMode {
  /// Default cell editing: tap or double-tap an individual cell to edit it.
  cell,

  /// Inline row editing: activates an entire row with dedicated Edit/Delete/Save/Cancel actions.
  row,

  /// Modal popup form: opens a dialog containing form fields for all editable columns.
  form,
}

/// Layout mode for the popup edit form.
enum AiGridFormLayoutMode {
  /// Vertical list view with one field per row (scrollable).
  row,

  /// Horizontal flow that automatically wraps fields left-to-right, then down.
  wrap,

  /// Structured multi-column grid (e.g. 2, 3, or 4 columns).
  grid,

  /// Fully custom user-provided widget builder.
  custom,
}

/// Configuration for the form layout in [AiGridEditMode.form].
class AiGridFormLayout {
  final AiGridFormLayoutMode mode;

  /// Number of columns for [AiGridFormLayoutMode.grid].
  final int? columns;

  /// Horizontal spacing between fields.
  final double fieldSpacing;

  /// Vertical spacing between field rows.
  final double rowSpacing;

  /// Fixed or base width of each field in [AiGridFormLayoutMode.wrap].
  final double? fieldWidth;

  /// Custom form widget builder for [AiGridFormLayoutMode.custom].
  final Widget Function(
    BuildContext context,
    Map<String, dynamic> draftValues,
    void Function(String column, dynamic value) onChanged,
  )? formBuilder;

  const AiGridFormLayout.row({this.rowSpacing = 12.0})
      : mode = AiGridFormLayoutMode.row,
        columns = 1,
        fieldSpacing = 0,
        fieldWidth = null,
        formBuilder = null;

  const AiGridFormLayout.wrap({
    this.fieldWidth = 240.0,
    this.fieldSpacing = 12.0,
    this.rowSpacing = 12.0,
  })  : mode = AiGridFormLayoutMode.wrap,
        columns = null,
        formBuilder = null;

  const AiGridFormLayout.grid({
    this.columns = 2,
    this.fieldSpacing = 16.0,
    this.rowSpacing = 16.0,
  })  : mode = AiGridFormLayoutMode.grid,
        fieldWidth = null,
        formBuilder = null;

  const AiGridFormLayout.custom(this.formBuilder)
      : mode = AiGridFormLayoutMode.custom,
        columns = null,
        fieldSpacing = 0,
        rowSpacing = 0,
        fieldWidth = null;
}

/// Position of the pinned action column in [AiGridEditMode.row].
enum AiGridActionColumnPosition {
  left,
  right,
}

/// Explicit input control type for editing a column cell or form field.
enum AiGridEditorType {
  text,
  number,
  currency,
  date,
  boolean,
  select,
}

/// Comprehensive configuration options for editing in [AiGrid].
class AiGridEditingOptions {
  /// Whether editing features are enabled on the grid.
  final bool enabled;

  /// The active editing mode ([AiGridEditMode.cell], [AiGridEditMode.row], or [AiGridEditMode.form]).
  final AiGridEditMode mode;

  /// Whether users can add new rows. When true, an "+ Add" button appears in the toolbar.
  final bool allowAdding;

  /// Whether users can update/edit existing rows.
  final bool allowUpdating;

  /// Whether users can delete existing rows.
  final bool allowDeleting;

  /// Position of the action column in [AiGridEditMode.row] (defaults to [AiGridActionColumnPosition.right]).
  final AiGridActionColumnPosition actionColumnPosition;

  /// Layout structure when editing in [AiGridEditMode.form].
  final AiGridFormLayout formLayout;

  /// Optional custom title for the popup edit/add form dialog.
  final String? popupTitle;

  /// Width constraint for the popup dialog (defaults to 560.0).
  final double popupWidth;

  /// Optional height constraint for the popup dialog.
  final double? popupHeight;

  /// Called before saving changes. Return an error message to block save and display the error,
  /// or return null to proceed.
  final FutureOr<String?> Function(Map<String, dynamic> row, Map<String, dynamic> changes)? beforeSave;

  /// Called for each modified field to persist the value back to the model or database.
  final void Function(String column, dynamic value)? commit;

  /// Called immediately after a row has been successfully updated or added.
  final void Function(Map<String, dynamic> row)? afterSave;

  /// Called before deleting a row. Return true to confirm deletion, or false to cancel.
  final FutureOr<bool> Function(Map<String, dynamic> row)? beforeDelete;

  /// Called immediately after a row has been removed.
  final void Function(Map<String, dynamic> row)? afterDelete;

  const AiGridEditingOptions({
    this.enabled = true,
    this.mode = AiGridEditMode.cell,
    this.allowAdding = false,
    this.allowUpdating = true,
    this.allowDeleting = false,
    this.actionColumnPosition = AiGridActionColumnPosition.right,
    this.formLayout = const AiGridFormLayout.row(),
    this.popupTitle,
    this.popupWidth = 560.0,
    this.popupHeight,
    this.beforeSave,
    this.commit,
    this.afterSave,
    this.beforeDelete,
    this.afterDelete,
  });
}
