import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../models/ai_grid_column.dart';
import '../models/ai_grid_dynamic_datasource.dart';

/// Represents a single parsed worksheet inside an Excel (.xlsx) workbook.
class AiGridExcelSheet {
  /// Name of the worksheet (e.g. 'Quarterly Sales', 'Orders').
  final String name;

  /// Internal worksheet ID in workbook.xml.
  final int sheetId;

  /// Total number of data rows (excluding the header row).
  final int rowCount;

  /// Total number of columns.
  final int columnCount;

  /// List of raw header titles as found in row 1.
  final List<String> headers;

  /// First few sample rows (up to 5) for fast preview in sheet picker dialogs.
  final List<Map<String, dynamic>> previewRows;

  /// Inferred dynamic columns with field keys, titles, and detected types.
  final List<AiGridDynamicColumnModel> columns;

  /// Full parsed data rows as key-value maps.
  final List<Map<String, dynamic>> rows;

  const AiGridExcelSheet({
    required this.name,
    required this.sheetId,
    required this.rowCount,
    required this.columnCount,
    required this.headers,
    this.previewRows = const [],
    this.columns = const [],
    this.rows = const [],
  });

  @override
  String toString() =>
      'AiGridExcelSheet(name: "$name", rows: $rowCount, cols: $columnCount)';
}

/// Represents a parsed Excel (.xlsx) workbook containing one or more worksheets.
class AiGridExcelWorkbook {
  /// File name or source label of the workbook (e.g. "sales_report_2026.xlsx").
  final String fileName;

  /// Parsed worksheets inside the workbook.
  final List<AiGridExcelSheet> sheets;

  const AiGridExcelWorkbook({required this.fileName, required this.sheets});

  /// Returns true if this workbook contains more than one worksheet.
  bool get isMultiSheet => sheets.length > 1;

  /// Returns the first worksheet, or null if workbook has no sheets.
  AiGridExcelSheet? get primarySheet => sheets.isNotEmpty ? sheets.first : null;

  /// Finds a sheet by case-insensitive name match.
  AiGridExcelSheet? getSheet(String name) {
    final lower = name.toLowerCase().trim();
    for (final sheet in sheets) {
      if (sheet.name.toLowerCase().trim() == lower) {
        return sheet;
      }
    }
    return null;
  }
}

/// High-performance, pure-Dart OpenXML spreadsheet (.xlsx) parser.
///
/// Fully `dart2wasm` compatible with zero native dependencies or platform channels.
class AiGridExcelParser {
  /// Built-in ECMA-376 / OpenXML number format IDs representing dates and times.
  static const Set<int> _builtinDateNumFmtIds = {
    14, // m/d/yyyy
    15, // d-mmm-yy
    16, // d-mmm
    17, // mmm-yy
    18, // h:mm AM/PM
    19, // h:mm:ss AM/PM
    20, // h:mm
    21, // h:mm:ss
    22, // m/d/yyyy h:mm
    27, 28, 29, 30, 31, 32, 33, 34, 35, 36, // CJK date formats
    45, // mm:ss
    46, // [h]:mm:ss
    47, // mm:ss.0
  };

  /// Parses bytes of an `.xlsx` file into an [AiGridExcelWorkbook].
  static AiGridExcelWorkbook parseBytes(
    Uint8List bytes, {
    String fileName = 'workbook.xlsx',
  }) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final fileMap = <String, ArchiveFile>{};

    for (final file in archive) {
      var norm = file.name.replaceAll('\\', '/');
      if (norm.startsWith('/')) norm = norm.substring(1);
      fileMap[norm.toLowerCase()] = file;
    }

    // 1. Parse Shared Strings table (xl/sharedStrings.xml)
    final sharedStrings = _parseSharedStrings(fileMap);

    // 2. Parse Styles and determine which style indices represent dates (xl/styles.xml)
    final dateStyleIndices = _parseDateStyleIndices(fileMap);

    // 3. Resolve workbook relationships (xl/_rels/workbook.xml.rels)
    final rels = _parseWorkbookRels(fileMap);

    // 4. Parse workbook structure to get sheet definitions (xl/workbook.xml)
    final sheetInfos = _parseWorkbookSheets(fileMap, rels);

    final sheets = <AiGridExcelSheet>[];

    for (final info in sheetInfos) {
      final sheetFile = fileMap[info.targetPath.toLowerCase()];
      if (sheetFile == null) continue;

      final sheet = _parseWorksheet(
        name: info.name,
        sheetId: info.sheetId,
        xmlBytes: sheetFile.content as List<int>,
        sharedStrings: sharedStrings,
        dateStyleIndices: dateStyleIndices,
      );
      sheets.add(sheet);
    }

    // Fallback: If no sheets were found via workbook.xml, try loading any sheet*.xml in xl/worksheets/
    if (sheets.isEmpty) {
      int autoId = 1;
      for (final entry in fileMap.entries) {
        if (entry.key.startsWith('xl/worksheets/sheet') &&
            entry.key.endsWith('.xml')) {
          final sheet = _parseWorksheet(
            name: 'Sheet $autoId',
            sheetId: autoId,
            xmlBytes: entry.value.content as List<int>,
            sharedStrings: sharedStrings,
            dateStyleIndices: dateStyleIndices,
          );
          sheets.add(sheet);
          autoId++;
        }
      }
    }

    return AiGridExcelWorkbook(fileName: fileName, sheets: sheets);
  }

  /// Extracts shared strings list from xl/sharedstrings.xml.
  static List<String> _parseSharedStrings(Map<String, ArchiveFile> fileMap) {
    final file = fileMap['xl/sharedstrings.xml'];
    if (file == null) return const [];

    try {
      final xmlStr = utf8.decode(file.content as List<int>);
      final doc = XmlDocument.parse(xmlStr);
      final list = <String>[];

      for (final si in doc.findAllElements('si')) {
        // Collect all <t> nodes within <si> (including direct <t> and runs <r><t>)
        final sb = StringBuffer();
        for (final t in si.findAllElements('t')) {
          sb.write(t.innerText);
        }
        list.add(sb.toString());
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  /// Extracts style indices that format values as dates or times.
  static Set<int> _parseDateStyleIndices(Map<String, ArchiveFile> fileMap) {
    final file = fileMap['xl/styles.xml'];
    if (file == null) return const {};

    try {
      final xmlStr = utf8.decode(file.content as List<int>);
      final doc = XmlDocument.parse(xmlStr);

      final customDateNumFmtIds = <int>{};
      for (final numFmt in doc.findAllElements('numFmt')) {
        final idStr = numFmt.getAttribute('numFmtId');
        final code = numFmt.getAttribute('formatCode') ?? '';
        final id = int.tryParse(idStr ?? '');
        if (id != null && _isDateFormatCode(code)) {
          customDateNumFmtIds.add(id);
        }
      }

      final dateIndices = <int>{};
      int xfIndex = 0;
      final cellXfs = doc.findAllElements('cellXfs');
      if (cellXfs.isNotEmpty) {
        for (final xf in cellXfs.first.findElements('xf')) {
          final numFmtIdStr = xf.getAttribute('numFmtId');
          final numFmtId = int.tryParse(numFmtIdStr ?? '') ?? 0;
          if (_builtinDateNumFmtIds.contains(numFmtId) ||
              customDateNumFmtIds.contains(numFmtId)) {
            dateIndices.add(xfIndex);
          }
          xfIndex++;
        }
      }
      return dateIndices;
    } catch (_) {
      return const {};
    }
  }

  static bool _isDateFormatCode(String code) {
    final lower = code.toLowerCase();
    // Exclude currency, percentage, and pure numeric patterns
    if (lower.contains('\$') || lower.contains('€') || lower.contains('£')) {
      return false;
    }
    return lower.contains('yy') ||
        lower.contains('yyyy') ||
        lower.contains('mmm') ||
        (lower.contains('m/') ||
            lower.contains('/m') ||
            lower.contains('m-')) ||
        (lower.contains('d/') ||
            lower.contains('/d') ||
            lower.contains('d-')) ||
        (lower.contains('hh:') ||
            lower.contains(':mm') ||
            lower.contains(':ss'));
  }

  /// Resolves relationship IDs to worksheet target paths from xl/_rels/workbook.xml.rels.
  static Map<String, String> _parseWorkbookRels(
    Map<String, ArchiveFile> fileMap,
  ) {
    final file = fileMap['xl/_rels/workbook.xml.rels'];
    if (file == null) return const {};

    try {
      final xmlStr = utf8.decode(file.content as List<int>);
      final doc = XmlDocument.parse(xmlStr);
      final map = <String, String>{};

      for (final rel in doc.findAllElements('Relationship')) {
        final id = rel.getAttribute('Id');
        var target = rel.getAttribute('Target') ?? '';
        if (id != null && target.isNotEmpty) {
          target = target.replaceAll('\\', '/');
          if (!target.startsWith('xl/')) {
            if (target.startsWith('/')) {
              target = target.substring(1);
            } else {
              target = 'xl/$target';
            }
          }
          map[id] = target;
        }
      }
      return map;
    } catch (_) {
      return const {};
    }
  }

  /// Extracts sheet descriptors (name, sheetId, targetPath) from xl/workbook.xml.
  static List<_SheetInfo> _parseWorkbookSheets(
    Map<String, ArchiveFile> fileMap,
    Map<String, String> rels,
  ) {
    final file = fileMap['xl/workbook.xml'];
    if (file == null) return const [];

    try {
      final xmlStr = utf8.decode(file.content as List<int>);
      final doc = XmlDocument.parse(xmlStr);
      final list = <_SheetInfo>[];
      final usedNames = <String, int>{};

      for (final sheet in doc.findAllElements('sheet')) {
        var name = sheet.getAttribute('name') ?? 'Sheet';
        if (usedNames.containsKey(name)) {
          final count = usedNames[name]! + 1;
          usedNames[name] = count;
          name = '$name ($count)';
        } else {
          usedNames[name] = 1;
        }

        final sheetId = int.tryParse(sheet.getAttribute('sheetId') ?? '1') ?? 1;
        final rId =
            sheet.getAttribute('r:id') ?? sheet.getAttribute('id') ?? '';
        final targetPath = rels[rId] ?? 'xl/worksheets/sheet$sheetId.xml';

        list.add(
          _SheetInfo(name: name, sheetId: sheetId, targetPath: targetPath),
        );
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  /// Parses individual sheet XML into an [AiGridExcelSheet].
  static AiGridExcelSheet _parseWorksheet({
    required String name,
    required int sheetId,
    required List<int> xmlBytes,
    required List<String> sharedStrings,
    required Set<int> dateStyleIndices,
  }) {
    final xmlStr = utf8.decode(xmlBytes);
    final doc = XmlDocument.parse(xmlStr);

    final rawGrid = <int, Map<int, dynamic>>{};
    int maxCol = 0;

    for (final rowElem in doc.findAllElements('row')) {
      final rAttr = rowElem.getAttribute('r');
      final rowIndex = int.tryParse(rAttr ?? '') ?? (rawGrid.length + 1);

      final rowMap = <int, dynamic>{};
      int autoCol = 0;

      for (final cElem in rowElem.findElements('c')) {
        final cellRef = cElem.getAttribute('r');
        int colIndex;
        if (cellRef != null) {
          colIndex = _columnRefToIndex(cellRef);
        } else {
          colIndex = autoCol;
        }
        autoCol = colIndex + 1;
        if (colIndex > maxCol) maxCol = colIndex;

        final typeAttr = cElem.getAttribute('t');
        final styleAttr = cElem.getAttribute('s');
        final styleIndex = int.tryParse(styleAttr ?? '') ?? -1;

        final isDateStyle = dateStyleIndices.contains(styleIndex);
        final val = _decodeCellValue(
          cElem: cElem,
          typeAttr: typeAttr,
          sharedStrings: sharedStrings,
          isDateStyle: isDateStyle,
        );

        rowMap[colIndex] = val;
      }

      if (rowMap.isNotEmpty) {
        rawGrid[rowIndex] = rowMap;
      }
    }

    if (rawGrid.isEmpty) {
      return AiGridExcelSheet(
        name: name,
        sheetId: sheetId,
        rowCount: 0,
        columnCount: 0,
        headers: const [],
        previewRows: const [],
        columns: const [],
        rows: const [],
      );
    }

    // Sort rows by row index
    final sortedRowIndices = rawGrid.keys.toList()..sort();
    final headerRowIdx = sortedRowIndices.first;
    final headerMap = rawGrid[headerRowIdx]!;

    // Extract headers
    final headers = <String>[];
    for (int c = 0; c <= maxCol; c++) {
      final rawH = headerMap[c]?.toString().trim() ?? '';
      headers.add(
        rawH.isNotEmpty ? rawH : 'Column_${_indexToColumnLetters(c)}',
      );
    }

    // Build unique field keys
    final fieldKeys = <String>[];
    final usedFields = <String, int>{};
    for (int c = 0; c < headers.length; c++) {
      final rawField = _sanitizeField(headers[c], c);
      if (usedFields.containsKey(rawField)) {
        final count = usedFields[rawField]! + 1;
        usedFields[rawField] = count;
        fieldKeys.add('${rawField}_$count');
      } else {
        usedFields[rawField] = 1;
        fieldKeys.add(rawField);
      }
    }

    // Extract data rows
    final rows = <Map<String, dynamic>>[];
    for (int i = 1; i < sortedRowIndices.length; i++) {
      final rIdx = sortedRowIndices[i];
      final rowMap = rawGrid[rIdx] ?? {};
      final rowData = <String, dynamic>{};

      bool hasAnyValue = false;
      for (int c = 0; c < fieldKeys.length; c++) {
        final val = rowMap[c];
        if (val != null && val.toString().trim().isNotEmpty) {
          hasAnyValue = true;
        }
        rowData[fieldKeys[c]] = val ?? '';
      }

      if (hasAnyValue) {
        rows.add(rowData);
      }
    }

    // Infer column types & build AiGridDynamicColumnModel
    final columns = <AiGridDynamicColumnModel>[];
    for (int c = 0; c < fieldKeys.length; c++) {
      final field = fieldKeys[c];
      final title = headers[c];
      final colValues = rows.map((r) => r[field]).toList();
      final detectedType = _inferType(colValues);

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

    final previewRows = rows.take(5).toList();

    return AiGridExcelSheet(
      name: name,
      sheetId: sheetId,
      rowCount: rows.length,
      columnCount: columns.length,
      headers: headers,
      previewRows: previewRows,
      columns: columns,
      rows: rows,
    );
  }

  static dynamic _decodeCellValue({
    required XmlElement cElem,
    required String? typeAttr,
    required List<String> sharedStrings,
    required bool isDateStyle,
  }) {
    if (typeAttr == 'inlineStr') {
      final isElem = cElem.findElements('is').firstOrNull;
      if (isElem != null) {
        return isElem.findAllElements('t').map((e) => e.innerText).join();
      }
      return '';
    }

    final vElem = cElem.findElements('v').firstOrNull;
    final rawText = vElem?.innerText.trim() ?? '';

    if (typeAttr == 's') {
      final sIndex = int.tryParse(rawText);
      if (sIndex != null && sIndex >= 0 && sIndex < sharedStrings.length) {
        return sharedStrings[sIndex];
      }
      return rawText;
    }

    if (typeAttr == 'b') {
      return rawText == '1' || rawText.toLowerCase() == 'true';
    }

    if (typeAttr == 'str') {
      return rawText;
    }

    if (typeAttr == 'e') {
      return rawText; // Error code, e.g. #N/A, #REF!
    }

    // Default numeric/date evaluation
    if (rawText.isNotEmpty) {
      final numVal = num.tryParse(rawText);
      if (numVal != null) {
        if (isDateStyle) {
          final dt = _excelSerialToDateTime(numVal);
          if (dt != null) {
            // If whole day without time component
            if (numVal == numVal.truncateToDouble()) {
              final y = dt.year.toString().padLeft(4, '0');
              final m = dt.month.toString().padLeft(2, '0');
              final d = dt.day.toString().padLeft(2, '0');
              return '$y-$m-$d';
            } else {
              return dt
                  .toIso8601String()
                  .replaceFirst('T', ' ')
                  .substring(0, 19);
            }
          }
        }
        if (numVal is int ||
            (numVal == numVal.toInt() && !rawText.contains('.'))) {
          return numVal.toInt();
        }
        return numVal.toDouble();
      }
    }

    return rawText;
  }

  /// Converts Excel 1900 date serial number to [DateTime].
  ///
  /// Accounts for the historic Lotus 1-2-3 leap year bug where 1900 is treated
  /// as a leap year (day 60 = 1900-02-29).
  static DateTime? _excelSerialToDateTime(num serial) {
    if (serial <= 0) return null;
    // Lotus 1-2-3 leap year correction: serial > 60 includes non-existent Feb 29, 1900
    final days = serial > 60 ? serial - 1 : serial;
    final ms = (days * 86400000).round();
    // Excel Day 1 is 1900-01-01, so base is 1899-12-31 UTC
    final base = DateTime.utc(1899, 12, 31);
    return base.add(Duration(milliseconds: ms));
  }

  /// Converts cell coordinate (e.g. "AB12") to 0-based column index.
  static int _columnRefToIndex(String cellRef) {
    final letters = cellRef.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    if (letters.isEmpty) return 0;
    int index = 0;
    for (int i = 0; i < letters.length; i++) {
      index = index * 26 + (letters.codeUnitAt(i) - 64);
    }
    return index - 1;
  }

  /// Converts 0-based column index to Excel column letters (0 -> "A", 25 -> "Z", 26 -> "AA").
  static String _indexToColumnLetters(int index) {
    int col = index + 1;
    final sb = StringBuffer();
    while (col > 0) {
      final rem = (col - 1) % 26;
      sb.writeCharCode(65 + rem);
      col = (col - 1) ~/ 26;
    }
    return sb.toString().split('').reversed.join();
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

  static AiGridColumnType _inferType(List<dynamic> values) {
    int numCount = 0;
    int currencyCount = 0;
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
      } else {
        final str = v.toString().trim();
        if (RegExp(r'^[\$\€\£\¥]\s*[\d,]+(\.\d+)?$').hasMatch(str)) {
          currencyCount++;
        } else if (DateTime.tryParse(str) != null && str.length >= 8) {
          dateCount++;
        } else if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(str)) {
          dateCount++;
        } else if (num.tryParse(str.replaceAll(',', '')) != null) {
          numCount++;
        }
      }
    }

    if (validCount == 0) return AiGridColumnType.text;
    if (currencyCount / validCount > 0.7) return AiGridColumnType.currency;
    if (numCount / validCount > 0.8) return AiGridColumnType.number;
    if (boolCount / validCount > 0.8) return AiGridColumnType.boolean;
    if (dateCount / validCount > 0.8) return AiGridColumnType.date;

    return AiGridColumnType.text;
  }

  /// Synthesizes a sample multi-sheet Excel (.xlsx) workbook in pure Dart for testing and demos.
  static Uint8List createSampleMultiSheetWorkbookBytes() {
    final sheet1Xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1">
      <c r="A1" t="s"><v>0</v></c>
      <c r="B1" t="s"><v>1</v></c>
      <c r="C1" t="s"><v>2</v></c>
      <c r="D1" t="s"><v>3</v></c>
      <c r="E1" t="s"><v>4</v></c>
      <c r="F1" t="s"><v>5</v></c>
      <c r="G1" t="s"><v>6</v></c>
      <c r="H1" t="s"><v>7</v></c>
    </row>
    <row r="2">
      <c r="A2" t="s"><v>8</v></c>
      <c r="B2" t="s"><v>12</v></c>
      <c r="C2" t="s"><v>16</v></c>
      <c r="D2"><v>142500.0</v></c>
      <c r="E2"><v>158900.0</v></c>
      <c r="F2"><v>164200.0</v></c>
      <c r="G2"><v>189400.0</v></c>
      <c r="H2"><v>650000.0</v></c>
    </row>
    <row r="3">
      <c r="A3" t="s"><v>8</v></c>
      <c r="B3" t="s"><v>13</v></c>
      <c r="C3" t="s"><v>17</v></c>
      <c r="D3"><v>98400.0</v></c>
      <c r="E3"><v>104200.0</v></c>
      <c r="F3"><v>112000.0</v></c>
      <c r="G3"><v>128600.0</v></c>
      <c r="H3"><v>440000.0</v></c>
    </row>
    <row r="4">
      <c r="A4" t="s"><v>9</v></c>
      <c r="B4" t="s"><v>12</v></c>
      <c r="C4" t="s"><v>18</v></c>
      <c r="D4"><v>184000.0</v></c>
      <c r="E4"><v>192500.0</v></c>
      <c r="F4"><v>210400.0</v></c>
      <c r="G4"><v>245000.0</v></c>
      <c r="H4"><v>820000.0</v></c>
    </row>
    <row r="5">
      <c r="A5" t="s"><v>9</v></c>
      <c r="B5" t="s"><v>14</v></c>
      <c r="C5" t="s"><v>19</v></c>
      <c r="D5"><v>76200.0</v></c>
      <c r="E5"><v>81400.0</v></c>
      <c r="F5"><v>89500.0</v></c>
      <c r="G5"><v>99800.0</v></c>
      <c r="H5"><v>350000.0</v></c>
    </row>
    <row r="6">
      <c r="A6" t="s"><v>10</v></c>
      <c r="B6" t="s"><v>12</v></c>
      <c r="C6" t="s"><v>20</v></c>
      <c r="D6"><v>210500.0</v></c>
      <c r="E6"><v>228400.0</v></c>
      <c r="F6"><v>245000.0</v></c>
      <c r="G6"><v>290000.0</v></c>
      <c r="H6"><v>950000.0</v></c>
    </row>
    <row r="7">
      <c r="A7" t="s"><v>10</v></c>
      <c r="B7" t="s"><v>15</v></c>
      <c r="C7" t="s"><v>21</v></c>
      <c r="D7"><v>64200.0</v></c>
      <c r="E7"><v>71000.0</v></c>
      <c r="F7"><v>78400.0</v></c>
      <c r="G7"><v>89200.0</v></c>
      <c r="H7"><v>300000.0</v></c>
    </row>
    <row r="8">
      <c r="A8" t="s"><v>11</v></c>
      <c r="B8" t="s"><v>12</v></c>
      <c r="C8" t="s"><v>16</v></c>
      <c r="D8"><v>88500.0</v></c>
      <c r="E8"><v>94200.0</v></c>
      <c r="F8"><v>102000.0</v></c>
      <c r="G8"><v>118400.0</v></c>
      <c r="H8"><v>400000.0</v></c>
    </row>
  </sheetData>
</worksheet>''';

    final sheet2Xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1">
      <c r="A1" t="s"><v>8</v></c>
      <c r="B1" t="s"><v>22</v></c>
      <c r="C1" t="s"><v>23</v></c>
      <c r="D1" t="s"><v>24</v></c>
      <c r="E1" t="s"><v>25</v></c>
    </row>
    <row r="2">
      <c r="A2" t="s"><v>8</v></c>
      <c r="B2" t="s"><v>26</v></c>
      <c r="C2"><v>500000.0</v></c>
      <c r="D2"><v>108.5</v></c>
      <c r="E2" t="s"><v>30</v></c>
    </row>
    <row r="3">
      <c r="A3" t="s"><v>9</v></c>
      <c r="B3" t="s"><v>27</v></c>
      <c r="C3"><v>650000.0</v></c>
      <c r="D3"><v>115.2</v></c>
      <c r="E3" t="s"><v>30</v></c>
    </row>
    <row r="4">
      <c r="A4" t="s"><v>10</v></c>
      <c r="B4" t="s"><v>28</v></c>
      <c r="C4"><v>750000.0</v></c>
      <c r="D4"><v>122.8</v></c>
      <c r="E4" t="s"><v>30</v></c>
    </row>
    <row r="5">
      <c r="A5" t="s"><v>11</v></c>
      <c r="B5" t="s"><v>29</v></c>
      <c r="C5"><v>350000.0</v></c>
      <c r="D5"><v>94.6</v></c>
      <c r="E5" t="s"><v>31</v></c>
    </row>
  </sheetData>
</worksheet>''';

    final sheet3Xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1">
      <c r="A1" t="s"><v>1</v></c>
      <c r="B1" t="s"><v>32</v></c>
      <c r="C1" t="s"><v>33</v></c>
      <c r="D1" t="s"><v>34</v></c>
    </row>
    <row r="2">
      <c r="A2" t="s"><v>12</v></c>
      <c r="B2"><v>1200.0</v></c>
      <c r="C2"><v>650.0</v></c>
      <c r="D2"><v>45.8</v></c>
    </row>
    <row r="3">
      <c r="A3" t="s"><v>13</v></c>
      <c r="B3"><v>450.0</v></c>
      <c r="C3"><v>280.0</v></c>
      <c r="D3"><v>37.7</v></c>
    </row>
    <row r="4">
      <c r="A4" t="s"><v>14</v></c>
      <c r="B4"><v>120.0</v></c>
      <c r="C4"><v>55.0</v></c>
      <c r="D4"><v>54.2</v></c>
    </row>
    <row r="5">
      <c r="A5" t="s"><v>15</v></c>
      <c r="B5"><v>85.0</v></c>
      <c r="C5"><v>35.0</v></c>
      <c r="D5"><v>58.8</v></c>
    </row>
  </sheetData>
</worksheet>''';

    final sharedStrings = [
      'Region',
      'Category',
      'SubCategory',
      'Q1 Sales',
      'Q2 Sales',
      'Q3 Sales',
      'Q4 Sales',
      'Annual Target',
      'North America',
      'EMEA',
      'APAC',
      'LATAM',
      'Technology',
      'Furniture',
      'Office Supplies',
      'Accessories',
      'Laptops & PCs',
      'Ergonomic Chairs',
      'Enterprise Servers',
      'Desk Organizers',
      'Mobile Phones',
      'Wireless Headsets',
      'Sales Director',
      'Annual Quota',
      'Attainment %',
      'Quota Status',
      'Sarah Jenkins',
      'Marcus Vance',
      'Aiko Tanaka',
      'Carlos Ruiz',
      'Exceeded',
      'On Track',
      'Avg Selling Price',
      'Unit Manufacturing Cost',
      'Gross Margin %',
    ];

    final sharedStringsXml = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'count="${sharedStrings.length}" uniqueCount="${sharedStrings.length}">',
    );
    for (final str in sharedStrings) {
      sharedStringsXml.write('<si><t>$str</t></si>');
    }
    sharedStringsXml.write('</sst>');

    final workbookXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Quarterly Revenue" sheetId="1" r:id="rId1"/>
    <sheet name="Regional Quotas" sheetId="2" r:id="rId2"/>
    <sheet name="Product Margins" sheetId="3" r:id="rId3"/>
  </sheets>
</workbook>''';

    final relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet3.xml"/>
</Relationships>''';

    final stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <cellXfs count="1"><xf numFmtId="0"/></cellXfs>
</styleSheet>''';

    final archive = Archive();
    archive.addFile(
      ArchiveFile(
        'xl/workbook.xml',
        workbookXml.length,
        utf8.encode(workbookXml),
      ),
    );
    archive.addFile(
      ArchiveFile(
        'xl/_rels/workbook.xml.rels',
        relsXml.length,
        utf8.encode(relsXml),
      ),
    );
    archive.addFile(
      ArchiveFile(
        'xl/sharedstrings.xml',
        sharedStringsXml.toString().length,
        utf8.encode(sharedStringsXml.toString()),
      ),
    );
    archive.addFile(
      ArchiveFile('xl/styles.xml', stylesXml.length, utf8.encode(stylesXml)),
    );
    archive.addFile(
      ArchiveFile(
        'xl/worksheets/sheet1.xml',
        sheet1Xml.length,
        utf8.encode(sheet1Xml),
      ),
    );
    archive.addFile(
      ArchiveFile(
        'xl/worksheets/sheet2.xml',
        sheet2Xml.length,
        utf8.encode(sheet2Xml),
      ),
    );
    archive.addFile(
      ArchiveFile(
        'xl/worksheets/sheet3.xml',
        sheet3Xml.length,
        utf8.encode(sheet3Xml),
      ),
    );

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }
}

class _SheetInfo {
  final String name;
  final int sheetId;
  final String targetPath;

  const _SheetInfo({
    required this.name,
    required this.sheetId,
    required this.targetPath,
  });
}
