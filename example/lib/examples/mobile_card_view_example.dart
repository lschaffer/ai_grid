import 'package:material_ui/material_ui.dart';
import 'package:ai_grid/ai_grid.dart';

/// Interactive showcase demonstrating Feature 7: Mobile "Card / Feed" Responsive View.
///
/// Features demonstrated:
/// - 1-Tap Toggle between High-Performance Canvas DataGrid and Responsive Card Feed
/// - Rich card layout: Primary title, subtitle, status pills, avatars, and 2-column key-value metrics
/// - Touch & Mobile gestures: Swipe right to Edit, Swipe left to Delete (with confirmation)
/// - Unified State: Search, Sorting, and Filters seamlessly synchronize across both views
/// - Master-Detail expansion directly inside individual cards
/// - MCP AI Agent Tool: `grid_set_view_mode` ("grid" or "card")
class MobileCardViewExamplePage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final Set<AiGridFeatureSkill>? activeSkills;

  const MobileCardViewExamplePage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
    this.activeSkills,
  });

  @override
  State<MobileCardViewExamplePage> createState() =>
      _MobileCardViewExamplePageState();
}

class _MobileCardViewExamplePageState extends State<MobileCardViewExamplePage> {
  late AiGridController _controller;
  LocalAiGridDataSource? _dataSource;
  bool _isHeaderExpanded = false;
  bool _enableSwipeActions = true;

  @override
  void initState() {
    super.initState();
    _controller = AiGridController();
    _loadSampleDataset();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _loadSampleDataset() {
    final columns = <AiGridColumn>[
      const AiGridColumn(
        field: 'order_id',
        title: 'Order ID',
        type: AiGridColumnType.text,
        width: 110,
        editable: true,
      ),
      const AiGridColumn(
        field: 'customer',
        title: 'Customer Name',
        type: AiGridColumnType.text,
        width: 170,
        editable: true,
      ),
      const AiGridColumn(
        field: 'company',
        title: 'Organization',
        type: AiGridColumnType.text,
        width: 160,
        editable: true,
      ),
      const AiGridColumn(
        field: 'status',
        title: 'Status',
        type: AiGridColumnType.text,
        width: 120,
        editable: true,
      ),
      AiGridColumn(
        field: 'amount',
        title: 'Total Amount',
        type: AiGridColumnType.currency,
        width: 130,
        editable: true,
        visual: AiGridColumn.dataBar(
          color: const Color(0xFF0078D4).withValues(alpha: 0.25),
        ),
      ),
      const AiGridColumn(
        field: 'items_count',
        title: 'Items',
        type: AiGridColumnType.number,
        width: 90,
        editable: true,
      ),
      const AiGridColumn(
        field: 'date',
        title: 'Order Date',
        type: AiGridColumnType.date,
        width: 120,
        editable: true,
      ),
    ];

    final rows = <Map<String, dynamic>>[
      {
        'order_id': 'ORD-8921',
        'customer': 'Eleanor Vance',
        'company': 'Apex Logistics Ltd',
        'status': 'Completed',
        'amount': 4520.00,
        'items_count': 14,
        'date': '2026-03-12',
      },
      {
        'order_id': 'ORD-8922',
        'customer': 'Marcus Brody',
        'company': 'Horizon Cloud Tech',
        'status': 'Processing',
        'amount': 1850.50,
        'items_count': 3,
        'date': '2026-03-14',
      },
      {
        'order_id': 'ORD-8923',
        'customer': 'Sophia Sterling',
        'company': 'Nexus Global Media',
        'status': 'Shipped',
        'amount': 9200.00,
        'items_count': 28,
        'date': '2026-03-15',
      },
      {
        'order_id': 'ORD-8924',
        'customer': 'David K. Miller',
        'company': 'Quantum Dynamics',
        'status': 'Pending Approval',
        'amount': 740.00,
        'items_count': 2,
        'date': '2026-03-16',
      },
      {
        'order_id': 'ORD-8925',
        'customer': 'Amara Chen',
        'company': 'Biolink Innovations',
        'status': 'Completed',
        'amount': 12450.00,
        'items_count': 42,
        'date': '2026-03-18',
      },
      {
        'order_id': 'ORD-8926',
        'customer': 'Liam O\'Connor',
        'company': 'Vanguard Security Corp',
        'status': 'Processing',
        'amount': 3100.25,
        'items_count': 7,
        'date': '2026-03-20',
      },
      {
        'order_id': 'ORD-8927',
        'customer': 'Clara Oswald',
        'company': 'Starlight Aerospace',
        'status': 'Shipped',
        'amount': 6800.00,
        'items_count': 19,
        'date': '2026-03-22',
      },
      {
        'order_id': 'ORD-8928',
        'customer': 'Julian Rossi',
        'company': 'Crestline Asset Partners',
        'status': 'Completed',
        'amount': 540.00,
        'items_count': 1,
        'date': '2026-03-23',
      },
    ];

    _dataSource = LocalAiGridDataSource(columns: columns, initialData: rows);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = widget.isDarkMode || theme.brightness == Brightness.dark;
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Collapsible Feature Banner (matches Pic 3 standard)
          _buildShowcaseBanner(context, isDark, isMobile),

          // 2. Interactive Control Bar (horizontally scrollable, 0 overflow)
          _buildActionBar(context, isDark, isMobile),

          // 3. Dual-Mode AiGrid Viewport
          Expanded(
            child: _dataSource == null
                ? const Center(child: CircularProgressIndicator())
                : AiGrid(
                    dataSource: _dataSource!,
                    controller: _controller,
                    enableAiAssistant: true,
                    showToolbar: true,
                    enabledSkills: widget.activeSkills,
                    editingOptions: const AiGridEditingOptions(
                      enabled: true,
                      mode: AiGridEditMode.row,
                      allowAdding: true,
                      allowDeleting: true,
                      allowUpdating: true,
                    ),
                    cardViewOptions: AiGridCardViewOptions(
                      primaryField: 'customer',
                      subtitleField: 'company',
                      badgeField: 'status',
                      avatarField: 'customer',
                      enableSwipeActions: _enableSwipeActions,
                      spacing: 12.0,
                      elevation: 1.5,
                    ),
                    detailRowBuilder: (ctx, row, rowIndex) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colorScheme.surfaceContainerHighest
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Order Fulfillment Details (${row['order_id']})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Delivery: Express 2-Day Priority Courier\n'
                              'Contact: ${row['customer']} (${row['company']})\n'
                              'Total Valuation: \$${row['amount']} across ${row['items_count']} item(s)',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowcaseBanner(
    BuildContext context,
    bool isDark,
    bool isMobile,
  ) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: isMobile
          ? () => setState(() => _isHeaderExpanded = !_isHeaderExpanded)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252526) : const Color(0xFFF1F5F9),
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.view_agenda_rounded,
                    color: Color(0xFF2563EB),
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
                          Expanded(
                            child: Text(
                              'Mobile "Card / Feed" Responsive View',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade600,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!isMobile || _isHeaderExpanded) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Toggle between high-performance canvas DataGrid and touch-friendly mobile cards with swipe-to-edit and swipe-to-delete gestures.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isMobile)
                  IconButton(
                    icon: Icon(
                      _isHeaderExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                    ),
                    tooltip: _isHeaderExpanded ? 'Collapse info' : 'Expand info',
                    onPressed: () => setState(
                      () => _isHeaderExpanded = !_isHeaderExpanded,
                    ),
                  ),
              ],
            ),
            if (_isHeaderExpanded) ...[
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPill(
                      Icons.touch_app_outlined,
                      '1-Tap View Switcher',
                      'DataGrid & card feed toggle',
                    ),
                    const SizedBox(width: 8),
                    _buildPill(
                      Icons.swipe_rounded,
                      'Swipe Actions',
                      'Swipe right edit, left delete',
                    ),
                    const SizedBox(width: 8),
                    _buildPill(
                      Icons.sync_rounded,
                      'Synchronized State',
                      'Sorting & search preserved',
                    ),
                    const SizedBox(width: 8),
                    _buildPill(
                      Icons.terminal_rounded,
                      'MCP Agent Tool',
                      'grid_set_view_mode',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPill(IconData icon, String title, String subtitle) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Flexible(
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
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
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

  Widget _buildActionBar(
    BuildContext context,
    bool isDark,
    bool isMobile,
  ) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final isCard = _controller.viewMode == AiGridViewMode.card;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? const Color(0xFF2D2D2D)
                    : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Segmented Button / View Switcher
                SegmentedButton<AiGridViewMode>(
                  segments: const [
                    ButtonSegment(
                      value: AiGridViewMode.grid,
                      icon: Icon(Icons.table_chart_outlined, size: 16),
                      label: Text('DataGrid'),
                    ),
                    ButtonSegment(
                      value: AiGridViewMode.card,
                      icon: Icon(Icons.view_agenda_outlined, size: 16),
                      label: Text('Card Feed'),
                    ),
                  ],
                  selected: {_controller.viewMode},
                  onSelectionChanged: (newSet) {
                    _controller.setViewMode(newSet.first);
                  },
                ),
                const SizedBox(width: 12),
                if (isCard) ...[
                  FilterChip(
                    label: const Text('Swipe Gestures'),
                    selected: _enableSwipeActions,
                    onSelected: (val) =>
                        setState(() => _enableSwipeActions = val),
                    avatar: Icon(
                      _enableSwipeActions
                          ? Icons.check_circle_outline
                          : Icons.do_not_disturb_on_outlined,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_controller.viewRows.length} record(s)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
