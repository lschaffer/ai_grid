# AI Grid Example Application

An interactive showcase of **`ai_grid`** featuring the enterprise **Superstore Sales Dataset** (1,000 JSON records) with **Server-Side Lazy Pagination**, inline multi-column filtering, exact-math AI Assistant calculations, responsive mobile/desktop layouts, and multi-format data export (CSV, JSON, PDF).

---

## 🚀 Features Demonstrated

* **Server-Side Lazy Pagination (`LazyAiGridDataSource`)**:
  * Loads 25 records per page on-demand with realistic asynchronous latency simulation.
  * Server-side filtering (`fetchWithFiltering: true`): resets page to 1 and applies query filters before slicing.
  * Server-side sorting (`fetchWithSorting: true`): dynamically sorts entire dataset before returning current page.
  * Built-in pagination footer with "Go to Page" jump dialog and total records count.
* **Intelligent AI Assistant with Model Context Protocol (MCP)**:
  * 14 registered MCP tools for filtering, sorting, column visibility, calculations, and page navigation.
  * Hallucination-free math engine (`grid_calculate`): calculates exact sums, averages, and group metrics in Dart.
  * Multi-column AND filtering and negative filters (`not equals`, `does not contain`).
* **Desktop & Mobile Responsive Layouts**:
  * **Desktop**: Moveable, resizable floating window (`draggable_overlay_window`).
  * **Mobile (< 620px)**: Dropdown action menus, auto-flexing search bar, and 1-tap mode switcher (`Data Grid` ⇄ `AI Assistant`).
* **Multi-Format Export**: Full export dialog with format options (CSV, JSON, PDF), delimiter selection, and column picker.

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
