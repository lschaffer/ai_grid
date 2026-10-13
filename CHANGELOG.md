## 0.0.3

* **Engine Migration to `fitgrid_table`**:
  * Migrated underlying grid engine to **[fitgrid_table](https://pub.dev/packages/fitgrid_table)**.
  * Direct canvas cell painting (~3ms frame time on 1M rows) instead of widget-per-cell virtualization.
  * Native content-based column auto-sizing (`autoSize`, `autoSizeAll`).
  * Built-in multi-column sorting with background isolate sorting support for large datasets.
* **Native Excel (XLSX) Export & `export` Tool**:
  * Added new MCP tool `export` triggered by natural prompts such as "export table", "export data", "export to excel", or "save table".
  * Prompts the user with the native platform "Save As..." dialog (`FileSaver.instance.saveAs`) to select output directory and filename across Web, Desktop (Windows, macOS, Linux), and Mobile (Android, iOS).
  * Direct pure-Dart Excel (`.xlsx`) export using FitGrid's native XLSX engine without native dependencies.
* **`material_ui` Ecosystem Compatibility**:
  * Migrated UI components to `package:material_ui/material_ui.dart` for seamless Flutter 3.47 unbundled environments.
* **Dual-Axis Horizontal & Vertical Scrollbars**:
  * Added dedicated horizontal `Scrollbar` bound to `_horizontalController` with axis-specific notification predicates alongside the vertical scrollbar.
  * Both horizontal and vertical scrollbars are now fully visible, interactive, and draggable across Windows, macOS, Linux, Web, and Mobile.
* **Interactive Column Header Menus & Drag-to-Group**:
  * Enabled 3-dots column menus (`showColumnMenu: true`) on all column headers offering sort ascending/descending, filter dialogs, freeze/pin to start or end, auto-fit column width, and one-click Group/Ungroup.
  * Unlocked 2D header dragging so columns can be dragged directly up into `AiGridGroupPanel` to group.
  * Added aggregate cell tooltips and fixed footer count number formatting.
* **Interactive Column Width Resizing & Sizing Policies**:
  * Enabled interactive draggable divider handles on column headers allowing users to resize column widths dynamically.
  * Double-clicking any column divider handle auto-fits the column to measured cell contents.
  * Added `AiGridColumn.columnWidth` supporting all **[FitGridColumnWidth](https://pub.dev/packages/fitgrid_table#column-widths)** policies (`auto`, `fixed`, `flex`, `fitHeader`) with custom `min` and `max` constraints.
  * Added `AiGridColumn.resizable` (defaults to `true`) and `maxWidth`.
  * Added programmatic controller methods: `setColumnWidth`, `autoSizeColumn`, `autoSizeAllColumns`, `columnWidths`, and `isColumnResized`.
  * Preserved initial column widths while keeping columns resizable, with full persistence in `exportSettings` and `restoreSettings`.
* **Pub.dev Ready**:
  * Eliminated all local path dependencies (`dart_mcp_core: ^1.1.4`).

## 0.0.2

* **Persistent Layout Storage Across App Restarts**:
  * Enhanced `AiGridSettingsStorage` with persistent `SharedPreferences` storage alongside memory caching.
  * Settings now reliably persist across process termination and app restarts on Desktop, Mobile, and Web.
* **Auto-Save Restoration & Startup Protection**:
  * Prevented initial unconfigured grid state from overwriting saved user layout settings during `onLoaded`.
  * Added bidirectional synchronization between `AiGridController.activeGrouping` and `TrinaGrid` row group delegate, ensuring drag-and-drop grouping in the UI immediately persists.
* **Row Grouping Stability**:
  * Fixed scheduler callback assertion failure (`hasRowGroups: is not true`) when clearing grouping or restoring settings with empty `groupColumns`.
* **AI Assistant UI Refinements**:
  * Removed unimplemented microphone icon from AI chat input row.
* **Environment Configuration & Security**:
  * Added `.env.example` templates and updated `.gitignore` rules for environment secrets.
* **Documentation & Previews**:
  * Added screenshot showcase (`example_1.png`) to README.

## 0.0.1

* Added Copy to Clipboard buttons for both user prompts and AI assistant responses in the AI chat panel.
* Added Save & Restore Grid Settings feature (`exportSettings`, `exportSettingsJson`, `restoreSettings`, `restoreSettingsJson`):
  * Persists visible columns, group columns, sorting, filters, and inline column filter row visibility.
  * Added `autoSave: true` and `persistenceKey` parameters to `AiGrid` to automatically persist and restore grid layout on startup.
  * Added `AiGridSettingsStorage` in-memory/session storage manager.
  * Added `grid_export_settings` and `grid_restore_settings` MCP tools to allow the AI Assistant to export or restore layouts.
  * Added Settings & Presets dropdown menu in example app with "Export Settings to JSON File", "Restore Settings from JSON", and "Reset Auto-Saved Settings".
* Initial release of **AI Grid**: An intelligent, high-performance DataGrid for Flutter with native AI assistant and Model Context Protocol (MCP) skill control.
* Built on top of [trina_grid](https://pub.dev/packages/trina_grid) for fast tabular virtualization and hierarchical grouping.
* Native AI Agent integration powered by [dart_mcp_core](https://pub.dev/packages/dart_mcp_core).
* 12 local MCP tools for real-time grid introspection, multi-column AND filtering, negative filtering, sorting, grouping, column visibility, and state management.
* Built-in exact calculation engine (`grid_calculate`) for sums, averages, counts, min, max, and medians without LLM math hallucinations.
* Export feature supporting fast and reliable CSV and JSON formats with flattened tabular structure compatible with Excel, Pandas, and BI tools.
* Responsive layouts:
  * Desktop: Floatable, moveable, and resizable AI assistant window (`draggable_overlay_window`).
  * Mobile: Non-overflowing flexible toolbar with dropdown menus, full-screen assistant mode, and seamless 1-tap tab switching.
* WebAssembly (WASM / `dart2wasm`) compatible.
* Read-only editing mode default with per-column opt-in (`enableEditingMode: false`).
* Automatic light and dark theme adaptation.
