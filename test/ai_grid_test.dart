import 'dart:convert';
import 'package:flutter/material.dart' as fm;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_grid/ai_grid.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('LocalAiGridDataSource Tests', () {
    test('creates rows and provides sample data', () async {
      final sample = List.generate(
        5,
        (i) => {
          'orderId': i + 1,
          'region': i % 2 == 0 ? 'East' : 'West',
          'saleAmount': (i + 1) * 100.0,
        },
      );
      final cols = [
        const AiGridColumn(
            field: 'orderId', title: 'Order ID', type: AiGridColumnType.number),
        const AiGridColumn(
            field: 'region', title: 'Region', type: AiGridColumnType.text),
        const AiGridColumn(
            field: 'saleAmount',
            title: 'Sale Amount',
            type: AiGridColumnType.currency),
      ];

      final ds = LocalAiGridDataSource(
        initialData: sample,
        columns: cols,
      );

      final rows = await ds.fetchRows();
      expect(rows.length, 5);

      final samples = await ds.getSampleData(limit: 3);
      expect(samples.length, 3);
      expect(samples.first.containsKey('orderId'), isTrue);
    });
  });

  group('AiGridController Tests', () {
    test('manages grouping, search, and state summary', () {
      final controller = AiGridController();
      expect(controller.activeGrouping.isEmpty, isTrue);

      controller.addGroup('region');
      expect(controller.activeGrouping, ['region']);

      controller.addGroup('sector');
      expect(controller.activeGrouping, ['region', 'sector']);

      controller.removeGroup('region');
      expect(controller.activeGrouping, ['sector']);

      controller.search('tech');
      expect(controller.searchQuery, 'tech');

      final state = controller.getStateSummary();
      expect(state['activeGrouping'], ['sector']);
      expect(state['searchQuery'], 'tech');
    });

    test('performs in-built calculations accurately', () {
      final controller = AiGridController();
      final sample = [
        {'orderId': 1, 'sales': 100.0, 'category': 'Tech'},
        {'orderId': 2, 'sales': 200.0, 'category': 'Tech'},
        {'orderId': 3, 'sales': 300.0, 'category': 'Office'},
      ];
      final cols = [
        const AiGridColumn(
            field: 'orderId', title: 'Order ID', type: AiGridColumnType.number),
        const AiGridColumn(
            field: 'sales', title: 'Sales', type: AiGridColumnType.currency),
        const AiGridColumn(
            field: 'category', title: 'Category', type: AiGridColumnType.text),
      ];

      final ds = LocalAiGridDataSource(initialData: sample, columns: cols);
      controller.attach(columns: cols, dataSource: ds);

      // Average
      final avgRes = controller.calculate(field: 'sales', operation: 'average');
      expect(avgRes['result'], 200.0);

      // Sum
      final sumRes = controller.calculate(field: 'sales', operation: 'sum');
      expect(sumRes['result'], 600.0);

      // Min & Max
      expect(
          controller.calculate(field: 'sales', operation: 'min')['result'], 100.0);
      expect(
          controller.calculate(field: 'sales', operation: 'max')['result'], 300.0);

      // Grouped calculation
      final groupCalc = controller.calculate(
          field: 'sales', operation: 'sum', groupBy: 'category');
      expect(groupCalc['groups'], isNotNull);
      final groups = groupCalc['groups'] as Map<String, dynamic>;
      expect(groups['Tech']['result'], 300.0);
      expect(groups['Office']['result'], 300.0);
    });

    test('supports multi-filter joined with AND', () {
      final controller = AiGridController();
      final sample = [
        {'orderId': 1, 'region': 'East', 'category': 'Tech'},
        {'orderId': 2, 'region': 'East', 'category': 'Office'},
        {'orderId': 3, 'region': 'West', 'category': 'Tech'},
      ];
      final cols = [
        const AiGridColumn(
            field: 'orderId', title: 'Order ID', type: AiGridColumnType.number),
        const AiGridColumn(
            field: 'region', title: 'Region', type: AiGridColumnType.text),
        const AiGridColumn(
            field: 'category', title: 'Category', type: AiGridColumnType.text),
      ];
      final ds = LocalAiGridDataSource(initialData: sample, columns: cols);
      controller.attach(columns: cols, dataSource: ds);

      controller.setFilters([
        {'field': 'region', 'operator': 'equals', 'value': 'East'},
        {'field': 'category', 'operator': 'equals', 'value': 'Tech'},
      ]);

      expect(controller.activeFilters.length, 2);
      expect(controller.activeFilters['region']?['value'], 'East');
      expect(controller.activeFilters['category']?['value'], 'Tech');
    });

    test('sequential setFilter calls preserve previous filters in both controller and fitController', () {
      final controller = AiGridController();
      final sample = [
        {'orderId': 1, 'Quantity': 5, 'Discount': 0.2},
        {'orderId': 2, 'Quantity': 2, 'Discount': 0.0},
        {'orderId': 3, 'Quantity': 7, 'Discount': 0.0},
      ];
      final cols = [
        const AiGridColumn(field: 'orderId', title: 'Order ID', type: AiGridColumnType.number),
        const AiGridColumn(field: 'Quantity', title: 'Quantity', type: AiGridColumnType.number),
        const AiGridColumn(field: 'Discount', title: 'Discount', type: AiGridColumnType.number),
      ];
      final ds = LocalAiGridDataSource(initialData: sample, columns: cols);
      controller.attach(columns: cols, dataSource: ds);

      // 1. First filter on Discount
      controller.setFilter('Discount', operator: 'not equals', value: '0');
      expect(controller.activeFilters.containsKey('Discount'), isTrue);
      expect(controller.fitController!.filter.filters.containsKey('Discount'), isTrue);
      expect(controller.fitController!.filter.filters['Discount']?.operator, FitGridFilterOperator.notEquals);

      // 2. Second filter on Quantity
      controller.setFilter('Quantity', operator: 'greaterThan', value: '4');
      // Verify Discount was NOT cleared
      expect(controller.activeFilters.containsKey('Discount'), isTrue);
      expect(controller.activeFilters.containsKey('Quantity'), isTrue);
      expect(controller.fitController!.filter.filters.containsKey('Discount'), isTrue);
      expect(controller.fitController!.filter.filters.containsKey('Quantity'), isTrue);
      expect(controller.fitController!.filter.filters['Discount']?.operator, FitGridFilterOperator.notEquals);
      expect(controller.fitController!.filter.filters['Quantity']?.operator, FitGridFilterOperator.greaterThan);
    });

    test('supports negative filter operators (not equals, does not contain)', () {
      final controller = AiGridController();
      final sample = [
        {'orderId': 1, 'category': 'Furniture'},
        {'orderId': 2, 'category': 'Office Supplies'},
        {'orderId': 3, 'category': 'Technology'},
      ];
      final cols = [
        const AiGridColumn(
            field: 'orderId', title: 'Order ID', type: AiGridColumnType.number),
        const AiGridColumn(
            field: 'category', title: 'Category', type: AiGridColumnType.text),
      ];
      final ds = LocalAiGridDataSource(initialData: sample, columns: cols);
      controller.attach(columns: cols, dataSource: ds);

      controller.setFilter('category', operator: 'not equals', value: 'Furniture');
      expect(controller.activeFilters['category']?['operator'], 'not equals');
      expect(controller.activeFilters['category']?['value'], 'Furniture');

      controller.setFilter('category', operator: 'does not contain', value: 'Supplies');
      expect(controller.activeFilters['category']?['operator'], 'does not contain');
      expect(controller.activeFilters['category']?['value'], 'Supplies');
    });
  });

  group('AiGrid MCP Skill & Tools Tests', () {
    test('executes MCP local tools against controller', () async {
      final controller = AiGridController();
      final sample = List.generate(
        10,
        (i) => {
          'orderId': i + 1,
          'region': i % 2 == 0 ? 'East' : 'West',
          'sector': i % 2 == 0 ? 'Tech' : 'Health',
          'sales': (i + 1) * 50.0,
        },
      );
      final cols = [
        const AiGridColumn(
            field: 'orderId', title: 'Order ID', type: AiGridColumnType.number),
        const AiGridColumn(
            field: 'region', title: 'Region', type: AiGridColumnType.text),
        const AiGridColumn(
            field: 'sector', title: 'Sector', type: AiGridColumnType.text),
        const AiGridColumn(
            field: 'sales', title: 'Sales', type: AiGridColumnType.currency),
      ];

      final ds = LocalAiGridDataSource(initialData: sample, columns: cols);
      controller.attach(columns: cols, dataSource: ds);

      final tools = AiGridSkill.createTools(controller);
      final schemaTool = tools.firstWhere((t) => t.name == 'grid_get_schema');
      final stateTool = tools.firstWhere((t) => t.name == 'grid_get_state');
      final calcTool = tools.firstWhere((t) => t.name == 'grid_calculate');
      final filterTool = tools.firstWhere((t) => t.name == 'grid_set_filter');
      final groupTool = tools.firstWhere((t) => t.name == 'grid_group');
      final sortTool = tools.firstWhere((t) => t.name == 'grid_sort');
      final resetTool = tools.firstWhere((t) => t.name == 'grid_reset');

      // Test schema
      final schemaRes = await schemaTool.execute({});
      expect(schemaRes.content.first.text?.contains('orderId'), isTrue);

      // Test calculate tool (in-built function without LLM math)
      final calcRes = await calcTool
          .execute({'field': 'sales', 'operation': 'average'});
      expect(calcRes.content.first.text?.toLowerCase().contains('average of sales'), isTrue);

      // Test multi-filter joined with AND
      final filterRes = await filterTool.execute({
        'filters': [
          {'field': 'region', 'operator': 'equals', 'value': 'East'},
          {'field': 'sector', 'operator': 'equals', 'value': 'Tech'},
        ]
      });
      expect(filterRes.content.first.text?.contains('Filters applied:'), isTrue);
      expect(filterRes.content.first.text?.contains('joined by AND'), isFalse);

      // Test grouping
      final groupRes =
          await groupTool.execute({'columns': ['region', 'sector']});
      expect(controller.activeGrouping, ['region', 'sector']);
      expect(groupRes.content.first.text?.contains('region, sector'), isTrue);

      // Test sorting
      final sortRes =
          await sortTool.execute({'column': 'orderId', 'descending': true});
      expect(controller.activeSortColumn, 'orderId');
      expect(controller.isSortDescending, isTrue);
      expect(sortRes.content.first.text?.contains('orderId'), isTrue);

      // Test reset
      await resetTool.execute({});
      expect(controller.activeGrouping.isEmpty, isTrue);
      expect(controller.activeSortColumn, isNull);

      // Test export tool declaration
      final exportTool = tools.firstWhere((t) => t.name == 'export');
      expect(exportTool.name, 'export');
      expect(exportTool.description.contains('Save As'), isTrue);

      final legacyExportTool = tools.firstWhere((t) => t.name == 'grid_export');
      expect(legacyExportTool.name, 'grid_export');
      expect(legacyExportTool.inputSchema['properties']?['format'], isNotNull);

      // Test column enableEditingMode
      final testCol = const AiGridColumn(
        field: 'test',
        title: 'Test',
        enableEditingMode: false,
      ).toFitGridColumn();
      expect(testCol.isEditable, isFalse);

      // Test state
      final stateRes = await stateTool.execute({});
      final stateJson = jsonDecode(stateRes.content.first.text ?? '{}');
      expect(stateJson['activeGrouping'], isEmpty);
    });

    test('AiGridController settings export and restore persists configuration', () async {
      final cols = [
        const AiGridColumn(field: 'id', title: 'ID', type: AiGridColumnType.number),
        const AiGridColumn(field: 'category', title: 'Category', type: AiGridColumnType.text),
        const AiGridColumn(field: 'sales', title: 'Sales', type: AiGridColumnType.number),
      ];

      final sample = [
        {'id': 1, 'category': 'Office Supplies', 'sales': 100},
        {'id': 2, 'category': 'Technology', 'sales': 500},
      ];

      final ds = LocalAiGridDataSource(initialData: sample, columns: cols);
      final controller = AiGridController();
      controller.attach(columns: cols, dataSource: ds);

      // Modify grid settings: grouping, sorting, filters, visibility
      controller.setGrouping(['category']);
      controller.setSorting('sales', descending: true);
      controller.setFilter('sales', operator: 'greater than', value: 50);
      controller.showOnlyColumns(['id', 'sales']);

      // 1. Export settings
      final exported = controller.exportSettings();
      expect(exported['groupColumns'], ['category']);
      expect(exported['sorts'], isNotEmpty);
      expect((exported['sorts'] as List).first['field'], 'sales');
      expect((exported['sorts'] as List).first['descending'], isTrue);
      expect(exported['filters'], isNotEmpty);
      expect(exported['filters']['sales']['operator'], 'greater than');
      expect(exported['visibleColumns'], containsAll(['id', 'sales']));
      expect(exported['hiddenColumns'], contains('category'));

      // 2. Export to JSON string
      final jsonStr = controller.exportSettingsJson();
      expect(jsonStr, contains('groupColumns'));
      expect(jsonStr, contains('category'));

      // 3. Reset grid
      controller.reset();
      expect(controller.activeGrouping, isEmpty);
      expect(controller.activeSortColumn, isNull);
      expect(controller.activeFilters, isEmpty);
      expect(controller.hiddenColumns, isEmpty);

      // 4. Restore settings from Map
      controller.restoreSettings(exported);
      expect(controller.activeGrouping, ['category']);
      expect(controller.activeSortColumn, 'sales');
      expect(controller.isSortDescending, isTrue);
      expect(controller.activeFilters.containsKey('sales'), isTrue);
      expect(controller.hiddenColumns, contains('category'));

      // 5. Test AiGridSettingsStorage cache
      AiGridSettingsStorage.save('test_persistence_key', exported);
      final loaded = AiGridSettingsStorage.load('test_persistence_key');
      expect(loaded, isNotNull);
      expect(loaded!['groupColumns'], ['category']);
      AiGridSettingsStorage.clear('test_persistence_key');
      expect(AiGridSettingsStorage.load('test_persistence_key'), isNull);

      // 6. Test MCP Tools: GridExportSettingsTool & GridRestoreSettingsTool
      final tools = AiGridSkill.createTools(controller);
      final exportSettingsTool = tools.firstWhere((t) => t.name == 'grid_export_settings');
      final restoreSettingsTool = tools.firstWhere((t) => t.name == 'grid_restore_settings');

      final exportResult = await exportSettingsTool.execute({});
      expect(exportResult.content.first.text, contains('"groupColumns"'));

      controller.reset();
      expect(controller.activeGrouping, isEmpty);

      final restoreResult = await restoreSettingsTool.execute({
        'settingsJson': exportResult.content.first.text,
      });
      expect(restoreResult.content.first.text, contains('restored successfully'));
      expect(controller.activeGrouping, ['category']);
    });

    test('LazyAiGridDataSource & pagination tools work as expected', () async {
      final cols = [
        const AiGridColumn(
            field: 'id', title: 'ID', type: AiGridColumnType.number),
        const AiGridColumn(
            field: 'name', title: 'Name', type: AiGridColumnType.text),
      ];

      final lazyDs = LazyAiGridDataSource(
        columns: cols,
        fetch: ({required page, required pageSize, sortColumn, descending = false, searchQuery}) async {
          return List.generate(
            pageSize,
            (i) => {
              'id': (page - 1) * pageSize + i + 1,
              'name': 'Item ${(page - 1) * pageSize + i + 1}',
            },
          );
        },
        totalRowCountGetter: () => 100,
      );

      expect(lazyDs.totalRowCount, 100);
      final sample = await lazyDs.getSampleData(limit: 2);
      expect(sample.length, 2);
      expect(sample.first['id'], 1);

      final controller = AiGridController();
      controller.attach(columns: cols, dataSource: lazyDs);

      final tools = AiGridSkill.createTools(controller);
      final pageTool = tools.firstWhere((t) => t.name == 'grid_go_to_page');
      final paginationStatusTool = tools.firstWhere((t) => t.name == 'grid_get_pagination_status');

      final statusRes = await paginationStatusTool.execute({});
      expect(statusRes.content.first.text?.contains('currentPage'), isTrue);

      final pageRes = await pageTool.execute({'page': 2, 'pageSize': 20});
      expect(pageRes.content.first.text?.contains('success'), isTrue);
    });

    testWidgets('AiGrid widget initializes safely with initialSettings containing empty groupColumns', (tester) async {
      final sample = [
        {'id': 1, 'name': 'A'},
        {'id': 2, 'name': 'B'},
      ];
      final cols = [
        const AiGridColumn(field: 'id', title: 'ID', type: AiGridColumnType.number),
        const AiGridColumn(field: 'name', title: 'Name', type: AiGridColumnType.text),
      ];
      final ds = LocalAiGridDataSource(initialData: sample, columns: cols);
      final controller = AiGridController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiGrid(
              controller: controller,
              dataSource: ds,
              initialSettings: const {
                'groupColumns': [],
                'visibleColumns': ['id', 'name'],
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.activeGrouping.isEmpty, isTrue);
    });

    testWidgets('AiGrid autoSave automatically restores saved group columns on startup', (tester) async {
      AiGridSettingsStorage.save('persist_test_key', {
        'groupColumns': ['name'],
        'visibleColumns': ['id', 'name'],
      });

      final sample = [
        {'id': 1, 'name': 'A'},
        {'id': 2, 'name': 'B'},
      ];
      final cols = [
        const AiGridColumn(field: 'id', title: 'ID', type: AiGridColumnType.number),
        const AiGridColumn(field: 'name', title: 'Name', type: AiGridColumnType.text),
      ];
      final ds = LocalAiGridDataSource(initialData: sample, columns: cols);
      final controller = AiGridController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiGrid(
              controller: controller,
              dataSource: ds,
              autoSave: true,
              persistenceKey: 'persist_test_key',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.activeGrouping, ['name']);
    });

    testWidgets('AiGrid renders both vertical and horizontal Scrollbars', (tester) async {
      final sample = [
        {'id': 1, 'name': 'A', 'val': 10},
      ];
      final cols = [
        const AiGridColumn(field: 'id', title: 'ID', type: AiGridColumnType.number, width: 200),
        const AiGridColumn(field: 'name', title: 'Name', type: AiGridColumnType.text, width: 300),
        const AiGridColumn(field: 'val', title: 'Val', type: AiGridColumnType.number, width: 400),
      ];
      final ds = LocalAiGridDataSource(initialData: sample, columns: cols);
      final controller = AiGridController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: AiGrid(
                controller: controller,
                dataSource: ds,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollbars = find.byType(Scrollbar);
      expect(scrollbars, findsNWidgets(2));
    });

    test('AiGridColumn toFitGridColumn handles resizable, fixed, and custom columnWidth', () {
      // Default: resizable=true -> auto width (not pinned)
      const col1 = AiGridColumn(field: 'name', title: 'Name', width: 160);
      final fitCol1 = col1.toFitGridColumn();
      expect(fitCol1.resizable, isTrue);
      expect(fitCol1.width.isPinned, isFalse);
      expect(fitCol1.width, isA<FitGridAutoWidth>());

      // Resizable=false with explicit width -> fixed width (pinned)
      const col2 = AiGridColumn(field: 'id', title: 'ID', width: 80, resizable: false);
      final fitCol2 = col2.toFitGridColumn();
      expect(fitCol2.resizable, isFalse);
      expect(fitCol2.width.isPinned, isTrue);
      expect(fitCol2.width, isA<FitGridFixedWidth>());

      // Custom columnWidth (e.g. flex)
      const col3 = AiGridColumn(
        field: 'desc',
        title: 'Description',
        columnWidth: FitGridColumnWidth.flex(2, min: 100),
      );
      final fitCol3 = col3.toFitGridColumn();
      expect(fitCol3.resizable, isTrue);
      expect(fitCol3.width, isA<FitGridFlexWidth>());
    });

    test('AiGridController sets and resets column widths', () {
      final sample = [
        {'id': 1, 'name': 'Item 1'},
      ];
      final cols = [
        const AiGridColumn(field: 'id', title: 'ID', type: AiGridColumnType.number, width: 100),
        const AiGridColumn(field: 'name', title: 'Name', type: AiGridColumnType.text, width: 200),
      ];
      final ds = LocalAiGridDataSource(initialData: sample, columns: cols);
      final controller = AiGridController();
      controller.attach(columns: cols, dataSource: ds);

      expect(controller.columnWidths['id'], 100.0);
      expect(controller.columnWidths['name'], 200.0);
      expect(controller.isColumnResized('id'), isTrue);

      controller.setColumnWidth('id', 150.0);
      expect(controller.columnWidths['id'], 150.0);

      controller.autoSizeColumn('id');
      expect(controller.isColumnResized('id'), isFalse);
    });

    test('AiGridController supports OR and inList filtering (e.g. New York or Denver)', () {
      final sample = [
        {'id': 1, 'city': 'New York'},
        {'id': 2, 'city': 'Denver'},
        {'id': 3, 'city': 'Chicago'},
        {'id': 4, 'city': 'San Francisco'},
      ];
      final cols = [
        const AiGridColumn(field: 'id', title: 'ID', type: AiGridColumnType.number),
        const AiGridColumn(field: 'city', title: 'City', type: AiGridColumnType.text),
      ];
      final ds = LocalAiGridDataSource(initialData: sample, columns: cols);
      final controller = AiGridController();
      controller.attach(columns: cols, dataSource: ds);

      // Test 1: operator "inList" with List of values
      controller.setFilter('city', operator: 'inList', value: ['New York', 'Denver']);
      expect(controller.fitController!.filter.filters['city']?.operator, FitGridFilterOperator.inList);
      expect(controller.fitController!.data.view.length, 2);
      expect(controller.fitController!.data.view.map((r) => r['city']), containsAll(['New York', 'Denver']));

      // Test 2: operator "or" with delimited string
      controller.setFilter('city', operator: 'or', value: 'Denver or Chicago');
      expect(controller.fitController!.filter.filters['city']?.operator, FitGridFilterOperator.inList);
      expect(controller.fitController!.data.view.length, 2);
      expect(controller.fitController!.data.view.map((r) => r['city']), containsAll(['Denver', 'Chicago']));

      // Test 3: automatic OR detection with contains and "New York or Denver"
      controller.setFilter('city', operator: 'contains', value: 'New York or Denver');
      expect(controller.fitController!.filter.filters['city']?.operator, FitGridFilterOperator.inList);
      expect(controller.fitController!.data.view.length, 2);

      // Test 4: parser and toText support
      final parsed = FitGridColumnFilter.parse('New York or Denver', FitGridFilterKind.text);
      expect(parsed, isNotNull);
      expect(parsed!.operator, FitGridFilterOperator.inList);
      expect(parsed.values, containsAll(['New York', 'Denver']));
      expect(parsed.matches('new york', null), isTrue);
      expect(parsed.matches('Denver', null), isTrue);
      expect(parsed.matches('Chicago', null), isFalse);
    });

    test('AiGridEditingOptions and AiGridColumn editing extensions configure properly', () {
      final col = AiGridColumn(
        field: 'title',
        title: 'Title',
        editable: true,
        editorIndex: 1,
        editorType: AiGridEditorType.text,
        validator: (v) => v == null || v.toString().isEmpty ? 'Required' : null,
        required: true,
      );

      expect(col.isEditable, isTrue);
      expect(col.required, isTrue);
      expect(col.editorIndex, 1);
      expect(col.editorType, AiGridEditorType.text);
      expect(col.validate(''), 'Title is required');
      expect(col.validate(null), 'Title is required');
      expect(col.validate('Valid'), isNull);

      final controller = AiGridController();
      controller.setEditingOptions(const AiGridEditingOptions(
        mode: AiGridEditMode.form,
        allowAdding: true,
        allowUpdating: true,
        allowDeleting: true,
        actionColumnPosition: AiGridActionColumnPosition.left,
        insertRowPosition: AiGridInsertRowPosition.bottom,
        formLayout: AiGridFormLayout.grid(columns: 3),
      ));

      expect(controller.editingOptions.mode, AiGridEditMode.form);
      expect(controller.editingOptions.allowAdding, isTrue);
      expect(controller.editingOptions.allowDeleting, isTrue);
      expect(controller.editingOptions.actionColumnPosition, AiGridActionColumnPosition.left);
      expect(controller.editingOptions.insertRowPosition, AiGridInsertRowPosition.bottom);
      expect(controller.editingOptions.formLayout.mode, AiGridFormLayoutMode.grid);
      expect(controller.editingOptions.formLayout.columns, 3);
    });

    test('AiGridController CRUD pipeline executes validation, commit, afterSave, and delete', () async {
      final sample = [
        {'id': 1, 'name': 'Item 1', 'price': 10.0},
        {'id': 2, 'name': 'Item 2', 'price': 20.0},
      ];
      final cols = [
        const AiGridColumn(field: 'id', title: 'ID', type: AiGridColumnType.number),
        AiGridColumn(
          field: 'name',
          title: 'Name',
          type: AiGridColumnType.text,
          editable: true,
          validator: (v) => v == null || v.toString().trim().isEmpty ? 'Name cannot be empty' : null,
        ),
        const AiGridColumn(field: 'price', title: 'Price', type: AiGridColumnType.number, editable: true),
      ];

      final ds = LocalAiGridDataSource(initialData: sample, columns: cols);
      final controller = AiGridController();
      controller.attach(columns: cols, dataSource: ds);

      final committedFields = <String, dynamic>{};
      Map<String, dynamic>? savedRowResult;

      controller.setEditingOptions(AiGridEditingOptions(
        mode: AiGridEditMode.row,
        allowAdding: true,
        allowUpdating: true,
        allowDeleting: true,
        commit: (col, val) => committedFields[col] = val,
        afterSave: (row) => savedRowResult = row,
      ));

      // 1. Test startEdit & updateDraftValue
      controller.startEdit(0);
      expect(controller.isEditingRow, isTrue);
      expect(controller.editingRowIndex, 0);
      expect(controller.draftRow?['name'], 'Item 1');

      controller.updateDraftValue('name', 'Updated Item 1');
      expect(controller.draftRow?['name'], 'Updated Item 1');

      // 2. Test saveEdit
      final err = await controller.saveEdit();
      expect(err, isNull);
      expect(controller.isEditingRow, isFalse);
      expect(controller.fitController!.data.rows[0]['name'], 'Updated Item 1');
      expect(committedFields['name'], 'Updated Item 1');
      expect(savedRowResult?['name'], 'Updated Item 1');

      // 3. Test validation failure on empty name
      controller.startEdit(0);
      controller.updateDraftValue('name', '');
      final valErr = await controller.saveEdit();
      expect(valErr, 'Name cannot be empty');
      expect(controller.isEditingRow, isTrue); // Keeps editor open
      expect(controller.validationErrors['name'], 'Name cannot be empty');

      controller.cancelEdit();
      expect(controller.isEditingRow, isFalse);
      expect(controller.validationErrors.isEmpty, isTrue);

      // 4. Test startAdd & save
      committedFields.clear();
      controller.startAdd({'id': 3, 'name': 'Item 3', 'price': 30.0});
      expect(controller.isAddingRow, isTrue);
      final addErr = await controller.saveEdit();
      expect(addErr, isNull);
      expect(controller.fitController!.data.rows.length, 3);
      expect(controller.fitController!.data.rows[0]['id'], 3);

      // 5. Test deleteRow
      Map<String, dynamic>? deletedRow;
      controller.setEditingOptions(AiGridEditingOptions(
        afterDelete: (r) => deletedRow = r,
      ));
      final delSuccess = await controller.deleteRow(0);
      expect(delSuccess, isTrue);
      expect(controller.fitController!.data.rows.length, 2);
      expect(deletedRow?['id'], 3);
    });

    testWidgets('AiGridFormDialog renders editable fields respecting editorIndex order', (tester) async {
      final cols = [
        const AiGridColumn(
          field: 'id',
          title: 'ID',
          type: AiGridColumnType.number,
          editable: false,
        ),
        const AiGridColumn(
          field: 'category',
          title: 'Category',
          type: AiGridColumnType.select,
          editable: true,
          editorIndex: 2,
          selectOptions: ['Tech', 'Home', 'Auto'],
        ),
        const AiGridColumn(
          field: 'name',
          title: 'Item Name',
          type: AiGridColumnType.text,
          editable: true,
          editorIndex: 1,
        ),
        const AiGridColumn(
          field: 'inStock',
          title: 'In Stock',
          type: AiGridColumnType.boolean,
          editable: true,
          editorIndex: 3,
        ),
      ];

      final ds = LocalAiGridDataSource(
        columns: cols,
        initialData: [
          {'id': 1, 'name': 'Widget A', 'category': 'Tech', 'inStock': true},
        ],
      );

      final controller = AiGridController();
      controller.attach(columns: cols, dataSource: ds);
      controller.setEditingOptions(const AiGridEditingOptions(
        mode: AiGridEditMode.form,
        allowUpdating: true,
      ));

      controller.startEdit(0);

      await tester.pumpWidget(
        fm.MaterialApp(
          home: fm.Scaffold(
            body: fm.Builder(
              builder: (context) => fm.ElevatedButton(
                onPressed: () => AiGridFormDialog.show(context, controller: controller),
                child: const fm.Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // ID is not editable, should not appear as form input
      expect(find.text('ID'), findsNothing);

      // Name, Category, In Stock should be rendered
      expect(find.text('Item Name'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('In Stock'), findsOneWidget);

      // Title defaults to Edit Record
      expect(find.text('Edit Record'), findsOneWidget);

      // Close dialog by tapping Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AiGridFormDialog), findsNothing);
      expect(controller.isEditingRow, isFalse);
    });

    testWidgets('AiGridFormDialog validates input, displays errors, and saves on success', (tester) async {
      final cols = [
        AiGridColumn(
          field: 'name',
          title: 'Item Name',
          type: AiGridColumnType.text,
          editable: true,
          validator: (val) => (val == null || val.toString().trim().isEmpty) ? 'Name required' : null,
        ),
        const AiGridColumn(
          field: 'price',
          title: 'Price',
          type: AiGridColumnType.currency,
          editable: true,
        ),
      ];

      final ds = LocalAiGridDataSource(
        columns: cols,
        initialData: [
          {'name': 'Item 1', 'price': 50.0},
        ],
      );

      final controller = AiGridController();
      controller.attach(columns: cols, dataSource: ds);
      controller.setEditingOptions(const AiGridEditingOptions(
        mode: AiGridEditMode.form,
        allowUpdating: true,
      ));

      controller.startEdit(0);

      await tester.pumpWidget(
        fm.MaterialApp(
          home: fm.Scaffold(
            body: fm.Builder(
              builder: (context) => fm.ElevatedButton(
                onPressed: () => AiGridFormDialog.show(context, controller: controller),
                child: const fm.Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Enter empty name to trigger validator
      await tester.enterText(find.widgetWithText(TextFormField, 'Item Name'), '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Name required'), findsOneWidget);
      expect(find.byType(AiGridFormDialog), findsOneWidget);

      // Enter valid name and save
      await tester.enterText(find.widgetWithText(TextFormField, 'Item Name'), 'Super Item');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(AiGridFormDialog), findsNothing);
      expect(controller.fitController!.data.rows[0]['name'], 'Super Item');
    });

    testWidgets('AiGridFormDialog supports wrap, grid, and custom form layouts', (tester) async {
      final cols = [
        const AiGridColumn(field: 'f1', title: 'Field 1', editable: true),
        const AiGridColumn(field: 'f2', title: 'Field 2', editable: true),
        const AiGridColumn(field: 'f3', title: 'Field 3', editable: true),
      ];

      final ds = LocalAiGridDataSource(
        columns: cols,
        initialData: [
          {'f1': 'A', 'f2': 'B', 'f3': 'C'},
        ],
      );

      final controller = AiGridController();
      controller.attach(columns: cols, dataSource: ds);

      // 1. Grid layout
      controller.setEditingOptions(const AiGridEditingOptions(
        mode: AiGridEditMode.form,
        formLayout: AiGridFormLayout.grid(columns: 2),
      ));
      controller.startEdit(0);

      await tester.pumpWidget(
        fm.MaterialApp(
          home: fm.Scaffold(
            body: fm.Builder(
              builder: (context) => fm.ElevatedButton(
                onPressed: () => AiGridFormDialog.show(context, controller: controller),
                child: const fm.Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(AiGridFormDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // 2. Custom layout
      controller.setEditingOptions(AiGridEditingOptions(
        mode: AiGridEditMode.form,
        formLayout: AiGridFormLayout.custom(
          (context, draftValues, onChanged) => Container(
            key: const ValueKey('custom-form-container'),
            child: const Text('Custom Form Layout Content'),
          ),
        ),
      ));
      controller.startEdit(0);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('custom-form-container')), findsOneWidget);
      expect(find.text('Custom Form Layout Content'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('AiGrid in row edit mode injects action column and toggles inline editing', (tester) async {
      final sample = [
        {'id': 1, 'name': 'Item A', 'price': 100.0},
        {'id': 2, 'name': 'Item B', 'price': 200.0},
      ];
      final cols = [
        const AiGridColumn(field: 'id', title: 'ID', type: AiGridColumnType.number),
        const AiGridColumn(field: 'name', title: 'Name', type: AiGridColumnType.text, editable: true),
        const AiGridColumn(field: 'price', title: 'Price', type: AiGridColumnType.number, editable: true),
      ];
      final ds = LocalAiGridDataSource(initialData: sample, columns: cols);
      final controller = AiGridController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 500,
              child: AiGrid(
                controller: controller,
                dataSource: ds,
                editingOptions: const AiGridEditingOptions(
                  mode: AiGridEditMode.row,
                  allowUpdating: true,
                  allowDeleting: true,
                  actionColumnPosition: AiGridActionColumnPosition.right,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check edit and delete icons are rendered
      expect(find.byIcon(Icons.edit_outlined), findsWidgets);
      expect(find.byIcon(Icons.delete_outline), findsWidgets);

      // Start editing first row
      controller.startEdit(0);
      await tester.pumpAndSettle();

      // Now check and close icons are rendered for row 0
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Cancel editing
      controller.cancelEdit();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    test('AiGridController logs editing events and supports clearEditEvents', () async {
      final controller = AiGridController();
      final ds = LocalAiGridDataSource(
        columns: [const AiGridColumn(field: 'id', title: 'ID', editable: true)],
        initialData: [{'id': 1}, {'id': 2}],
      );
      controller.attach(columns: ds.columns, dataSource: ds);

      expect(controller.editEvents, isEmpty);

      controller.startEdit(0);
      expect(controller.editEvents.length, 1);
      expect(controller.editEvents.last.action, 'startEdit');

      controller.updateDraftValue('id', 99);
      expect(controller.editEvents.length, 2);
      expect(controller.editEvents.last.action, 'change');
      expect(controller.editEvents.last.newValue, 99);

      await controller.saveEdit();
      expect(controller.editEvents.length, 3);
      expect(controller.editEvents.last.action, 'save');

      await controller.deleteRow(0);
      expect(controller.editEvents.length, 4);
      expect(controller.editEvents.last.action, 'delete');

      controller.clearEditEvents();
      expect(controller.editEvents, isEmpty);
    });

    test('AiGridPivotConfig models serialize to/from JSON and support aggregations', () {
      const valConfig = AiGridPivotValueConfig(
        columnId: 'sales',
        aggregation: AiGridPivotAggregation.average,
        label: 'Avg Sales',
      );
      expect(valConfig.effectiveLabel('Sales'), 'Avg Sales');
      expect(valConfig.aggregation.displayName, 'Average');
      expect(valConfig.aggregation.toFitGrid(), FitGridAggregation.average);

      final jsonVal = valConfig.toJson();
      final parsedVal = AiGridPivotValueConfig.fromJson(jsonVal);
      expect(parsedVal.columnId, 'sales');
      expect(parsedVal.aggregation, AiGridPivotAggregation.average);

      const pivotConfig = AiGridPivotConfig(
        rowFieldIds: ['region', 'category'],
        columnFieldIds: ['segment'],
        values: [valConfig],
        showChart: true,
        chartType: AiGridPivotChartType.pie,
      );

      final jsonPivot = pivotConfig.toJson();
      final parsedPivot = AiGridPivotConfig.fromJson(jsonPivot);
      expect(parsedPivot.rowFieldIds, ['region', 'category']);
      expect(parsedPivot.columnFieldIds, ['segment']);
      expect(parsedPivot.values.length, 1);
      expect(parsedPivot.showChart, isTrue);
      expect(parsedPivot.chartType, AiGridPivotChartType.pie);
    });

    test('AiGridController creates pivot table, generates chart data, and restores normal table', () {
      final controller = AiGridController();
      final sample = [
        {'region': 'East', 'category': 'Tech', 'sales': 100.0, 'profit': 20.0},
        {'region': 'East', 'category': 'Office', 'sales': 50.0, 'profit': 10.0},
        {'region': 'West', 'category': 'Tech', 'sales': 200.0, 'profit': 40.0},
        {'region': 'West', 'category': 'Office', 'sales': 80.0, 'profit': 15.0},
      ];
      final cols = [
        const AiGridColumn(field: 'region', title: 'Region', type: AiGridColumnType.text),
        const AiGridColumn(field: 'category', title: 'Category', type: AiGridColumnType.text),
        const AiGridColumn(field: 'sales', title: 'Sales', type: AiGridColumnType.number),
        const AiGridColumn(field: 'profit', title: 'Profit', type: AiGridColumnType.number),
      ];

      final ds = LocalAiGridDataSource(initialData: sample, columns: cols);
      final fitCtrl = FitGridController<Map<String, dynamic>>(
        rows: sample,
        columns: cols.map((c) => c.toFitGridColumn()).toList(),
      );
      controller.attach(columns: cols, dataSource: ds, fitController: fitCtrl);

      expect(controller.isPivotActive, isFalse);

      // Set Pivot: Rows: region, Columns: category, Measures: sales (sum) & profit (average)
      controller.setPivot(const AiGridPivotConfig(
        rowFieldIds: ['region'],
        columnFieldIds: ['category'],
        values: [
          AiGridPivotValueConfig(columnId: 'sales', aggregation: AiGridPivotAggregation.sum),
          AiGridPivotValueConfig(columnId: 'profit', aggregation: AiGridPivotAggregation.average),
        ],
        showChart: true,
        chartType: AiGridPivotChartType.groupedBar,
      ));

      expect(controller.isPivotActive, isTrue);
      expect(controller.pivotConfig, isNotNull);
      // There are 2 regions (East, West)
      expect(controller.fitController!.data.rows.length, 2);
      expect(controller.columns.length, greaterThanOrEqualTo(3));

      // Chart data generated
      final chartData = controller.pivotChartData;
      expect(chartData, isNotNull);
      expect(chartData!.categories, containsAll(['East', 'West']));
      expect(chartData.seriesNames.isNotEmpty, isTrue);

      // Toggle chart & change type
      controller.togglePivotChart(false);
      expect(controller.pivotConfig!.showChart, isFalse);
      controller.togglePivotChart(true);
      expect(controller.pivotConfig!.showChart, isTrue);

      controller.setPivotChartType(AiGridPivotChartType.line);
      expect(controller.pivotConfig!.chartType, AiGridPivotChartType.line);

      // Clear Pivot (Switch back to normal table mode)
      controller.clearPivot();
      expect(controller.isPivotActive, isFalse);
      expect(controller.fitController!.data.rows.length, 4);
      expect(controller.columns.length, 4);
    });

    test('MCP GridCreatePivotTableTool and GridResetPivotTableTool execute correctly', () async {
      final controller = AiGridController();
      final sample = [
        {'region': 'North', 'sales': 120.0},
        {'region': 'South', 'sales': 250.0},
      ];
      final cols = [
        const AiGridColumn(field: 'region', title: 'Region'),
        const AiGridColumn(field: 'sales', title: 'Sales', type: AiGridColumnType.number),
      ];
      final ds = LocalAiGridDataSource(initialData: sample, columns: cols);
      final fitCtrl = FitGridController<Map<String, dynamic>>(
        rows: sample,
        columns: cols.map((c) => c.toFitGridColumn()).toList(),
      );
      controller.attach(columns: cols, dataSource: ds, fitController: fitCtrl);

      final createTool = GridCreatePivotTableTool(controller);
      final resetTool = GridResetPivotTableTool(controller);

      final result = await createTool.execute({
        'rows': ['region'],
        'data': [
          {'column': 'sales', 'aggregation': 'sum'},
        ],
        'showChart': true,
        'chartType': 'column',
      });

      expect(result.isError, isFalse);
      expect(result.content.first.text, contains('Pivot Table created successfully'));
      expect(controller.isPivotActive, isTrue);
      expect(controller.pivotConfig!.chartType, AiGridPivotChartType.column);

      // Reset
      final resetResult = await resetTool.execute({});
      expect(resetResult.isError, isFalse);
      expect(resetResult.content.first.text, contains('Pivot mode deactivated'));
      expect(controller.isPivotActive, isFalse);
    });

    testWidgets('AiGrid renders Pivot Table and side-by-side Chart in pivot mode', (tester) async {
      final controller = AiGridController();
      final sample = [
        {'category': 'Furniture', 'sales': 500.0},
        {'category': 'Office', 'sales': 300.0},
      ];
      final cols = [
        const AiGridColumn(field: 'category', title: 'Category'),
        const AiGridColumn(field: 'sales', title: 'Sales', type: AiGridColumnType.number),
      ];
      final ds = LocalAiGridDataSource(initialData: sample, columns: cols);

      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 800,
              child: AiGrid(
                dataSource: ds,
                controller: controller,
                enableAiAssistant: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Normal table mode
      expect(find.byType(AiGridPivotChart), findsNothing);

      // Activate Pivot with Chart
      controller.setPivot(const AiGridPivotConfig(
        rowFieldIds: ['category'],
        values: [
          AiGridPivotValueConfig(columnId: 'sales', aggregation: AiGridPivotAggregation.sum),
        ],
        showChart: true,
      ));
      await tester.pumpAndSettle();

      // Pivot Chart is rendered beside table
      expect(find.byType(AiGridPivotChart), findsOneWidget);
      expect(find.text('Pivot Chart'), findsOneWidget);

      // Close chart via chart close button
      await tester.tap(find.byTooltip('Hide Chart'));
      await tester.pumpAndSettle();
      expect(find.byType(AiGridPivotChart), findsNothing);

      // Clear pivot
      controller.clearPivot();
      await tester.pumpAndSettle();
      expect(controller.isPivotActive, isFalse);
    });

    testWidgets('AiGridPivotChooserDialog opens safely without MaterialLocalizations errors', (tester) async {
      final controller = AiGridController();
      final sample = [
        {'category': 'Furniture', 'sales': 500.0},
      ];
      final cols = [
        const AiGridColumn(field: 'category', title: 'Category'),
        const AiGridColumn(field: 'sales', title: 'Sales', type: AiGridColumnType.number),
      ];
      final ds = LocalAiGridDataSource(initialData: sample, columns: cols);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 800,
              child: AiGrid(
                dataSource: ds,
                controller: controller,
                enableAiAssistant: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Pivot Table button in toolbar
      final pivotBtn = find.byTooltip('Pivot Table (Field Chooser)...');
      expect(pivotBtn, findsOneWidget);
      await tester.tap(pivotBtn);
      await tester.pumpAndSettle();

      // Dialog is displayed
      expect(find.byType(AiGridPivotChooserDialog), findsOneWidget);
      expect(find.text('Pivot Table Field Chooser'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AiGridPivotChooserDialog), findsNothing);
    });
  });
}



