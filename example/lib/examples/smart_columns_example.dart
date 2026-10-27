import 'package:material_ui/material_ui.dart';
import 'package:ai_grid/ai_grid.dart';

/// Showcase demonstration for Feature 1:
/// AI-Synthesized Columns ("Smart / Prompt Columns").
class SmartColumnsExamplePage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const SmartColumnsExamplePage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<SmartColumnsExamplePage> createState() =>
      _SmartColumnsExamplePageState();
}

class _SmartColumnsExamplePageState extends State<SmartColumnsExamplePage> {
  late final AiGridController _controller;
  late LocalAiGridDataSource _dataSource;
  AiGridConfig? _aiConfig;

  @override
  void initState() {
    super.initState();
    _controller = AiGridController();

    final llmConfig = AiGridEnvLoader.createLlmConfigFromEnv();
    _aiConfig = AiGridConfig(
      llmConfig: llmConfig,
      suggestedPrompts: const [
        'Run AI Smart Columns on all tickets',
        'Add smart column classifying issue Category',
        'Add smart column translating feedback to Spanish',
        'Select all Critical urgency tickets',
        'Filter Negative sentiment tickets',
        'Export tickets to Excel',
      ],
    );

    _controller.editingOptions = const AiGridEditingOptions(
      enabled: false,
    );

    _setupDataSource();
  }

  void _setupDataSource() {
    final columns = <AiGridColumn>[
      const AiGridColumn(
        field: 'ticket_id',
        title: 'Ticket ID',
        width: 110,
        type: AiGridColumnType.text,
      ),
      const AiGridColumn(
        field: 'customer',
        title: 'Customer Organization',
        width: 170,
        type: AiGridColumnType.text,
      ),
      const AiGridColumn(
        field: 'channel',
        title: 'Support Channel',
        width: 140,
        type: AiGridColumnType.select,
        selectOptions: ['Email', 'Slack Connect', 'Web Portal', 'Live Chat'],
      ),
      const AiGridColumn(
        field: 'feedback',
        title: 'Customer Feedback / Issue Description',
        width: 320,
        type: AiGridColumnType.text,
        editable: false,
      ),

      // Smart Column 1: AI Sentiment
      AiGridSmartColumn(
        field: 'sentiment',
        title: 'AI Sentiment',
        width: 140,
        promptTemplate:
            "Classify sentiment of '{feedback}' as Positive, Neutral, Negative, or Critical",
        options: const ['Positive', 'Neutral', 'Negative', 'Critical'],
        sparkleColor: const Color(0xFF8B5CF6),
        cellStyle: (val, row) {
          final s = val?.toString();
          if (s == 'Positive') {
            return const TextStyle(
              color: Color(0xFF2E7D32),
              fontWeight: FontWeight.bold,
            );
          } else if (s == 'Negative') {
            return const TextStyle(
              color: Color(0xFFD97706),
              fontWeight: FontWeight.bold,
            );
          } else if (s == 'Critical') {
            return const TextStyle(
              color: Color(0xFFDC2626),
              fontWeight: FontWeight.bold,
            );
          }
          return null;
        },
      ),

      // Smart Column 2: AI Urgency
      AiGridSmartColumn(
        field: 'urgency',
        title: 'AI Urgency',
        width: 150,
        promptTemplate:
            "Rate urgency from P1 (Critical), P2 (High), P3 (Medium), to P4 (Low) for: '{feedback}'",
        options: const ['P1 (Critical)', 'P2 (High)', 'P3 (Medium)', 'P4 (Low)'],
        sparkleColor: const Color(0xFFF97316),
        cellStyle: (val, row) {
          final u = val?.toString() ?? '';
          if (u.contains('P1') || u.contains('Critical')) {
            return const TextStyle(
              color: Color(0xFFDC2626),
              fontWeight: FontWeight.bold,
            );
          } else if (u.contains('P2') || u.contains('High')) {
            return const TextStyle(
              color: Color(0xFFEA580C),
              fontWeight: FontWeight.bold,
            );
          } else if (u.contains('P3') || u.contains('Medium')) {
            return const TextStyle(
              color: Color(0xFFCA8A04),
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(color: Color(0xFF16A34A));
        },
      ),

      // Smart Column 3: AI Action Recommendation
      const AiGridSmartColumn(
        field: 'action',
        title: 'AI Next Action',
        width: 220,
        promptTemplate:
            "Suggest the immediate next support action for '{feedback}' in 3 to 4 words",
        sparkleColor: Color(0xFF0D9488),
      ),
    ];

    final sampleData = <Map<String, dynamic>>[
      {
        'ticket_id': 'TK-101',
        'customer': 'Acme Cloud Corp',
        'channel': 'Slack Connect',
        'feedback':
            'Massive latency spike during peak hours. Our API gateways timed out causing dropped orders. Need an immediate fix or SLA credit.',
        'sentiment': null,
        'urgency': null,
        'action': null,
      },
      {
        'ticket_id': 'TK-102',
        'customer': 'TechNova Systems',
        'channel': 'Web Portal',
        'feedback':
            'The automated monthly PDF report looks fantastic! Our executive team loves the new sparklines and pivot matrix. Kudos!',
        'sentiment': null,
        'urgency': null,
        'action': null,
      },
      {
        'ticket_id': 'TK-103',
        'customer': 'GlobalBank Switzerland',
        'channel': 'Email',
        'feedback':
            'Cannot generate invoices for EMEA customers with VAT numbers. Getting HTTP 500 error on checkout page. Critical blocker for our Q4 billing.',
        'sentiment': null,
        'urgency': null,
        'action': null,
      },
      {
        'ticket_id': 'TK-104',
        'customer': 'Apex Healthcare',
        'channel': 'Support Chat',
        'feedback':
            'Would it be possible to add dark mode toggle for the mobile app version? Also the contrast ratio on secondary buttons could be slightly higher.',
        'sentiment': null,
        'urgency': null,
        'action': null,
      },
      {
        'ticket_id': 'TK-105',
        'customer': 'Cyberdyne AI Labs',
        'channel': 'Slack Connect',
        'feedback':
            'Our database migration completed smoothly over the weekend with zero downtime. Exceptional customer support and documentation from your team!',
        'sentiment': null,
        'urgency': null,
        'action': null,
      },
      {
        'ticket_id': 'TK-106',
        'customer': 'Hooli Internet Services',
        'channel': 'Email',
        'feedback':
            'Urgent: We were double charged on our annual enterprise subscription invoice #INV-9821. Please issue a refund immediately.',
        'sentiment': null,
        'urgency': null,
        'action': null,
      },
      {
        'ticket_id': 'TK-107',
        'customer': 'Wayne Enterprises',
        'channel': 'Web Portal',
        'feedback':
            'Looking for technical documentation on setting up SSO with Okta and SAML 2.0. The setup wizard gets stuck on step 3 during certificate upload.',
        'sentiment': null,
        'urgency': null,
        'action': null,
      },
      {
        'ticket_id': 'TK-108',
        'customer': 'Initech Solutions',
        'channel': 'Email',
        'feedback':
            'Security vulnerability scan flagged an outdated SSL cipher on your staging environment endpoint. Please review attached CVE report and patch.',
        'sentiment': null,
        'urgency': null,
        'action': null,
      },
      {
        'ticket_id': 'TK-109',
        'customer': 'Umbrella Pharmaceuticals',
        'channel': 'Slack Connect',
        'feedback':
            'The Excel export feature is lightning fast now! Handled 250,000 rows without breaking a sweat. Really impressed with the recent engine upgrade.',
        'sentiment': null,
        'urgency': null,
        'action': null,
      },
      {
        'ticket_id': 'TK-110',
        'customer': 'Stark Industries',
        'channel': 'Web Portal',
        'feedback':
            'Severe memory leak observed when running the desktop app continuously for over 48 hours. Process consumed 8GB RAM and froze.',
        'sentiment': null,
        'urgency': null,
        'action': null,
      },
      {
        'ticket_id': 'TK-111',
        'customer': 'Pied Piper Compression',
        'channel': 'Support Chat',
        'feedback':
            'Can we customize the automated alert webhook payload to include ticket severity and customer ARR tier?',
        'sentiment': null,
        'urgency': null,
        'action': null,
      },
      {
        'ticket_id': 'TK-112',
        'customer': 'Wonka Confectionery',
        'channel': 'Email',
        'feedback':
            'Password reset link sent to my email expired within 60 seconds instead of the stated 15 minutes. Locked out of our administrative dashboard.',
        'sentiment': null,
        'urgency': null,
        'action': null,
      },
    ];

    _dataSource = LocalAiGridDataSource(
      columns: columns,
      initialData: sampleData,
    );
  }

  Future<void> _showAddSmartColumnDialog() async {
    final titleCtrl = TextEditingController(text: 'AI Category');
    final fieldCtrl = TextEditingController(text: 'category');
    final promptCtrl = TextEditingController(
      text:
          "Classify the ticket category of '{feedback}' as Bug Report, Feature Request, Billing, or Performance",
    );
    final optionsCtrl = TextEditingController(
      text: 'Bug Report, Feature Request, Billing, Performance',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6)),
              SizedBox(width: 8),
              Text('Add AI Smart Column'),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Define a new synthesized column evaluated per-row by the LLM using variables like {feedback}, {customer}, or {channel}.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Column Title',
                      hintText: 'e.g. AI Category',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      fieldCtrl.text = val
                          .trim()
                          .toLowerCase()
                          .replaceAll(RegExp(r'[^a-z0-9_]'), '_');
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: fieldCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Field ID',
                      hintText: 'e.g. category',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: promptCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Prompt Template',
                      hintText: "e.g. Classify '{feedback}' into Category",
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: optionsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Allowed Options (comma-separated, optional)',
                      hintText: 'e.g. Bug, Feature, Billing',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add & Run Column'),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final field = fieldCtrl.text.trim();
      final title = titleCtrl.text.trim();
      final prompt = promptCtrl.text.trim();
      final opts = optionsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (field.isNotEmpty && title.isNotEmpty && prompt.isNotEmpty) {
        final smartCol = AiGridSmartColumn(
          field: field,
          title: title,
          promptTemplate: prompt,
          options: opts.isNotEmpty ? opts : null,
          width: 170,
          sparkleColor: const Color(0xFF6366F1),
        );
        _controller.addSmartColumn(smartCol, autoRun: true, aiConfig: _aiConfig);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('Added AI Smart Column "$title". Evaluating rows...'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
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
                  color:
                      isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF8B5CF6),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI-Synthesized Smart / Prompt Columns',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Declare columns computed on-demand by LLMs with prompt templates ({feedback}), streaming generation, and per-cell regeneration.',
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

          // Interactive Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color:
                      isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final isGenerating = _controller.isGeneratingSmartColumns;
                  return Row(
                    children: [
                      FilledButton.icon(
                        icon: isGenerating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.bolt_rounded, size: 18),
                        label: Text(
                          isGenerating
                              ? 'Synthesizing Columns...'
                              : 'Run All Smart Columns',
                        ),
                        onPressed: isGenerating
                            ? null
                            : () async {
                                await _controller.runSmartColumns(
                                  force: true,
                                  aiConfig: _aiConfig,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.maybeOf(context)
                                      ?.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Synthesized AI values across all rows.'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Custom Smart Column'),
                        onPressed: _showAddSmartColumnDialog,
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.clear_all_rounded, size: 16),
                        label: const Text('Clear AI Values'),
                        onPressed: () {
                          _controller.clearSmartColumnValues();
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            const SnackBar(
                              content: Text('Cleared all AI synthesized values.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Reset Dataset'),
                        onPressed: () {
                          _setupDataSource();
                          setState(() {});
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            const SnackBar(
                              content: Text('Reset dataset to initial state.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
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
