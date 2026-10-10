import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_grid/ai_grid.dart';

void main() {
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

      // Test state
      final stateRes = await stateTool.execute({});
      final stateJson = jsonDecode(stateRes.content.first.text ?? '{}');
      expect(stateJson['activeGrouping'], isEmpty);
    });
  });
}
