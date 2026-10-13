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
      ExportTool(controller),
      GridExportTool(controller),
      GridGoToPageTool(controller),
      GridGetPaginationTool(controller),
      GridExportSettingsTool(controller),
      GridRestoreSettingsTool(controller),
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

IMPORTANT RULES FOR EXPORTING:
• When the user asks to export, download, or save table or grid data (e.g. "export table", "export data", "export grid", "export to excel", "export to xlsx", "download data", "save table"):
  ALWAYS call the `export` tool.
  This triggers the platform "Save As..." dialog (on Web, Desktop, and Mobile) so the user can select their output directory and enter their desired filename, exporting cleanly to Excel (.xlsx) using FitGrid's native XLSX engine.
• For legacy or programmatic raw CSV/JSON downloads, `grid_export` is also available.

IMPORTANT RULES FOR COLUMN VISIBILITY:
• When the user says "show fields X, Y, Z" or "only show columns A, B" or "display columns A, B, C":
  Use `grid_set_column_visibility` with `showOnly: ["X", "Y", "Z"]`. This will automatically HIDE all other columns and display only the requested ones!
• When the user asks to hide specific columns (e.g. "hide column X"), use `hideColumns: ["X"]` or `column: "X", visible: false`.
• When the user asks to restore or show all columns, use `grid_reset`.

Confirm the actions and calculations clearly and concisely to the user. Do not append extra explanatory notes like "(active filters joined by AND)" or "(joined by AND)".
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
            text: 'Filters applied: $desc.',
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
            text: 'Filter applied: $column $op "$value".',
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

/// MCP tool to export current grid data to Excel (.xlsx) using FitGrid's XLSX engine
/// and prompt the user with a native Save As... dialog to select output directory and filename.
class ExportTool extends McpLocalTool {
  final AiGridController controller;
  ExportTool(this.controller);

  @override
  String get name => 'export';

  @override
  String get description =>
      'Exports current grid data to Excel (.xlsx) using FitGrid and opens the platform Save As... dialog to select output directory and filename. Works on Web, Desktop (Windows, macOS, Linux), and Mobile (Android, iOS).';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'fileName': {
            'type': 'string',
            'description':
                'Optional initial filename without extension (e.g. "sales_report"). Defaults to grid_export_<timestamp>.',
          },
          'includeHeaders': {
            'type': 'boolean',
            'description':
                'Whether to include column headers as the first row. Defaults to true.',
          },
          'selectedOnly': {
            'type': 'boolean',
            'description':
                'Whether to export only selected rows instead of all visible rows. Defaults to false.',
          },
        },
      };

  @override
  Future<MCPToolResult> execute(Map<String, dynamic> arguments) async {
    try {
      final fileName = arguments['fileName'] as String?;
      final includeHeaders = (arguments['includeHeaders'] as bool?) ?? true;
      final selectedOnly = (arguments['selectedOnly'] as bool?) ?? false;

      final savedPath = await controller.exportTableWithSaveDialog(
        fileName: fileName,
        includeHeaders: includeHeaders,
        selectedOnly: selectedOnly,
      );

      if (savedPath == null || savedPath.isEmpty) {
        return MCPToolResult(
          content: [
            MCPContent(
              type: 'text',
              text: 'Export cancelled by user (file was not saved).',
            ),
          ],
        );
      }

      return MCPToolResult(
        content: [
          MCPContent(
            type: 'text',
            text:
                'Table successfully exported to Excel (.xlsx)! Saved to: $savedPath',
          ),
        ],
      );
    } catch (e) {
      return MCPToolResult(
        isError: true,
        content: [
          MCPContent(type: 'text', text: 'Failed to export table: $e'),
        ],
      );
    }
  }
}

/// MCP tool to export current grid data to CSV or JSON.
class GridExportTool extends McpLocalTool {
  final AiGridController controller;
  GridExportTool(this.controller);

  @override
  String get name => 'grid_export';

  @override
  String get description =>
      'Exports grid data to XLSX, CSV, TSV, or JSON and downloads/saves the file. Supports specifying custom format, column selection, and CSV separator.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'format': {
            'type': 'string',
            'description':
                'Export file format: "xlsx", "csv", "tsv", or "json". Defaults to "xlsx".',
            'enum': ['xlsx', 'csv', 'tsv', 'json'],
          },
          'columns': {
            'type': 'array',
            'items': {'type': 'string'},
            'description':
                'Optional list of column titles or field names to include in export. If omitted, all visible columns are exported.',
          },
          'includeHeaders': {
            'type': 'boolean',
            'description':
                'Whether to include column header row. Defaults to true.',
          },
          'separator': {
            'type': 'string',
            'description':
                'Delimiter character for CSV format (e.g. ",", ";", "\t"). Defaults to ",".',
          },
        },
      };

  @override
  Future<MCPToolResult> execute(Map<String, dynamic> arguments) async {
    try {
      final format = (arguments['format'] as String?) ?? 'csv';
      final columnsRaw = arguments['columns'] as List<dynamic>?;
      final columns = columnsRaw?.map((e) => e.toString()).toList();
      final includeHeaders = (arguments['includeHeaders'] as bool?) ?? true;
      final separator = (arguments['separator'] as String?) ?? ',';

      final savedPath = await controller.exportGrid(
        format: format,
        columns: columns,
        includeHeaders: includeHeaders,
        separator: separator,
      );

      return MCPToolResult(
        content: [
          MCPContent(
            type: 'text',
            text:
                'Grid successfully exported as ${format.toUpperCase()}! File saved: $savedPath',
          ),
        ],
      );
    } catch (e) {
      return MCPToolResult(
        isError: true,
        content: [
          MCPContent(type: 'text', text: 'Failed to export grid: $e'),
        ],
      );
    }
  }
}

/// MCP Tool allowing the AI Assistant to navigate pages.
class GridGoToPageTool extends McpLocalTool {
  final AiGridController controller;
  GridGoToPageTool(this.controller);

  @override
  String get name => 'grid_go_to_page';

  @override
  String get description =>
      'Navigates pagination on the grid to a specific page number or relative direction ("next", "previous", "first", "last").';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'page': {
            'type': 'integer',
            'description': 'Target page number (1-based index).',
          },
          'direction': {
            'type': 'string',
            'enum': ['next', 'previous', 'first', 'last'],
            'description': 'Relative page move direction.',
          },
          'pageSize': {
            'type': 'integer',
            'description': 'Optional new page size to set.',
          },
        },
      };

  @override
  Future<MCPToolResult> execute(Map<String, dynamic> arguments) async {
    final pageSize = arguments['pageSize'] as int?;
    if (pageSize != null && pageSize > 0) {
      controller.setPageSize(pageSize);
    }

    final page = arguments['page'] as int?;
    final direction = arguments['direction'] as String?;

    if (page != null) {
      controller.setPage(page);
    } else if (direction != null) {
      final cur = controller.page;
      final total = controller.totalPage;
      switch (direction.toLowerCase()) {
        case 'next':
          controller.setPage(cur + 1);
          break;
        case 'previous':
          controller.setPage(cur > 1 ? cur - 1 : 1);
          break;
        case 'first':
          controller.setPage(1);
          break;
        case 'last':
          controller.setPage(total);
          break;
      }
    }

    return MCPToolResult(
      content: [
        MCPContent(
          type: 'text',
          text: jsonEncode({
            'status': 'success',
            'currentPage': controller.page,
            'totalPage': controller.totalPage,
            'pageSize': controller.pageSize,
          }),
        ),
      ],
    );
  }
}

/// MCP Tool allowing the AI Assistant to query pagination status.
class GridGetPaginationTool extends McpLocalTool {
  final AiGridController controller;
  GridGetPaginationTool(this.controller);

  @override
  String get name => 'grid_get_pagination_status';

  @override
  String get description =>
      'Returns current pagination state: current page, total pages, page size, and whether pagination is active.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {},
      };

  @override
  Future<MCPToolResult> execute(Map<String, dynamic> arguments) async {
    return MCPToolResult(
      content: [
        MCPContent(
          type: 'text',
          text: jsonEncode({
            'isPaginated': controller.isPaginated,
            'currentPage': controller.page,
            'totalPage': controller.totalPage,
            'pageSize': controller.pageSize,
          }),
        ),
      ],
    );
  }
}

/// MCP Tool allowing the AI Assistant to export current grid configuration settings.
class GridExportSettingsTool extends McpLocalTool {
  final AiGridController controller;
  GridExportSettingsTool(this.controller);

  @override
  String get name => 'grid_export_settings';

  @override
  String get description =>
      'Exports the current grid settings (visible columns, grouping, sorts, filters, column filter row) as a JSON string.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {},
      };

  @override
  Future<MCPToolResult> execute(Map<String, dynamic> arguments) async {
    final settingsJson = controller.exportSettingsJson();
    return MCPToolResult(
      content: [
        MCPContent(
          type: 'text',
          text: settingsJson,
        ),
      ],
    );
  }
}

/// MCP Tool allowing the AI Assistant to restore grid settings from a JSON string or settings map.
class GridRestoreSettingsTool extends McpLocalTool {
  final AiGridController controller;
  GridRestoreSettingsTool(this.controller);

  @override
  String get name => 'grid_restore_settings';

  @override
  String get description =>
      'Restores grid configuration (visible columns, grouping, sorts, filters) from a settings JSON string or object.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'settingsJson': {
            'type': 'string',
            'description': 'JSON string containing grid settings.',
          },
          'settings': {
            'type': 'object',
            'description': 'Settings object containing visibleColumns, groupColumns, sorts, filters.',
          },
        },
      };

  @override
  Future<MCPToolResult> execute(Map<String, dynamic> arguments) async {
    final jsonStr = arguments['settingsJson'] as String?;
    final settingsMap = arguments['settings'] as Map<String, dynamic>?;

    if (jsonStr != null && jsonStr.isNotEmpty) {
      controller.restoreSettingsJson(jsonStr);
      return MCPToolResult(
        content: [
          MCPContent(
            type: 'text',
            text: 'Grid settings restored successfully from JSON.',
          )
        ],
      );
    } else if (settingsMap != null) {
      controller.restoreSettings(settingsMap);
      return MCPToolResult(
        content: [
          MCPContent(
            type: 'text',
            text: 'Grid settings restored successfully from settings map.',
          )
        ],
      );
    } else {
      return MCPToolResult(
        isError: true,
        content: [
          MCPContent(
            type: 'text',
            text: 'Please provide either "settingsJson" or "settings".',
          )
        ],
      );
    }
  }
}
