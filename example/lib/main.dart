import 'package:material_ui/material_ui.dart';
import 'package:ai_grid/ai_grid.dart';
import 'dynamic_ai_grid_example.dart';
import 'examples/superstore_enterprise_example.dart';
import 'examples/conditional_formatting_example.dart';
import 'examples/range_selection_example.dart';
import 'examples/smart_columns_example.dart';
import 'examples/master_detail_example.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AiGridEnvLoader.load();
  runApp(const AiGridShowcaseApp());
}

/// Available showcase demos in the AI Grid Gallery.
enum ShowcaseDemo {
  superstore(
    id: 'superstore',
    title: 'Flagship Superstore Grid',
    subtitle: 'DevExtreme editing, banded pivot matrix & canvas charts',
    icon: Icons.table_chart_rounded,
    badge: 'Flagship',
  ),
  smartColumns(
    id: 'smart_columns',
    title: 'Feature 1: AI Smart / Prompt Columns',
    subtitle: 'Per-row prompt evaluation & synthesized columns',
    icon: Icons.auto_awesome_rounded,
    badge: 'NEW',
  ),
  conditionalFormatting(
    id: 'conditional_formatting',
    title: 'Feature 2: Conditional Formatting & Visuals',
    subtitle: 'In-cell data bars, profit colors, progress & sparklines',
    icon: Icons.palette_rounded,
    badge: 'NEW',
  ),
  rangeSelection(
    id: 'range_selection',
    title: 'Feature 4: Range Selection & Copy/Paste',
    subtitle: 'Excel-like drag selection, keyboard navigation & TSV clipboard',
    icon: Icons.select_all_rounded,
    badge: 'NEW',
  ),
  dynamicGrid(
    id: 'dynamic_grid',
    title: 'Dynamic Ingestion DataGrid',
    subtitle: 'Ingest from files (CSV, TSV, PDF), Web GET & clipboard',
    icon: Icons.cloud_download_rounded,
    badge: 'v0.4.0',
  ),
  masterDetail(
    id: 'master_detail',
    title: 'Feature 3: Master-Detail Child Rows',
    subtitle: 'Expandable row details, nested grids & tabbed cards',
    icon: Icons.unfold_more_rounded,
    badge: 'NEW',
  ),
  excelImport(
    id: 'excel_import',
    title: 'Feature 5: Pure-Dart Excel (.xlsx) Import',
    subtitle: 'Native workbook reading, multi-sheet selection & schema inference',
    icon: Icons.file_present_rounded,
    badge: 'Planned',
  ),
  dataAuditor(
    id: 'data_auditor',
    title: 'Feature 6: AI Data Auditor & Cleaner',
    subtitle: 'Anomaly detection, missing value imputation & format cleanup',
    icon: Icons.health_and_safety_rounded,
    badge: 'Planned',
  ),
  mobileCardView(
    id: 'mobile_card_view',
    title: 'Feature 7: Mobile Card / Feed View',
    subtitle: '1-tap responsive switch between grid and feed card view',
    icon: Icons.view_agenda_rounded,
    badge: 'Planned',
  ),
  contextualAi(
    id: 'contextual_ai',
    title: 'Feature 8: Contextual Row/Cell AI Actions',
    subtitle: 'Right-click quick actions: analyze, explain, draft message',
    icon: Icons.menu_open_rounded,
    badge: 'Planned',
  );

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String badge;

  const ShowcaseDemo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badge,
  });
}

class AiGridShowcaseApp extends StatefulWidget {
  const AiGridShowcaseApp({super.key});

  @override
  State<AiGridShowcaseApp> createState() => _AiGridShowcaseAppState();
}

class _AiGridShowcaseAppState extends State<AiGridShowcaseApp> {
  ThemeMode _themeMode = ThemeMode.light;
  ShowcaseDemo _currentDemo = ShowcaseDemo.conditionalFormatting;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _selectDemo(ShowcaseDemo demo) {
    setState(() {
      _currentDemo = demo;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Grid - Next-Gen Feature Showcase',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0078D4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0078D4),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: ShowcaseGalleryShell(
        currentDemo: _currentDemo,
        onSelectDemo: _selectDemo,
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class ShowcaseGalleryShell extends StatelessWidget {
  final ShowcaseDemo currentDemo;
  final ValueChanged<ShowcaseDemo> onSelectDemo;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const ShowcaseGalleryShell({
    super.key,
    required this.currentDemo,
    required this.onSelectDemo,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  void _openFullScreenFeatureList(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => _FullScreenFeatureListPage(
          currentDemo: currentDemo,
          onSelectDemo: (demo) {
            Navigator.of(ctx).pop();
            onSelectDemo(demo);
          },
          isDarkMode: isDarkMode,
          onToggleTheme: onToggleTheme,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = MediaQuery.sizeOf(context).width < 700;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: isMobile ? 8 : 12,
        title: isMobile
            ? InkWell(
                onTap: () => _openFullScreenFeatureList(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Icon(
                          currentDemo.icon,
                          size: 15,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currentDemo.title,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: theme.hintColor,
                      ),
                    ],
                  ),
                ),
              )
            : Row(
                children: [
                  InkWell(
                    onTap: () => _openFullScreenFeatureList(context),
                    borderRadius: BorderRadius.circular(6),
                    child: Tooltip(
                      message: 'Open Fullscreen Feature Gallery',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.grid_view_rounded,
                              size: 16,
                              color: colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'AI GRID GALLERY',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ShowcaseDemo>(
                        isExpanded: true,
                        value: currentDemo,
                        icon: const Icon(Icons.arrow_drop_down_rounded),
                        items: ShowcaseDemo.values.map((demo) {
                          final isNew = demo.badge == 'NEW';
                          final isPlanned = demo.badge == 'Planned';
                          return DropdownMenuItem<ShowcaseDemo>(
                            value: demo,
                            child: Row(
                              children: [
                                Icon(demo.icon, size: 18),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    demo.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isPlanned ? Colors.grey : null,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isNew
                                        ? Colors.green.withValues(alpha: 0.2)
                                        : isPlanned
                                            ? Colors.grey.withValues(alpha: 0.2)
                                            : Colors.blue.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    demo.badge,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isNew
                                          ? Colors.green.shade800
                                          : isPlanned
                                              ? Colors.grey.shade600
                                              : Colors.blue.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            onSelectDemo(val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.grid_view_rounded),
            tooltip: 'All Features (Full Screen)',
            onPressed: () => _openFullScreenFeatureList(context),
          ),
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Toggle Theme',
            onPressed: onToggleTheme,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildCurrentDemoView(context),
    );
  }

  Widget _buildCurrentDemoView(BuildContext context) {
    switch (currentDemo) {
      case ShowcaseDemo.superstore:
        return SuperstoreGridPage(
          isDarkMode: isDarkMode,
          onToggleTheme: onToggleTheme,
        );
      case ShowcaseDemo.conditionalFormatting:
        return ConditionalFormattingExamplePage(
          isDarkMode: isDarkMode,
          onToggleTheme: onToggleTheme,
        );
      case ShowcaseDemo.dynamicGrid:
        return DynamicGridHomePage(
          isDarkMode: isDarkMode,
          onToggleTheme: onToggleTheme,
        );
      case ShowcaseDemo.rangeSelection:
        return RangeSelectionExamplePage(
          isDarkMode: isDarkMode,
          onToggleTheme: onToggleTheme,
        );
      case ShowcaseDemo.smartColumns:
        return SmartColumnsExamplePage(
          isDarkMode: isDarkMode,
          onToggleTheme: onToggleTheme,
        );
      case ShowcaseDemo.masterDetail:
        return MasterDetailExamplePage(
          isDarkMode: isDarkMode,
          onToggleTheme: onToggleTheme,
        );
      case ShowcaseDemo.excelImport:
      case ShowcaseDemo.dataAuditor:
      case ShowcaseDemo.mobileCardView:
      case ShowcaseDemo.contextualAi:
        return _buildFeatureRoadmapCard(context, currentDemo);
    }
  }

  Widget _buildFeatureRoadmapCard(BuildContext context, ShowcaseDemo demo) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Card(
          margin: const EdgeInsets.all(24),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          colorScheme.primary.withValues(alpha: 0.15),
                      child: Icon(demo.icon, size: 28, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            demo.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Approved in Roadmap (Features 1–8)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  demo.subtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Planned Architecture & Highlights:',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _buildBullet(context, 'Full specification defined in ai_grid_features_plan.md'),
                _buildBullet(context, 'Dedicated MCP tools for AI natural language orchestration'),
                _buildBullet(context, 'Direct 60 FPS canvas painting with zero widget overhead'),
                _buildBullet(context, 'WASM and Material 3 adaptive design'),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Back to Feature 2 Demo'),
                      onPressed: () =>
                          onSelectDemo(ShowcaseDemo.conditionalFormatting),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBullet(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen responsive feature showcase gallery list, ideal for mobile devices.
class _FullScreenFeatureListPage extends StatelessWidget {
  final ShowcaseDemo currentDemo;
  final ValueChanged<ShowcaseDemo> onSelectDemo;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const _FullScreenFeatureListPage({
    required this.currentDemo,
    required this.onSelectDemo,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final readyDemos =
        ShowcaseDemo.values.where((d) => d.badge != 'Planned').toList();
    final plannedDemos =
        ShowcaseDemo.values.where((d) => d.badge == 'Planned').toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
              child: Icon(Icons.grid_view_rounded,
                  size: 16, color: colorScheme.primary),
            ),
            const SizedBox(width: 10),
            const Text(
              'Feature Showcase Gallery',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Toggle Theme',
            onPressed: onToggleTheme,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildSectionHeader(
            context,
            'INTERACTIVE READY FEATURES (${readyDemos.length})',
            Icons.check_circle_rounded,
            Colors.green.shade700,
          ),
          const SizedBox(height: 10),
          ...readyDemos.map((demo) => _buildDemoCard(context, demo, isReady: true)),
          const SizedBox(height: 20),
          _buildSectionHeader(
            context,
            'UPCOMING ROADMAP FEATURES (${plannedDemos.length})',
            Icons.rocket_launch_rounded,
            Colors.amber.shade900,
          ),
          const SizedBox(height: 10),
          ...plannedDemos
              .map((demo) => _buildDemoCard(context, demo, isReady: false)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDemoCard(BuildContext context, ShowcaseDemo demo,
      {required bool isReady}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = demo == currentDemo;

    Color badgeBg;
    Color badgeFg;
    switch (demo.badge) {
      case 'Flagship':
        badgeBg = Colors.purple.withValues(alpha: 0.15);
        badgeFg = Colors.purple.shade700;
        break;
      case 'NEW':
        badgeBg = Colors.green.withValues(alpha: 0.15);
        badgeFg = Colors.green.shade800;
        break;
      case 'v0.4.0':
        badgeBg = Colors.blue.withValues(alpha: 0.15);
        badgeFg = Colors.blue.shade800;
        break;
      default:
        badgeBg = Colors.grey.withValues(alpha: 0.15);
        badgeFg = Colors.grey.shade600;
    }

    return Card(
      elevation: isSelected ? 2 : 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.45)
          : (isDarkMode ? const Color(0xFF1B202B) : const Color(0xFFF8FAFC)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? colorScheme.primary
              : (isDarkMode
                  ? Colors.white12
                  : Colors.black.withValues(alpha: 0.08)),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onSelectDemo(demo),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isSelected
                    ? colorScheme.primary
                    : colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(
                  demo.icon,
                  size: 20,
                  color: isSelected ? Colors.white : colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            demo.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isReady
                                  ? (isDarkMode ? Colors.white : Colors.black87)
                                  : (isDarkMode
                                      ? Colors.white60
                                      : Colors.black54),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            demo.badge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: badgeFg,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      demo.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_circle_rounded,
                  color: colorScheme.primary,
                  size: 22,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
