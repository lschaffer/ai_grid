import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../models/ai_grid_column.dart';
import '../models/ai_grid_data_auditor.dart';

/// Engine for auditing tabular data health, detecting anomalies,
/// and executing automated data cleaning transformations.
class AiGridDataCleaner {
  /// Analyzes tabular data and returns an [AiGridAuditReport].
  static AiGridAuditReport audit({
    required List<Map<String, dynamic>> rows,
    required List<AiGridColumn> columns,
  }) {
    if (rows.isEmpty) {
      return const AiGridAuditReport(
        overallScore: 100,
        totalRows: 0,
        totalColumns: 0,
        issues: [],
      );
    }

    final issues = <AiGridAuditIssue>[];
    final activeColumns = columns
        .where((c) => !c.field.startsWith('__'))
        .toList();

    // 1. Duplicate Rows Detection
    final duplicateIndices = _findDuplicateRowIndices(rows, activeColumns);
    if (duplicateIndices.isNotEmpty) {
      final sample = duplicateIndices.take(3).map((idx) => rows[idx]).toList();
      issues.add(
        AiGridAuditIssue(
          id: 'duplicate_rows',
          type: AiGridAuditIssueType.duplicates,
          severity: duplicateIndices.length > (rows.length * 0.1)
              ? AiGridAuditSeverity.critical
              : AiGridAuditSeverity.warning,
          title: '${duplicateIndices.length} Duplicate Records',
          description:
              'Found ${duplicateIndices.length} duplicate rows with identical field values.',
          affectedCount: duplicateIndices.length,
          affectedRowIndices: duplicateIndices,
          sampleValues: sample,
          remediation: const AiGridAuditRemediation(
            action: AiGridCleanseAction.removeDuplicates,
            label: 'Remove Duplicate Rows',
            description: 'De-duplicates dataset, retaining the first occurrence of each unique record.',
          ),
        ),
      );
    }

    // 2. Column-by-Column Diagnostics
    for (final col in activeColumns) {
      final field = col.field;
      final values = rows.map((r) => r[field]).toList();

      // a. Missing / Null Values
      final missingIndices = <int>[];
      for (int i = 0; i < values.length; i++) {
        if (_isMissing(values[i])) {
          missingIndices.add(i);
        }
      }

      if (missingIndices.isNotEmpty) {
        final pct = (missingIndices.length / rows.length) * 100;
        final isNumeric = _isNumericColumn(col, values);
        issues.add(
          AiGridAuditIssue(
            id: 'missing_$field',
            type: AiGridAuditIssueType.missingValues,
            severity: pct > 25
                ? AiGridAuditSeverity.critical
                : (pct > 5
                      ? AiGridAuditSeverity.warning
                      : AiGridAuditSeverity.info),
            title: '${missingIndices.length} Missing Values in "${col.title}"',
            description:
                '${missingIndices.length} rows (${pct.toStringAsFixed(1)}%) have empty or null values in column "${col.title}".',
            columnField: field,
            affectedCount: missingIndices.length,
            affectedRowIndices: missingIndices,
            remediation: AiGridAuditRemediation(
              action: AiGridCleanseAction.imputeMissing,
              label: isNumeric ? 'Impute with Median' : 'Impute with Mode',
              description: isNumeric
                  ? 'Fills missing values with the column statistical median.'
                  : 'Fills missing values with the most frequent category.',
              field: field,
              imputeStrategy: isNumeric
                  ? AiGridImputeStrategy.median
                  : AiGridImputeStrategy.mode,
            ),
          ),
        );
      }

      // b. Dirty Numbers Detection
      final isNumeric = _isNumericColumn(col, values);
      if (isNumeric) {
        final dirtyIndices = <int>[];
        final sampleDirty = <dynamic>[];
        for (int i = 0; i < values.length; i++) {
          final v = values[i];
          if (_isMissing(v)) continue;
          if (v is! num && _isDirtyNumber(v)) {
            dirtyIndices.add(i);
            if (sampleDirty.length < 3) sampleDirty.add(v);
          }
        }

        if (dirtyIndices.isNotEmpty) {
          issues.add(
            AiGridAuditIssue(
              id: 'dirty_numbers_$field',
              type: AiGridAuditIssueType.dirtyNumbers,
              severity: AiGridAuditSeverity.warning,
              title: 'Dirty Number Formats in "${col.title}"',
              description:
                  'Found ${dirtyIndices.length} string entries with currency symbols, commas, or text markers in numeric column "${col.title}".',
              columnField: field,
              affectedCount: dirtyIndices.length,
              affectedRowIndices: dirtyIndices,
              sampleValues: sampleDirty,
              remediation: AiGridAuditRemediation(
                action: AiGridCleanseAction.cleanNumbers,
                label: 'Parse & Normalize Numbers',
                description: 'Strips currency symbols, commas, and normalizes dirty string numbers to exact numeric values.',
                field: field,
              ),
            ),
          );
        }

        // c. Statistical Outliers (IQR Method)
        final numValues = <num>[];
        final numIndexMap = <int, num>{};
        for (int i = 0; i < values.length; i++) {
          final parsed = _parseCleanNumber(values[i]);
          if (parsed != null) {
            numValues.add(parsed);
            numIndexMap[i] = parsed;
          }
        }

        if (numValues.length >= 8) {
          final sorted = List<num>.from(numValues)..sort();
          final q1 = _percentile(sorted, 0.25);
          final q3 = _percentile(sorted, 0.75);
          final iqr = q3 - q1;

          if (iqr > 0) {
            final lowerFence = q1 - 1.5 * iqr;
            final upperFence = q3 + 1.5 * iqr;

            final outlierIndices = <int>[];
            final outlierSamples = <dynamic>[];

            for (final entry in numIndexMap.entries) {
              if (entry.value < lowerFence || entry.value > upperFence) {
                outlierIndices.add(entry.key);
                if (outlierSamples.length < 3) outlierSamples.add(entry.value);
              }
            }

            if (outlierIndices.isNotEmpty) {
              issues.add(
                AiGridAuditIssue(
                  id: 'outliers_$field',
                  type: AiGridAuditIssueType.outliers,
                  severity: AiGridAuditSeverity.info,
                  title: '${outlierIndices.length} Outliers in "${col.title}"',
                  description:
                      'Detected ${outlierIndices.length} values outside expected statistical range [${_formatCompactNum(lowerFence)}, ${_formatCompactNum(upperFence)}].',
                  columnField: field,
                  affectedCount: outlierIndices.length,
                  affectedRowIndices: outlierIndices,
                  sampleValues: outlierSamples,
                  remediation: AiGridAuditRemediation(
                    action: AiGridCleanseAction.capOutliers,
                    label: 'Cap Outliers to Statistical Fences',
                    description:
                        'Applies Winsorization, capping extreme values to [${_formatCompactNum(lowerFence)}, ${_formatCompactNum(upperFence)}].',
                    field: field,
                  ),
                ),
              );
            }
          }
        }
      }

      // d. Inconsistent Date Formats
      final isDate = _isDateColumn(col, values);
      if (isDate) {
        final mixedDateIndices = <int>[];
        final sampleDates = <dynamic>[];

        for (int i = 0; i < values.length; i++) {
          final v = values[i];
          if (_isMissing(v)) continue;
          final str = v.toString().trim();
          if (!_isStandardIsoDate(str) && _tryParseAnyDate(str) != null) {
            mixedDateIndices.add(i);
            if (sampleDates.length < 3) sampleDates.add(str);
          }
        }

        if (mixedDateIndices.isNotEmpty) {
          issues.add(
            AiGridAuditIssue(
              id: 'mixed_dates_$field',
              type: AiGridAuditIssueType.mixedDates,
              severity: AiGridAuditSeverity.warning,
              title: 'Mixed Date Formats in "${col.title}"',
              description:
                  'Found ${mixedDateIndices.length} date strings using non-standard or localized formats. Standardize to YYYY-MM-DD.',
              columnField: field,
              affectedCount: mixedDateIndices.length,
              affectedRowIndices: mixedDateIndices,
              sampleValues: sampleDates,
              remediation: AiGridAuditRemediation(
                action: AiGridCleanseAction.standardizeDates,
                label: 'Standardize to YYYY-MM-DD',
                description: 'Converts non-standard dates (e.g. "03/15/2026", "15-03-2026", "March 15, 2026") into ISO YYYY-MM-DD format.',
                field: field,
              ),
            ),
          );
        }
      }

      // e. Leading / Trailing Whitespace
      final whitespaceIndices = <int>[];
      final sampleWs = <dynamic>[];
      for (int i = 0; i < values.length; i++) {
        final v = values[i];
        if (v is String && v != v.trim()) {
          whitespaceIndices.add(i);
          if (sampleWs.length < 3) sampleWs.add(v);
        }
      }

      if (whitespaceIndices.isNotEmpty) {
        issues.add(
          AiGridAuditIssue(
            id: 'whitespace_$field',
            type: AiGridAuditIssueType.inconsistentWhitespace,
            severity: AiGridAuditSeverity.info,
            title: 'Whitespace Anomalies in "${col.title}"',
            description:
                'Found ${whitespaceIndices.length} entries with untrimmed leading or trailing whitespace.',
            columnField: field,
            affectedCount: whitespaceIndices.length,
            affectedRowIndices: whitespaceIndices,
            sampleValues: sampleWs,
            remediation: AiGridAuditRemediation(
              action: AiGridCleanseAction.trimWhitespace,
              label: 'Trim Extra Spaces',
              description:
                  'Strips leading and trailing spaces from text values.',
              field: field,
            ),
          ),
        );
      }
    }

    // 3. Compute Health Score
    int penalty = 0;
    for (final issue in issues) {
      switch (issue.severity) {
        case AiGridAuditSeverity.critical:
          penalty += 15;
          break;
        case AiGridAuditSeverity.warning:
          penalty += 8;
          break;
        case AiGridAuditSeverity.info:
          penalty += 3;
          break;
      }
    }
    final overallScore = math.max(0, 100 - penalty);

    return AiGridAuditReport(
      overallScore: overallScore,
      totalRows: rows.length,
      totalColumns: activeColumns.length,
      issues: issues,
    );
  }

  /// Applies a specific [remediation] action across [rows] and returns the cleansed dataset.
  static List<Map<String, dynamic>> applyRemediation({
    required List<Map<String, dynamic>> rows,
    required AiGridAuditRemediation remediation,
    List<AiGridColumn>? columns,
  }) {
    switch (remediation.action) {
      case AiGridCleanseAction.removeDuplicates:
        return removeDuplicates(rows);

      case AiGridCleanseAction.trimWhitespace:
        return trimWhitespace(rows, field: remediation.field);

      case AiGridCleanseAction.standardizeDates:
        if (remediation.field == null) return rows;
        return standardizeDates(rows, field: remediation.field!);

      case AiGridCleanseAction.cleanNumbers:
        if (remediation.field == null) return rows;
        return cleanNumbers(rows, field: remediation.field!);

      case AiGridCleanseAction.imputeMissing:
        if (remediation.field == null) return rows;
        return imputeMissingValues(
          rows,
          field: remediation.field!,
          strategy: remediation.imputeStrategy ?? AiGridImputeStrategy.median,
          constantValue: remediation.constantValue,
        );

      case AiGridCleanseAction.capOutliers:
        if (remediation.field == null) return rows;
        return capOutliers(rows, field: remediation.field!);

      case AiGridCleanseAction.cleanAll:
        return cleanAll(rows, columns: columns ?? const []);
    }
  }

  /// Removes exact duplicate rows, keeping the first occurrence.
  static List<Map<String, dynamic>> removeDuplicates(
    List<Map<String, dynamic>> rows,
  ) {
    final seen = <String>{};
    final cleaned = <Map<String, dynamic>>[];

    for (final row in rows) {
      final key = _rowSignature(row);
      if (seen.add(key)) {
        cleaned.add(Map<String, dynamic>.from(row));
      }
    }
    return cleaned;
  }

  /// Trims leading and trailing whitespace from strings in specified [field] or all string fields.
  static List<Map<String, dynamic>> trimWhitespace(
    List<Map<String, dynamic>> rows, {
    String? field,
  }) {
    return rows.map((r) {
      final copy = Map<String, dynamic>.from(r);
      if (field != null) {
        final val = copy[field];
        if (val is String) copy[field] = val.trim();
      } else {
        for (final k in copy.keys) {
          final val = copy[k];
          if (val is String) copy[k] = val.trim();
        }
      }
      return copy;
    }).toList();
  }

  /// Normalizes dirty string numbers (currency symbols, commas, text markers) to real numbers.
  static List<Map<String, dynamic>> cleanNumbers(
    List<Map<String, dynamic>> rows, {
    required String field,
  }) {
    return rows.map((r) {
      final copy = Map<String, dynamic>.from(r);
      final raw = copy[field];
      if (raw != null) {
        final cleaned = _parseCleanNumber(raw);
        if (cleaned != null) {
          copy[field] = cleaned;
        } else if (_isMissing(raw) || _isDirtyNumber(raw)) {
          copy[field] = null;
        }
      }
      return copy;
    }).toList();
  }

  /// Standardizes mixed date strings into clean ISO YYYY-MM-DD strings.
  static List<Map<String, dynamic>> standardizeDates(
    List<Map<String, dynamic>> rows, {
    required String field,
    String targetFormat = 'yyyy-MM-dd',
  }) {
    final formatter = DateFormat(targetFormat);

    return rows.map((r) {
      final copy = Map<String, dynamic>.from(r);
      final raw = copy[field];
      if (raw != null) {
        final dt = _tryParseAnyDate(raw.toString().trim());
        if (dt != null) {
          copy[field] = formatter.format(dt);
        }
      }
      return copy;
    }).toList();
  }

  /// Imputes missing/null values in [field] using the given [strategy].
  static List<Map<String, dynamic>> imputeMissingValues(
    List<Map<String, dynamic>> rows, {
    required String field,
    required AiGridImputeStrategy strategy,
    dynamic constantValue,
  }) {
    dynamic fillValue;

    if (strategy == AiGridImputeStrategy.zero) {
      fillValue = 0;
    } else if (strategy == AiGridImputeStrategy.empty) {
      fillValue = '';
    } else if (strategy == AiGridImputeStrategy.constant) {
      fillValue = constantValue ?? '';
    } else {
      final validValues = rows
          .map((r) => r[field])
          .where((v) => !_isMissing(v))
          .toList();

      if (strategy == AiGridImputeStrategy.mode) {
        final freq = <dynamic, int>{};
        for (final v in validValues) {
          freq[v] = (freq[v] ?? 0) + 1;
        }
        fillValue = freq.entries.isEmpty
            ? ''
            : freq.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      } else {
        // Numeric mean / median
        final numValues = validValues
            .map((v) => _parseCleanNumber(v))
            .whereType<num>()
            .toList();

        if (numValues.isNotEmpty) {
          if (strategy == AiGridImputeStrategy.mean) {
            final sum = numValues.reduce((a, b) => a + b);
            final mean = sum / numValues.length;
            fillValue = (mean == mean.truncateToDouble())
                ? mean.toInt()
                : (mean * 100).round() / 100;
          } else if (strategy == AiGridImputeStrategy.median) {
            final med = _percentile(numValues..sort(), 0.50);
            fillValue = (med == med.truncateToDouble())
                ? med.toInt()
                : (med * 100).round() / 100;
          }
        } else {
          fillValue = 0;
        }
      }
    }

    return rows.map((r) {
      final copy = Map<String, dynamic>.from(r);
      if (_isMissing(copy[field])) {
        copy[field] = fillValue;
      }
      return copy;
    }).toList();
  }

  /// Winsorizes / caps outliers in [field] to lower and upper 1.5 * IQR fences.
  static List<Map<String, dynamic>> capOutliers(
    List<Map<String, dynamic>> rows, {
    required String field,
  }) {
    final numValues = rows
        .map((r) => _parseCleanNumber(r[field]))
        .whereType<num>()
        .toList();

    if (numValues.length < 8) return rows;

    final sorted = List<num>.from(numValues)..sort();
    final q1 = _percentile(sorted, 0.25);
    final q3 = _percentile(sorted, 0.75);
    final iqr = q3 - q1;
    if (iqr <= 0) return rows;

    final lower = q1 - 1.5 * iqr;
    final upper = q3 + 1.5 * iqr;

    return rows.map((r) {
      final copy = Map<String, dynamic>.from(r);
      final val = _parseCleanNumber(copy[field]);
      if (val != null) {
        if (val < lower) {
          copy[field] = (lower == lower.truncateToDouble())
              ? lower.toInt()
              : lower;
        } else if (val > upper) {
          copy[field] = (upper == upper.truncateToDouble())
              ? upper.toInt()
              : upper;
        }
      }
      return copy;
    }).toList();
  }

  /// Performs full automated cleaning across all detected issues.
  static List<Map<String, dynamic>> cleanAll(
    List<Map<String, dynamic>> rows, {
    required List<AiGridColumn> columns,
  }) {
    var data = removeDuplicates(rows);
    data = trimWhitespace(data);

    final report = audit(rows: data, columns: columns);
    for (final issue in report.issues) {
      data = applyRemediation(
        rows: data,
        remediation: issue.remediation,
        columns: columns,
      );
    }
    return data;
  }

  // --- Helper Methods ---

  static bool _isMissing(dynamic v) {
    if (v == null) return true;
    final str = v.toString().trim().toLowerCase();
    return str.isEmpty ||
        str == 'null' ||
        str == 'none' ||
        str == 'n/a' ||
        str == '-';
  }

  static bool _isDirtyNumber(dynamic v) {
    if (v is num) return false;
    final str = v.toString().trim();
    if (_isMissing(str)) return false;
    // Has currency symbol or commas or text
    if (RegExp(r'[\$\€\£\¥\,]').hasMatch(str)) {
      final clean = str.replaceAll(RegExp(r'[\$\€\£\¥\,\s]'), '');
      return num.tryParse(clean) != null;
    }
    return false;
  }

  static num? _parseCleanNumber(dynamic v) {
    if (v is num) return v;
    if (v == null) return null;
    final str = v.toString().trim().replaceAll(RegExp(r'[\$\€\£\¥\,\s]'), '');
    return num.tryParse(str);
  }

  static bool _isNumericColumn(AiGridColumn col, List<dynamic> values) {
    if (col.type == AiGridColumnType.number ||
        col.type == AiGridColumnType.currency) {
      return true;
    }
    int numCount = 0;
    int validCount = 0;
    for (final v in values) {
      if (_isMissing(v)) continue;
      validCount++;
      if (_parseCleanNumber(v) != null) numCount++;
    }
    return validCount > 0 && (numCount / validCount) >= 0.7;
  }

  static bool _isDateColumn(AiGridColumn col, List<dynamic> values) {
    if (col.type == AiGridColumnType.date ||
        col.type == AiGridColumnType.datetime) {
      return true;
    }
    int dateCount = 0;
    int validCount = 0;
    for (final v in values) {
      if (_isMissing(v)) continue;
      validCount++;
      if (_tryParseAnyDate(v.toString().trim()) != null) dateCount++;
    }
    return validCount > 0 && (dateCount / validCount) >= 0.6;
  }

  static bool _isStandardIsoDate(String s) {
    return RegExp(r'^\d{4}-\d{2}-\d{2}(?: \d{2}:\d{2}:\d{2})?$').hasMatch(s);
  }

  static DateTime? _tryParseAnyDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    // ISO
    final iso = DateTime.tryParse(s);
    if (iso != null && s.length >= 8) return iso;

    // Try common patterns
    final formats = [
      'MM/dd/yyyy',
      'M/d/yyyy',
      'dd-MM-yyyy',
      'd-M-yyyy',
      'dd/MM/yyyy',
      'd/M/yyyy',
      'yyyy/MM/dd',
      'yyyy.MM.dd',
      'MMM d, yyyy',
      'MMMM d, yyyy',
      'd MMM yyyy',
      'd MMMM yyyy',
    ];

    for (final fmt in formats) {
      try {
        return DateFormat(fmt).parseStrict(s);
      } catch (_) {}
    }
    return null;
  }

  static List<int> _findDuplicateRowIndices(
    List<Map<String, dynamic>> rows,
    List<AiGridColumn> columns,
  ) {
    final seen = <String, int>{};
    final duplicates = <int>[];

    for (int i = 0; i < rows.length; i++) {
      final sig = _rowSignature(rows[i], columns);
      if (seen.containsKey(sig)) {
        duplicates.add(i);
      } else {
        seen[sig] = i;
      }
    }
    return duplicates;
  }

  static String _rowSignature(
    Map<String, dynamic> row, [
    List<AiGridColumn>? columns,
  ]) {
    final keys = columns != null
        ? columns.map((c) => c.field).toList()
        : (row.keys.where((k) => !k.startsWith('__')).toList()..sort());

    final sb = StringBuffer();
    for (final k in keys) {
      final v = row[k];
      sb.write('$k:${v?.toString().trim().toLowerCase()}|');
    }
    return sb.toString();
  }

  static num _percentile(List<num> sorted, double p) {
    assert(sorted.isNotEmpty);
    if (sorted.length == 1) return sorted.first;
    final index = p * (sorted.length - 1);
    final lower = index.floor();
    final upper = index.ceil();
    final weight = index - lower;
    return sorted[lower] * (1 - weight) + sorted[upper] * weight;
  }

  static String _formatCompactNum(num n) {
    if (n.abs() >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    } else if (n.abs() >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}k';
    }
    return n.toStringAsFixed(1);
  }
}
