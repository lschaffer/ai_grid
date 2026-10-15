---
name: ai-grid
description: Comprehensive developer and coding agent guide for the ai_grid Flutter DataGrid package. Use when integrating, configuring, or extending high-performance canvas tables with DevExtreme-style editing (cell, row, modal form), dynamic Pivot Grids with banded split headers, hierarchical tree grouping, moveable split-panel charts, Excel export, and native Model Context Protocol (MCP) AI tools.
version: 0.3.0
author: lschaffer
tags:
  - flutter
  - datagrid
  - pivot-table
  - devextreme
  - ai-assistant
  - mcp
  - model-context-protocol
  - excel-export
---

# AI Grid (`ai_grid`) Skill for Coding Agents

This skill provides an authoritative, complete guide for coding agents (Claude Code, Antigravity, Cursor, Windsurf, Roo, etc.) and software engineers integrating, configuring, or customizing the **`ai_grid`** Flutter package.

---

## 1. Package Overview & Architecture

`ai_grid` is an enterprise-grade Flutter DataGrid combining:
1. **Ultra-High Performance Canvas Virtualization**: Powered by `fitgrid_table` — paints cells directly to the Flutter canvas with ~3ms frame times across up to 1,000,000 rows.
2. **DevExtreme-Style Editing**: In-place cell editing, inline row editing with draft states and pinned action buttons, and modal popup form dialogs (`AiGridFormDialog`) with 4 configurable layouts.
3. **DevExtreme-Style On-The-Fly Pivot Grid**: Transform any active table into an aggregated multi-dimensional pivot grid with banded split headers (`FitGridColumnGroup`), hierarchical tree row grouping, and moveable split-panel canvas charts.
4. **Native AI Assistant & Model Context Protocol (MCP)**: 18 built-in tools (`dart_mcp_core`) enabling LLMs to introspect schema, run exact-math calculations in Dart (zero hallucination), filter, sort, group, pivot, and export via natural language.
5. **Pure-Dart Excel (.xlsx) Export**: Zero native C/C++ dependencies; opens platform-native "Save As..." dialog across Desktop, Web, and Mobile.
6. **Ecosystem Standard**: Fully compatible with `package:material_ui` and Flutter 3.24+ WebAssembly (`dart2wasm`).

---

## 2. Installation & Dependencies

In `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  ai_grid: ^0.3.0
  material_ui: ^1.4.0
```

> [!IMPORTANT]
> Always import `package:material_ui/material_ui.dart` across your application and widgets to ensure full compatibility with unbundled Flutter environments.

---

## 3. Basic DataGrid Setup

```dart
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ai_grid/ai_grid.dart';

class MyGridPage extends StatefulWidget {
  const MyGridPage({super.key});

  @override
  State<MyGridPage> createState() => _MyGridPageState();
}

class _MyGridPageState extends State<MyGridPage> {
  late final AiGridController _controller;
  late final LocalAiGridDataSource _dataSource;

  final List<AiGridColumn> _columns = [
    const AiGridColumn(
      field: 'id',
      title: 'ID',
      width: 80,
      type: AiGridColumnType.text,
      isGroupable: false,
    ),
    const AiGridColumn(
      field: 'product',
      title: 'Product',
      width: 180,
      type: AiGridColumnType.text,
    ),
    const AiGridColumn(
      field: 'category',
      title: 'Category',
      width: 140,
      type: AiGridColumnType.text,
    ),
    const AiGridColumn(
      field: 'sales',
      title: 'Sales',
      width: 120,
      type: AiGridColumnType.currency,
      numberFormat: '#,##0.00',
      aggregateType: AiGridAggregateType.sum,
    ),
    const AiGridColumn(
      field: 'quantity',
      title: 'Quantity',
      width: 100,
      type: AiGridColumnType.number,
      aggregateType: AiGridAggregateType.sum,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AiGridController();
    _dataSource = LocalAiGridDataSource(
      columns: _columns,
      initialData: [
        {'id': '1', 'product': 'Laptop', 'category': 'Technology', 'sales': 1200.0, 'quantity': 2},
        {'id': '2', 'product': 'Desk Chair', 'category': 'Furniture', 'sales': 250.0, 'quantity': 4},
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AiGrid(
        controller: _controller,
        dataSource: _dataSource,
        showToolbar: true,
        enableAiAssistant: true,
        autoSave: true,
        persistenceKey: 'my_grid_settings',
      ),
    );
  }
}
```

---

## 4. Column Configuration (`AiGridColumn`)

| Property | Type | Description |
| :--- | :--- | :--- |
| `field` | `String` | Unique key in row data map. |
| `title` | `String` | Display label in header. |
| `type` | `AiGridColumnType` | `text`, `number`, `currency`, `date`, `boolean`, `select`. |
| `width` | `double?` | Preferred pixel width. |
| `minWidth` / `maxWidth` | `double` | Sizing limits for interactive resizing. |
| `columnWidth` | `FitGridColumnWidth?` | `auto()`, `fixed(w)`, `flex(share)`, `fitHeader()`. |
| `aggregateType` | `AiGridAggregateType` | Footer rollup: `none`, `sum`, `average`, `min`, `max`, `count`. |
| `numberFormat` | `String?` | Custom pattern (e.g. `'#,##0.00'`, `'\$#,##0'`). |
| `selectOptions` | `List<String>?` | Predefined dropdown items for `select` type. |
| `editable` | `bool?` | Explicitly enable or disable editing on this column. |
| `editorIndex` | `int?` | Ordering index of field in `form` popup dialog. |
| `editorType` | `AiGridEditorType?` | Control type (`text`, `number`, `currency`, `date`, `dateTime`, `select`, `boolean`). |
| `validator` | `String? Function(dynamic)?` | Validation callback returning error message or `null`. |
| `required` | `bool` | Mandatory field validation (fails if empty/whitespace). |
| `editorBuilder` | `Widget Function(...)` | Completely custom input widget builder for inline or form editing. |

---

## 5. DevExtreme-Style DataGrid Editing

Configure editing via `AiGridEditingOptions`:

```dart
AiGridEditingOptions(
  enabled: true,
  mode: AiGridEditMode.row, // .cell, .row, or .form
  allowAdding: true,
  allowUpdating: true,
  allowDeleting: true,
  actionColumnPosition: AiGridActionColumnPosition.left, // .left or .right
  formLayout: AiGridFormLayout.grid, // .row, .wrap, .grid, .custom
  formGridColumns: 2, // 2-column layout in form dialog
  confirmDelete: true,
  commit: (row, isNew) async {
    // Persist to backend database / REST API
    await myApi.saveRecord(row, isNew: isNew);
  },
  afterSave: (row, isNew) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isNew ? 'Row created!' : 'Row updated!')),
    );
  },
  afterDelete: (row) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Row deleted!')),
    );
  },
)
```

### Editing Modes (`AiGridEditMode`)
1. **`AiGridEditMode.cell`**: Direct in-place cell editing on click or double-tap.
2. **`AiGridEditMode.row`**: Full-row inline editing with draft buffer and pinned action icons:
   - `check`: Validates all columns, commits changes, and calls `afterSave`.
   - `close`: Discards draft changes without persisting.
   - `edit_outlined`: Enters row editing mode for that index.
   - `delete_outline`: Triggers confirmation dialog and removes the row.
3. **`AiGridEditMode.form`**: Modal Material 3 popup form (`AiGridFormDialog`) with field ordering (`editorIndex`), multi-column grid layouts, and vertical error summaries.

---

## 6. DevExtreme-Style Dynamic Pivot Grid & Side-by-Side Chart

Transform any active table into an enterprise multi-dimensional Pivot Grid programmatically or via AI prompt:

### Programmatic Activation
```dart
controller.setPivot(
  const AiGridPivotConfig(
    rowFieldIds: ['Category', 'SubCategory'],
    columnFieldIds: ['Segment', 'Region'],
    values: [
      AiGridPivotValueConfig(columnId: 'Sales', aggregation: AiGridPivotAggregation.sum),
      AiGridPivotValueConfig(columnId: 'Discount', aggregation: AiGridPivotAggregation.average),
    ],
    groupByRows: true, // DevExtreme hierarchical tree row grouping
    showColumnTotals: true, // Grand total columns
    showChart: true,
    chartType: AiGridPivotChartType.groupedBar,
  ),
);

// Switch back to normal table mode anytime:
controller.clearPivot();
```

### Key Pivot Features
* **Banded Split Column Headers (`FitGridColumnGroup`)**:
  - Automatically merges parent column dimension headers across nested metrics:
    $$\begin{array}{|c|c|c|c|}
    \hline
    \multirow{2}{*}{\text{Category}} & \multicolumn{2}{c|}{\textbf{Consumer / Central}} & \multicolumn{1}{c|}{\textbf{Grand Total}} \\
    \cline{2-4}
    & \text{Sales (Sum)} & \text{Discount (Average)} & \text{Sales (Sum)} \\
    \hline
    \end{array}$$
  - Row dimensions (`Category`, `SubCategory`) automatically span the full double-height header vertically.
* **Hierarchical Tree Row Grouping**:
  - Automatically groups by preceding row dimensions (`rowDimensions.take(length - 1)`), providing expandable/collapsible drill-downs with aggregated subtotals.
* **Moveable Split-Panel Chart**:
  - Side-by-side canvas chart (`AiGridPivotChart`) supporting `groupedBar`, `column`, `line`, and `pie`.
  - Interactive draggable splitter with 1:1 absolute mouse tracking and visual drag feedback.
  - Automatically filters to Top-6 series and Top-10 categories by total volume to prevent canvas/legend overflows on high-cardinality dimensions.
* **Clean Empty Cell Formatting**:
  - Null cross-tabulation intersections render cleanly with a muted em-dash (`—`), and numeric values format with `#,##0.##`.

---

## 7. Model Context Protocol (MCP) AI Tools Reference

`ai_grid` provides 18 registered MCP local tools via `AiGridSkill`:

| Tool Name | Key Parameters | Description |
| :--- | :--- | :--- |
| `grid_get_schema` | *(none)* | Returns columns, types, titles, editable status, and active features. |
| `grid_get_state` | *(none)* | Returns active grouping, filters, sorting, search query, and row counts. |
| `grid_get_sample_data` | `limit` (int) | Retrieves 1–10 sample rows for contextual LLM reasoning. |
| `grid_calculate` | `column`, `calculation` (`sum`, `average`, `median`, `min`, `max`, `count`), `groupBy` | **Hallucination-free math engine** executed strictly in Dart. |
| `grid_set_filter` | `field`, `operator` (`equals`, `notEquals`, `contains`, `doesNotContain`, `greaterThan`, `inList`), `value` | Applies single or multi-column filters joined by AND. |
| `grid_clear_filters` | `field` (optional) | Clears all or specified column filters. |
| `grid_sort` | `column`, `descending`, `multiSort` | Applies multi-column prioritized sorting. |
| `grid_group` | `columns` (array) | Sets multi-level hierarchical row grouping. |
| `grid_set_column_visibility` | `visible`, `hidden`, `showOnly` | Shows or hides specific columns. |
| `grid_search` | `query` | Executes global cross-column full-text search. |
| `export` | *(none)* | Exports data to Excel (`.xlsx`) and triggers native Save As dialog. |
| `grid_export` | `format` (`xlsx`, `csv`, `tsv`, `json`), `filename` | Exports data in chosen format and saves file. |
| `grid_go_to_page` | `page`, `direction` (`next`, `prev`, `first`, `last`), `pageSize` | Navigates client or server pagination. |
| `grid_get_pagination_status` | *(none)* | Returns active page index, total pages, and page size. |
| `grid_export_settings` | *(none)* | Exports all grid layout settings as JSON string. |
| `grid_restore_settings` | `settings` | Restores layout settings from JSON string or map. |
| `grid_create_pivot_table` | `rows`, `columns`, `data` (`column`, `aggregation`), `showChart`, `chartType` | Transforms grid into an aggregated Pivot Table on the fly. |
| `grid_reset_pivot_table` | *(none)* | Deactivates pivot mode and restores original table. |

---

## 8. Best Practices for AI Agents Writing Pivot Prompts

### ✅ Dense, Informative Aggregations
Pivot tables are designed to **aggregate higher-level categorical dimensions**:
* **Category &times; Region**:
  `create pivot table, rows category and subcategory, columns segment and region, data fields sales (sum), discount (avg)`
  $\rightarrow$ 17 rows $\times$ 12 banded columns. **Every cell has populated data.**
* **State &times; Segment**:
  `create pivot table, rows state, columns segment, data fields sales (sum), profit (sum)`
* **Category &times; Ship Mode**:
  `create pivot table, rows category, columns ship mode, data fields sales (sum), quantity (sum), chart type column`

### ⚠️ Avoid Primary Key Cross-Tabulation Sparsity
* **Rule**: Never combine a unique leaf key (e.g. `OrderID` or `CustomerID` with 1,000 distinct values) against a high-cardinality column dimension (e.g. `City` with 500 distinct values).
* **Why**: Each individual order occurred in only *one* city. A matrix of $693 \times 482 = 334,000$ cells will mathematically have $99.8\%$ empty cells (`—`).
* **Fix**: Use categorical dimensions (`Category`, `SubCategory`, `Region`, `Segment`, `ShipMode`, `State`) for dense, insightful business intelligence.

---

## 9. Layout Persistence & Settings Storage

Enable automatic persistence across app restarts:
```dart
AiGrid(
  controller: _controller,
  dataSource: _dataSource,
  autoSave: true,
  persistenceKey: 'user_sales_grid_v1',
)
```
Or export/import programmatically:
```dart
// Export layout to JSON
final jsonString = _controller.exportSettingsJson();

// Restore layout from JSON
_controller.restoreSettingsJson(jsonString);
```
Persists:
- Active column filters and search query
- Multi-level hierarchical row groupings
- Prioritized multi-column sorts
- Column visibility and custom column widths
- Inline filter header row visibility

---

## 10. Server-Side Data Loading (`LazyAiGridDataSource`)

For datasets with millions of rows loaded on-demand from a remote API:

```dart
final dataSource = LazyAiGridDataSource(
  columns: myColumns,
  totalRows: 500000,
  fetch: (page, pageSize, sorts, filters) async {
    final response = await myBackendApi.getRows(
      offset: (page - 1) * pageSize,
      limit: pageSize,
      sortColumn: sorts.firstOrNull?.field,
      sortAscending: sorts.firstOrNull?.direction == FitGridSortDirection.ascending,
      filterQuery: filters,
    );
    return response.rows;
  },
);
```

---

## 11. Coding Guidelines for AI Agents

1. **Package Imports**: Always import `package:material_ui/material_ui.dart` instead of `flutter/material.dart`.
2. **Never Call `setState` in Builds**: Always schedule state updates after frames or attach listeners inside `initState`/`dispose`.
3. **Empty Pivot Intersections**: Null values in pivot cells are intentional representations of sparse intersections; format with `'—'` in muted gray rather than empty strings.
4. **Synchronize Changes to Forked Repos**: If modifying files inside `lib/src/fitgrid/`, ensure identical parity with `c:\projects\ls\fitgrid`.
