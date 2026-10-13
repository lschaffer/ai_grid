import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../controllers/ai_grid_controller.dart';
import '../theme/ai_grid_theme.dart';
import 'ai_grid_export_dialog.dart';

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

  void _showExportDialog(BuildContext context) {
    AiGridExportDialog.show(context, widget.controller);
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
                _showExportDialog(context);
                break;
            }
          },
          itemBuilder: (context) => [
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
                  Text('Export Data...', style: TextStyle(fontSize: 13)),
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
          tooltip: 'Export Grid Data',
          onPressed: () => _showExportDialog(context),
        ),
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
