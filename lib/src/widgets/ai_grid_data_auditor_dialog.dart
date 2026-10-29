import 'package:material_ui/material_ui.dart';

import '../controllers/ai_grid_controller.dart';
import '../models/ai_grid_data_auditor.dart';

/// Modal dialog providing interactive data health auditing and automated 1-click remediation.
class AiGridDataAuditorDialog extends StatefulWidget {
  const AiGridDataAuditorDialog({super.key, required this.controller});

  final AiGridController controller;

  /// Shows the dialog and returns the result of any data cleaning performed, or null.
  static Future<AiGridCleanResult?> show(
    BuildContext context, {
    required AiGridController controller,
  }) {
    return showGeneralDialog<AiGridCleanResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: const Color(0x80000000),
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        Widget content = AiGridDataAuditorDialog(controller: controller);

        final hasLoc =
            Localizations.of<MaterialLocalizations>(
              dialogContext,
              MaterialLocalizations,
            ) !=
            null;
        if (!hasLoc) {
          content = Localizations(
            locale: const Locale('en', 'US'),
            delegates: const [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            child: content,
          );
        }

        return SafeArea(child: content);
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<AiGridDataAuditorDialog> createState() =>
      _AiGridDataAuditorDialogState();
}

class _AiGridDataAuditorDialogState extends State<AiGridDataAuditorDialog> {
  late AiGridAuditReport _report;
  bool _isCleaning = false;
  String? _lastAppliedMessage;
  AiGridCleanResult? _cumulativeResult;

  @override
  void initState() {
    super.initState();
    _refreshReport();
  }

  void _refreshReport() {
    setState(() {
      _report = widget.controller.auditData();
    });
  }

  Future<void> _applyRemediation(AiGridAuditRemediation remediation) async {
    setState(() => _isCleaning = true);
    try {
      final res = widget.controller.cleanData(remediation);
      _cumulativeResult = res;
      _lastAppliedMessage = res.message;
      _refreshReport();
    } finally {
      if (mounted) setState(() => _isCleaning = false);
    }
  }

  Future<void> _applyCleanAll() async {
    setState(() => _isCleaning = true);
    try {
      final res = widget.controller.cleanAllData();
      _cumulativeResult = res;
      _lastAppliedMessage = res.message;
      _refreshReport();
    } finally {
      if (mounted) setState(() => _isCleaning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildHeader(context),
              const SizedBox(height: 16),

              // Quality Score & Metric Cards
              _buildScoreOverview(context),
              const SizedBox(height: 16),

              if (_lastAppliedMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _lastAppliedMessage!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Issues List Header
              Row(
                children: [
                  const Icon(Icons.rule_folder_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Detected Data Quality Issues (${_report.issueCount})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_report.hasIssues)
                    FilledButton.icon(
                      icon: _isCleaning
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_fix_high_rounded, size: 16),
                      label: const Text('Clean All Anomalies (1-Click)'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF107C41),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isCleaning ? null : _applyCleanAll,
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Issues View
              Expanded(
                child: _report.hasIssues
                    ? ListView.separated(
                        itemCount: _report.issues.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          return _buildIssueTile(context, _report.issues[idx]);
                        },
                      )
                    : _buildCleanState(context),
              ),

              const SizedBox(height: 16),
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_cumulativeResult),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.health_and_safety_rounded,
            color: colorScheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Data Quality Auditor',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Automated tabular anomaly detection, type hygiene & statistical outlier profiling',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Re-audit Data',
          onPressed: _isCleaning ? null : _refreshReport,
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(_cumulativeResult),
        ),
      ],
    );
  }

  Widget _buildScoreOverview(BuildContext context) {
    final theme = Theme.of(context);
    final score = _report.qualityScore;

    Color scoreColor;
    String gradeText;
    if (score >= 90) {
      scoreColor = const Color(0xFF107C41);
      gradeText = 'Excellent Health';
    } else if (score >= 75) {
      scoreColor = Colors.teal;
      gradeText = 'Good Hygiene';
    } else if (score >= 50) {
      scoreColor = Colors.orange.shade800;
      gradeText = 'Needs Attention';
    } else {
      scoreColor = Colors.red.shade700;
      gradeText = 'Critical Quality Deficit';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scoreColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          // Circular Score Meter
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score / 100.0,
                  strokeWidth: 7,
                  backgroundColor: scoreColor.withValues(alpha: 0.2),
                  color: scoreColor,
                ),
                Text(
                  '$score%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),

          // Rating details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      gradeText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_report.cleanRows}/${_report.totalRows} clean rows',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scoreColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Scored across completeness, format consistency, type uniformity, and distribution boundaries.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Summary Stats Pills
          Wrap(
            spacing: 8,
            children: [
              _buildStatPill(
                'Critical',
                '${_report.criticalIssues}',
                Colors.red.shade700,
              ),
              _buildStatPill(
                'Warnings',
                '${_report.warningIssues}',
                Colors.orange.shade800,
              ),
              _buildStatPill(
                'Clean %',
                '${((_report.cleanRows / (_report.totalRows == 0 ? 1 : _report.totalRows)) * 100).toInt()}%',
                Colors.teal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueTile(BuildContext context, AiGridAuditIssue issue) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isCritical = issue.severity == AiGridAuditSeverity.critical;
    final sevColor = isCritical
        ? Colors.red.shade700
        : (issue.severity == AiGridAuditSeverity.warning
              ? Colors.orange.shade800
              : Colors.blue.shade700);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Severity Icon
          Icon(
            isCritical
                ? Icons.error_outline_rounded
                : Icons.warning_amber_rounded,
            color: sevColor,
            size: 20,
          ),
          const SizedBox(width: 10),

          // Issue Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: sevColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        issue.severity.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: sevColor,
                        ),
                      ),
                    ),
                    Text(
                      issue.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (issue.columnField != null)
                      Text(
                        '(${issue.columnField})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    Text(
                      '• ${issue.affectedCount} affected',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  issue.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (issue.sampleValues.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Samples: ',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      ...issue.sampleValues.take(5).map((sample) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            sample == null
                                ? 'null'
                                : (sample.toString().isEmpty
                                      ? '""'
                                      : sample.toString()),
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: colorScheme.onSurface,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Fix Button
          OutlinedButton.icon(
            icon: const Icon(Icons.build_rounded, size: 14),
            label: Text(issue.remediation.actionLabel),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
            onPressed: _isCleaning
                ? null
                : () => _applyRemediation(issue.remediation),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF107C41).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_rounded,
              size: 48,
              color: Color(0xFF107C41),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Dataset is 100% Clean & Pristine!',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Zero duplicates, missing values, dirty numbers, or mixed formats detected.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
