# AI Grid (`ai_grid`)

[![pub version](https://img.shields.io/badge/pub-v0.9.0-blue.svg)](https://pub.dev/packages/ai_grid)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.24.0-02569B.svg?logo=flutter)](https://flutter.dev)
[![WASM Ready](https://img.shields.io/badge/WebAssembly-WASM%20Compatible-success.svg)](https://flutter.dev/to/wasm)

**AI Grid** is an intelligent, high-performance DataGrid for Flutter that bridges enterprise tabular virtualization with native AI assistant controls and Model Context Protocol (MCP) tool execution.

![AI Grid Showcase](https://raw.githubusercontent.com/lschaffer/ai_grid/main/example_1.png)

![AI Smart Synthesis Columns](https://raw.githubusercontent.com/lschaffer/ai_grid/main/example_combined_ai_synth_column.png)

![Range Selection & Multi-Cell Copy](https://raw.githubusercontent.com/lschaffer/ai_grid/main/example_combined_range_selection.png)

![Master-Detail Child Rows & Nested DataGrids](https://raw.githubusercontent.com/lschaffer/ai_grid/main/example_combined_master_detail.png)

![AI Grid Live Demo](https://raw.githubusercontent.com/lschaffer/ai_grid/main/ai_grid_example1.gif)

![AI Grid Pivot Grid & Side-by-Side Chart](https://raw.githubusercontent.com/lschaffer/ai_grid/main/ai_grid_example_pivot.gif)

* **Grid Engine**: Powered by **[fitgrid_table](https://pub.dev/packages/fitgrid_table)** — measuring your content instead of guessing widths, painting cells via direct canvas rendering (~3ms frame times on 1M rows), sticky hierarchical row grouping, isolate multi-sort, and summary footers.
* **AI Agent & Tool Orchestration**: Powered by **[dart_mcp_core](https://pub.dev/packages/dart_mcp_core)** — exposing structured MCP local tools for real-time schema introspection, precise in-engine math calculations, multi-column filtering, and natural language table operations.
* **Coding Agent Ready**: Includes a standardized [`SKILL.md`](./SKILL.md) compatible with Claude Code, Antigravity, Cursor, Windsurf, Roo, and other autonomous coding agents for instant API discovery and integration.

---

## ✨ Key Features

### 1. ⚡ High-Performance Canvas DataGrid
* **Direct Canvas Rendering**: Cells are painted directly to the canvas rather than building hundreds of individual widgets, delivering consistent 60/120 FPS scrolling even over 1,000,000 rows.
* **Content-Based Auto-Sizing**: Automatically measures content to fit columns without manual pixel width calculations.
* **Hierarchical Row Grouping**: Drag-and-drop column headers or trigger grouping programmatically with aggregate rollups.
* **Multi-Column Sorting**: Prioritized multi-column sorting with background isolate execution for massive datasets.
* **Inline Column Filtering**: Individual column filter row supporting contains, equals, starts with, ends with, and comparison operators.
* **Aggregate Footers**: Auto-computed sum, average, min, max, and count summary rows.

### 2. ✍️ DevExtreme-Style DataGrid Editing (Cell, Row & Form Modes)

![Modal Form Editing](https://raw.githubusercontent.com/lschaffer/ai_grid/main/example_form_edit.png)

![Inline Row Editing](https://raw.githubusercontent.com/lschaffer/ai_grid/main/example_row_edit.png)

* **Three Editing Modes (`AiGridEditMode`)**:
  * `cell`: Direct in-place cell editing.
  * `row`: Inline row editing with committed draft states, full-cell inputs, and standard Material action icons (`check` to save, `close` to cancel, `edit_outlined`, `delete_outline`).
  * `form`: Modal Material 3 popup form dialog editing all editable fields in a structured layout.
* **Pinned Action Column (`AiGridActionColumnPosition`)**: Automatically pinned to `left` or `right` with compact, overflow-free action buttons.
* **Modal Popup Form (`AiGridFormDialog`)**:
  * Configurable layouts via `AiGridFormLayout`: `row` (vertical scrollable list), `wrap` (horizontal flow), `grid` (multi-column grid), or `custom` (`formBuilder`).
  * Standard Material 3 controls for text, numbers, currency, date & datetime pickers, dropdown selects, and toggle switches.
  * Form field ordering driven by `editorIndex`.
* **Column-Level Editing Rules (`AiGridColumn`)**:
  * `editable`: Explicitly enable or disable editing per column.
  * `required`: Mandatory field validation with inline error border indicators and tooltips.
  * `editorType`: Control type (`text`, `number`, `currency`, `date`, `dateTime`, `select`, `boolean`).
  * `validator`: Field-level validation callbacks.
  * `editorBuilder`: Custom inline or form field widget builders.
* **Complete CRUD Lifecycle & Validation Pipeline**:
  * **Vertical Validation Errors Dialog**: Summary dialog on save listing all errors vertically.
  * **Delete Confirmation Dialog**: Built-in confirmation before deleting rows (`beforeDelete`).
  * Persistence hooks via `commit`, `afterSave`, and `afterDelete`.

### 3. 📑 Master-Detail Child Rows & Nested DataGrids

Embed rich, virtualized expandable child panels beneath any row to show nested tables, order line items, fulfillment timelines, or customer details.

![Master-Detail Child Rows & Nested DataGrids](https://raw.githubusercontent.com/lschaffer/ai_grid/main/example_combined_master_detail.png)

* **Pinned Leading Expansion Column**: Automatically renders a leading chevron toggle column with smooth rotate animations.
* **Full-Width Canvas Virtualization (`detailBuilder`)**: Mounts arbitrary Flutter widgets into full-width detail slots without losing horizontal scrolling or canvas performance.
* **Nested Child `AiGrid` Tables**: Embed independent child data grids with custom schemas, summary aggregate footers, and independent sorting/filtering.
* **Accordion Mode (`autoCollapseOthers`)**: Built-in toggle to automatically collapse previously opened detail rows when a new row is expanded.
* **Persistent Open State Across Mutations**: Row identity key resolver (`rowKey`) keeps detail panels pinned to the correct underlying record through sorting, filtering, and grouping passes.
* **Configurable Panel Height**: Set uniform panel heights via `detailRowHeight` (default `360.0`) or per-row dynamic heights via `detailHeight: (row, index) => ...`.
* **Programmatic & MCP Control**: Full expansion control via `controller.expandRow()`, `controller.collapseRow()`, `controller.toggleRowDetail()`, `controller.expandAllDetails()`, and 4 dedicated MCP tools (`grid_toggle_row_detail`, `grid_expand_all_details`, `grid_collapse_all_details`, `grid_get_detail_status`).

### 4. 📊 DevExtreme-Style Dynamic Pivot Grid & Side-by-Side Chart

Convert any active table into an enterprise multi-dimensional Pivot Grid on the fly with real-time aggregated cross-tabulations and side-by-side synchronized charts.

* **Field Chooser Dialog (`AiGridPivotChooserDialog`)**:
  * Visual drop zones for **Row Fields** (vertical breakdown), **Column Fields** (horizontal cross-tabulation), and **Data / Measures** (metrics to aggregate).
  * Smart column heuristic separating true metrics (`Sales`, `Quantity`, `Profit`) from dimensions (`Category`, `Region`) and primary keys (`OrderID`, `PostalCode`).
  * Aggregation functions: `Sum`, `Average`, `Count`, `Min`, `Max`.
  * One-click presets matching DevExtreme showcase designs (e.g. *Category &times; Region*, *Segment &times; Ship Mode*).
* **DevExtreme-Style Banded Split Column Headers**:
  * Automatically creates unified top-level header bands across multi-column breakdowns (e.g. `Consumer / Central` spanning over `Sales (Sum)` and `Discount (Average)`).
  * Row dimension headers (`Order ID`, `Category`) cleanly span the full double-height header vertically.
* **Hierarchical Row Tree Grouping**:
  * Multiple row dimensions (e.g. `Category` &rarr; `SubCategory`) automatically generate collapsible tree-style grouping with group subtotals.
* **Moveable Split-Panel Canvas Chart**:
  * Side-by-side interactive chart (`AiGridPivotChart`) supporting `groupedBar`, `column`, `line`, and `pie` visualization.
  * Interactive draggable divider with 1:1 absolute mouse tracking and theme-reactive highlight feedback.
  * Smart Top-6 series and Top-10 categories data filtering to prevent legend overflow on large datasets.
* **AI Assistant & Natural Language Control**:
  * Run prompts like *"create pivot table, rows category and subcategory, columns segment, data fields sales (sum), profit (sum)"*.
  * Deactivate or restore standard view anytime via toolbar button or *"reset pivot table"*.

### 5. 🎨 In-Grid Visual Analytics & Conditional Formatting
* **Direct Canvas Cell Visuals**:
  * **Data Bars (`AiGridColumn.dataBar`)**: Horizontal bars painted on canvas behind cell text with customizable positive and negative colors, minimums, maximums, and zero-line alignment.
  * **Progress Tracks (`AiGridColumn.progress`)**: Proportional progress tracks filled to a fraction between 0.0 and 1.0.
  * **In-Cell Sparklines (`AiGridColumnType.sparkline` & `AiGridColumn.sparkline`)**: High-performance mini line and area charts painted directly inside cells from row value arrays without widget overhead.
* **Declarative & Dynamic Conditional Formatting (`AiGridConditionalFormat`)**:
  * Rule-based cell and row highlighting supporting `>`, `<`, `>=`, `<=`, `==`, `!=`, `contains`, `between`, and custom predicates.
  * Entire-row background alerts (`applyToRow: true`) and custom text color/font weight styling.
  * Color scale / heatmap gradient interpolation across minimum to maximum values.
* **Controller Orchestration & Auto-Save**:
  * Programmatic and natural language formatting controls via `controller.addConditionalFormat()` and `controller.clearConditionalFormats()`.
  * Preserved automatically across grid layout persistence and JSON export/restore.

### 6. 📋 Cell Range Selection & Bidirectional Spreadsheet Copy/Paste
* **Desktop-Grade Ergonomics**:
  * Rectangular cell selection via mouse drag and keyboard navigation.
  * `Shift + Arrow` keys dynamically expand and contract active cell boundaries.
  * `Ctrl+C` (or Cmd+C) copies selected rectangular cells into standard Tab-Separated Values (TSV), directly pasteable into Microsoft Excel, Google Sheets, and LibreOffice.
  * `Ctrl+V` (or Cmd+V) parses clipboard TSV matrices and batch-writes into editable columns starting at the active anchor cell.
* **Excel-Style Selection Status Bar**:
  * Real-time metrics computed directly over the active selection: Cell Count, Row/Column Dimensions, Numeric Sum, Average (Mean), Min, and Max.
  * Cleanly docked at the footer of the DataGrid on desktop and mobile.
  * Quick-action copy button with toast notification.
* **Controller APIs & Introspection**:
  * Programmatic range selection via `controller.selectCellRange()`, `controller.selectCell()`, and `controller.clearCellRangeSelection()`.
  * Real-time statistical analysis via `controller.calculateSelectedRangeSummary()` returning `AiGridRangeSummary`.
  * Direct clipboard export via `controller.copySelectedRangeToClipboard()`.
* **MCP Range Tools**:
  * `grid_get_selected_range`: Inspects active selection coordinates, dimensions, and computed statistics.
  * `grid_select_range`: Programmatically selects rectangular cell ranges by row index and column fields.

### 7. ✨ AI Smart / Prompt Columns (LLM Synthesis)
* **LLM-Synthesized Columns (`AiGridSmartColumn`)**: Define columns dynamically evaluated by any configured LLM using per-row prompt template interpolation (e.g. `"Classify sentiment of '{feedback}'"`).
* **Interactive & Batch Execution**: Generate values cell-by-cell on click with interactive sparkle buttons or execute batch synthesis asynchronously across rows with `AiGridSmartColumnRunner`.
* **Discrete Categories & Offline Fallback**: Restrict outputs to categorical enums (`options: ['Positive', 'Neutral', 'Negative']`) with built-in heuristic fallbacks when working offline without active API keys.
* **Autonomous MCP Tools**: AI agents can inspect, add, and run smart columns dynamically via `grid_add_smart_column` and `grid_run_smart_columns`.

### 8. 🧠 Native AI Assistant & Model Context Protocol (MCP)
* **Embedded AI Chat**: Conversational interface that understands your tabular schema, column types, and data distributions.
* **Hallucination-Free Math Engine (`grid_calculate`)**: Calculations (sum, average, minimum, maximum, count, median) are executed strictly inside the Dart engine—ensuring 100% mathematical accuracy without LLM arithmetic errors.
* **Multi-Column AND Filtering**: Seamlessly parses and applies complex queries across multiple columns simultaneously (e.g. *"filter region East and category Furniture"*).
* **Negative Filtering**: Supports `not equals` and `does not contain` operators (e.g. *"Category not Furniture"*, *"exclude South"*).
* **Context-Aware Suggestions**: Proactive quick-action chips generated dynamically based on active columns.
* **LLM Provider Agnostic**: Connects seamlessly with Mistral, OpenAI, Anthropic Claude, Google Gemini, Ollama, custom OpenAI-compatible endpoints, or built-in local heuristics.

### 9. 💾 Save & Restore Grid Settings (Auto-Save)
* **Full State Persistence**: Export or restore grid configuration including:
  * `visibleColumns` & `hiddenColumns`
  * `groupColumns` (hierarchical row grouping)
  * `sorts` (multi-column priority, field, direction)
  * `filters` (field, operator, target value)
  * `showColumnFilterRow` (inline filter header visibility)
* **Automatic Layout Restoration (`autoSave`)**: Pass `autoSave: true` and a `persistenceKey` to automatically persist all user layout changes and restore them on startup.
* **JSON Import/Export**: Export settings to JSON string or save to file via `controller.exportSettingsJson()` and restore via `controller.restoreSettingsJson(str)`.
* **In-Memory Cache**: Built-in `AiGridSettingsStorage` handles session-level caching and retrieval.

### 10. 🌐 Dynamic AI DataGrid (Files, Web GET & Clipboard Ingestion)

Instantly generate, inspect, and interact with dynamic DataGrids from external files, public web APIs, or clipboard content without hardcoding data models:

![Dynamic Grid from Clipboard](https://raw.githubusercontent.com/lschaffer/ai_grid/main/ai_dynamic_grid_from_clipboard.gif)

![Dynamic Grid from PDF](https://raw.githubusercontent.com/lschaffer/ai_grid/main/ai_dynamic_grid_from_pdf.gif)

* **Multi-Source Ingestion**:
  * **Files**: Pick `.csv`, `.tsv`, `.json`, `.md` (Markdown pipe tables), `.txt`, `.pdf`, or `.docx` files. Tabular structures and field types (`number`, `text`, `boolean`, `date`, `currency`) are automatically detected and parsed.
  * **Public Web APIs (GET)**: Ingest JSON endpoints or HTML tables directly from HTTP URLs. Data is fetched on demand and maintained in read-only mode for safety.
  * **System Clipboard**: Paste tables directly with `Ctrl+V` or the clipboard button. Automatically extracts markdown tables, delimited text, or JSON structures. Multimodal support handles clipboard images and dropped files.
* **Persistent Data Models & Bundles**:
  * Schemas are modeled as YAML definitions (`$name_mdl.yaml`) and data rows are saved as JSON (`$name.json`) in `SharedPreferences`.
  * **Export / Import Bundles**: Export complete dynamic dataset bundles (`.agrid.yaml`) containing both the column metadata model and dataset rows. Easily import bundles across devices.
  * **In-Place DevExtreme Write-Back**: Edits made in cell, row, or modal form modes are automatically committed back to `SharedPreferences` storage.
* **6 Built-in Dynamic MCP Tools**:
  * `grid_create_dynamic_datasource`: Creates, validates, and activates a dynamic dataset from structured rows or inferred columns.
  * `grid_list_datasources`: Lists all saved dynamic datasets, row counts, origins, and active status.
  * `grid_load_datasource`: Switches the active DataGrid view to any stored dataset.
  * `grid_delete_datasource`: Deletes a saved dynamic dataset and its associated YAML model.
  * `grid_fetch_web_data`: Fetches, previews, and inspects web data before ingestion.
  * `grid_export_datasource_yaml`: Exports the active or specified dataset as a portable YAML bundle string.
* **Generic Columns Editor Dialogs**:
  * **Full-Table Columns Editor (`AiGridColumnsEditorDialog`)**: Self-hosting, nested `AiGrid` dialog for modifying all columns in the active table. Modify column captions, data types (`number`, `text`, `date`, `datetime`), editable permissions, required validation flags, widths, max widths, editor types, and reorder or delete columns.
  * **Single Column Editor (`AiGridColumnEditorDialog`)**: Quick per-column editor accessible via header context menus for fast schema adjustments.
  * Changes immediately update the live grid and persist back to storage YAML models.
* **Read-Only Datatable Protection & Editor Suppression**:
  * Tables fetched from web endpoints or loaded with `isReadonly: true` strictly enforce read-only semantics.
  * **Actions Column Suppressed**: The pinned `__actions__` column containing edit pencil, delete trash, and check/cancel buttons is hidden.
  * **Toolbar Controls Suppressed**: The `+` (Add Record) and Columns Editor buttons are hidden from the toolbar.
  * **Inline Edit Triggers Blocked**: In-cell and double-click row edit triggers are locked, preventing editing states from activating.
  * **CRUD Operations Guarded**: Invocations to `startEdit`, `startAdd`, `showEditDialog`, `saveEdit`, and `deleteRow` safely early-exit.
* **Option C: Hybrid Composable Architecture**:
  * Keeps `ai_grid` core lightweight with zero native FFI dependencies for full `dart2wasm` safety.
  * Provides a pluggable `assistantBuilder` slot on `AiGrid` for developers who want to drop in external AI chat interfaces such as `FlutterUiMcp` or `McpPlayground`.
* **Runnable Example**: See [`example/lib/dynamic_ai_grid_example.dart`](./example/lib/dynamic_ai_grid_example.dart).

### 7. 📋 Copy-to-Clipboard in AI Assistant
* **Prompt Bubbles**: 1-tap copy button on every user message bubble.
* **AI Responses**: Copy button in the header of each assistant response card to copy the full AI response and execution summary directly to the system clipboard.

### 8. 📱 Responsive Desktop & Mobile Layouts
* **Desktop Mode (≥ 620px)**:
  * Floatable, moveable, and resizable AI Assistant window powered by [`draggable_overlay_window`](https://pub.dev/packages/draggable_overlay_window).
  * 8-directional edge/corner resizing, drag-by-header, minimize, maximize, and smooth focus management.
* **Mobile Mode (< 620px)**:
  * Dynamic, non-overflowing toolbar with action menus collapsed into a sleek `PopupMenuButton` dropdown.
  * Auto-flexing search bar that adapts to any screen width without pixel overflows.
  * Instant 1-tap Mode Switcher tab bar (`[ 📊 Data Grid ]` | `[ ✨ AI Assistant ]`).
  * Full-screen mobile assistant view with quick `[← Back to Data Grid]` navigation.

### 9. ↔️ Interactive Column Resizing & Width Policies
* **Drag-to-Resize**: Hovering between column headers reveals draggable divider handles to interactively adjust column widths.
* **Auto-Fit on Double-Click**: Double-clicking any column divider handle or choosing "Size to fit" in the column menu auto-fits the column to its actual cell content.
* **Flexible Sizing Policies**: Configure `columnWidth` with any policy from [fitgrid_table](https://pub.dev/packages/fitgrid_table#column-widths):
  * `FitGridColumnWidth.auto(min: 80, max: 300)` — dynamic content-based measurement.
  * `FitGridColumnWidth.fixed(120)` — pinned exact pixel width.
  * `FitGridColumnWidth.flex(1, min: 140)` — proportional flex share of remaining grid width.
  * `FitGridColumnWidth.fitHeader(min: 44)` — sized strictly to the header label.
* **Layout Persistence**: Custom column widths automatically persist across app restarts when `autoSave: true` is enabled.

### 10. 📤 Fast & Pure-Dart Excel (.xlsx) Export
* One-click **Export to Excel** directly accessible via the toolbar download button, mobile menu, or natural language AI command (`export`):
  * **Native Save As Dialog**: Opens the platform's native "Save As..." dialog (`FileSaver.instance.saveAs`) allowing the user to select the destination folder and filename across Web, Desktop (Windows, macOS, Linux), and Mobile (Android, iOS).
  * **Pure-Dart Excel Engine**: Generates `.xlsx` workbooks directly in Dart with zero C/C++ native dependencies or platform channels.
  * **Direct Programmatic API**: Trigger export programmatically anytime via `controller.export()`.

### 11. 📄 Pagination & Partial Data Load (Client-Side & Server-Side)
* **Client-Side Pagination**: Simple opt-in via `enablePagination: true` and `pageSize: 25`, rendering an interactive page-navigation footer with total row counts and page controls.
* **Server-Side Partial Data Load (`LazyAiGridDataSource`)**:
  * Only requests and loads the slice of records for the active page from your backend or REST/GraphQL API.
  * Dynamically passes current page, page size, active column sorting, and active filter criteria to your `fetch` callback.

### 12. 🌐 WebAssembly (WASM) Compatible
* Fully verified with Flutter WebAssembly (`dart2wasm`).
* Zero direct dependencies on legacy `dart:html`.
* Native filesystem operations are cleanly isolated behind conditional imports, ensuring zero runtime or compile-time breakages in browser WASM environments.

### 13. 🎨 Modern Adaptive Theming
* Harmonious styling that automatically reflects the parent application's Material 3 `ThemeData` across Light and Dark modes.

---

## 🛠️ MCP Tool Reference

`ai_grid` exposes 27 specialized MCP tools through `AiGridSkill`:

| Tool Name | Description |
| :--- | :--- |
| `grid_get_schema` | Returns column field names, titles, types, and capability flags. |
| `grid_get_state` | Returns active grouping, active filters, sorting, search query, row count, and visibility. |
| `grid_get_sample_data` | Retrieves real sample rows (1–10 rows) for contextual reasoning. |
| `grid_calculate` | **Calculates exact metrics** (sum, average, min, max, count, median) in Dart without LLM math errors. |
| `grid_set_filter` | Applies single or multi-column filters joined by AND, including negative operators. |
| `grid_clear_filters` | Clears all or specified column filters. |
| `grid_sort` | Applies single or multi-column sorting with ascending/descending directions. |
| `grid_group` | Sets hierarchical row grouping fields. |
| `grid_set_column_visibility` | Shows or hides specific columns. |
| `grid_search` | Applies global tabular text search. |
| `export` | **Exports table data to Excel (.xlsx)** using FitGrid and opens the native Save As... dialog to select output directory and filename. Works on Web, Desktop, and Mobile. |
| `grid_export` | Exports grid data to XLSX, CSV, TSV, or JSON and downloads/saves the file. |
| `grid_go_to_page` | Navigates pagination to a specific page or relative direction ("next", "previous", "first", "last"). |
| `grid_get_pagination_status` | Returns active pagination status (current page, total pages, page size, isPaginated). |
| `grid_export_settings` | Exports current grid settings (visible columns, grouping, sorts, filters) as a JSON string. |
| `grid_restore_settings` | Restores grid settings from a JSON string or settings object. |
| `grid_create_pivot_table` | Transforms the table into an aggregated Pivot Table on the fly with optional side-by-side Chart. |
| `grid_reset_pivot_table` | Deactivates pivot mode and restores the standard grid view, columns, and groupings. |
| `grid_create_dynamic_datasource` | Creates, persists, and activates a dynamic DataGrid dataset from structured rows or inferred columns. |
| `grid_list_datasources` | Lists all saved dynamic datasets, their row counts, origins, and active status. |
| `grid_load_datasource` | Loads a saved dynamic DataGrid dataset by name into the interactive grid. |
| `grid_delete_datasource` | Deletes a dynamic dataset and its associated YAML model from storage. |
| `grid_fetch_web_data` | Fetches, inspects, and previews tabular data from a public HTTP GET URL. |
| `grid_export_datasource_yaml` | Exports a dynamic dataset package (model and data rows) as a YAML formatted string. |
| `grid_set_conditional_format` | Applies conditional formatting (data bars, color scales, or highlight rules) to a column or row. |
| `grid_clear_conditional_formats` | Clears active conditional formatting rules for a column or the entire grid. |
| `grid_reset` | Resets grouping, filters, sorting, search, and restores all column visibility. |

---

## 🚀 Getting Started

### Installation

Add `ai_grid` to your `pubspec.yaml`:

```yaml
dependencies:
  ai_grid: ^0.4.0
  material_ui: ^1.4.0
```

*(Note for local development: If using local checkouts, path dependencies can be specified via dependency overrides).*

### Basic Usage

```dart
import 'package:flutter/material.dart';
import 'package:ai_grid/ai_grid.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: const SalesGridPage(),
    );
  }
}

class SalesGridPage extends StatefulWidget {
  const SalesGridPage({super.key});

  @override
  State<SalesGridPage> createState() => _SalesGridPageState();
}

class _SalesGridPageState extends State<SalesGridPage> {
  late final AiGridController _controller;
  late final LocalAiGridDataSource _dataSource;

  @override
  void initState() {
    super.initState();
    _controller = AiGridController();
    _controller.editingOptions = const AiGridEditingOptions(
      enabled: true,
      mode: AiGridEditMode.row, // .cell, .row, or .form
      allowAdding: true,
      allowUpdating: true,
      allowDeleting: true,
    );

    final columns = [
      const AiGridColumn(
        field: 'orderId',
        title: 'Order ID',
        type: AiGridColumnType.text,
        aggregateType: AiGridAggregateType.count,
        editable: true,
        width: 140,
      ),
      const AiGridColumn(
        field: 'customer',
        title: 'Customer Name',
        type: AiGridColumnType.text,
        editable: true,
        width: 180,
      ),
      const AiGridColumn(
        field: 'category',
        title: 'Category',
        type: AiGridColumnType.select,
        selectOptions: ['Furniture', 'Technology', 'Office Supplies'],
        editable: true,
        width: 140,
      ),
      const AiGridColumn(
        field: 'sales',
        title: 'Sales Amount',
        type: AiGridColumnType.currency,
        aggregateType: AiGridAggregateType.sum,
        editable: false,
        width: 140,
      ),
    ];

    final sampleData = [
      {'orderId': 'ORD-001', 'customer': 'Claire Gute', 'category': 'Furniture', 'sales': 261.96},
      {'orderId': 'ORD-002', 'customer': 'Brosina Hoffman', 'category': 'Technology', 'sales': 731.94},
      {'orderId': 'ORD-003', 'customer': 'Darrin Van Huff', 'category': 'Office Supplies', 'sales': 14.62},
    ];

    _dataSource = LocalAiGridDataSource(
      initialData: sampleData,
      columns: columns,
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
      appBar: AppBar(title: const Text('Enterprise Sales Data')),
      body: AiGrid(
        dataSource: _dataSource,
        controller: _controller,
        enableAiAssistant: true,
      ),
    );
  }
}
```

---

## 🤖 Configuring the AI Assistant

Configure any LLM provider via `.env` or in code:

```dart
// Option 1: Load from .env
final config = await AiGridConfig.fromEnv();

// Option 2: Programmatic configuration
final config = AiGridConfig(
  llmConfig: LlmConfig(
    provider: LlmProvider.mistral, // or openai, anthropic, gemini, ollama
    apiKey: 'your_api_key_here',
    model: 'mistral-large-latest',
  ),
);

AiGrid(
  dataSource: dataSource,
  aiConfig: config,
);
```

### Supported `.env` Variables

Create a `.env` file in the root of your application or asset bundle:

```ini
# Provider: mistral | openai | anthropic (or claude) | gemini | ollama | openai_compatible
LLM_PROVIDER=mistral

# Model identifier
LLM_MODEL=mistral-medium-latest

# API Authentication Key (Optional for local Ollama / LM Studio)
LLM_API_KEY=your_api_key_here

# Base URL (Required for openai_compatible, custom proxy, or Ollama)
LLM_URL=https://api.mistral.ai/v1
```

#### Provider Configuration Examples

##### 1. Mistral AI
```ini
LLM_PROVIDER=mistral
LLM_MODEL=mistral-medium-latest
LLM_API_KEY=your_mistral_api_key
LLM_URL=https://api.mistral.ai/v1
```

##### 2. OpenAI
```ini
LLM_PROVIDER=openai
LLM_MODEL=gpt-4o-mini
LLM_API_KEY=sk-...
```

##### 3. Anthropic Claude
```ini
LLM_PROVIDER=anthropic
LLM_MODEL=claude-3-5-sonnet-20241022
LLM_API_KEY=sk-ant-...
```

##### 4. Google Gemini
```ini
LLM_PROVIDER=gemini
LLM_MODEL=gemini-1.5-flash
LLM_API_KEY=AIzaSy...
```

##### 5. Ollama (Local on localhost:11434)
```ini
LLM_PROVIDER=ollama
LLM_MODEL=llama3.1
LLM_URL=http://localhost:11434
```

##### 6. Custom OpenAI-Compatible (OpenRouter, Groq, Together, LM Studio, vLLM)
```ini
LLM_PROVIDER=openai_compatible
LLM_MODEL=meta-llama/llama-3.1-70b-instruct
LLM_API_KEY=your_custom_key_or_empty
LLM_URL=https://openrouter.ai/api/v1
```

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
