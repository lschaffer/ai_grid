import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_grid/ai_grid.dart';

void main() {
  group('AiGridDataCleaner & Auditor Tests', () {
    final columns = [
      const AiGridColumn(
        field: 'order_id',
        title: 'Order ID',
        type: AiGridColumnType.text,
      ),
      const AiGridColumn(
        field: 'order_date',
        title: 'Order Date',
        type: AiGridColumnType.date,
      ),
      const AiGridColumn(
        field: 'region',
        title: 'Region',
        type: AiGridColumnType.text,
      ),
      const AiGridColumn(
        field: 'sales',
        title: 'Sales',
        type: AiGridColumnType.currency,
      ),
      const AiGridColumn(
        field: 'profit',
        title: 'Profit',
        type: AiGridColumnType.number,
      ),
      const AiGridColumn(
        field: 'postal_code',
        title: 'Postal Code',
        type: AiGridColumnType.text,
      ),
    ];

    List<Map<String, dynamic>> createDirtyRows() {
      return [
        {
          'order_id': 'ORD-101',
          'order_date': '2026-01-15',
          'region': 'North America',
          'sales': 120.50,
          'profit': 25.0,
          'postal_code': '10001',
        },
        {
          'order_id': 'ORD-102',
          'order_date': '02/18/2026', // Mixed date format (MM/dd/yyyy)
          'region': ' EMEA ', // Inconsistent whitespace
          'sales': r'$1,450.00', // Dirty currency string
          'profit': 180.0,
          'postal_code': null, // Missing value
        },
        {
          'order_id': 'ORD-103',
          'order_date': '15-03-2026', // Mixed date format (dd-MM-yyyy)
          'region': 'APAC',
          'sales': '350.00',
          'profit': 98000.0, // Statistical outlier
          'postal_code': '90210',
        },
        {
          'order_id': 'ORD-104',
          'order_date': '2026-04-10',
          'region': 'LATAM',
          'sales': 85.0,
          'profit': 12.0,
          'postal_code': '33101',
        },
        {
          'order_id': 'ORD-105',
          'order_date': '2026-05-01',
          'region': 'North America',
          'sales': 95.0,
          'profit': 15.0,
          'postal_code': '10002',
        },
        {
          'order_id': 'ORD-106',
          'order_date': '2026-06-12',
          'region': 'EMEA',
          'sales': 110.0,
          'profit': 18.0,
          'postal_code': 'SW1A 1AA',
        },
        {
          'order_id': 'ORD-107',
          'order_date': '2026-07-04',
          'region': 'APAC',
          'sales': 130.0,
          'profit': 22.0,
          'postal_code': '100-0001',
        },
        {
          'order_id': 'ORD-108',
          'order_date': '2026-08-20',
          'region': 'LATAM',
          'sales': 75.0,
          'profit': 10.0,
          'postal_code': '01310-100',
        },
        {
          'order_id': 'ORD-109',
          'order_date': '2026-09-15',
          'region': 'North America',
          'sales': 140.0,
          'profit': 28.0,
          'postal_code': '10003',
        },
        // Duplicate row identical to ORD-101
        {
          'order_id': 'ORD-101',
          'order_date': '2026-01-15',
          'region': 'North America',
          'sales': 120.50,
          'profit': 25.0,
          'postal_code': '10001',
        },
      ];
    }

    test('Audit detects duplicates, dirty numbers, mixed dates, whitespace and outliers', () {
      final rows = createDirtyRows();
      final report = AiGridDataCleaner.audit(rows: rows, columns: columns);

      expect(report.totalRows, 10);
      expect(report.totalColumns, 6);
      expect(report.overallScore, lessThan(100));
      expect(report.isClean, isFalse);

      final issueTypes = report.issues.map((i) => i.type).toSet();
      expect(issueTypes, contains(AiGridAuditIssueType.duplicates));
      expect(issueTypes, contains(AiGridAuditIssueType.dirtyNumbers));
      expect(issueTypes, contains(AiGridAuditIssueType.mixedDates));
      expect(issueTypes, contains(AiGridAuditIssueType.inconsistentWhitespace));
      expect(issueTypes, contains(AiGridAuditIssueType.missingValues));
      expect(issueTypes, contains(AiGridAuditIssueType.outliers));

      // Duplicates issue
      final dupIssue = report.issues.firstWhere(
        (i) => i.type == AiGridAuditIssueType.duplicates,
      );
      expect(dupIssue.affectedCount, 1);
      expect(dupIssue.affectedRowIndices, contains(9));

      // Dirty numbers issue
      final dirtyIssue = report.issues.firstWhere(
        (i) => i.type == AiGridAuditIssueType.dirtyNumbers,
      );
      expect(dirtyIssue.columnField, 'sales');

      // Mixed dates issue
      final dateIssue = report.issues.firstWhere(
        (i) => i.type == AiGridAuditIssueType.mixedDates,
      );
      expect(dateIssue.columnField, 'order_date');
      expect(dateIssue.affectedCount, 2);

      // Outlier issue
      final outlierIssues = report.issues
          .where((i) => i.type == AiGridAuditIssueType.outliers)
          .toList();
      expect(outlierIssues.any((i) => i.columnField == 'profit'), isTrue);
      final profitOutlier = outlierIssues.firstWhere(
        (i) => i.columnField == 'profit',
      );
      expect(profitOutlier.sampleValues, contains(98000.0));
    });

    test('Remediation: removeDuplicates removes duplicate records', () {
      final rows = createDirtyRows();
      final cleaned = AiGridDataCleaner.removeDuplicates(rows);

      expect(cleaned.length, 9);
      final ord101Count = cleaned
          .where((r) => r['order_id'] == 'ORD-101')
          .length;
      expect(ord101Count, 1);
    });

    test('Remediation: cleanNumbers strips currency symbols and commas', () {
      final rows = createDirtyRows();
      final cleaned = AiGridDataCleaner.cleanNumbers(rows, field: 'sales');

      expect(cleaned[1]['sales'], 1450.0);
      expect(cleaned[1]['sales'], isA<num>());
    });

    test('Remediation: standardizeDates normalizes MM/dd/yyyy and dd-MM-yyyy to ISO YYYY-MM-DD', () {
      final rows = createDirtyRows();
      final cleaned = AiGridDataCleaner.standardizeDates(
        rows,
        field: 'order_date',
      );

      expect(cleaned[1]['order_date'], '2026-02-18');
      expect(cleaned[2]['order_date'], '2026-03-15');
    });

    test('Remediation: trimWhitespace removes spaces from strings', () {
      final rows = createDirtyRows();
      final cleaned = AiGridDataCleaner.trimWhitespace(rows, field: 'region');

      expect(cleaned[1]['region'], 'EMEA');
    });

    test('Remediation: imputeMissingValues fills nulls with median/mode', () {
      final rows = createDirtyRows();
      final cleaned = AiGridDataCleaner.imputeMissingValues(
        rows,
        field: 'postal_code',
        strategy: AiGridImputeStrategy.mode,
      );

      expect(cleaned[1]['postal_code'], isNotNull);
      expect(cleaned[1]['postal_code'].toString().isNotEmpty, isTrue);
    });

    test(
      'Remediation: cleanAll resolves all anomalies and produces high score',
      () {
        final rows = createDirtyRows();
        final cleaned = AiGridDataCleaner.cleanAll(rows, columns: columns);

        expect(cleaned.length, 9); // Duplicates removed
        expect(cleaned[1]['sales'], isA<num>()); // Number normalized
        expect(cleaned[1]['region'], 'EMEA'); // Trimmed
        expect(cleaned[1]['order_date'], '2026-02-18'); // Standardized date

        final postAudit = AiGridDataCleaner.audit(
          rows: cleaned,
          columns: columns,
        );
        expect(postAudit.overallScore, greaterThanOrEqualTo(90));
      },
    );

    test('AiGridController audits and cleans data dynamically', () {
      final controller = AiGridController();
      final rows = createDirtyRows();
      final descriptor = AiGridDynamicDescriptor(
        name: 'test_dirty',
        modelName: 'test_dirty_mdl.yaml',
        datasourceName: 'test_dirty.json',
        title: 'Test Dirty',
        sourceType: 'file',
        sourceOrigin: 'dirty.csv',
        rowCount: rows.length,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      controller.loadDynamicDatasource(descriptor, columns, rows);

      // Initial audit
      final initialReport = controller.auditData();
      expect(initialReport.overallScore, lessThan(80));
      expect(initialReport.hasIssues, isTrue);

      // Clean single anomaly (whitespace in region)
      final whitespaceIssue = initialReport.issues.firstWhere(
        (i) => i.type == AiGridAuditIssueType.inconsistentWhitespace,
      );
      final trimResult = controller.cleanData(whitespaceIssue.remediation);
      expect(trimResult.success, isTrue);
      expect(controller.rows[1]['region'], 'EMEA');

      // 1-Click Clean all
      final cleanAllResult = controller.cleanAllData();
      expect(cleanAllResult.success, isTrue);
      expect(controller.rows.length, 9); // Duplicate removed

      final finalReport = controller.auditData();
      expect(finalReport.overallScore, greaterThanOrEqualTo(90));
      controller.dispose();
    });

    test(
      'AiGrid MCP Tools: grid_audit_data and grid_apply_data_cleanse',
      () async {
        final controller = AiGridController();
        final rows = createDirtyRows();
        final descriptor = AiGridDynamicDescriptor(
          name: 'test_mcp_dirty',
          modelName: 'test_mcp_dirty_mdl.yaml',
          datasourceName: 'test_mcp_dirty.json',
          title: 'Test MCP Dirty',
          sourceType: 'file',
          sourceOrigin: 'dirty.csv',
          rowCount: rows.length,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        controller.loadDynamicDatasource(descriptor, columns, rows);

        final auditTool = GridAuditDataTool(controller);
        final auditRes = await auditTool.execute({});
        expect(auditRes.isError, isFalse);
        expect(auditRes.content.first.text, contains('overallScore'));
        expect(auditRes.content.first.text, contains('issues'));

        final cleanseTool = GridApplyDataCleanseTool(controller);
        final cleanRes = await cleanseTool.execute({'action': 'clean_all'});
        expect(cleanRes.isError, isFalse);
        expect(cleanRes.content.first.text, contains('modifiedCount'));
        expect(controller.rows.length, 9);

        controller.dispose();
      },
    );

    testWidgets(
      'AiGridDataAuditorDialog renders score and executes 1-click clean',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final controller = AiGridController();
        final rows = createDirtyRows();
        final descriptor = AiGridDynamicDescriptor(
          name: 'test_widget_dirty',
          modelName: 'test_widget_dirty_mdl.yaml',
          datasourceName: 'test_widget_dirty.json',
          title: 'Test Widget Dirty',
          sourceType: 'file',
          sourceOrigin: 'dirty.csv',
          rowCount: rows.length,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        controller.loadDynamicDatasource(descriptor, columns, rows);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => controller.showDataAuditorDialog(context),
                  child: const Text('Open Auditor'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Auditor'));
        await tester.pumpAndSettle();

        expect(find.text('AI Data Quality Auditor'), findsOneWidget);
        expect(find.text('Clean All Anomalies (1-Click)'), findsOneWidget);

        await tester.tap(find.text('Clean All Anomalies (1-Click)'));
        await tester.pumpAndSettle();

        expect(controller.rows.length, 9);
        expect(find.text('Done'), findsOneWidget);
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        controller.dispose();
      },
    );
  });
}
