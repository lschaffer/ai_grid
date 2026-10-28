import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_grid/ai_grid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiGrid Master-Detail Options Model Tests', () {
    test('default options configuration', () {
      final opts = AiGridMasterDetailOptions(
        detailBuilder: (context, row, index) => const Text('detail'),
      );

      expect(opts.enabled, true);
      expect(opts.detailRowHeight, 360.0);
      expect(opts.autoCollapseOthers, false);
      expect(opts.detailHeight, isNull);
      expect(opts.rowKey, isNull);
      expect(opts.initiallyExpandedKeys, isNull);
    });

    test('copyWith updates properties properly', () {
      final opts = AiGridMasterDetailOptions(
        detailBuilder: (context, row, index) => const Text('detail'),
        detailRowHeight: 200.0,
        autoCollapseOthers: false,
      );

      final copy = opts.copyWith(
        detailRowHeight: 300.0,
        autoCollapseOthers: true,
      );

      expect(copy.detailRowHeight, 300.0);
      expect(copy.autoCollapseOthers, true);
      expect(copy.enabled, true);
    });
  });

  group('AiGridController Master-Detail State Management', () {
    late AiGridController controller;
    late List<AiGridColumn> columns;
    late List<Map<String, dynamic>> testData;

    setUp(() {
      controller = AiGridController();
      columns = [
        const AiGridColumn(field: 'id', title: 'ID', width: 60),
        const AiGridColumn(field: 'customer', title: 'Customer', width: 120),
        const AiGridColumn(field: 'total', title: 'Total', width: 100),
      ];
      testData = [
        {'id': 'ORD-101', 'customer': 'Acme Corp', 'total': 450.0},
        {'id': 'ORD-102', 'customer': 'Globex Inc', 'total': 890.0},
        {'id': 'ORD-103', 'customer': 'Initech LLC', 'total': 120.0},
      ];
    });

    tearDown(() {
      controller.dispose();
    });

    test('enabling master-detail attaches options and handles initial expansion', () {
      final dataSource = LocalAiGridDataSource(initialData: testData, columns: columns);
      controller.setMasterDetailOptions(AiGridMasterDetailOptions(
        detailBuilder: (context, row, index) => Text('Row ${row['id']}'),
        initiallyExpandedKeys: {'ORD-101'},
      ));

      controller.attach(
        columns: columns,
        dataSource: dataSource,
      );

      expect(controller.isMasterDetailEnabled, true);
      expect(controller.isRowExpanded('ORD-101'), true);
      expect(controller.isRowExpanded('ORD-102'), false);
      expect(controller.expandedDetailCount, 1);
    });

    test('expandRow, collapseRow and toggleRowDetail modify expansion state', () {
      final dataSource = LocalAiGridDataSource(initialData: testData, columns: columns);
      controller.setMasterDetailOptions(AiGridMasterDetailOptions(
        detailBuilder: (context, row, index) => Text('Row ${row['id']}'),
      ));
      controller.attach(columns: columns, dataSource: dataSource);

      expect(controller.isRowExpanded('ORD-101'), false);

      // Expand
      controller.expandRow('ORD-101');
      expect(controller.isRowExpanded('ORD-101'), true);
      expect(controller.expandedDetailKeys.contains('ORD-101'), true);

      // Toggle off
      controller.toggleRowDetail('ORD-101');
      expect(controller.isRowExpanded('ORD-101'), false);

      // Toggle on
      controller.toggleRowDetail('ORD-101');
      expect(controller.isRowExpanded('ORD-101'), true);

      // Collapse
      controller.collapseRow('ORD-101');
      expect(controller.isRowExpanded('ORD-101'), false);
    });

    test('expandRowAt and toggleRowDetailAt work by view index', () {
      final dataSource = LocalAiGridDataSource(initialData: testData, columns: columns);
      controller.setMasterDetailOptions(AiGridMasterDetailOptions(
        detailBuilder: (context, row, index) => Text('Row ${row['id']}'),
      ));
      controller.attach(columns: columns, dataSource: dataSource);

      expect(controller.isRowExpandedAt(0), false);
      expect(controller.isRowExpandedAt(1), false);

      controller.expandRowAt(1);
      expect(controller.isRowExpandedAt(1), true);
      expect(controller.isRowExpanded('ORD-102'), true);

      controller.toggleRowDetailAt(1);
      expect(controller.isRowExpandedAt(1), false);
    });

    test('expandAllDetails and collapseAllDetails operate across all rows', () {
      final dataSource = LocalAiGridDataSource(initialData: testData, columns: columns);
      controller.setMasterDetailOptions(AiGridMasterDetailOptions(
        detailBuilder: (context, row, index) => Text('Row ${row['id']}'),
      ));
      controller.attach(columns: columns, dataSource: dataSource);

      controller.expandAllDetails();
      expect(controller.expandedDetailCount, 3);
      expect(controller.isRowExpanded('ORD-101'), true);
      expect(controller.isRowExpanded('ORD-102'), true);
      expect(controller.isRowExpanded('ORD-103'), true);

      controller.collapseAllDetails();
      expect(controller.expandedDetailCount, 0);
      expect(controller.hasExpandedDetails, false);
    });

    test('accordion mode collapses other rows when expanding a new row', () {
      final dataSource = LocalAiGridDataSource(initialData: testData, columns: columns);
      controller.setMasterDetailOptions(AiGridMasterDetailOptions(
        detailBuilder: (context, row, index) => Text('Row ${row['id']}'),
        autoCollapseOthers: true,
      ));
      controller.attach(columns: columns, dataSource: dataSource);

      controller.expandRow('ORD-101');
      expect(controller.isRowExpanded('ORD-101'), true);
      expect(controller.expandedDetailCount, 1);

      controller.expandRow('ORD-102');
      expect(controller.isRowExpanded('ORD-102'), true);
      expect(controller.isRowExpanded('ORD-101'), false);
      expect(controller.expandedDetailCount, 1);
    });

    test('onExpansionChanged callback is notified on state changes', () {
      final notifications = <Map<String, dynamic>>[];
      final dataSource = LocalAiGridDataSource(initialData: testData, columns: columns);
      controller.setMasterDetailOptions(AiGridMasterDetailOptions(
        detailBuilder: (context, row, index) => Text('Row ${row['id']}'),
        onExpansionChanged: (key, isExpanded) {
          notifications.add({'key': key, 'expanded': isExpanded});
        },
      ));
      controller.attach(columns: columns, dataSource: dataSource);

      controller.expandRow('ORD-101');
      expect(notifications.any((n) => n['key'] == 'ORD-101' && n['expanded'] == true), true);

      controller.collapseRow('ORD-101');
      expect(notifications.any((n) => n['key'] == 'ORD-101' && n['expanded'] == false), true);
    });
  });

  group('AiGrid Master-Detail MCP Tools', () {
    late AiGridController controller;
    late List<AiGridColumn> columns;
    late List<Map<String, dynamic>> testData;

    setUp(() {
      controller = AiGridController();
      columns = [
        const AiGridColumn(field: 'id', title: 'ID', width: 60),
        const AiGridColumn(field: 'customer', title: 'Customer', width: 120),
        const AiGridColumn(field: 'total', title: 'Total', width: 100),
      ];
      testData = [
        {'id': 'ORD-101', 'customer': 'Acme Corp', 'total': 450.0},
        {'id': 'ORD-102', 'customer': 'Globex Inc', 'total': 890.0},
        {'id': 'ORD-103', 'customer': 'Initech LLC', 'total': 120.0},
      ];
      final dataSource = LocalAiGridDataSource(initialData: testData, columns: columns);
      controller.setMasterDetailOptions(AiGridMasterDetailOptions(
        detailBuilder: (context, row, index) => Text('Row ${row['id']}'),
      ));
      controller.attach(columns: columns, dataSource: dataSource);
    });

    tearDown(() {
      controller.dispose();
    });

    test('GridToggleRowDetailTool toggles by rowKey and rowIndex', () async {
      final tool = GridToggleRowDetailTool(controller);

      // Toggle by key
      final res1 = await tool.execute({'rowKey': 'ORD-101'});
      expect(res1.isError, false);
      final json1 = jsonDecode(res1.content.first.text!);
      expect(json1['isNowExpanded'], true);
      expect(controller.isRowExpanded('ORD-101'), true);

      // Toggle off by index 0
      final res2 = await tool.execute({'rowIndex': 0, 'expand': false});
      expect(res2.isError, false);
      final json2 = jsonDecode(res2.content.first.text!);
      expect(json2['isNowExpanded'], false);
      expect(controller.isRowExpanded('ORD-101'), false);
    });

    test('GridExpandAllDetailsTool and GridCollapseAllDetailsTool via MCP', () async {
      final expandTool = GridExpandAllDetailsTool(controller);
      final collapseTool = GridCollapseAllDetailsTool(controller);
      final statusTool = GridGetDetailStatusTool(controller);

      final expRes = await expandTool.execute({});
      expect(expRes.isError, false);
      expect(controller.expandedDetailCount, 3);

      final statusRes = await statusTool.execute({});
      final statusJson = jsonDecode(statusRes.content.first.text!);
      expect(statusJson['enabled'], true);
      expect(statusJson['expandedCount'], 3);

      final collRes = await collapseTool.execute({});
      expect(collRes.isError, false);
      expect(controller.expandedDetailCount, 0);
    });
  });
}
