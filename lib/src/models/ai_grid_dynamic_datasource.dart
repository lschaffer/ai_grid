import 'dart:convert';
import 'package:yaml/yaml.dart';
import 'ai_grid_column.dart';
import 'ai_grid_editing_options.dart';

/// Column descriptor within a dynamic grid model definition.
class AiGridDynamicColumnModel {
  final String field;
  final String title;
  final AiGridColumnType type;
  final bool editable;
  final bool required;
  final double? width;
  final double? maxWidth;
  final String? numberFormat;
  final AiGridEditorType? editorType;

  const AiGridDynamicColumnModel({
    required this.field,
    required this.title,
    this.type = AiGridColumnType.text,
    this.editable = true,
    this.required = false,
    this.width,
    this.maxWidth,
    this.numberFormat,
    this.editorType,
  });

  AiGridDynamicColumnModel copyWith({
    String? field,
    String? title,
    AiGridColumnType? type,
    bool? editable,
    bool? required,
    double? width,
    double? maxWidth,
    String? numberFormat,
    AiGridEditorType? editorType,
  }) {
    return AiGridDynamicColumnModel(
      field: field ?? this.field,
      title: title ?? this.title,
      type: type ?? this.type,
      editable: editable ?? this.editable,
      required: required ?? this.required,
      width: width ?? this.width,
      maxWidth: maxWidth ?? this.maxWidth,
      numberFormat: numberFormat ?? this.numberFormat,
      editorType: editorType ?? this.editorType,
    );
  }

  AiGridColumn toAiGridColumn() {
    return AiGridColumn(
      field: field,
      title: title,
      type: type,
      editable: editable,
      required: required,
      width: width,
      maxWidth: maxWidth,
      numberFormat: numberFormat,
      editorType: editorType,
    );
  }

  factory AiGridDynamicColumnModel.fromAiGridColumn(AiGridColumn col) {
    return AiGridDynamicColumnModel(
      field: col.field,
      title: col.title,
      type: col.type,
      editable: col.editable ?? true,
      required: col.required,
      width: col.width,
      maxWidth: col.maxWidth,
      numberFormat: col.numberFormat,
      editorType: col.editorType,
    );
  }

  Map<String, dynamic> toJson() => {
        'field': field,
        'title': title,
        'type': type.name,
        'editable': editable,
        'required': required,
        if (width != null) 'width': width,
        if (maxWidth != null) 'max_width': maxWidth,
        if (numberFormat != null) 'number_format': numberFormat,
        if (editorType != null) 'editor_type': editorType!.name,
      };

  factory AiGridDynamicColumnModel.fromJson(Map<String, dynamic> json) {
    AiGridColumnType parseType(String? t) {
      if (t == null) return AiGridColumnType.text;
      switch (t.toLowerCase()) {
        case 'number':
        case 'int':
        case 'integer':
        case 'double':
        case 'float':
          return AiGridColumnType.number;
        case 'currency':
        case 'price':
        case 'money':
          return AiGridColumnType.currency;
        case 'date':
          return AiGridColumnType.date;
        case 'datetime':
          return AiGridColumnType.datetime;
        case 'boolean':
        case 'bool':
          return AiGridColumnType.boolean;
        case 'select':
          return AiGridColumnType.select;
        default:
          return AiGridColumnType.text;
      }
    }

    AiGridEditorType? parseEditorType(String? e) {
      if (e == null) return null;
      for (final val in AiGridEditorType.values) {
        if (val.name.toLowerCase() == e.toLowerCase()) return val;
      }
      return null;
    }

    return AiGridDynamicColumnModel(
      field: json['field'] as String? ?? 'unknown',
      title: json['title'] as String? ?? json['field'] as String? ?? '',
      type: parseType(json['type']?.toString()),
      editable: json['editable'] as bool? ?? true,
      required: json['required'] as bool? ?? false,
      width: (json['width'] as num?)?.toDouble(),
      maxWidth: (json['max_width'] as num?)?.toDouble() ??
          (json['maxWidth'] as num?)?.toDouble(),
      numberFormat: json['number_format'] as String? ?? json['numberFormat'] as String?,
      editorType: parseEditorType(json['editor_type']?.toString() ?? json['editorType']?.toString()),
    );
  }
}

/// Dynamic grid schema model definition, serializable to/from YAML and JSON.
class AiGridDynamicModel {
  final String modelName;
  final String datasourceName;
  final String title;
  final bool isReadonly;
  final String sourceType; // 'file' | 'web' | 'clipboard'
  final String? sourceOrigin;
  final DateTime createdAt;
  final List<AiGridDynamicColumnModel> columns;

  const AiGridDynamicModel({
    required this.modelName,
    required this.datasourceName,
    required this.title,
    this.isReadonly = false,
    this.sourceType = 'file',
    this.sourceOrigin,
    required this.createdAt,
    required this.columns,
  });

  AiGridDynamicModel copyWith({
    String? modelName,
    String? datasourceName,
    String? title,
    bool? isReadonly,
    String? sourceType,
    String? sourceOrigin,
    DateTime? createdAt,
    List<AiGridDynamicColumnModel>? columns,
  }) {
    return AiGridDynamicModel(
      modelName: modelName ?? this.modelName,
      datasourceName: datasourceName ?? this.datasourceName,
      title: title ?? this.title,
      isReadonly: isReadonly ?? this.isReadonly,
      sourceType: sourceType ?? this.sourceType,
      sourceOrigin: sourceOrigin ?? this.sourceOrigin,
      createdAt: createdAt ?? this.createdAt,
      columns: columns ?? this.columns,
    );
  }

  List<AiGridColumn> toColumns() => columns.map((c) => c.toAiGridColumn()).toList();

  Map<String, dynamic> toJson() => {
        'version': '1.0',
        'model_name': modelName,
        'datasource_name': datasourceName,
        'title': title,
        'is_readonly': isReadonly,
        'source_type': sourceType,
        if (sourceOrigin != null) 'source_origin': sourceOrigin,
        'created_at': createdAt.toIso8601String(),
        'columns': columns.map((c) => c.toJson()).toList(),
      };

  String toYamlString() {
    final sb = StringBuffer();
    sb.writeln('version: "1.0"');
    sb.writeln('model_name: "$modelName"');
    sb.writeln('datasource_name: "$datasourceName"');
    sb.writeln('title: "${title.replaceAll('"', r'\"')}"');
    sb.writeln('is_readonly: $isReadonly');
    sb.writeln('source_type: "$sourceType"');
    if (sourceOrigin != null) {
      sb.writeln('source_origin: "${sourceOrigin!.replaceAll('"', r'\"')}"');
    }
    sb.writeln('created_at: "${createdAt.toIso8601String()}"');
    sb.writeln('columns:');
    for (final col in columns) {
      sb.writeln('  - field: "${col.field}"');
      sb.writeln('    title: "${col.title.replaceAll('"', r'\"')}"');
      sb.writeln('    type: "${col.type.name}"');
      sb.writeln('    editable: ${col.editable}');
      sb.writeln('    required: ${col.required}');
      if (col.width != null) sb.writeln('    width: ${col.width}');
      if (col.maxWidth != null) sb.writeln('    max_width: ${col.maxWidth}');
      if (col.numberFormat != null) {
        sb.writeln('    number_format: "${col.numberFormat}"');
      }
      if (col.editorType != null) {
        sb.writeln('    editor_type: "${col.editorType!.name}"');
      }
    }
    return sb.toString();
  }

  factory AiGridDynamicModel.fromJson(Map<String, dynamic> json) {
    final colsRaw = json['columns'] as List? ?? const [];
    final cols = colsRaw
        .map((c) => AiGridDynamicColumnModel.fromJson(Map<String, dynamic>.from(c as Map)))
        .toList();

    return AiGridDynamicModel(
      modelName: json['model_name'] as String? ?? 'datasource_mdl.yaml',
      datasourceName: json['datasource_name'] as String? ?? 'datasource.json',
      title: json['title'] as String? ?? 'Dynamic DataGrid',
      isReadonly: json['is_readonly'] as bool? ?? false,
      sourceType: json['source_type'] as String? ?? 'file',
      sourceOrigin: json['source_origin'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      columns: cols,
    );
  }

  factory AiGridDynamicModel.fromYamlString(String yamlString) {
    final parsed = loadYaml(yamlString);
    if (parsed is! Map) {
      throw FormatException('Invalid YAML structure for AiGridDynamicModel');
    }
    final map = _deepConvertYamlMap(parsed);
    return AiGridDynamicModel.fromJson(map);
  }

  static Map<String, dynamic> _deepConvertYamlMap(Map yamlMap) {
    final result = <String, dynamic>{};
    yamlMap.forEach((key, value) {
      final strKey = key.toString();
      if (value is Map) {
        result[strKey] = _deepConvertYamlMap(value);
      } else if (value is List) {
        result[strKey] = value.map((e) => e is Map ? _deepConvertYamlMap(e) : e).toList();
      } else {
        result[strKey] = value;
      }
    });
    return result;
  }
}

/// Metadata descriptor of a saved dynamic datasource in the registry.
class AiGridDynamicDescriptor {
  final String name;
  final String modelName;
  final String datasourceName;
  final String title;
  final String sourceType;
  final String? sourceOrigin;
  final bool isReadonly;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int rowCount;

  const AiGridDynamicDescriptor({
    required this.name,
    required this.modelName,
    required this.datasourceName,
    required this.title,
    this.sourceType = 'file',
    this.sourceOrigin,
    this.isReadonly = false,
    required this.createdAt,
    required this.updatedAt,
    required this.rowCount,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'model_name': modelName,
        'datasource_name': datasourceName,
        'title': title,
        'source_type': sourceType,
        if (sourceOrigin != null) 'source_origin': sourceOrigin,
        'is_readonly': isReadonly,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'row_count': rowCount,
      };

  factory AiGridDynamicDescriptor.fromJson(Map<String, dynamic> json) {
    return AiGridDynamicDescriptor(
      name: json['name'] as String? ?? '',
      modelName: json['model_name'] as String? ?? '',
      datasourceName: json['datasource_name'] as String? ?? '',
      title: json['title'] as String? ?? json['name'] as String? ?? 'Datasource',
      sourceType: json['source_type'] as String? ?? 'file',
      sourceOrigin: json['source_origin'] as String?,
      isReadonly: json['is_readonly'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      rowCount: (json['row_count'] as num?)?.toInt() ?? 0,
    );
  }

  AiGridDynamicDescriptor copyWith({
    String? name,
    String? modelName,
    String? datasourceName,
    String? title,
    String? sourceType,
    String? sourceOrigin,
    bool? isReadonly,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? rowCount,
  }) {
    return AiGridDynamicDescriptor(
      name: name ?? this.name,
      modelName: modelName ?? this.modelName,
      datasourceName: datasourceName ?? this.datasourceName,
      title: title ?? this.title,
      sourceType: sourceType ?? this.sourceType,
      sourceOrigin: sourceOrigin ?? this.sourceOrigin,
      isReadonly: isReadonly ?? this.isReadonly,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowCount: rowCount ?? this.rowCount,
    );
  }
}

/// Standalone export/import package combining model definition and data rows in YAML.
class AiGridDynamicBundle {
  final AiGridDynamicDescriptor descriptor;
  final AiGridDynamicModel model;
  final List<Map<String, dynamic>> rows;

  const AiGridDynamicBundle({
    required this.descriptor,
    required this.model,
    required this.rows,
  });

  String toYamlString() {
    final sb = StringBuffer();
    sb.writeln('# AiGrid Dynamic Datasource Package');
    sb.writeln('metadata:');
    sb.writeln('  name: "${descriptor.name}"');
    sb.writeln('  title: "${descriptor.title.replaceAll('"', r'\"')}"');
    sb.writeln('  source_type: "${descriptor.sourceType}"');
    sb.writeln('  is_readonly: ${descriptor.isReadonly}');
    sb.writeln('  created_at: "${descriptor.createdAt.toIso8601String()}"');
    sb.writeln('  updated_at: "${descriptor.updatedAt.toIso8601String()}"');
    sb.writeln('  row_count: ${rows.length}');
    sb.writeln();
    sb.writeln('model:');
    for (final line in model.toYamlString().split('\n')) {
      if (line.isNotEmpty) sb.writeln('  $line');
    }
    sb.writeln();
    sb.writeln('data:');
    for (final row in rows) {
      sb.writeln('  - ${jsonEncode(row)}');
    }
    return sb.toString();
  }

  factory AiGridDynamicBundle.fromYamlString(String yamlContent) {
    final parsed = loadYaml(yamlContent);
    if (parsed is! Map) {
      throw const FormatException('Invalid YAML bundle structure');
    }
    final map = AiGridDynamicModel._deepConvertYamlMap(parsed);
    final meta = map['metadata'] as Map<String, dynamic>? ?? {};
    final modelMap = map['model'] as Map<String, dynamic>? ?? {};
    final dataList = map['data'] as List? ?? [];

    final model = AiGridDynamicModel.fromJson(modelMap);
    final rows = <Map<String, dynamic>>[];
    for (final item in dataList) {
      if (item is Map) {
        rows.add(Map<String, dynamic>.from(item));
      } else if (item is String) {
        try {
          final decoded = jsonDecode(item);
          if (decoded is Map) rows.add(Map<String, dynamic>.from(decoded));
        } catch (_) {}
      }
    }

    final desc = AiGridDynamicDescriptor(
      name: meta['name'] as String? ?? model.datasourceName.replaceAll('.json', ''),
      modelName: model.modelName,
      datasourceName: model.datasourceName,
      title: meta['title'] as String? ?? model.title,
      sourceType: meta['source_type'] as String? ?? model.sourceType,
      sourceOrigin: meta['source_origin'] as String? ?? model.sourceOrigin,
      isReadonly: meta['is_readonly'] as bool? ?? model.isReadonly,
      createdAt: meta['created_at'] != null
          ? DateTime.tryParse(meta['created_at'].toString()) ?? DateTime.now()
          : model.createdAt,
      updatedAt: meta['updated_at'] != null
          ? DateTime.tryParse(meta['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      rowCount: rows.length,
    );

    return AiGridDynamicBundle(
      descriptor: desc,
      model: model,
      rows: rows,
    );
  }
}
