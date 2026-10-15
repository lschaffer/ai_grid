# Architectural Plan: DevExtreme-Style Pivot Table & AI Assistant Integration for `ai_grid`

This document outlines the architecture and execution plan for adding on-the-fly **Pivot Table** capabilities to **`ai_grid`**, matching DevExtreme's [PivotGrid](https://js.devexpress.com/React/Demos/WidgetsGallery/Demo/PivotGrid/Overview/FluentBlueLight/) design, integrating with the underlying `fitgrid_table` pivot engine, empowering the **AI Assistant** with natural language pivot generation, and providing an auto-generated **side-by-side Chart** visualization.

---

## 1. High-Level Architecture

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                   AiGrid Component                                     │
├────────────────────────────────────────────────────────────────────────────────────────┤
│                                     AiGridToolbar                                      │
│  [Search...]  [Filters]  [Columns]  [Pivot Mode ⚑]  [Field Chooser]  [Chart Toggle 📊] │
├───────────────────────────────────────────┬────────────────────────────────────────────┤
│               Table View                  │           Bonus: Pivot Chart               │
│                                           │                                            │
│  ┌─────────────────────────────────────┐  │  ┌──────────────────────────────────────┐  │
│  │         Pivoted FitGrid             │  │  │          AiGridPivotChart            │  │
│  │  • Read-only (editing suppressed)   │  │  │  • Bar / Grouped Bar / Line / Pie    │  │
│  │  • Multi-level column headers       │  │  │  • Responsive Side-by-Side Split    │  │
│  │  • Grand totals & subtotals         │  │  │  • Canvas-based (Zero dependency)    │  │
│  │  • Native XLSX Export               │  │  │  • Interactive hover tooltips        │  │
│  └─────────────────────────────────────┘  │  └──────────────────────────────────────┘  │
└───────────────────────────────────────────┴────────────────────────────────────────────┘
                                     │
               ┌─────────────────────┼─────────────────────┐
               ▼                                           ▼
┌─────────────────────────────┐             ┌─────────────────────────────┐
│    Interactive UI Chooser   │             │   AI Assistant & MCP Tool   │
│  • Drag & Drop Field Zones  │             │  • Natural language parsing │
│  • Row / Col / Data areas   │             │  • create_pivot_table       │
│  • Aggregation selectors    │             │  • reset_pivot_table        │
└─────────────────────────────┘             └─────────────────────────────┘
```

---

## 2. Core Models & Configuration (`lib/src/models/ai_grid_pivot.dart`)

### 2.1 Configuration Schema
```dart
/// Aggregation functions supported in Pivot mode.
enum AiGridPivotAggregation {
  sum,
  count,
  average,
  min,
  max,
}

/// A value / metric field to aggregate in the pivot table.
class AiGridPivotValueConfig {
  const AiGridPivotValueConfig({
    required this.columnId,
    this.aggregation = AiGridPivotAggregation.sum,
    this.label,
    this.format,
  });

  final String columnId;
  final AiGridPivotAggregation aggregation;
  final String? label;
  final String Function(num value)? format;
}

/// Pivot chart visualization types.
enum AiGridPivotChartType {
  groupedBar,
  column,
  line,
  pie,
}

/// Full configuration for an active pivot transformation.
class AiGridPivotConfig {
  const AiGridPivotConfig({
    required this.rowFieldIds,
    this.columnFieldIds = const <String>[],
    required this.values,
    this.showColumnTotals = true,
    this.showRowTotals = true,
    this.showChart = false,
    this.chartType = AiGridPivotChartType.groupedBar,
  });

  final List<String> rowFieldIds;
  final List<String> columnFieldIds;
  final List<AiGridPivotValueConfig> values;
  final bool showColumnTotals;
  final bool showRowTotals;
  final bool showChart;
  final AiGridPivotChartType chartType;
}
```

---

## 3. Controller Pipeline (`lib/src/controllers/ai_grid_controller.dart`)

### 3.1 Pivot State Management
- Add state variables:
  - `AiGridPivotConfig? _pivotConfig;`
  - `FitGridPivotResult? _pivotResult;`
  - `bool get isPivotActive => _pivotConfig != null;`
- Methods:
  - `void setPivot(AiGridPivotConfig config)`:
    1. Reads original source rows from `dataSource.rows`.
    2. Maps `rowFieldIds` and `columnFieldIds` to `FitGridPivotDimension`.
    3. Handles multi-level composite column dimensions: `columns: [country, city, segment]`.
    4. Computes `fitGridPivot(...)` and saves `_pivotResult`.
    5. Sets `fitController` into read-only mode and loads pivoted rows/columns.
    6. Notifies listeners.
  - `void clearPivot()`:
    1. Sets `_pivotConfig = null` and `_pivotResult = null`.
    2. Restores original grid columns, rows, and editable triggers.
    3. Notifies listeners.
  - `void togglePivotChart([bool? show])`:
    1. Updates `_pivotConfig = _pivotConfig.copyWith(showChart: show ?? !_pivotConfig.showChart)`.
    2. Notifies listeners.

---

## 4. UI: DevExtreme-Style Field Chooser Panel (`AiGridPivotChooserDialog`)

Inspired by DevExtreme's [dxPivotGrid Field Chooser](https://js.devexpress.com/React/Demos/WidgetsGallery/Demo/PivotGrid/Overview/FluentBlueLight/):
- **4 Configurable Zones**:
  1. **All Fields**: Available grid columns that can be dragged or assigned.
  2. **Row Dimensions**: Placed vertically as tree/group headings.
  3. **Column Dimensions**: Expanded horizontally across the grid header bands.
  4. **Data (Measures)**: Aggregated values with summary function picker popup (`Sum`, `Count`, `Average`, `Min`, `Max`).
- **Interactive Controls**:
  - Drag-and-drop chips or intuitive `+ / -` action buttons.
  - "Apply" and "Reset" buttons.
  - Quick presets (e.g. "Sales by Region", "Orders by Date & Category").

---

## 5. AI Assistant & MCP Tool Integration

### 5.1 Tool Definition: `create_pivot_table`
The AI Assistant will have access to a dedicated MCP tool:
```json
{
  "name": "create_pivot_table",
  "description": "Transforms the table on the fly into an aggregated pivot table with optional side-by-side chart",
  "parameters": {
    "rows": { "type": "array", "items": { "type": "string" }, "description": "Column names/IDs to use as row dimensions" },
    "columns": { "type": "array", "items": { "type": "string" }, "description": "Column names/IDs to use as column dimensions" },
    "values": {
      "type": "array",
      "items": {
        "column": "string",
        "aggregation": "sum | count | average | min | max",
        "label": "string"
      }
    },
    "showChart": { "type": "boolean", "default": false },
    "chartType": { "type": "string", "enum": ["groupedBar", "column", "line", "pie"] }
  }
}
```

### 5.2 Natural Language Understanding
The assistant seamlessly parses prompts such as:
> *"Create a pivot table - rows (order id, order date), columns country, city, segment, data (sales - type: sum, discount - type avg)"*

The assistant:
1. Fuzzy-matches labels (`"order id" -> "order_id"`, `"sales" -> "sales_amount"`).
2. Maps `"type: sum"` to `AiGridPivotAggregation.sum`.
3. Calls `create_pivot_table` and gives a concise confirmation with summary stats.

### 5.3 Reset / Normal Mode Tool: `reset_pivot_table`
> *"Switch back to normal table"* / *"Close pivot view"*
Calls `reset_pivot_table`, restoring the standard editable grid state.

---

## 6. Read-Only Protection & Native Excel Export

### 6.1 Read-Only Enforcement
- While `isPivotActive`:
  - `FitGrid.editTrigger` is forced to `FitGridEditTrigger.none`.
  - Inline row action columns and cell editors are suppressed.
  - Context menu reflects pivot-specific operations (e.g., sort on measure, copy with headers).

### 6.2 Excel (.xlsx) Export
- Integrates with the existing `AiGridExportDialog`:
  - When in Pivot Mode, exports the `_pivotResult` rows and multi-level columns.
  - Formats numbers, bold headers, and includes Grand Total summary rows.
  - Generates standard `.xlsx` spreadsheets ready for Excel / Google Sheets.

---

## 7. Bonus: Side-by-Side Pivot Chart (`AiGridPivotChart`)

### 7.1 Architecture
- Zero external charting bloat: implemented using high-performance Flutter `CustomPainter`.
- Smooth animations on dimension changes.
- Responsive layout:
  - On desktop/wide screens: side-by-side split view (resizable divider).
  - On compact screens: collapsible bottom/top drawer or tabbed view.

### 7.2 Chart Modes
1. **Grouped Bar**: Compares data series across categories (e.g. Sales across Segments by Country).
2. **Stacked Column**: Shows composition of totals.
3. **Line Chart**: Ideal for time-based row dimensions (dates, quarters).
4. **Pie / Donut**: Proportional share of the top dimension.

---

## 8. Step-by-Step Implementation Roadmap

| Phase | Task | Details |
|---|---|---|
| **Phase 1** | **Pivot Data Models & Multi-Column Dimensions** | Create `AiGridPivotConfig`, enhance dimension bucketing for multiple column hierarchy in `fitgrid/src/model/pivot.dart`. |
| **Phase 2** | **Controller Pipeline & State Management** | Add `setPivot`, `clearPivot`, `togglePivotChart` to `AiGridController`. |
| **Phase 3** | **Interactive Field Chooser UI** | Build DevExtreme-inspired dialog / panel with 4 drag zones & aggregation selectors. |
| **Phase 4** | **AI Assistant & MCP Tools** | Implement `create_pivot_table` and `reset_pivot_table` tools with fuzzy column matching. |
| **Phase 5** | **Read-Only Mode & XLSX Export** | Guard editing, enable seamless pivot `.xlsx` export, ensure clean toggle back to normal table. |
| **Phase 6** | **Bonus: Canvas Pivot Chart** | Implement `AiGridPivotChart` with bar/grouped/line/pie modes beside the grid. |
| **Phase 7** | **Testing & Examples** | Unit tests for pivot computation, MCP tools, and example integration in `example/lib/main.dart`. |
