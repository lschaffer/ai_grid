# Changelog

## 0.9.0

Master-Detail Child Rows & Nested DataGrids, Accordion Mode (`autoCollapseOthers`), Expand/Collapse Programmatic API, 4 New MCP Tools, and Showcase Gallery Demo.

### 📑 Feature 3: Master-Detail Child Rows & Nested Grids
* **Master-Detail Configuration (`AiGridMasterDetailOptions`)**:
  * Pinned leading chevron expansion column automatically managed by `FitGrid`.
  * Fully virtualized full-width detail slot (`detailBuilder`) mounting real widgets including nested child `AiGrid` instances, delivery tracking timelines, or tabbed customer profiles.
  * Configurable panel height (`detailRowHeight` and per-row `detailHeight`).
  * Custom row key resolver (`rowKey`) maintaining open panels across sort, search, and filter passes.
  * Built-in **Accordion Mode (`autoCollapseOthers`)**: Expanding a row automatically collapses previously open rows.
  * Initial expansion support (`initiallyExpandedKeys`).
  * Expansion state change callback (`onExpansionChanged`).
* **Controller Operations**:
  * `expandRow(key)` / `expandRowAt(index)`.
  * `collapseRow(key)` / `collapseRowAt(index)`.
  * `toggleRowDetail(key)` / `toggleRowDetailAt(index)`.
  * `expandAllDetails()` / `collapseAllDetails()`.
  * `isRowExpanded(key)`, `isRowExpandedAt(index)`, `expandedDetailKeys`, `hasExpandedDetails`, `expandedDetailCount`.
* **4 New Model Context Protocol (MCP) Tools (`AiGridSkill`)**:
  * `grid_toggle_row_detail`: Expands, collapses, or toggles child row detail by row key or view index.
  * `grid_expand_all_details`: Expands all rows in the active view (unless accordion mode is active).
  * `grid_collapse_all_details`: Collapses all currently expanded row details.
  * `grid_get_detail_status`: Returns current master-detail configuration and list of expanded row keys.
* **Showcase Gallery Demo (`MasterDetailExamplePage`)**:
  * Enterprise Superstore Orders with 3-tab expandable child panels:
    * **Child Items Grid**: Full nested `AiGrid` with canvas virtualization, auto-sized columns, and summary footers.
    * **Shipping & Delivery**: Visual 5-step delivery tracker with carrier tracking numbers and clipboard copy.
  * Accordion mode switcher, live expanded counter, and detail height segmented buttons.

### 📱 Mobile UI & Ergonomics Enhancements
* **Fullscreen Mobile Dialogs (`Dialog.fullscreen`)**:
  * `AiGridFormDialog`: Automatically presents full-screen on mobile devices (`width < 600`) with top AppBar and full-height scrollable form.
  * `AiGridDatasourceManagerDialog` & `AiGridWebDataSourceDialog`: Fullscreen dialogs with native responsive layout on mobile screens.
  * Superstore editing event log & JSON restore settings dialogs adapt to fullscreen on mobile.
* **Single-Field-Per-Row Form Editing**:
  * Form editing dialog automatically enforces single-column layout (`AiGridFormLayoutMode.row`) on mobile screens to prevent multi-column squishing.
  * Dropdown selectors expanded (`isExpanded: true`) with text ellipsis truncation.
  * Compact constraints (32x32) on clear and date picker actions to eliminate suffix icon row overflows.
* **Mobile Menu Dropdown (`:menu`)**:
  * Collapses horizontal action buttons into a consolidated `PopupMenuButton` on mobile viewports to prevent AppBar overflow.
* **Collapsible Showcase Headers**:
  * Showcase headers for Master-Detail, Range Selection, and AI Smart Columns are collapsible via tap or chevron toggle, maximizing vertical canvas space on small screens.
  * Detail panel sub-headers (`TabBar`) wrap safely in `Expanded` to prevent horizontal overflows.

## 0.8.0

Enhanced Scrollbar Interaction Isolation, Non-Displacing Selection Status Bar, Dependency Updates (`material_ui: ^1.8.0`, `dart_mcp_core: ^1.4.0`), and Showcase UI Ergonomics.

### 🛡️ Scrollbar Hit-Testing & Gesture Isolation
* **Zero Collision with Scrollbar**: Wrapped `Scrollbar` around cell gestures and added boundary checks (`_isOverScrollbar`) in `FitGrid`. Dragging or clicking horizontal or vertical scrollbar thumbs no longer triggers cell selections, range dragging, or inline edit mode.
* **Non-Displacing Selection Status Bar**: When `showSelectionStatusBar` is enabled, the status bar now maintains a fixed 28px height with a subtle `'Ready'` idle indicator, completely preventing the grid viewport from jumping upwards upon selecting multiple cells.
* **Safe Default Behavior**: `cellSelection` and `showSelectionStatusBar` default to `false` in `AiGrid`, ensuring standard table usage remains lightweight and row-focused.
* **Refined Showcase Examples**: Disabled inline cell editing across feature showcase grids (`Smart Columns`, `Conditional Formatting`, `Range Selection`) for a cleaner demonstration experience.
* **Dependency Updates**: Upgraded to `material_ui: ^1.8.0` and `dart_mcp_core: ^1.4.0`.

## 0.7.0

AI Smart / Prompt Columns (LLM-synthesized columns, per-row prompt interpolation, high-speed batch evaluation via `McpAgentEngine`, intelligent local heuristic fallback, inline sparkle indicators, interactive per-cell generation buttons), 2 new Model Context Protocol (MCP) tools, and dedicated showcase gallery demo.

### ✨ AI Smart / Prompt Columns
* **LLM-Synthesized Columns (`AiGridSmartColumn`)**:
  * Evaluates dynamic column values on-demand using any configured LLM (OpenAI, Gemini, Claude, Mistral, Ollama) or offline heuristic rules.
  * Formatted with `{fieldName}` variable interpolation (e.g. `"Classify customer sentiment of '{notes}'"`).
  * Optional discrete categorical `options` constraint (`['Positive', 'Neutral', 'Negative']`).
  * Custom `localEvaluator` callback hook for client-side evaluation pipelines.
* **Batch Evaluation Engine (`AiGridSmartColumnRunner`)**:
  * Evaluates multi-row chunks asynchronously via `McpAgentEngine`.
  * Built-in intelligent local heuristic fallback for sentiment analysis, urgency rating, ticket categorization, and next action recommendations when offline.
* **Inline Cell Visuals & Sparkle Indicators**:
  * Real-time generating state with animated spinner and shimmering `"Synthesizing..."` label.
  * Generated state with purple sparkle badge (`Icons.auto_awesome`), tooltip showing source prompt, and custom styling.
  * Idle / empty state with interactive `✨ Generate` button allowing per-cell generation on click.
* **Controller Orchestration & Introspection**:
  * `controller.addSmartColumn(column, {autoRun: true})`.
  * `controller.runSmartColumns({force: false, field})`.
  * `controller.runSmartColumnForCell(rowIndex, field)`.
  * `controller.clearSmartColumnValues(field)`.
  * `controller.isGeneratingSmartColumns`, `controller.smartColumns`, `controller.isSmartColumn(field)`, `controller.getSmartCellStatus(field, rowIndex)`.
* **2 New MCP Tools (`AiGridSkill`)**:
  * `grid_add_smart_column`: Adds or registers a prompt-driven smart column via natural language.
  * `grid_run_smart_columns`: Triggers batch synthesis across all rows or a targeted smart column.
* **Showcase Demo (`example/lib/examples/smart_columns_example.dart`)**:
  * Customer support tickets dataset demonstrating 3 preconfigured smart columns: AI Sentiment, AI Urgency, and AI Recommended Action.
  * Toolbar buttons for running all columns, adding custom prompt columns, clearing values, and preconfigured contextual prompt suggestions.


Cell Range Selection, bidirectional spreadsheet clipboard interoperability (`Ctrl+C` TSV export / `Ctrl+V` paste), real-time Excel-style Selection Status Bar, summary statistics model, 2 new Model Context Protocol (MCP) tools, and interactive showcase demo.

### 📋 Cell Range Selection & Bidirectional Spreadsheet Copy/Paste
* **Desktop-Grade Range Selection**:
  * Rectangular cell selection via mouse drag and keyboard navigation.
  * `Shift + Arrow` keys dynamically expand and contract active cell boundaries.
  * `Ctrl+C` (or Cmd+C) copies selected ranges directly into Tab-Separated Values (TSV), cleanly pasteable into Microsoft Excel, Google Sheets, and LibreOffice.
  * `Ctrl+V` (or Cmd+V) parses clipboard TSV matrices and batch-writes into editable columns starting at the selected anchor.
* **Excel-Style Selection Status Bar**:
  * Real-time metrics computed directly over the active selection: Cell Count, Row/Column Dimensions, Numeric Sum, Average (Mean), Min, and Max.
  * Docked cleanly at the footer of the DataGrid on desktop and mobile.
  * Quick-action copy button with toast notification.
* **Controller APIs & Introspection**:
  * `controller.selectCellRange(anchorRow, anchorColumn, extentRow, extentColumn)`.
  * `controller.selectCell(row, columnField)` & `controller.clearCellRangeSelection()`.
  * `controller.calculateSelectedRangeSummary()` returning `AiGridRangeSummary`.
  * `controller.copySelectedRangeToClipboard({includeHeaders: true})`.
* **2 New MCP Tools (`AiGridSkill`)**:
  * `grid_get_selected_range`: Inspects active selection coordinates, dimensions, and computed statistics.
  * `grid_select_range`: Programmatically selects rectangular cell ranges by row index and column fields.
* **Feature Showcase Demo (`example/lib/examples/range_selection_example.dart`)**:
  * Financial quarterly revenue matrix demonstrating multi-cell selection, in-cell editing, copy/paste shortcuts, and AI-driven range highlights.

## 0.5.0

In-grid Visual Analytics & Conditional Formatting (canvas-painted data bars, bidirectional profit bars, progress tracks, sparklines, and row highlights), dynamic format persistence, 2 new Model Context Protocol (MCP) tools, and the modular Example Showcase Gallery.

### 🎨 In-Grid Visual Analytics & Conditional Formatting
* **Direct Canvas Cell Painting**:
  * **Data Bars (`AiGridColumn.dataBar`)**: Horizontal data bars painted on canvas behind cell text with customizable positive and negative colors, minimums, maximums, and zero-line alignment.
  * **Progress Tracks (`AiGridColumn.progress`)**: Proportional progress tracks filled to a fraction between 0.0 and 1.0.
  * **In-Cell Sparklines (`AiGridColumnType.sparkline` & `AiGridColumn.sparkline`)**: High-performance mini line and area charts painted directly inside cells from row value arrays without widget overhead.
* **Declarative & Dynamic Conditional Formatting (`AiGridConditionalFormat`)**:
  * Rule-based highlighting supporting `>`, `<`, `>=`, `<=`, `==`, `!=`, `contains`, `between`, and custom predicates.
  * Cell-level and row-level background highlighting (`applyToRow: true`).
  * Custom text colors, font weights, and color scale / heatmap gradients.
* **Controller Orchestration & Layout Persistence**:
  * `controller.addConditionalFormat()`, `controller.removeConditionalFormat()`, `controller.clearConditionalFormats()`.
  * Preserved across grid serialization, JSON export/restore, and `autoSave: true`.
* **2 New MCP Tools (`AiGridSkill`)**:
  * `grid_set_conditional_format`: Enables AI assistants to apply data bars, color scales, or highlight rules via natural language.
  * `grid_clear_conditional_formats`: Clears active formatting rules for a column or the entire grid.
* **Modular Example Showcase Gallery (`example/lib/main.dart`)**:
  * Refactored example launcher featuring an interactive dropdown gallery switcher between Flagship Superstore Grid, Dynamic Ingestion Grid, and the new Conditional Formatting & Visuals Showcase, with architectural roadmap cards for upcoming features.

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
