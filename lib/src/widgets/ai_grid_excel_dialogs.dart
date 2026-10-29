import 'package:material_ui/material_ui.dart';

import '../data/excel_table_parser.dart';

/// Interactive Material 3 dialog for selecting and previewing worksheets
/// from an Excel (.xlsx) workbook.
class AiGridExcelSheetPickerDialog extends StatefulWidget {
  /// The parsed workbook containing one or more worksheets.
  final AiGridExcelWorkbook workbook;

  /// Optional initial sheet name to select. Defaults to the first sheet.
  final String? initialSheetName;

  const AiGridExcelSheetPickerDialog({
    super.key,
    required this.workbook,
    this.initialSheetName,
  });

  /// Static helper to display the sheet selection dialog.
  ///
  /// Returns the selected [AiGridExcelSheet], or null if canceled.
  static Future<AiGridExcelSheet?> show(
    BuildContext context, {
    required AiGridExcelWorkbook workbook,
    String? initialSheetName,
  }) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    if (isMobile) {
      return Navigator.of(context).push<AiGridExcelSheet>(
        MaterialPageRoute<AiGridExcelSheet>(
          fullscreenDialog: true,
          builder: (ctx) => AiGridExcelSheetPickerDialog(
            workbook: workbook,
            initialSheetName: initialSheetName,
          ),
        ),
      );
    }

    return showDialog<AiGridExcelSheet>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AiGridExcelSheetPickerDialog(
        workbook: workbook,
        initialSheetName: initialSheetName,
      ),
    );
  }

  @override
  State<AiGridExcelSheetPickerDialog> createState() =>
      _AiGridExcelSheetPickerDialogState();
}

class _AiGridExcelSheetPickerDialogState
    extends State<AiGridExcelSheetPickerDialog> {
  late AiGridExcelSheet _selectedSheet;

  @override
  void initState() {
    super.initState();
    if (widget.initialSheetName != null) {
      final found = widget.workbook.getSheet(widget.initialSheetName!);
      _selectedSheet = found ?? widget.workbook.primarySheet!;
    } else {
      _selectedSheet = widget.workbook.primarySheet!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.workbook.fileName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_selectedSheet),
              child: const Text('Import'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            _buildWorkbookHeader(context),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'SELECT WORKSHEET (${widget.workbook.sheets.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...widget.workbook.sheets.map(
                    (sheet) => _buildSheetTile(sheet),
                  ),
                  const SizedBox(height: 16),
                  _buildPreviewSection(context),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildWorkbookHeader(context),
            const Divider(height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Sheet Selection List
                  SizedBox(
                    width: 280,
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? colorScheme.surfaceContainerHighest.withValues(
                                alpha: 0.3,
                              )
                            : colorScheme.surfaceContainerLow,
                        border: Border(
                          right: BorderSide(
                            color: theme.dividerColor.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Row(
                              children: [
                                Text(
                                  'WORKSHEETS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${widget.workbook.sheets.length}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              itemCount: widget.workbook.sheets.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                final sheet = widget.workbook.sheets[index];
                                return _buildSheetTile(sheet);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Right Live Preview Pane
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _buildPreviewSection(context),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _buildDialogFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkbookHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF107C41).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.table_chart_rounded,
              color: Color(0xFF107C41),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.workbook.fileName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF107C41).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '.xlsx',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF107C41),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Select which worksheet you would like to import into AI Grid',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetTile(AiGridExcelSheet sheet) {
    final isSelected =
        sheet.sheetId == _selectedSheet.sheetId &&
        sheet.name == _selectedSheet.name;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedSheet = sheet;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sheet.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected ? colorScheme.primary : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${sheet.rowCount} rows • ${sheet.columnCount} cols',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.preview_rounded, size: 16, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'SHEET PREVIEW: ${_selectedSheet.name}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: colorScheme.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_selectedSheet.rowCount} rows • ${_selectedSheet.columnCount} columns',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Columns Chips
        if (_selectedSheet.headers.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _selectedSheet.columns.take(8).map((col) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      col.title,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      col.type.name,
                      style: TextStyle(
                        fontSize: 9,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Sample Rows Preview Table
        Expanded(
          child: _selectedSheet.rows.isEmpty
              ? Center(
                  child: Text(
                    'No data rows found in this sheet.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        headingRowHeight: 36,
                        dataRowMinHeight: 32,
                        dataRowMaxHeight: 32,
                        headingRowColor: WidgetStateProperty.all(
                          colorScheme.surfaceContainerHighest,
                        ),
                        columns: _selectedSheet.columns.map((col) {
                          return DataColumn(
                            label: Text(
                              col.title,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                        rows: _selectedSheet.previewRows.map((row) {
                          return DataRow(
                            cells: _selectedSheet.columns.map((col) {
                              final val = row[col.field];
                              return DataCell(
                                Text(
                                  val?.toString() ?? '',
                                  style: const TextStyle(fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildDialogFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: FilledButton.icon(
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(
                'Import "${_selectedSheet.name}"',
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () => Navigator.of(context).pop(_selectedSheet),
            ),
          ),
        ],
      ),
    );
  }
}
