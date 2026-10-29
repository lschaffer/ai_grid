import 'package:material_ui/material_ui.dart';
import 'package:ai_grid/ai_grid.dart';

/// Showcase demonstration for Feature 5:
/// Pure-Dart Excel (.xlsx) Ingestion, Multi-Sheet Selection & Schema Inference.
class ExcelImportExamplePage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const ExcelImportExamplePage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<ExcelImportExamplePage> createState() => _ExcelImportExamplePageState();
}

class _ExcelImportExamplePageState extends State<ExcelImportExamplePage> {
  late final AiGridController _controller;
  LocalAiGridDataSource? _dataSource;
  AiGridConfig? _aiConfig;
  bool _isHeaderExpanded = false;

  AiGridExcelWorkbook? _currentWorkbook;
  String _activeSheetName = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AiGridController();

    final llmConfig = AiGridEnvLoader.createLlmConfigFromEnv();
    _aiConfig = AiGridConfig(
      llmConfig: llmConfig,
      suggestedPrompts: const [
        'Which region had the highest Q4 sales?',
        'Calculate total Q1 through Q4 revenue',
        'Filter rows where Annual Target is over \$500k',
        'Summarize this imported Excel sheet',
      ],
    );

    // Load initial multi-sheet demo workbook
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRetailDemoWorkbook(showPicker: false);
    });
  }

  Future<void> _loadRetailDemoWorkbook({bool showPicker = true}) async {
    setState(() => _isLoading = true);
    try {
      final bytes = AiGridExcelParser.createSampleMultiSheetWorkbookBytes();
      final wb = AiGridExcelParser.parseBytes(
        bytes,
        fileName: 'Global_Retail_Performance_2026.xlsx',
      );

      _currentWorkbook = wb;

      AiGridExcelSheet? sheetToLoad;
      if (showPicker && mounted) {
        sheetToLoad = await AiGridExcelSheetPickerDialog.show(
          context,
          workbook: wb,
          initialSheetName: _activeSheetName.isNotEmpty
              ? _activeSheetName
              : null,
        );
      } else {
        sheetToLoad = wb.primarySheet;
      }

      if (sheetToLoad != null) {
        _applySheet(sheetToLoad);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applySheet(AiGridExcelSheet sheet) {
    _activeSheetName = sheet.name;
    final cleanSheet = sheet.name
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')
        .toLowerCase();
    final dsName = 'retail_2026_$cleanSheet';
    final now = DateTime.now();

    final descriptor = AiGridDynamicDescriptor(
      name: dsName,
      modelName: '${dsName}_mdl.yaml',
      datasourceName: '$dsName.json',
      title: '${sheet.name} (Global Retail 2026)',
      sourceType: 'file',
      sourceOrigin: 'Global_Retail_Performance_2026.xlsx',
      rowCount: sheet.rows.length,
      createdAt: now,
      updatedAt: now,
    );

    final gridColumns = sheet.columns.map((c) => c.toAiGridColumn()).toList();
    _dataSource = LocalAiGridDataSource(
      columns: gridColumns,
      initialData: sheet.rows,
    );

    _controller.loadDynamicDatasource(descriptor, gridColumns, sheet.rows);
  }

  Future<void> _handlePickLocalExcel() async {
    try {
      final sheet = await _controller.importExcel(context: context);
      if (sheet != null && mounted) {
        setState(() {
          _currentWorkbook = _controller.activeExcelWorkbook;
          _activeSheetName = sheet.name;
          _dataSource = LocalAiGridDataSource(
            columns: sheet.columns.map((c) => c.toAiGridColumn()).toList(),
            initialData: sheet.rows,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported Excel sheet "${sheet.name}"!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error importing Excel: $e')));
      }
    }
  }

  void _switchSheet(AiGridExcelSheet sheet) {
    setState(() {
      _applySheet(sheet);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 1. Collapsible Showcase Banner
          _buildShowcaseBanner(context),

          // 2. Action & Sheet Switcher Bar
          _buildActionBar(context),

          // 3. High-Performance AiGrid Viewport
          Expanded(
            child: _isLoading || _dataSource == null
                ? const Center(child: CircularProgressIndicator())
                : AiGrid(
                    dataSource: _dataSource!,
                    controller: _controller,
                    aiConfig: _aiConfig,
                    dynamicGrid: true,
                    enableAiAssistant: true,
                    showToolbar: true,
                    editingOptions: const AiGridEditingOptions(
                      enabled: true,
                      mode: AiGridEditMode.row,
                      allowAdding: true,
                      allowDeleting: true,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowcaseBanner(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isHeaderExpanded = !_isHeaderExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF107C41).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.table_chart_rounded,
                      color: Color(0xFF107C41),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Feature 5: Pure-Dart Excel (.xlsx) Import',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'NEW',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Native OpenXML spreadsheet parser with multi-sheet picker dialog, automatic type inference, and 100% WASM compatibility.',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isHeaderExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_isHeaderExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    _buildFeaturePill(
                      Icons.memory_rounded,
                      'Pure Dart Engine',
                      'Zero FFI / WASM Safe',
                    ),
                    const SizedBox(width: 12),
                    _buildFeaturePill(
                      Icons.layers_rounded,
                      'Multi-Sheet Dialog',
                      'Preview & Select Worksheets',
                    ),
                    const SizedBox(width: 12),
                    _buildFeaturePill(
                      Icons.auto_awesome_rounded,
                      'Type Inference',
                      'Dates, Currency & Numbers',
                    ),
                    const SizedBox(width: 12),
                    _buildFeaturePill(
                      Icons.swap_horiz_rounded,
                      'Full Roundtrip',
                      'Export Back to .xlsx Anytime',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeaturePill(IconData icon, String title, String subtitle) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Pick local xlsx
          FilledButton.icon(
            icon: const Icon(Icons.file_open_rounded, size: 16),
            label: const Text('Pick Local .xlsx File'),
            onPressed: _handlePickLocalExcel,
          ),

          // Open multi-sheet picker dialog
          OutlinedButton.icon(
            icon: const Icon(
              Icons.table_view_rounded,
              size: 16,
              color: Color(0xFF107C41),
            ),
            label: const Text('Sheet Picker Dialog'),
            onPressed: () => _loadRetailDemoWorkbook(showPicker: true),
          ),

          // Multi-sheet switcher dropdown
          if (_currentWorkbook != null && _currentWorkbook!.isMultiSheet) ...[
            Builder(
              builder: (context) {
                final sheets = _currentWorkbook!.sheets;
                final sheetNames = sheets.map((s) => s.name).toSet();
                final safeValue = sheetNames.contains(_activeSheetName)
                    ? _activeSheetName
                    : (sheets.isNotEmpty ? sheets.first.name : null);
                if (safeValue == null) return const SizedBox.shrink();

                return Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: safeValue,
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded),
                      items: sheets.map((s) {
                        return DropdownMenuItem<String>(
                          value: s.name,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.description_outlined,
                                size: 14,
                                color: Color(0xFF107C41),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                s.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '(${s.rowCount} rows)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final s = _currentWorkbook!.getSheet(val);
                          if (s != null) _switchSheet(s);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ],

          // Export back to Excel button
          IconButton(
            icon: const Icon(Icons.file_download_outlined, size: 18),
            tooltip: 'Export Table Back to Excel (.xlsx)',
            onPressed: () => _controller.export(),
          ),
        ],
      ),
    );
  }
}
