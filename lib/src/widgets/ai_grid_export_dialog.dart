import 'dart:convert';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:trina_grid/trina_grid.dart';
import '../controllers/ai_grid_controller.dart';

/// Dialog for configuring and exporting grid data as CSV or JSON.
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
  String _selectedFormat = 'csv';
  bool _includeHeaders = true;
  bool _ignoreFixedRows = false;
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
    final sm = widget.controller.stateManager;
    if (sm == null) {
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

    final fileName = 'grid_export_${DateTime.now().millisecondsSinceEpoch}';

    try {
      String savedPath = '';
      if (_selectedFormat == 'csv') {
        final content = await TrinaGridExportCsv().export(
          stateManager: sm,
          columns: chosenColumns,
          includeHeaders: _includeHeaders,
          separator: _csvSeparator,
          ignoreFixedRows: _ignoreFixedRows,
        );
        savedPath = await FileSaver.instance.saveFile(
          name: fileName,
          bytes: Uint8List.fromList(utf8.encode(content)),
          fileExtension: 'csv',
          mimeType: MimeType.csv,
        );
      } else if (_selectedFormat == 'json') {
        final content = await TrinaGridExportJson().export(
          stateManager: sm,
          columns: chosenColumns,
          includeHeaders: _includeHeaders,
          ignoreFixedRows: _ignoreFixedRows,
        );
        savedPath = await FileSaver.instance.saveFile(
          name: fileName,
          bytes: Uint8List.fromList(utf8.encode(content)),
          fileExtension: 'json',
          mimeType: MimeType.json,
        );
      }

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
        width: 440,
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
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Ignore fixed/frozen rows', style: TextStyle(fontSize: 13)),
                value: _ignoreFixedRows,
                onChanged: (val) => setState(() => _ignoreFixedRows = val ?? false),
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
                    _separatorButton('\t', 'Tab (\t)'),
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
                  children: _selectedColumns.keys.map((colTitle) {
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      title: Text(colTitle, style: const TextStyle(fontSize: 13)),
                      value: _selectedColumns[colTitle] ?? false,
                      onChanged: (val) {
                        setState(() => _selectedColumns[colTitle] = val ?? false);
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
                      color: _isError ? Colors.red.shade200 : Colors.green.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isError ? Icons.error_outline : Icons.check_circle_outline,
                        color: _isError ? Colors.red : Colors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _isError ? Colors.red.shade900 : Colors.green.shade900,
                          ),
                        ),
                      ),
                    ],
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
          label: Text(_isExporting ? 'Exporting...' : 'Export'),
        ),
      ],
    );
  }

  Widget _separatorButton(String val, String label) {
    final isSelected = _csvSeparator == val;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (_) => setState(() => _csvSeparator = val),
      selectedColor: colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
