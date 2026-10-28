import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ai_grid/ai_grid.dart';

/// Showcase demonstration for Feature 3:
/// Master-Detail Child Rows & Nested DataGrids.
class MasterDetailExamplePage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const MasterDetailExamplePage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<MasterDetailExamplePage> createState() =>
      _MasterDetailExamplePageState();
}

class _MasterDetailExamplePageState extends State<MasterDetailExamplePage> {
  late final AiGridController _controller;
  late final LocalAiGridDataSource _dataSource;
  AiGridConfig? _aiConfig;

  bool _accordionMode = false;
  double _detailRowHeight = 380.0;
  int _lastExpandedCount = 1;

  @override
  void initState() {
    super.initState();
    _controller = AiGridController();

    final llmConfig = AiGridEnvLoader.createLlmConfigFromEnv();
    _aiConfig = AiGridConfig(
      llmConfig: llmConfig,
      suggestedPrompts: const [
        'Expand order ORD-2026-901',
        'Show details for row 2',
        'Which orders are currently expanded?',
        'Collapse all details',
        'Filter orders with status "Delivered"',
      ],
    );

    final columns = [
      const AiGridColumn(
        field: 'id',
        title: 'Order ID',
        width: 130,
        type: AiGridColumnType.text,
      ),
      const AiGridColumn(
        field: 'date',
        title: 'Date',
        width: 110,
        type: AiGridColumnType.date,
      ),
      const AiGridColumn(
        field: 'customer',
        title: 'Customer Organization',
        width: 200,
        type: AiGridColumnType.text,
      ),
      const AiGridColumn(
        field: 'status',
        title: 'Status',
        width: 140,
        minWidth: 125,
        type: AiGridColumnType.select,
        selectOptions: ['Delivered', 'In Transit', 'Processing', 'Pending'],
        cellBuilder: _buildStatusCell,
      ),
      const AiGridColumn(
        field: 'priority',
        title: 'Priority',
        width: 120,
        minWidth: 105,
        type: AiGridColumnType.select,
        selectOptions: ['Urgent', 'High', 'Standard'],
        cellBuilder: _buildPriorityCell,
      ),
      const AiGridColumn(
        field: 'item_count',
        title: 'Line Items',
        width: 100,
        type: AiGridColumnType.number,
      ),
      const AiGridColumn(
        field: 'total',
        title: 'Order Total',
        width: 130,
        type: AiGridColumnType.currency,
        aggregateType: AiGridAggregateType.sum,
      ),
      const AiGridColumn(
        field: 'carrier',
        title: 'Shipping Carrier',
        width: 130,
        type: AiGridColumnType.text,
      ),
    ];

    final sampleOrders = _generateSampleOrders();
    _dataSource = LocalAiGridDataSource(
      initialData: sampleOrders,
      columns: columns,
    );

    _controller.setMasterDetailOptions(AiGridMasterDetailOptions(
      enabled: true,
      detailRowHeight: _detailRowHeight,
      autoCollapseOthers: _accordionMode,
      rowKey: (row) => row['id'] ?? row,
      initiallyExpandedKeys: {'ORD-2026-901'},
      detailBuilder: (context, row, rowIndex) {
        return _MasterDetailPanel(
          key: ValueKey('detail_panel_${row['id']}'),
          order: row,
          rowIndex: rowIndex,
          isDarkMode: widget.isDarkMode,
        );
      },
    ));

    _controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    final count = _controller.expandedDetailCount;
    if (count != _lastExpandedCount && mounted) {
      _lastExpandedCount = count;
      setState(() {});
    }
  }

  void _toggleAccordionMode(bool value) {
    setState(() {
      _accordionMode = value;
      _controller.setMasterDetailOptions(
        _controller.masterDetailOptions?.copyWith(
          autoCollapseOthers: value,
        ),
      );
    });
  }

  void _setDetailHeight(double height) {
    setState(() {
      _detailRowHeight = height;
      _controller.setMasterDetailOptions(
        _controller.masterDetailOptions?.copyWith(
          detailRowHeight: height,
        ),
      );
    });
  }

  static Widget _buildStatusCell(
      BuildContext context, Map<String, dynamic> row, int rowIndex) {
    final status = row['status']?.toString() ?? 'Pending';
    Color bg;
    Color fg;
    IconData icon;

    switch (status) {
      case 'Delivered':
        bg = Colors.green.withValues(alpha: 0.15);
        fg = Colors.green.shade700;
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'In Transit':
        bg = Colors.blue.withValues(alpha: 0.15);
        fg = Colors.blue.shade700;
        icon = Icons.local_shipping_outlined;
        break;
      case 'Processing':
        bg = Colors.amber.withValues(alpha: 0.15);
        fg = Colors.amber.shade900;
        icon = Icons.sync_rounded;
        break;
      default:
        bg = Colors.grey.withValues(alpha: 0.15);
        fg = Colors.grey.shade700;
        icon = Icons.hourglass_empty_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: fg),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildPriorityCell(
      BuildContext context, Map<String, dynamic> row, int rowIndex) {
    final priority = row['priority']?.toString() ?? 'Standard';
    Color color;

    switch (priority) {
      case 'Urgent':
        color = Colors.red.shade600;
        break;
      case 'High':
        color = Colors.orange.shade800;
        break;
      default:
        color = Colors.blueGrey;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                priority,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final expandedCount = _controller.expandedDetailCount;

    return Scaffold(
      body: Column(
        children: [
          // Header / Feature Summary Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? const Color(0xFF1E2430)
                  : const Color(0xFFF1F5F9),
              border: Border(
                bottom: BorderSide(
                  color: widget.isDarkMode
                      ? Colors.white12
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
                  child: Icon(
                    Icons.unfold_more_rounded,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Feature 3: Master-Detail Child Rows & Nested DataGrids',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'READY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Click the leading chevron icon on any row to inspect expandable child tabs: nested order item grids, delivery tracking timeline & customer profile.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: widget.isDarkMode
                              ? Colors.white70
                              : Colors.black87,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Master-Detail Controls Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? const Color(0xFF161B22)
                  : const Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(
                  color: widget.isDarkMode
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                // Accordion Switch
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: _accordionMode,
                      onChanged: _toggleAccordionMode,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Accordion Mode',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message:
                          'When enabled, expanding a row automatically collapses previously expanded rows.',
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18, child: VerticalDivider(width: 1)),

                // Expand All / Collapse All buttons
                OutlinedButton.icon(
                  icon: const Icon(Icons.unfold_more_rounded, size: 15),
                  label: const Text('Expand All'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  onPressed: _accordionMode ? null : () => _controller.expandAllDetails(),
                ),

                FilledButton.tonalIcon(
                  icon: const Icon(Icons.unfold_less_rounded, size: 15),
                  label: Text('Collapse All${expandedCount > 0 ? " ($expandedCount)" : ""}'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  onPressed: expandedCount > 0
                      ? () => _controller.collapseAllDetails()
                      : null,
                ),

                const SizedBox(height: 18, child: VerticalDivider(width: 1)),

                // Height Selector
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Panel Height:',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SegmentedButton<double>(
                      segments: const [
                        ButtonSegment(value: 320.0, label: Text('320px')),
                        ButtonSegment(value: 380.0, label: Text('380px')),
                        ButtonSegment(value: 460.0, label: Text('460px')),
                      ],
                      selected: {_detailRowHeight},
                      onSelectionChanged: (set) => _setDetailHeight(set.first),
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        textStyle: WidgetStatePropertyAll(
                          const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main DataGrid View
          Expanded(
            child: AiGrid(
              dataSource: _dataSource,
              controller: _controller,
              aiConfig: _aiConfig,
              showToolbar: true,
              enableAiAssistant: true,
              enablePagination: false,
              cellSelection: false,
            ),
          ),
        ],
      ),
    );
  }

  static List<Map<String, dynamic>> _generateSampleOrders() {
    return [
      {
        'id': 'ORD-2026-901',
        'date': '2026-10-24',
        'customer': 'Apex Technologies Inc',
        'status': 'Delivered',
        'priority': 'Urgent',
        'item_count': 3,
        'total': 4850.00,
        'carrier': 'FedEx Express',
        'tracking': 'FX-8492049182',
        'address': '100 Innovation Way, Austin, TX 78701',
        'contact': 'Sarah Jenkins (VP Infrastructure)',
        'email': 's.jenkins@apextech.com',
        'phone': '+1 (512) 555-0199',
        'payment_terms': 'Net 30 (Wire Transfer)',
        'items': [
          {
            'item_id': 'ITM-01',
            'product': 'Dell PowerEdge R750 Server Rack',
            'sku': 'SRV-PE-R750',
            'category': 'Servers',
            'qty': 1,
            'unit_price': 3450.00,
            'discount': 0.05,
            'line_total': 3277.50,
            'stock': 'Shipped',
          },
          {
            'item_id': 'ITM-02',
            'product': 'Cisco Catalyst 9300 48-Port Switch',
            'sku': 'NET-C9300-48P',
            'category': 'Networking',
            'qty': 1,
            'unit_price': 1250.00,
            'discount': 0.00,
            'line_total': 1250.00,
            'stock': 'Shipped',
          },
          {
            'item_id': 'ITM-03',
            'product': 'APC Smart-UPS RT 3000VA 230V',
            'sku': 'PWR-UPS-3000',
            'category': 'Power',
            'qty': 1,
            'unit_price': 322.50,
            'discount': 0.00,
            'line_total': 322.50,
            'stock': 'Shipped',
          },
        ],
      },
      {
        'id': 'ORD-2026-902',
        'date': '2026-10-25',
        'customer': 'Nordic Data Labs AB',
        'status': 'In Transit',
        'priority': 'High',
        'item_count': 2,
        'total': 2140.00,
        'carrier': 'DHL Global',
        'tracking': 'DHL-9310842091',
        'address': 'Kungsportsavenyen 10, Gothenburg, Sweden',
        'contact': 'Magnus Lindqvist (Lead Architect)',
        'email': 'magnus@nordicdatalabs.se',
        'phone': '+46 31 123 456',
        'payment_terms': 'Credit Card (Corporate AMEX)',
        'items': [
          {
            'item_id': 'ITM-04',
            'product': 'NVIDIA RTX 4090 24GB GPU Module',
            'sku': 'GPU-4090-24G',
            'category': 'Hardware',
            'qty': 1,
            'unit_price': 1890.00,
            'discount': 0.00,
            'line_total': 1890.00,
            'stock': 'In Transit',
          },
          {
            'item_id': 'ITM-05',
            'product': 'Corsair AX1600i Titanium PSU',
            'sku': 'PWR-AX1600I',
            'category': 'Power',
            'qty': 1,
            'unit_price': 250.00,
            'discount': 0.00,
            'line_total': 250.00,
            'stock': 'In Transit',
          },
        ],
      },
      {
        'id': 'ORD-2026-903',
        'date': '2026-10-26',
        'customer': 'Kitsune Media Tokyo',
        'status': 'Processing',
        'priority': 'Standard',
        'item_count': 4,
        'total': 1580.00,
        'carrier': 'Yamato Transport',
        'tracking': 'YM-7731902410',
        'address': 'Roppongi Hills Mori Tower 24F, Minato-ku, Tokyo',
        'contact': 'Kenji Takahashi (Studio Director)',
        'email': 'kenji@kitsunemedia.jp',
        'phone': '+81 3 5555 0122',
        'payment_terms': 'Invoice (Bank Transfer)',
        'items': [
          {
            'item_id': 'ITM-06',
            'product': 'Sony Venice 2 OLED EVF Eye Cup',
            'sku': 'CAM-SNY-EVF',
            'category': 'Video',
            'qty': 2,
            'unit_price': 240.00,
            'discount': 0.05,
            'line_total': 456.00,
            'stock': 'Reserved',
          },
          {
            'item_id': 'ITM-07',
            'product': 'SanDisk Professional 4TB PRO-BLADE SSD',
            'sku': 'STR-4TB-BLADE',
            'category': 'Storage',
            'qty': 2,
            'unit_price': 590.00,
            'discount': 0.10,
            'line_total': 1062.00,
            'stock': 'Reserved',
          },
          {
            'item_id': 'ITM-08',
            'product': 'SmallRig Carbon Fiber Matte Box',
            'sku': 'ACC-SR-MB01',
            'category': 'Accessories',
            'qty': 1,
            'unit_price': 62.00,
            'discount': 0.00,
            'line_total': 62.00,
            'stock': 'Reserved',
          },
        ],
      },
      {
        'id': 'ORD-2026-904',
        'date': '2026-10-26',
        'customer': 'Bavaria Motor Werke AG',
        'status': 'Delivered',
        'priority': 'Urgent',
        'item_count': 2,
        'total': 6200.00,
        'carrier': 'UPS Next Day Air',
        'tracking': 'UPS-1Z9999999999',
        'address': 'Petuelring 130, Munich, Germany',
        'contact': 'Klaus Schneider (Head of Simulation)',
        'email': 'klaus.schneider@bmw-group.de',
        'phone': '+49 89 382 0',
        'payment_terms': 'Corporate SAP PO #984210',
        'items': [
          {
            'item_id': 'ITM-09',
            'product': 'Ansys HPC 32-Core Parallel Computing Node',
            'sku': 'SFT-ANSYS-32C',
            'category': 'Software License',
            'qty': 1,
            'unit_price': 5200.00,
            'discount': 0.00,
            'line_total': 5200.00,
            'stock': 'Delivered',
          },
          {
            'item_id': 'ITM-10',
            'product': 'Mellanox ConnectX-6 200Gb/s IB Adapter',
            'sku': 'NET-MLX-CX6',
            'category': 'Networking',
            'qty': 1,
            'unit_price': 1000.00,
            'discount': 0.00,
            'line_total': 1000.00,
            'stock': 'Delivered',
          },
        ],
      },
      {
        'id': 'ORD-2026-905',
        'date': '2026-10-27',
        'customer': 'Vanguard BioPharma Corp',
        'status': 'Pending',
        'priority': 'Standard',
        'item_count': 1,
        'total': 890.00,
        'carrier': 'FedEx Ground',
        'tracking': 'FX-7749201842',
        'address': '450 Cambridge Science Park, Boston, MA 02142',
        'contact': 'Dr. Elena Rostova',
        'email': 'erostova@vanguardbio.com',
        'phone': '+1 (617) 555-0144',
        'payment_terms': 'Net 60',
        'items': [
          {
            'item_id': 'ITM-11',
            'product': 'Thermo Scientific Microplate Centrifuge',
            'sku': 'LAB-TS-MPC2',
            'category': 'Lab Equipment',
            'qty': 1,
            'unit_price': 890.00,
            'discount': 0.00,
            'line_total': 890.00,
            'stock': 'Awaiting Payment',
          },
        ],
      },
    ];
  }
}

/// Rich Tabbed Master-Detail Child Row Container
class _MasterDetailPanel extends StatefulWidget {
  final Map<String, dynamic> order;
  final int rowIndex;
  final bool isDarkMode;

  const _MasterDetailPanel({
    super.key,
    required this.order,
    required this.rowIndex,
    required this.isDarkMode,
  });

  @override
  State<_MasterDetailPanel> createState() => _MasterDetailPanelState();
}

class _MasterDetailPanelState extends State<_MasterDetailPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  late final AiGridController _childController;
  late final LocalAiGridDataSource _childDataSource;
  late final List<AiGridColumn> _childColumns;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _childController = AiGridController();
    _childController.showGroupPanel = false;
    _childController.showColumnFilterRow = false;

    _childColumns = [
      const AiGridColumn(
        field: 'item_id',
        title: 'Item Code',
        width: 100,
        type: AiGridColumnType.text,
      ),
      const AiGridColumn(
        field: 'product',
        title: 'Product Description',
        width: 260,
        type: AiGridColumnType.text,
      ),
      const AiGridColumn(
        field: 'sku',
        title: 'SKU',
        width: 130,
        type: AiGridColumnType.text,
      ),
      const AiGridColumn(
        field: 'category',
        title: 'Category',
        width: 120,
        type: AiGridColumnType.text,
      ),
      const AiGridColumn(
        field: 'qty',
        title: 'Quantity',
        width: 85,
        type: AiGridColumnType.number,
      ),
      const AiGridColumn(
        field: 'unit_price',
        title: 'Unit Price',
        width: 110,
        type: AiGridColumnType.currency,
      ),
      const AiGridColumn(
        field: 'discount',
        title: 'Discount',
        width: 85,
        type: AiGridColumnType.number,
      ),
      const AiGridColumn(
        field: 'line_total',
        title: 'Line Total',
        width: 120,
        type: AiGridColumnType.currency,
        aggregateType: AiGridAggregateType.sum,
      ),
      const AiGridColumn(
        field: 'stock',
        title: 'Inventory Status',
        width: 120,
        type: AiGridColumnType.text,
      ),
    ];

    final items = (widget.order['items'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        const [];
    _childDataSource = LocalAiGridDataSource(
      initialData: items,
      columns: _childColumns,
    );
  }

  @override
  void didUpdateWidget(covariant _MasterDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.order != oldWidget.order) {
      final items = (widget.order['items'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [];
      _childDataSource.setData(items);
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _childController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final order = widget.order;
    final items = (order['items'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        const [];

    return Container(
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? const Color(0xFF13171F)
            : const Color(0xFFF1F5F9),
        border: Border(
          top: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
          bottom: BorderSide(
            color: widget.isDarkMode ? Colors.white12 : Colors.black12,
          ),
        ),
      ),
      child: Column(
        children: [
          // Sub-header with TabBar & Order Snapshot
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? const Color(0xFF1B202B)
                  : const Color(0xFFE2E8F0),
              border: Border(
                bottom: BorderSide(
                  color: widget.isDarkMode ? Colors.white10 : Colors.black12,
                ),
              ),
            ),
            child: Row(
              children: [
                TabBar(
                  controller: _tabCtrl,
                  isScrollable: true,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                  tabAlignment: TabAlignment.start,
                  indicatorWeight: 2.5,
                  indicatorColor: colorScheme.primary,
                  labelColor: colorScheme.primary,
                  unselectedLabelColor:
                      widget.isDarkMode ? Colors.white60 : Colors.black54,
                  labelStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.table_view_rounded, size: 15),
                      text: 'Child Items Grid (${items.length})',
                    ),
                    const Tab(
                      icon: Icon(Icons.timeline_rounded, size: 15),
                      text: 'Shipping & Delivery',
                    ),
                    const Tab(
                      icon: Icon(Icons.badge_outlined, size: 15),
                      text: 'Customer & Payment',
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  'Order ${order['id']}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '•  Total: \$${order['total']?.toStringAsFixed(2) ?? '0.00'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // Tab 1: Nested Child AiGrid
                _buildChildItemsGrid(context),

                // Tab 2: Shipping & Delivery Timeline
                _buildShippingTimeline(context, order),

                // Tab 3: Customer & Payment Profile Card
                _buildCustomerProfile(context, order),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildItemsGrid(BuildContext context) {
    if (_childDataSource.totalRowCount == 0) {
      return const Center(child: Text('No line items recorded for this order.'));
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.isDarkMode ? Colors.white12 : Colors.black12,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: AiGrid(
            key: ValueKey('child_grid_${widget.order['id']}'),
            controller: _childController,
            dataSource: _childDataSource,
            showToolbar: false,
            enableAiAssistant: false,
            enablePagination: false,
            showSelectionStatusBar: false,
          ),
        ),
      ),
    );
  }

  Widget _buildShippingTimeline(
      BuildContext context, Map<String, dynamic> order) {
    final tracking = order['tracking']?.toString() ?? 'N/A';
    final carrier = order['carrier']?.toString() ?? 'Carrier';
    final address = order['address']?.toString() ?? 'Address not specified';
    final status = order['status']?.toString() ?? 'Pending';

    final steps = [
      {'title': 'Order Placed', 'subtitle': '${order['date']} 09:14 AM', 'done': true},
      {'title': 'Payment Verified', 'subtitle': 'Funds Cleared', 'done': true},
      {
        'title': 'Packed & Dispatched',
        'subtitle': 'Hub Facility',
        'done': status != 'Pending'
      },
      {
        'title': 'In Transit via $carrier',
        'subtitle': 'Tracking: $tracking',
        'done': status == 'In Transit' || status == 'Delivered'
      },
      {
        'title': 'Delivered to Customer',
        'subtitle': address,
        'done': status == 'Delivered'
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip(
                avatar: const Icon(Icons.local_shipping_rounded, size: 16),
                label: Text('$carrier: $tracking'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copy Tracking #'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 11),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: tracking));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied $tracking to clipboard'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Horizontal Stepper Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: steps.map((step) {
                final isDone = step['done'] as bool;
                return Padding(
                  padding: const EdgeInsets.only(right: 24),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isDone
                              ? Colors.green.shade600
                              : Colors.grey.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDone ? Icons.check : Icons.more_horiz,
                          size: 16,
                          color: isDone ? Colors.white : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step['title'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDone
                                  ? (widget.isDarkMode
                                      ? Colors.white
                                      : Colors.black87)
                                  : Colors.grey,
                            ),
                          ),
                          Text(
                            step['subtitle'] as String,
                            style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerProfile(
      BuildContext context, Map<String, dynamic> order) {
    final customer = order['customer']?.toString() ?? 'Customer';
    final contact = order['contact']?.toString() ?? 'Representative';
    final email = order['email']?.toString() ?? 'N/A';
    final phone = order['phone']?.toString() ?? 'N/A';
    final address = order['address']?.toString() ?? 'N/A';
    final terms = order['payment_terms']?.toString() ?? 'Net 30';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.blue.withValues(alpha: 0.2),
            child: Text(
              customer.substring(0, 1),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Primary Contact: $contact',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _buildInfoChip(Icons.email_outlined, email),
                    _buildInfoChip(Icons.phone_outlined, phone),
                    _buildInfoChip(Icons.location_on_outlined, address),
                    _buildInfoChip(Icons.receipt_long_outlined, 'Terms: $terms'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
