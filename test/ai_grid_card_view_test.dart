import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_grid/ai_grid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testColumns = [
    const AiGridColumn(field: 'id', title: 'ID', type: AiGridColumnType.text),
    const AiGridColumn(
      field: 'name',
      title: 'Customer',
      type: AiGridColumnType.text,
    ),
    const AiGridColumn(
      field: 'status',
      title: 'Status',
      type: AiGridColumnType.text,
    ),
    const AiGridColumn(
      field: 'total',
      title: 'Total',
      type: AiGridColumnType.currency,
    ),
  ];

  final testRows = [
    {'id': 'C-101', 'name': 'Alice Smith', 'status': 'Active', 'total': 150.0},
    {'id': 'C-102', 'name': 'Bob Jones', 'status': 'Pending', 'total': 300.0},
    {
      'id': 'C-103',
      'name': 'Charlie Brown',
      'status': 'Active',
      'total': 450.0,
    },
  ];

  group('Feature 7: Mobile Card View - Controller & Options', () {
    test('Initial viewMode defaults to grid', () {
      final controller = AiGridController();
      expect(controller.viewMode, equals(AiGridViewMode.grid));
      controller.dispose();
    });

    test('setViewMode and toggleViewMode update state and notify', () {
      final controller = AiGridController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setViewMode(AiGridViewMode.card);
      expect(controller.viewMode, equals(AiGridViewMode.card));
      expect(notifications, equals(1));

      // Re-setting same mode should not notify
      controller.setViewMode(AiGridViewMode.card);
      expect(notifications, equals(1));

      // Toggle flips back to grid
      controller.toggleViewMode();
      expect(controller.viewMode, equals(AiGridViewMode.grid));
      expect(notifications, equals(2));

      // Toggle flips to card
      controller.toggleViewMode();
      expect(controller.viewMode, equals(AiGridViewMode.card));
      expect(notifications, equals(3));

      controller.dispose();
    });

    test('exportSettings and restoreSettings persist viewMode', () {
      final controller = AiGridController();
      final ds = LocalAiGridDataSource(
        columns: testColumns,
        initialData: testRows,
      );
      controller.attach(columns: testColumns, dataSource: ds);

      controller.setViewMode(AiGridViewMode.card);
      final settings = controller.exportSettings();
      expect(settings['viewMode'], equals('card'));

      // Restore to a new controller
      final newController = AiGridController();
      newController.attach(columns: testColumns, dataSource: ds);
      expect(newController.viewMode, equals(AiGridViewMode.grid));

      newController.restoreSettings(settings);
      expect(newController.viewMode, equals(AiGridViewMode.card));

      controller.dispose();
      newController.dispose();
    });

    test('AiGridCardViewOptions copyWith preserves and overrides values', () {
      const options = AiGridCardViewOptions(
        primaryField: 'name',
        subtitleField: 'id',
        badgeField: 'status',
        enableSwipeActions: true,
        elevation: 2.0,
      );

      final updated = options.copyWith(
        elevation: 4.0,
        enableSwipeActions: false,
      );

      expect(updated.primaryField, equals('name'));
      expect(updated.subtitleField, equals('id'));
      expect(updated.badgeField, equals('status'));
      expect(updated.elevation, equals(4.0));
      expect(updated.enableSwipeActions, isFalse);
    });
  });

  group('Feature 7: MCP Tool - grid_set_view_mode', () {
    test('grid_set_view_mode switches view mode properly', () async {
      final controller = AiGridController();
      final tool = GridSetViewModeTool(controller);

      expect(tool.name, equals('grid_set_view_mode'));
      expect(controller.viewMode, equals(AiGridViewMode.grid));

      // Switch to card
      final res1 = await tool.execute({'mode': 'card'});
      expect(res1.isError, isFalse);
      expect(controller.viewMode, equals(AiGridViewMode.card));

      // Switch to grid
      final res2 = await tool.execute({'mode': 'grid'});
      expect(res2.isError, isFalse);
      expect(controller.viewMode, equals(AiGridViewMode.grid));

      // Invalid mode
      final res3 = await tool.execute({'mode': 'carousel'});
      expect(res3.isError, isTrue);

      controller.dispose();
    });
  });

  group('Feature 7: Widget Integration - AiGridCardView', () {
    testWidgets('Renders card feed with primary title, subtitle and badge', (
      tester,
    ) async {
      final controller = AiGridController();
      final ds = LocalAiGridDataSource(
        columns: testColumns,
        initialData: testRows,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiGrid(
              dataSource: ds,
              controller: controller,
              viewMode: AiGridViewMode.card,
              cardViewOptions: const AiGridCardViewOptions(
                primaryField: 'name',
                subtitleField: 'id',
                badgeField: 'status',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check that records are rendered
      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('Bob Jones'), findsOneWidget);
      expect(find.text('Charlie Brown'), findsOneWidget);

      // Subtitles
      expect(find.text('C-101'), findsOneWidget);
      expect(find.text('C-102'), findsOneWidget);
      expect(find.text('C-103'), findsOneWidget);

      // Status badges
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Active'), findsNWidgets(2));

      controller.dispose();
    });

    testWidgets('Card feed reflects filter and search dynamically', (
      tester,
    ) async {
      final controller = AiGridController();
      final ds = LocalAiGridDataSource(
        columns: testColumns,
        initialData: testRows,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiGrid(
              dataSource: ds,
              controller: controller,
              viewMode: AiGridViewMode.card,
              cardViewOptions: const AiGridCardViewOptions(
                primaryField: 'name',
                subtitleField: 'id',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Filter to status = Pending
      controller.setFilter('status', operator: 'equals', value: 'Pending');
      await tester.pumpAndSettle();

      expect(find.text('Bob Jones'), findsOneWidget);
      expect(find.text('Alice Smith'), findsNothing);
      expect(find.text('Charlie Brown'), findsNothing);

      // Clear filter
      controller.clearAllFilters();
      await tester.pumpAndSettle();

      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('Bob Jones'), findsOneWidget);
      expect(find.text('Charlie Brown'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Renders empty state when search matches no records', (
      tester,
    ) async {
      final controller = AiGridController();
      final ds = LocalAiGridDataSource(
        columns: testColumns,
        initialData: testRows,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiGrid(
              dataSource: ds,
              controller: controller,
              viewMode: AiGridViewMode.card,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Search for non-existent record
      controller.setSearchQuery('NonExistentPerson');
      await tester.pumpAndSettle();

      expect(find.text('No records match your criteria'), findsOneWidget);
      expect(find.text('Reset Filters'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Initializes safely inside AnimatedBuilder without setState during build', (
      tester,
    ) async {
      final controller = AiGridController();
      final ds = LocalAiGridDataSource(
        columns: testColumns,
        initialData: testRows,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                return AiGrid(
                  dataSource: ds,
                  controller: controller,
                  viewMode: AiGridViewMode.card,
                  detailRowBuilder: (ctx, row, rowIndex) => const Text('Details'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Alice Smith'), findsAtLeastNWidgets(1));

      controller.dispose();
    });
  });
}
