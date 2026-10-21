# Architectural Plan: Dynamic AI Grid from File & Web Data Sources

This document details the architectural design and implementation plan for **Dynamic AI Grid** in `ai_grid`. It enables generating, loading, editing, and managing dynamic tabular DataGrids from local files (CSV, JSON, TXT, Markdown, PDF, Word), system clipboard (images, spreadsheets, dropped files), and remote HTTP GET endpoints, powered by multimodal LLMs, native MCP tools, and `dart_mcp_core 1.3.0`.

---

## 1. System Architecture & High-Level Flow

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                   INPUT SOURCES                                        │
│                                                                                        │
│  [ Local Files ]             [ System Clipboard ]              [ Web HTTP GET ]        │
│  CSV, JSON, TXT, MD,          Images (Screenshots),             Public REST APIs,      │
│  PDF, Word (.docx)            Dropped Files, Copied Text        HTML Tabular Pages     │
└──────────────┬─────────────────────────┬───────────────────────────────┬───────────────┘
               │                         │                               │
               ▼                         ▼                               ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              INGESTION & PARSING ENGINE                                │
│                                                                                        │
│  1. Pure-Dart Parsers: CSV/TSV, JSON arrays, Markdown `|---|---|` pipe tables.         │
│  2. Multimodal LLM Extraction (PDF, Images, Screenshots, Complex Docs, Web HTML)       │
│     via `dart_mcp_core 1.3.0` (`TextPart`, `ImagePart`, `DocumentPart`).               │
└────────────────────────────────────────┬───────────────────────────────────────────────┘
                                         │
                                         ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                            DYNAMIC DATASOURCE ARTIFACTS                                │
│                                                                                        │
│  1. Model Schema: `${name}_mdl.yaml` (Columns, Titles, Detected Types, Editability)   │
│  2. Data Rows:    `${name}.json`     (Raw tabular row maps)                            │
│  3. Metadata:     Source type, Readonly flag (true for Web), Timestamp, Row Count      │
└────────────────────────────────────────┬───────────────────────────────────────────────┘
                                         │
                     ┌───────────────────┴───────────────────┐
                     ▼                                       ▼
┌──────────────────────────────────────────┐  ┌──────────────────────────────────────────┐
│      PERSISTENCE (SharedPreferences)     │  │           ACTIVE AIGRID RUNTIME          │
│                                          │  │                                          │
│  • Registry: `ai_grid_dynamic_registry`  │  │  • AiGrid(dynamicGrid: true)             │
│  • Model:    `ai_grid_dyn_model_${name}` │──▶  • AiGridToolbar (Datasource Manager)    │
│  • Rows:     `ai_grid_dyn_data_${name}`  │  │  • DevExtreme Editing (writes back)     │
│  • Export/Import: YAML bundle package    │  │  • AiGridAssistantPanel (Multimodal)     │
└──────────────────────────────────────────┘  └──────────────────────────────────────────┘
```

---

## 2. Dynamic Model Schema & Storage Specifications

### 2.1 Model Definition Schema (`${name}_mdl.yaml` / `${name}_mdl.json`)

The model defines the grid's column contracts, inferred data types, display formatting, and editability:

```yaml
version: "1.0"
model_name: "monthly_sales_mdl.yaml"
datasource_name: "monthly_sales.json"
title: "Monthly Sales Report"
is_readonly: false
source_type: "file" # "file" | "web" | "clipboard"
source_origin: "sales_q3.csv"
created_at: "2026-10-20T20:00:00Z"

columns:
  - field: "id"
    title: "ID"
    type: "text" # "text" | "number" | "currency" | "date" | "boolean"
    editable: false
    required: true
    width: 80
  - field: "product"
    title: "Product Name"
    type: "text"
    editable: true
    required: true
    width: 180
  - field: "category"
    title: "Category"
    type: "text"
    editable: true
    width: 140
  - field: "sales"
    title: "Sales Amount"
    type: "currency"
    number_format: "#,##0.00"
    editable: true
    width: 130
  - field: "quantity"
    title: "Quantity"
    type: "number"
    number_format: "#,##0"
    editable: true
    width: 100
  - field: "order_date"
    title: "Order Date"
    type: "date"
    editable: true
    width: 120
```

### 2.2 Table Data Storage (`${name}.json`)

The data payload contains the row collection:

```json
[
  {
    "id": "ORD-101",
    "product": "Ergonomic Desk",
    "category": "Furniture",
    "sales": 540.50,
    "quantity": 3,
    "order_date": "2026-09-15"
  },
  {
    "id": "ORD-102",
    "product": "4K Ultra Monitor",
    "category": "Technology",
    "sales": 1199.99,
    "quantity": 1,
    "order_date": "2026-09-16"
  }
]
```

### 2.3 Registry & SharedPreferences Storage Structure

Datasources are registered and maintained in persistent storage:

| Preference Key | Type | Description |
| :--- | :--- | :--- |
| `ai_grid_dynamic_registry` | JSON String | Array of datasource descriptors (`name`, `model_name`, `datasource_name`, `created_at`, `updated_at`, `source_type`, `source_origin`, `is_readonly`, `row_count`). |
| `ai_grid_dyn_model_${name}` | String (YAML/JSON) | Serialized column model definition for `$name`. |
| `ai_grid_dyn_data_${name}` | String (JSON) | Serialized row data list for `$name`. |
| `ai_grid_active_datasource` | String | Name of the currently active dynamic datasource. |

### 2.4 Single-Bundle YAML Import & Export

Users can export or import the entire datasource bundle as a clean, human-readable YAML document (`.agrid.yaml` or `.yaml`):

```yaml
# AiGrid Dynamic Datasource Package
metadata:
  name: "monthly_sales"
  exported_at: "2026-10-20T20:15:00Z"
  is_readonly: false
  source_type: "file"

model:
  columns:
    - field: "id"
      title: "ID"
      type: "text"
      editable: false
    - field: "sales"
      title: "Sales"
      type: "currency"
      editable: true

data:
  - id: "ORD-101"
    sales: 540.50
  - id: "ORD-102"
    sales: 1199.99
```

---

## 3. Ingestion & Tabular Data Extraction Pipeline

### 3.1 Supported File Types & Detection Matrix

| File Type | Primary Strategy | Fallback / AI Strategy | Web Mode |
| :--- | :--- | :--- | :--- |
| **CSV / TSV** | Pure-Dart Delimited Parser with auto-type heuristic | LLM repair for malformed headers | Read-only upload |
| **JSON** | Native `jsonDecode`: detects array of objects or nested `{ data: [...] }` | LLM json extraction | Read-only upload |
| **TXT** | Delimiter heuristic (tabs, commas, semicolons, fixed spaces) | LLM structured table conversion | Read-only upload |
| **Markdown (.md)** | Regex/Table Parser extracting `\| col1 \| col2 \|` blocks | LLM table extractor | Read-only upload |
| **PDF** | Multimodal Vision / Document model via `dart_mcp_core 1.3.0` (`DocumentPart` / `ImagePart`) | OCR / LLM table reconstruction | Read-only upload |
| **Word (.docx)** | Pure-Dart `archive` extraction of `word/document.xml` (`<w:tbl>` tags) | LLM doc extraction | Read-only upload |
| **Clipboard (Image/Doc)** | `ClipboardContentService` (Windows native bitmap / dropped files / base64) | Multimodal Vision model extracts table to JSON | Read-only |
| **Web HTTP GET** | Pure `http.get()` parsing JSON arrays or HTML tables | LLM extraction from HTML body | Read-only (CORS aware) |

### 3.2 Markdown Table Parser (`MarkdownTableExtractor`)
Extracts tables directly without burning LLM tokens when standard markdown pipe syntax is detected:
```dart
class MarkdownTableExtractor {
  static List<Map<String, dynamic>>? tryExtract(String markdown) {
    final lines = markdown.split('\n').map((l) => l.trim()).toList();
    // Identifies | col | col | headers, separator |-|-|, and data rows
    // Emits parsed row maps and column definitions
  }
}
```

### 3.3 HTTP GET Web Source Pipeline
* **Protocol**: HTTP GET only (no auth header required in v1).
* **Execution**:
  1. Requests URL with standard headers (`Accept: application/json, text/html`).
  2. If response is JSON array $\rightarrow$ directly builds columns & rows.
  3. If response is HTML $\rightarrow$ searches for `<table>` tags; if present, parses `<tr>/<th>/<td>` cells; otherwise feeds HTML text snippet to LLM table extractor.
* **Security & Immutability**: All web-derived datasources are marked `is_readonly = true`.

---

## 4. MCP Tools Integration (`dart_mcp_core 1.3.0`)

We register 6 dedicated tools in `AiGridSkill` to empower the embedded agent:

```
┌────────────────────────────────────────────────────────────────────────┐
│                   New Dynamic Grid MCP Tools                           │
├────────────────────────────────────────────────────────────────────────┤
│  1. `grid_create_dynamic_datasource`                                  │
│     Params: name, model (YAML/JSON), data (JSON array), isReadonly     │
│     Creates $name_mdl.yaml and $name.json in SharedPreferences,        │
│     immediately activates and displays the grid.                       │
│                                                                        │
│  2. `grid_list_datasources`                                            │
│     Params: (none)                                                     │
│     Returns all saved dynamic datasources, row counts, and origins.    │
│                                                                        │
│  3. `grid_load_datasource`                                             │
│     Params: name                                                       │
│     Switches the active DataGrid view to the requested datasource.     │
│                                                                        │
│  4. `grid_delete_datasource`                                           │
│     Params: name                                                       │
│     Deletes datasource and model from storage.                         │
│                                                                        │
│  5. `grid_fetch_web_data`                                              │
│     Params: url                                                        │
│     Executes HTTP GET, returns tabular body or structured extract.     │
│                                                                        │
│  6. `grid_export_datasource_yaml`                                      │
│     Params: name                                                       │
│     Exports combined YAML bundle package string.                       │
└────────────────────────────────────────────────────────────────────────┘
```

### 4.1 System Prompt Extensions
The agent is instructed:
- *"When the user provides an attached image, PDF, or document containing a table (e.g. 'extract table from attached picture', 'create grid from file'), read the multimodal input, detect columns and types, and invoke `grid_create_dynamic_datasource` with model YAML and row data."*
- *"When asked to fetch from a URL, use `grid_fetch_web_data`, convert the result to rows, and invoke `grid_create_dynamic_datasource` with `isReadonly: true`."*

---

## 5. Architectural Evaluation: `flutter_ui_mcp` vs `flutter_ui_mcp_core` vs Lean Embedded Assistant

A critical design consideration is whether to adopt the existing `flutter_ui_mcp` or `flutter_ui_mcp_core` packages directly from `\projects\ls\mcp_playground` instead of maintaining an embedded chat UI within `ai_grid`.

### 5.1 Deep-Dive: Package Profiles & Capabilities

| Capability / Attribute | `flutter_ui_mcp` (`FlutterUiMcp` / `McpPlayground`) | `flutter_ui_mcp_core` | Lean Embedded `AiGridAssistantPanel` |
| :--- | :--- | :--- | :--- |
| **Primary Role** | Full Standalone Agent IDE & Workbench | Shared Controllers, Dialogs, & Tools | Focused DataGrid Assistant Floating Overlay |
| **Package Size** | ~3,200 lines (`flutter_ui_mcp_widget.dart`) | 20+ Dialogs, Benchmarks, HuggingFace GGUF | ~800 lines (compact, focused) |
| **Dependencies** | **Very Heavy** (15+ packages: `llamadart`, `openai_dart`, `anthropic_sdk_dart`, `ollama_dart`, `googleai_dart`, `flutter_markdown_plus`, `flutter_widget_from_html_core`, `archive`, `path_provider`, etc.) | **Heavy** (also includes `llamadart`, LLM SDKs, `flutter_widget_from_html_core` due to embedded LLM & discover dialogs) | **Ultra-Lean** (`dart_mcp_core`, `shared_preferences`, `material_ui`) |
| **Web / WASM Compatibility** | **Restricted / Problematic** (`llamadart` binds native C++ FFI `llama.cpp` libraries) | **Restricted** (references `llamadart` in `embedded_llm_adapter.dart`) | **100% WebAssembly (`dart2wasm`) & Web compatible** |
| **Form Factor / UX** | Full-screen app layout (`Scaffold`, `AppBar`, drawer, two-site splitter, agent inspector) | Individual components (`SubPromptListEditor`, `ChatBubble`, `SettingsDrawer`, etc.) | Compact draggable floating overlay (420×540px) or mobile slide-up sheet |
| **Multimodal & Attachments** | Yes (`file_picker`, `ClipboardContentService`, thumbnail preview cards) | Yes (`ClipboardContentService`, `SubPromptListEditor`) | Yes (targeted adoption of `ClipboardContentService` & attachment cards) |
| **Feature Fit for DataGrid** | Overkill (contains Python/Node installer, benchmark eval runner, GGUF HuggingFace downloads) | Contains many unrelated IDE components | **Exact fit** (focused on data queries, math calculations, schema inspection, dynamic grids) |

---

### 5.2 Trade-Off Analysis

#### Option A: Direct Dependency on `flutter_ui_mcp`
* **Advantages**:
  - Zero UI code to write for the chat interface.
  - Instantly inherits the entire rich feature set: trajectory visualizer, agent inspector, token pricing, session memory archive.
* **Disadvantages (Critical Dealbreakers for `ai_grid` core)**:
  1. **Disastrous Dependency Bloat**: Any developer adding `ai_grid` to their application would be forced to compile `llamadart` (C++ native FFI), `flutter_widget_from_html_core`, `archive`, and all commercial LLM SDKs.
  2. **Breaks `dart2wasm` Web Target**: `ai_grid` is designed for ultra-high-speed canvas rendering across desktop and web (WASM). Native FFI in `llamadart` breaks or complicates web compilation.
  3. **Visual Incompatibility**: `McpPlayground` is hardcoded as an expansive workbench application (`Scaffold` + `AppBar` + Two-Pane Splitter). Squeezing it into a 420px floating window creates an unusable, cramped experience.

#### Option B: Direct Dependency on `flutter_ui_mcp_core`
* **Advantages**:
  - Grants access to `SubPromptListEditor`, `ClipboardContentService`, and `ChatBubble` without the top-level `McpPlayground` chrome.
* **Disadvantages**:
  - `flutter_ui_mcp_core` still imports `llamadart` (via `embedded_llm_adapter.dart`) and heavy dependencies in its `pubspec.yaml`. Thus, depending on `flutter_ui_mcp_core` does *not* solve the dependency bloat or WASM issue.

#### Option C: Recommended Architectural Strategy — **Hybrid Composable Architecture**
1. **Default Zero-Bloat Core (`ai_grid`)**:
   - Keep `ai_grid` lean, fast, and WebAssembly-safe.
   - Adopt the **pure-Dart / Flutter widget patterns** from `flutter_ui_mcp_core`:
     - Bring in `ClipboardContentService` (clean, self-contained clipboard image and file detector).
     - Implement the attachment card preview carousel and `PasteTextIntent` (Ctrl+V) handler directly inside `AiGridAssistantPanel`.
     - Forward multimodal payloads using `dart_mcp_core 1.3.0` (`ChatMessage.user` with `ChatContentPart`).
2. **Pluggable External Assistant Slot (`assistantBuilder`)**:
   - Provide an optional `assistantBuilder` on `AiGrid`:
     ```dart
     AiGrid(
       // Optional slot: users who want the full McpPlayground can plug it in directly!
       assistantBuilder: (context, controller, mcpTools) => McpPlayground(
         customLocalTools: mcpTools,
         // ...
       ),
     )
     ```
   - This allows users in the `mcp_playground` ecosystem to drop in the full `FlutterUiMcp` workbench seamlessly, while standard `ai_grid` users remain completely unburdened by heavy native dependencies!

---

## 6. Chat Window Enhancements (`AiGridAssistantPanel`)

Based on the proven patterns in `mcp_playground/flutter_ui_mcp_core`:

1. **Attachment Input Bar**:
   - `Icons.attach_file_outlined`: Opens `FilePicker` for `.csv`, `.json`, `.txt`, `.md`, `.pdf`, `.docx`, images.
   - `Icons.content_paste_go_outlined`: Direct paste button.
   - **Ctrl+V / Cmd+V Keyboard Listener**:
     - Overrides `PasteTextIntent` via `Actions` on the input `TextField`.
     - Uses `ClipboardContentService` to inspect Windows native bitmap (`CF_BITMAP`/PNG) or clipboard files.
2. **Attachment Previews**:
   - Displays horizontal scrollable cards with image thumbnails or file icons, file names, size badges, and `(X)` remove buttons.
3. **Multimodal Agent Execution**:
   - Packages attachments into `ChatMessage.user(text, parts: [...], attachments: [...])`.
   - `dart_mcp_core 1.3.0` dispatches typed `ImagePart` and `DocumentPart` payloads natively to OpenAI, Claude, Gemini, and Ollama.

---

## 7. Dynamic Grid UI & Toolbar Integration

### 7.1 `AiGrid` Configuration
```dart
AiGrid(
  dynamicGrid: true, // Enables dynamic datasource management
  controller: _controller,
  dataSource: _initialDataSource, // Optional fallback or initial dataset
  editingOptions: AiGridEditingOptions(
    enabled: true,
    mode: AiGridEditMode.row, // cell, row, or form
  ),
)
```

### 7.2 Top Toolbar (`AiGridToolbar`) Controls
When `dynamicGrid: true`:
1. **Datasources Manager Button (`Icons.table_view_outlined`)**:
   - Opens **Datasources Dialog**:
     - Search & filter existing datasources.
     - Status badges (`Read-only`, `File`, `Web`, `Rows: 1,250`).
     - Actions: **Load**, **Export YAML**, **Delete**.
     - **Import YAML Bundle** button to load a `.agrid.yaml` file.
2. **Add New Datasource Button (`Icons.add_circle_outline`)**:
   - Quick popup menu:
     - **"From File..."**: Opens file picker, auto-infers model & data.
     - **"From Web GET URL..."**: Opens modal to enter URL, fetches and previews.
     - **"From Clipboard..."**: Grabs active clipboard table/image immediately.

---

## 8. DevExtreme Editing & Persistence Write-Back Pipeline

When the user edits a cell, completes inline row editing, or saves a modal popup form:

```
[User Edits Cell / Row / Form]
               │
               ▼
[Validation Passes]
               │
               ▼
[LocalAiGridDataSource Updated in Memory]
               │
               ▼
[Is Dynamic Datasource Active?]
    ├── No  ──> standard controller commit callback
    └── Yes ──> [Is Readonly?]
                    ├── Yes ──> Disallow editing / SnackBar notice
                    └── No  ──> `AiGridDynamicStorage.updateData(name, rows)`
                                (Auto-syncs JSON to SharedPreferences)
```

---

## 9. Platform Support & Constraints

* **Desktop (Windows, macOS, Linux) & Tablets/Mobile**:
  - Full local filesystem access.
  - Native clipboard inspection (PowerShell on Windows, platform channels).
  - Unrestricted local SharedPreferences persistence.
  - Full editing and YAML export/import.
* **Web**:
  - In-browser file picking (reads raw bytes in memory).
  - SharedPreferences mapped to browser `localStorage`.
  - Web GET endpoints subject to browser **CORS restrictions** (clear notification provided if CORS header is absent).
  - Dynamic web datasources operate in **read-only mode**.

---

## 10. Future Visual Model Editor Integration (Next Version)

The schema design provides a direct foundation for a visual column editor dialog:
* Edit column `title` and `width`.
* Change inferred `type` (`text` $\leftrightarrow$ `number` $\leftrightarrow$ `date` $\leftrightarrow$ `currency`).
* Toggle `editable` and `required` flags.
* Reorder column visual indices (`editorIndex`).
* Export updated `${name}_mdl.yaml`.

---

## 11. Implementation Roadmap

1. **Step 1: Core Dependencies & Upgrade**:
   - Update `pubspec.yaml` to `dart_mcp_core: ^1.3.0`, add `file_picker: ^13.1.0` (or platform equivalent).
2. **Step 2: Dynamic Storage & Model Classes**:
   - Implement `AiGridDynamicModel`, `AiGridDynamicDescriptor`, and `AiGridDynamicStorage`.
   - Implement YAML exporter and parser.
3. **Step 3: Ingestion Utilities**:
   - Port lightweight `ClipboardContentService` and `MarkdownTableExtractor`.
   - Implement Web HTTP GET loader.
4. **Step 4: MCP Tools**:
   - Implement the 6 dynamic grid tools in `ai_grid_tools.dart`.
5. **Step 5: Toolbar & UI Dialogs**:
   - Add `dynamicGrid` prop to `AiGrid`.
   - Add Datasource Manager Dialog & New Datasource Dialog to `AiGridToolbar`.
6. **Step 6: Multimodal Chat Assistant Extension**:
   - Add file picker, clipboard paste (Ctrl+V), and attachment cards to `AiGridAssistantPanel`.
7. **Step 7: Example App & Documentation**:
   - Create `example/lib/dynamic_ai_grid_example.dart`.
   - Update `README.md` and `SKILL.md`.
