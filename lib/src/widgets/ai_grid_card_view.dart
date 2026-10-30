import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../controllers/ai_grid_controller.dart';
import '../models/ai_grid_column.dart';
import '../models/ai_grid_view_mode.dart';
import 'ai_grid_context_menu.dart';

/// Responsive Card / Feed view for [AiGrid], ideal for mobile screens and compact layouts.
class AiGridCardView extends StatefulWidget {
  final AiGridController controller;
  final AiGridCardViewOptions options;

  const AiGridCardView({
    super.key,
    required this.controller,
    this.options = const AiGridCardViewOptions(),
  });

  @override
  State<AiGridCardView> createState() => _AiGridCardViewState();
}

class _AiGridCardViewState extends State<AiGridCardView> {
  final Set<int> _expandedRowIndices = <int>{};

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final rows = widget.controller.viewRows;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;

        if (rows.isEmpty) {
          return _buildEmptyState(context, colorScheme);
        }

        final columns = widget.controller.columns.isNotEmpty
            ? widget.controller.columns
            : (widget.controller.dataSource?.columns ?? const <AiGridColumn>[]);

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          itemCount: rows.length,
          separatorBuilder: (context, index) =>
              SizedBox(height: widget.options.spacing),
          itemBuilder: (context, index) {
            final row = rows[index];
            return _buildCardItem(
              context: context,
              row: row,
              rowIndex: index,
              columns: columns,
              theme: theme,
              colorScheme: colorScheme,
              isDark: isDark,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    final hasActiveFilter =
        widget.controller.activeFilters.isNotEmpty ||
        widget.controller.searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No records match your criteria',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasActiveFilter
                  ? 'Try clearing active filters or modifying search keywords.'
                  : 'The current dataset contains no records.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (hasActiveFilter) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.clear_all_rounded, size: 16),
                label: const Text('Reset Filters'),
                onPressed: () {
                  widget.controller.clearAllFilters();
                  widget.controller.setSearchQuery('');
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardItem({
    required BuildContext context,
    required Map<String, dynamic> row,
    required int rowIndex,
    required List<AiGridColumn> columns,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    if (widget.options.cardBuilder != null) {
      return widget.options.cardBuilder!(context, row, rowIndex);
    }

    final cardContent = Card(
      elevation: widget.options.elevation,
      shape: RoundedRectangleBorder(
        borderRadius:
            widget.options.borderRadius ?? BorderRadius.circular(10.0),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 0.8,
        ),
      ),
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius:
            widget.options.borderRadius ?? BorderRadius.circular(10.0),
        onTap: () {
          if (widget.controller.editingOptions.enabled &&
              widget.controller.editingOptions.allowUpdating) {
            widget.controller.showEditDialog(context, rowIndex: rowIndex);
          }
        },
        child: Padding(
          padding: widget.options.contentPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(
                context: context,
                row: row,
                rowIndex: rowIndex,
                columns: columns,
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 10),
              _buildFieldsGrid(
                row: row,
                columns: columns,
                colorScheme: colorScheme,
              ),
              if (widget.controller.isMasterDetailEnabled)
                _buildMasterDetailSection(
                  context: context,
                  row: row,
                  rowIndex: rowIndex,
                  colorScheme: colorScheme,
                ),
            ],
          ),
        ),
      ),
    );

    if (!widget.options.enableSwipeActions) {
      return cardContent;
    }

    final keyString = widget.controller.resolveRowKey(row).toString();

    return Dismissible(
      key: ValueKey('card_$keyString'),
      background: Container(
        decoration: BoxDecoration(
          color: Colors.green.shade600,
          borderRadius:
              widget.options.borderRadius ?? BorderRadius.circular(10),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Row(
          children: [
            Icon(Icons.edit_outlined, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'Edit',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius:
              widget.options.borderRadius ?? BorderRadius.circular(10),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right: Edit
          HapticFeedback.lightImpact();
          if (widget.controller.editingOptions.enabled &&
              widget.controller.editingOptions.allowUpdating) {
            widget.controller.showEditDialog(context, rowIndex: rowIndex);
          }
          return false; // Do not dismiss
        } else if (direction == DismissDirection.endToStart) {
          // Swipe left: Delete
          HapticFeedback.mediumImpact();
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete Record'),
              content: const Text(
                'Are you sure you want to delete this record?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            widget.controller.deleteRow(rowIndex);
            return true;
          }
          return false;
        }
        return false;
      },
      child: cardContent,
    );
  }

  Widget _buildHeader({
    required BuildContext context,
    required Map<String, dynamic> row,
    required int rowIndex,
    required List<AiGridColumn> columns,
    required ColorScheme colorScheme,
  }) {
    // Resolve primary title
    final primaryField =
        widget.options.primaryField ??
        columns
            .where(
              (c) =>
                  c.field != 'actions' &&
                  !widget.options.excludedFields.contains(c.field),
            )
            .firstOrNull
            ?.field;
    final primaryVal = primaryField != null
        ? row[primaryField]?.toString()
        : null;

    // Resolve subtitle
    final subtitleField =
        widget.options.subtitleField ??
        columns
            .where(
              (c) =>
                  c.field != 'actions' &&
                  c.field != primaryField &&
                  !widget.options.excludedFields.contains(c.field),
            )
            .firstOrNull
            ?.field;
    final subtitleVal = subtitleField != null
        ? row[subtitleField]?.toString()
        : null;

    // Resolve badge
    final badgeField = widget.options.badgeField;
    final badgeVal = badgeField != null ? row[badgeField]?.toString() : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.options.avatarField != null &&
            row[widget.options.avatarField!] != null) ...[
          CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              (primaryVal?.isNotEmpty ?? false)
                  ? primaryVal![0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                primaryVal ?? 'Record #$rowIndex',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitleVal != null && subtitleVal.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitleVal,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        if (badgeVal != null && badgeVal.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              badgeVal,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
        const SizedBox(width: 4),
        // AI Sparkle Quick Trigger
        IconButton(
          icon: Icon(Icons.auto_awesome, size: 18, color: colorScheme.primary),
          tooltip: 'Ask AI About Record',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () =>
              widget.controller.askAiAboutRow(row, context: context),
        ),
        // 3-dots Context Menu Button
        Builder(
          builder: (btnCtx) => IconButton(
            icon: Icon(
              Icons.more_vert_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Record Actions',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              final box = btnCtx.findRenderObject() as RenderBox?;
              final pos = box != null
                  ? box.localToGlobal(box.size.bottomRight(Offset.zero))
                  : Offset.zero;
              AiGridContextMenu.show(
                context: context,
                position: pos,
                controller: widget.controller,
                row: row,
                rowIndex: rowIndex,
                columnField: primaryField,
                cellValue: primaryVal,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFieldsGrid({
    required Map<String, dynamic> row,
    required List<AiGridColumn> columns,
    required ColorScheme colorScheme,
  }) {
    final primaryField = widget.options.primaryField;
    final subtitleField = widget.options.subtitleField;
    final badgeField = widget.options.badgeField;
    final avatarField = widget.options.avatarField;

    final displayCols = columns.where((c) {
      if (c.field == 'actions') return false;
      if (widget.options.excludedFields.contains(c.field)) return false;
      if (c.field == primaryField) return false;
      if (c.field == subtitleField) return false;
      if (c.field == badgeField) return false;
      if (c.field == avatarField) return false;
      return true;
    }).toList();

    if (displayCols.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use 2 columns for wider cards, 1 column for tight space
        final isTwoCol = constraints.maxWidth >= 320;
        final cellWidth = isTwoCol
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 8,
          children: displayCols.map((col) {
            final val = row[col.field];
            final formattedVal = _formatCellValue(col, val);

            return SizedBox(
              width: cellWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    col.title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    formattedVal,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _formatCellValue(AiGridColumn col, dynamic val) {
    if (val == null) return '—';
    return col.formatDisplayValue(val);
  }

  Widget _buildMasterDetailSection({
    required BuildContext context,
    required Map<String, dynamic> row,
    required int rowIndex,
    required ColorScheme colorScheme,
  }) {
    final opts = widget.controller.masterDetailOptions;
    if (opts == null) return const SizedBox.shrink();

    final isExpanded = _expandedRowIndices.contains(rowIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Divider(height: 1),
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedRowIndices.remove(rowIndex);
              } else {
                _expandedRowIndices.add(rowIndex);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  isExpanded ? 'Hide Details' : 'Show Details',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 4),
          SizedBox(
            height:
                opts.detailHeight?.call(row, rowIndex) ?? opts.detailRowHeight,
            child: opts.detailBuilder(context, row, rowIndex),
          ),
        ],
      ],
    );
  }
}
