import 'dart:convert';
import 'package:dart_mcp_core/dart_mcp_core.dart';
import '../controllers/ai_grid_controller.dart';

/// Exposes all local tools and skill manifest for [AiGrid] control via MCP.
class AiGridSkill {
  AiGridSkill._();

  static const String skillName = 'ai_grid_control';
  static const String skillDescription =
      'Controls an interactive AI DataGrid: inspect schema, filter (supports multi-column AND), calculate exact metrics without hallucinations, sort, group, search, show/hide columns, and reset tabular data.';

  /// Creates all 11 MCP tools bound to the provided [controller].
  static List<McpLocalTool> createTools(AiGridController controller) {
    return [
      GridGetSchemaTool(controller),
      GridGetStateTool(controller),
      GridGetSampleTool(controller),
      GridCalculateTool(controller),
      GridSetFilterTool(controller),
      GridClearFiltersTool(controller),
      GridSearchTool(controller),
      GridSortTool(controller),
      GridGroupTool(controller),
      GridSetColumnVisibilityTool(controller),
      GridResetTool(controller),
    ];
  }

  static const String defaultSystemPrompt = '''
You are an expert data analyst assistant embedded directly in an interactive DataGrid.
Use the available tools to help the user explore, filter, sort, group, show or hide columns, calculate metrics, and analyze tabular data.
Always start by checking the schema or current state if you need context on column names and values.

IMPORTANT RULES FOR CALCULATIONS:
• When the user asks to calculate, average, mean, sum, total, minimum, maximum, count, or median (e.g. "calculate avg sale amount", "what is the total profit", "calculate average discount by category"), ALWAYS use the `grid_calculate` tool. DO NOT calculate numbers in your head or hallucinate math. The grid engine calculates exact values in Dart.

IMPORTANT RULES FOR FILTERS:
• When the user specifies multiple filter conditions (e.g. "filter region South and Category Furniture"), use `grid_set_filter` with the `filters` array to apply ALL conditions joined by AND.
• For negative conditions (e.g. "not Furniture", "Category not equals Furniture", "exclude South"), use operator "not equals" or "does not contain".

IMPORTANT RULES FOR SORTING:
• When the user asks to sort by multiple columns, use `grid_sort` with the `sorts` array parameter.

Confirm the actions and calculations clearly and concisely to the user.
''';

  /// Creates a SkillManifest representing the AI Grid skill.
  static SkillManifest createSkillManifest(AiGridController controller) {
    final tools = createTools(controller);
    return SkillManifest(
      name: skillName,
      description: skillDescription,
      version: '1.1.0',
      systemPrompt: defaultSystemPrompt,
      tools: tools
          .map((t) => SkillToolDeclaration(
                name: t.name,
                description: t.description,
                inputSchema: t.inputSchema,
              ))
          .toList(),
    );
  }
}

class GridGetSchemaTool extends McpLocalTool {
  final AiGridController controller;
  GridGetSchemaTool(this.controller);

  @override
  String get name => 'grid_get_schema';

  @override
  String get description =>
      'Returns the grid column schema (field names, titles, data types, groupable/sortable/filterable flags).';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {},
      };

  @override
  Future<MCPToolResult> execute(Map<String, dynamic> arguments) async {
    final schema = controller.getSchemaSummary();
    return MCPToolResult(
      content: [MCPContent(type: 'text', text: jsonEncode(schema))],
    );
  }
}

class GridGetStateTool extends McpLocalTool {
  final AiGridController controller;
  GridGetStateTool(this.controller);

  @override
  String get name => 'grid_get_state';

  @override
  String get description =>
      'Returns current grid state (active grouping, active filters, active sorting, search query, filtered row count, visible/hidden columns, sortedColumns).';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {},
      };

  @override
  Future<MCPToolResult> execute(Map<String, dynamic> arguments) async {
    final state = controller.getStateSummary();
    return MCPToolResult(
      content: [MCPContent(type: 'text', text: jsonEncode(state))],
    );
  }
}

class GridGetSampleTool extends McpLocalTool {
  final AiGridController controller;
  GridGetSampleTool(this.controller);

  @override
  String get name => 'grid_get_sample_data';

  @override
  String get description =>
      'Fetches a sample of the data rows (up to 10 rows) to see actual values and format.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'limit': {
            'type': 'integer',
            'description': 'Number of rows to return (default: 5, max: 10)',
          }
        },
      };

  @override
  Future<MCPToolResult> execute(Map<String, dynamic> arguments) async {
    final limit = (arguments['limit'] as num?)?.toInt() ?? 5;
    final samples = await controller.getSampleData(limit: limit.clamp(1, 10));
    return MCPToolResult(
      content: [MCPContent(type: 'text', text: jsonEncode(samples))],
    );
  }
}

class GridCalculateTool extends McpLocalTool {
  final AiGridController controller;
  GridCalculateTool(this.controller);

  @override
  String get name => 'grid_calculate';

  @override
  String get description =>
      'Performs in-built mathematical calculations (average, sum, min, max, count, median) over column values accurately without LLM hallucinations. Can optionally group results by another column.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'required': ['field', 'operation'],
        'properties': {
          'field': {
            'type': 'string',
            'description':
                'The numeric column field or title to calculate over (e.g. "Sales", "Profit", "Quantity", "Discount").',
          },
          'operation': {
            'type': 'string',
            'enum': ['average', 'sum', 'min', 'max', 'count', 'median'],
            'description': 'The mathematical calculation to perform.',
          },
          'filteredOnly': {
            'type': 'boolean',
            'description':
                'If true, calculates over currently filtered rows (default true). If false, calculates over all rows.',
          },
          'groupBy': {
            'type': 'string',
            'description':
                'Optional column to group calculations by (e.g. "Category", "Region", "Segment").',
          },
        },
      };

  @override
  Future<MCPToolResult> execute(Map<String, dynamic> arguments) async {
    final field = arguments['field'] as String;
    final op = arguments['operation'] as String;
    final filteredOnly = arguments['filteredOnly'] as bool? ?? true;
    final groupBy = arguments['groupBy'] as String?;

    final result = controller.calculate(
      field: field,
      operation: op,
      filteredOnly: filteredOnly,
      groupBy: groupBy,
    );

    if (result['error'] != null) {
      return MCPToolResult(
        isError: true,
        content: [MCPContent(type: 'text', text: result['error'].toString())],
      );
    }

    String summaryText;
    if (result['results'] != null) {
      final groupMap = result['results'] as Map<String, dynamic>;
      final lines = groupMap.entries
          .map((e) =>
              '• ${e.key}: ${e.value['formatted']} (${e.value['count']} items)')
          .join('\n');
      summaryText =
          '${result['operation'].toString().toUpperCase()} of ${result['columnTitle']} grouped by ${result['groupedBy']}:\n$lines';
    } else {
      summaryText =
          'The ${result['operation']} of ${result['columnTitle']} is ${result['formatted']} (calculated across ${result['count']} rows).';
    }

    return MCPToolResult(
      content: [
        MCPContent(type: 'text', text: summaryText),
      ],
    );
  }
}

class GridSetFilterTool extends McpLocalTool {
  final AiGridController controller;
  GridSetFilterTool(this.controller);

  @override
  String get name => 'grid_set_filter';

  @override
  String get description =>
      'Filters the grid by column. Supports single or multiple filters joined with AND. Supported operators: contains, equals, not equals, does not contain, startsWith, endsWith, greaterThan, lessThan.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'column': {
            'type': 'string',
            'description': 'The field name of the column (e.g. Region, Category, Sales).',
          },
          'operator': {
            'type': 'string',
            'enum': [
              'contains',
              'equals',
              'not equals',
              'does not contain',
              'startsWith',
              'endsWith',
              'greaterThan',
              'lessThan'
            ],
            'description': 'Filter operator to apply.',
          },
          'value': {
            'description': 'The filter value to match against.',
          },
          'filters': {
            'type': 'array',
            'description':
                'List of multiple filter conditions to apply simultaneously (joined by AND). E.g. [{"column": "Region", "operator": "equals", "value": "South"}, {"column": "Category", "operator": "equals", "value": "Furniture"}]',
            'items': {
              'type': 'object',
              'required': ['column', 'operator', 'value'],
              'properties': {
                'column': {'type': 'string'},
                'operator': {'type': 'string'},
                'value': {},
              },
            },
          },
          'replace': {
            'type': 'boolean',
            'description':
                'If true, replaces all existing filters. Default is false (appends to active filters with AND).',
          }
        },
      };

  @override
  Future<MCPToolResult> execute(Map<String, dynamic> arguments) async {
    final filters = arguments['filters'] as List<dynamic>?;
    final replace = arguments['replace'] as bool? ?? false;

    if (filters != null && filters.isNotEmpty) {
      final list =
          filters.map((f) => Map<String, dynamic>.from(f as Map)).toList();
      controller.setFilters(list, replace: replace);
      final desc = list
          .map((f) => '${f['column'] ?? f['field']} ${f['operator']} "${f['value']}"')
          .join(' AND ');
      return MCPToolResult(
        content: [
          MCPContent(
            type: 'text',
            text: 'Filters applied (joined by AND): $desc.',
          )
        ],
      );
    }

    final column = arguments['column'] as String?;
    if (column != null && column.isNotEmpty) {
      final op = (arguments['operator'] as String?) ?? 'contains';
      final value = arguments['value'];

      if (replace) {
        controller.setFilters([
          {'column': column, 'operator': op, 'value': value}
        ], replace: true);
      } else {
        controller.setFilter(column, operator: op, value: value);
      }

      return MCPToolResult(
        content: [
          MCPContent(
            type: 'text',
            text: 'Filter applied: $column $op "$value" (active filters joined by AND).',
          )
        ],
      );
    }

    return MCPToolResult(
      isError: true,
      content: [
        MCPContent(
          type: 'text',
          text: 'Either "column", "operator", "value" or "filters" array must be provided.',
        ),
      ],
    );
  }
}

class GridClearFiltersTool extends McpLocalTool {
  final AiGridController controller;
  GridClearFiltersTool(this.controller);

  @override
  String get name => 'grid_clear_filters';

  @override
  String get description =>
      'Clears all applied column filters or a specific column filter.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'column': {
            'type': 'string',
            'description':
                'Optional specific column to clear filter from. If omitted, clears all filters.',
          }
        },
      };

  @override
  Future<MCPToolResult> execute(Map<String, dynamic> arguments) async {
    final column = arguments['column'] as String?;
    if (column != null && column.isNotEmpty) {
      controller.removeFilter(column);
      return MCPToolResult(
        content: [
          MCPContent(type: 'text', text: 'Filter cleared for column "$column".')
        ],
      );
    } else {
      controller.clearAllFilters();
      return MCPToolResult(
        content: [MCPContent(type: 'text', text: 'All column filters cleared.')],
      );
    }
  }
}

class GridSearchTool extends McpLocalTool {
  final AiGridController controller;
  GridSearchTool(this.controller);

  @override
  String get name => 'grid_search';

  @override
  String get description =>
      'Performs a global search across all columns. Pass empty string to clear search.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description':
                'Search string to filter rows across all columns. Empty to clear.',
          }
        },
      };

  @override
  Future<MCPToolResult> execute(Map<String, dynamic> arguments) async {
    final query = arguments['query'] as String? ?? '';
    controller.search(query);
    return MCPToolResult(
      content: [
        MCPContent(
          type: 'text',
          text: query.isEmpty
              ? 'Global search cleared.'
              : 'Global search applied for: "$query".',
        )
      ],
    );
  }
}

class GridSortTool extends McpLocalTool {
  final AiGridController controller;
  GridSortTool(this.controller);

  @override
  String get name => 'grid_sort';

  @override
  String get description =>
      'Sorts the grid by one or more columns in ascending or descending order. Supports multi-column sorting.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'column': {
            'type': 'string',
            'description': 'Single column field name to sort by (e.g. Region, Sales).',
          },
          'descending': {
            'type': 'boolean',
            'description': 'True for descending sort, false for ascending (default: false).',
          },
          'append': {
            'type': 'boolean',
            'description':
                'If true, appends this column to existing sorts (multi-column sorting). Default is false.',
          },
          'sorts': {
            'type': 'array',
            'description':
                'Ordered list of column sort definitions for multi-column sorting. E.g. [{"column": "Region", "descending": false}, {"column": "Sales", "descending": true}].',
            'items': {
              'type': 'object',
              'required': ['column'],
              'properties': {
                'column': {'type': 'string'},
                'descending': {'type': 'boolean'},
              },
            },
          },
        },
      };

  @override
  Future<MCPToolResult> execute(Map<String, dynamic> arguments) async {
    final sorts = arguments['sorts'] as List<dynamic>?;
    if (sorts != null && sorts.isNotEmpty) {
      final configs =
          sorts.map((s) => Map<String, dynamic>.from(s as Map)).toList();
      controller.multiSort(configs);
      final descList = configs
          .map((c) =>
              '${c['column'] ?? c['field']} (${(c['descending'] == true) ? 'desc' : 'asc'})')
          .join(', ');
      return MCPToolResult(
        content: [
          MCPContent(
            type: 'text',
            text: 'Grid multi-sorted by: $descList.',
          )
        ],
      );
    }

    final column = arguments['column'] as String?;
    if (column != null && column.isNotEmpty) {
      final descending = arguments['descending'] as bool? ?? false;
      final append = arguments['append'] as bool? ?? false;
      controller.sort(column, descending: descending, append: append);
      return MCPToolResult(
        content: [
          MCPContent(
            type: 'text',
            text:
                'Grid sorted by "$column" ${descending ? "descending" : "ascending"}${append ? " (appended to multi-sort)" : ""}.',
          )
        ],
      );
    }

    controller.clearSorting();
    return MCPToolResult(
      content: [
        MCPContent(
          type: 'text',
          text: 'Grid sorting cleared.',
        )
      ],
    );
  }
}

class GridGroupTool extends McpLocalTool {
  final AiGridController controller;
  GridGroupTool(this.controller);

  @override
  String get name => 'grid_group';

  @override
  String get description =>
      'Configures multi-level hierarchical grouping by one or more column field names.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'required': ['columns'],
        'properties': {
          'columns': {
            'type': 'array',
            'items': {'type': 'string'},
            'description':
                'Ordered list of column fields to group by. Empty array removes all grouping.',
          }
        },
      };

  @override
  Future<MCPToolResult> execute(Map<String, dynamic> arguments) async {
    final cols = (arguments['columns'] as List? ?? []).cast<String>();
    controller.setGrouping(cols);
    return MCPToolResult(
      content: [
        MCPContent(
          type: 'text',
          text: cols.isEmpty
              ? 'Grouping cleared.'
              : 'Grid grouped by: ${cols.join(", ")}.',
        )
      ],
    );
  }
}

class GridSetColumnVisibilityTool extends McpLocalTool {
  final AiGridController controller;
  GridSetColumnVisibilityTool(this.controller);

  @override
  String get name => 'grid_set_column_visibility';

  @override
  String get description =>
      'Shows or hides columns in the DataGrid. Can show/hide a single column or multiple columns at once.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'column': {
            'type': 'string',
            'description': 'The field name of the column to show or hide.',
          },
          'visible': {
            'type': 'boolean',
            'description': 'True to show the column, false to hide it.',
          },
          'visibility': {
            'type': 'object',
            'description': 'Optional map of column fields to boolean visibility values.',
          },
        },
      };

  @override
  Future<MCPToolResult> execute(Map<String, dynamic> arguments) async {
    final column = arguments['column'] as String?;
    final visible = arguments['visible'] as bool? ?? true;
    final visibility = arguments['visibility'] as Map<String, dynamic>?;

    if (visibility != null) {
      final map = visibility.map((k, v) => MapEntry(k, v as bool));
      controller.setColumnsVisibility(map);
      return MCPToolResult(
        content: [
          MCPContent(
            type: 'text',
            text: 'Updated visibility for columns: ${jsonEncode(map)}',
          ),
        ],
      );
    }

    if (column != null && column.isNotEmpty) {
      controller.setColumnVisibility(column, visible);
      return MCPToolResult(
        content: [
          MCPContent(
            type: 'text',
            text: 'Column "$column" is now ${visible ? "visible" : "hidden"}.',
          ),
        ],
      );
    }

    return MCPToolResult(
      isError: true,
      content: [
        MCPContent(
          type: 'text',
          text: 'Either "column" and "visible" or "visibility" map must be provided.',
        ),
      ],
    );
  }
}

class GridResetTool extends McpLocalTool {
  final AiGridController controller;
  GridResetTool(this.controller);

  @override
  String get name => 'grid_reset';

  @override
  String get description =>
      'Resets all grouping, filters, search query, column visibility, and sorting back to initial defaults.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {},
      };

  @override
  Future<MCPToolResult> execute(Map<String, dynamic> arguments) async {
    controller.reset();
    return MCPToolResult(
      content: [
        MCPContent(type: 'text', text: 'Grid reset to initial default state.')
      ],
    );
  }
}
