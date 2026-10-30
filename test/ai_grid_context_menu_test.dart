import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_grid/ai_grid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testColumns = [
    const AiGridColumn(field: 'id', title: 'ID', type: AiGridColumnType.text),
    const AiGridColumn(
      field: 'client',
      title: 'Client',
      type: AiGridColumnType.text,
    ),
    const AiGridColumn(
      field: 'severity',
      title: 'Severity',
      type: AiGridColumnType.text,
    ),
    const AiGridColumn(
      field: 'score',
      title: 'Score',
      type: AiGridColumnType.number,
    ),
  ];

  final testRows = [
    {
      'id': 'T-01',
      'client': 'Alpha Inc',
      'severity': 'Critical',
      'score': 95.0,
    },
    {'id': 'T-02', 'client': 'Beta LLC', 'severity': 'Low', 'score': 20.0},
  ];

  group('Feature 8: Contextual AI Actions - Controller Methods', () {
    test('filterSimilar sets filter accurately on field and value', () {
      final controller = AiGridController();
      final ds = LocalAiGridDataSource(
        columns: testColumns,
        initialData: testRows,
      );
      controller.attach(columns: testColumns, dataSource: ds);

      controller.filterSimilar(field: 'severity', value: 'Critical');
      expect(controller.activeFilters.containsKey('severity'), isTrue);
      expect(
        controller.activeFilters['severity']?['value'],
        equals('Critical'),
      );

      controller.dispose();
    });

    test('askAiAboutRow seeds pendingAiPrompt and enables assistant', () {
      final controller = AiGridController();
      final ds = LocalAiGridDataSource(
        columns: testColumns,
        initialData: testRows,
      );
      controller.attach(columns: testColumns, dataSource: ds);

      expect(controller.pendingAiPrompt.value, isNull);
      expect(controller.showAiAssistant, isFalse);

      controller.askAiAboutRow(testRows[0]);
      expect(controller.pendingAiPrompt.value, isNotNull);
      expect(controller.pendingAiPrompt.value, contains('Alpha Inc'));
      expect(controller.showAiAssistant, isTrue);

      controller.clearPendingAiPrompt();
      expect(controller.pendingAiPrompt.value, isNull);

      controller.dispose();
    });

    test('draftMessageFromRow seeds communication prompt', () {
      final controller = AiGridController();
      final ds = LocalAiGridDataSource(
        columns: testColumns,
        initialData: testRows,
      );
      controller.attach(columns: testColumns, dataSource: ds);

      controller.draftMessageFromRow(testRows[1]);
      expect(
        controller.pendingAiPrompt.value,
        contains('Draft a professional communication'),
      );
      expect(controller.pendingAiPrompt.value, contains('Beta LLC'));

      controller.dispose();
    });

    test('explainCellValue seeds explanation prompt targeting column', () {
      final controller = AiGridController();
      final ds = LocalAiGridDataSource(
        columns: testColumns,
        initialData: testRows,
      );
      controller.attach(columns: testColumns, dataSource: ds);

      controller.explainCellValue(testRows[0], 'score');
      expect(controller.pendingAiPrompt.value, contains('Score'));
      expect(controller.pendingAiPrompt.value, contains('95.0'));

      controller.dispose();
    });
  });

  group('Feature 8: MCP Tool - grid_execute_context_action', () {
    test(
      'Executes ask_ai, draft_message, explain_value and filter_similar',
      () async {
        final controller = AiGridController();
        final ds = LocalAiGridDataSource(
          columns: testColumns,
          initialData: testRows,
        );
        controller.attach(columns: testColumns, dataSource: ds);
        final tool = GridExecuteContextActionTool(controller);

        expect(tool.name, equals('grid_execute_context_action'));

        // 1. ask_ai
        final res1 = await tool.execute({'action': 'ask_ai', 'row_index': 0});
        expect(res1.isError, isFalse);
        expect(controller.pendingAiPrompt.value, contains('Alpha Inc'));

        // 2. draft_message
        final res2 = await tool.execute({
          'action': 'draft_message',
          'row_index': 1,
        });
        expect(res2.isError, isFalse);
        expect(controller.pendingAiPrompt.value, contains('Beta LLC'));

        // 3. explain_value
        final res3 = await tool.execute({
          'action': 'explain_value',
          'row_index': 0,
          'field': 'score',
        });
        expect(res3.isError, isFalse);
        expect(controller.pendingAiPrompt.value, contains('Score'));

        // 4. filter_similar
        final res4 = await tool.execute({
          'action': 'filter_similar',
          'row_index': 0,
          'field': 'severity',
        });
        expect(res4.isError, isFalse);
        expect(
          controller.activeFilters['severity']?['value'],
          equals('Critical'),
        );

        // 5. copy_cell
        final res5 = await tool.execute({
          'action': 'copy_cell',
          'row_index': 1,
          'field': 'client',
        });
        expect(res5.isError, isFalse);
        expect(res5.content.first.text, contains('Beta LLC'));

        // 6. copy_row
        final res6 = await tool.execute({'action': 'copy_row', 'row_index': 0});
        expect(res6.isError, isFalse);
        expect(res6.content.first.text, contains('Alpha Inc'));

        // Error handling: invalid row index
        final resErr = await tool.execute({
          'action': 'ask_ai',
          'row_index': 999,
        });
        expect(resErr.isError, isTrue);

        controller.dispose();
      },
    );
  });

  group('Feature 8: AiGridContextMenu Widget Integration', () {
    testWidgets('buildMenuItems generates AI actions and custom actions', (
      tester,
    ) async {
      final controller = AiGridController();
      final ds = LocalAiGridDataSource(
        columns: testColumns,
        initialData: testRows,
      );
      controller.attach(columns: testColumns, dataSource: ds);

      var customActionTriggered = false;

      controller.setContextMenuConfig(
        AiGridContextMenuConfiguration(
          enabled: true,
          enableAiActions: true,
          enableClipboardActions: true,
          enableFilterSimilar: true,
          customActions: [
            AiGridContextAction(
              id: 'custom_alert',
              label: 'Trigger Alert',
              onExecute: (ctx, ctrl, row, rowIndex, col) async {
                customActionTriggered = true;
              },
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final items = AiGridContextMenu.buildMenuItems(
                  context: context,
                  controller: controller,
                  row: testRows[0],
                  rowIndex: 0,
                  columnField: 'client',
                  cellValue: testRows[0]['client'],
                );

                return ListView(
                  children: items.map((item) {
                    if (item is PopupMenuItem<void>) {
                      final popup = item;
                      return ListTile(title: popup.child, onTap: popup.onTap);
                    }
                    return const Divider();
                  }).toList(),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ask AI About Record'), findsOneWidget);
      expect(find.text('Draft Message / Email'), findsOneWidget);
      expect(find.text('Explain Value (client)'), findsOneWidget);
      expect(find.text('Filter Similar: Alpha Inc'), findsOneWidget);
      expect(find.text('Copy Cell Value'), findsOneWidget);
      expect(find.text('Copy Row (JSON)'), findsOneWidget);
      expect(find.text('Trigger Alert'), findsOneWidget);

      // Tap on custom action
      await tester.tap(find.text('Trigger Alert'));
      expect(customActionTriggered, isTrue);

      controller.dispose();
    });
  });
}
