# AI Grid (`ai_grid`): Implementation Plan for Next-Gen Features (1–8) & Showcase Gallery

This document outlines the detailed architectural design, API specifications, rendering/data pipelines, Model Context Protocol (MCP) tools, and dedicated example implementations for features 1 through 8.

---

## 🏛️ Overall Showcase Architecture (`example/lib`)

To make these capabilities immediately accessible and testable, the `example/` project will be structured with a **Feature Showcase Gallery Shell**:

```
example/lib/
├── main.dart                                    # Main entry point with Navigation Drawer & Feature Switcher
├── dynamic_ai_grid_example.dart                 # Existing Dynamic Ingestion Demo
├── examples/
│   ├── superstore_enterprise_example.dart       # Flagship Superstore Demo (DevExtreme + Pivot)
│   ├── 01_ai_smart_columns_example.dart         # AI Synthesized / Prompt Columns
│   ├── 02_conditional_formatting_example.dart   # Data Bars, Color Scales & Sparklines
│   ├── 03_master_detail_example.dart            # Expandable Child Grids & Details
│   ├── 04_cell_range_selection_example.dart     # Spreadsheet Range Selection & Copy/Paste
│   ├── 05_excel_import_example.dart             # Pure-Dart .xlsx Ingestion & Model Generation
│   ├── 06_ai_data_auditor_example.dart          # Data Quality Audit, Outliers & Auto-Cleaning
│   ├── 07_mobile_card_view_example.dart         # Responsive Mobile Card / Feed View
│   └── 08_contextual_ai_actions_example.dart    # Row/Cell Context Menu & Semantic AI Actions
```

---

## 1. 🔮 AI-Synthesized Columns ("Smart / Prompt Columns")

### 1.1 Goal & User Experience
Allow users or developers to declare columns whose values are generated on-demand by an LLM based on row context (e.g. sentiment classification, customer intent, language translation, data normalization).

### 1.2 Data Model & API Design
```dart
class AiGridSmartColumn extends AiGridColumn {
  final String promptTemplate; // e.g. "Classify sentiment of '{feedback}' into Positive, Neutral, Negative"
  final List<String>? inputFields; // ['feedback']
  final bool autoExecute; // evaluate on data load or lazy on-demand
  final Duration cacheDuration;

  const AiGridSmartColumn({
    required super.field,
    required super.title,
    required this.promptTemplate,
    this.inputFields,
    this.autoExecute = false,
    super.width = 160,
  }) : super(type: AiGridColumnType.text);
}
```

### 1.3 Execution Engine
1. **Batch Isolate/Async Queue**: A dedicated `AiGridSmartColumnRunner` that collects row batches (e.g., 10 rows per prompt) to avoid hitting LLM rate limits and reduce token overhead.
2. **In-Grid Cell Visuals**:
   - `Pending/Generating`: Subtle shimmering shimmer indicator or pulsing dot.
   - `Generated`: Normal text with a small subtle sparkle icon indicator on hover.
   - `Regenerate Action`: Cell context menu option to regenerate single cell or whole column.
3. **MCP Tool Integration**:
   - `grid_generate_smart_column`: Allows the AI Assistant to autonomously create a new smart column from a prompt:
     `{"field": "urgency", "prompt": "Evaluate urgency from 1 to 5 based on '{issue_description}'"}`

---

## 2. 🎨 In-Grid Visual Analytics: Sparklines & Conditional Formatting

### 2.1 Goal & User Experience
Bring Excel / DevExtreme level data visualization directly into canvas-rendered cells without sacrificing 60/120 FPS performance.

### 2.2 Features & Sub-Types
1. **Data Bars (`AiGridDataBarFormat`)**:
   - Horizontal bars drawn directly on the canvas background of numeric cells.
   - Proportional to `(value - min) / (max - min)`. Supports positive/negative bidirectional bars (positive green to the right, negative red to the left).
2. **Color Scales / Heatmaps (`AiGridColorScaleFormat`)**:
   - 2-color or 3-color gradients (e.g., Green-Yellow-Red or Blue-White-Orange) mapped to numeric value percentiles.
3. **In-Cell Sparklines (`AiGridColumnType.sparkline`)**:
   - Renders a mini line chart, bar chart, or area chart directly on canvas inside the cell given a `List<num>` in row data.

### 2.3 API Design
```dart
enum AiGridSparklineType { line, bar, area }

class AiGridConditionalFormat {
  final String field;
  final AiGridFormatType type; // dataBar, colorScale, iconSet, highlight
  final Color? positiveColor;
  final Color? negativeColor;
  final List<Color>? gradientColors;
  final bool Function(dynamic value, Map<String, dynamic> row)? customRule;
}
```

### 2.4 Rendering Integration
- Integrate with `FitGridCustomCellPainter` inside the canvas paint loop of `fitgrid_table`.
- Zero widget instantiation overhead; computed directly via `canvas.drawRect` and `canvas.drawPath`.
- **MCP Tool**: `grid_apply_conditional_format` allowing natural language commands like *"highlight all sales over \$10k in green and show data bars on profit"*.

---

## 3. 📑 Master-Detail & Expandable Detail Rows (`rowDetailBuilder`)

### 3.1 Goal & User Experience
Support hierarchical enterprise records where expanding a row displays a nested child table, customer details card, or JSON tree.

### 3.2 API Design
```dart
typedef AiGridDetailRowBuilder = Widget Function(
  BuildContext context,
  Map<String, dynamic> parentRow,
  int rowIndex,
);

class AiGridMasterDetailOptions {
  final bool enabled;
  final AiGridDetailRowBuilder detailBuilder;
  final double detailRowHeight;
  final bool autoCollapseOthers; // accordion mode
  final bool allowMultipleExpanded;
}
```

### 3.3 Virtualization Strategy
- `fitgrid_table` calculates dynamic row heights: when row $i$ is expanded, its height expands from `defaultRowHeight` (e.g. 36px) to `defaultRowHeight + detailRowHeight` (e.g. 240px).
- Detail widget is mounted via a virtualized overlay or integrated nested canvas slot, properly clipping and scrolling with horizontal/vertical table viewports.

---

## 4. 📋 Cell Range Selection & Bidirectional Spreadsheet Copy/Paste

### 4.1 Goal & User Experience
Deliver true desktop spreadsheet ergonomics with rectangular cell selection, keyboard navigation, and seamless Excel / Google Sheets interoperability.

### 4.2 Interaction Model
1. **Mouse Drag Selection**: Click and drag across cells to form a blue highlighted selection rectangle with a primary active cell.
2. **Keyboard Navigation**:
   - Arrow keys navigate the active cell.
   - `Shift + Arrow keys` expand or shrink the selected range.
   - `Tab` / `Shift + Tab` cycle through row cells.
3. **Clipboard Interoperability**:
   - `Ctrl+C`: Serializes selected rectangular range to TSV (Tab-Separated Values). Directly pasteable into Excel, LibreOffice, and Google Sheets.
   - `Ctrl+V`: Parses TSV from clipboard and batch-updates editable cells starting at the active cell anchor.
4. **Summary Status Bar**:
   - Selected cells automatically compute and display instant statistics in the footer bar: `Average: X | Count: N | Sum: Y`.

---

## 5. 📥 Native Excel (.xlsx) Import

### 5.1 Goal & User Experience
Complete the tabular ingestion roundtrip: drop or pick `.xlsx` workbooks directly into `ai_grid` without needing prior CSV conversion.

### 5.2 Implementation Details
1. **Pure-Dart Parser**:
   - Utilize a pure-Dart archive and XML extractor (`package:excel` or lean internal OOXML parser) to remain 100% `dart2wasm` safe with zero native dependencies.
2. **Multi-Sheet Selection Dialog**:
   - If workbook has multiple worksheets, prompt the user with a sheet picker preview showing sheet names and estimated row counts.
3. **Schema Inference & Dynamic Model Creation**:
   - Auto-detect column headers from row 1.
   - Infer types (`date`, `currency`, `number`, `boolean`, `text`).
   - Emit standard `AiGridDynamicModel` and save to `AiGridDynamicStorage` (`SharedPreferences`).

---

## 6. 🧹 AI Data Auditor & Auto-Cleaning (`grid_audit_data`)

### 6.1 Goal & User Experience
Provide an instant "Data Quality Inspector" that analyzes tabular data for anomalies, inconsistencies, and nulls, offering one-click AI remediations.

### 6.2 Audit Capabilities
1. **Schema & Format Consistency**:
   - Detect mixed date formats (`2026-01-01` vs `01/02/2026`).
   - Detect dirty numbers (e.g. `$1,200.00` mixed with `1200` and `N/A`).
2. **Statistical Outliers**:
   - IQR (Interquartile Range) or standard deviation checks for extreme values in numeric columns.
3. **Duplicate & Null Detection**:
   - Flag complete duplicate rows or high-cardinality missing values.
4. **Interactive Fix Dialog**:
   - Visual summary card with issues list.
   - Quick action buttons: *"Standardize Dates"*, *"Impute Missing with Mean/Median"*, *"Strip Currency Symbols"*, *"Remove Duplicates"*.

### 6.3 MCP Tool
- `grid_audit_data`: Returns a structured diagnostics report of issues and proposed cleanups.
- `grid_apply_data_cleanse`: Applies chosen transformations directly to the datasource.

---

## 7. 📱 Mobile "Card / Feed" Responsive View Toggle

### 7.1 Goal & User Experience
On narrow mobile screens (< 480px), horizontal scrolling across 10+ columns can be cumbersome. Provide an adaptive, 1-tap view switcher between **Standard Grid View** and **Card / Feed View**.

### 7.2 UI/UX Architecture
- **Toolbar Switcher**: An icon button `[ ▦ Grid ]` / `[ ☰ Cards ]`.
- **Card Renderer (`AiGridCardView`)**:
  - Each record renders as a Material 3 Card.
  - Primary title (first text column) and prominent badge (status/category).
  - Key-value pairs displayed in a 2-column compact grid.
  - Swipe actions (swipe right to edit, swipe left to delete).
- **Preserved Core Engine**: Sorting, searching, filtering, and the AI Assistant operate seamlessly across both view modes.

---

## 8. 🖱️ Contextual Row/Cell AI Actions (Right-Click Context Menu)

### 8.1 Goal & User Experience
Expose localized, contextual AI operations directly on cell/row right-click or long-press.

### 8.2 Context Menu Actions
- 💬 **"Ask AI about this row"**: Opens the assistant drawer pre-seeded with the row's JSON data.
- ✉️ **"Draft Email / Message from record"**: Synthesizes a notification or correspondence from the row context.
- 🔍 **"Filter similar records"**: Automatically creates an in-grid filter matching the clicked cell value or category.
- 📊 **"Explain outlier"**: Explains why a specific metric deviates from the column distribution.

---

## 🚀 Example App Extension Plan (`example/lib/main.dart`)

### Gallery Architecture:
```dart
enum ExampleShowcase {
  superstore('Flagship Superstore (DevExtreme & Pivot)', Icons.table_chart),
  smartColumns('1. AI Smart / Prompt Columns', Icons.auto_awesome),
  conditionalFormatting('2. Data Bars, Heatmaps & Sparklines', Icons.palette),
  masterDetail('3. Master-Detail Child Rows', Icons.unfold_more),
  rangeSelection('4. Range Selection & Copy-Paste', Icons.select_all),
  excelImport('5. Excel (.xlsx) Import', Icons.file_present),
  dataAuditor('6. AI Data Auditor & Cleaner', Icons.health_and_safety),
  mobileCardView('7. Mobile Card / Feed View', Icons.view_agenda),
  contextualAi('8. Contextual Row/Cell AI Actions', Icons.menu_open),
  dynamicIngestion('Dynamic Ingestion (Files, Web, Clip)', Icons.cloud_download);

  final String title;
  final IconData icon;
  const ExampleShowcase(this.title, this.icon);
}
```

### Top Bar Showcase Switcher:
- A clean `DropdownButtonHideUnderline` or leading hamburger `Drawer` in the AppBar of `example/lib/main.dart` allows instant switching between any of the 10 demos without restarting the app.

---

## 📅 Implementation Status & Roadmap

| Feature | Name | Status | Version |
| :---: | :--- | :---: | :---: |
| **Feature 1** | **AI Smart / Prompt Columns** | ✅ **Completed** | `v0.7.0` |
| **Feature 2** | **Conditional Formatting, Data Bars & Sparklines** | ✅ **Completed** | `v0.5.0` |
| **Feature 3** | **Master-Detail Child Rows & Nested Grids** | ⏳ Planned | `v0.8.0` |
| **Feature 4** | **Cell Range Selection & Bidirectional Copy/Paste** | ✅ **Completed** | `v0.6.0` |
| **Feature 5** | **Pure-Dart Excel (.xlsx) Import** | ⏳ Planned | `v0.9.0` |
| **Feature 6** | **AI Data Auditor & Cleaner** | ⏳ Planned | `v0.10.0` |
| **Feature 7** | **Mobile Card / Feed Responsive Mode** | ⏳ Planned | `v0.11.0` |
| **Feature 8** | **Contextual Row/Cell AI Actions** | ⏳ Planned | `v0.12.0` |
| **Bonus** | **Dynamic Ingestion (CSV, TSV, PDF, Web GET, Clip)** | ✅ **Completed** | `v0.4.0` |
