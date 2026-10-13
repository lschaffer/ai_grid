## 0.0.3

* **Engine Migration to `fitgrid_table`**:
  * Migrated underlying grid engine to **[fitgrid_table](https://pub.dev/packages/fitgrid_table)**.
  * Direct canvas cell painting (~3ms frame time on 1M rows) instead of widget-per-cell virtualization.
  * Native content-based column auto-sizing (`autoSize`, `autoSizeAll`).
  * Built-in multi-column sorting with background isolate sorting support for large datasets.
* **Native Excel (XLSX) Export**:
  * Added pure Dart Excel (`.xlsx`) export alongside CSV, TSV, and JSON formats without external native dependencies.
* **`material_ui` Ecosystem Compatibility**:
  * Migrated UI components to `package:material_ui/material_ui.dart` for seamless Flutter 3.47 unbundled environments.
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
