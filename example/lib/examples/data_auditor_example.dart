import 'package:material_ui/material_ui.dart';
import 'package:ai_grid/ai_grid.dart';

/// Interactive showcase demonstrating Feature 6: AI Data Auditor & Cleaner.
///
/// Features demonstrated:
/// - Real-time Data Quality Health Score (0-100%)
/// - Anomaly detection: Duplicates, Dirty Currency/Numbers, Mixed Date Formats,
///   Inconsistent Whitespace, Missing Values, and Statistical Outliers
/// - Interactive modal dialog with per-issue fixes and 1-Click "Clean All"
/// - Native MCP tools for AI Agent integration: `grid_audit_data` & `grid_apply_data_cleanse`
class DataAuditorExamplePage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const DataAuditorExamplePage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<DataAuditorExamplePage> createState() => _DataAuditorExamplePageState();
}

class _DataAuditorExamplePageState extends State<DataAuditorExamplePage> {
  late AiGridController _controller;
  LocalAiGridDataSource? _dataSource;
  AiGridAuditReport? _currentReport;
  bool _isBannerExpanded = true;

  @override
  void initState() {
    super.initState();
    _controller = AiGridController();
    _loadDirtyDataset();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _loadDirtyDataset() {
    final columns = <AiGridColumn>[
      const AiGridColumn(
        field: 'order_id',
        title: 'Order ID',
        type: AiGridColumnType.text,
        width: 110,
        editable: true,
      ),
      const AiGridColumn(
        field: 'order_date',
        title: 'Order Date',
        type: AiGridColumnType.text,
        width: 130,
        editable: true,
      ),
      const AiGridColumn(
        field: 'region',
        title: 'Region',
        type: AiGridColumnType.text,
        width: 140,
        editable: true,
      ),
      AiGridColumn(
        field: 'sales',
        title: 'Sales Amount',
        type: AiGridColumnType.currency,
        width: 140,
        editable: true,
        visual: AiGridColumn.dataBar(
          color: const Color(0xFF107C41).withValues(alpha: 0.25),
        ),
      ),
      const AiGridColumn(
        field: 'profit',
        title: 'Profit',
        type: AiGridColumnType.currency,
        width: 130,
        editable: true,
      ),
      const AiGridColumn(
        field: 'postal_code',
        title: 'Postal Code',
        type: AiGridColumnType.text,
        width: 130,
        editable: true,
      ),
    ];

    // Intentionally noisy, realistic tabular dataset
    final rows = <Map<String, dynamic>>[
      {
        'order_id': 'ORD-101',
        'order_date': '2026-01-15',
        'region': 'North America',
        'sales': 120.50,
        'profit': 25.0,
        'postal_code': '10001',
      },
      {
        'order_id': 'ORD-102',
        'order_date': '02/18/2026', // Mixed date format (MM/dd/yyyy)
        'region': '  EMEA  ', // Inconsistent whitespace
        'sales': r'$1,450.00', // Dirty currency string
        'profit': 180.0,
        'postal_code': null, // Missing value
      },
      {
        'order_id': 'ORD-103',
        'order_date': '15-03-2026', // Mixed date format (dd-MM-yyyy)
        'region': 'APAC',
        'sales': '350.00',
        'profit': 98000.0, // Statistical outlier
        'postal_code': '90210',
      },
      {
        'order_id': 'ORD-104',
        'order_date': '2026-04-10',
        'region': 'LATAM',
        'sales': 85.0,
        'profit': 12.0,
        'postal_code': '33101',
      },
      {
        'order_id': 'ORD-105',
        'order_date': '2026-05-01',
        'region': 'North America',
        'sales': 95.0,
        'profit': 15.0,
        'postal_code': '10002',
      },
      {
        'order_id': 'ORD-106',
        'order_date': '2026-06-12',
        'region': '  EMEA',
        'sales': 110.0,
        'profit': 18.0,
        'postal_code': 'SW1A 1AA',
      },
      {
        'order_id': 'ORD-107',
        'order_date': '2026-07-04',
        'region': 'APAC',
        'sales': 130.0,
        'profit': 22.0,
        'postal_code': '100-0001',
      },
      {
        'order_id': 'ORD-108',
        'order_date': '2026-08-20',
        'region': 'LATAM ',
        'sales': 75.0,
        'profit': 10.0,
        'postal_code': null, // Missing value
      },
      {
        'order_id': 'ORD-109',
        'order_date': '2026-09-14',
        'region': 'North America',
        'sales': 60.0,
        'profit': 8.0,
        'postal_code': '10003',
      },
      {
        'order_id': 'ORD-101', // Exact duplicate record of first row
        'order_date': '2026-01-15',
        'region': 'North America',
        'sales': 120.50,
        'profit': 25.0,
        'postal_code': '10001',
      },
    ];

    final now = DateTime.now();
    final descriptor = AiGridDynamicDescriptor(
      name: 'noisy_retail_orders',
      modelName: 'noisy_retail_orders_mdl.yaml',
      datasourceName: 'noisy_retail_orders.json',
      title: 'Noisy Retail Orders (Pre-Clean)',
      sourceType: 'file',
      sourceOrigin: 'retail_orders_dirty.csv',
      rowCount: rows.length,
      createdAt: now,
      updatedAt: now,
    );

    _dataSource = LocalAiGridDataSource(columns: columns, initialData: rows);

    _controller.loadDynamicDatasource(descriptor, columns, rows);
    _refreshScore();
  }

  void _refreshScore() {
    setState(() {
      _currentReport = _controller.auditData();
    });
  }

  Future<void> _openAuditorDialog() async {
    final result = await _controller.showDataAuditorDialog(context);
    if (result != null && mounted) {
      _refreshScore();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
    } else if (mounted) {
      _refreshScore();
    }
  }

  void _cleanAllAnomalies() {
    final res = _controller.cleanAllData();
    _refreshScore();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(res.message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = widget.isDarkMode || theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : null,
      body: Column(
        children: [
          // 1. Collapsible Showcase Banner
          _buildShowcaseBanner(context, isDark),

          // 2. Action & Health Score Bar
          _buildActionBar(context, isDark),

          // 3. High-Performance AiGrid Viewport
          Expanded(
            child: _dataSource == null
                ? const Center(child: CircularProgressIndicator())
                : AiGrid(
                    dataSource: _dataSource!,
                    controller: _controller,
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

  Widget _buildShowcaseBanner(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.25)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _isBannerExpanded = !_isBannerExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF107C41).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.health_and_safety_rounded,
                      color: Color(0xFF107C41),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Row(
                      children: [
                        Text(
                          'Feature 6: AI Data Auditor & Cleaner',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '• Anomaly detection, missing value imputation, type hygiene & 1-click remediation',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isBannerExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_isBannerExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildPill(
                    Icons.rule_rounded,
                    'Anomaly Profiling',
                    'Duplicates, missing values & IQR outliers',
                    colorScheme,
                    isDark,
                  ),
                  _buildPill(
                    Icons.auto_fix_high_rounded,
                    '1-Click Clean',
                    'Strips \$ symbols, trims whitespace, standardizes dates',
                    colorScheme,
                    isDark,
                  ),
                  _buildPill(
                    Icons.bolt_rounded,
                    'MCP Agent Tools',
                    'grid_audit_data & grid_apply_data_cleanse',
                    colorScheme,
                    isDark,
                  ),
                  _buildPill(
                    Icons.verified_outlined,
                    'Health Score Meter',
                    'Continuous 0-100% table quality index',
                    colorScheme,
                    isDark,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPill(
    IconData icon,
    String title,
    String subtitle,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHigh : colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(
            alpha: isDark ? 0.3 : 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF107C41)),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final score = _currentReport?.overallScore ?? 100;

    Color scoreColor;
    if (score >= 90) {
      scoreColor = const Color(0xFF107C41);
    } else if (score >= 70) {
      scoreColor = Colors.teal;
    } else if (score >= 50) {
      scoreColor = Colors.orange.shade800;
    } else {
      scoreColor = Colors.red.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerLow : colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Open Auditor Dialog
          FilledButton.icon(
            icon: const Icon(Icons.health_and_safety_rounded, size: 16),
            label: const Text('Open Data Auditor & Cleaner'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF107C41),
              foregroundColor: Colors.white,
            ),
            onPressed: _openAuditorDialog,
          ),

          // 1-Click Clean All
          OutlinedButton.icon(
            icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
            label: const Text('1-Click AI Auto-Clean'),
            onPressed: _cleanAllAnomalies,
          ),

          // Reset dirty dataset
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            tooltip: 'Reload Dirty Sample Dataset',
            onPressed: () {
              _loadDirtyDataset();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reloaded dirty sample dataset.')),
              );
            },
          ),

          // Live Health Score Pill
          if (_currentReport != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    score >= 90
                        ? Icons.verified_rounded
                        : Icons.warning_amber_rounded,
                    size: 14,
                    color: scoreColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Health: $score%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${_currentReport!.issueCount} issues, ${_currentReport!.cleanRows}/${_currentReport!.totalRows} clean rows)',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
