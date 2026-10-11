import 'package:flutter/material.dart';
import 'package:draggable_overlay_window/draggable_overlay_window.dart';
import 'package:trina_grid/trina_grid.dart';
import '../config/ai_grid_config.dart';
import '../config/ai_grid_settings_storage.dart';
import '../controllers/ai_grid_controller.dart';
import '../models/ai_grid_data_source.dart';
import '../theme/ai_grid_theme.dart';
import 'ai_grid_assistant_panel.dart';
import 'ai_grid_group_panel.dart';
import 'ai_grid_toolbar.dart';

/// An intelligent DataGrid widget for Flutter.
///
/// Combines high-performance tabular virtualization, hierarchical grouping,
/// inline column filtering, aggregate summary footers, global search,
/// and native AI assistant capabilities with responsive desktop (floating window)
/// and mobile (tab/full-screen view with dropdown actions) layouts.
class AiGrid extends StatefulWidget {
  final AiGridDataSource dataSource;
  final AiGridController? controller;
  final bool showToolbar;
  final bool enableAiAssistant;
  final AiGridConfig? aiConfig;
  final TrinaGridConfiguration? configuration;
  final Future<void> Function(String prompt)? onAiPrompt;

  /// Custom footer callback (e.g. for custom pagination or status bars).
  final CreateFooterCallBack? createFooter;

  /// Whether client-side pagination should be enabled by default.
  final bool enablePagination;

  /// Page size if pagination is enabled.
  final int? pageSize;

  /// Whether to show the total number of rows in the pagination footer.
  final bool showTotalRows;

  /// Whether to display the "Go to Page" button in the pagination footer.
  final bool enableGotoPage;

  /// Whether changes to column visibility, grouping, sorting, and filters
  /// are automatically saved and restored when the grid initializes.
  final bool autoSave;

  /// Unique key used to persist grid settings when [autoSave] is true.
  final String persistenceKey;

  /// Optional initial settings map to apply when grid is loaded.
  final Map<String, dynamic>? initialSettings;

  /// Callback triggered whenever grid settings change.
  final void Function(Map<String, dynamic> settings)? onSettingsChanged;

  const AiGrid({
    super.key,
    required this.dataSource,
    this.controller,
    this.showToolbar = true,
    this.enableAiAssistant = true,
    this.aiConfig,
    this.configuration,
    this.onAiPrompt,
    this.createFooter,
    this.enablePagination = false,
    this.pageSize,
    this.showTotalRows = true,
    this.enableGotoPage = true,
    this.autoSave = false,
    this.persistenceKey = 'ai_grid_default_settings',
    this.initialSettings,
    this.onSettingsChanged,
  });

  @override
  State<AiGrid> createState() => _AiGridState();
}

class _AiGridState extends State<AiGrid> {
  late AiGridController _controller;
  late final DraggableWindowController _draggableWindowController;
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

    _draggableWindowController = DraggableWindowController(
      initialPosition: const Offset(360, 60),
      initialSize: const Size(420, 540),
    );

    _controller.addListener(_syncAiAssistantWindowState);
    _controller.addListener(_onControllerStateChangedForAutoSave);
    if (_controller.showAiAssistant && widget.enableAiAssistant) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _draggableWindowController.show();
      });
    }

    _loadData();
    widget.dataSource.addListener(_onDataSourceChanged);
  }

  bool _hasRestoredSettings = false;

  void _restoreInitialSettingsIfNeeded() {
    if (_hasRestoredSettings) return;
    _hasRestoredSettings = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialSettings != null) {
        _controller.restoreSettings(widget.initialSettings!);
      } else if (widget.autoSave) {
        final saved = AiGridSettingsStorage.load(widget.persistenceKey);
        if (saved != null) {
          _controller.restoreSettings(saved);
        }
      }
    });
  }

  void _onControllerStateChangedForAutoSave() {
    if (!_controller.isAttached) return;
    final current = _controller.exportSettings();
    widget.onSettingsChanged?.call(current);
    if (widget.autoSave) {
      AiGridSettingsStorage.save(widget.persistenceKey, current);
    }
  }

  void _syncAiAssistantWindowState() {
    if (_controller.showAiAssistant && !_draggableWindowController.isVisible) {
      _draggableWindowController.show();
    } else if (!_controller.showAiAssistant && _draggableWindowController.isVisible) {
      _draggableWindowController.hide();
    }
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
    _controller.removeListener(_syncAiAssistantWindowState);
    _controller.removeListener(_onControllerStateChangedForAutoSave);
    _draggableWindowController.dispose();
    if (_internalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onDataSourceChanged() {
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.dataSource is LazyAiGridDataSource) {
      if (mounted) {
        setState(() {
          _rows = <TrinaRow>[];
          _isLoading = false;
        });
      }
      return;
    }
    setState(() => _isLoading = true);
    final rows = await widget.dataSource.fetchRows();
    if (mounted) {
      setState(() {
        _rows = rows;
        _isLoading = false;
      });
    }
  }

  CreateFooterCallBack? _resolveFooter() {
    if (widget.createFooter != null) {
      return widget.createFooter;
    }
    if (widget.dataSource is LazyAiGridDataSource) {
      final lazySource = widget.dataSource as LazyAiGridDataSource;
      return (stateManager) => TrinaLazyPagination(
            stateManager: stateManager,
            fetch: lazySource.fetch,
            fetchWithSorting: lazySource.fetchWithSorting,
            fetchWithFiltering: lazySource.fetchWithFiltering,
            showTotalRows: widget.showTotalRows,
            enableGotoPage: widget.enableGotoPage,
          );
    }
    if (widget.enablePagination || widget.pageSize != null) {
      return (stateManager) => TrinaPagination(
            stateManager,
            showTotalRows: widget.showTotalRows,
            enableGotoPage: widget.enableGotoPage,
          );
    }
    return null;
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

    final config = widget.configuration ??
        AiGridTheme.createThemeFromContext(
          context,
          showColumnFilter: _controller.showColumnFilterRow,
        );

    final borderColor = isDark
        ? colorScheme.outlineVariant.withAlpha(80)
        : AiGridTheme.borderColor;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 650;

            return Material(
              type: MaterialType.transparency,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? colorScheme.surface : AiGridTheme.backgroundLight,
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: () {
                  final isLlmConfigured = widget.aiConfig?.isLlmConfigured ??
                      (AiGridEnvLoader.createLlmConfigFromEnv()?.isConfigured ??
                          false);
                  return isMobile
                      ? _buildMobileLayout(
                          context,
                          isDark,
                          colorScheme,
                          borderColor,
                          config,
                          trinaColumns,
                          isLlmConfigured,
                        )
                      : _buildDesktopLayout(
                          context,
                          isDark,
                          colorScheme,
                          config,
                          trinaColumns,
                          isLlmConfigured,
                        );
                }(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
    Color borderColor,
    TrinaGridConfiguration config,
    List<TrinaColumn> trinaColumns,
    bool isLlmConfigured,
  ) {
    return Column(
      children: [
        if (widget.showToolbar)
          AiGridToolbar(
            controller: _controller,
            enableAiAssistant: widget.enableAiAssistant,
            isLlmConfigured: isLlmConfigured,
            hideIfNoLlm: widget.aiConfig?.hideAiAssistantIfNoLlm ?? false,
            onRefresh: _loadData,
          ),
        if (widget.enableAiAssistant && isLlmConfigured) ...[
          // Sleek Mobile Mode Switcher Tab Bar
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerHighest
                  : const Color(0xFFF1F5F9),
              border: Border(
                bottom: BorderSide(color: borderColor, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _controller.setAiAssistantVisible(false),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: !_controller.showAiAssistant
                                ? colorScheme.primary
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.table_chart_outlined,
                            size: 15,
                            color: !_controller.showAiAssistant
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Data Grid',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: !_controller.showAiAssistant
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: !_controller.showAiAssistant
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _controller.setAiAssistantVisible(true),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _controller.showAiAssistant
                                ? colorScheme.primary
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 15,
                            color: _controller.showAiAssistant
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'AI Assistant',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _controller.showAiAssistant
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: _controller.showAiAssistant
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        // Body view: either Assistant full-screen or DataGrid + Group Panel
        if (_controller.showAiAssistant && widget.enableAiAssistant)
          Expanded(
            child: AiGridAssistantPanel(
              controller: _controller,
              aiConfig: widget.aiConfig,
              onSendPrompt: widget.onAiPrompt,
              isFullScreen: true,
              embeddedInWindow: false,
            ),
          )
        else ...[
          AiGridGroupPanel(controller: _controller),
          Expanded(
            child: TrinaGrid(
              columns: trinaColumns,
              rows: List<TrinaRow>.from(_rows),
              configuration: config,
              createFooter: _resolveFooter(),
              onLoaded: (TrinaGridOnLoadedEvent event) {
                _controller.attach(
                  stateManager: event.stateManager,
                  columns: widget.dataSource.columns,
                  dataSource: widget.dataSource,
                );
                if (widget.pageSize != null) {
                  event.stateManager.setPageSize(widget.pageSize!);
                }
                event.stateManager.setShowColumnFilter(
                  _controller.showColumnFilterRow,
                );
                _restoreInitialSettingsIfNeeded();
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
    TrinaGridConfiguration config,
    List<TrinaColumn> trinaColumns,
    bool isLlmConfigured,
  ) {
    return OverlayWindowStack(
      windows: [
        if (widget.enableAiAssistant && isLlmConfigured)
          DraggableOverlayWindow(
            key: ValueKey(_draggableWindowController.windowId),
            controller: _draggableWindowController,
            title: 'AI Assistant',
            icon: Icons.auto_awesome,
            onClose: () => _controller.setAiAssistantVisible(false),
            config: DraggableWindowConfig(
              initialWidth: 420.0,
              initialHeight: 540.0,
              minWidth: 320.0,
              minHeight: 280.0,
              maxWidth: 900.0,
              maxHeight: 900.0,
              borderRadius: 12.0,
              elevation: 10.0,
              focusedElevation: 18.0,
              windowBackgroundColor: isDark
                  ? colorScheme.surfaceContainerHigh
                  : Colors.white,
              headerBackgroundColor: isDark
                  ? colorScheme.surfaceContainerHighest
                  : const Color(0xFFF1F5F9),
              borderColor: isDark
                  ? colorScheme.outlineVariant.withAlpha(90)
                  : AiGridTheme.borderColor,
              focusedBorderColor: colorScheme.primary,
              headerIconColor: colorScheme.primary,
              headerButtonsColor: colorScheme.onSurfaceVariant,
              headerTextStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'Segoe UI',
              ),
              resizable: true,
              enableScrolling: false,
              contentPadding: EdgeInsets.zero,
            ),
            content: AiGridAssistantPanel(
              controller: _controller,
              aiConfig: widget.aiConfig,
              onSendPrompt: widget.onAiPrompt,
              embeddedInWindow: true,
            ),
          ),
      ],
      child: Column(
        children: [
          if (widget.showToolbar)
            AiGridToolbar(
              controller: _controller,
              enableAiAssistant: widget.enableAiAssistant,
              isLlmConfigured: isLlmConfigured,
              hideIfNoLlm: widget.aiConfig?.hideAiAssistantIfNoLlm ?? false,
              onRefresh: _loadData,
            ),
          AiGridGroupPanel(controller: _controller),
          Expanded(
            child: TrinaGrid(
              columns: trinaColumns,
              rows: List<TrinaRow>.from(_rows),
              configuration: config,
              createFooter: _resolveFooter(),
              onLoaded: (TrinaGridOnLoadedEvent event) {
                _controller.attach(
                  stateManager: event.stateManager,
                  columns: widget.dataSource.columns,
                  dataSource: widget.dataSource,
                );
                if (widget.pageSize != null) {
                  event.stateManager.setPageSize(widget.pageSize!);
                }
                event.stateManager.setShowColumnFilter(
                  _controller.showColumnFilterRow,
                );
                _restoreInitialSettingsIfNeeded();
              },
            ),
          ),
        ],
      ),
    );
  }
}
