import '../models/ai_grid_column.dart';
import '../models/ai_grid_dynamic_datasource.dart';

/// Extracts structured tabular rows and column definitions from Markdown content.
class MarkdownTableExtractor {
  /// Checks whether the markdown content contains at least one markdown pipe table.
  static bool containsTable(String markdown) => extractFirst(markdown) != null;

  /// Result of markdown table extraction containing columns and row maps.
  static MarkdownTableResult? extractFirst(String markdown) {
    final lines = markdown.split('\n');
    int startIdx = -1;

    for (int i = 0; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      final nextLine = lines[i + 1].trim();

      // Check for table header line and divider line (|---|---|)
      if (line.startsWith('|') &&
          line.endsWith('|') &&
          nextLine.startsWith('|') &&
          nextLine.endsWith('|') &&
          RegExp(r'^\|[\s\-:]+(\|[\s\-:]+)+\|$').hasMatch(nextLine)) {
        startIdx = i;
        break;
      }
    }

    if (startIdx == -1) return null;

    final headerLine = lines[startIdx].trim();
    final headers = _splitRow(headerLine);
    if (headers.isEmpty) return null;

    final rows = <Map<String, dynamic>>[];
    for (int i = startIdx + 2; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.startsWith('|') || !line.endsWith('|')) break;

      final cells = _splitRow(line);
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
          title: title,
          type: detectedType,
          editable: true,
          numberFormat: detectedType == AiGridColumnType.currency
              ? '#,##0.00'
              : (detectedType == AiGridColumnType.number ? '#,##0.##' : null),
        ),
      );
    }

    return MarkdownTableResult(
      columns: columns,
      rows: rows,
    );
  }

  static List<String> _splitRow(String line) {
    final stripped = line.substring(1, line.length - 1);
    return stripped.split('|').map((s) => s.trim()).toList();
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

    // Check bool
    if (trimmed.toLowerCase() == 'true') return true;
    if (trimmed.toLowerCase() == 'false') return false;

    // Check currency ($1,234.50 or €50.00)
    final currencyMatch = RegExp(r'^[\$\€\£\¥]\s*([\d,]+(?:\.\d+)?)$').firstMatch(trimmed);
    if (currencyMatch != null) {
      final clean = currencyMatch.group(1)!.replaceAll(',', '');
      final numVal = double.tryParse(clean);
      if (numVal != null) return numVal;
    }

    // Check int
    final intVal = int.tryParse(trimmed);
    if (intVal != null) return intVal;

    // Check double
    final dblVal = double.tryParse(trimmed.replaceAll(',', ''));
    if (dblVal != null && trimmed.contains('.')) return dblVal;

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

class MarkdownTableResult {
  final List<AiGridDynamicColumnModel> columns;
  final List<Map<String, dynamic>> rows;

  const MarkdownTableResult({
    required this.columns,
    required this.rows,
  });
}
