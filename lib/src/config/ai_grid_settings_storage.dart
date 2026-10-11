/// Storage cache for persisting and restoring grid settings across sessions.
class AiGridSettingsStorage {
  static final Map<String, Map<String, dynamic>> _cache = {};

  /// Saves settings for the given [key].
  static void save(String key, Map<String, dynamic> settings) {
    _cache[key] = Map<String, dynamic>.from(settings);
  }

  /// Retrieves saved settings for the given [key], or null if none saved.
  static Map<String, dynamic>? load(String key) {
    final found = _cache[key];
    if (found == null) return null;
    return Map<String, dynamic>.from(found);
  }

  /// Clears saved settings for the given [key].
  static void clear(String key) {
    _cache.remove(key);
  }
}
