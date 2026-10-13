# Changelog

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
