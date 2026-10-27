import 'package:material_ui/material_ui.dart';
import 'package:ai_grid/ai_grid.dart';

class ConditionalFormattingExamplePage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const ConditionalFormattingExamplePage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<ConditionalFormattingExamplePage> createState() =>
      _ConditionalFormattingExamplePageState();
}

class _ConditionalFormattingExamplePageState
    extends State<ConditionalFormattingExamplePage> {
  late final AiGridController _controller;
  late LocalAiGridDataSource _dataSource;
  AiGridConfig? _aiConfig;

  bool _showDataBars = true;
  bool _showSparklines = true;
  bool _showRowHighlights = true;
  bool _showTextFormatting = true;

  @override
  void initState() {
    super.initState();
    _controller = AiGridController();

    final llmConfig = AiGridEnvLoader.createLlmConfigFromEnv();
    _aiConfig = AiGridConfig(
      llmConfig: llmConfig,
      suggestedPrompts: const [
        'Highlight profit below 0 in red',
        'Apply data bars to sales',
        'Select negative profit cells',
        'Highlight margin >= 35%',
        'Clear all conditional formatting',
      ],
    );

    _controller.editingOptions = const AiGridEditingOptions(
      enabled: false,
    );

    _setupDataSource();
    _applyActiveFormatting();
  }

  void _setupDataSource() {
    final columns = [
      const AiGridColumn(
        field: 'sku',
        title: 'SKU / Product',
        width: 170,
        type: AiGridColumnType.text,
      ),
      const AiGridColumn(
        field: 'category',
        title: 'Category',
        width: 140,
        type: AiGridColumnType.select,
        selectOptions: ['Hardware', 'Software', 'Cloud Services', 'Consulting'],
      ),
      AiGridColumn(
        field: 'sales',
        title: 'Sales (\$)',
        width: 150,
        type: AiGridColumnType.currency,
        numberFormat: '#,##0.00',
        aggregateType: AiGridAggregateType.sum,
        visual: _showDataBars
            ? AiGridColumn.dataBar(
                color: const Color(0xFF1E88E5), // Blue bar
                min: 0,
                max: 12000,
                showText: true,
              )
            : null,
      ),
      AiGridColumn(
        field: 'profit',
        title: 'Net Profit (\$)',
        width: 160,
        type: AiGridColumnType.currency,
        numberFormat: '#,##0.00',
        aggregateType: AiGridAggregateType.sum,
        visual: _showDataBars
            ? AiGridColumn.dataBar(
                color: const Color(0xFF43A047), // Positive green
                negativeColor: const Color(0xFFE53935), // Negative red
                showText: true,
              )
            : null,
        cellColor: _showTextFormatting
            ? (val, row) {
                if (val is num && val < 0) return const Color(0xFFE53935);
                if (val is num && val > 2000) return const Color(0xFF2E7D32);
                return null;
              }
            : null,
      ),
      AiGridColumn(
        field: 'margin',
        title: 'Margin Track',
        width: 140,
        type: AiGridColumnType.number,
        visual: AiGridColumn.progress(
          fractionOf: (row) {
            final p = row['profit'] as num? ?? 0;
            final s = row['sales'] as num? ?? 1;
            if (s <= 0) return 0.0;
            return (p / s).clamp(0.0, 1.0);
          },
          color: const Color(0xFF00897B),
          showText: true,
        ),
      ),
      if (_showSparklines)
        const AiGridColumn(
          field: 'trend',
          title: '12M Trend (Sparkline)',
          width: 170,
          type: AiGridColumnType.sparkline,
        ),
      const AiGridColumn(
        field: 'status',
        title: 'Health Status',
        width: 130,
        type: AiGridColumnType.text,
      ),
    ];

    final sampleData = [
      {
        'sku': 'Cloud Enterprise E5',
        'category': 'Cloud Services',
        'sales': 11450.00,
        'profit': 3420.00,
        'margin': 0.30,
        'trend': [20, 25, 30, 28, 35, 42, 50, 58, 65, 72, 85, 95],
        'status': 'Strong Growth',
      },
      {
        'sku': 'DevOps Pipeline Pro',
        'category': 'Software',
        'sales': 8920.00,
        'profit': 2250.00,
        'margin': 0.25,
        'trend': [40, 38, 45, 50, 48, 55, 60, 68, 70, 75, 80, 88],
        'status': 'Stable',
      },
      {
        'sku': 'Edge AI Inference Box',
        'category': 'Hardware',
        'sales': 6400.00,
        'profit': -820.00,
        'margin': -0.12,
        'trend': [65, 60, 52, 45, 40, 35, 30, 28, 25, 20, 18, 15],
        'status': 'Critical Loss',
      },
      {
        'sku': 'Security Audit 2026',
        'category': 'Consulting',
        'sales': 9800.00,
        'profit': 4100.00,
        'margin': 0.42,
        'trend': [15, 20, 22, 35, 40, 55, 60, 72, 80, 90, 95, 100],
        'status': 'High Margin',
      },
      {
        'sku': 'Legacy Database Sync',
        'category': 'Software',
        'sales': 3200.00,
        'profit': -450.00,
        'margin': -0.14,
        'trend': [30, 28, 25, 22, 20, 18, 15, 12, 10, 8, 5, 4],
        'status': 'Phasing Out',
      },
      {
        'sku': 'Kubernetes Gateway',
        'category': 'Cloud Services',
        'sales': 7800.00,
        'profit': 1850.00,
        'margin': 0.24,
        'trend': [25, 30, 35, 40, 42, 48, 50, 54, 58, 62, 65, 70],
        'status': 'Growing',
      },
      {
        'sku': 'Server Rack Module X',
        'category': 'Hardware',
        'sales': 10500.00,
        'profit': 850.00,
        'margin': 0.08,
        'trend': [50, 52, 48, 50, 55, 54, 50, 52, 48, 50, 52, 55],
        'status': 'Low Margin',
      },
      {
        'sku': 'AI Model Fine-Tuning',
        'category': 'Consulting',
        'sales': 12200.00,
        'profit': 5500.00,
        'margin': 0.45,
        'trend': [10, 18, 25, 35, 48, 62, 75, 88, 100, 115, 130, 145],
        'status': 'Star Performer',
      },
    ];

    _dataSource = LocalAiGridDataSource(
      columns: columns,
      initialData: sampleData,
    );
    if (_controller.isAttached) {
      _controller.updateColumns(columns, notify: false);
    }
  }

  void _applyActiveFormatting() {
    _controller.clearConditionalFormats();

    if (_showRowHighlights) {
      // Highlight rows with negative profit in a subtle red tint
      _controller.addConditionalFormat(
        AiGridConditionalFormat.highlight(
          field: 'profit',
          operator: '<',
          targetValue: 0,
          backgroundColor: widget.isDarkMode
              ? const Color(0x35E53935)
              : const Color(0x18E53935),
          applyToRow: true,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(covariant ConditionalFormattingExamplePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode) {
      _applyActiveFormatting();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = widget.isDarkMode;

    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: isDark
          ? const Color(0xFF121418)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Feature 2: Conditional Formatting & Visuals',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Data Bars, Bidirectional Profit Bars, Progress Tracks & In-Cell Sparklines',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Formatting Toggles Ribbon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                  : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : Colors.grey.shade200,
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    avatar: const Icon(Icons.bar_chart_rounded, size: 16),
                    label: const Text('Data Bars'),
                    selected: _showDataBars,
                    onSelected: (val) {
                      setState(() {
                        _showDataBars = val;
                        _setupDataSource();
                        _applyActiveFormatting();
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    avatar: const Icon(Icons.show_chart_rounded, size: 16),
                    label: const Text('Sparklines'),
                    selected: _showSparklines,
                    onSelected: (val) {
                      setState(() {
                        _showSparklines = val;
                        _setupDataSource();
                        _applyActiveFormatting();
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    avatar: const Icon(Icons.warning_amber_rounded, size: 16),
                    label: const Text('Row Alert Highlights'),
                    selected: _showRowHighlights,
                    onSelected: (val) {
                      setState(() {
                        _showRowHighlights = val;
                        _applyActiveFormatting();
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    avatar: const Icon(Icons.format_color_text_rounded, size: 16),
                    label: const Text('Conditional Text Colors'),
                    selected: _showTextFormatting,
                    onSelected: (val) {
                      setState(() {
                        _showTextFormatting = val;
                        _setupDataSource();
                        _applyActiveFormatting();
                      });
                    },
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('AI: Highlight Margins'),
                    onPressed: () {
                      _controller.addConditionalFormat(
                        AiGridConditionalFormat.highlight(
                          field: 'margin',
                          operator: '>=',
                          targetValue: 0.30,
                          textColor: const Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold,
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('AI applied: Highlight margins >= 30% in bold green'),
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
