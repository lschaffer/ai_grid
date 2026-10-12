import 'dart:convert';
import 'package:flutter/material.dart';
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
      expect(filterRes.content.first.text?.contains('Filters applied (joined by AND)'), isTrue);

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
      final exportTool = tools.firstWhere((t) => t.name == 'grid_export');
      expect(exportTool.name, 'grid_export');
      expect(exportTool.inputSchema['properties']?['format'], isNotNull);

      // Test column enableEditingMode
      final testCol = const AiGridColumn(
        field: 'test',
        title: 'Test',
        enableEditingMode: false,
      ).toTrinaColumn();
      expect(testCol.enableEditingMode, isFalse);

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
        fetch: (request) async {
          final page = request.page;
          final pageSize = request.pageSize;
          final rows = List.generate(
            pageSize,
            (i) => TrinaRow(
              cells: {
                'id': TrinaCell(value: (page - 1) * pageSize + i + 1),
                'name': TrinaCell(value: 'Item ${(page - 1) * pageSize + i + 1}'),
              },
            ),
          );
          return TrinaLazyPaginationResponse(
            totalPage: 10,
            rows: rows,
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
  });
}
