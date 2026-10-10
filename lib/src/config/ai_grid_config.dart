import 'dart:io';
import 'package:flutter/services.dart';
import 'package:dart_mcp_core/dart_mcp_core.dart';

/// Loads environment variables from `.env` files or rootBundle.
class AiGridEnvLoader {
  static final Map<String, String> _env = {};
  static bool _isLoaded = false;

  /// Loads the `.env` file from the specified path or standard search locations.
  static Future<void> load({String? path}) async {
    if (_isLoaded) return;
    String content = '';
    try {
      final fileCandidates = [
        if (path != null) File(path),
        File('.env'),
        File('../.env'),
        File('../../.env'),
      ];
      for (final f in fileCandidates) {
        if (await f.exists()) {
          content = await f.readAsString();
          if (content.isNotEmpty) break;
        }
      }
    } catch (_) {}

    if (content.trim().isEmpty) {
      try {
        content = await rootBundle.loadString('.env');
      } catch (_) {}
    }

    if (content.isNotEmpty) {
      for (var line in content.split('\n')) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        final parts = line.split('=');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final val = parts.sublist(1).join('=').trim();
          _env[key] = val;
        }
      }
    }
    _isLoaded = true;
  }

  /// Gets an environment variable value by key.
  static String get(String key, {String defaultValue = ''}) {
    return _env[key] ?? defaultValue;
  }

  /// Creates a [LlmConfig] parsed from environment variables.
  static LlmConfig? createLlmConfigFromEnv() {
    final providerStr = get('LLM_PROVIDER').trim().toLowerCase();
    final model = get('LLM_MODEL').trim();
    final apiKey = get('LLM_API_KEY').trim();
    final baseUrl = get('LLM_URL').trim();

    if (providerStr.isEmpty) return null;

    final provider = LlmProvider.fromConfigKey(providerStr);
    if (provider == LlmProvider.none) return null;

    return LlmConfig(
      provider: provider,
      model: model.isNotEmpty ? model : 'gpt-4o-mini',
      apiKey: apiKey,
      baseUrl: baseUrl,
    );
  }
}

/// Configuration options for the AI assistant embedded in [AiGrid].
class AiGridConfig {
  /// LLM provider and credentials configuration.
  final LlmConfig? llmConfig;

  /// Whether the AI assistant panel and toolbar trigger are enabled.
  final bool enableAiAssistant;

  /// Optional custom system prompt overriding the default agent instructions.
  final String? systemPrompt;

  const AiGridConfig({
    this.llmConfig,
    this.enableAiAssistant = true,
    this.systemPrompt,
  });

  /// Automatically creates an [AiGridConfig] by reading the `.env` file.
  static Future<AiGridConfig> fromEnv({String? envPath}) async {
    await AiGridEnvLoader.load(path: envPath);
    return AiGridConfig(
      llmConfig: AiGridEnvLoader.createLlmConfigFromEnv(),
    );
  }
}
