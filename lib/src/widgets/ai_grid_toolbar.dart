import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/ai_grid_controller.dart';
import '../theme/ai_grid_theme.dart';

/// Top Toolbar for [AiGrid], providing search, filter toggle, group toggle,
/// refresh, and AI Assistant controls.
class AiGridToolbar extends StatefulWidget {
  final AiGridController controller;
  final bool enableAiAssistant;
  final VoidCallback? onRefresh;

  const AiGridToolbar({
    super.key,
    required this.controller,
    this.enableAiAssistant = true,
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
        return Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: toolbarBg,
            border: Border(
              bottom: BorderSide(color: borderCol, width: 1),
            ),
          ),
          child: Row(
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
              const Spacer(),
              // Global Search Box
              SizedBox(
                width: 220,
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
              ),
              if (widget.enableAiAssistant) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: widget.controller.toggleAiAssistant,
                  icon: Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: widget.controller.showAiAssistant
                        ? Colors.white
                        : colorScheme.primary,
                  ),
                  label: Text(
                    'AI Assistant',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.controller.showAiAssistant
                          ? Colors.white
                          : colorScheme.primary,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.controller.showAiAssistant
                        ? colorScheme.primary
                        : (isDark
                            ? colorScheme.surfaceContainerHighest
                            : const Color(0xFFEFF6FF)),
                    elevation: 0,
                    side: BorderSide(
                      color: widget.controller.showAiAssistant
                          ? colorScheme.primary
                          : (isDark
                              ? colorScheme.outlineVariant.withAlpha(100)
                              : const Color(0xFFBFDBFE)),
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
              ],
            ],
          ),
        );
      },
    );
  }
}
