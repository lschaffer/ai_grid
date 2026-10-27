import 'package:flutter_test/flutter_test.dart';
import 'package:ai_grid/ai_grid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiGrid Smart Columns & LLM Synthesis Tests', () {
    test('AiGridSmartColumn formats prompt with row variable interpolation', () {
      const col = AiGridSmartColumn(
        field: 'sentiment',
        title: 'Sentiment',
        promptTemplate:
            "Classify sentiment of '{feedback}' from customer '{customer}'",
      );

      final row = {
        'customer': 'Acme Corp',
        'feedback': 'The grid is super fast and responsive!',
      };

      final prompt = col.formatPrompt(row);
      expect(
        prompt,
        "Classify sentiment of 'The grid is super fast and responsive!' from customer 'Acme Corp'",
      );
    });

    test('AiGridSmartColumnRunner heuristic fallback accurately classifies sentiment and urgency', () {
      const sentimentCol = AiGridSmartColumn(
        field: 'sentiment',
        title: 'Sentiment',
        promptTemplate: "Classify sentiment of '{feedback}'",
        options: ['Positive', 'Neutral', 'Negative', 'Critical'],
      );

      const urgencyCol = AiGridSmartColumn(
        field: 'urgency',
        title: 'Urgency',
        promptTemplate: "Rate urgency for '{feedback}'",
        options: ['P1 (Critical)', 'P2 (High)', 'P3 (Medium)', 'P4 (Low)'],
      );

      final positiveRow = {'feedback': 'We love the new Excel export feature! Excellent work.'};
      final criticalRow = {'feedback': 'Severe outage: Database crash causing data loss!'};
      final bugRow = {'feedback': 'Encountered an error when sorting by date.'};

      expect(
        AiGridSmartColumnRunner.heuristicFallback(sentimentCol, positiveRow),
        'Positive',
      );
      expect(
        AiGridSmartColumnRunner.heuristicFallback(sentimentCol, criticalRow),
        'Critical',
      );
      expect(
        AiGridSmartColumnRunner.heuristicFallback(sentimentCol, bugRow),
        'Negative',
      );

      expect(
        AiGridSmartColumnRunner.heuristicFallback(urgencyCol, criticalRow),
        'P1 (Critical)',
      );
      expect(
        AiGridSmartColumnRunner.heuristicFallback(urgencyCol, bugRow),
        'P2 (High)',
      );
    });

    test('AiGridController manages smart columns, runs batch synthesis, and updates cells', () async {
      final controller = AiGridController();
      final columns = <AiGridColumn>[
        const AiGridColumn(field: 'id', title: 'ID', width: 60),
        const AiGridColumn(field: 'issue', title: 'Issue', width: 200),
        const AiGridSmartColumn(
          field: 'sentiment',
          title: 'AI Sentiment',
          promptTemplate: "Classify sentiment of '{issue}'",
          options: ['Positive', 'Neutral', 'Negative'],
        ),
      ];

      final data = [
        {'id': '1', 'issue': 'Loving the high performance canvas renderer!'},
        {'id': '2', 'issue': 'Application crashed with out of memory error'},
      ];

      final dataSource = LocalAiGridDataSource(columns: columns, initialData: data);
      controller.attach(columns: columns, dataSource: dataSource);

      expect(controller.smartColumns.length, 1);
      expect(controller.isSmartColumn('sentiment'), isTrue);
      expect(controller.isSmartColumn('id'), isFalse);
      expect(controller.getSmartCellStatus('sentiment', 0), AiGridSmartCellStatus.idle);
      expect(controller.rows[0]['sentiment'], isNull);

      // Run smart column evaluation
      await controller.runSmartColumns(force: true);

      expect(controller.getSmartCellStatus('sentiment', 0), AiGridSmartCellStatus.generated);
      expect(controller.getSmartCellStatus('sentiment', 1), AiGridSmartCellStatus.generated);
      expect(controller.rows[0]['sentiment'], 'Positive');
      expect(controller.rows[1]['sentiment'], 'Negative');

      // Clear AI values
      controller.clearSmartColumnValues('sentiment');
      expect(controller.rows[0]['sentiment'], isNull);
      expect(controller.getSmartCellStatus('sentiment', 0), AiGridSmartCellStatus.idle);

      // Re-run single cell
      await controller.runSmartColumnForCell(0, 'sentiment');
      expect(controller.rows[0]['sentiment'], 'Positive');
      expect(controller.rows[1]['sentiment'], isNull);

      controller.dispose();
    });

    test('MCP GridAddSmartColumnTool and GridRunSmartColumnsTool execute cleanly', () async {
      final controller = AiGridController();
      final columns = <AiGridColumn>[
        const AiGridColumn(field: 'ticket', title: 'Ticket', width: 80),
        const AiGridColumn(field: 'notes', title: 'Notes', width: 200),
      ];
      final data = [
        {'ticket': 'TK-1', 'notes': 'Exceptional customer service, resolved quickly!'},
        {'ticket': 'TK-2', 'notes': 'Billing error: charged twice this month.'},
      ];
      final dataSource = LocalAiGridDataSource(columns: columns, initialData: data);
      controller.attach(columns: columns, dataSource: dataSource);

      final addTool = GridAddSmartColumnTool(controller);
      final runTool = GridRunSmartColumnsTool(controller);

      // 1. Add smart column via MCP
      final addResult = await addTool.execute({
        'field': 'sentiment',
        'title': 'AI Sentiment',
        'promptTemplate': "Classify sentiment of '{notes}'",
        'options': ['Positive', 'Neutral', 'Negative'],
        'autoRun': false,
      });

      expect(addResult.isError, isFalse);
      expect(addResult.text, contains('"status":"added"'));
      expect(controller.smartColumns.length, 1);
      expect(controller.smartColumns.first.field, 'sentiment');

      // 2. Trigger run via MCP
      final runResult = await runTool.execute({
        'field': 'sentiment',
        'force': true,
      });

      expect(runResult.isError, isFalse);
      expect(runResult.text, contains('"status":"completed"'));
      expect(controller.rows[0]['sentiment'], 'Positive');

      controller.dispose();
    });
  });
}
