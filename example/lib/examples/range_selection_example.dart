import 'package:material_ui/material_ui.dart';
import 'package:ai_grid/ai_grid.dart';

/// Showcase demonstration for Feature 4:
/// Cell Range Selection & Bidirectional Spreadsheet Copy/Paste.
class RangeSelectionExamplePage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const RangeSelectionExamplePage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<RangeSelectionExamplePage> createState() =>
      _RangeSelectionExamplePageState();
}

class _RangeSelectionExamplePageState extends State<RangeSelectionExamplePage> {
  late final AiGridController _controller;
  late final LocalAiGridDataSource _dataSource;
  AiGridConfig? _aiConfig;

  @override
  void initState() {
    super.initState();
    _controller = AiGridController();

    final llmConfig = AiGridEnvLoader.createLlmConfigFromEnv();
    _aiConfig = AiGridConfig(
      llmConfig: llmConfig,
      suggestedPrompts: const [
        'Select low margin cells',
        'Select highest margin cells',
        'Select Q1-Q2 Revenue (Rows 0-3)',
        'Select all quarterly revenue',
        'Summary of selected range',
      ],
    );

    _controller.editingOptions = const AiGridEditingOptions(
      enabled: false,
    );

    final columns = [
      const AiGridColumn(
        field: 'product',
        title: 'Product / Line Item',
        width: 180,
        type: AiGridColumnType.text,
      ),
      const AiGridColumn(
        field: 'region',
        title: 'Region',
        width: 120,
        type: AiGridColumnType.select,
        selectOptions: ['North America', 'EMEA', 'APAC', 'LATAM'],
      ),
      const AiGridColumn(
        field: 'q1_sales',
        title: 'Q1 Revenue',
        width: 140,
        type: AiGridColumnType.currency,
        editable: false,
      ),
      const AiGridColumn(
        field: 'q2_sales',
        title: 'Q2 Revenue',
        width: 140,
        type: AiGridColumnType.currency,
        editable: false,
      ),
      const AiGridColumn(
        field: 'q3_sales',
        title: 'Q3 Revenue',
        width: 140,
        type: AiGridColumnType.currency,
        editable: false,
      ),
      const AiGridColumn(
        field: 'q4_sales',
        title: 'Q4 Revenue',
        width: 140,
        type: AiGridColumnType.currency,
        editable: false,
      ),
      const AiGridColumn(
        field: 'total',
        title: 'Annual Total',
        width: 150,
        type: AiGridColumnType.currency,
      ),
      AiGridColumn(
        field: 'margin',
        title: 'Op. Margin',
        width: 130,
        type: AiGridColumnType.number,
        numberFormat: '0.0%',
        cellStyle: (val, row) {
          final m = (val is num) ? val.toDouble() : 0.0;
          if (m >= 0.30) {
            return const TextStyle(
              color: Color(0xFF2E7D32),
              fontWeight: FontWeight.bold,
            );
          } else if (m < 0.15) {
            return const TextStyle(
              color: Color(0xFFD32F2F),
              fontWeight: FontWeight.bold,
            );
          }
          return null;
        },
      ),
    ];

    final sampleData = <Map<String, dynamic>>[
      {
        'product': 'Cloud Infrastructure',
        'region': 'North America',
        'q1_sales': 14200.00,
        'q2_sales': 16500.00,
        'q3_sales': 18900.00,
        'q4_sales': 22400.00,
        'total': 72000.00,
        'margin': 0.38,
      },
      {
        'product': 'AI Assistant Suite',
        'region': 'North America',
        'q1_sales': 8900.00,
        'q2_sales': 12300.00,
        'q3_sales': 17800.00,
        'q4_sales': 26500.00,
        'total': 65500.00,
        'margin': 0.44,
      },
      {
        'product': 'Database Appliances',
        'region': 'EMEA',
        'q1_sales': 12500.00,
        'q2_sales': 13100.00,
        'q3_sales': 11800.00,
        'q4_sales': 14200.00,
        'total': 51600.00,
        'margin': 0.22,
      },
      {
        'product': 'Enterprise Support',
        'region': 'EMEA',
        'q1_sales': 6200.00,
        'q2_sales': 6400.00,
        'q3_sales': 6800.00,
        'q4_sales': 7100.00,
        'total': 26500.00,
        'margin': 0.12,
      },
      {
        'product': 'Security & Compliance',
        'region': 'APAC',
        'q1_sales': 9400.00,
        'q2_sales': 10800.00,
        'q3_sales': 11900.00,
        'q4_sales': 13400.00,
        'total': 45500.00,
        'margin': 0.31,
      },
      {
        'product': 'Mobile Edge Gateways',
        'region': 'APAC',
        'q1_sales': 4800.00,
        'q2_sales': 5200.00,
        'q3_sales': 4900.00,
        'q4_sales': 5800.00,
        'total': 20700.00,
        'margin': 0.18,
      },
      {
        'product': 'IoT Sensor Hubs',
        'region': 'LATAM',
        'q1_sales': 3200.00,
        'q2_sales': 3800.00,
        'q3_sales': 4100.00,
        'q4_sales': 4600.00,
        'total': 15700.00,
        'margin': 0.09,
      },
      {
        'product': 'Analytics Workbench',
        'region': 'LATAM',
        'q1_sales': 7500.00,
        'q2_sales': 8900.00,
        'q3_sales': 9600.00,
        'q4_sales': 11200.00,
        'total': 37200.00,
        'margin': 0.34,
      },
    ];

    _dataSource = LocalAiGridDataSource(
      columns: columns,
      initialData: sampleData,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDarkMode;

    return ScaffoldMessenger(
      child: Scaffold(
        body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252526) : const Color(0xFFF1F5F9),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.select_all_rounded,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cell Range Selection & Spreadsheet Copy/Paste',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Click & drag across cells, use Shift+Arrows to expand range, Ctrl+C to copy TSV to Excel, Ctrl+V to paste values, and inspect instant stats.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Shortcut Actions Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.crop_free_rounded, size: 16),
                    label: const Text('Select Q1–Q2 Revenue (Rows 0–3)'),
                    onPressed: () {
                      _controller.selectCellRange(
                        anchorRow: 0,
                        anchorColumn: 'q1_sales',
                        extentRow: 3,
                        extentColumn: 'q2_sales',
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.border_all_rounded, size: 16),
                    label: const Text('Select All Quarterly Data'),
                    onPressed: () {
                      _controller.selectCellRange(
                        anchorRow: 0,
                        anchorColumn: 'q1_sales',
                        extentRow: 7,
                        extentColumn: 'q4_sales',
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy Selection (Ctrl+C)'),
                    onPressed: () async {
                      final ok = await _controller.copySelectedRangeToClipboard(
                        includeHeaders: true,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Copied selection with headers to clipboard! Paste into Excel or Google Sheets.'
                                  : 'Select a range of cells first.',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    tooltip: 'Clear Selection (Esc)',
                    onPressed: () {
                      _controller.clearCellRangeSelection();
                    },
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('AI: Select High Margin Cells'),
                    onPressed: () {
                      _controller.selectCellRange(
                        anchorRow: 0,
                        anchorColumn: 'margin',
                        extentRow: 1,
                        extentColumn: 'margin',
                      );
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        const SnackBar(
                          content: Text('AI selected top margin performers'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Main Interactive DataGrid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: AiGrid(
                dataSource: _dataSource,
                controller: _controller,
                aiConfig: _aiConfig,
                cellSelection: true,
                enableCopy: true,
                enablePaste: true,
                showSelectionStatusBar: true,
                enableAiAssistant: true,
                autoSave: false,
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
