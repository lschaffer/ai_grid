import 'package:material_ui/material_ui.dart';
import 'package:ai_grid/ai_grid.dart';

/// Interactive showcase demonstrating Feature 8: Contextual Row/Cell AI Actions.
///
/// Features demonstrated:
/// - Desktop Right-Click & Mobile Long-Press contextual action menus
/// - Built-in AI Actions: "Ask AI About Record", "Draft Message / Email", "Explain Outlier"
/// - 1-Click "Filter Similar Records" directly from any cell
/// - Clipboard Integration: Copy cell value or entire row JSON
/// - Custom Developer Actions: Register custom business handlers with conditional visibility
/// - Execution Activity Log: Real-time visual timeline of triggered actions
/// - MCP AI Agent Tool: `grid_execute_context_action`
class ContextualAiExamplePage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final Set<AiGridFeatureSkill>? activeSkills;

  const ContextualAiExamplePage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
    this.activeSkills,
  });

  @override
  State<ContextualAiExamplePage> createState() =>
      _ContextualAiExamplePageState();
}

class _ContextualAiExamplePageState extends State<ContextualAiExamplePage> {
  late AiGridController _controller;
  LocalAiGridDataSource? _dataSource;
  bool _isHeaderExpanded = false;
  final List<String> _activityLog = <String>[];

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

  void _logAction(String message) {
    setState(() {
      final time = DateTime.now().toIso8601String().substring(11, 19);
      _activityLog.insert(0, '[$time] $message');
      if (_activityLog.length > 20) _activityLog.removeLast();
    });
  }

  void _loadSampleDataset() {
    final columns = <AiGridColumn>[
      const AiGridColumn(
        field: 'ticket_id',
        title: 'Ticket #',
        type: AiGridColumnType.text,
        width: 100,
        editable: true,
      ),
      const AiGridColumn(
        field: 'client',
        title: 'Client',
        type: AiGridColumnType.text,
        width: 150,
        editable: true,
      ),
      const AiGridColumn(
        field: 'category',
        title: 'Category',
        type: AiGridColumnType.text,
        width: 130,
        editable: true,
      ),
      const AiGridColumn(
        field: 'severity',
        title: 'Severity',
        type: AiGridColumnType.text,
        width: 110,
        editable: true,
      ),
      const AiGridColumn(
        field: 'sla_hours',
        title: 'SLA (hrs)',
        type: AiGridColumnType.number,
        width: 100,
        editable: true,
      ),
      AiGridColumn(
        field: 'impact_score',
        title: 'Impact Score',
        type: AiGridColumnType.number,
        width: 120,
        editable: true,
        visual: AiGridColumn.dataBar(
          color: const Color(0xFFE11D48).withValues(alpha: 0.25),
        ),
      ),
      const AiGridColumn(
        field: 'summary',
        title: 'Issue Summary',
        type: AiGridColumnType.text,
        width: 280,
        editable: true,
      ),
    ];

    final rows = <Map<String, dynamic>>[
      {
        'ticket_id': 'INC-501',
        'client': 'Stripe Connect',
        'category': 'Payment Gateway',
        'severity': 'Critical',
        'sla_hours': 2,
        'impact_score': 98.5,
        'summary': 'Intermittent 504 Gateway Timeouts during webhook dispatch',
      },
      {
        'ticket_id': 'INC-502',
        'client': 'Acme Corp',
        'category': 'Authentication',
        'severity': 'High',
        'sla_hours': 4,
        'impact_score': 74.0,
        'summary': 'SAML SSO certificate expiration warning in production',
      },
      {
        'ticket_id': 'INC-503',
        'client': 'Fintech Global',
        'category': 'Payment Gateway',
        'severity': 'Critical',
        'sla_hours': 1,
        'impact_score': 99.0,
        'summary': 'Double charge reported on high-value wire settlement',
      },
      {
        'ticket_id': 'INC-504',
        'client': 'Veloce Logistics',
        'category': 'API Performance',
        'severity': 'Medium',
        'sla_hours': 8,
        'impact_score': 45.0,
        'summary': 'Batch geocoding latency increased by 180ms',
      },
      {
        'ticket_id': 'INC-505',
        'client': 'Hyperion Retail',
        'category': 'Database',
        'severity': 'High',
        'sla_hours': 4,
        'impact_score': 82.0,
        'summary': 'Deadlock detected on catalog inventory updates',
      },
      {
        'ticket_id': 'INC-506',
        'client': 'Acme Corp',
        'category': 'Billing',
        'severity': 'Low',
        'sla_hours': 24,
        'impact_score': 20.0,
        'summary': 'Invoice PDF rendering currency symbol mismatch',
      },
      {
        'ticket_id': 'INC-507',
        'client': 'Stripe Connect',
        'category': 'Payment Gateway',
        'severity': 'High',
        'sla_hours': 4,
        'impact_score': 79.5,
        'summary': 'Refund queue backlog exceeding 5,000 requests',
      },
      {
        'ticket_id': 'INC-508',
        'client': 'Nordic Bank',
        'category': 'Security',
        'severity': 'Critical',
        'sla_hours': 1,
        'impact_score': 99.8,
        'summary': 'Suspicious anomaly in cryptographic signature payload',
      },
    ];

    _dataSource = LocalAiGridDataSource(columns: columns, initialData: rows);

    // Configure Context Menu with custom developer actions
    _controller.setContextMenuConfig(
      AiGridContextMenuConfiguration(
        enabled: true,
        enableAiActions: true,
        enableClipboardActions: true,
        enableEditingActions: true,
        enableFilterSimilar: true,
        customActions: [
          AiGridContextAction(
            id: 'escalate_tier2',
            label: 'Escalate to Tier 2 Support',
            icon: Icons.priority_high_rounded,
            isDestructive: false,
            isVisible: (row, col) =>
                row['severity'] == 'Critical' || row['severity'] == 'High',
            onExecute: (ctx, ctrl, row, rowIndex, col) async {
              _logAction(
                '🚨 Escalated ${row['ticket_id']} (${row['client']}) to Tier 2 Engineering!',
              );
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(
                    'Ticket ${row['ticket_id']} escalated to on-call engineers.',
                  ),
                  backgroundColor: Colors.deepOrange,
                ),
              );
            },
          ),
          AiGridContextAction(
            id: 'dispatch_client_ack',
            label: 'Dispatch Client SLA Notice',
            icon: Icons.mark_email_read_rounded,
            onExecute: (ctx, ctrl, row, rowIndex, col) async {
              _logAction(
                '✉️ Dispatched SLA Acknowledgment to ${row['client']}.',
              );
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(
                    'SLA acknowledgment notice dispatched to ${row['client']}.',
                  ),
                ),
              );
            },
          ),
        ],
        onActionExecuted: (actionId, row) {
          _logAction(
            'Action "$actionId" executed on ${row['ticket_id'] ?? 'record'}',
          );
        },
      ),
    );

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
          // 1. Collapsible Showcase Banner (matches Pic 3 standard)
          _buildShowcaseBanner(context, isDark, isMobile),

          // 2. Interactive Hint & Quick Action Bar (horizontally scrollable, 0 overflow)
          _buildActionBar(context, isDark, isMobile),

          // 3. Grid Viewport with Context Menu Active
          Expanded(
            child: _dataSource == null
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: AiGrid(
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
                        ),
                      ),
                      if (!isMobile && _activityLog.isNotEmpty) ...[
                        Container(
                          width: 1,
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                        SizedBox(
                          width: 280,
                          child: _buildActivitySidebar(context, isDark),
                        ),
                      ],
                    ],
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
                    color: const Color(0xFFDB2777).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.mouse_outlined,
                    color: Color(0xFFDB2777),
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
                              'Contextual Row/Cell AI Actions',
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
                          'Right-click on desktop or long-press on mobile to trigger contextual AI prompts, 1-click filtering, and custom domain actions.',
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
                      Icons.auto_awesome,
                      'Right-Click Menu',
                      'Desktop right-click / mobile long-press',
                    ),
                    const SizedBox(width: 8),
                    _buildPill(
                      Icons.mark_email_unread_outlined,
                      'AI Synthesizer',
                      'Ask AI, Draft Message, Explain Value',
                    ),
                    const SizedBox(width: 8),
                    _buildPill(
                      Icons.filter_alt_outlined,
                      '1-Click "Filter Similar"',
                      'Isolate matching records in 1-click',
                    ),
                    const SizedBox(width: 8),
                    _buildPill(
                      Icons.terminal_rounded,
                      'MCP Agent Tool',
                      'grid_execute_context_action',
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
          Icon(icon, size: 16, color: const Color(0xFFDB2777)),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
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
              icon: const Icon(Icons.flash_on_rounded, size: 16),
              label: const Text('Simulate Right-Click (Row 0)'),
              onPressed: () {
                if (_controller.rows.isNotEmpty) {
                  final row = _controller.rows[0];
                  AiGridContextMenu.show(
                    context: context,
                    position: const Offset(200, 260),
                    controller: _controller,
                    row: row,
                    rowIndex: 0,
                    columnField: 'client',
                    cellValue: row['client'],
                  );
                }
              },
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Ask AI (Row 0)'),
              onPressed: () {
                if (_controller.rows.isNotEmpty) {
                  _controller.askAiAboutRow(
                    _controller.rows[0],
                    context: context,
                  );
                }
              },
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.filter_alt_outlined, size: 16),
              label: const Text('Filter "Acme Corp"'),
              onPressed: () {
                _controller.filterSimilar(
                  field: 'client',
                  value: 'Acme Corporation',
                );
              },
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.mail_outline, size: 16),
              label: const Text('Draft Email'),
              onPressed: () {
                if (_controller.rows.isNotEmpty) {
                  _controller.draftMessageFromRow(
                    _controller.rows[0],
                    context: context,
                  );
                }
              },
            ),
            if (isMobile && _activityLog.isNotEmpty) ...[
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.history_rounded, size: 16),
                label: Text('Activity (${_activityLog.length})'),
                onPressed: () => _showMobileActivitySheet(context, isDark),
              ),
            ],
            if (_activityLog.isNotEmpty) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear Activity'),
                onPressed: () => setState(() => _activityLog.clear()),
              ),
            ],
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    size: 14,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isMobile
                        ? 'Long-press cell for menu'
                        : 'Right-click cell for menu',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMobileActivitySheet(BuildContext context, bool isDark) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.25,
          maxChildSize: 0.85,
          expand: false,
          builder: (ctx, scrollController) {
            final theme = Theme.of(ctx);
            final colorScheme = theme.colorScheme;

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Context Action Activity',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.clear_all, size: 18),
                        tooltip: 'Clear Log',
                        onPressed: () {
                          setState(() => _activityLog.clear());
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: _activityLog.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (_, index) {
                        return Text(
                          _activityLog[index],
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: colorScheme.onSurface,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActivitySidebar(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      color: isDark
          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
          : const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              const Text(
                'Context Action Activity',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.clear_all, size: 16),
                tooltip: 'Clear Log',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: () => setState(() => _activityLog.clear()),
              ),
            ],
          ),
          const Divider(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: _activityLog.length,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final log = _activityLog[index];
                return Text(
                  log,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: colorScheme.onSurface,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
