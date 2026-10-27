import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ai_grid/ai_grid.dart';

void main() {
  group('AiGrid Conditional Formatting Tests', () {
    test('AiGridConditionalFormat serializes to and from JSON', () {
      final bar = AiGridConditionalFormat.dataBar(
        field: 'sales',
        color: const Color(0xFF1E88E5),
        negativeColor: const Color(0xFFE53935),
        min: 0,
        max: 5000,
        showText: true,
      );

      final barJson = bar.toJson();
      expect(barJson['field'], 'sales');
      expect(barJson['type'], 'dataBar');
      expect(barJson['min'], 0);
      expect(barJson['max'], 5000);

      final restoredBar = AiGridConditionalFormat.fromJson(barJson);
      expect(restoredBar.field, 'sales');
      expect(restoredBar.type, AiGridFormatType.dataBar);
      expect(restoredBar.min, 0);
      expect(restoredBar.max, 5000);

      final highlight = AiGridConditionalFormat.highlight(
        field: 'profit',
        operator: '<',
        targetValue: 0,
        backgroundColor: const Color(0xFFFFCDD2),
        textColor: const Color(0xFFB71C1C),
        fontWeight: FontWeight.bold,
        applyToRow: true,
      );

      final highlightJson = highlight.toJson();
      final restoredHighlight =
          AiGridConditionalFormat.fromJson(highlightJson);
      expect(restoredHighlight.field, 'profit');
      expect(restoredHighlight.operator, '<');
      expect(restoredHighlight.applyToRow, true);

      // Verify matches
      expect(restoredHighlight.matches(-50, {'profit': -50}), isTrue);
      expect(restoredHighlight.matches(100, {'profit': 100}), isFalse);
    });

    test('AiGridColumn supports visual, cellStyle, and cellColor', () {
      final col = AiGridColumn(
        field: 'sales',
        title: 'Sales',
        type: AiGridColumnType.currency,
        visual: AiGridColumn.dataBar(
          color: const Color(0xFF43A047),
          negativeColor: const Color(0xFFE53935),
        ),
        cellColor: (val, row) {
          if (val is num && val < 0) return const Color(0xFFD32F2F);
          return null;
        },
      );

      expect(col.visual, isNotNull);
      expect(col.cellColor, isNotNull);

      final fitCol = col.toFitGridColumn();
      expect(fitCol.visual, isNotNull);
      expect(fitCol.cellStyle, isNotNull);

      // Sparkline column
      final sparkCol = const AiGridColumn(
        field: 'trend',
        title: '12M Trend',
        type: AiGridColumnType.sparkline,
      );
      final fitSpark = sparkCol.toFitGridColumn();
      expect(fitSpark.visual, isNotNull);
    });

    test('AiGridController manages conditional formats dynamically', () {
      final controller = AiGridController();
      final columns = [
        const AiGridColumn(field: 'id', title: 'ID'),
        const AiGridColumn(
            field: 'sales', title: 'Sales', type: AiGridColumnType.number),
        const AiGridColumn(
            field: 'profit', title: 'Profit', type: AiGridColumnType.number),
      ];

      final rows = [
        {'id': '1', 'sales': 1200, 'profit': 250},
        {'id': '2', 'sales': 800, 'profit': -150},
      ];

      final now = DateTime.now();
      controller.loadDynamicDatasource(
        AiGridDynamicDescriptor(
          name: 'test_ds',
          title: 'Test DS',
          modelName: 'test_ds_mdl',
          datasourceName: 'test_ds_data',
          createdAt: now,
          updatedAt: now,
          rowCount: rows.length,
        ),
        columns,
        rows,
      );

      expect(controller.conditionalFormats, isEmpty);

      // Add a data bar format
      controller.addConditionalFormat(
        AiGridConditionalFormat.dataBar(field: 'sales'),
      );
      expect(controller.conditionalFormats.length, 1);

      // Add a row highlight format
      controller.addConditionalFormat(
        AiGridConditionalFormat.highlight(
          field: 'profit',
          operator: '<',
          targetValue: 0,
          backgroundColor: const Color(0x33E53935),
          applyToRow: true,
        ),
      );
      expect(controller.conditionalFormats.length, 2);

      // Check rowColor resolution
      final row1Color = controller.resolveRowColor(rows[0], 0);
      final row2Color = controller.resolveRowColor(rows[1], 1);
      expect(row1Color, isNull);
      expect(row2Color, isNotNull);

      // Export settings includes conditional formats
      final settings = controller.exportSettings();
      expect(settings['conditionalFormats'], isNotNull);
      expect((settings['conditionalFormats'] as List).length, 2);

      // Clear formats
      controller.clearConditionalFormats('sales');
      expect(controller.conditionalFormats.length, 1);
      controller.clearConditionalFormats();
      expect(controller.conditionalFormats, isEmpty);
    });

    test('MCP Tools set and clear conditional formatting', () async {
      final controller = AiGridController();
      final setTool = GridSetConditionalFormatTool(controller);
      final clearTool = GridClearConditionalFormatsTool(controller);

      // Apply data bar via MCP
      final res1 = await setTool.execute({
        'field': 'sales',
        'format_type': 'data_bar',
        'color': 'blue',
      });
      expect(res1.isError, isFalse);
      expect(controller.conditionalFormats.length, 1);
      expect(
          controller.conditionalFormats.first.type, AiGridFormatType.dataBar);

      // Apply highlight via MCP
      final res2 = await setTool.execute({
        'field': 'profit',
        'format_type': 'highlight',
        'operator': '<',
        'value': 0,
        'color': 'red',
        'apply_to_row': true,
      });
      expect(res2.isError, isFalse);
      expect(controller.conditionalFormats.length, 2);

      // Clear via MCP
      final res3 = await clearTool.execute({'field': 'sales'});
      expect(res3.isError, isFalse);
      expect(controller.conditionalFormats.length, 1);

      final res4 = await clearTool.execute({});
      expect(res4.isError, isFalse);
      expect(controller.conditionalFormats, isEmpty);
    });
  });
}
