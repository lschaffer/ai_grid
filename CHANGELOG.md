# Changelog

## 0.4.0

Dynamic AI DataGrid with multi-source tabular ingestion (files, public HTTP GET APIs, and system clipboard), persistent YAML/JSON data models, portable bundle export/import, DevExtreme editing write-back, Option C Hybrid Composable Architecture, and 6 new Model Context Protocol (MCP) tools.

### 🌐 Dynamic AI DataGrid from Files, Web GET & System Clipboard
* **Multi-Source File Ingestion**:
  * Native file picker integration supporting `.csv`, `.tsv`, `.json`, `.md` (Markdown pipe tables), `.txt`, `.pdf`, and `.docx`.
  * Pure-Dart delimited parser (`DelimitedTableParser`) with automatic delimiter detection (comma, tab, semicolon) and heuristic data type inference (`number`, `currency`, `boolean`, `date`, `text`).
  * Pure-Dart markdown pipe table extractor (`MarkdownTableExtractor`) extracting tables, headers, and cell values.
* **Public Web APIs (HTTP GET)**:
  * Ingest public JSON array endpoints or HTML table tags directly via `AiGridWebDataSourceDialog` and `WebTableFetcher`.
  * Public web endpoints are automatically designated `isReadonly: true` for safe, read-only inspection.
* **System Clipboard Ingestion & Multimodal Support**:
  * `ClipboardContentService` with desktop PowerShell bitmap inspection, file drop detection, and pure-Dart text parsing fallback.
  * Ingest tabular markdown, CSV, or JSON directly from the clipboard via keyboard shortcut (`Ctrl+V`) or toolbar action.
* **Data Model & Persistence Architecture**:
  * Model schema definition: `$name_mdl.yaml` (`AiGridDynamicModel`).
  * Data rows: `$name.json`.
  * `AiGridDynamicStorage`: Complete persistence manager leveraging `SharedPreferences` with in-memory caching and active datasource registry tracking.
  * **Portable Bundles (`.agrid.yaml`)**: Export and import complete bundles combining model schemas and dataset rows across desktop, web, and mobile.
* **DevExtreme Editing Write-Back**:
  * In-place cell, row, and modal form edits automatically write back and persist directly to `SharedPreferences` for non-readonly datasources.
* **Option C: Hybrid Composable Architecture**:
  * Zero-bloat core with lean embedded assistant panel and zero native FFI dependencies for full Flutter WebAssembly (`dart2wasm`) safety.
  * Pluggable `assistantBuilder` parameter on `AiGrid` allowing developers to drop in external AI chat interfaces such as `FlutterUiMcp` or `McpPlayground`.
* **6 New Dynamic MCP Tools (`AiGridSkill`)**:
  * `grid_create_dynamic_datasource`: Creates, validates, persists, and activates a dynamic dataset.
  * `grid_list_datasources`: Lists all saved dynamic datasets, their row counts, origins, and active status.
  * `grid_load_datasource`: Loads a stored dynamic DataGrid dataset by name into the interactive grid.
  * `grid_delete_datasource`: Deletes a saved dynamic dataset and its associated YAML model.
  * `grid_fetch_web_data`: Fetches, inspects, and previews tabular data from a public HTTP GET URL.
  * `grid_export_datasource_yaml`: Exports a dynamic dataset package (model and data rows) as a YAML formatted string.
* **Columns Editor Dialogs (`AiGridColumnEditorDialog` & `AiGridColumnsEditorDialog`)**:
  * **Generic Full-Table Columns Editor (`AiGridColumnsEditorDialog`)**: Self-hosting nested `AiGrid` modal table for managing all column schemas: edit caption, data type (`number`, `text`, `date`, `datetime`), editable flag, required validation, default width, max width, editor type, and column reordering / deletion.
  * **Single Column Editor (`AiGridColumnEditorDialog`)**: Quick per-column editor dialog accessible from column header context menus.
  * Synchronized persistence: updates column definitions in the controller, reconfigures active FitGrid columns, and writes back schema modifications to the YAML model in `SharedPreferences`.
* **Read-Only Mode & Complete Editor Control Suppression**:
  * Datasets marked `isReadonly: true` (including all web endpoints fetched via HTTP GET) completely suppress editing capabilities.
  * **Actions Column Hidden**: The pinned `__actions__` column (edit pencil, delete trash, check/cross save buttons) is completely removed from the table.
  * **Toolbar Controls Suppressed**: The `+` (Add Record) and Columns Editor buttons are hidden from the toolbar.
  * **Double-Click & In-Cell Editing Blocked**: Row double-tap triggers and cell editing triggers are locked to programmatic-only, preventing edit modes from engaging.
  * **Controller Guards**: Programmatic edit and delete calls (`startEdit`, `startAdd`, `showEditDialog`, `saveEdit`, `deleteRow`) are safely rejected with early exits.
* **FitGrid Double-Click Row Edit Stabilization**:
  * Synced latest upstream FitGrid engine fixes to eliminate row collapse and erroneous edit state transitions when double-clicking table rows.
* **Adaptive Toolbar & Viewport Resilience**:
  * Replaced fixed search box widths with flexible `Expanded` + `ConstrainedBox(maxWidth: 220)` alignment to prevent horizontal `RenderFlex` overflows on compact viewports.
  * Truncated datasource titles in the toolbar button to cleanly accommodate long web URLs.
* **Datasource UI Dialogs & Toolbars**:
  * `AiGridDatasourceManagerDialog`: Visual manager modal with search, active datasource badge, YAML export/import, delete with confirmation, and one-click loading.
  * `AiGridWebDataSourceDialog`: Inspect and load public web endpoints.
  * Dynamic toolbar buttons: "Datasources" manager button, "+ New Datasource" popup menu, and "Columns Editor" button.
* **Runnable Example**:
  * Added `example/lib/dynamic_ai_grid_example.dart` demonstrating pre-seeded tech companies dataset, switching datasources, and DevExtreme editing write-back.

## 0.3.0

On-the-fly DevExtreme-Style Pivot Grid with interactive Field Chooser, banded split column headers, hierarchical row grouping, moveable split-panel canvas chart, and natural language AI Assistant tools.

### DevExtreme-Style Dynamic Pivot Grid & Side-by-Side Chart
* **Pivot Table Field Chooser Dialog (`AiGridPivotChooserDialog`)**:
  * DevExtreme-inspired modal dialog featuring available fields list and drag/add drop zones for **Row Fields**, **Column Fields**, and **Data (Measures)**.
  * Smart column classification heuristic distinguishing authentic measures (`Sales`, `Quantity`, `Profit`), dimensions (`Category`, `Region`), and identifiers (`OrderID`, `PostalCode`).
  * Per-measure aggregation selection: `sum`, `average`, `count`, `min`, and `max`.
  * Quick DevExtreme presets for instant cross-tabulations (e.g. *Category &times; Region*, *Segment &times; Ship Mode*).
* **DevExtreme-Style Banded Split Column Headers (`FitGridColumnGroup`)**:
  * Native integration with FitGrid's column groups: parent column dimensions (e.g. `Consumer / Central` or `Grand Total`) span horizontally across their nested child measures (`Sales (Sum)`, `Discount (Average)`).
  * Ungrouped row dimension columns (`Order ID`, `Category`) automatically span the full double-height header vertically.
* **Hierarchical Tree Row Grouping (`groupByRows`)**:
  * Automatically sets tree-style multi-level row grouping across preceding row dimensions, enabling in-place collapsible drill-downs.
* **Interactive Side-by-Side Canvas Pivot Chart (`AiGridPivotChart`)**:
  * Real-time canvas visualization supporting `groupedBar`, `column`, `line`, and `pie` chart modes.
  * Smart Top-6 series and Top-10 categories data filtering to keep charts crisp, readable, and responsive on high-cardinality cross-tabulations.
  * Constrained, scrollable legend with `+N more in table` indicators to prevent flex overflows.
* **Moveable Split Panel Divider**:
  * Interactive draggable splitter divider between the grid and chart with 1:1 absolute mouse tracking and theme-highlighted hover/drag visual feedback.
  * Responsive split: horizontal side-by-side on desktop (`>= 720px`) and vertical stacked on smaller viewports.
* **Clean Empty Cell Formatting**:
  * Muted em-dash (`—`) for empty matrix cross-tabulation intersections with `#,#00.##` numeric formatting.
* **AI Assistant & MCP Pivot Tools**:
  * `grid_create_pivot_table`: Transforms the table into an aggregated Pivot Table on the fly from natural language prompts.
  * `grid_reset_pivot_table`: Instantly deactivates pivot mode and restores the original table, columns, and groupings.

## 0.2.0

Comprehensive DevExtreme-style DataGrid Editing support across cell, row, and modal form modes with full CRUD lifecycle validation and action column orchestration.

### DevExtreme-Style DataGrid Editing
* **Three Editing Modes (`AiGridEditMode`)**:
  * `cell`: Default direct in-cell editing.
  * `row`: Inline row editing with committed draft states and standard Material action icons (`check` to save, `close` to cancel, `edit_outlined` to edit, `delete_outline` to delete).
  * `form`: Modal Material 3 popup dialog editing all editable fields in a structured layout.
* **Pinned Action Column (`AiGridActionColumnPosition`)**:
  * Pinned to `start` (`left`) or `end` (`right`) of the grid.
  * Compact, overflow-free action buttons with tooltips for editing, deleting, saving, and cancelling.
* **Modal Popup Form (`AiGridFormDialog`)**:
  * Flexible layout engine (`AiGridFormLayout`) supporting:
    * `row`: Vertical scrollable list with one field per row.
    * `wrap`: Adaptive horizontal flow wrapping left-to-right.
    * `grid`: Multi-column grid layout (e.g. 2, 3, or 4 columns).
    * `custom`: Fully custom widget builder (`formBuilder`).
  * Field ordering based on column `editorIndex`.
  * Standard Material form controls: text input, numeric input, currency with customizable prefix, date/dateTime pickers, dropdown selects, and toggle switches.
* **Column-Level Editing Specifications (`AiGridColumn`)**:
  * `editable`: Explicitly enable or disable editing per column.
  * `editorIndex`: Sort order of the column's field in the edit form.
  * `editorType`: Explicit control type (`text`, `number`, `currency`, `date`, `dateTime`, `select`, `boolean`).
  * `editorOptions`: Options map for placeholders, prefixes, and dropdown items.
  * `validator`: Custom validator callback returning an error string or null.
  * `editorBuilder`: Completely custom in-place editor builder for inline cells or form fields.
* **CRUD Lifecycle & Validation Pipeline**:
  * `required`: Built-in mandatory field validation with inline error borders and error tooltips.
  * `validator`: Custom column-level validation rules with dynamic error messages.
  * **Vertical Validation Errors Dialog**: Clicking save with errors displays a clean, vertical modal popup dialog summarizing all field errors with field titles and error reasons.
  * **Delete Confirmation Dialog**: Material confirmation dialog prior to deleting rows (`beforeDelete`).
  * `commit`: Per-field persistence callback for committing values to backend or state.
  * `afterSave`: Callback invoked on successful row update or add.
  * `afterDelete`: Callback invoked after row deletion.
* **DevExtreme-Style In-Place Row Editing**:
  * Full-cell editor integration without row gaps, seamless border indicators, and blinking cursor on active inputs.
* **Toolbar Add Action**:
  * Integrated `+ Add` button in desktop and mobile toolbars when `allowAdding: true`.
  * Configurable new record insertion position (`top` or `bottom`).
  * Automatically routes to `showEditDialog` in `form` mode or `startAdd` in `row`/`cell` mode.

## 0.1.0

Initial feature-complete release of **AI Grid**: An intelligent, ultra-high-performance DataGrid for Flutter with native AI Assistant and Model Context Protocol (MCP) skill control.

### High-Performance Canvas Grid Engine
* **Direct Canvas Cell Painting**: Renders cells directly to the Flutter canvas with ~3ms frame times on up to 1,000,000 rows.
* **Full 2D Virtualization**: Handles large datasets smoothly with minimal memory footprint across Desktop, Web, and Mobile.
* **WebAssembly (WASM) Ready**: Fully compatible with `dart2wasm` and modern Flutter web compilation.
* **`material_ui` Ecosystem Compatibility**: Native compatibility with `package:material_ui` for unbundled Flutter 3.47+ environments.

### Native AI Assistant & Model Context Protocol (MCP)
* **Model Context Protocol (MCP) Integration**: Built directly on [dart_mcp_core](https://pub.dev/packages/dart_mcp_core) to expose real-time tabular introspection and control tools to LLMs.
* **13 Interactive MCP Tools**: Includes tools for schema inspection, state retrieval, multi-column filtering, multi-level sorting, grouping, column visibility, calculations, exports, and layout persistence.
* **Hallucination-Free Math Engine (`grid_calculate`)**: In-grid calculations for sums, averages, medians, minimums, maximums, and counts executed directly in Dart rather than LLM mental math.
* **Responsive Assistant UI**:
  * **Desktop**: Moveable, resizable, and floatable draggable overlay window (`draggable_overlay_window`).
  * **Mobile**: Full-screen bottom-sheet assistant with responsive tab switching and overflow-free toolbars.
  * **Copy Actions**: Quick 1-click clipboard copy for user prompts and assistant responses.

### Advanced Filtering & Search
* **Inline Column Filter Row**: Quick-filter inputs under column headers supporting text and numeric prefix syntax (`>`, `>=`, `<`, `<=`, `!=`, `=`, `..` ranges).
* **Multi-Value "OR" & Checklist Filters**: Supports multi-value match (`inList`), comma/pipe-separated inputs, and natural queries (e.g. `in: New York, Denver` or `New York or Denver`).
* **Multi-Column Filtering**: Applies multiple column filters simultaneously joined with AND logic.
* **Negative Filtering**: Built-in support for `not equals` and `does not contain` conditions.
* **Global Search Panel**: Real-time cross-column full-text search with match highlighting.

### Multi-Level Grouping & Aggregations
* **Interactive Drag-to-Group**: Drag column headers directly into the group panel to establish multi-level hierarchical grouping.
* **Tree View Groups**: Collapsible group rows with group item counts and custom formatting.
* **Aggregate Footers**: Built-in footer summaries displaying column metrics (Sum, Average, Min, Max, Count) with number formatting.

### Interactive Column Management
* **Interactive Column Resizing**: Draggable column header divider handles allow users to interactively resize column widths.
* **Auto-Fit on Double Click**: Double-clicking any column divider handle automatically measures and sizes the column to fit cell contents.
* **Flexible Sizing Policies**: Supports `auto`, `fixed`, `flex`, and `fitHeader` column sizing with custom `min` and `max` constraints.
* **Column Header Menus**: 3-dots column menus on every header offering sort ascending/descending, filter dialogs, freeze/pin to start or end, auto-fit width, and one-click grouping.
* **Column Visibility**: Show or hide individual columns, or isolate specific columns (`showOnly: [...]`).

### Pure-Dart Excel (XLSX) & Data Export
* **Native Excel Export**: Pure-Dart `.xlsx` spreadsheet export engine with zero native platform dependencies.
* **Native Platform "Save As..." Integration**: Triggers platform-native directory selection and filename prompt (`file_saver`) across Web, Desktop (Windows, macOS, Linux), and Mobile (Android, iOS).
* **CSV & JSON Export**: Flattened tabular export options for Excel, Pandas, and BI tooling.

### Layout Persistence & Settings Presets
* **State Persistence**: Complete export and restore of grid configurations (group columns, sorting, filters, visible columns, and column widths) to/from JSON.
* **Automatic Layout Restoration (`autoSave`)**: Automatically saves and restores user layout preferences across app restarts using `SharedPreferences`.

### Scroll & Theme Polish
* **Dual-Axis Draggable Scrollbars**: Synchronized, visible, and interactive horizontal and vertical scrollbars.
* **Theme Adaptation**: Automatic adaptation to ambient light and dark application themes.
