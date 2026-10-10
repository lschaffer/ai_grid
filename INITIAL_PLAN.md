# AI Grid (`ai_grid`) — Project Plan & Architecture Blueprint

> **DevExtreme-inspired intelligent DataGrid for Flutter with native AI assistant and MCP skill control.**

---

## 1. Executive Summary & Naming Decision

### Name Selection: `ai_grid` (Widget: `AiGrid`) vs `ai_data_table` (Widget: `AiDataTable`)

| Criteria | `ai_grid` / `AiGrid` (Selected) | `ai_data_table` / `AiDataTable` |
| :--- | :--- | :--- |
| **Industry Convention** | Matches modern enterprise standards (**DevExtreme DataGrid**, **AG Grid**, **Syncfusion DataGrid**). | Associated with basic tabular widgets (Flutter's built-in `DataTable`). |
| **Feature Association** | Implies high-performance 2D virtualization, multi-level grouping, column filtering, aggregate footers, and stateful controller. | Implies simple, rigid, static rows and columns. |
| **Brevity & Branding** | Concise, modern, and memorable (`ai_grid`, `AiGrid`). | Verbose (`ai_data_table`, `AiDataTable`). |

**Decision**: The package is named **`ai_grid`**, with the primary widget named **`AiGrid`**.

---

## 2. Base Package Architecture: Vendored `trina_grid` with `material_ui` Tweak

### Base Comparison: `trina_grid` vs `data_table_2`

| Feature / Requirement | `trina_grid` (Active fork of PlutoGrid) | `data_table_2` | Verdict & Impact |
| :--- | :--- | :--- | :--- |
| **Hierarchical Row Grouping** | **Native** (`TrinaRowGroup`, collapsible tree groups, group headers with row counts). | **None** (Only flat rows; grouping must be custom-rendered with complex tree hacks). | **`trina_grid` wins decisively**. DevExtreme's multi-level grouping requires native row grouping. |
| **Column Filter Row** | **Native** (Inline filter row under headers with Contains, Equals, StartsWith, GreaterThan, etc.). | **None** (Only manual dropdown menus in headers). | **`trina_grid` wins**. Matches DevExtreme filter row directly. |
| **Aggregations & Summaries** | **Native** (`TrinaAggregateColumnFooter` for Sum, Avg, Min, Max, Count). | **None** (Must manually calculate and append a footer row). | **`trina_grid` wins**. Built-in aggregate calculations for total and grouped views. |
| **Global Search Panel** | **Native** (Fast in-memory text filter across visible columns). | **Manual** (Must filter the outer data list manually). | **`trina_grid` wins**. |
| **Programmatic State Controller** | **`TrinaGridStateManager`** provides deep imperative APIs (`setFilter`, `setSort`, `setRowGroup`, `paginate`, `setShowColumnFilter`). | Limited controller primarily for scroll and column resizing. | **`trina_grid` wins**. The AI MCP tools need programmatic APIs to modify grid state. |
| **Performance & Virtualization** | Full 2D virtualization (handles 100k+ rows effortlessly on Desktop & Web). | Virtualized row scrolling, but struggles with complex hierarchical structures. | **`trina_grid` wins**. |
| **Platform Support** | Windows, macOS, Linux, Web, Android, iOS. | Windows, macOS, Linux, Web, Android, iOS. | Both support all platforms. |

### Flutter 3.47+ Standalone `material_ui` Decoupling
With Flutter 3.47 and Dart 3.13, Flutter has unbundled `material_ui` and `cupertino_ui` into standalone packages on pub.dev. Upstream `trina_grid` still uses legacy `package:flutter/material.dart` in its filter UI and dialog components.

**Vendor Strategy**:
- `trina_grid` is vendored directly into `projects/ls/ai_grid/plugins/trina_grid`.
- Dependencies updated in `plugins/trina_grid/pubspec.yaml` with `material_ui: ^1.4.0`.
- Filter UI components (`trina_column_filter.dart`, `multi_line_column_filter.dart`, `filter_helper.dart`, `filtering_row_state.dart`) refactored to import `package:material_ui/material_ui.dart`.
- `ai_grid` references this local plugin via `path: plugins/trina_grid`, ensuring 100% compatibility with `flutter_ui_mcp_core` and the modern Flutter 3.47+ ecosystem.

---

## 3. DevExtreme DataGrid AI Features Alignment

Based on the [DevExtreme DataGrid AI Assistant](https://js.devexpress.com/Angular/Demos/WidgetsGallery/Demo/DataGrid/AIAssistant/FluentBlueLight/):

```
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│  [Region ↑]  [Product ↑]                                                [ ⟳ ]  [ 🔍 Search...        ] │ <- Group Panel & Search
├────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ [ ] | Region ≡                   | Product ≡            | Sale Amount ≡      | Sector ≡        |       │ <- Header Row
│     | [🔍                    ]   | [🔍               ]  | [🔍            ]   | [🔍 Health      ] |       │ <- Column Filter Row
├─────┴────────────────────────────┴──────────────────────┴────────────────────┴─────────────────┴───────┤
│ ▼ Region: Africa (Count: 14)                                                                           │ <- Level 1 Group
│     ▼ Product: Eco Max (Count: 4)                                                                      │ <- Level 2 Group
│         [ ] Africa               | Eco Max              | $9,300             | Health                  │ <- Data Row
│         [ ] Africa               | Eco Max              | $4,440             | Health                  │
│                                                                                                        │
│                                           ┌──────────────────────────────────────────────┐             │
│                                           │  ✨ AI Assistant                         [✕] │             │ <- Floating AI Assistant
│                                           ├──────────────────────────────────────────────┤             │
│                                           │  ✅ Summary                                  │             │
│                                           │     Display summaries: "Sale Amount" sum.    │             │
│                                           │                                              │             │
│                                           │                  [ count by region ]         │             │
│                                           │  ✅ Grouping and Summary                     │             │
│                                           │     Group data against "Region".             │             │
│                                           │                                              │             │
│                                           │  [💡 Help]  [🔍 Filter Sector by Health]     │             │
│                                           │  [⬆️ Sort by Region]  [🧩 Group by Product]  │             │
│                                           │ ──────────────────────────────────────────── │             │
│                                           │  [ Type a message...               🎙️ ] [➔] │             │
│                                           └──────────────────────────────────────────────┘             │
├────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Sum: $2,259,500                                                                     Page [ 1 / 10 ] >  │ <- Footer Aggregates & Pager
└────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Visual & Interactive Features in Scope (Phase 1: Read-Only Grid)
1. **Top Group Panel**:
   - Shows active grouping chips (e.g. `Region ↑`, `Product ↑`).
   - Allows collapsing/expanding groups and clearing groups.
2. **Global Search Bar**:
   - Real-time text search across all columns with debounce.
3. **Column Filter Row**:
   - DevExtreme-style filter inputs directly beneath column headers.
   - Type-aware filters (Text: Contains/Equals; Numeric: > / < / =; Enum: Dropdown).
4. **Hierarchical Row Groups**:
   - Tree-based expand/collapse with group aggregate badges (e.g. `(Count: 14)`).
5. **Footer Summary & Aggregations**:
   - Column footers displaying `Sum`, `Average`, `Count`, `Min`, `Max`.
6. **Pager & Page Size Selector**:
   - Fast page navigation with customizable page sizes (10, 25, 50, 100).
7. **Overlay / Docked AI Assistant Widget**:
   - Floating panel overlaying the grid (draggable or docked to bottom-right).
   - Visual execution cards with status badges (e.g. Green checkmark for completed actions).
   - Dynamic recommendation chips based on current schema and state.
   - Text input box with submit button and optional voice trigger.

---

## 4. Architecture & Layering

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           User Application                              │
│                                                                         │
│   AiGrid(                                                               │
│     dataSource: LocalAiGridDataSource(salesData),                       │
│     columns: [...],                                                     │
│     controller: gridController,                                         │
│     aiConfig: AiGridAssistantConfig(...),                               │
│   )                                                                     │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │
             ┌───────────────────────┴───────────────────────┐
             ▼                                               ▼
┌─────────────────────────┐                     ┌─────────────────────────┐
│     AI Assistant UI     │                     │     AiGrid Widget       │
│  - Floating Panel       │                     │  - Top Group Panel      │
│  - Action History Cards │                     │  - Toolbar & Search     │
│  - Prompt Suggestions   │                     │  - Vendored TrinaGrid   │
│  - Chat Input Box       │                     │  - Aggregation Footer   │
└────────────┬────────────┘                     └────────────┬────────────┘
             │                                               │
             ▼                                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           AiGridController                              │
│  - Coordinates Data Source, Grid State, and AI Agent                    │
│  - State: filter, sort, group, search, pagination, summary              │
│  - Actions: applyFilter(), setGrouping(), search(), summarize()         │
└───────────────────────┬─────────────────────────────────────────────────┘
                        │
      ┌─────────────────┴─────────────────┐
      ▼                                   ▼
┌───────────────────────────┐   ┌─────────────────────────────────────────┐
│     AiGridDataSource      │   │         dart_mcp_core Skill             │
│  - LocalAiGridDataSource  │   │     "ai_grid_control" Skill             │
│  - ServerAiGridDataSource │   │  - grid_get_schema                      │
│  - Paged fetching         │   │  - grid_get_state                       │
│  - In-memory aggregations │   │  - grid_filter / grid_clear_filters     │
└───────────────────────────┘   │  - grid_sort                            │
                                │  - grid_group                           │
                                │  - grid_summarize                       │
                                │  - grid_search                          │
                                │  - grid_paginate                        │
                                │  - grid_reset                           │
                                └─────────────────────────────────────────┘
```

---

## 5. `dart_mcp_core` Integration: Single MCP Skill

`ai_grid` provides **one comprehensive Skill**:
- **Skill Name**: `ai_grid_control` (or `datatable_control`)
- **Purpose**: "Allows the AI assistant to inspect the data grid schema, query current state, and control filtering, sorting, grouping, aggregations, search, and pagination."

### MCP Local Tools (`McpLocalTool` implementations)

| Tool Name | Parameters | Purpose |
| :--- | :--- | :--- |
| `grid_get_schema` | *(none)* | Returns column names, data types, groupable/sortable flags, and sample values. |
| `grid_get_state` | *(none)* | Returns current active filters, active sort columns, active group columns, summary metrics, page index, and visible row count. |
| `grid_get_sample` | `limit` (int, default 5) | Returns top rows or summary statistics so LLM understands exact text values (e.g. valid sector names). |
| `grid_filter` | `columnKey` (string), `operator` (equals, contains, gt, lt, between), `value` (any) | Applies a filter to a specific column. |
| `grid_clear_filters` | `columnKey` (optional string) | Clears filters on one or all columns. |
| `grid_search` | `query` (string) | Applies global search string across all columns. |
| `grid_sort` | `columnKey` (string), `descending` (bool) | Sorts the grid by specified column. |
| `grid_group` | `columns` (array of strings) | Sets hierarchical grouping (e.g. `["Region", "Product"]`). |
| `grid_summarize` | `aggregations` (map: columnKey -> sum/avg/count/min/max) | Enables summary footers and group aggregations. |
| `grid_paginate` | `page` (int), `pageSize` (optional int) | Navigates to page and sets page size. |
| `grid_reset` | *(none)* | Resets grid to original unfiltered, ungrouped state. |

---

## 6. Implementation Phases & Status

- [x] **Setup & Vendoring**:
  - `ai_grid` Flutter package created at `C:\projects\ls\ai_grid`.
  - Local vendored `plugins/trina_grid` established.
  - Standalone `material_ui: ^1.4.0` integrated into filter components.
  - Linked `dart_mcp_core` dependency.
- [ ] **Phase 1: Core Read-Only Grid & Data Sources**:
  - `AiGridColumn` definition (field, title, type, width, groupable, filterable, sortable, aggregate).
  - `AiGridDataSource` abstract contract + `LocalAiGridDataSource`.
  - DevExtreme-styled Fluent theme wrapper for TrinaGrid.
  - Top Group Panel widget (drag/click chips for active grouping).
  - DevExtreme Global Search bar widget.
  - DevExtreme Column Filter Row.
  - Aggregate Column Footers.
- [ ] **Phase 2: Controller & MCP Skill Tools**:
  - `AiGridController` bridging grid state to `dart_mcp_core` tools.
  - 11 `McpLocalTool` implementations.
  - `SkillManifest` definition.
- [ ] **Phase 3: DevExtreme-like Floating AI Assistant**:
  - Floating/docked assistant panel widget.
  - Action cards with status badges.
  - Suggestion action pills.
  - Agent conversation pipeline.
- [ ] **Phase 4: Server-Side DataSource & Demo**:
  - `ServerAiGridDataSource` (pagination & query payloads).
  - Example app mirroring DevExtreme Sales demo.
