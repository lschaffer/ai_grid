import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dart_mcp_core/dart_mcp_core.dart';
import 'ai_grid_smart_column.dart';

/// Execution runner that evaluates AI Smart Columns using LLMs or local fallbacks.
class AiGridSmartColumnRunner {
  AiGridSmartColumnRunner._();

  /// Evaluates an [AiGridSmartColumn] for a list of [rows].
  /// Returns a map of `rowIndex -> evaluatedValue`.
  static Future<Map<int, dynamic>> evaluateBatch({
    required AiGridSmartColumn column,
    required List<Map<String, dynamic>> rows,
    required List<int> rowIndices,
    LlmConfig? llmConfig,
  }) async {
    final results = <int, dynamic>{};
    if (rowIndices.isEmpty) return results;

    // 1. Try LLM evaluation if configured
    if (llmConfig != null && llmConfig.isConfigured) {
      try {
        final llmResults = await _evaluateWithLlm(
          column: column,
          rows: rows,
          rowIndices: rowIndices,
          llmConfig: llmConfig,
        );
        results.addAll(llmResults);
      } catch (e) {
        debugPrint('LLM Smart Column evaluation error: $e');
      }
    }

    // 2. For any remaining/unfilled rows, use localEvaluator or heuristic fallback
    for (final idx in rowIndices) {
      if (!results.containsKey(idx) || results[idx] == null) {
        final row = rows[idx];
        if (column.localEvaluator != null) {
          try {
            results[idx] = await column.localEvaluator!(row);
          } catch (_) {
            results[idx] = heuristicFallback(column, row);
          }
        } else {
          results[idx] = heuristicFallback(column, row);
        }
      }
    }

    return results;
  }

  /// Calls the configured LLM using McpAgentEngine in batches.
  static Future<Map<int, dynamic>> _evaluateWithLlm({
    required AiGridSmartColumn column,
    required List<Map<String, dynamic>> rows,
    required List<int> rowIndices,
    required LlmConfig llmConfig,
  }) async {
    final out = <int, dynamic>{};
    const batchSize = 6;

    for (var b = 0; b < rowIndices.length; b += batchSize) {
      final chunkIndices = rowIndices.sublist(
        b,
        (b + batchSize < rowIndices.length) ? b + batchSize : rowIndices.length,
      );

      final promptBuffer = StringBuffer();
      promptBuffer.writeln(
        'Task: Evaluate each of the following data rows based on this prompt template:',
      );
      promptBuffer.writeln('Template: "${column.promptTemplate}"');
      if (column.options != null && column.options!.isNotEmpty) {
        promptBuffer.writeln(
          'Allowed Options: [${column.options!.join(", ")}]. For each row, you MUST choose strictly one of these options.',
        );
      }
      promptBuffer.writeln(
        'Return ONLY a valid JSON array of strings corresponding to the result for each row in the exact order given. Example: ["Val1", "Val2"]\n',
      );

      for (var i = 0; i < chunkIndices.length; i++) {
        final idx = chunkIndices[i];
        final row = rows[idx];
        promptBuffer.writeln('Row ${i + 1}: ${column.formatPrompt(row)}');
      }

      final promptText = promptBuffer.toString();
      final agent = Agent(
        key: 'smart_column_agent',
        name: 'Smart Column Agent',
        llmConfig: llmConfig,
        systemPrompt:
            'You are a high-speed tabular AI assistant synthesizing column values. Output only a raw JSON array of strings without markdown fences.',
        initialMessages: [
          ChatMessage.user(promptText, parts: [TextPart(promptText)]),
        ],
        prompts: [
          SubPromptStep(text: promptText, stopAfterToolCall: false),
        ],
        dartTools: const [],
        remoteServers: const [],
        localServers: const [],
      );

      final engine = McpAgentEngine();
      engine.setAgents([agent]);

      String? responseText;
      await engine.run(
        'smart_column_agent',
        onAssistantResult: (p, res) {
          responseText = res;
        },
      );

      if (responseText != null && responseText!.isNotEmpty) {
        try {
          var clean = responseText!.trim();
          if (clean.startsWith('```json')) {
            clean = clean.replaceAll('```json', '').replaceAll('```', '').trim();
          } else if (clean.startsWith('```')) {
            clean = clean.replaceAll('```', '').trim();
          }
          final decoded = jsonDecode(clean);
          if (decoded is List) {
            for (var i = 0; i < chunkIndices.length && i < decoded.length; i++) {
              out[chunkIndices[i]] = decoded[i]?.toString();
            }
          }
        } catch (_) {}
      }
    }
    return out;
  }

  /// Intelligent local heuristic fallback for common NLP prompt categories.
  static String heuristicFallback(
      AiGridSmartColumn column, Map<String, dynamic> row) {
    final lowerPrompt = column.promptTemplate.toLowerCase();
    final combinedRowText =
        row.values.map((v) => v?.toString() ?? '').join(' ').toLowerCase();

    // 1. Sentiment analysis
    if (lowerPrompt.contains('sentiment')) {
      if (combinedRowText.contains('outage') ||
          combinedRowText.contains('crash') ||
          combinedRowText.contains('corrupt') ||
          combinedRowText.contains('urgent') ||
          combinedRowText.contains('broken') ||
          combinedRowText.contains('unacceptable')) {
        return column.options?.contains('Critical') == true
            ? 'Critical'
            : 'Negative';
      }
      if (combinedRowText.contains('fail') ||
          combinedRowText.contains('error') ||
          combinedRowText.contains('slow') ||
          combinedRowText.contains('bug') ||
          combinedRowText.contains('issue') ||
          combinedRowText.contains('frustrat') ||
          combinedRowText.contains('poor') ||
          combinedRowText.contains('bad')) {
        return 'Negative';
      }
      if (combinedRowText.contains('great') ||
          combinedRowText.contains('lov') ||
          combinedRowText.contains('excellent') ||
          combinedRowText.contains('exceptional') ||
          combinedRowText.contains('amazing') ||
          combinedRowText.contains('perfect') ||
          combinedRowText.contains('fast') ||
          combinedRowText.contains('pleased') ||
          combinedRowText.contains('smooth') ||
          combinedRowText.contains('helpful') ||
          combinedRowText.contains('impressive') ||
          combinedRowText.contains('resolved')) {
        return 'Positive';
      }
      return 'Neutral';
    }

    // 2. Urgency rating
    if (lowerPrompt.contains('urgency') || lowerPrompt.contains('priority')) {
      if (combinedRowText.contains('crash') ||
          combinedRowText.contains('down') ||
          combinedRowText.contains('outage') ||
          combinedRowText.contains('blocker') ||
          combinedRowText.contains('data loss')) {
        return column.options?.firstWhere(
                (o) => o.contains('1') || o.toLowerCase().contains('critical'),
                orElse: () => 'P1 (Critical)') ??
            'P1 (Critical)';
      }
      if (combinedRowText.contains('error') ||
          combinedRowText.contains('broken') ||
          combinedRowText.contains('urgent') ||
          combinedRowText.contains('fail')) {
        return column.options?.firstWhere(
                (o) => o.contains('2') || o.toLowerCase().contains('high'),
                orElse: () => 'P2 (High)') ??
            'P2 (High)';
      }
      if (combinedRowText.contains('slow') ||
          combinedRowText.contains('delay') ||
          combinedRowText.contains('question') ||
          combinedRowText.contains('feature')) {
        return column.options?.firstWhere(
                (o) => o.contains('3') || o.toLowerCase().contains('med'),
                orElse: () => 'P3 (Medium)') ??
            'P3 (Medium)';
      }
      return column.options?.firstWhere(
              (o) => o.contains('4') || o.toLowerCase().contains('low'),
              orElse: () => 'P4 (Low)') ??
          'P4 (Low)';
    }

    // 3. Recommended Action
    if (lowerPrompt.contains('action') || lowerPrompt.contains('recommend')) {
      if (combinedRowText.contains('crash') ||
          combinedRowText.contains('outage') ||
          combinedRowText.contains('down')) {
        return 'Escalate to Engineering';
      }
      if (combinedRowText.contains('billing') ||
          combinedRowText.contains('invoice') ||
          combinedRowText.contains('charge')) {
        return 'Transfer to Billing Team';
      }
      if (combinedRowText.contains('slow') ||
          combinedRowText.contains('performance')) {
        return 'Request Diagnostic Logs';
      }
      if (combinedRowText.contains('how to') ||
          combinedRowText.contains('question') ||
          combinedRowText.contains('documentation')) {
        return 'Send API Documentation';
      }
      if (combinedRowText.contains('love') ||
          combinedRowText.contains('great') ||
          combinedRowText.contains('thanks')) {
        return 'Close with Gratitude';
      }
      return 'Assign Support Specialist';
    }

    // 4. Categorization / Intent
    if (lowerPrompt.contains('category') || lowerPrompt.contains('intent')) {
      if (combinedRowText.contains('bug') ||
          combinedRowText.contains('error') ||
          combinedRowText.contains('crash')) {
        return 'Bug / Defect';
      }
      if (combinedRowText.contains('feature') ||
          combinedRowText.contains('wish') ||
          combinedRowText.contains('add')) {
        return 'Feature Request';
      }
      if (combinedRowText.contains('bill') ||
          combinedRowText.contains('pay') ||
          combinedRowText.contains('price')) {
        return 'Billing & Account';
      }
      return 'Technical Support';
    }

    // 5. Default generic synthesis
    if (column.options != null && column.options!.isNotEmpty) {
      return column.options!.first;
    }
    return 'Analyzed';
  }
}
