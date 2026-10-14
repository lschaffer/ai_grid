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
* **Intelligent AI Assistant with Model Context Protocol (MCP)**:
  * 16 registered MCP tools for filtering, sorting, column visibility, calculations, and layout persistence.
  * Hallucination-free math engine (`grid_calculate`): calculates exact sums, averages, and group metrics in Dart.
  * Multi-column AND filtering and negative filters (`not equals`, `does not contain`).
* **Desktop & Mobile Responsive Layouts**:
  * **Desktop**: Moveable, resizable floating window (`draggable_overlay_window`).
  * **Mobile (< 620px)**: Dropdown action menus, auto-flexing search bar, and 1-tap mode switcher (`Data Grid` ⇄ `AI Assistant`).
* **Layout Presets & Settings Storage**:
  * Pre-configured layout presets (Grouped, Financial Focus, High-Value Sales).
  * Export/Restore grid layout JSON and persistent auto-save (`autoSave: true`).

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
