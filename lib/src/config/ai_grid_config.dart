import 'package:flutter/services.dart';
import 'env_reader_stub.dart'
    if (dart.library.io) 'env_reader_io.dart';
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
      final diskContent = await readEnvFileFromDisk(path);
      if (diskContent != null && diskContent.isNotEmpty) {
        content = diskContent;
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
    var providerStr = get('LLM_PROVIDER').trim().toLowerCase();
    final model = get('LLM_MODEL').trim();
    final apiKey = get('LLM_API_KEY').trim();
    final baseUrl = get('LLM_URL').trim();

    if (providerStr.isEmpty) return null;

    // Normalize common provider aliases
    if (providerStr == 'anthropic') providerStr = 'claude';
    if (providerStr == 'openai-compatible' || providerStr == 'custom') {
      providerStr = 'openai_compatible';
    }
    if (providerStr == 'google') providerStr = 'gemini';

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

  /// Whether to hide the AI assistant button entirely when no LLM is configured (if false, it is grayed out/disabled).
  final bool hideAiAssistantIfNoLlm;

  /// Optional custom system prompt overriding the default agent instructions.
  final String? systemPrompt;

  /// Optional contextual sample prompts shown as quick-action suggestion chips in the AI Assistant panel.
  final List<String>? suggestedPrompts;

  const AiGridConfig({
    this.llmConfig,
    this.enableAiAssistant = true,
    this.hideAiAssistantIfNoLlm = false,
    this.systemPrompt,
    this.suggestedPrompts,
  });

  /// Creates a copy of this [AiGridConfig] with specific fields replaced.
  AiGridConfig copyWith({
    LlmConfig? llmConfig,
    bool? enableAiAssistant,
    bool? hideAiAssistantIfNoLlm,
    String? systemPrompt,
    List<String>? suggestedPrompts,
  }) {
    return AiGridConfig(
      llmConfig: llmConfig ?? this.llmConfig,
      enableAiAssistant: enableAiAssistant ?? this.enableAiAssistant,
      hideAiAssistantIfNoLlm:
          hideAiAssistantIfNoLlm ?? this.hideAiAssistantIfNoLlm,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      suggestedPrompts: suggestedPrompts ?? this.suggestedPrompts,
    );
  }

  /// Whether a valid LLM provider and credentials are configured.
  bool get isLlmConfigured =>
      (llmConfig ?? AiGridEnvLoader.createLlmConfigFromEnv())?.isConfigured ??
      false;

  /// Automatically creates an [AiGridConfig] by reading the `.env` file.
  static Future<AiGridConfig> fromEnv({String? envPath}) async {
    await AiGridEnvLoader.load(path: envPath);
    return AiGridConfig(
      llmConfig: AiGridEnvLoader.createLlmConfigFromEnv(),
    );
  }
}
