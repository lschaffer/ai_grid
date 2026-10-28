import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:ai_grid/ai_grid.dart';
import '../dynamic_ai_grid_example.dart';
class SuperstoreGridPage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const SuperstoreGridPage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<SuperstoreGridPage> createState() => _SuperstoreGridPageState();
}

class _SuperstoreGridPageState extends State<SuperstoreGridPage> {
  LocalAiGridDataSource? _dataSource;
  late final AiGridController _controller;
  AiGridConfig? _aiConfig;
  bool _isLoading = true;
  String? _errorMessage;
  AiGridEditMode _editMode = AiGridEditMode.row;

  @override
  void initState() {
    super.initState();
    _controller = AiGridController();

    // Configure LLM from .env or fallback
    final llmConfig = AiGridEnvLoader.createLlmConfigFromEnv();
    _aiConfig = AiGridConfig(
      llmConfig: llmConfig,
      suggestedPrompts: const [
        'Select top 5 sales cells',
        'Calculate average profit by Segment',
        'Pivot by Category and Region with sum of sales',
        'Filter Furniture in West region',
        'Export table to Excel',
      ],
    );

    // Configure DevExtreme-style editing features
    _controller.editingOptions = AiGridEditingOptions(
      enabled: true,
      mode: _editMode,
      allowAdding: true,
      allowUpdating: true,
      allowDeleting: true,
      actionColumnPosition: AiGridActionColumnPosition.right,
      formLayout: const AiGridFormLayout.grid(columns: 2),
      insertRowPosition: AiGridInsertRowPosition.top,
      popupTitle: 'Superstore Order Details',
      afterSave: (row) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order ${row['OrderID'] ?? ''} saved successfully!'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      },
      afterDelete: (row) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order ${row['OrderID'] ?? ''} deleted.'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );

    _loadSuperstoreJson();
  }

  Future<void> _loadSuperstoreJson() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/superstore_sales_1000.json');
      final List<dynamic> decoded = jsonDecode(jsonString);
      final records = decoded.cast<Map<String, dynamic>>();

      // Extract distinct sorted values for select/dropdown fields
      final shipModes = records
          .map((r) => r['ShipMode']?.toString())
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      final segments = records
          .map((r) => r['Segment']?.toString())
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      final countries = records
          .map((r) => r['Country']?.toString())
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      final cities = records
          .map((r) => r['City']?.toString())
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      final states = records
          .map((r) => r['State']?.toString())
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      final regions = records
          .map((r) => r['Region']?.toString())
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      final categories = records
          .map((r) => r['Category']?.toString())
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      final subCategories = records
          .map((r) => r['SubCategory']?.toString())
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      final columns = [
        const AiGridColumn(
          field: 'OrderID',
          title: 'Order ID',
          type: AiGridColumnType.text,
          aggregateType: AiGridAggregateType.count,
          numberFormat: '#,###',
          width: 140,
          editable: true,
          required: true,
          editorIndex: 0,
        ),
        const AiGridColumn(
          field: 'OrderDate',
          title: 'Order Date',
          type: AiGridColumnType.date,
          editorType: AiGridEditorType.date,
          width: 140,
          editable: true,
          editorIndex: 1,
        ),
        const AiGridColumn(
          field: 'ShipDate',
          title: 'Ship Date',
          type: AiGridColumnType.date,
          editorType: AiGridEditorType.date,
          width: 140,
          editable: true,
          editorIndex: 2,
        ),
        AiGridColumn(
          field: 'ShipMode',
          title: 'Ship Mode',
          type: AiGridColumnType.select,
          selectOptions: shipModes,
          width: 130,
          editable: true,
          editorIndex: 3,
        ),
        const AiGridColumn(
          field: 'CustomerID',
          title: 'Customer ID',
          type: AiGridColumnType.text,
          width: 120,
          editable: true,
          editorIndex: 4,
        ),
        const AiGridColumn(
          field: 'CustomerName',
          title: 'Customer Name',
          type: AiGridColumnType.text,
          width: 160,
          editable: true,
          editorIndex: 5,
        ),
        AiGridColumn(
          field: 'Segment',
          title: 'Segment',
          type: AiGridColumnType.select,
          selectOptions: segments,
          width: 120,
          editable: true,
          editorIndex: 6,
        ),
        AiGridColumn(
          field: 'Country',
          title: 'Country',
          type: AiGridColumnType.select,
          selectOptions: countries,
          width: 120,
          editable: true,
          editorIndex: 7,
        ),
        AiGridColumn(
          field: 'City',
          title: 'City',
          type: AiGridColumnType.select,
          selectOptions: cities,
          width: 140,
          editable: true,
          editorIndex: 8,
        ),
        AiGridColumn(
          field: 'State',
          title: 'State',
          type: AiGridColumnType.select,
          selectOptions: states,
          width: 130,
          editable: true,
          editorIndex: 9,
        ),
        const AiGridColumn(
          field: 'PostalCode',
          title: 'Postal Code',
          type: AiGridColumnType.number,
          width: 110,
          editable: true,
          editorIndex: 10,
        ),
        AiGridColumn(
          field: 'Region',
          title: 'Region',
          type: AiGridColumnType.select,
          selectOptions: regions,
          width: 110,
          editable: true,
          editorIndex: 11,
        ),
        const AiGridColumn(
          field: 'ProductID',
          title: 'Product ID',
          type: AiGridColumnType.text,
          width: 150,
          editable: true,
          editorIndex: 12,
        ),
        AiGridColumn(
          field: 'Category',
          title: 'Category',
          type: AiGridColumnType.select,
          selectOptions: categories,
          width: 130,
          editable: true,
          editorIndex: 13,
        ),
        AiGridColumn(
          field: 'SubCategory',
          title: 'Sub-Category',
          type: AiGridColumnType.select,
          selectOptions: subCategories,
          width: 140,
          editable: true,
          editorIndex: 14,
        ),
        const AiGridColumn(
          field: 'ProductName',
          title: 'Product Name',
          type: AiGridColumnType.text,
          width: 260,
          editable: true,
          editorIndex: 15,
        ),
        const AiGridColumn(
          field: 'Sales',
          title: 'Sales',
          type: AiGridColumnType.currency,
          aggregateType: AiGridAggregateType.sum,
          width: 130,
          editable: false,
        ),
        const AiGridColumn(
          field: 'Quantity',
          title: 'Quantity',
          type: AiGridColumnType.number,
          aggregateType: AiGridAggregateType.sum,
          width: 100,
          editable: true,
          editorIndex: 16,
        ),
        const AiGridColumn(
          field: 'Discount',
          title: 'Discount',
          type: AiGridColumnType.number,
          aggregateType: AiGridAggregateType.average,
          width: 110,
          editable: true,
          editorIndex: 17,
        ),
        const AiGridColumn(
          field: 'Profit',
          title: 'Profit',
          type: AiGridColumnType.currency,
          aggregateType: AiGridAggregateType.sum,
          width: 130,
          editable: false,
        ),
      ];

      final ds = LocalAiGridDataSource(
        columns: columns,
        initialData: records,
      );

      if (mounted) {
        setState(() {
          _dataSource = ds;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Error loading Superstore dataset: $e\n$stack');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _dataSource?.dispose();
    super.dispose();
  }

  Future<void> _exportSettingsToJsonFile() async {
    try {
      final jsonStr = _controller.exportSettingsJson();
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));
      final fileName = 'grid_settings_${DateTime.now().millisecondsSinceEpoch}';
      final savedPath = await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        fileExtension: 'json',
        mimeType: MimeType.json,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Settings exported to JSON! ${savedPath.isNotEmpty ? "($savedPath)" : ""}',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export settings: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showRestoreSettingsDialog() {
    final textController = TextEditingController(text: _controller.exportSettingsJson());
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    showDialog(
      context: context,
      builder: (ctx) {
        if (isMobile) {
          return Dialog.fullscreen(
            child: Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
                title: const Text('Restore Layout Settings'),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilledButton.tonal(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _controller.restoreSettingsJson(textController.text);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Grid layout successfully restored!'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Paste or edit a valid FitGrid JSON configuration below (supports columnOrder, widths, frozen, sorts, filters, and groupColumns):',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TextField(
                        controller: textController,
                        maxLines: null,
                        expands: true,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return AlertDialog(
          title: const Text('Restore Grid Layout Settings'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste or edit a valid FitGrid JSON configuration below (supports columnOrder, widths, frozen, sorts, filters, and groupColumns):',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  maxLines: 10,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.restore, size: 16),
              label: const Text('Apply Layout'),
              onPressed: () {
                Navigator.pop(ctx);
                _controller.restoreSettingsJson(textController.text);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Grid layout successfully restored!'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditingEventLogDialog(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final events = _controller.editEvents.reversed.toList();
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;

            Color getActionColor(String action) {
              switch (action) {
                case 'save':
                  return Colors.green;
                case 'startEdit':
                  return Colors.blue;
                case 'startAdd':
                  return Colors.teal;
                case 'change':
                  return Colors.purple;
                case 'delete':
                  return Colors.red;
                case 'cancel':
                  return Colors.orange;
                case 'error':
                  return Colors.redAccent;
                default:
                  return colorScheme.primary;
              }
            }

            IconData getActionIcon(String action) {
              switch (action) {
                case 'save':
                  return Icons.check_circle_outline;
                case 'startEdit':
                  return Icons.edit_outlined;
                case 'startAdd':
                  return Icons.add_circle_outline;
                case 'change':
                  return Icons.sync_alt;
                case 'delete':
                  return Icons.delete_outline;
                case 'cancel':
                  return Icons.cancel_outlined;
                case 'error':
                  return Icons.error_outline;
                default:
                  return Icons.info_outline;
              }
            }

            final contentBody = events.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history_outlined, size: 48, color: colorScheme.outlineVariant),
                            const SizedBox(height: 12),
                            Text(
                              'No editing events recorded yet',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Edit a row, change cell values, or delete/add records to see live event logs here.',
                              style: TextStyle(fontSize: 12, color: colorScheme.outline),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: events.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final event = events[index];
                          final actionColor = getActionColor(event.action);
                          final timeStr =
                              '${event.timestamp.hour.toString().padLeft(2, '0')}:${event.timestamp.minute.toString().padLeft(2, '0')}:${event.timestamp.second.toString().padLeft(2, '0')}';

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: actionColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: actionColor.withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(getActionIcon(event.action), size: 12, color: actionColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        event.action.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: actionColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event.message,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                      if (event.data != null && event.data!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            event.data!.entries
                                                .take(4)
                                                .map((e) => '${e.key}: ${e.value}')
                                                .join(' â€¢ '),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontFamily: 'monospace',
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.outline,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );

            if (isMobile) {
              return Dialog.fullscreen(
                child: Scaffold(
                  appBar: AppBar(
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    title: Text('Editing Event Log (${events.length})'),
                    actions: [
                      if (events.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.delete_sweep_outlined),
                          tooltip: 'Clear Log',
                          onPressed: () {
                            _controller.clearEditEvents();
                            setDialogState(() {});
                          },
                        ),
                    ],
                  ),
                  body: contentBody,
                ),
              );
            }

            return AlertDialog(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.receipt_long, size: 20, color: colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 10),
                  const Text('Editing Event Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${events.length} events',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 620,
                height: 460,
                child: contentBody,
              ),
              actions: [
                if (events.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                    label: const Text('Clear Log'),
                    onPressed: () {
                      _controller.clearEditEvents();
                      setDialogState(() {});
                    },
                  ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

    final isMobile = MediaQuery.sizeOf(context).width < 700;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        titleSpacing: isMobile ? 8 : 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.table_chart_outlined, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                isMobile ? 'Superstore' : 'Superstore Sales (1,000 JSON)',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isMobile) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _aiConfig?.llmConfig != null &&
                          _aiConfig!.llmConfig!.isConfigured
                      ? '${_aiConfig!.llmConfig!.provider.displayName} Active'
                      : 'Local Heuristic AI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: isMobile
            ? [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  tooltip: 'Menu & Options',
                  onSelected: (val) async {
                    if (val == 'dynamic_ai_grid') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DynamicGridHomePage(
                            isDarkMode: widget.isDarkMode,
                            onToggleTheme: widget.onToggleTheme,
                          ),
                        ),
                      );
                    } else if (val == 'edit_mode_row') {
                      setState(() {
                        _editMode = AiGridEditMode.row;
                        _controller.editingOptions =
                            _controller.editingOptions.copyWith(mode: AiGridEditMode.row);
                      });
                    } else if (val == 'edit_mode_cell') {
                      setState(() {
                        _editMode = AiGridEditMode.cell;
                        _controller.editingOptions =
                            _controller.editingOptions.copyWith(mode: AiGridEditMode.cell);
                      });
                    } else if (val == 'edit_mode_form') {
                      setState(() {
                        _editMode = AiGridEditMode.form;
                        _controller.editingOptions =
                            _controller.editingOptions.copyWith(mode: AiGridEditMode.form);
                      });
                    } else if (val == 'event_log') {
                      _showEditingEventLogDialog(context);
                    } else if (val == 'preset_pivot_category_region') {
                      _controller.setPivot(const AiGridPivotConfig(
                        rowFieldIds: ['Category', 'SubCategory'],
                        columnFieldIds: ['Region'],
                        values: [
                          AiGridPivotValueConfig(columnId: 'Sales', aggregation: AiGridPivotAggregation.sum),
                          AiGridPivotValueConfig(columnId: 'Profit', aggregation: AiGridPivotAggregation.average),
                        ],
                        showChart: true,
                        chartType: AiGridPivotChartType.column,
                        showRowTotals: true,
                        showColumnTotals: true,
                      ));
                    } else if (val == 'preset_pivot_segment_ship') {
                      _controller.setPivot(const AiGridPivotConfig(
                        rowFieldIds: ['Segment'],
                        columnFieldIds: ['ShipMode'],
                        values: [
                          AiGridPivotValueConfig(columnId: 'Sales', aggregation: AiGridPivotAggregation.sum),
                          AiGridPivotValueConfig(columnId: 'OrderID', aggregation: AiGridPivotAggregation.count),
                        ],
                        showChart: true,
                        chartType: AiGridPivotChartType.groupedBar,
                        showRowTotals: true,
                        showColumnTotals: true,
                      ));
                    } else if (val == 'export_json_file') {
                      await _exportSettingsToJsonFile();
                    } else if (val == 'restore_json') {
                      _showRestoreSettingsDialog();
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'dynamic_ai_grid',
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome, size: 18),
                          SizedBox(width: 10),
                          Text('Dynamic AI Grid'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    CheckedPopupMenuItem(
                      value: 'edit_mode_row',
                      checked: _editMode == AiGridEditMode.row,
                      child: const Row(
                        children: [
                          Icon(Icons.edit_note, size: 18),
                          SizedBox(width: 10),
                          Text('Row Edit Mode'),
                        ],
                      ),
                    ),
                    CheckedPopupMenuItem(
                      value: 'edit_mode_cell',
                      checked: _editMode == AiGridEditMode.cell,
                      child: const Row(
                        children: [
                          Icon(Icons.grid_on, size: 18),
                          SizedBox(width: 10),
                          Text('Cell Edit Mode'),
                        ],
                      ),
                    ),
                    CheckedPopupMenuItem(
                      value: 'edit_mode_form',
                      checked: _editMode == AiGridEditMode.form,
                      child: const Row(
                        children: [
                          Icon(Icons.dynamic_form_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Form (Popup) Mode'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'event_log',
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long_outlined, size: 18),
                          const SizedBox(width: 10),
                          Text('Editing Events (${_controller.editEvents.length})'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'preset_pivot_category_region',
                      child: Row(
                        children: [
                          Icon(Icons.pivot_table_chart, size: 18),
                          SizedBox(width: 10),
                          Text('Pivot: Category x Region'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'preset_pivot_segment_ship',
                      child: Row(
                        children: [
                          Icon(Icons.pie_chart_outline, size: 18),
                          SizedBox(width: 10),
                          Text('Pivot: Segment x Ship'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'export_json_file',
                      child: Row(
                        children: [
                          Icon(Icons.file_download_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Export Settings JSON'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'restore_json',
                      child: Row(
                        children: [
                          Icon(Icons.file_upload_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Restore Settings JSON'),
                        ],
                      ),
                    ),
                  ],
                ),
              ]
            : [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Dynamic AI Grid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DynamicGridHomePage(
                            isDarkMode: widget.isDarkMode,
                            onToggleTheme: widget.onToggleTheme,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Top bar switch among editing modes (Row, Cell, Form)
                Container(
                  height: 36,
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<AiGridEditMode>(
                      value: _editMode,
                      icon: const Icon(Icons.arrow_drop_down, size: 18),
                      borderRadius: BorderRadius.circular(8),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: AiGridEditMode.row,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_note, size: 16),
                              SizedBox(width: 6),
                              Text('Row Edit Mode'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: AiGridEditMode.cell,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.grid_on, size: 16),
                              SizedBox(width: 6),
                              Text('Cell Edit Mode'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: AiGridEditMode.form,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.dynamic_form_outlined, size: 16),
                              SizedBox(width: 6),
                              Text('Form (Popup) Mode'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (mode) {
                        if (mode != null) {
                          setState(() {
                            _editMode = mode;
                            _controller.editingOptions =
                                _controller.editingOptions.copyWith(mode: mode);
                          });
                        }
                      },
                    ),
                  ),
                ),
                ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) {
                    final count = _controller.editEvents.length;
                    return IconButton(
                      icon: Badge(
                        isLabelVisible: count > 0,
                        label: Text(count > 99 ? '99+' : '$count'),
                        child: const Icon(Icons.receipt_long_outlined),
                      ),
                      tooltip: 'Editing Events Log ($count)',
                      onPressed: () => _showEditingEventLogDialog(context),
                    );
                  },
                ),
                PopupMenuButton<String>(
            icon: const Icon(Icons.tune_outlined),
            tooltip: 'Layout Presets & Settings',
            constraints: const BoxConstraints(minWidth: 340, maxWidth: 400),
            onSelected: (val) async {
              if (val == 'preset_pivot_category_region') {
                _controller.setPivot(const AiGridPivotConfig(
                  rowFieldIds: ['Category', 'SubCategory'],
                  columnFieldIds: ['Region'],
                  values: [
                    AiGridPivotValueConfig(columnId: 'Sales', aggregation: AiGridPivotAggregation.sum),
                    AiGridPivotValueConfig(columnId: 'Profit', aggregation: AiGridPivotAggregation.average),
                  ],
                  showChart: true,
                  chartType: AiGridPivotChartType.column,
                  showRowTotals: true,
                  showColumnTotals: true,
                ));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Applied Pivot: Category & Sub-Category by Region (Sales Sum, Profit Avg) + Chart'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else if (val == 'preset_pivot_segment_ship') {
                _controller.setPivot(const AiGridPivotConfig(
                  rowFieldIds: ['Segment'],
                  columnFieldIds: ['ShipMode'],
                  values: [
                    AiGridPivotValueConfig(columnId: 'Sales', aggregation: AiGridPivotAggregation.sum),
                    AiGridPivotValueConfig(columnId: 'OrderID', aggregation: AiGridPivotAggregation.count),
                  ],
                  showChart: true,
                  chartType: AiGridPivotChartType.groupedBar,
                  showRowTotals: true,
                  showColumnTotals: true,
                ));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Applied Pivot: Segment by Ship Mode (Sales Sum, Order Count) + Chart'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else if (val == 'preset_grouping') {
                _controller.restoreSettings({
                  'groupColumns': ['Category', 'Region'],
                  'sort': [
                    {'column': 'Sales', 'dir': 'descending'},
                  ],
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Applied Preset: Grouped by Category & Region, sorted by Sales'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else if (val == 'preset_financial') {
                _controller.restoreSettings({
                  'widths': {
                    'OrderID': 110.0,
                    'CustomerName': 180.0,
                    'Sales': 140.0,
                    'Profit': 140.0,
                    'Discount': 100.0,
                  },
                  'sort': [
                    {'column': 'Profit', 'dir': 'descending'},
                  ],
                  'groupColumns': <String>[],
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Applied Preset: Financial Focus (Custom column widths & sorted by Profit)'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else if (val == 'preset_high_value') {
                _controller.restoreSettings({
                  'filters': {
                    'Sales': {'op': 'greaterThan', 'value': 500},
                  },
                  'sort': [
                    {'column': 'Sales', 'dir': 'descending'},
                  ],
                  'groupColumns': <String>[],
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Applied Preset: High Value Orders (Sales > \$500)'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else if (val == 'export_json_file') {
                await _exportSettingsToJsonFile();
              } else if (val == 'restore_json') {
                _showRestoreSettingsDialog();
              } else if (val == 'clear_settings') {
                AiGridSettingsStorage.clear('superstore_grid_settings');
                _controller.reset();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Layout settings cleared and grid reset to defaults.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'preset_pivot_category_region',
                child: Row(
                  children: [
                    Icon(Icons.pivot_table_chart, size: 18, color: Color(0xFF0078D4)),
                    SizedBox(width: 8),
                    Flexible(child: Text('Pivot: Category x Region + Chart')),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'preset_pivot_segment_ship',
                child: Row(
                  children: [
                    Icon(Icons.pie_chart_outline, size: 18, color: Color(0xFF107C41)),
                    SizedBox(width: 8),
                    Flexible(child: Text('Pivot: Segment x Ship Mode')),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'preset_grouping',
                child: Row(
                  children: [
                    Icon(Icons.layers_outlined, size: 18),
                    SizedBox(width: 8),
                    Flexible(child: Text('Preset: Group by Category & Region')),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'preset_financial',
                child: Row(
                  children: [
                    Icon(Icons.attach_money, size: 18),
                    SizedBox(width: 8),
                    Flexible(child: Text('Preset: Financial Focus (Custom Widths)')),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'preset_high_value',
                child: Row(
                  children: [
                    Icon(Icons.filter_alt_outlined, size: 18),
                    SizedBox(width: 8),
                    Flexible(child: Text('Preset: High Value Sales (> \$500)')),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'export_json_file',
                child: Row(
                  children: [
                    Icon(Icons.file_download_outlined, size: 18),
                    SizedBox(width: 8),
                    Flexible(child: Text('Export Layout (FitGrid JSON)')),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'restore_json',
                child: Row(
                  children: [
                    Icon(Icons.file_upload_outlined, size: 18),
                    SizedBox(width: 8),
                    Flexible(child: Text('Restore Layout from JSON')),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear_settings',
                child: Row(
                  children: [
                    Icon(Icons.restore_outlined, size: 18, color: Colors.orange),
                    SizedBox(width: 8),
                    Flexible(child: Text('Reset Layout to Defaults')),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.schema_outlined),
            tooltip: 'Inspect MCP Skill Schema',
            onPressed: () {
              final schema = _controller.getSchemaSummary();
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('MCP Grid Skill Schema'),
                  content: SingleChildScrollView(
                    child: Text(schema.toString()),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading Superstore dataset from JSON assets...'),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Text(
                    'Failed to load JSON dataset: $_errorMessage',
                    style: TextStyle(color: colorScheme.error),
                  ),
                )
              : Padding(
                  padding: EdgeInsets.all(
                    MediaQuery.of(context).size.width < 600 ? 0.0 : 12.0,
                  ),
                  child: AiGrid(
                    dataSource: _dataSource!,
                    controller: _controller,
                    aiConfig: _aiConfig,
                    editingOptions: _controller.editingOptions,
                    enableAiAssistant: true,
                    enablePagination: false,
                    autoSave: true,
                    persistenceKey: 'superstore_grid_settings',
                  ),
                ),
    );
  }
}
