import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_grid_column.dart';
import '../models/ai_grid_dynamic_datasource.dart';
import 'delimited_table_parser.dart';

/// Fetches and parses tabular data from HTTP GET endpoints (JSON APIs, HTML tables, CSV endpoints).
class WebTableFetcher {
  /// Fetches the given [url] and parses tabular rows and columns.
  static Future<WebTableResult> fetch(String url) async {
    final uri = Uri.parse(url);
    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json, text/csv, text/html, text/plain, */*',
        'User-Agent': 'AiGrid/1.0',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP GET failed with status ${response.statusCode}: ${response.reasonPhrase}');
    }

    final body = response.body.trim();
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';

    // 1. JSON Array or Object with nested array
    if (contentType.contains('application/json') || body.startsWith('[') || body.startsWith('{')) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is List) {
          return _parseJsonArray(decoded);
        } else if (decoded is Map) {
          // Look for common array wrappers
          for (final key in ['data', 'items', 'results', 'rows', 'records', 'users', 'posts']) {
            if (decoded[key] is List) {
              return _parseJsonArray(decoded[key] as List);
            }
          }
          // Single object
          return _parseJsonArray([decoded]);
        }
      } catch (_) {
        // Fallback to text parsing
      }
    }

    // 2. CSV / Delimited
    if (contentType.contains('text/csv') || contentType.contains('text/tab-separated-values')) {
      final res = DelimitedTableParser.parse(body);
      return WebTableResult(
        columns: res.columns,
        rows: res.rows,
        rawContent: body,
      );
    }

    // 3. HTML Table
    if (contentType.contains('text/html') || body.contains('<table')) {
      final htmlResult = _tryParseHtmlTable(body);
      if (htmlResult != null) return htmlResult;
    }

    // 4. Delimited fallback if multiple lines with commas
    if (body.contains('\n') && (body.contains(',') || body.contains('\t'))) {
      final res = DelimitedTableParser.parse(body);
      if (res.rows.isNotEmpty) {
        return WebTableResult(
          columns: res.columns,
          rows: res.rows,
          rawContent: body,
        );
      }
    }

    // Fallback: return raw content so LLM can extract
    return WebTableResult(
      columns: const [],
      rows: const [],
      rawContent: body,
    );
  }

  static WebTableResult _parseJsonArray(List list) {
    if (list.isEmpty) {
      return const WebTableResult(columns: [], rows: []);
    }

    final rows = <Map<String, dynamic>>[];
    final allKeys = <String>{};

    for (final item in list) {
      if (item is Map) {
        final flatMap = _flattenMap(Map<String, dynamic>.from(item));
        rows.add(flatMap);
        allKeys.addAll(flatMap.keys);
      }
    }

    final columns = <AiGridDynamicColumnModel>[];
    for (final key in allKeys) {
      final values = rows.map((r) => r[key]).toList();
      final detectedType = _inferType(values);

      columns.add(
        AiGridDynamicColumnModel(
          field: key,
          title: _formatTitle(key),
          type: detectedType,
          editable: false, // Web sources default to readonly
          numberFormat: detectedType == AiGridColumnType.currency
              ? '#,##0.00'
              : (detectedType == AiGridColumnType.number ? '#,##0.##' : null),
        ),
      );
    }

    return WebTableResult(
      columns: columns,
      rows: rows,
    );
  }

  static Map<String, dynamic> _flattenMap(Map<String, dynamic> map, [String prefix = '']) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      final newKey = prefix.isEmpty ? key : '${prefix}_$key';
      if (value is Map) {
        result.addAll(_flattenMap(Map<String, dynamic>.from(value), newKey));
      } else {
        result[newKey] = value;
      }
    });
    return result;
  }

  static WebTableResult? _tryParseHtmlTable(String html) {
    final tableRegex = RegExp(r'<table[^>]*>(.*?)<\/table>', dotAll: true, caseSensitive: false);
    final match = tableRegex.firstMatch(html);
    if (match == null) return null;

    final tableHtml = match.group(1)!;
    final rowRegex = RegExp(r'<tr[^>]*>(.*?)<\/tr>', dotAll: true, caseSensitive: false);
    final thRegex = RegExp(r'<th[^>]*>(.*?)<\/th>', dotAll: true, caseSensitive: false);
    final tdRegex = RegExp(r'<td[^>]*>(.*?)<\/td>', dotAll: true, caseSensitive: false);

    final rowMatches = rowRegex.allMatches(tableHtml).toList();
    if (rowMatches.isEmpty) return null;

    List<String> headers = [];
    int dataStart = 0;

    // Check if first row has <th>
    final firstRow = rowMatches.first.group(1)!;
    final firstThs = thRegex.allMatches(firstRow).map((m) => _stripTags(m.group(1)!)).toList();

    if (firstThs.isNotEmpty) {
      headers = firstThs;
      dataStart = 1;
    } else {
      // Use first row td as headers
      final firstTds = tdRegex.allMatches(firstRow).map((m) => _stripTags(m.group(1)!)).toList();
      headers = firstTds;
      dataStart = 1;
    }

    if (headers.isEmpty) return null;

    final rows = <Map<String, dynamic>>[];
    for (int i = dataStart; i < rowMatches.length; i++) {
      final rowHtml = rowMatches[i].group(1)!;
      final cells = tdRegex.allMatches(rowHtml).map((m) => _stripTags(m.group(1)!)).toList();
      if (cells.isEmpty) continue;

      final rowMap = <String, dynamic>{};
      for (int c = 0; c < headers.length; c++) {
        final key = _sanitizeField(headers[c], c);
        rowMap[key] = c < cells.length ? _parseValue(cells[c]) : '';
      }
      rows.add(rowMap);
    }

    if (rows.isEmpty) return null;

    final columns = <AiGridDynamicColumnModel>[];
    for (int c = 0; c < headers.length; c++) {
      final field = _sanitizeField(headers[c], c);
      final title = headers[c];
      final detectedType = _inferType(rows.map((r) => r[field]).toList());

      columns.add(
        AiGridDynamicColumnModel(
          field: field,
          title: title.isEmpty ? field : title,
          type: detectedType,
          editable: false, // Readonly
        ),
      );
    }

    return WebTableResult(
      columns: columns,
      rows: rows,
      rawContent: html,
    );
  }

  static String _stripTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  static String _formatTitle(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  static String _sanitizeField(String header, int index) {
    var field = header.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    while (field.contains('__')) {
      field = field.replaceAll('__', '_');
    }
    field = field.replaceAll(RegExp(r'^_+|_+$'), '');
    if (field.isEmpty) field = 'col_$index';
    return field;
  }

  static dynamic _parseValue(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    if (trimmed.toLowerCase() == 'true') return true;
    if (trimmed.toLowerCase() == 'false') return false;

    final numVal = num.tryParse(trimmed.replaceAll(',', ''));
    if (numVal != null) return numVal;

    return trimmed;
  }

  static AiGridColumnType _inferType(List<dynamic> values) {
    int numCount = 0;
    int boolCount = 0;
    int dateCount = 0;
    int validCount = 0;

    for (final v in values) {
      if (v == null || v.toString().trim().isEmpty) continue;
      validCount++;

      if (v is num) {
        numCount++;
      } else if (v is bool) {
        boolCount++;
      } else if (DateTime.tryParse(v.toString()) != null && v.toString().length >= 8) {
        dateCount++;
      }
    }

    if (validCount == 0) return AiGridColumnType.text;
    if (numCount / validCount > 0.8) return AiGridColumnType.number;
    if (boolCount / validCount > 0.8) return AiGridColumnType.boolean;
    if (dateCount / validCount > 0.8) return AiGridColumnType.date;

    return AiGridColumnType.text;
  }
}

class WebTableResult {
  final List<AiGridDynamicColumnModel> columns;
  final List<Map<String, dynamic>> rows;
  final String? rawContent;

  const WebTableResult({
    required this.columns,
    required this.rows,
    this.rawContent,
  });

  bool get hasTableData => columns.isNotEmpty && rows.isNotEmpty;
}
