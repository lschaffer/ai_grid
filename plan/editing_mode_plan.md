# Architectural Plan: DevExtreme-Style Editing for `ai_grid`

This document details the design and implementation for comprehensive DataGrid editing in **`ai_grid`**, drawing from [DevExtreme DataGrid Editing](https://js.devexpress.com/Angular/Documentation/ApiReference/UI_Components/dxDataGrid/Configuration/editing/) while integrating natively with **`fitgrid_table`** and Flutter's widget architecture.

---

## 1. Architecture & Design Principles

```
┌────────────────────────────────────────────────────────────────────────┐
│                          AiGridEditingOptions                          │
│  • mode: cell | row | form (popup)                                     │
│  • allowAdding | allowUpdating | allowDeleting                         │
│  • actionColumnPosition: left | right                                  │
│  • formLayout: row (list) | wrap | grid | formBuilder                  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
         ┌──────────────────────────┼──────────────────────────┐
         ▼                          ▼                          ▼
   ┌───────────┐              ┌───────────┐              ┌───────────┐
   │ Cell Mode │              │ Row Mode  │              │ Form Mode │
   │ (Inline)  │              │ (Inline)  │              │  (Popup)  │
   └─────┬─────┘              └─────┬─────┘              └─────┬─────┘
         │                          │                          │
         ▼                          ▼                          ▼
  Direct FitGrid           Pinned Action Column        Modal Dialog
  Cell Overlays            [Edit] [Delete]            [Form Layout]
  (Canvas-native)          [Save] [Cancel]            [Save] [Cancel]
         │                          │                          │
         └──────────────────────────┼──────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                   Validation & Lifecycle Pipeline                      │
│                                                                        │
│   1. beforeSave(row, changes) ──> [Validation: String? / bool]         │
│   2. commit(column, value)    ──> [Data Source Update]                 │
│   3. afterSave(updatedRow)    ──> [Persistence & Notification]         │
│                                                                        │
│   1. beforeDelete(row)        ──> [Confirmation / Guard]               │
│   2. afterDelete(deletedRow)  ──> [Data Source Removal]                │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Configuration Models

### 2.1 Editing Mode Enum
```dart
enum AiGridEditMode {
  /// Default FitGrid behavior: tap or double-tap an individual cell to edit it.
  cell,

  /// Inline row editing: activates an entire row with dedicated Edit/Delete/Save/Cancel actions.
  row,

  /// Modal popup form: opens a dialog containing form fields for all editable columns.
  form,
}
```

### 2.2 Form Layout Strategy Enum & Config
```dart
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

class AiGridFormLayout {
  final AiGridFormLayoutMode mode;
  final int? columns; // For grid mode (e.g. 2, 3, or 4)
  final double fieldSpacing;
  final double rowSpacing;
  final double? fieldWidth; // For wrap mode (e.g. 240px per field)
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
```

### 2.3 Action Column Position Enum
```dart
enum AiGridActionColumnPosition {
  left,
  right,
}
```

### 2.4 Editing Options Class (`AiGridEditingOptions`)
```dart
class AiGridEditingOptions {
  final bool enabled;
  final AiGridEditMode mode;
  final bool allowAdding;
  final bool allowUpdating;
  final bool allowDeleting;
  final AiGridActionColumnPosition actionColumnPosition;
  final AiGridFormLayout formLayout;
  final String? popupTitle;
  final double popupWidth;
  final double? popupHeight;

  // Validation & Lifecycle hooks
  final FutureOr<String?> Function(Map<String, dynamic> row, Map<String, dynamic> changes)? beforeSave;
  final void Function(String column, dynamic value)? commit;
  final void Function(Map<String, dynamic> row)? afterSave;
  final FutureOr<bool> Function(Map<String, dynamic> row)? beforeDelete;
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
```

---

## 3. Column-Level Editor Enhancements (`AiGridColumn`)

To support Form and Row modes alongside Cell mode, `AiGridColumn` will be extended with:

| Property | Type | Description |
|---|---|---|
| `editable` | `bool` | Whether this column can be edited (defaults to `false`). Only columns with `editable == true` appear in the edit form or row editor. |
| `editorIndex` | `int?` | Explicit layout order in Form/Popup mode (columns sorted by `editorIndex`, then by column definition order). |
| `editorType` | `AiGridEditorType?` | Explicit editor widget type (`text`, `number`, `currency`, `date`, `boolean`, `select`). Defaults to mapping from `type`. |
| `editorOptions` | `Map<String, dynamic>?` | Extra options (e.g. min/max for numbers, date picker ranges, select items). |
| `editorBuilder` | `Widget Function(...)` | Custom editor builder override for bespoke widgets (e.g. colour picker, slider, barcode scanner). |
| `validator` | `String? Function(dynamic val)` | Per-field validation rule returning error text or `null`. |

---

## 4. State Management in `AiGridController`

`AiGridController` will manage active edit sessions:

1. **State variables**:
   - `int? _editingRowIndex`: Current row index being edited in `row` or `form` mode.
   - `Map<String, dynamic>? _draftRow`: Copy of row being edited.
   - `bool _isAddingRow`: `true` if editing a brand-new row.
   - `Map<String, String> _validationErrors`: Map of column field names to error messages.
2. **Controller methods**:
   - `startAdd()`: Opens a blank form (or activates new row at top) initialized with column defaults.
   - `startEdit(int rowIndex)`: Opens edit form or activates row mode for the given row.
   - `saveEdit()`: Validates draft via `beforeSave`, applies updates via `commit` / data source, calls `afterSave`, and closes editor.
   - `cancelEdit()`: Discards draft changes and resets state.
   - `deleteRow(int rowIndex)`: Runs `beforeDelete`, removes row from data source, and calls `afterDelete`.

---

## 5. Editing Modes Implementation Details

### 5.1 Cell Mode (Default)
- Connects directly to `FitGridColumn.editor`.
- Double-clicking or pressing Enter on a cell paints an active text/dropdown overlay directly over that cell.
- Focus loss or Enter commits the cell; Escape cancels.

### 5.2 Row Mode
- When `options.mode == AiGridEditMode.row` and (`allowUpdating` or `allowDeleting` is true):
  - Injects a **pinned action column** (`_actionColumn`) either at index 0 (`left`) or the end (`right`).
  - **Normal State**: Displays standard Material icons: `IconButton(icon: Icons.edit_outlined)` and/or `IconButton(icon: Icons.delete_outline)`.
  - **Editing State**: Switches the action column to `[Save (Icons.check)]` and `[Cancel (Icons.close)]`.
  - The row's cells display their respective inline editors or draft values while in editing state.
  - Clicking `[Save]` triggers `saveEdit()`; clicking `[Cancel]` reverts to original values.

### 5.3 Form (Popup) Mode
- Triggered by:
  - Clicking the row's Edit icon (or double-clicking row).
  - Clicking the toolbar's `+ Add` button.
- Displays a Material Design 3 Dialog:
  - **Header**: Title (e.g. *"Edit Order #10024"* or *"Add New Row"*) with Close button.
  - **Body**: Renders only columns where `editable == true`, ordered by `editorIndex`:
    - **`row` layout**: Scrollable vertical `ListView` of labeled `TextFormField`, `DropdownButtonFormField`, Date picker fields, and Switch tiles.
    - **`wrap` layout**: `Wrap` container with fixed item width (e.g. 240px) flowing left-to-right then wrapping down.
    - **`grid` layout**: `GridView` or structured `Table` layout adhering to specified column count (e.g. 2, 3, or 4 columns).
    - **`custom` layout**: Invokes `formLayout.formBuilder(context, draftValues, onChanged)` for completely custom layouts.
  - **Footer**:
    - `[Cancel]` button (secondary text button).
    - `[Save]` button (filled/primary button) with loading and error states.

---

## 6. Toolbar & CRUD Affordances

When `editingOptions.allowAdding == true`:
- The `AiGridToolbar` automatically renders an **`+ Add`** action button:
  - In `form` mode: Opens the Add New Row modal dialog.
  - In `row` mode: Inserts an empty editable draft row at index 0 and scrolls into view.
  - In `cell` mode: Inserts a row and begins editing the first editable cell.

---

## 7. Lifecycle Hooks & Validation Pipeline

```
User clicks [Save]
       │
       ▼
1. Column-Level Validators
   • Run column.validator(val) for each edited field.
   • If invalid ──> Display field errors in form/row; abort save.
       │
       ▼
2. beforeSave(row, changes)
   • Can perform async validation (e.g. check unique SKU via API).
   • Can return an error String ──> Display snackbar/banner; abort save.
   • Can return false ──> Abort save silently.
       │
       ▼
3. commit(column, value)
   • Calls user commit callback for each changed field.
   • Updates underlying LocalAiGridDataSource or LazyAiGridDataSource.
       │
       ▼
4. afterSave(updatedRow)
   • Calls host callback.
   • Triggers autoSave / layout persistence if enabled.
   • Closes dialog / row edit state.
```

---

## 8. AI Assistant Integration (MCP Tools)

The AI Assistant will also gain native tools to perform edits safely through the same lifecycle pipeline:
1. `grid_add_row`: `{ "values": { "City": "Denver", "Sales": 250 } }`
2. `grid_update_row`: `{ "rowIndex": 5, "values": { "Status": "Shipped" } }`
3. `grid_delete_row`: `{ "rowIndex": 5 }`

All AI-initiated modifications will run through the same `beforeSave` and `commit` guards.

---

## 9. Step-by-Step Implementation Roadmap

| Milestone | Deliverables |
|---|---|
| **Phase 1: Models & Column Spec** | • Add `AiGridEditMode`, `AiGridFormLayout`, `AiGridEditingOptions`<br>• Extend `AiGridColumn` with `editable`, `editorIndex`, `editorType`, `editorOptions`, `validator`, `editorBuilder`. |
| **Phase 2: Controller State & CRUD API** | • Implement draft row state, `startAdd`, `startEdit`, `saveEdit`, `cancelEdit`, `deleteRow`<br>• Wire validation pipeline (`beforeSave`, `commit`, `afterSave`, `beforeDelete`, `afterDelete`). |
| **Phase 3: Form / Popup Mode Dialog** | • Create `AiGridFormDialog` component<br>• Implement `row`, `wrap`, `grid`, and custom `formBuilder` layouts<br>• Build standard editor widgets (text, number, date picker, dropdown, boolean switch). |
| **Phase 4: Row Mode & Pinned Action Column** | • Implement dynamic action column (left/right pinned) with standard Material icons (`Icons.edit_outlined`, `Icons.delete_outline`, `Icons.check`, `Icons.close`)<br>• Connect inline row edit toggling. |
| **Phase 5: Toolbar Integration & AI Tools** | • Add `+ Add` button in `AiGridToolbar`<br>• Expose MCP editing tools (`grid_add_row`, `grid_update_row`, `grid_delete_row`). |
| **Phase 6: Example Showcase & Tests** | • Add editable demo page in `example/lib/main.dart` demonstrating Cell, Row, and Form modes<br>• Comprehensive unit & widget test suite. |
