import 'package:flutter_test/flutter_test.dart';
import 'package:ai_grid/ai_grid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiGrid Range Selection & Summary Tests', () {
    test('AiGridRangeSummary calculates correct summary metrics from raw rows', () {
      final rows = [
        {'product': 'Server', 'q1': 1000, 'q2': 2000},
        {'product': 'Storage', 'q1': 3000, 'q2': 4000},
      ];
      final summary = AiGridRangeSummary.fromValues(
        rows: rows,
        columnFields: ['q1', 'q2'],
      );

      expect(summary.cellCount, 4);
      expect(summary.rowCount, 2);
      expect(summary.columnCount, 2);
      expect(summary.numericCount, 4);
      expect(summary.sum, 10000);
      expect(summary.average, 2500.0);
      expect(summary.min, 1000);
      expect(summary.max, 4000);

      final json = summary.toJson();
      expect(json['cellCount'], 4);
      expect(json['sum'], 10000);
      expect(json['average'], 2500.0);
    });

    test('AiGridRangeSummary parses formatted numeric strings (currency & commas)', () {
      final rows = [
        {'sales': r'$1,500.00', 'tax': r'$150.00'},
        {'sales': r'$2,500.00', 'tax': r'$250.00'},
      ];
      final summary = AiGridRangeSummary.fromValues(
        rows: rows,
        columnFields: ['sales', 'tax'],
      );

      expect(summary.cellCount, 4);
      expect(summary.numericCount, 4);
      expect(summary.sum, 4400.0);
      expect(summary.average, 1100.0);
      expect(summary.min, 150.0);
      expect(summary.max, 2500.0);
    });

    test('AiGridController manages cell range selection and computes summary', () {
      final controller = AiGridController();
      final columns = [
        const AiGridColumn(field: 'id', title: 'ID', width: 60),
        const AiGridColumn(field: 'val1', title: 'Val 1', width: 100, type: AiGridColumnType.number),
        const AiGridColumn(field: 'val2', title: 'Val 2', width: 100, type: AiGridColumnType.number),
      ];
      final data = [
        {'id': 'A', 'val1': 10, 'val2': 20},
        {'id': 'B', 'val1': 30, 'val2': 40},
        {'id': 'C', 'val1': 50, 'val2': 60},
      ];
      final dataSource = LocalAiGridDataSource(columns: columns, initialData: data);

      controller.attach(
        columns: columns,
        dataSource: dataSource,
      );

      expect(controller.hasCellRangeSelection, isFalse);
      expect(controller.calculateSelectedRangeSummary(), isNull);

      // Select range 0:val1 to 1:val2
      controller.selectCellRange(
        anchorRow: 0,
        anchorColumn: 'val1',
        extentRow: 1,
        extentColumn: 'val2',
      );

      expect(controller.hasCellRangeSelection, isTrue);
      expect(controller.isMultiCellRangeSelected, isTrue);
      final range = controller.selectedCellRange;
      expect(range, isNotNull);
      expect(range!.firstRow, 0);
      expect(range.lastRow, 1);

      final summary = controller.calculateSelectedRangeSummary();
      expect(summary, isNotNull);
      expect(summary!.cellCount, 4);
      expect(summary.rowCount, 2);
      expect(summary.columnCount, 2);
      expect(summary.sum, 100); // 10 + 20 + 30 + 40
      expect(summary.average, 25.0);
      expect(summary.min, 10);
      expect(summary.max, 40);

      // Clear selection
      controller.clearCellRangeSelection();
      expect(controller.hasCellRangeSelection, isFalse);
      expect(controller.selectedCellRange, isNull);

      controller.dispose();
    });

    test('MCP GridGetSelectedRangeTool and GridSelectRangeTool work seamlessly', () async {
      final controller = AiGridController();
      final columns = [
        const AiGridColumn(field: 'item', title: 'Item', width: 100),
        const AiGridColumn(field: 'price', title: 'Price', width: 100, type: AiGridColumnType.number),
      ];
      final data = [
        {'item': 'Widget A', 'price': 15.0},
        {'item': 'Widget B', 'price': 25.0},
        {'item': 'Widget C', 'price': 35.0},
      ];
      final dataSource = LocalAiGridDataSource(columns: columns, initialData: data);

      controller.attach(
        columns: columns,
        dataSource: dataSource,
      );

      final getTool = GridGetSelectedRangeTool(controller);
      final selectTool = GridSelectRangeTool(controller);

      // 1. Initial check (no selection)
      final initialResult = await getTool.execute({});
      expect(initialResult.isError, isFalse);
      expect(initialResult.text, contains('"hasSelection":false'));

      // 2. Programmatic selection via MCP
      final selectResult = await selectTool.execute({
        'startRow': 0,
        'startColumn': 'price',
        'endRow': 2,
        'endColumn': 'price',
      });
      expect(selectResult.isError, isFalse);
      expect(selectResult.text, contains('"status":"selected"'));
      expect(selectResult.text, contains('"sum":75'));

      // 3. Inspect updated selection via getTool
      final updatedResult = await getTool.execute({});
      expect(updatedResult.isError, isFalse);
      expect(updatedResult.text, contains('"hasSelection":true'));
      expect(updatedResult.text, contains('"sum":75'));
      expect(updatedResult.text, contains('"average":25'));

      controller.dispose();
    });

    test('MCP GridSelectRangeTool handles semantic queries (lowest/highest margin)', () async {
      final controller = AiGridController();
      final columns = [
        const AiGridColumn(field: 'product', title: 'Product', width: 100),
        const AiGridColumn(
            field: 'margin',
            title: 'Margin',
            width: 100,
            type: AiGridColumnType.number),
      ];
      final data = [
        {'product': 'A', 'margin': 0.35},
        {'product': 'B', 'margin': 0.10},
        {'product': 'C', 'margin': 0.22},
        {'product': 'D', 'margin': 0.08},
      ];
      final dataSource =
          LocalAiGridDataSource(columns: columns, initialData: data);
      controller.attach(columns: columns, dataSource: dataSource);

      final selectTool = GridSelectRangeTool(controller);

      // Semantic selection: select low margin cells (lowest 2)
      final result = await selectTool.execute({
        'field': 'margin',
        'condition': 'lowest',
        'count': 2,
      });

      expect(result.isError, isFalse);
      expect(result.text, contains('"status":"selected"'));
      expect(result.text, contains('"mode":"semantic"'));
      expect(controller.hasCellRangeSelection, isTrue);
      final summary = controller.calculateSelectedRangeSummary();
      expect(summary, isNotNull);
      expect(summary!.cellCount, 2);
      // lowest two margins are 0.08 and 0.10 -> min is 0.08, max is 0.10
      expect(summary.min, 0.08);
      expect(summary.max, 0.10);

      // Categorical string selection: targetValue as String (not num)
      final catController = AiGridController();
      final catColumns = <AiGridColumn>[
        const AiGridColumn(field: 'ticket', title: 'Ticket', width: 80),
        const AiGridColumn(field: 'urgency', title: 'Urgency', width: 120),
      ];
      final catData = [
        {'ticket': 'TK-1', 'urgency': 'P1 (Critical)'},
        {'ticket': 'TK-2', 'urgency': 'P2 (High)'},
        {'ticket': 'TK-3', 'urgency': 'P1 (Critical)'},
      ];
      final catDataSource = LocalAiGridDataSource(columns: catColumns, initialData: catData);
      catController.attach(columns: catColumns, dataSource: catDataSource);
      final catSelectTool = GridSelectRangeTool(catController);

      final catResult = await catSelectTool.execute({
        'field': 'urgency',
        'targetValue': 'Critical',
        'condition': 'contains',
        'entireRow': true,
      });

      expect(catResult.isError, isFalse);
      expect(catResult.text, contains('"mode":"categorical"'));
      expect(catController.hasCellRangeSelection, isTrue);
      expect(catController.selectedCellRange?.lastRow, 1); // 2 matching critical rows sorted to rows 0 and 1

      catController.dispose();
      controller.dispose();
    });
  });
}
