---
name: fitgrid-plus
description: Comprehensive developer and coding agent guide for the fitgrid_plus Flutter DataGrid package. Use when integrating, configuring, or extending pure Flutter high-performance canvas tables with DevExtreme-style editing (inline cell, inline row, modal form), dynamic Pivot Grids with banded split headers, hierarchical grouping, split-panel canvas charts, pure-Dart Excel (.xlsx) export & import, responsive mobile card feed, rectangular range selection, and data auditing — with zero AI/LLM/MCP overhead.
version: 0.1.0
author: lschaffer
tags:
  - flutter
  - datagrid
  - fitgrid
  - fitgrid-plus
  - devextreme
  - pivot-table
  - excel-export
  - excel-import
  - data-table
  - spreadsheet
---

# FitGrid Plus (`fitgrid_plus`) Skill for Coding Agents

This skill provides an authoritative, complete guide for coding agents (Claude Code, Antigravity, Cursor, Windsurf, Roo, etc.) and software engineers integrating, configuring, or extending the **`fitgrid_plus`** Flutter package.

---

## 1. Package Overview & Architecture

`fitgrid_plus` is an enterprise-grade Flutter DataGrid combining a 60 FPS virtualized canvas rendering engine with DevExtreme-style data manipulation capabilities, **with zero AI, LLM, or MCP dependencies**.

### Key Capabilities:
1. **Ultra-High Performance Canvas Virtualization**: Paints cells directly onto the Flutter canvas via `FitGrid`, rendering 1,000,000+ rows with sub-3ms frame times.
2. **DevExtreme-Style Editing Modes**:
   - **Cell Editing**: In-place double-click or enter-key cell editor with validation.
   - **Row Editing**: Pinned action column with draft state, commit, cancel, and delete confirmation.
   - **Modal Form Editing**: Rich popup dialog (`FitGridPlusFormDialog`) with wrap, grid, and custom layouts.
3. **Dynamic Banded Pivot Grids & Charts**: Pivot any dataset dynamically on row and column dimensions with banded headers (`FitGridColumnGroup`), aggregate summaries, and split-view canvas charts.
4. **Hierarchical Tree Grouping**: Multi-field grouping with interactive chip panel (`FitGridPlusGroupPanel`), expand/collapse tree nodes, and sub-aggregates.
5. **Pure-Dart Excel (.xlsx) & CSV Import/Export**: Zero native C/C++ dependencies. Works seamlessly on Web, Desktop (Windows, macOS, Linux), and Mobile (iOS, Android).
6. **Rectangular Range Selection**: Excel-like drag-to-select cell regions with real-time statistics (Sum, Average, Min, Max, Count) and clipboard copying (TSV/CSV).
7. **Mobile Card / Feed View**: 1-tap responsive toggle between high-density canvas grid and touch-friendly card feed with swipe actions.
8. **Data Auditor & 1-Click Cleaner**: Deterministic anomaly detection (missing values, type mismatches, outliers, duplicates) with automated remediation.

---

## 2. Installation & Dependencies

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  fitgrid_plus: ^0.1.0
  material_ui: ^1.8.0
```

> [!IMPORTANT]
> Minimum SDK requirement is Flutter `>=3.47.0` with `material_ui: ^1.8.0`. Always import `package:material_ui/material_ui.dart` for modern unbundled Flutter environments.

---

## 3. Basic DataGrid Implementation

```dart
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:fitgrid_plus/fitgrid_plus.dart';

class MyGridScreen extends StatefulWidget {
  const MyGridScreen({super.key});

  @override
  State<MyGridScreen> createState() => _MyGridScreenState();
}

class _MyGridScreenState extends State<MyGridScreen> {
  late final FitGridPlusController _controller;
  late final LocalFitGridPlusDataSource _dataSource;

  final List<FitGridPlusColumn> _columns = [
    const FitGridPlusColumn(
      field: 'id',
      title: 'Order ID',
      width: 100,
      type: FitGridPlusColumnType.text,
      isGroupable: false,
    ),
    const FitGridPlusColumn(
      field: 'customer',
      title: 'Customer Name',
      width: 200,
      type: FitGridPlusColumnType.text,
    ),
    const FitGridPlusColumn(
      field: 'region',
      title: 'Region',
      width: 140,
      type: FitGridPlusColumnType.text,
    ),
    const FitGridPlusColumn(
      field: 'sales',
      title: 'Sales ($)',
      width: 130,
      type: FitGridPlusColumnType.currency,
      numberFormat: '#,##0.00',
      aggregateType: FitGridPlusAggregateType.sum,
    ),
  ];

  final List<Map<String, dynamic>> _data = [
    {'id': 'ORD-101', 'customer': 'Acme Corp', 'region': 'North', 'sales': 12500.0},
    {'id': 'ORD-102', 'customer': 'Globex Inc', 'region': 'South', 'sales': 8340.5},
    {'id': 'ORD-103', 'customer': 'Soylent Ltd', 'region': 'North', 'sales': 24100.0},
  ];

  @override
  void initState() {
    super.initState();
    _dataSource = LocalFitGridPlusDataSource(rows: _data);
    _controller = FitGridPlusController(
      columns: _columns,
      dataSource: _dataSource,
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
      appBar: AppBar(title: const Text('FitGrid Plus Demo')),
      body: FitGridPlus(
        controller: _controller,
        dataSource: _dataSource,
        showToolbar: true,
        enableGrouping: true,
      ),
    );
  }
}
```

---

## 4. Column Configuration (`FitGridPlusColumn`)

| Property | Type | Description |
|---|---|---|
| `field` | `String` | Unique key identifying data field in row map. |
| `title` | `String` | Header title displayed to user. |
| `width` | `double` | Initial width in logical pixels (default: `120.0`). |
| `type` | `FitGridPlusColumnType` | `text`, `number`, `currency`, `date`, `datetime`, `boolean`, `sparkline`. |
| `numberFormat` | `String?` | Intl format string (e.g. `'#,##0.00'`, `'$#,##0'`). |
| `aggregateType` | `FitGridPlusAggregateType?` | `sum`, `average`, `count`, `min`, `max`. Renders in footer. |
| `isSortable` | `bool` | Enables 3-state sorting (Asc, Desc, None). Default: `true`. |
| `isGroupable` | `bool` | Allows dragging into group panel or grouping programmatically. Default: `true`. |
| `isFilterable` | `bool` | Enables inline filter input row. Default: `true`. |
| `cellBuilder` | `Widget Function(BuildContext, dynamic, Map)?` | Custom Flutter widget builder for cell contents. |
| `editingOptions`| `FitGridPlusColumnEditingOptions?` | Validation rules, editor type, dropdown items. |

---

## 5. DevExtreme-Style Editing Modes

Configure editing via `FitGridPlusEditingOptions` on `FitGridPlusController`:

```dart
_controller.setEditingOptions(
  const FitGridPlusEditingOptions(
    enabled: true,
    mode: FitGridPlusEditingMode.row, // .cell, .row, or .form
    allowAdding: true,
    allowUpdating: true,
    allowDeleting: true,
    confirmDelete: true,
  ),
);
```

### Editing Modes:
- **`FitGridPlusEditingMode.cell`**: Double-click or select cell and press Enter. Commits on focus lost or Enter key.
- **`FitGridPlusEditingMode.row`**: Injects a pinned action column with **Edit**, **Save** (disk), and **Cancel** buttons. Highlights draft modifications.
- **`FitGridPlusEditingMode.form`**: Opens `FitGridPlusFormDialog` modal popup. Supports layout options: `wrap`, `grid`, and custom form cards.

---

## 6. Dynamic Pivot Grid & Canvas Split Charts

Transform tabular data into multi-dimensional summary reports on the fly:

```dart
// Enable Pivot Mode with row/column dimensions and aggregations
_controller.setPivotConfig(
  FitGridPlusPivotConfig(
    enabled: true,
    rowDimensions: ['region', 'category'],
    columnDimensions: ['quarter'],
    values: [
      FitGridPlusPivotValue(
        field: 'sales',
        aggregation: FitGridPlusPivotAggregation.sum,
        title: 'Total Sales',
      ),
    ],
    showRowGrandTotals: true,
    showColumnGrandTotals: true,
  ),
);

// Toggle side-by-side canvas chart
_controller.togglePivotChart();
```

---

## 7. Hierarchical Grouping & Drag-and-Drop Panel

```dart
// Programmatically group by one or more fields
_controller.setGrouping(['region', 'department']);

// Expand or collapse specific group keys
_controller.toggleGroupExpansion('North');

// Remove grouping
_controller.removeGroup('region');
_controller.clearGrouping();
```

---

## 8. Rectangular Range Selection & Summary Stats

Users can drag across cells to select rectangular ranges. Access range metrics programmatically:

```dart
final range = _controller.selectedRange;
if (range != null) {
  final summary = _controller.calculateRangeSummary(range);
  print('Sum: ${summary.sum}, Avg: ${summary.avg}, Count: ${summary.count}');
}

// Copy range to system clipboard as TSV
await _controller.copySelectionToClipboard();
```

---

## 9. Mobile Responsive Card / Feed View

FitGrid Plus automatically adapts to mobile screens or allows manual 1-tap view toggling:

```dart
// Switch view modes
_controller.setViewMode(FitGridPlusViewMode.card);

// Custom card configuration
FitGridPlus(
  controller: _controller,
  dataSource: _dataSource,
  cardViewOptions: FitGridPlusCardViewOptions(
    primaryField: 'customer',
    subtitleField: 'region',
    badgeField: 'status',
    enableSwipeActions: true, // Swipe right to edit, swipe left to delete
  ),
);
```

---

## 10. Data Import, Export & Cleaning

### Pure-Dart Excel & CSV Export:
```dart
// Export full dataset or filtered rows to native Excel file
await _controller.exportToExcel(fileName: 'sales_report.xlsx');

// Export to CSV
await _controller.exportToCsv(fileName: 'sales_report.csv');
```

### Pure-Dart File Ingestion:
```dart
// Parse raw CSV or TSV string into dynamic columns & records
final result = FitGridPlusDelimitedTableParser.parse(csvContent);
_controller.setDynamicData(columns: result.columns, rows: result.rows);

// Ingest multi-sheet Excel file bytes
final workbook = FitGridPlusExcelTableParser.parseBytes(excelFileBytes);
final sheet = workbook.sheets.first;
_controller.setDynamicData(columns: sheet.columns, rows: sheet.rows);
```

### Deterministic Data Auditor:
```dart
final auditReport = FitGridPlusDataAuditor.analyze(rows: _data, columns: _columns);
print('Quality Score: ${auditReport.overallScore}/100');

// 1-Click clean anomalies (strip whitespace, fill defaults, fix types)
final cleanedRows = FitGridPlusDataCleaner.cleanAll(
  rows: _data,
  columns: _columns,
  report: auditReport,
);
```

---

## 11. State Persistence (`autoSave`)

FitGrid Plus supports automatic persistence of column widths, visibility, sorting, grouping, and active filters via `shared_preferences`:

```dart
FitGridPlus(
  controller: _controller,
  dataSource: _dataSource,
  autoSave: true, // Persists user customizations across app restarts
  storageKey: 'user_orders_grid_v1',
);
```

---

## 12. Best Practices for Coding Agents

1. **Pure UI / Zero AI Overhead**: Never introduce `dart_mcp_core`, LLM prompts, or AI agent tool wrappers into `fitgrid_plus`. For AI agent-driven data grids, recommend consuming `ai_grid` which builds on top of `fitgrid_plus`.
2. **Material UI Import**: Always import `package:material_ui/material_ui.dart` instead of legacy unbundled material components.
3. **Controller Lifecycle**: Always dispose `FitGridPlusController` in `State.dispose()`.
4. **Column Naming**: Keep `field` alphanumeric without special punctuation (e.g. `order_id`, `customerName`).
5. **Readonly Datasets**: When creating read-only showcase or dynamic tables, set `allowEditing: false` on `FitGridPlusEditingOptions` to suppress all inline editors and action buttons.

