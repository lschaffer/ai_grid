import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:ai_grid/ai_grid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AiGridEnvLoader.load();
  runApp(const DynamicAiGridExampleApp());
}

class DynamicAiGridExampleApp extends StatefulWidget {
  const DynamicAiGridExampleApp({super.key});

  @override
  State<DynamicAiGridExampleApp> createState() => _DynamicAiGridExampleAppState();
}

class _DynamicAiGridExampleAppState extends State<DynamicAiGridExampleApp> {
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
      title: 'AiGrid - Dynamic AI DataGrid Demo',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Modern Indigo
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: DynamicGridHomePage(
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class DynamicGridHomePage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const DynamicGridHomePage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<DynamicGridHomePage> createState() => _DynamicGridHomePageState();
}

class _DynamicGridHomePageState extends State<DynamicGridHomePage> {
  late AiGridController _controller;
  AiGridDataSource? _dataSource;
  bool _isLoading = true;
  String _statusMessage = 'Initializing dynamic storage...';

  @override
  void initState() {
    super.initState();
    _controller = AiGridController();
    _initializeInitialDatasource();
  }

  Future<void> _initializeInitialDatasource() async {
    // Start the dynamic app with a clean empty table: no rows, no columns!
    _dataSource = LocalAiGridDataSource(
      columns: const [],
      initialData: const [],
    );
    _controller.clearDynamicDatasource();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSampleMonthlySales() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading 200-row Monthly Sales (from PDF dataset)...';
    });

    try {
      final jsonStr = await DefaultAssetBundle.of(context).loadString('assets/sales_1000.json');
      final list = jsonDecode(jsonStr) as List;
      final rows = list.take(200).map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final columns = [
        const AiGridDynamicColumnModel(
          field: 'orderId',
          title: 'Order ID',
          type: AiGridColumnType.number,
          editable: false,
          width: 90,
        ),
        const AiGridDynamicColumnModel(
          field: 'date',
          title: 'Date',
          type: AiGridColumnType.date,
          editable: true,
          width: 120,
        ),
        const AiGridDynamicColumnModel(
          field: 'region',
          title: 'Region',
          type: AiGridColumnType.text,
          editable: true,
          width: 140,
        ),
        const AiGridDynamicColumnModel(
          field: 'sector',
          title: 'Sector',
          type: AiGridColumnType.text,
          editable: true,
          width: 140,
        ),
        const AiGridDynamicColumnModel(
          field: 'product',
          title: 'Product',
          type: AiGridColumnType.text,
          editable: true,
          width: 130,
        ),
        const AiGridDynamicColumnModel(
          field: 'saleAmount',
          title: 'Sale Amount',
          type: AiGridColumnType.currency,
          editable: true,
          numberFormat: r'$#,##0.00',
          width: 130,
        ),
        const AiGridDynamicColumnModel(
          field: 'status',
          title: 'Status',
          type: AiGridColumnType.text,
          editable: true,
          width: 110,
        ),
      ];

      final desc = AiGridDynamicDescriptor(
        name: 'monthly_sales',
        modelName: 'monthly_sales_mdl.yaml',
        datasourceName: 'monthly_sales.json',
        title: 'Monthly Sales (200 records)',
        sourceType: 'file',
        sourceOrigin: 'example/assets/monthly_sales_200.pdf',
        rowCount: rows.length,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final model = AiGridDynamicModel(
        modelName: 'monthly_sales_mdl.yaml',
        datasourceName: 'monthly_sales.json',
        title: 'Monthly Sales (200 records)',
        sourceType: 'file',
        sourceOrigin: 'example/assets/monthly_sales_200.pdf',
        createdAt: DateTime.now(),
        columns: columns,
      );

      await AiGridDynamicStorage.saveDatasource(
        descriptor: desc,
        model: model,
        rows: rows,
      );
      await AiGridDynamicStorage.setActiveDatasourceName('monthly_sales');

      final cols = model.toColumns();
      _dataSource = LocalAiGridDataSource(columns: cols, initialData: rows);
      _controller.loadDynamicDatasource(desc, cols, rows);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loaded 200-row "Monthly Sales" dataset matching monthly_sales_200.pdf!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sample dataset: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'AI DYNAMIC GRID',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final active = _controller.activeDynamicDatasource;
                  return Text(
                    active != null ? active.title : 'Dynamic DataGrid (Empty)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear to Empty Table',
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              _controller.clearDynamicDatasource();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cleared grid to an empty table.')),
              );
            },
          ),
          IconButton(
            tooltip: 'Load 200-row Monthly Sales (PDF dataset)',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _loadSampleMonthlySales,
          ),
          IconButton(
            tooltip: 'Datasource Manager',
            icon: const Icon(Icons.dataset_outlined),
            onPressed: () => AiGridDatasourceManagerDialog.show(context, _controller),
          ),
          IconButton(
            tooltip: 'Web Data Source (GET)',
            icon: const Icon(Icons.language_outlined),
            onPressed: () => AiGridWebDataSourceDialog.show(context, _controller),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading || _dataSource == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_statusMessage, style: theme.textTheme.bodyMedium),
                ],
              ),
            )
          : AiGrid(
              dataSource: _dataSource!,
              controller: _controller,
              dynamicGrid: true,
              enableAiAssistant: true,
              showToolbar: true,
              editingOptions: AiGridEditingOptions(
                enabled: true,
                mode: AiGridEditMode.row,
                allowAdding: true,
                allowDeleting: true,
              ),
            ),
    );
  }
}
