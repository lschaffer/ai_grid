import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dart_mcp_core/dart_mcp_core.dart';
import '../config/ai_grid_config.dart';
import '../controllers/ai_grid_controller.dart';
import '../mcp/ai_grid_tools.dart';
import '../models/ai_grid_column.dart';
import '../theme/ai_grid_theme.dart';

/// Floating AI Assistant panel providing interactive conversation,
/// automated tool execution via `McpAgentEngine`, and smart dynamic suggestion chips.
class AiGridAssistantPanel extends StatefulWidget {
  final AiGridController controller;
  final AiGridConfig? aiConfig;
  final Future<void> Function(String prompt)? onSendPrompt;
  final bool embeddedInWindow;
  final bool isFullScreen;

  const AiGridAssistantPanel({
    super.key,
    required this.controller,
    this.aiConfig,
    this.onSendPrompt,
    this.embeddedInWindow = false,
    this.isFullScreen = false,
  });

  @override
  State<AiGridAssistantPanel> createState() => _AiGridAssistantPanelState();
}

class _AiGridAssistantPanelState extends State<AiGridAssistantPanel> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_AssistantMessage> _messages = [];
  bool _isLoading = false;

  void _copyToClipboard(BuildContext context, String text) {
    if (text.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Copied to clipboard'),
          ],
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _initDefaultSuggestions();
  }

  void _initDefaultSuggestions() {
    final llm = widget.aiConfig?.llmConfig ??
        AiGridEnvLoader.createLlmConfigFromEnv();
    final modelName = llm != null && llm.isConfigured
        ? '${llm.provider.displayName} (${llm.model})'
        : 'Local Heuristic';

    _messages.add(
      _AssistantMessage(
        title: 'Assistant Ready',
        description:
            'Connected to $modelName. Ask me to calculate, group, filter, sort, or summarize your data.',
        isSystem: true,
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  void _handleQuickAction(String actionLabel, VoidCallback action) {
    action();
    setState(() {
      _messages.add(
        _AssistantMessage(
          title: 'Action Executed',
          description: actionLabel,
          isUser: false,
        ),
      );
    });
    _scrollToBottom();
  }

  Future<void> _handleSend() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_AssistantMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _textCtrl.clear();
    _scrollToBottom();

    try {
      if (widget.onSendPrompt != null) {
        await widget.onSendPrompt!(text);
      } else {
        final llm = widget.aiConfig?.llmConfig ??
            AiGridEnvLoader.createLlmConfigFromEnv();

        if (llm != null && llm.isConfigured) {
          await _executeWithAgentsEngine(text, llm);
        } else {
          _executeLocalHeuristic(text);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            _AssistantMessage(
              title: 'Execution Error',
              description: e.toString(),
              isUser: false,
            ),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _executeWithAgentsEngine(String prompt, LlmConfig config) async {
    final tools = AiGridSkill.createTools(widget.controller);
    final agent = Agent(
      key: 'ai_grid_agent',
      name: 'DataGrid Agent',
      llmConfig: config,
      systemPrompt: widget.aiConfig?.systemPrompt ??
          AiGridSkill.defaultSystemPrompt,
      prompts: [
        SubPromptStep(
          text: prompt,
          stopAfterToolCall: false,
        ),
      ],
      dartTools: tools,
      remoteServers: const [],
      localServers: const [],
    );

    final engine = McpAgentEngine();
    engine.setAgents([agent]);

    await engine.run(
      'ai_grid_agent',
      onToolResult: (toolName, params, result) {
        if (!mounted) return;
        setState(() {
          _messages.add(_AssistantMessage(
            title: 'Action: $toolName',
            description: result.length > 250
                ? '${result.substring(0, 250)}...'
                : result,
            isUser: false,
          ));
        });
        _scrollToBottom();
      },
      onAssistantResult: (p, response) {
        if (!mounted) return;
        setState(() {
          _messages.add(_AssistantMessage(
            description: response,
            isUser: false,
          ));
        });
        _scrollToBottom();
      },
      onError: (err) {
        if (!mounted) return;
        final errStr = err.toString();
        final isCors = errStr.contains('Failed to fetch') || errStr.contains('XMLHttpRequest');
        setState(() {
          _messages.add(_AssistantMessage(
            title: isCors ? 'Browser CORS Restriction' : 'Agent Error',
            description: isCors
                ? 'Direct browser call blocked by CORS.\nLaunch Chrome with --disable-web-security or configure a proxy.'
                : errStr,
            isUser: false,
          ));
        });
        _scrollToBottom();
      },
    );
  }

  void _executeLocalHeuristic(String prompt) {
    final lower = prompt.toLowerCase();

    if (lower.contains('clear') || lower.contains('reset')) {
      widget.controller.reset();
      _messages.add(
        _AssistantMessage(
          title: 'Reset',
          description: 'Grid state reset to defaults.',
          isUser: false,
        ),
      );
      _scrollToBottom();
      return;
    }

    if (lower.contains('calc') ||
        lower.contains('avg') ||
        lower.contains('average') ||
        lower.contains('sum') ||
        lower.contains('total') ||
        lower.contains('min') ||
        lower.contains('max') ||
        lower.contains('median') ||
        lower.contains('count')) {
      String op = 'average';
      if (lower.contains('sum') || lower.contains('total')) {
        op = 'sum';
      } else if (lower.contains('min')) {
        op = 'min';
      } else if (lower.contains('max')) {
        op = 'max';
      } else if (lower.contains('median')) {
        op = 'median';
      } else if (lower.contains('count')) {
        op = 'count';
      }

      AiGridColumn? targetCol;
      for (final col in widget.controller.columns) {
        if (lower.contains(col.field.toLowerCase()) ||
            lower.contains(col.title.toLowerCase())) {
          targetCol = col;
          break;
        }
      }
      targetCol ??= widget.controller.columns
          .where((c) =>
              c.type == AiGridColumnType.number ||
              c.type == AiGridColumnType.currency)
          .firstOrNull;

      if (targetCol != null) {
        final calc = widget.controller.calculate(
          field: targetCol.field,
          operation: op,
        );
        _messages.add(
          _AssistantMessage(
            title: 'Calculation ($op)',
            description:
                '${targetCol.title} ($op): ${calc['result'] ?? calc['error']}',
            isUser: false,
          ),
        );
        return;
      }
    }

    // Dynamic grouping / sorting / filtering
    bool matched = false;
    for (final col in widget.controller.columns) {
      final fLower = col.field.toLowerCase();
      final tLower = col.title.toLowerCase();

      if (lower.contains('group') &&
          (lower.contains(fLower) || lower.contains(tLower))) {
        widget.controller.addGroup(col.field);
        _messages.add(
          _AssistantMessage(
            title: 'Grouping',
            description: 'Grouped data against "${col.title}".',
            isUser: false,
          ),
        );
        matched = true;
        break;
      }

      if (lower.contains('sort') &&
          (lower.contains(fLower) || lower.contains(tLower))) {
        final desc = lower.contains('desc');
        widget.controller.setSorting(col.field, descending: desc);
        _messages.add(
          _AssistantMessage(
            title: 'Sorting',
            description:
                'Sorted by "${col.title}" ${desc ? "descending" : "ascending"}.',
            isUser: false,
          ),
        );
        matched = true;
        break;
      }
    }

    if (matched) return;

    if (lower.contains('clear') || lower.contains('reset')) {
      widget.controller.reset();
      _messages.add(
        _AssistantMessage(
          title: 'Reset',
          description: 'Grid state reset to defaults.',
          isUser: false,
        ),
      );
    } else {
      _messages.add(
        _AssistantMessage(
          title: 'Processed',
          description: 'Interpreted command: "$prompt".',
          isUser: false,
        ),
      );
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    final panelBg = isDark ? colorScheme.surfaceContainerHigh : Colors.white;
    final panelBorder =
        isDark ? colorScheme.outlineVariant.withAlpha(90) : AiGridTheme.borderColor;

    final content = Column(
      children: [
        if (!widget.embeddedInWindow) _buildHeader(context),
        Expanded(child: _buildMessageList(context)),
        _buildSuggestionChips(context),
        _buildInputBox(context),
      ],
    );

    if (widget.embeddedInWindow) {
      return content;
    }

    if (widget.isFullScreen) {
      return Container(
        color: panelBg,
        child: content,
      );
    }

    return Container(
      width: 390,
      height: 490,
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 90 : 40),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: panelBorder, width: 1),
      ),
      child: content,
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHighest
            : const Color(0xFFF8FAFC),
        borderRadius: widget.isFullScreen
            ? BorderRadius.zero
            : const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? colorScheme.outlineVariant.withAlpha(60)
                : AiGridTheme.borderColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (widget.isFullScreen) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 18),
              onPressed: () => widget.controller.setAiAssistantVisible(false),
              tooltip: 'Back to Data Grid',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
          ],
          Icon(
            Icons.auto_awesome,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'AI Assistant',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
              fontFamily: 'Segoe UI',
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => widget.controller.setAiAssistantVisible(false),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        if (msg.isUser) {
          final userText = msg.text ?? '';
          return Align(
            alignment: Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.primaryContainer
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? colorScheme.primary.withAlpha(100)
                      : const Color(0xFFBFDBFE),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      userText,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? colorScheme.onPrimaryContainer
                            : AiGridTheme.textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      Icons.copy_outlined,
                      size: 13,
                      color: (isDark
                              ? colorScheme.onPrimaryContainer
                              : AiGridTheme.textColor)
                          .withAlpha(150),
                    ),
                    tooltip: 'Copy prompt',
                    onPressed: () => _copyToClipboard(context, userText),
                    padding: const EdgeInsets.all(2),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          );
        }

        final fullResponse = [
          if (msg.title != null) msg.title!,
          if (msg.description != null) msg.description!,
        ].join('\n');

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surfaceContainer
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark
                  ? colorScheme.outlineVariant.withAlpha(60)
                  : AiGridTheme.borderColor,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.check_circle,
                size: 16,
                color: Color(0xFF16A34A),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (msg.title != null)
                      Text(
                        msg.title!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    if (msg.description != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          msg.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.copy_outlined,
                  size: 13,
                  color: colorScheme.onSurfaceVariant.withAlpha(140),
                ),
                tooltip: 'Copy response',
                onPressed: () => _copyToClipboard(context, fullResponse),
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuggestionChips(BuildContext context) {
    final cols = widget.controller.columns;
    AiGridColumn? numCol;
    AiGridColumn? groupCol;
    AiGridColumn? sortCol;
    AiGridColumn? filterCol;

    for (final col in cols) {
      if (numCol == null &&
          (col.type == AiGridColumnType.number ||
              col.type == AiGridColumnType.currency)) {
        numCol = col;
      }
      if (groupCol == null &&
          col.isGroupable &&
          col.type == AiGridColumnType.text) {
        groupCol = col;
      }
      if (sortCol == null && col.isSortable) {
        sortCol = col;
      }
      if (filterCol == null &&
          col.isFilterable &&
          col.type == AiGridColumnType.text) {
        filterCol = col;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _buildChip(context, '💡 Help', () {
            final examples = <String>[];
            if (numCol != null) {
              examples.add('• "Calculate average ${numCol.title}"');
            }
            if (groupCol != null) {
              examples.add('• "Group by ${groupCol.title}"');
            }
            if (filterCol != null) {
              examples.add('• "Filter ${filterCol.title} contains [value]"');
            }
            if (sortCol != null) {
              examples.add('• "Sort by ${sortCol.title}"');
            }
            examples.add('• "Reset all filters"');

            setState(() {
              _messages.add(
                _AssistantMessage(
                  title: 'Available Capabilities',
                  description: 'Try asking:\n${examples.join('\n')}',
                ),
              );
            });
            _scrollToBottom();
          }),
          if (numCol != null)
            _buildChip(context, '📊 Avg ${numCol.title}', () {
              final result = widget.controller.calculate(
                field: numCol!.field,
                operation: 'average',
              );
              setState(() {
                _messages.add(
                  _AssistantMessage(
                    title: 'Action: grid_calculate',
                    description:
                        'Average ${numCol!.title}: ${result['result'] ?? result['error']}',
                    isUser: false,
                  ),
                );
              });
              _scrollToBottom();
            }),
          if (groupCol != null)
            _buildChip(context, '🧩 Group by ${groupCol.title}', () {
              _handleQuickAction(
                'Grouped by ${groupCol!.title}',
                () => widget.controller.addGroup(groupCol!.field),
              );
            }),
          if (sortCol != null)
            _buildChip(context, '⬆️ Sort by ${sortCol.title}', () {
              _handleQuickAction(
                'Sorted by ${sortCol!.title}',
                () => widget.controller.setSorting(sortCol!.field),
              );
            }),
          if (filterCol != null)
            _buildChip(context, '🔍 Filter ${filterCol.title}', () {
              _textCtrl.text = 'filter ${filterCol!.title} contains ';
              _textCtrl.selection = TextSelection.fromPosition(
                TextPosition(offset: _textCtrl.text.length),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceContainerHighest
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? colorScheme.outlineVariant.withAlpha(60)
                : AiGridTheme.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildInputBox(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHighest
            : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(
          top: BorderSide(
            color: isDark
                ? colorScheme.outlineVariant.withAlpha(60)
                : AiGridTheme.borderColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textCtrl,
              onSubmitted: (_) => _handleSend(),
              style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant.withAlpha(160),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.mic_none, size: 18),
            onPressed: () {},
            color: colorScheme.onSurfaceVariant,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: _isLoading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  )
                : Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: colorScheme.primary,
                  ),
            onPressed: _isLoading ? null : _handleSend,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
        ],
      ),
    );
  }
}

class _AssistantMessage {
  final String? text;
  final String? title;
  final String? description;
  final bool isUser;
  final bool isSystem;

  _AssistantMessage({
    this.text,
    this.title,
    this.description,
    this.isUser = false,
    this.isSystem = false,
  });
}
