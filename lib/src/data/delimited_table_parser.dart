import '../models/ai_grid_column.dart';
import '../models/ai_grid_dynamic_datasource.dart';

/// Parses delimited text (CSV, TSV, semicolon-separated) into dynamic columns and rows.
class DelimitedTableParser {
  static DelimitedTableResult parse(String content, {String? delimiter}) {
    final text = content.trim();
    if (text.isEmpty) {
      return const DelimitedTableResult(columns: [], rows: []);
    }

    // Auto-detect delimiter if not specified
    final delim = delimiter ?? _detectDelimiter(text);
    final rawLines = _splitCsvLines(text);
    if (rawLines.isEmpty) {
      return const DelimitedTableResult(columns: [], rows: []);
    }

    final headerTokens = _parseCsvLine(rawLines[0], delim);
    final headers = headerTokens.map((h) => h.trim()).toList();

    final rows = <Map<String, dynamic>>[];
    for (int i = 1; i < rawLines.length; i++) {
      final line = rawLines[i].trim();
      if (line.isEmpty) continue;
      final tokens = _parseCsvLine(line, delim);
      final rowMap = <String, dynamic>{};
      for (int c = 0; c < headers.length; c++) {
        final key = _sanitizeField(headers[c], c);
        final rawVal = c < tokens.length ? tokens[c] : '';
        rowMap[key] = _parseValue(rawVal);
      }
      rows.add(rowMap);
    }

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
          editable: true,
          numberFormat: detectedType == AiGridColumnType.currency
              ? '#,##0.00'
              : (detectedType == AiGridColumnType.number ? '#,##0.##' : null),
        ),
      );
    }

    return DelimitedTableResult(columns: columns, rows: rows);
  }

  static String _detectDelimiter(String text) {
    final firstLine = text.split('\n').first;
    int commaCount = 0;
    int tabCount = 0;
    int semiCount = 0;

    for (int i = 0; i < firstLine.length; i++) {
      final char = firstLine[i];
      if (char == ',') commaCount++;
      if (char == '\t') tabCount++;
      if (char == ';') semiCount++;
    }

    if (tabCount > commaCount && tabCount > semiCount) return '\t';
    if (semiCount > commaCount && semiCount > tabCount) return ';';
    return ',';
  }

  static List<String> _splitCsvLines(String text) {
    final lines = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '"') {
        inQuotes = !inQuotes;
        sb.write(char);
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
          i++; // Skip \n
        }
        lines.add(sb.toString());
        sb.clear();
      } else {
        sb.write(char);
      }
    }
    if (sb.isNotEmpty) lines.add(sb.toString());
    return lines;
  }

  static List<String> _parseCsvLine(String line, String delim) {
    final tokens = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++; // Skip escaped quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == delim && !inQuotes) {
        tokens.add(sb.toString().trim());
        sb.clear();
      } else {
        sb.write(char);
      }
    }
    tokens.add(sb.toString().trim());
    return tokens;
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

    final currencyMatch = RegExp(r'^[\$\€\£\¥]\s*([\d,]+(?:\.\d+)?)$').firstMatch(trimmed);
    if (currencyMatch != null) {
      final clean = currencyMatch.group(1)!.replaceAll(',', '');
      final numVal = double.tryParse(clean);
      if (numVal != null) return numVal;
    }

    final intVal = int.tryParse(trimmed);
    if (intVal != null) return intVal;

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

class DelimitedTableResult {
  final List<AiGridDynamicColumnModel> columns;
  final List<Map<String, dynamic>> rows;

  const DelimitedTableResult({
    required this.columns,
    required this.rows,
  });
}
