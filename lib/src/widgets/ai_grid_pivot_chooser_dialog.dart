import 'package:flutter/material.dart';
import '../controllers/ai_grid_controller.dart';
import '../models/ai_grid_column.dart';
import '../models/ai_grid_pivot.dart';

/// DevExtreme-style Pivot Grid Field Chooser Dialog.
///
/// Allows visual configuration of:
/// 1. Row fields (vertical grouping dimensions)
/// 2. Column fields (horizontal grouping dimensions)
/// 3. Data fields / measures (with aggregation function selector)
/// 4. Side-by-side Chart options and Grand Totals
class AiGridPivotChooserDialog extends StatefulWidget {
  const AiGridPivotChooserDialog({
    super.key,
    required this.controller,
  });

  final AiGridController controller;

  /// Shows the dialog.
  static Future<void> show(BuildContext context, AiGridController controller) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AiGridPivotChooserDialog(controller: controller),
    );
  }

  @override
  State<AiGridPivotChooserDialog> createState() => _AiGridPivotChooserDialogState();
}

class _AiGridPivotChooserDialogState extends State<AiGridPivotChooserDialog> {
  late List<String> _rowFieldIds;
  late List<String> _columnFieldIds;
  late List<AiGridPivotValueConfig> _values;
  late bool _showColumnTotals;
  late bool _showChart;
  late AiGridPivotChartType _chartType;
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    final active = widget.controller.pivotConfig;
    if (active != null) {
      _rowFieldIds = List<String>.from(active.rowFieldIds);
      _columnFieldIds = List<String>.from(active.columnFieldIds);
      _values = List<AiGridPivotValueConfig>.from(active.values);
      _showColumnTotals = active.showColumnTotals;
      _showChart = active.showChart;
      _chartType = active.chartType;
    } else {
      // Sensible defaults from available columns
      final allCols = _availableColumns;
      final textCols = allCols.where((c) => c.type == AiGridColumnType.text).toList();
      final numCols = allCols.where((c) => c.type == AiGridColumnType.number || c.type == AiGridColumnType.currency).toList();

      _rowFieldIds = textCols.isNotEmpty ? [textCols.first.field] : (allCols.isNotEmpty ? [allCols.first.field] : []);
      _columnFieldIds = textCols.length > 1 ? [textCols[1].field] : [];
      _values = numCols.isNotEmpty
          ? [AiGridPivotValueConfig(columnId: numCols.first.field, aggregation: AiGridPivotAggregation.sum)]
          : (allCols.isNotEmpty
              ? [AiGridPivotValueConfig(columnId: allCols.last.field, aggregation: AiGridPivotAggregation.count)]
              : []);
      _showColumnTotals = true;
      _showChart = true;
      _chartType = AiGridPivotChartType.groupedBar;
    }
  }

  List<AiGridColumn> get _availableColumns {
    // If pivot is active, use the original columns preserved by controller
    return widget.controller.columns;
  }

  String _columnTitle(String field) {
    for (final col in _availableColumns) {
      if (col.field == field) return col.title;
    }
    return field;
  }

  void _apply() {
    if (_rowFieldIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one Row field.')),
      );
      return;
    }
    if (_values.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one Data / Metric field.')),
      );
      return;
    }

    final config = AiGridPivotConfig(
      rowFieldIds: _rowFieldIds,
      columnFieldIds: _columnFieldIds,
      values: _values,
      showColumnTotals: _showColumnTotals,
      showChart: _showChart,
      chartType: _chartType,
    );

    widget.controller.setPivot(config);
    Navigator.of(context).pop();
  }

  void _reset() {
    widget.controller.clearPivot();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredColumns = _availableColumns.where((col) {
      if (_searchFilter.isEmpty) return true;
      final q = _searchFilter.toLowerCase();
      return col.title.toLowerCase().contains(q) || col.field.toLowerCase().contains(q);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF1F5F9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  Icon(Icons.pivot_table_chart, color: theme.colorScheme.primary, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Pivot Table Field Chooser',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    splashRadius: 18,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content Body: Split into All Fields (Left) and Drop Zones (Right)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left: All Available Fields
                  Container(
                    width: 280,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Available Fields',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Search fields...',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onChanged: (val) => setState(() => _searchFilter = val),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: filteredColumns.length,
                            itemBuilder: (context, idx) {
                              final col = filteredColumns[idx];
                              final isNumeric = col.type == AiGridColumnType.number ||
                                  col.type == AiGridColumnType.currency;
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                elevation: 0.5,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isNumeric ? Icons.numbers : Icons.text_fields,
                                        size: 16,
                                        color: isNumeric ? Colors.teal : Colors.blueGrey,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          col.title,
                                          style: const TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        tooltip: 'Add to area',
                                        icon: const Icon(Icons.add_circle_outline, size: 18),
                                        padding: EdgeInsets.zero,
                                        onSelected: (target) {
                                          setState(() {
                                            if (target == 'row' && !_rowFieldIds.contains(col.field)) {
                                              _rowFieldIds.add(col.field);
                                            } else if (target == 'col' && !_columnFieldIds.contains(col.field)) {
                                              _columnFieldIds.add(col.field);
                                            } else if (target == 'data') {
                                              _values.add(AiGridPivotValueConfig(
                                                columnId: col.field,
                                                aggregation: isNumeric
                                                    ? AiGridPivotAggregation.sum
                                                    : AiGridPivotAggregation.count,
                                              ));
                                            }
                                          });
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(value: 'row', child: Text('Add to Rows')),
                                          const PopupMenuItem(value: 'col', child: Text('Add to Columns')),
                                          const PopupMenuItem(value: 'data', child: Text('Add to Data (Measures)')),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right: 3 Selection Zones (Rows, Columns, Data/Measures)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Rows Zone
                          _buildZone(
                            title: 'Row Fields (Tree & Vertical Grouping)',
                            icon: Icons.table_rows,
                            color: Colors.blue.shade700,
                            items: _rowFieldIds,
                            onRemove: (id) => setState(() => _rowFieldIds.remove(id)),
                          ),
                          const SizedBox(height: 12),

                          // Columns Zone
                          _buildZone(
                            title: 'Column Fields (Horizontal Breakdown)',
                            icon: Icons.view_column,
                            color: Colors.indigo.shade700,
                            items: _columnFieldIds,
                            onRemove: (id) => setState(() => _columnFieldIds.remove(id)),
                          ),
                          const SizedBox(height: 12),

                          // Data / Measures Zone
                          Expanded(
                            child: _buildDataMeasuresZone(),
                          ),

                          const SizedBox(height: 10),
                          const Divider(),

                          // Options Row: Chart & Totals
                          Row(
                            children: [
                              Checkbox(
                                value: _showChart,
                                onChanged: (v) => setState(() => _showChart = v ?? false),
                              ),
                              const Text('Auto-create Chart', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 8),
                              if (_showChart)
                                DropdownButton<AiGridPivotChartType>(
                                  value: _chartType,
                                  isDense: true,
                                  underline: const SizedBox.shrink(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  items: AiGridPivotChartType.values.map((t) {
                                    return DropdownMenuItem(
                                      value: t,
                                      child: Text(t.displayName),
                                    );
                                  }).toList(),
                                  onChanged: (t) {
                                    if (t != null) setState(() => _chartType = t);
                                  },
                                ),
                              const Spacer(),
                              Checkbox(
                                value: _showColumnTotals,
                                onChanged: (v) => setState(() => _showColumnTotals = v ?? true),
                              ),
                              const Text('Grand Totals', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Actions Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF252526) : const Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0),
                  ),
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  if (widget.controller.isPivotActive)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.undo, size: 16),
                      label: const Text('Reset to Normal Table'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                      onPressed: _reset,
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Apply Pivot'),
                    onPressed: _apply,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZone({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
    required ValueChanged<String> onRemove,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withAlpha(80)),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'None (add from left panel)',
                style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final id in items)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    label: Text(_columnTitle(id), style: const TextStyle(fontSize: 11)),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => onRemove(id),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDataMeasuresZone() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withAlpha(80)),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate, size: 15, color: Colors.teal.shade700),
              const SizedBox(width: 6),
              Text(
                'Data Fields / Measures (Aggregated Values)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_values.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No measures selected. Add numeric fields from left.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _values.length,
                itemBuilder: (context, idx) {
                  final val = _values[idx];
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.withAlpha(60)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _columnTitle(val.columnId),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                        // Aggregation Selector Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: Colors.teal.withAlpha(25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButton<AiGridPivotAggregation>(
                            value: val.aggregation,
                            underline: const SizedBox.shrink(),
                            isDense: true,
                            style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold),
                            items: AiGridPivotAggregation.values.map((agg) {
                              return DropdownMenuItem(
                                value: agg,
                                child: Text(agg.displayName),
                              );
                            }).toList(),
                            onChanged: (newAgg) {
                              if (newAgg != null) {
                                setState(() {
                                  _values[idx] = val.copyWith(aggregation: newAgg);
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.redAccent),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          tooltip: 'Remove',
                          onPressed: () {
                            setState(() => _values.removeAt(idx));
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
