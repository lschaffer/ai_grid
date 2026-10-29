import 'dart:convert';

/// Issue categories identified by the Data Quality Auditor.
enum AiGridAuditIssueType {
  /// Exact or key-based duplicate records.
  duplicates,

  /// Null, empty, or unpopulated values.
  missingValues,

  /// Currency symbols, commas, or text markers (e.g. 'N/A') in numeric columns.
  dirtyNumbers,

  /// Inconsistent or non-standard date string formats.
  mixedDates,

  /// Unnecessary leading or trailing spaces.
  inconsistentWhitespace,

  /// Statistical outliers exceeding 1.5 * IQR (Interquartile Range).
  outliers,
}

/// Severity level of a data quality issue.
enum AiGridAuditSeverity { info, warning, critical }

/// Strategy for imputing missing values.
enum AiGridImputeStrategy { mean, median, mode, zero, empty, constant }

/// Action to cleanse or remediate a data quality issue.
enum AiGridCleanseAction {
  removeDuplicates,
  standardizeDates,
  cleanNumbers,
  imputeMissing,
  trimWhitespace,
  capOutliers,
  cleanAll,
}

/// Remediation proposal for resolving a detected data quality issue.
class AiGridAuditRemediation {
  final AiGridCleanseAction action;
  final String label;
  final String description;
  final String? field;
  final AiGridImputeStrategy? imputeStrategy;
  final dynamic constantValue;

  const AiGridAuditRemediation({
    required this.action,
    required this.label,
    required this.description,
    this.field,
    this.imputeStrategy,
    this.constantValue,
  });

  String get actionLabel => label;

  Map<String, dynamic> toJson() => {
    'action': action.name,
    'label': label,
    'description': description,
    if (field != null) 'field': field,
    if (imputeStrategy != null) 'imputeStrategy': imputeStrategy!.name,
    if (constantValue != null) 'constantValue': constantValue,
  };
}

/// Individual issue detected during data auditing.
class AiGridAuditIssue {
  final String id;
  final AiGridAuditIssueType type;
  final AiGridAuditSeverity severity;
  final String title;
  final String description;
  final String? columnField;
  final int affectedCount;
  final List<int> affectedRowIndices;
  final List<dynamic> sampleValues;
  final AiGridAuditRemediation remediation;
  bool isResolved;

  AiGridAuditIssue({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    this.columnField,
    required this.affectedCount,
    required this.affectedRowIndices,
    this.sampleValues = const [],
    required this.remediation,
    this.isResolved = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'severity': severity.name,
    'title': title,
    'description': description,
    if (columnField != null) 'columnField': columnField,
    'affectedCount': affectedCount,
    'affectedRowIndices': affectedRowIndices,
    'sampleValues': sampleValues.map((v) => v.toString()).toList(),
    'remediation': remediation.toJson(),
    'isResolved': isResolved,
  };
}

/// Complete diagnostic audit report evaluating table data health.
class AiGridAuditReport {
  /// Overall data quality health score between 0 and 100.
  final int overallScore;

  /// Total number of rows analyzed.
  final int totalRows;

  /// Total number of columns analyzed.
  final int totalColumns;

  /// List of detected issues.
  final List<AiGridAuditIssue> issues;

  const AiGridAuditReport({
    required this.overallScore,
    required this.totalRows,
    required this.totalColumns,
    required this.issues,
  });

  /// Count of active, unresolved issues.
  int get activeIssuesCount => issues.where((i) => !i.isResolved).length;

  /// Overall quality score.
  int get qualityScore => overallScore;

  /// Returns true if any issues were detected.
  bool get hasIssues => issues.isNotEmpty;

  /// Total count of detected issues.
  int get issueCount => issues.length;

  /// Count of critical severity issues.
  int get criticalIssues =>
      issues.where((i) => i.severity == AiGridAuditSeverity.critical).length;

  /// Count of warning severity issues.
  int get warningIssues =>
      issues.where((i) => i.severity == AiGridAuditSeverity.warning).length;

  /// Count of clean rows without any detected issues.
  int get cleanRows {
    final dirtyIndices = <int>{};
    for (final issue in issues) {
      dirtyIndices.addAll(issue.affectedRowIndices);
    }
    return (totalRows - dirtyIndices.length).clamp(0, totalRows);
  }

  /// Returns true if table data has zero unresolved issues.
  bool get isClean => activeIssuesCount == 0;

  Map<String, dynamic> toJson() => {
    'overallScore': overallScore,
    'totalRows': totalRows,
    'totalColumns': totalColumns,
    'totalIssues': issues.length,
    'activeIssuesCount': activeIssuesCount,
    'isClean': isClean,
    'issues': issues.map((i) => i.toJson()).toList(),
  };

  @override
  String toString() => jsonEncode(toJson());
}

/// Result of an automated data cleaning operation.
class AiGridCleanResult {
  final int modifiedCount;
  final int remainingRows;
  final String message;
  final bool success;

  const AiGridCleanResult({
    required this.modifiedCount,
    required this.remainingRows,
    required this.message,
    this.success = true,
  });

  Map<String, dynamic> toJson() => {
    'modifiedCount': modifiedCount,
    'remainingRows': remainingRows,
    'message': message,
    'success': success,
  };

  @override
  String toString() => jsonEncode(toJson());
}
