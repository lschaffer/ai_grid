import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../controllers/ai_grid_controller.dart';
import '../models/ai_grid_editing_options.dart';
import '../theme/ai_grid_theme.dart';
import 'ai_grid_pivot_chooser_dialog.dart';

/// Top Toolbar for [AiGrid], providing search, filter toggle, group toggle,
/// refresh, export, and AI Assistant controls with responsive desktop/mobile layouts.
class AiGridToolbar extends StatefulWidget {
  final AiGridController controller;
  final bool enableAiAssistant;
  final bool isLlmConfigured;
  final bool hideIfNoLlm;
  final VoidCallback? onRefresh;

  const AiGridToolbar({
    super.key,
    required this.controller,
    this.enableAiAssistant = true,
    this.isLlmConfigured = true,
    this.hideIfNoLlm = false,
    this.onRefresh,
  });

  @override
  State<AiGridToolbar> createState() => _AiGridToolbarState();
}

class _AiGridToolbarState extends State<AiGridToolbar> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.controller.searchQuery;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      widget.controller.search(value);
    });
  }

  Future<void> _handleExport(BuildContext context) async {
    try {
      final savedPath = await widget.controller.exportTableWithSaveDialog();
      if (savedPath != null && savedPath.isNotEmpty && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Table exported successfully to $savedPath'),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Export failed: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    final toolbarBg = isDark ? colorScheme.surface : AiGridTheme.backgroundLight;
    final borderCol = isDark
        ? colorScheme.outlineVariant.withAlpha(80)
        : AiGridTheme.borderColor;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 620;

            return Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: toolbarBg,
                border: Border(
                  bottom: BorderSide(color: borderCol, width: 1),
                ),
              ),
              child: isMobile
                  ? _buildMobileToolbar(context, isDark, colorScheme, borderCol)
                  : _buildDesktopToolbar(context, isDark, colorScheme, borderCol),
            );
          },
        );
      },
    );
  }

  Widget _buildMobileToolbar(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
    Color borderCol,
  ) {
    return Row(
      children: [
        // Dropdown menu for mobile actions
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 20, color: colorScheme.onSurfaceVariant),
          tooltip: 'Grid Actions',
          onSelected: (value) {
            switch (value) {
              case 'group':
                widget.controller.toggleGroupPanel();
                break;
              case 'filter':
                widget.controller.toggleColumnFilterRow();
                break;
              case 'reset':
                widget.controller.reset();
                _searchCtrl.clear();
                widget.onRefresh?.call();
                break;
              case 'export':
                _handleExport(context);
                break;
              case 'pivot':
                AiGridPivotChooserDialog.show(context, widget.controller);
                break;
              case 'add':
                if (widget.controller.editingOptions.mode == AiGridEditMode.form) {
                  widget.controller.showEditDialog(context);
                } else {
                  widget.controller.startAdd();
                }
                break;
            }
          },
          itemBuilder: (context) => [
            if (widget.controller.editingOptions.enabled &&
                widget.controller.editingOptions.allowAdding &&
                widget.controller.editingOptions.mode != AiGridEditMode.cell) ...[
              const PopupMenuItem(
                value: 'add',
                child: Row(
                  children: [
                    Icon(Icons.add, size: 18),
                    SizedBox(width: 10),
                    Text('Add Record', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
            ],
            PopupMenuItem(
              value: 'group',
              child: Row(
                children: [
                  Icon(
                    Icons.layers_outlined,
                    size: 18,
                    color: widget.controller.showGroupPanel
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.controller.showGroupPanel
                        ? 'Hide Group Panel'
                        : 'Show Group Panel',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'filter',
              child: Row(
                children: [
                  Icon(
                    Icons.filter_alt_outlined,
                    size: 18,
                    color: widget.controller.showColumnFilterRow
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.controller.showColumnFilterRow
                        ? 'Hide Filter Row'
                        : 'Show Filter Row',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'export',
              child: const Row(
                children: [
                  Icon(Icons.file_download_outlined, size: 18),
                  SizedBox(width: 10),
                  Text('Export to Excel', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'pivot',
              child: Row(
                children: [
                  Icon(
                    widget.controller.isPivotActive
                        ? Icons.pivot_table_chart
                        : Icons.pivot_table_chart_outlined,
                    size: 18,
                    color: widget.controller.isPivotActive
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.controller.isPivotActive
                        ? 'Configure Pivot Table'
                        : 'Pivot Table...',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'reset',
              child: const Row(
                children: [
                  Icon(Icons.refresh, size: 18),
                  SizedBox(width: 10),
                  Text('Reset Grid State', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
        // Flexible search box that expands dynamically without overflowing
        Expanded(
          child: _buildSearchBox(context, isDark, colorScheme, borderCol),
        ),
        if (widget.enableAiAssistant &&
            (!widget.hideIfNoLlm || widget.isLlmConfigured)) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: widget.isLlmConfigured
                ? 'Toggle AI Assistant'
                : 'AI Assistant disabled: No LLM configured',
            child: IconButton.filledTonal(
              onPressed: widget.isLlmConfigured
                  ? widget.controller.toggleAiAssistant
                  : null,
              icon: Icon(
                Icons.auto_awesome,
                size: 18,
                color: widget.isLlmConfigured
                    ? (widget.controller.showAiAssistant
                        ? Colors.white
                        : colorScheme.primary)
                    : colorScheme.onSurface.withAlpha(90),
              ),
              style: IconButton.styleFrom(
                backgroundColor: !widget.isLlmConfigured
                    ? (isDark
                        ? colorScheme.surfaceContainerHighest.withAlpha(80)
                        : Colors.grey.shade200)
                    : (widget.controller.showAiAssistant
                        ? colorScheme.primary
                        : (isDark
                            ? colorScheme.surfaceContainerHighest
                            : const Color(0xFFEFF6FF))),
                padding: const EdgeInsets.all(8),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDesktopToolbar(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
    Color borderCol,
  ) {
    return Row(
      children: [
        if (widget.controller.editingOptions.enabled &&
            widget.controller.editingOptions.allowAdding &&
            widget.controller.editingOptions.mode != AiGridEditMode.cell) ...[
          IconButton(
            icon: Icon(
              Icons.add,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Add Record',
            onPressed: () {
              if (widget.controller.editingOptions.mode == AiGridEditMode.form) {
                widget.controller.showEditDialog(context);
              } else {
                widget.controller.startAdd();
              }
            },
          ),
        ],
        IconButton(
          icon: Icon(
            Icons.layers_outlined,
            size: 20,
            color: widget.controller.showGroupPanel
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          tooltip: 'Toggle Group Panel',
          onPressed: widget.controller.toggleGroupPanel,
        ),
        IconButton(
          icon: Icon(
            Icons.filter_alt_outlined,
            size: 20,
            color: widget.controller.showColumnFilterRow
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          tooltip: 'Toggle Filter Row',
          onPressed: widget.controller.toggleColumnFilterRow,
        ),
        IconButton(
          icon: Icon(
            Icons.refresh,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          tooltip: 'Reset Grid State',
          onPressed: () {
            widget.controller.reset();
            _searchCtrl.clear();
            widget.onRefresh?.call();
          },
        ),
        IconButton(
          icon: Icon(
            Icons.file_download_outlined,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          tooltip: 'Export to Excel (.xlsx)',
          onPressed: () => _handleExport(context),
        ),
        IconButton(
          icon: Icon(
            widget.controller.isPivotActive
                ? Icons.pivot_table_chart
                : Icons.pivot_table_chart_outlined,
            size: 20,
            color: widget.controller.isPivotActive
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          tooltip: widget.controller.isPivotActive
              ? 'Configure Pivot Table'
              : 'Pivot Table (Field Chooser)...',
          onPressed: () => AiGridPivotChooserDialog.show(context, widget.controller),
        ),
        if (widget.controller.isPivotActive) ...[
          IconButton(
            icon: Icon(
              widget.controller.pivotConfig?.showChart == true
                  ? Icons.bar_chart
                  : Icons.bar_chart_outlined,
              size: 20,
              color: widget.controller.pivotConfig?.showChart == true
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Toggle Pivot Chart',
            onPressed: widget.controller.togglePivotChart,
          ),
          IconButton(
            icon: const Icon(Icons.undo, size: 20, color: Colors.redAccent),
            tooltip: 'Exit Pivot (Return to Table)',
            onPressed: widget.controller.clearPivot,
          ),
        ],
        const Spacer(),
        // Global Search Box
        SizedBox(
          width: 220,
          child: _buildSearchBox(context, isDark, colorScheme, borderCol),
        ),
        if (widget.enableAiAssistant &&
            (!widget.hideIfNoLlm || widget.isLlmConfigured)) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: widget.isLlmConfigured
                ? 'Toggle AI Assistant'
                : 'AI Assistant disabled: No LLM configured',
            child: ElevatedButton.icon(
              onPressed: widget.isLlmConfigured
                  ? widget.controller.toggleAiAssistant
                  : null,
              icon: Icon(
                Icons.auto_awesome,
                size: 16,
                color: widget.isLlmConfigured
                    ? (widget.controller.showAiAssistant
                        ? Colors.white
                        : colorScheme.primary)
                    : colorScheme.onSurface.withAlpha(90),
              ),
              label: Text(
                'AI Assistant',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.isLlmConfigured
                      ? (widget.controller.showAiAssistant
                          ? Colors.white
                          : colorScheme.primary)
                      : colorScheme.onSurface.withAlpha(90),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: !widget.isLlmConfigured
                    ? (isDark
                        ? colorScheme.surfaceContainerHighest.withAlpha(80)
                        : Colors.grey.shade200)
                    : (widget.controller.showAiAssistant
                        ? colorScheme.primary
                        : (isDark
                            ? colorScheme.surfaceContainerHighest
                            : const Color(0xFFEFF6FF))),
                elevation: 0,
                side: BorderSide(
                  color: !widget.isLlmConfigured
                      ? Colors.transparent
                      : (widget.controller.showAiAssistant
                          ? colorScheme.primary
                          : (isDark
                              ? colorScheme.outlineVariant.withAlpha(100)
                              : const Color(0xFFBFDBFE))),
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSearchBox(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
    Color borderCol,
  ) {
    return SizedBox(
      height: 32,
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        style: TextStyle(
          fontSize: 13,
          color: colorScheme.onSurface,
          fontFamily: 'Segoe UI',
        ),
        decoration: InputDecoration(
          hintText: 'Search...',
          hintStyle: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurfaceVariant.withAlpha(160),
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 14),
                  onPressed: () {
                    _searchCtrl.clear();
                    widget.controller.clearSearch();
                  },
                )
              : null,
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: isDark
              ? colorScheme.surfaceContainerHighest
              : const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(
              color: borderCol,
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(
              color: borderCol,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(
              color: colorScheme.primary,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
