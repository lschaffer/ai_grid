import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_grid/ai_grid.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('DelimitedTableParser Tests', () {
    test('parses comma-separated CSV with automatic type detection', () {
      const csv = '''id,name,active,score,joined
1,Alice,true,95.5,2023-01-15
2,Bob,false,82.0,2023-02-20
3,"Charlie, Jr.",true,99.25,2023-03-10''';

      final result = DelimitedTableParser.parse(csv);
      expect(result.columns.length, 5);
      expect(result.rows.length, 3);

      expect(result.columns[0].field, 'id');
      expect(result.columns[0].type, AiGridColumnType.number);

      expect(result.columns[1].field, 'name');
      expect(result.columns[1].type, AiGridColumnType.text);

      expect(result.columns[2].field, 'active');
      expect(result.columns[2].type, AiGridColumnType.boolean);

      expect(result.columns[3].field, 'score');
      expect(result.columns[3].type, AiGridColumnType.number);

      expect(result.columns[4].field, 'joined');
      expect(result.columns[4].type, AiGridColumnType.date);

      expect(result.rows[0]['name'], 'Alice');
      expect(result.rows[0]['active'], true);
      expect(result.rows[2]['name'], 'Charlie, Jr.');
      expect(result.rows[2]['score'], 99.25);
    });

    test('parses tab-separated TSV', () {
      const tsv = 'dept\theadcount\tbudget\n'
          'Engineering\t120\t2500000\n'
          'Marketing\t45\t800000';

      final result = DelimitedTableParser.parse(tsv, delimiter: '\t');
      expect(result.columns.length, 3);
      expect(result.rows.length, 2);
      expect(result.rows[0]['dept'], 'Engineering');
      expect(result.rows[0]['headcount'], 120);
    });
  });

  group('MarkdownTableExtractor Tests', () {
    test('finds and parses markdown pipe tables', () {
      const markdown = '''
# Quarterly Report
Here is the performance table:

| Department | Target Met | Q1 Revenue | Date |
| :--- | :---: | ---: | --- |
| Sales | true | 125000.50 | 2026-03-31 |
| Engineering | false | 98000.00 | 2026-03-31 |
| Operations | true | 45000.75 | 2026-03-31 |

End of section.
''';

      expect(MarkdownTableExtractor.containsTable(markdown), isTrue);
      final result = MarkdownTableExtractor.extractFirst(markdown);
      expect(result, isNotNull);
      expect(result!.columns.length, 4);
      expect(result.rows.length, 3);

      expect(result.columns[0].field, 'department');
      expect(result.columns[0].title, 'Department');
      expect(result.columns[0].type, AiGridColumnType.text);
      expect(result.columns[1].type, AiGridColumnType.boolean);
      expect(result.columns[2].type, AiGridColumnType.number);
      expect(result.columns[3].type, AiGridColumnType.date);

      expect(result.rows[0]['department'], 'Sales');
      expect(result.rows[0]['target_met'], true);
      expect(result.rows[0]['q1_revenue'], 125000.50);
    });
  });

  group('PdfTableExtractor Tests', () {
    test('extracts text from monthly_sales_200.pdf', () async {
      final file = File('example/assets/monthly_sales_200.pdf');
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final text = PdfTableExtractor.extractText(bytes);
        expect(text.isNotEmpty, isTrue);
        expect(text.contains('Monthly Sales'), isTrue);
        expect(text.contains('Order ID'), isTrue);
        expect(text.contains('1001'), isTrue);
      }
    });
  });

  group('AiGridDynamicStorage & Bundle Tests', () {
    test('saves, lists, loads, and deletes dynamic datasources with YAML bundles', () async {
      final columns = [
        const AiGridDynamicColumnModel(field: 'id', title: 'ID', type: AiGridColumnType.number),
        const AiGridDynamicColumnModel(field: 'product', title: 'Product', type: AiGridColumnType.text),
        const AiGridDynamicColumnModel(field: 'price', title: 'Price', type: AiGridColumnType.number),
      ];
      final rows = [
        {'id': 1, 'product': 'Laptop', 'price': 1200},
        {'id': 2, 'product': 'Mouse', 'price': 25},
      ];

      final desc = AiGridDynamicDescriptor(
        name: 'inventory_2026',
        modelName: 'inventory_2026_mdl.yaml',
        datasourceName: 'inventory_2026.json',
        title: 'Inventory 2026',
        sourceType: 'file',
        rowCount: rows.length,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final model = AiGridDynamicModel(
        modelName: 'inventory_2026_mdl.yaml',
        datasourceName: 'inventory_2026.json',
        title: 'Inventory 2026',
        createdAt: DateTime.now(),
        columns: columns,
      );

      await AiGridDynamicStorage.saveDatasource(
        descriptor: desc,
        model: model,
        rows: rows,
      );

      expect(desc.name, 'inventory_2026');
      expect(desc.rowCount, 2);
      expect(desc.modelName, 'inventory_2026_mdl.yaml');
      expect(desc.datasourceName, 'inventory_2026.json');

      final list = await AiGridDynamicStorage.listDatasources();
      expect(list.any((d) => d.name == 'inventory_2026'), isTrue);

      final loaded = await AiGridDynamicStorage.getBundle('inventory_2026');
      expect(loaded, isNotNull);
      expect(loaded!.model.columns.length, 3);
      expect(loaded.rows.length, 2);
      expect(loaded.rows[0]['product'], 'Laptop');

      // Update rows
      final updatedRows = [
        {'id': 1, 'product': 'Laptop Pro', 'price': 1400},
        {'id': 2, 'product': 'Mouse', 'price': 25},
        {'id': 3, 'product': 'Keyboard', 'price': 75},
      ];
      await AiGridDynamicStorage.updateDataRows('inventory_2026', updatedRows);

      final reloaded = await AiGridDynamicStorage.getBundle('inventory_2026');
      expect(reloaded!.rows.length, 3);
      expect(reloaded.rows[0]['product'], 'Laptop Pro');

      // Export bundle as YAML
      final bundleYaml = await AiGridDynamicStorage.exportBundleYaml('inventory_2026');
      expect(bundleYaml, isNotNull);
      expect(bundleYaml!.contains('inventory_2026'), isTrue);
      expect(bundleYaml.contains('Laptop Pro'), isTrue);

      // Import bundle with a new or imported structure
      final importedDesc = await AiGridDynamicStorage.importBundleYaml(bundleYaml);
      expect(importedDesc.name, 'inventory_2026');
      expect(importedDesc.rowCount, 3);

      // Delete datasource
      final deleted = await AiGridDynamicStorage.deleteDatasource('inventory_2026');
      expect(deleted, isTrue);

      final postDelete = await AiGridDynamicStorage.getBundle('inventory_2026');
      expect(postDelete, isNull);
    });
  });

  group('AiGridController Dynamic Datasource Tests', () {
    test('loadDynamicDatasource configures controller columns, data, and auto-persists updates', () async {
      final columns = [
        const AiGridDynamicColumnModel(field: 'orderId', title: 'Order ID', type: AiGridColumnType.number),
        const AiGridDynamicColumnModel(field: 'client', title: 'Client', type: AiGridColumnType.text),
        const AiGridDynamicColumnModel(field: 'amount', title: 'Amount', type: AiGridColumnType.number),
      ];
      final rows = [
        {'orderId': 101, 'client': 'Acme Corp', 'amount': 500.0},
        {'orderId': 102, 'client': 'Beta LLC', 'amount': 750.0},
      ];

      final desc = AiGridDynamicDescriptor(
        name: 'orders',
        modelName: 'orders_mdl.yaml',
        datasourceName: 'orders.json',
        title: 'Customer Orders',
        sourceType: 'file',
        rowCount: rows.length,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final model = AiGridDynamicModel(
        modelName: 'orders_mdl.yaml',
        datasourceName: 'orders.json',
        title: 'Customer Orders',
        createdAt: DateTime.now(),
        columns: columns,
      );

      await AiGridDynamicStorage.saveDatasource(
        descriptor: desc,
        model: model,
        rows: rows,
      );

      final controller = AiGridController();
      final loadedData = await AiGridDynamicStorage.getBundle('orders');
      expect(loadedData, isNotNull);

      controller.loadDynamicDatasource(
        loadedData!.descriptor,
        loadedData.model.columns.map((c) => c.toAiGridColumn()).toList(),
        loadedData.rows,
      );

      expect(controller.activeDynamicDatasource, isNotNull);
      expect(controller.activeDynamicDatasource!.name, 'orders');

      final gridRows = controller.fitController?.data.rows;
      expect(gridRows?.length, 2);

      // Trigger a row edit to verify write-back persistence
      controller.startEdit(0);
      controller.updateDraftValue('client', 'Acme International');
      controller.updateDraftValue('amount', 650.0);
      final saveErr = await controller.saveEdit();
      expect(saveErr, isNull);

      // Verify that SharedPreferences was updated
      final persisted = await AiGridDynamicStorage.getBundle('orders');
      expect(persisted!.rows[0]['client'], 'Acme International');
      expect(persisted.rows[0]['amount'], 650.0);

      // Trigger row deletion to verify write-back persistence
      final deleted = await controller.deleteRow(0);
      expect(deleted, isTrue);

      final postDeletePersisted = await AiGridDynamicStorage.getBundle('orders');
      expect(postDeletePersisted!.rows.length, 1);
      expect(postDeletePersisted.rows[0]['client'], 'Beta LLC');
    });
  });

  group('AiGrid Dynamic MCP Tools Tests', () {
    test('executes dynamic datasource MCP tools', () async {
      final controller = AiGridController();
      final createTool = GridCreateDynamicDatasourceTool(controller);
      final listTool = GridListDatasourcesTool(controller);
      final loadTool = GridLoadDatasourceTool(controller);
      final exportTool = GridExportDatasourceYamlTool(controller);
      final deleteTool = GridDeleteDatasourceTool(controller);

      // 1. Create Tool
      final createRes = await createTool.execute({
        'name': 'mcp_sales',
        'title': 'MCP Sales Data',
        'data': [
          {'rep': 'Sarah', 'deals': 15, 'revenue': 120000},
          {'rep': 'John', 'deals': 8, 'revenue': 64000},
        ],
      });

      expect(createRes.isError, isFalse);
      expect(createRes.content.first.text?.contains('mcp_sales'), isTrue);
      expect(controller.activeDynamicDatasource?.name, 'mcp_sales');

      // 2. List Tool
      final listRes = await listTool.execute({});
      expect(listRes.isError, isFalse);
      final listText = listRes.content.first.text ?? '';
      expect(listText.contains('mcp_sales'), isTrue);

      // 3. Export YAML Tool
      final exportRes = await exportTool.execute({'name': 'mcp_sales'});
      expect(exportRes.isError, isFalse);
      final yamlContent = exportRes.content.first.text ?? '';
      expect(yamlContent.contains('mcp_sales'), isTrue);
      expect(yamlContent.contains('Sarah'), isTrue);

      // 4. Load Tool
      final loadRes = await loadTool.execute({'name': 'mcp_sales'});
      expect(loadRes.isError, isFalse);
      expect(loadRes.content.first.text?.contains('Loaded dynamic datasource "mcp_sales"'), isTrue);

      // 5. Delete Tool
      final deleteRes = await deleteTool.execute({'name': 'mcp_sales'});
      expect(deleteRes.isError, isFalse);

      final listAfterDelete = await listTool.execute({});
      final remainingText = listAfterDelete.content.first.text ?? '';
      expect(remainingText.contains('mcp_sales'), isFalse);
    });

    testWidgets('editing row in dynamic grid preserves all columns and does not collapse to Actions only', (tester) async {
      final controller = AiGridController();
      final dataSource = LocalAiGridDataSource(columns: const [], initialData: const []);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 600,
              child: AiGrid(
                dataSource: dataSource,
                controller: controller,
                dynamicGrid: true,
                showToolbar: false,
                editingOptions: const AiGridEditingOptions(
                  enabled: true,
                  mode: AiGridEditMode.row,
                  allowAdding: true,
                  allowDeleting: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Load dynamic dataset (e.g. Top Tech Companies)
      final columns = <AiGridColumn>[
        const AiGridColumn(field: 'company', title: 'Company', editable: true),
        const AiGridColumn(field: 'valuation', title: 'Valuation', editable: true),
        const AiGridColumn(field: 'employees', title: 'Employees', editable: true),
      ];
      final rows = [
        {'company': 'Stripe', 'valuation': 65.0, 'employees': 8000},
        {'company': 'OpenAI', 'valuation': 157.0, 'employees': 1700},
      ];
      final desc = AiGridDynamicDescriptor(
        name: 'tech_companies',
        modelName: 'tech_companies.yaml',
        datasourceName: 'tech_companies.json',
        title: 'Top Tech Companies',
        sourceType: 'table',
        sourceOrigin: 'test',
        rowCount: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      controller.loadDynamicDatasource(desc, columns, rows);
      await tester.pumpAndSettle();

      // Verify all columns exist in the fitController
      final fitColsBefore = controller.fitController!.columns.columns;
      expect(fitColsBefore.any((c) => c.id == 'company'), isTrue);
      expect(fitColsBefore.any((c) => c.id == 'valuation'), isTrue);
      expect(fitColsBefore.any((c) => c.id == 'employees'), isTrue);
      expect(fitColsBefore.any((c) => c.id == '__actions__'), isTrue);

      // Start row edit (e.g. double click row)
      controller.startEdit(0);
      await tester.pumpAndSettle();

      // Crucial assertion: All data columns MUST still exist, not just Actions!
      final fitColsAfter = controller.fitController!.columns.columns;
      expect(fitColsAfter.any((c) => c.id == 'company'), isTrue);
      expect(fitColsAfter.any((c) => c.id == 'valuation'), isTrue);
      expect(fitColsAfter.any((c) => c.id == 'employees'), isTrue);
      expect(fitColsAfter.any((c) => c.id == '__actions__'), isTrue);
      expect(fitColsAfter.length, 4);
      expect(controller.isEditingRow, isTrue);

      // Cancel edit and verify clean restoration
      controller.cancelEdit();
      await tester.pumpAndSettle();
      expect(controller.isEditingRow, isFalse);
    });

    test('updateColumnDefinition updates column in controller and persists to storage', () async {
      final controller = AiGridController();
      final columns = <AiGridColumn>[
        const AiGridColumn(field: 'item', title: 'Item', type: AiGridColumnType.text),
        const AiGridColumn(field: 'qty', title: 'Qty', type: AiGridColumnType.number),
      ];
      final rows = [
        {'item': 'Widget A', 'qty': 10},
      ];
      final desc = AiGridDynamicDescriptor(
        name: 'inventory_dyn',
        modelName: 'inventory_dyn.yaml',
        datasourceName: 'inventory_dyn.json',
        title: 'Inventory Dynamic',
        sourceType: 'table',
        sourceOrigin: 'test',
        rowCount: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isReadonly: false,
      );

      final dynamicModel = AiGridDynamicModel(
        modelName: 'inventory_dyn.yaml',
        datasourceName: 'inventory_dyn.json',
        title: 'Inventory Dynamic',
        createdAt: DateTime.now(),
        columns: columns.map((c) => AiGridDynamicColumnModel.fromAiGridColumn(c)).toList(),
      );
      await AiGridDynamicStorage.saveDatasource(descriptor: desc, model: dynamicModel, rows: rows);

      controller.loadDynamicDatasource(desc, columns, rows);

      final updated = await controller.updateColumnDefinition(
        field: 'item',
        title: 'Product Name',
        type: AiGridColumnType.text,
        editable: true,
        required: true,
        width: 180,
        maxWidth: 400,
        editorType: AiGridEditorType.text,
      );
      expect(updated, isTrue);

      final col = controller.columns.firstWhere((c) => c.field == 'item');
      expect(col.title, 'Product Name');
      expect(col.required, isTrue);
      expect(col.width, 180);
      expect(col.maxWidth, 400);

      final savedModel = await AiGridDynamicStorage.getModel('inventory_dyn');
      expect(savedModel, isNotNull);
      final savedCol = savedModel!.columns.firstWhere((c) => c.field == 'item');
      expect(savedCol.title, 'Product Name');
      expect(savedCol.required, isTrue);
      expect(savedCol.maxWidth, 400);

      expect(col.validate(''), contains('Product Name is required'));
      expect(col.validate('Widget B'), isNull);
    });

    testWidgets('AiGridColumnEditorDialog allows editing column definitions and prevents read-only', (tester) async {
      final controller = AiGridController();
      final columns = <AiGridColumn>[
        const AiGridColumn(field: 'event_date', title: 'Event Date', type: AiGridColumnType.date),
      ];
      final rows = [
        {'event_date': '2026-10-21'},
      ];

      // 1. Check read-only guard
      final readonlyDesc = AiGridDynamicDescriptor(
        name: 'ro_dataset',
        modelName: 'ro.yaml',
        datasourceName: 'ro.json',
        title: 'Read Only Dataset',
        sourceType: 'table',
        sourceOrigin: 'test',
        rowCount: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isReadonly: true,
      );
      controller.loadDynamicDatasource(readonlyDesc, columns, rows);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () => controller.showColumnEditorDialog(ctx, field: 'event_date'),
                child: const Text('Open Editor'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Editor'));
      await tester.pumpAndSettle();

      // Dialog should NOT open because it is read-only
      expect(find.byType(AiGridColumnEditorDialog), findsNothing);

      // 2. Now load writable dataset and open dialog
      final writableDesc = AiGridDynamicDescriptor(
        name: 'rw_dataset',
        modelName: 'rw.yaml',
        datasourceName: 'rw.json',
        title: 'Writable Dataset',
        sourceType: 'table',
        sourceOrigin: 'test',
        rowCount: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isReadonly: false,
      );
      controller.loadDynamicDatasource(writableDesc, columns, rows);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Editor'));
      await tester.pumpAndSettle();

      // Dialog should now be open
      expect(find.byType(AiGridColumnEditorDialog), findsOneWidget);
      expect(find.text('Edit Column: event_date'), findsOneWidget);

      // Change title to "Scheduled Date & Time"
      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, 'Scheduled Date & Time');
      await tester.pumpAndSettle();

      // Tap Save Column
      await tester.tap(find.text('Save Column'));
      await tester.pumpAndSettle();

      // Dialog should close and column should be updated
      expect(find.byType(AiGridColumnEditorDialog), findsNothing);
      expect(controller.columns.first.title, 'Scheduled Date & Time');
    });

    test('updateAllColumns updates all columns in controller, fitgrid, and persists to storage', () async {
      final controller = AiGridController();
      final initialCols = <AiGridColumn>[
        const AiGridColumn(field: 'c1', title: 'Column 1', width: 100),
        const AiGridColumn(field: 'c2', title: 'Column 2', width: 120),
      ];
      final rows = [
        {'c1': 'A', 'c2': 'B'},
      ];

      final desc = AiGridDynamicDescriptor(
        name: 'test_multi_cols',
        modelName: 'test_multi_cols.yaml',
        datasourceName: 'test_multi_cols.json',
        title: 'Multi Cols Dataset',
        sourceType: 'table',
        sourceOrigin: 'test',
        rowCount: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isReadonly: false,
      );

      final model = AiGridDynamicModel(
        modelName: 'test_multi_cols.yaml',
        datasourceName: 'test_multi_cols.json',
        title: 'Multi Cols Dataset',
        createdAt: DateTime.now(),
        columns: initialCols.map((c) => AiGridDynamicColumnModel.fromAiGridColumn(c)).toList(),
      );
      await AiGridDynamicStorage.saveDatasource(descriptor: desc, model: model, rows: rows);

      controller.loadDynamicDatasource(desc, initialCols, rows);
      expect(controller.columns.length, 2);

      // Reorder and add a 3rd column
      final updatedCols = <AiGridColumn>[
        const AiGridColumn(field: 'c2', title: 'Column 2 Renamed', width: 150),
        const AiGridColumn(field: 'c1', title: 'Column 1', width: 100),
        const AiGridColumn(field: 'c3', title: 'Column 3 New', type: AiGridColumnType.number, width: 80),
      ];

      final success = await controller.updateAllColumns(updatedCols);
      expect(success, isTrue);
      expect(controller.columns.length, 3);
      expect(controller.columns[0].field, 'c2');
      expect(controller.columns[0].title, 'Column 2 Renamed');
      expect(controller.columns[2].field, 'c3');

      // Storage model persistence
      final savedModel = await AiGridDynamicStorage.getModel('test_multi_cols');
      expect(savedModel, isNotNull);
      expect(savedModel!.columns.length, 3);
      expect(savedModel.columns[0].field, 'c2');
      expect(savedModel.columns[0].title, 'Column 2 Renamed');
      expect(savedModel.columns[2].field, 'c3');
    });

    testWidgets('AiGridColumnsEditorDialog renders nested AiGrid and applies column updates', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = AiGridController();
      final columns = <AiGridColumn>[
        const AiGridColumn(field: 'col_a', title: 'Column Alpha', width: 120),
      ];
      final rows = [
        {'col_a': 'Val 1'},
      ];

      // 1. Read-only guard
      final roDesc = AiGridDynamicDescriptor(
        name: 'ro_multi',
        modelName: 'ro.yaml',
        datasourceName: 'ro.json',
        title: 'RO Multi',
        sourceType: 'table',
        sourceOrigin: 'test',
        rowCount: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isReadonly: true,
      );
      controller.loadDynamicDatasource(roDesc, columns, rows);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () => controller.showColumnsEditorDialog(ctx),
                child: const Text('Open Columns Editor'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Columns Editor'));
      await tester.pumpAndSettle();
      expect(find.byType(AiGridColumnsEditorDialog), findsNothing);

      // 2. Writable dataset
      final rwDesc = AiGridDynamicDescriptor(
        name: 'rw_multi',
        modelName: 'rw.yaml',
        datasourceName: 'rw.json',
        title: 'RW Multi',
        sourceType: 'table',
        sourceOrigin: 'test',
        rowCount: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isReadonly: false,
      );
      controller.loadDynamicDatasource(rwDesc, columns, rows);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Columns Editor'));
      await tester.pumpAndSettle();

      // Dialog is open and hosts an inner AiGrid
      expect(find.byType(AiGridColumnsEditorDialog), findsOneWidget);
      expect(find.text('Columns Editor (Dynamic Schema)'), findsOneWidget);
      expect(find.text('Add Column'), findsOneWidget);

      // Tap Add Column to add a 2nd column
      await tester.tap(find.text('Add Column'));
      await tester.pumpAndSettle();

      // Tap Apply & Save All Changes
      await tester.tap(find.text('Apply & Save All Changes'));
      await tester.pumpAndSettle();

      // Dialog should close and controller now has 2 columns
      expect(find.byType(AiGridColumnsEditorDialog), findsNothing);
      expect(controller.columns.length, 2);
      expect(controller.columns[0].field, 'col_a');
      expect(controller.columns[1].field, 'column_2');
    });

    testWidgets('Readonly dynamic datatable (e.g. fetched from web) suppresses all editor controls', (tester) async {
      final controller = AiGridController();
      controller.editingOptions = const AiGridEditingOptions(
        enabled: true,
        mode: AiGridEditMode.row,
        allowAdding: true,
        allowDeleting: true,
        allowUpdating: true,
      );

      final columns = <AiGridColumn>[
        const AiGridColumn(field: 'userId', title: 'UserId', type: AiGridColumnType.number),
        const AiGridColumn(field: 'id', title: 'Id', type: AiGridColumnType.number),
        const AiGridColumn(field: 'title', title: 'Title', type: AiGridColumnType.text),
        const AiGridColumn(field: 'body', title: 'Body', type: AiGridColumnType.text),
      ];

      final rows = [
        {'userId': 1, 'id': 1, 'title': 'Post 1', 'body': 'Content 1'},
        {'userId': 1, 'id': 2, 'title': 'Post 2', 'body': 'Content 2'},
      ];

      final webDesc = AiGridDynamicDescriptor(
        name: 'web_posts',
        modelName: 'web_posts.yaml',
        datasourceName: 'web_posts.json',
        title: 'Web: https://jsonplaceholder.typicode.com/posts',
        sourceType: 'web',
        sourceOrigin: 'https://jsonplaceholder.typicode.com/posts',
        rowCount: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isReadonly: true,
      );

      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
      });

      final dataSource = LocalAiGridDataSource(columns: columns, initialData: rows);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 600,
              child: AiGrid(
                controller: controller,
                dataSource: dataSource,
                dynamicGrid: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Load the web dynamic datasource
      controller.loadDynamicDatasource(webDesc, columns, rows);
      await tester.pumpAndSettle();

      // 1. Actions column must NOT be present
      expect(controller.fitController!.columns.columns.any((c) => c.id == '__actions__'), isFalse);
      expect(find.text('Actions'), findsNothing);

      // 2. Toolbar Add Record button must NOT be present
      expect(find.byTooltip('Add Record'), findsNothing);

      // 3. Toolbar Columns Editor button must NOT be present
      expect(find.byTooltip('Columns Editor (Manage All Columns)'), findsNothing);

      // 4. Edit operations must be rejected
      controller.startEdit(0);
      expect(controller.isEditingRow, isFalse);

      controller.startAdd();
      expect(controller.isAddingRow, isFalse);
    });
  });
}
