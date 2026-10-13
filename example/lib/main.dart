import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:ai_grid/ai_grid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Automatically loads root/local .env if present
  await AiGridEnvLoader.load();
  runApp(const AiGridExampleApp());
}

class AiGridExampleApp extends StatefulWidget {
  const AiGridExampleApp({super.key});

  @override
  State<AiGridExampleApp> createState() => _AiGridExampleAppState();
}

class _AiGridExampleAppState extends State<AiGridExampleApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI DataGrid Demo - Superstore Dataset',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0078D4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0078D4),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: SuperstoreGridPage(
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    _controller = AiGridController();

    // Configure LLM from .env or fallback
    final llmConfig = AiGridEnvLoader.createLlmConfigFromEnv();
    _aiConfig = AiGridConfig(llmConfig: llmConfig);

    _loadSuperstoreJson();
  }

  Future<void> _loadSuperstoreJson() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/superstore_sales_1000.json');
      final List<dynamic> decoded = jsonDecode(jsonString);
      final records = decoded.cast<Map<String, dynamic>>();

      final columns = [
        const AiGridColumn(
          field: 'OrderID',
          title: 'Order ID',
          type: AiGridColumnType.text,
          aggregateType: AiGridAggregateType.count,
          numberFormat: 'Total: #,###',
          width: 140,
        ),
        const AiGridColumn(
          field: 'OrderDate',
          title: 'Order Date',
          type: AiGridColumnType.date,
          width: 120,
        ),
        const AiGridColumn(
          field: 'ShipDate',
          title: 'Ship Date',
          type: AiGridColumnType.date,
          width: 120,
        ),
        const AiGridColumn(
          field: 'ShipMode',
          title: 'Ship Mode',
          type: AiGridColumnType.text,
          width: 130,
        ),
        const AiGridColumn(
          field: 'CustomerID',
          title: 'Customer ID',
          type: AiGridColumnType.text,
          width: 120,
        ),
        const AiGridColumn(
          field: 'CustomerName',
          title: 'Customer Name',
          type: AiGridColumnType.text,
          width: 160,
        ),
        const AiGridColumn(
          field: 'Segment',
          title: 'Segment',
          type: AiGridColumnType.text,
          width: 120,
        ),
        const AiGridColumn(
          field: 'Country',
          title: 'Country',
          type: AiGridColumnType.text,
          width: 120,
        ),
        const AiGridColumn(
          field: 'City',
          title: 'City',
          type: AiGridColumnType.text,
          width: 140,
        ),
        const AiGridColumn(
          field: 'State',
          title: 'State',
          type: AiGridColumnType.text,
          width: 130,
        ),
        const AiGridColumn(
          field: 'PostalCode',
          title: 'Postal Code',
          type: AiGridColumnType.number,
          width: 110,
        ),
        const AiGridColumn(
          field: 'Region',
          title: 'Region',
          type: AiGridColumnType.text,
          width: 110,
        ),
        const AiGridColumn(
          field: 'ProductID',
          title: 'Product ID',
          type: AiGridColumnType.text,
          width: 150,
        ),
        const AiGridColumn(
          field: 'Category',
          title: 'Category',
          type: AiGridColumnType.text,
          width: 130,
        ),
        const AiGridColumn(
          field: 'SubCategory',
          title: 'Sub-Category',
          type: AiGridColumnType.text,
          width: 140,
        ),
        const AiGridColumn(
          field: 'ProductName',
          title: 'Product Name',
          type: AiGridColumnType.text,
          width: 260,
        ),
        const AiGridColumn(
          field: 'Sales',
          title: 'Sales',
          type: AiGridColumnType.currency,
          aggregateType: AiGridAggregateType.sum,
          width: 130,
        ),
        const AiGridColumn(
          field: 'Quantity',
          title: 'Quantity',
          type: AiGridColumnType.number,
          aggregateType: AiGridAggregateType.sum,
          width: 100,
        ),
        const AiGridColumn(
          field: 'Discount',
          title: 'Discount',
          type: AiGridColumnType.number,
          aggregateType: AiGridAggregateType.average,
          width: 110,
        ),
        const AiGridColumn(
          field: 'Profit',
          title: 'Profit',
          type: AiGridColumnType.currency,
          aggregateType: AiGridAggregateType.sum,
          width: 130,
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Grid Settings'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste or edit a valid JSON settings configuration below (supports visibleColumns, groupColumns, sorts, filters, showColumnFilterRow):',
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
            label: const Text('Apply Settings'),
            onPressed: () {
              Navigator.pop(ctx);
              _controller.restoreSettingsJson(textController.text);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Grid settings successfully restored!'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.table_chart_outlined, size: 20),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Superstore Sales (1,000 JSON)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune_outlined),
            tooltip: 'Settings & Presets',
            onSelected: (val) async {
              if (val == 'export_json_file') {
                await _exportSettingsToJsonFile();
              } else if (val == 'restore_json') {
                _showRestoreSettingsDialog();
              } else if (val == 'clear_settings') {
                AiGridSettingsStorage.clear('superstore_grid_settings');
                _controller.reset();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Auto-saved settings cleared and grid reset to defaults.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'export_json_file',
                child: Row(
                  children: [
                    Icon(Icons.file_download_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Export Settings to JSON File'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'restore_json',
                child: Row(
                  children: [
                    Icon(Icons.file_upload_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Restore Settings from JSON'),
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
                    Text('Reset & Clear Auto-Saved Settings'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            tooltip: widget.isDarkMode
                ? 'Switch to Light Theme'
                : 'Switch to Dark Theme',
            onPressed: widget.onToggleTheme,
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
                    enableAiAssistant: true,
                    enablePagination: false,
                    autoSave: true,
                    persistenceKey: 'superstore_grid_settings',
                  ),
                ),
    );
  }
}
