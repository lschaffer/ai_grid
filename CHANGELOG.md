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
