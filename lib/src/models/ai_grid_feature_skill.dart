/// Modular feature skills for [AiGrid] and MCP tool exposure.
///
/// Allows developers and AI agents to selectively activate and deactivate
/// feature skill bundles at runtime to optimize LLM context window usage,
/// focus agent decision-making, and tailor available capabilities.
enum AiGridFeatureSkill {
  /// Foundational DataGrid capabilities: schema, row inspection, filtering,
  /// sorting, paging, search, column visibility, calculations, and data export.
  /// Always active by default.
  core(
    id: 'core',
    displayName: 'Core DataGrid',
    description:
        'Schema inspection, filtering, sorting, pagination, search, column visibility, exact Dart calculations, and exports.',
    isAlwaysOn: true,
  ),

  /// Dynamic Pivot tables, multi-metric cross-tabulation, and split-pane charts.
  pivot(
    id: 'pivot',
    displayName: 'Pivot & Charts',
    description:
        'Dynamic Pivot matrix with banded split headers, multi-metric cross-tabulation, and interactive split-panel charts.',
  ),

  /// Runtime dynamic datasets, file uploads (CSV, TSV, PDF), web APIs, and persistence.
  dynamicGrid(
    id: 'dynamic_grid',
    displayName: 'Dynamic Datasources',
    description:
        'Runtime dynamic schema ingestion from CSV, TSV, PDF, Web REST endpoints, and clipboard.',
  ),

  /// Cell data bars, color scales, threshold highlights, and visual styling rules.
  conditionalFormatting(
    id: 'conditional_formatting',
    displayName: 'Conditional Formatting',
    description:
        'Cell data bars, color scales, threshold highlights, and custom visual styling rules.',
  ),

  /// Excel-like multi-cell rectangular range selection, keyboard shortcuts, and TSV copy/paste.
  rangeSelection(
    id: 'range_selection',
    displayName: 'Range Selection & Clipboard',
    description:
        'Spreadsheet-like cell range selection, keyboard shortcuts, stats, and clipboard TSV integration.',
  ),

  /// Prompt-driven per-row synthesized columns with category options and batch evaluation.
  smartColumns(
    id: 'smart_columns',
    displayName: 'AI Smart Columns',
    description:
        'Prompt-driven per-row synthesized columns with category options and batch evaluation.',
  ),

  /// Expandable row details, nested DataGrids, and custom detail cards.
  masterDetail(
    id: 'master_detail',
    displayName: 'Master-Detail Child Rows',
    description:
        'Expandable row details, nested DataGrids, and custom detail cards.',
  ),

  /// Native Pure-Dart Excel (.xlsx/.xls) workbook ingestion, sheet selection, and header mapping.
  excelImport(
    id: 'excel_import',
    displayName: 'Excel Import',
    description:
        'Native workbook reading, multi-sheet selection, formula evaluation, and schema inference.',
  ),

  /// Tabular anomaly detection, data health scoring (0-100%), and 1-click remediation.
  dataAuditor(
    id: 'data_auditor',
    displayName: 'AI Data Auditor & Cleaner',
    description:
        'Anomaly detection, missing value imputation, type hygiene, and 1-click remediation.',
  ),

  /// Mobile-responsive card feed layout, swipe actions, and contextual AI menu triggers.
  cardView(
    id: 'card_view',
    displayName: 'Mobile Card View & Actions',
    description:
        'Mobile card feed view, swipe actions, and contextual AI menu quick triggers.',
  );

  final String id;
  final String displayName;
  final String description;
  final bool isAlwaysOn;

  const AiGridFeatureSkill({
    required this.id,
    required this.displayName,
    required this.description,
    this.isAlwaysOn = false,
  });

  /// Resolves an [AiGridFeatureSkill] from its [id] or [name].
  static AiGridFeatureSkill? fromId(String id) {
    final lower = id.toLowerCase().trim();
    for (final skill in AiGridFeatureSkill.values) {
      if (skill.id.toLowerCase() == lower ||
          skill.name.toLowerCase() == lower ||
          'ai_grid_${skill.id}'.toLowerCase() == lower) {
        return skill;
      }
    }
    return null;
  }
}

