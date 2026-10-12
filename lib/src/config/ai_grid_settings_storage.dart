import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage cache for persisting and restoring grid settings across sessions.
class AiGridSettingsStorage {
  static final Map<String, Map<String, dynamic>> _cache = {};

  /// Saves settings for the given [key] to both in-memory cache and persistent storage.
  static void save(String key, Map<String, dynamic> settings) {
    final copy = Map<String, dynamic>.from(settings);
    _cache[key] = copy;

    // Persist to SharedPreferences for survival across app restarts
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('ai_grid_settings_$key', jsonEncode(copy));
      }).catchError((_) {
        // Ignore errors if persistent storage is unavailable
      });
    } catch (_) {
      // Ignore synchronous exceptions
    }
  }

  /// Retrieves saved settings for the given [key] from in-memory cache, or null if none saved.
  static Map<String, dynamic>? load(String key) {
    final found = _cache[key];
    if (found == null) return null;
    return Map<String, dynamic>.from(found);
  }

  /// Retrieves saved settings asynchronously from persistent storage (e.g. across app restarts),
  /// falling back to the in-memory cache.
  static Future<Map<String, dynamic>?> loadAsync(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('ai_grid_settings_$key');
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str) as Map<String, dynamic>;
        _cache[key] = decoded;
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Fall through to in-memory cache
    }
    return load(key);
  }

  /// Clears saved settings for the given [key] from both in-memory and persistent storage.
  static void clear(String key) {
    _cache.remove(key);
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove('ai_grid_settings_$key');
      }).catchError((_) {});
    } catch (_) {}
  }
}
