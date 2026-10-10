import 'package:flutter/material.dart';
import 'package:trina_grid/trina_grid.dart';
import '../controllers/ai_grid_controller.dart';
import '../theme/ai_grid_theme.dart';

/// Top Group Panel widget.
///
/// Displays active grouped columns as chips and supports dragging column headers
/// into the panel to group, as well as a quick '+' selector button.
class AiGridGroupPanel extends StatelessWidget {
  final AiGridController controller;

  const AiGridGroupPanel({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    final panelBg = isDark
        ? colorScheme.surfaceContainer
        : AiGridTheme.groupPanelBackground;
    final borderCol = isDark
        ? colorScheme.outlineVariant.withAlpha(80)
        : AiGridTheme.borderColor;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.showGroupPanel) {
          return const SizedBox.shrink();
        }

        final groups = controller.activeGrouping;

        return DragTarget<TrinaColumn>(
          onWillAcceptWithDetails: (details) {
            return !controller.activeGrouping.contains(details.data.field);
          },
          onAcceptWithDetails: (details) {
            controller.addGroup(details.data.field);
          },
          builder: (context, candidateData, rejectedData) {
            final isHovering = candidateData.isNotEmpty;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isHovering
                    ? colorScheme.primary.withAlpha(isDark ? 50 : 25)
                    : panelBg,
                border: Border(
                  bottom: BorderSide(
                    color: isHovering ? colorScheme.primary : borderCol,
                    width: isHovering ? 2 : 1,
                  ),
                ),
              ),
              child: groups.isEmpty
                  ? _buildEmptyPlaceholder(context, isHovering)
                  : _buildGroupChips(context, groups, isHovering),
            );
          },
        );
      },
    );
  }

  Widget _buildAddColumnButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final available = controller.columns
        .where((c) => !controller.activeGrouping.contains(c.field))
        .toList();

    if (available.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      tooltip: 'Add column to group',
      icon: Icon(
        Icons.add_circle_outline,
        size: 16,
        color: colorScheme.primary,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 160),
      onSelected: (field) => controller.addGroup(field),
      itemBuilder: (context) => available
          .map(
            (c) => PopupMenuItem<String>(
              value: c.field,
              height: 32,
              child: Text(
                c.title,
                style: const TextStyle(fontSize: 12, fontFamily: 'Segoe UI'),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildEmptyPlaceholder(BuildContext context, bool isHovering) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(
          isHovering ? Icons.add_to_photos : Icons.view_column_outlined,
          size: 16,
          color: isHovering
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant.withAlpha(160),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isHovering
                ? 'Drop here to group by this column'
                : 'Drag a column header here to group by that column',
            style: TextStyle(
              color: isHovering
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant.withAlpha(160),
              fontSize: 12,
              fontWeight: isHovering ? FontWeight.w600 : FontWeight.normal,
              fontStyle: isHovering ? FontStyle.normal : FontStyle.italic,
              fontFamily: 'Segoe UI',
            ),
          ),
        ),
        _buildAddColumnButton(context),
      ],
    );
  }

  Widget _buildGroupChips(
    BuildContext context,
    List<String> groups,
    bool isHovering,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    final chipBg = isDark ? colorScheme.surfaceContainerHighest : Colors.white;
    final chipBorder = isDark
        ? colorScheme.outlineVariant.withAlpha(90)
        : AiGridTheme.borderColor;

    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...groups.map((field) {
                final col = controller.columns.firstWhere(
                  (c) => c.field == field,
                  orElse: () => controller.columns.first,
                );

                return Container(
                  padding: const EdgeInsets.only(
                    left: 10,
                    right: 4,
                    top: 3,
                    bottom: 3,
                  ),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: chipBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 50 : 15),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        col.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                          fontFamily: 'Segoe UI',
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_upward,
                        size: 12,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 2),
                      InkWell(
                        onTap: () => controller.removeGroup(field),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              _buildAddColumnButton(context),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: controller.clearGrouping,
          icon: const Icon(Icons.clear_all, size: 14),
          label: const Text('Clear', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onSurfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}
