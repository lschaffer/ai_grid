import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_grid_dynamic_datasource.dart';

/// Manages persistence, discovery, and storage of dynamic DataGrid models and datasets.
class AiGridDynamicStorage {
  static const String _registryKey = 'ai_grid_dynamic_registry';
  static const String _activeKey = 'ai_grid_dyn_active_name';

  // In-memory cache for fast lookups and test runtime
  static final Map<String, AiGridDynamicDescriptor> _descriptorCache = {};
  static final Map<String, AiGridDynamicModel> _modelCache = {};
  static final Map<String, List<Map<String, dynamic>>> _dataCache = {};
  static String? _cachedActiveName;

  /// Retrieves list of all registered dynamic datasources.
  static Future<List<AiGridDynamicDescriptor>> listDatasources() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_registryKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        final list = decoded
            .map((item) => AiGridDynamicDescriptor.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        for (final d in list) {
          _descriptorCache[d.name] = d;
        }
        return list;
      }
    } catch (_) {}
    return _descriptorCache.values.toList();
  }

  /// Retrieves the descriptor for a specific datasource name.
  static Future<AiGridDynamicDescriptor?> getDescriptor(String name) async {
    if (_descriptorCache.containsKey(name)) {
      return _descriptorCache[name];
    }
    final list = await listDatasources();
    return list.where((d) => d.name == name).firstOrNull;
  }

  /// Retrieves the column model for a specific datasource name.
  static Future<AiGridDynamicModel?> getModel(String name) async {
    if (_modelCache.containsKey(name)) {
      return _modelCache[name];
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('ai_grid_dyn_model_$name');
      if (raw != null && raw.isNotEmpty) {
        final model = raw.trim().startsWith('{')
            ? AiGridDynamicModel.fromJson(jsonDecode(raw) as Map<String, dynamic>)
            : AiGridDynamicModel.fromYamlString(raw);
        _modelCache[name] = model;
        return model;
      }
    } catch (_) {}
    return null;
  }

  /// Retrieves the data rows for a specific datasource name.
  static Future<List<Map<String, dynamic>>?> getDataRows(String name) async {
    if (_dataCache.containsKey(name)) {
      return List<Map<String, dynamic>>.from(_dataCache[name]!);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('ai_grid_dyn_data_$name');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        final rows = decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _dataCache[name] = rows;
        return rows;
      }
    } catch (_) {}
    return null;
  }

  /// Retrieves the complete dynamic bundle (descriptor, model, and rows).
  static Future<AiGridDynamicBundle?> getBundle(String name) async {
    final desc = await getDescriptor(name);
    final model = await getModel(name);
    final rows = await getDataRows(name);
    if (desc == null || model == null || rows == null) return null;
    return AiGridDynamicBundle(
      descriptor: desc,
      model: model,
      rows: rows,
    );
  }

  /// Saves or updates a dynamic datasource along with its model and data rows.
  static Future<void> saveDatasource({
    required AiGridDynamicDescriptor descriptor,
    required AiGridDynamicModel model,
    required List<Map<String, dynamic>> rows,
  }) async {
    _descriptorCache[descriptor.name] = descriptor;
    _modelCache[descriptor.name] = model;
    _dataCache[descriptor.name] = List<Map<String, dynamic>>.from(rows);

    try {
      final prefs = await SharedPreferences.getInstance();
      // 1. Update registry list
      final currentList = await listDatasources();
      final updatedList = currentList.where((d) => d.name != descriptor.name).toList()
        ..add(descriptor);
      await prefs.setString(_registryKey, jsonEncode(updatedList.map((d) => d.toJson()).toList()));

      // 2. Save model as YAML string
      await prefs.setString('ai_grid_dyn_model_${descriptor.name}', model.toYamlString());

      // 3. Save rows as JSON
      await prefs.setString('ai_grid_dyn_data_${descriptor.name}', jsonEncode(rows));
    } catch (_) {}
  }

  /// Fast update of only the data rows (e.g. after DevExtreme editing).
  static Future<void> updateDataRows(String name, List<Map<String, dynamic>> rows) async {
    _dataCache[name] = List<Map<String, dynamic>>.from(rows);

    final desc = await getDescriptor(name);
    if (desc != null) {
      final updatedDesc = desc.copyWith(
        rowCount: rows.length,
        updatedAt: DateTime.now(),
      );
      _descriptorCache[name] = updatedDesc;

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('ai_grid_dyn_data_$name', jsonEncode(rows));

        final list = await listDatasources();
        final updatedList = list.map((d) => d.name == name ? updatedDesc : d).toList();
        await prefs.setString(_registryKey, jsonEncode(updatedList.map((d) => d.toJson()).toList()));
      } catch (_) {}
    }
  }

  /// Updates the schema model definition for a dynamic datasource.
  static Future<void> updateModel(String name, AiGridDynamicModel model) async {
    _modelCache[name] = model;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_grid_dyn_model_$name', model.toYamlString());
    } catch (_) {}
  }

  /// Deletes a datasource and its associated keys from storage.
  static Future<bool> deleteDatasource(String name) async {
    _descriptorCache.remove(name);
    _modelCache.remove(name);
    _dataCache.remove(name);
    if (_cachedActiveName == name) _cachedActiveName = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ai_grid_dyn_model_$name');
      await prefs.remove('ai_grid_dyn_data_$name');

      final current = await listDatasources();
      final updated = current.where((d) => d.name != name).toList();
      await prefs.setString(_registryKey, jsonEncode(updated.map((d) => d.toJson()).toList()));

      if (prefs.getString(_activeKey) == name) {
        await prefs.remove(_activeKey);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Exports a datasource as a single YAML bundle string.
  static Future<String?> exportBundleYaml(String name) async {
    final bundle = await getBundle(name);
    return bundle?.toYamlString();
  }

  /// Imports a datasource from a YAML bundle string and persists it.
  static Future<AiGridDynamicDescriptor> importBundleYaml(String yamlContent) async {
    final bundle = AiGridDynamicBundle.fromYamlString(yamlContent);
    await saveDatasource(
      descriptor: bundle.descriptor,
      model: bundle.model,
      rows: bundle.rows,
    );
    return bundle.descriptor;
  }

  /// Gets the currently active dynamic datasource name (if any).
  static Future<String?> getActiveDatasourceName() async {
    if (_cachedActiveName != null) return _cachedActiveName;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedActiveName = prefs.getString(_activeKey);
      return _cachedActiveName;
    } catch (_) {}
    return null;
  }

  /// Sets the currently active dynamic datasource name.
  static Future<void> setActiveDatasourceName(String? name) async {
    _cachedActiveName = name;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (name != null) {
        await prefs.setString(_activeKey, name);
      } else {
        await prefs.remove(_activeKey);
      }
    } catch (_) {}
  }

  /// Clears in-memory cache (primarily for tests).
  static void clearCache() {
    _descriptorCache.clear();
    _modelCache.clear();
    _dataCache.clear();
    _cachedActiveName = null;
  }
}
