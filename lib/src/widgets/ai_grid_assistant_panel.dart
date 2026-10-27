import 'dart:convert';
import 'dart:io' as io;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:dart_mcp_core/dart_mcp_core.dart';
import '../config/ai_grid_config.dart';
import '../controllers/ai_grid_controller.dart';
import '../data/clipboard_content_service.dart';
import '../data/pdf_table_extractor.dart';
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
  final bool dynamicGrid;

  const AiGridAssistantPanel({
    super.key,
    required this.controller,
    this.aiConfig,
    this.onSendPrompt,
    this.embeddedInWindow = false,
    this.isFullScreen = false,
    this.dynamicGrid = false,
  });

  @override
  State<AiGridAssistantPanel> createState() => _AiGridAssistantPanelState();
}

class _AiGridAssistantPanelState extends State<AiGridAssistantPanel> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_AssistantMessage> _messages = [];
  final List<MessageAttachment> _attachments = [];
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

  bool get _isDynamicMode =>
      widget.dynamicGrid ||
      widget.controller.activeDynamicDatasource != null;

  void _initDefaultSuggestions() {
    final llm = widget.aiConfig?.llmConfig ??
        AiGridEnvLoader.createLlmConfigFromEnv();
    final modelName = llm != null && llm.isConfigured
        ? '${llm.provider.displayName} (${llm.model})'
        : 'Local Heuristic';

    final isDynamic = _isDynamicMode;

    final String welcomeDesc;
    if (isDynamic) {
      welcomeDesc =
          'Connected to $modelName.\n\n'
          'You can create and manage DataGrids dynamically:\n'
          '• Attach a file (PDF, CSV, JSON, Markdown, TXT, Word) using 📎 or paste from clipboard (Ctrl+V or 📋) and ask to create a table\n'
          '• Ingest public web APIs (HTTP GET)\n'
          '• Ask me to calculate, filter, sort, group, pivot, or export to Excel.';
    } else {
      welcomeDesc =
          'Connected to $modelName. Ask me to calculate, group, filter, sort, or summarize your data.';
    }

    _messages.add(
      _AssistantMessage(
        title: isDynamic ? 'Dynamic DataGrid Assistant' : 'Assistant Ready',
        description: welcomeDesc,
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

  Future<void> _pickAttachments() async {
    try {
      final files = await FilePicker.pickFiles();
      if (files.isNotEmpty) {
        for (final f in files) {
          Uint8List? bytes;
          try {
            bytes = await f.readAsBytes();
          } catch (_) {
            if (f.path != null && !kIsWeb) {
              final file = io.File(f.path!);
              if (await file.exists()) {
                bytes = await file.readAsBytes();
              }
            }
          }
          final name = f.name;
          final mime = _mimeFromExtension(name);
          _attachments.add(
            MessageAttachment(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              name: name,
              path: f.path ?? '',
              bytes: bytes,
              mimeType: mime,
              size: bytes?.length,
            ),
          );
        }
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Failed to pick files: $e');
    }
  }

  Future<void> _handleClipboardPaste([dynamic directPayloads]) async {
    try {
      List<ClipboardPayload> payloads;
      if (directPayloads is List<ClipboardPayload>) {
        payloads = directPayloads;
      } else {
        payloads = await ClipboardContentService.readClipboard();
      }
      if (payloads.isEmpty) return;

      int addedCount = 0;
      for (final p in payloads) {
        if (p.isMedia && p.bytes != null) {
          _attachments.add(
            MessageAttachment(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              name: p.name,
              path: p.filePath ?? '',
              bytes: p.bytes,
              mimeType: p.mimeType,
              size: p.bytes?.length,
            ),
          );
          addedCount++;
        } else if (p.type == ClipboardContentType.text && p.text != null) {
          final cur = _textCtrl.text;
          _textCtrl.text = cur.isEmpty ? p.text! : '$cur\n${p.text}';
        }
      }

      if (mounted && addedCount > 0) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attached $addedCount item(s) from clipboard'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  static String _mimeFromExtension(String name) {
    final ext = name.split('.').last.toLowerCase();
    const map = <String, String>{
      'txt': 'text/plain',
      'md': 'text/markdown',
      'csv': 'text/csv',
      'tsv': 'text/tab-separated-values',
      'json': 'application/json',
      'yaml': 'text/yaml',
      'yml': 'text/yaml',
      'html': 'text/html',
      'pdf': 'application/pdf',
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'gif': 'image/gif',
      'webp': 'image/webp',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  Future<void> _handleSend() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;

    final attachmentsToSend = List<MessageAttachment>.from(_attachments);
    final displayText = text.isNotEmpty
        ? text
        : 'Attached: ${attachmentsToSend.map((a) => a.name).join(", ")}';

    setState(() {
      _messages.add(_AssistantMessage(text: displayText, isUser: true));
      _isLoading = true;
      _attachments.clear();
    });
    _textCtrl.clear();
    _scrollToBottom();

    try {
      if (widget.onSendPrompt != null) {
        await widget.onSendPrompt!(displayText);
      } else {
        final llm = widget.aiConfig?.llmConfig ??
            AiGridEnvLoader.createLlmConfigFromEnv();

        if (llm != null && llm.isConfigured) {
          await _executeWithAgentsEngine(displayText, attachmentsToSend, llm);
        } else {
          _executeLocalHeuristic(displayText);
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

  Future<void> _executeWithAgentsEngine(
    String prompt,
    List<MessageAttachment> attachments,
    LlmConfig config,
  ) async {
    final parts = <ChatContentPart>[
      TextPart(prompt),
    ];

    final promptBuilder = StringBuffer(prompt);

    for (final att in attachments) {
      if (att.bytes != null && att.bytes!.isNotEmpty) {
        if (att.mimeType.toLowerCase().startsWith('image/')) {
          parts.add(ImagePart.fromBytes(att.bytes!, mimeType: att.mimeType));
        } else {
          String? text;
          try {
            if (att.name.toLowerCase().endsWith('.pdf') ||
                att.mimeType == 'application/pdf') {
              text = PdfTableExtractor.extractText(att.bytes!);
            } else {
              text = utf8.decode(att.bytes!);
            }
          } catch (_) {}

          if (text != null && text.isNotEmpty) {
            promptBuilder.writeln(
              '\n\n--- [Attached Document: ${att.name}] ---\n$text',
            );
          }

          parts.add(DocumentPart(
            bytes: att.bytes,
            fileName: att.name,
            mimeType: att.mimeType,
            textContent: text,
          ));
        }
      }
    }

    final effectivePrompt = promptBuilder.toString();

    final userMsg = ChatMessage.user(
      effectivePrompt,
      parts: parts,
      attachments: attachments,
    );

    final tools = AiGridSkill.createTools(widget.controller);
    final agent = Agent(
      key: 'ai_grid_agent',
      name: 'DataGrid Agent',
      llmConfig: config,
      systemPrompt: widget.aiConfig?.systemPrompt ??
          AiGridSkill.defaultSystemPrompt,
      initialMessages: [userMsg],
      prompts: [
        SubPromptStep(
          text: effectivePrompt,
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

    // Smart Column Heuristic Execution
    if (lower.contains('smart column') ||
        lower.contains('run smart') ||
        lower.contains('synthesize') ||
        lower.contains('evaluate column')) {
      if (widget.controller.smartColumns.isNotEmpty) {
        widget.controller.runSmartColumns(force: true);
        _messages.add(
          _AssistantMessage(
            title: 'AI Smart Columns',
            description:
                'Triggered evaluation for ${widget.controller.smartColumns.length} AI smart columns across all rows.',
            isUser: false,
          ),
        );
        _scrollToBottom();
        return;
      }
    }

    // Cell selection heuristic
    if (lower.startsWith('select') ||
        lower.contains('select ') ||
        lower.contains('selection')) {
      AiGridColumn? targetCol;
      for (final col in widget.controller.columns) {
        if (lower.contains(col.field.toLowerCase()) ||
            lower.contains(col.title.toLowerCase())) {
          targetCol = col;
          break;
        }
      }

      final bool isLow = lower.contains('low') ||
          lower.contains('min') ||
          lower.contains('bottom') ||
          lower.contains('worst');
      final bool isHigh = lower.contains('high') ||
          lower.contains('max') ||
          lower.contains('top') ||
          lower.contains('best');

      if (targetCol != null && (isLow || isHigh)) {
        widget.controller.setSorting(targetCol.field, descending: isHigh);
        const int selectCount = 3;
        final maxRows = widget.controller.rows.length;
        final extent = (selectCount < maxRows ? selectCount : maxRows) - 1;
        if (extent >= 0) {
          widget.controller.selectCellRange(
            anchorRow: 0,
            anchorColumn: targetCol.field,
            extentRow: extent,
            extentColumn: targetCol.field,
          );
          final summary = widget.controller.calculateSelectedRangeSummary();
          _messages.add(
            _AssistantMessage(
              title: 'Cell Range Selection',
              description:
                  'Selected ${isLow ? "lowest" : "highest"} ${extent + 1} cells in "${targetCol.title}".'
                  '\nSum: ${summary?.sum?.toStringAsFixed(2) ?? "0"} | Avg: ${summary?.average?.toStringAsFixed(2) ?? "0"} | Min: ${summary?.min} | Max: ${summary?.max}',
              isUser: false,
            ),
          );
          _scrollToBottom();
          return;
        }
      }

      // Categorical / keyword matching in column (e.g. "Critical", "P1", "Positive", "Negative")
      String? matchedCategory;
      if (targetCol != null) {
        for (final row in widget.controller.rows) {
          final cellStr = row[targetCol.field]?.toString().toLowerCase() ?? '';
          for (final word in lower.split(RegExp(r'\s+'))) {
            final w = word.replaceAll(RegExp(r'[^a-z0-9]'), '');
            if (w.length >= 3 &&
                cellStr.contains(w) &&
                !['select', 'all', 'tickets', 'rows', 'cells', 'the', 'and', 'for', targetCol.field.toLowerCase()].contains(w)) {
              matchedCategory = w;
              break;
            }
          }
          if (matchedCategory != null) break;
        }
      }

      if (targetCol != null && matchedCategory != null) {
        final categoryLower = matchedCategory;
        int matching = 0;
        for (final row in widget.controller.rows) {
          final val = row[targetCol.field]?.toString().toLowerCase() ?? '';
          if (val.contains(categoryLower)) matching++;
        }

        widget.controller.setSorting(targetCol.field, descending: false);
        final selectCount = matching > 0 ? matching : 1;
        final maxRows = widget.controller.rows.length;
        final extent = (selectCount < maxRows ? selectCount : maxRows) - 1;
        if (extent >= 0) {
          final isTicketsOrRows = lower.contains('ticket') || lower.contains('row');
          final cols = widget.controller.columns;
          final startCol = isTicketsOrRows ? cols.first.field : targetCol.field;
          final endCol = isTicketsOrRows ? cols.last.field : targetCol.field;

          widget.controller.selectCellRange(
            anchorRow: 0,
            anchorColumn: startCol,
            extentRow: extent,
            extentColumn: endCol,
          );
          final summary = widget.controller.calculateSelectedRangeSummary();
          _messages.add(
            _AssistantMessage(
              title: 'Cell Range Selection',
              description:
                  'Selected $selectCount ${isTicketsOrRows ? "tickets" : "cells"} matching "$categoryLower" in "${targetCol.title}".'
                  '\nActive selection count: ${summary?.cellCount ?? selectCount}.',
              isUser: false,
            ),
          );
          _scrollToBottom();
          return;
        }
      } else if (lower.contains('all')) {
        final cols = widget.controller.columns;
        final rowCount = widget.controller.rows.length;
        if (cols.isNotEmpty && rowCount > 0) {
          widget.controller.selectCellRange(
            anchorRow: 0,
            anchorColumn: cols.first.field,
            extentRow: rowCount - 1,
            extentColumn: cols.last.field,
          );
          _messages.add(
            _AssistantMessage(
              title: 'Cell Range Selection',
              description: 'Selected all cells across the grid ($rowCount rows).',
              isUser: false,
            ),
          );
          _scrollToBottom();
          return;
        }
      }
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

  void _sendPresetPrompt(String prompt) {
    _textCtrl.text = prompt;
    _handleSend();
  }

  Widget _buildSuggestionChips(BuildContext context) {
    final suggested = widget.aiConfig?.suggestedPrompts;
    final isDynamic = _isDynamicMode;

    if (suggested != null && suggested.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildChip(context, '💡 Help', () {
              final examples = <String>[];
              examples.add('Contextual Suggestions:');
              for (final p in suggested) {
                examples.add('• "$p"');
              }
              examples.add('\nStandard Actions:');
              examples.add('• "Export to Excel"');
              examples.add('• "Reset grid"');

              setState(() {
                _messages.add(
                  _AssistantMessage(
                    title: 'Available Capabilities',
                    description: examples.join('\n'),
                  ),
                );
              });
              _scrollToBottom();
            }),
            if (isDynamic) ...[
              _buildChip(context, '📎 Attach File', _pickAttachments),
              _buildChip(context, '📋 Paste Clipboard', _handleClipboardPaste),
            ],
            for (final prompt in suggested)
              _buildChip(
                context,
                '✨ $prompt',
                () => _sendPresetPrompt(prompt),
              ),
          ],
        ),
      );
    }

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
            if (isDynamic) {
              examples.add('• "Create a table from the attached file"');
              examples.add('• "Extract table from clipboard and name it sales"');
              examples.add('• "Fetch data from https://..."');
            }
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
            examples.add('• "Export to Excel"');
            examples.add('• "Reset grid"');

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
          if (isDynamic) ...[
            _buildChip(context, '📎 Attach File', _pickAttachments),
            _buildChip(context, '📋 Paste Clipboard', _handleClipboardPaste),
          ],
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

  Widget _buildAttachmentPreviews(ThemeData theme) {
    if (_attachments.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.attach_file, size: 12, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                'Attachments (${_attachments.length})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => setState(() => _attachments.clear()),
                child: Text(
                  'Clear all',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _attachments.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 6),
              itemBuilder: (context, idx) {
                final att = _attachments[idx];
                final isImage = att.mimeType.toLowerCase().startsWith('image/');

                return Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: theme.colorScheme.surface,
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: isImage && att.bytes != null
                            ? Image.memory(
                                att.bytes!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => _buildDocIcon(att, theme),
                              )
                            : _buildDocIcon(att, theme),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _attachments.removeAt(idx)),
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocIcon(MessageAttachment att, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insert_drive_file_outlined, size: 20, color: theme.colorScheme.primary),
            const SizedBox(height: 2),
            Text(
              att.name,
              style: const TextStyle(fontSize: 8),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBox(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAttachmentPreviews(theme),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
              IconButton(
                icon: const Icon(Icons.attach_file_outlined, size: 18),
                tooltip: 'Attach Files or Images',
                onPressed: _isLoading ? null : _pickAttachments,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
              IconButton(
                icon: const Icon(Icons.content_paste_go_outlined, size: 18),
                tooltip: 'Paste from Clipboard (Ctrl+V)',
                onPressed: _isLoading ? null : () => _handleClipboardPaste(),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    PasteTextIntent: CallbackAction<PasteTextIntent>(
                      onInvoke: (intent) async {
                        final payloads = await ClipboardContentService.readClipboard();
                        final media = payloads.where((p) => p.isMedia).toList();
                        if (media.isNotEmpty) {
                          _handleClipboardPaste(media);
                          return null;
                        }
                        final data = await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null) {
                          final cur = _textCtrl.text;
                          final sel = _textCtrl.selection;
                          if (sel.isValid) {
                            final newText = cur.replaceRange(sel.start, sel.end, data!.text!);
                            _textCtrl.value = TextEditingValue(
                              text: newText,
                              selection: TextSelection.collapsed(offset: sel.start + data.text!.length),
                            );
                          } else {
                            _textCtrl.text = '$cur${data!.text}';
                          }
                        }
                        return null;
                      },
                    ),
                  },
                  child: TextField(
                    controller: _textCtrl,
                    onSubmitted: (_) => _handleSend(),
                    style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: _isLoading
                          ? 'Assistant is working...'
                          : 'Type a message, paste image/doc (Ctrl+V)...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant.withAlpha(160),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    ),
                  ),
                ),
              ),
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
        ),
      ],
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
