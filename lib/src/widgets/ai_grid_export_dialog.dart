import 'package:material_ui/material_ui.dart';
import '../controllers/ai_grid_controller.dart';

/// Dialog for configuring and exporting grid data as CSV, XLSX, TSV, or JSON.
class AiGridExportDialog extends StatefulWidget {
  final AiGridController controller;

  const AiGridExportDialog({
    super.key,
    required this.controller,
  });

  /// Helper to display the export dialog.
  static Future<void> show(BuildContext context, AiGridController controller) {
    return showDialog(
      context: context,
      builder: (context) => AiGridExportDialog(controller: controller),
    );
  }

  @override
  State<AiGridExportDialog> createState() => _AiGridExportDialogState();
}

class _AiGridExportDialogState extends State<AiGridExportDialog> {
  String _selectedFormat = 'xlsx';
  bool _includeHeaders = true;
  String _csvSeparator = ',';
  bool _isExporting = false;
  String? _statusMessage;
  bool _isError = false;

  final Map<String, bool> _selectedColumns = {};

  @override
  void initState() {
    super.initState();
    final columns = widget.controller.columns;
    for (final col in columns) {
      _selectedColumns[col.title] = true;
    }
  }

  Future<void> _handleExport() async {
    if (!widget.controller.isAttached) {
      setState(() {
        _isError = true;
        _statusMessage = 'Grid is not ready for export.';
      });
      return;
    }

    final chosenColumns = _selectedColumns.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (chosenColumns.isEmpty) {
      setState(() {
        _isError = true;
        _statusMessage = 'Please select at least one column.';
      });
      return;
    }

    setState(() {
      _isExporting = true;
      _statusMessage = null;
      _isError = false;
    });

    try {
      final savedPath = await widget.controller.exportGrid(
        format: _selectedFormat,
        columns: chosenColumns,
        includeHeaders: _includeHeaders,
        separator: _csvSeparator,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Export saved successfully! ${savedPath.isNotEmpty ? "($savedPath)" : ""}',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _isError = true;
          _statusMessage = 'Export failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.file_download_outlined, color: colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Export Grid Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Export Format', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'xlsx',
                    label: Text('Excel (XLSX)'),
                    icon: Icon(Icons.table_view_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: 'csv',
                    label: Text('CSV'),
                    icon: Icon(Icons.table_chart_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: 'json',
                    label: Text('JSON'),
                    icon: Icon(Icons.code, size: 16),
                  ),
                ],
                selected: {_selectedFormat},
                onSelectionChanged: (newSet) {
                  setState(() => _selectedFormat = newSet.first);
                },
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Include column headers', style: TextStyle(fontSize: 13)),
                value: _includeHeaders,
                onChanged: (val) => setState(() => _includeHeaders = val ?? true),
              ),
              if (_selectedFormat == 'csv') ...[
                const SizedBox(height: 8),
                const Text('CSV Separator:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _separatorButton(',', 'Comma (,)'),
                    const SizedBox(width: 8),
                    _separatorButton(';', 'Semicolon (;)'),
                    const SizedBox(width: 8),
                    _separatorButton('\t', 'Tab (\\t)'),
                  ],
                ),
              ],
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Select Columns', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            for (final k in _selectedColumns.keys) {
                              _selectedColumns[k] = true;
                            }
                          });
                        },
                        child: const Text('All', style: TextStyle(fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            for (final k in _selectedColumns.keys) {
                              _selectedColumns[k] = false;
                            }
                          });
                        },
                        child: const Text('None', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDark ? colorScheme.outlineVariant.withAlpha(80) : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: _selectedColumns.entries.map((entry) {
                    return CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      title: Text(entry.key, style: const TextStyle(fontSize: 13)),
                      value: entry.value,
                      onChanged: (val) {
                        setState(() {
                          _selectedColumns[entry.key] = val ?? false;
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isError ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _isError ? Colors.red.shade300 : Colors.green.shade300,
                    ),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      color: _isError ? Colors.red.shade900 : Colors.green.shade900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isExporting ? null : _handleExport,
          icon: _isExporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.file_download, size: 16),
          label: Text(_isExporting ? 'Exporting...' : 'Export File'),
        ),
      ],
    );
  }

  Widget _separatorButton(String sep, String label) {
    final isSelected = _csvSeparator == sep;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _csvSeparator = sep);
      },
      selectedColor: colorScheme.primaryContainer,
    );
  }
}
