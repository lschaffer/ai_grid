# AI Grid Example Application

An interactive showcase of **`ai_grid`** featuring the enterprise **Superstore Sales Dataset** (1,000 JSON records) with **DevExtreme-Style DataGrid Editing**, top-bar editing mode switching (Row, Cell, Form), inline multi-column filtering, exact-math AI Assistant calculations, responsive mobile/desktop layouts, and Excel export.

---

## 🚀 Features Demonstrated

* **DevExtreme-Style Editing & Top-Bar Mode Switcher**:
  * **Top Bar Switcher**: Switch dynamically between `Row Edit Mode`, `Cell Edit Mode`, and `Form (Popup) Mode` via the AppBar dropdown.
  * **Row Edit Mode**: Pinned action column with standard Material icons for Edit (`edit_outlined`), Delete (`delete_outline`), Save (`check`), and Cancel (`close`).
  * **Cell Edit Mode**: Direct in-place cell editing.
  * **Form (Popup) Mode**: Modal Material 3 dialog (`AiGridFormDialog`) in a 2-column grid layout with validation and field ordering (`editorIndex`).
  * **Fine-Grained Column Editing Rules**:
    * Each column is editable except `Sales` and `Profit` (read-only).
    * `OrderDate` and `ShipDate` feature `DateTime` controls (date and time selection).
    * Categorical fields (`Category`, `Sub-Category`, `City`, `State`, `Region`, `Segment`, `ShipMode`, `Country`) provide searchable/selectable lists populated from distinct records.
* **DevExtreme-Style Dynamic Pivot Grid & Side-by-Side Chart**:
  * **Interactive Field Chooser**: Tap the pivot button in the toolbar to drag/add **Row Fields**, **Column Fields**, and **Data (Measures)** with instant DevExtreme presets.
  * **Banded Split Column Headers**: Parent column dimensions (`Consumer / Central`, `Grand Total`) span across child measures (`Sales (Sum)`, `Discount (Average)`).
  * **Hierarchical Row Tree Grouping**: Multi-level row dimensions (e.g. `Category` &rarr; `SubCategory`) automatically create collapsible tree structures.
  * **Moveable Split-Panel Chart**: Real-time canvas chart (Grouped Bar, Column, Line, Pie) with 1:1 draggable divider and Top-6 series / Top-10 categories data filtering.
* **Intelligent AI Assistant with Model Context Protocol (MCP)**:
  * 18 registered MCP tools for filtering, sorting, column visibility, calculations, pivot grids, and layout persistence.
  * Hallucination-free math engine (`grid_calculate`): calculates exact sums, averages, and group metrics in Dart.
  * Multi-column AND filtering and negative filters (`not equals`, `does not contain`).
* **Desktop & Mobile Responsive Layouts**:
  * **Desktop**: Moveable, resizable floating window (`draggable_overlay_window`).
  * **Mobile (< 620px)**: Dropdown action menus, auto-flexing search bar, and 1-tap mode switcher (`Data Grid` ⇄ `AI Assistant`).
* **Layout Presets & Settings Storage**:
  * Pre-configured layout presets (Grouped, Financial Focus, High-Value Sales).
  * Export/Restore grid layout JSON and persistent auto-save (`autoSave: true`).

---

## 📊 Example Prompts for Correct Pivot Grid Analysis

Pivot tables are designed to **aggregate higher-level business dimensions** against each other so that cross-tabulation cells are densely populated and actionable.

### ✅ Recommended Dense Aggregations

#### 1. Category & Sub-Category by Segment & Region (DevExtreme Standard)
```text
create pivot table, rows category and subcategory, columns segment and region, data fields sales (sum), discount (avg)
```
* **Why it works**: Aggregates 1,000 transaction rows into 17 product sub-categories across 12 segment/region combinations. Every single cell is populated with meaningful summary numbers and banded headers.

#### 2. State Performance by Customer Segment
```text
create pivot table, rows state, columns segment, data fields sales (sum), profit (sum)
```
* **Why it works**: Clean 49-row matrix comparing Consumer, Corporate, and Home Office sales & profits across every US State.

#### 3. Category Breakdown by Shipping Method (Column Chart)
```text
create pivot table, rows category, columns ship mode, data fields sales (sum), quantity (sum), chart type column
```
* **Why it works**: Compact 3-row comparison showing volume shipped via First Class, Same Day, Second Class, and Standard Class with an automatic column chart.

#### 4. Regional Profitability Overview
```text
create pivot table, rows region, columns category, data fields sales (sum), profit (sum), discount (avg)
```
* **Why it works**: Compact regional scorecard breaking down revenue, margins, and discounts across Furniture, Office Supplies, and Technology.

#### 5. Reset to Normal Table Mode
```text
reset pivot table
```
* **Why it works**: Instantly restores the original flat data grid, full column set, and previous grouping.

---

### ⚠️ Pro-Tip: Avoid Leaf-Level Primary Keys in Cross-Tabulations
When writing pivot prompts:
* **Prefer Categorical Dimensions**: `Category`, `SubCategory`, `Region`, `Segment`, `ShipMode`, `State`.
* **Avoid Leaf-Level Unique Keys**: Putting `OrderID` (1,000 distinct IDs) in rows against `City` (500 cities) creates a matrix of **693 rows $\times$ 482 columns = 334,000 cells**. Since any single order was shipped to only *one* city, $99.8\%$ of cells will mathematically be empty (`—`), creating high sparsity.

---

## 🛠️ Setup & Configuration

### 1. Configure `.env`

Copy `.env.example` to `.env` or create a `.env` file in `example/`:

```ini
# Supported: mistral | openai | anthropic | gemini | ollama | openai_compatible
LLM_PROVIDER=mistral
LLM_MODEL=mistral-medium-latest
LLM_API_KEY=your_api_key_here
LLM_URL=https://api.mistral.ai/v1
```

#### Custom OpenAI-Compatible (OpenRouter, LM Studio, Groq, vLLM):
```ini
LLM_PROVIDER=openai_compatible
LLM_MODEL=deepseek/deepseek-chat
LLM_API_KEY=your_api_key
LLM_URL=https://openrouter.ai/api/v1
```

> **Note**: If no LLM credentials are provided, `ai_grid` automatically grays out the AI Assistant button and falls back cleanly without crashing.

---

## 🏃 Running the Example

### Desktop (Windows / macOS / Linux)
```bash
flutter run -d windows
```

### Web (Chrome Development with CORS bypass)
When testing remote LLM APIs (like Mistral, OpenAI, or OpenRouter) from `localhost`, use the pre-configured dev script:
```powershell
.\scripts\run_dev.ps1
```
Or manually:
```bash
flutter run -d chrome --web-browser-flag "--disable-web-security" --web-browser-flag "--user-data-dir=C:/tmp/chrome_dev_test"
```

### WebAssembly (WASM Production Build)
```bash
flutter build web --wasm
```
