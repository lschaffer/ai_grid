import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../controllers/ai_grid_controller.dart';
import '../models/ai_grid_editing_options.dart';
import '../models/ai_grid_view_mode.dart';

/// Context menu builder and presenter for cell/row right-clicks, long-presses, and card popups.
class AiGridContextMenu {
  const AiGridContextMenu._();

  /// Builds a list of [PopupMenuEntry] elements tailored for the selected record and cell.
  static List<PopupMenuEntry<void>> buildMenuItems({
    required BuildContext context,
    required AiGridController controller,
    required Map<String, dynamic> row,
    required int rowIndex,
    String? columnField,
    dynamic cellValue,
    List<PopupMenuEntry<void>>? defaultItems,
  }) {
    final config = controller.contextMenuConfig;
    if (!config.enabled) {
      return defaultItems ?? const <PopupMenuEntry<void>>[];
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final items = <PopupMenuEntry<void>>[];

    // --- Helper to build consistent menu items ---
    PopupMenuItem<void> createItem({
      required String label,
      required IconData icon,
      required VoidCallback onTap,
      bool isAi = false,
      bool isDestructive = false,
    }) {
      final itemColor = isDestructive
          ? colorScheme.error
          : (isAi ? colorScheme.primary : colorScheme.onSurface);

      return PopupMenuItem<void>(
        onTap: () {
          onTap();
          config.onActionExecuted?.call(label, row);
        },
        height: 38,
        child: Row(
          children: [
            Icon(icon, size: 18, color: itemColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isAi ? FontWeight.w600 : FontWeight.normal,
                  color: itemColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isAi)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'AI',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // 1. AI Actions
    if (config.enableAiActions) {
      items.add(
        createItem(
          label: 'Ask AI About Record',
          icon: Icons.auto_awesome,
          isAi: true,
          onTap: () => controller.askAiAboutRow(row, context: context),
        ),
      );
      items.add(
        createItem(
          label: 'Draft Message / Email',
          icon: Icons.mail_outline_rounded,
          isAi: true,
          onTap: () => controller.draftMessageFromRow(row, context: context),
        ),
      );
      if (columnField != null) {
        items.add(
          createItem(
            label: 'Explain Value ($columnField)',
            icon: Icons.lightbulb_outline_rounded,
            isAi: true,
            onTap: () =>
                controller.explainCellValue(row, columnField, context: context),
          ),
        );
      }
    }

    // 2. Filter Similar Records
    if (config.enableFilterSimilar &&
        columnField != null &&
        cellValue != null &&
        cellValue.toString().trim().isNotEmpty) {
      if (items.isNotEmpty) items.add(const PopupMenuDivider(height: 8));
      final valStr = cellValue.toString();
      final preview = valStr.length > 16
          ? '${valStr.substring(0, 14)}…'
          : valStr;
      items.add(
        createItem(
          label: 'Filter Similar: $preview',
          icon: Icons.filter_alt_outlined,
          onTap: () =>
              controller.filterSimilar(field: columnField, value: cellValue),
        ),
      );
    }

    // 3. Clipboard Actions
    if (config.enableClipboardActions) {
      if (items.isNotEmpty) items.add(const PopupMenuDivider(height: 8));
      if (cellValue != null) {
        items.add(
          createItem(
            label: 'Copy Cell Value',
            icon: Icons.copy_outlined,
            onTap: () {
              Clipboard.setData(ClipboardData(text: cellValue.toString()));
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(
                  content: Text('Copied "$cellValue" to clipboard'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        );
      }
      items.add(
        createItem(
          label: 'Copy Row (JSON)',
          icon: Icons.data_object_rounded,
          onTap: () {
            Clipboard.setData(ClipboardData(text: jsonEncode(row)));
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              const SnackBar(
                content: Text('Copied row JSON to clipboard'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      );
    }

    // 4. Row Editing Actions
    if (config.enableEditingActions && controller.editingOptions.enabled) {
      if (items.isNotEmpty) items.add(const PopupMenuDivider(height: 8));
      if (controller.editingOptions.allowUpdating) {
        items.add(
          createItem(
            label: 'Edit Row',
            icon: Icons.edit_outlined,
            onTap: () {
              if (controller.editingOptions.mode == AiGridEditMode.form ||
                  controller.viewMode == AiGridViewMode.card) {
                controller.showEditDialog(context, rowIndex: rowIndex);
              } else {
                controller.startEditingRow(rowIndex);
              }
            },
          ),
        );
      }
      if (controller.editingOptions.allowDeleting) {
        items.add(
          createItem(
            label: 'Delete Row',
            icon: Icons.delete_outline_rounded,
            isDestructive: true,
            onTap: () => controller.deleteRow(rowIndex),
          ),
        );
      }
    }

    // 5. Custom Developer Actions
    final visibleCustom = config.customActions
        .where((act) => act.isVisible?.call(row, columnField) ?? true)
        .toList();

    if (visibleCustom.isNotEmpty) {
      if (items.isNotEmpty) items.add(const PopupMenuDivider(height: 8));
      for (final action in visibleCustom) {
        items.add(
          createItem(
            label: action.label,
            icon: action.icon ?? Icons.play_arrow_outlined,
            isAi: action.isAiAction,
            isDestructive: action.isDestructive,
            onTap: () => action.onExecute(
              context,
              controller,
              row,
              rowIndex,
              columnField,
            ),
          ),
        );
      }
    }

    return items;
  }

  /// Displays the contextual popup menu at [position].
  static Future<void> show({
    required BuildContext context,
    required Offset position,
    required AiGridController controller,
    required Map<String, dynamic> row,
    required int rowIndex,
    String? columnField,
    dynamic cellValue,
  }) async {
    final items = buildMenuItems(
      context: context,
      controller: controller,
      row: row,
      rowIndex: rowIndex,
      columnField: columnField,
      cellValue: cellValue,
    );

    if (items.isEmpty || !context.mounted) return;

    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final overlaySize = overlay?.size ?? MediaQuery.of(context).size;

    await showMenu<void>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlaySize,
      ),
      items: items,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
