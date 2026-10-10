import 'package:flutter/material.dart';
import 'package:trina_grid/trina_grid.dart';
import '../config/ai_grid_config.dart';
import '../controllers/ai_grid_controller.dart';
import '../models/ai_grid_data_source.dart';
import '../theme/ai_grid_theme.dart';
import 'ai_grid_assistant_panel.dart';
import 'ai_grid_group_panel.dart';
import 'ai_grid_toolbar.dart';

/// An intelligent DataGrid widget for Flutter.
///
/// Combines high-performance tabular virtualization, hierarchical grouping,
/// inline column filtering, aggregate summary footers, global search, and a
/// native AI assistant overlay with MCP skill controls.
class AiGrid extends StatefulWidget {
  final AiGridDataSource dataSource;
  final AiGridController? controller;
  final bool showToolbar;
  final bool enableAiAssistant;
  final AiGridConfig? aiConfig;
  final TrinaGridConfiguration? configuration;
  final Future<void> Function(String prompt)? onAiPrompt;

  const AiGrid({
    super.key,
    required this.dataSource,
    this.controller,
    this.showToolbar = true,
    this.enableAiAssistant = true,
    this.aiConfig,
    this.configuration,
    this.onAiPrompt,
  });

  @override
  State<AiGrid> createState() => _AiGridState();
}

class _AiGridState extends State<AiGrid> {
  late AiGridController _controller;
  bool _internalController = false;
  List<TrinaRow> _rows = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = AiGridController();
      _internalController = true;
    }

    _loadData();
    widget.dataSource.addListener(_onDataSourceChanged);
  }

  @override
  void didUpdateWidget(covariant AiGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dataSource != oldWidget.dataSource) {
      oldWidget.dataSource.removeListener(_onDataSourceChanged);
      widget.dataSource.addListener(_onDataSourceChanged);
      _loadData();
    }
  }

  @override
  void dispose() {
    widget.dataSource.removeListener(_onDataSourceChanged);
    if (_internalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onDataSourceChanged() {
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final rows = await widget.dataSource.fetchRows();
    if (mounted) {
      setState(() {
        _rows = rows;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final trinaColumns =
        widget.dataSource.columns.map((c) => c.toTrinaColumn()).toList();

    // Use parent app theme dynamically if no explicit configuration was supplied
    final config = widget.configuration ??
        AiGridTheme.createThemeFromContext(
          context,
          showColumnFilter: _controller.showColumnFilterRow,
        );

    final borderColor = isDark
        ? colorScheme.outlineVariant.withAlpha(80)
        : AiGridTheme.borderColor;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surface : AiGridTheme.backgroundLight,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            if (widget.showToolbar)
              AiGridToolbar(
                controller: _controller,
                enableAiAssistant: widget.enableAiAssistant,
                onRefresh: _loadData,
              ),
            AiGridGroupPanel(controller: _controller),
            Expanded(
              child: Stack(
                children: [
                  TrinaGrid(
                    columns: trinaColumns,
                    rows: _rows,
                    configuration: config,
                    onLoaded: (TrinaGridOnLoadedEvent event) {
                      _controller.attach(
                        stateManager: event.stateManager,
                        columns: widget.dataSource.columns,
                        dataSource: widget.dataSource,
                      );
                      event.stateManager.setShowColumnFilter(
                        _controller.showColumnFilterRow,
                      );
                    },
                  ),
                  ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) {
                      if (!_controller.showAiAssistant ||
                          !widget.enableAiAssistant) {
                        return const SizedBox.shrink();
                      }

                      return Positioned(
                        right: 16,
                        bottom: 16,
                        child: AiGridAssistantPanel(
                          controller: _controller,
                          aiConfig: widget.aiConfig,
                          onSendPrompt: widget.onAiPrompt,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
