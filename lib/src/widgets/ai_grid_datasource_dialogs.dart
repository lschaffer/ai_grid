import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../config/ai_grid_dynamic_storage.dart';
import '../controllers/ai_grid_controller.dart';
import '../data/web_table_fetcher.dart';
import '../models/ai_grid_dynamic_datasource.dart';

/// Modal dialog for browsing, loading, exporting, deleting, and importing dynamic DataGrid datasources.
class AiGridDatasourceManagerDialog extends StatefulWidget {
  final AiGridController controller;

  const AiGridDatasourceManagerDialog({super.key, required this.controller});

  static Future<void> show(BuildContext context, AiGridController controller) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AiGridDatasourceManagerDialog(controller: controller),
    );
  }

  @override
  State<AiGridDatasourceManagerDialog> createState() =>
      _AiGridDatasourceManagerDialogState();
}

class _AiGridDatasourceManagerDialogState
    extends State<AiGridDatasourceManagerDialog> {
  List<AiGridDynamicDescriptor> _datasources = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  Future<void> _loadList() async {
    setState(() => _isLoading = true);
    final list = await AiGridDynamicStorage.listDatasources();
    if (mounted) {
      setState(() {
        _datasources = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLoad(AiGridDynamicDescriptor desc) async {
    final model = await AiGridDynamicStorage.getModel(desc.name);
    final rows = await AiGridDynamicStorage.getDataRows(desc.name);

    if (model != null && rows != null && mounted) {
      widget.controller.loadDynamicDatasource(desc, model.toColumns(), rows);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Loaded datasource "${desc.title}" (${rows.length} rows)',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleDelete(AiGridDynamicDescriptor desc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Datasource'),
        content: Text(
          'Are you sure you want to delete "${desc.title}" (${desc.name})? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AiGridDynamicStorage.deleteDatasource(desc.name);
      await _loadList();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Deleted "${desc.name}"')));
      }
    }
  }

  Future<void> _handleExportYaml(AiGridDynamicDescriptor desc) async {
    final yamlString = await AiGridDynamicStorage.exportBundleYaml(desc.name);
    if (yamlString != null && mounted) {
      try {
        final bytes = utf8.encode(yamlString);
        String? savedPath;
        try {
          savedPath = await FileSaver.instance.saveAs(
            name: '${desc.name}.agrid',
            bytes: Uint8List.fromList(bytes),
            fileExtension: 'yaml',
            mimeType: MimeType.other,
            dialogTitle: 'Save Dynamic Grid YAML Bundle',
          );
        } catch (_) {
          savedPath = await FileSaver.instance.saveFile(
            name: '${desc.name}.agrid',
            fileExtension: 'yaml',
            bytes: Uint8List.fromList(bytes),
            mimeType: MimeType.other,
          );
        }
        if (mounted) {
          final msg = (savedPath != null && savedPath.isNotEmpty)
              ? 'Saved to: $savedPath'
              : 'Exported "${desc.name}" bundle as YAML.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
      } catch (_) {
        await Clipboard.setData(ClipboardData(text: yamlString));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copied YAML bundle to clipboard.')),
          );
        }
      }
    }
  }

  Future<void> _handleImportYaml() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['yaml', 'yml', 'json', 'agrid'],
      );

      if (file != null) {
        final content = await file.xFile.readAsString();

        if (content.isNotEmpty) {
          final desc = await AiGridDynamicStorage.importBundleYaml(content);
          await _loadList();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Imported dynamic datasource "${desc.title}"!'),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeName = widget.controller.activeDynamicDatasource?.name;

    final filtered = _datasources.where((d) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return d.name.toLowerCase().contains(q) ||
          d.title.toLowerCase().contains(q) ||
          d.sourceType.toLowerCase().contains(q);
    }).toList();

    final isMobile = MediaQuery.sizeOf(context).width < 600;

    final bodyContent = Column(
      children: [
        // Search Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search datasources...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
            ),

            // Body List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 48,
                            color: theme.disabledColor,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No saved dynamic datasources found.'
                                : 'No datasources match "$_searchQuery".',
                            style: TextStyle(color: theme.disabledColor),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final d = filtered[index];
                        final isActive = d.name == activeName;

                        return Card(
                          elevation: isActive ? 2 : 0,
                          color: isActive
                              ? theme.colorScheme.primaryContainer.withValues(
                                  alpha: 0.3,
                                )
                              : (isDark
                                    ? theme.colorScheme.surfaceContainerHighest
                                    : Colors.grey.shade50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isActive
                                  ? theme.colorScheme.primary
                                  : (isDark
                                        ? Colors.white10
                                        : Colors.grey.shade300),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              d.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isActive) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    theme.colorScheme.primary,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'ACTIVE',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        children: [
                                          _chip(d.name, Colors.blueGrey),
                                          _chip(
                                            '${d.rowCount} rows',
                                            Colors.teal,
                                          ),
                                          _chip(
                                            d.sourceType.toUpperCase(),
                                            Colors.indigo,
                                          ),
                                          if (d.isReadonly)
                                            _chip(
                                              'READ-ONLY',
                                              Colors.amber.shade900,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.file_download_outlined,
                                        size: 18,
                                      ),
                                      tooltip: 'Export YAML Bundle',
                                      onPressed: () => _handleExportYaml(d),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: Colors.redAccent,
                                      ),
                                      tooltip: 'Delete Datasource',
                                      onPressed: () => _handleDelete(d),
                                    ),
                                    const SizedBox(width: 4),
                                    FilledButton(
                                      onPressed: isActive
                                          ? null
                                          : () => _handleLoad(d),
                                      child: Text(
                                        isActive ? 'Current' : 'Load',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
      ],
    );

    if (isMobile) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('Dynamic Datasources'),
            actions: [
              IconButton(
                icon: const Icon(Icons.file_upload_outlined),
                tooltip: 'Import YAML',
                onPressed: _handleImportYaml,
              ),
            ],
          ),
          body: bodyContent,
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 600),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.table_view_outlined,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Dynamic Datasources',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.file_upload_outlined, size: 16),
                    label: const Text('Import YAML'),
                    onPressed: _handleImportYaml,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: bodyContent),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Modal dialog for fetching and creating a read-only dynamic DataGrid from an HTTP GET URL.
class AiGridWebDataSourceDialog extends StatefulWidget {
  final AiGridController controller;

  const AiGridWebDataSourceDialog({super.key, required this.controller});

  static Future<void> show(BuildContext context, AiGridController controller) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AiGridWebDataSourceDialog(controller: controller),
    );
  }

  @override
  State<AiGridWebDataSourceDialog> createState() =>
      _AiGridWebDataSourceDialogState();
}

class _AiGridWebDataSourceDialogState extends State<AiGridWebDataSourceDialog> {
  final _urlCtrl = TextEditingController(
    text: 'https://jsonplaceholder.typicode.com/posts',
  );
  final _nameCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;
  WebTableResult? _preview;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAndPreview() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _preview = null;
    });

    try {
      final res = await WebTableFetcher.fetch(url);
      if (!res.hasTableData) {
        setState(() {
          _error = 'URL returned content, but no tabular rows or columns could be detected.';
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _preview = res;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createAndLoad() async {
    if (_preview == null) return;
    final url = _urlCtrl.text.trim();
    final customName = _nameCtrl.text.trim();

    final uri = Uri.parse(url);
    final baseName = customName.isNotEmpty
        ? customName
        : (uri.pathSegments.isNotEmpty ? uri.pathSegments.last : uri.host)
              .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
              .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final name = (baseName.isEmpty ? 'web_data' : baseName).toLowerCase();
    final modelName = '${name}_mdl.yaml';
    final datasourceName = '$name.json';
    final now = DateTime.now();

    final dynamicModel = AiGridDynamicModel(
      modelName: modelName,
      datasourceName: datasourceName,
      title: 'Web: $url',
      isReadonly: true,
      sourceType: 'web',
      sourceOrigin: url,
      createdAt: now,
      columns: _preview!.columns.map((c) => c.copyWith(editable: false)).toList(),
    );

    final descriptor = AiGridDynamicDescriptor(
      name: name,
      modelName: modelName,
      datasourceName: datasourceName,
      title: 'Web: $url',
      sourceType: 'web',
      sourceOrigin: url,
      isReadonly: true,
      createdAt: now,
      updatedAt: now,
      rowCount: _preview!.rows.length,
    );

    await AiGridDynamicStorage.saveDatasource(
      descriptor: descriptor,
      model: dynamicModel,
      rows: _preview!.rows,
    );

    widget.controller.loadDynamicDatasource(
      descriptor,
      dynamicModel.toColumns(),
      _preview!.rows,
    );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Created dynamic grid "$name" (${_preview!.rows.length} rows, Read-only).',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    final formFields = [
      const Text(
        'Enter a public HTTP/HTTPS URL returning tabular JSON array, CSV, or HTML table. Note: Web sources are read-only.',
        style: TextStyle(fontSize: 12),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _urlCtrl,
        decoration: const InputDecoration(
          labelText: 'HTTP GET URL',
          hintText: 'https://api.example.com/data',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _nameCtrl,
        decoration: const InputDecoration(
          labelText: 'Datasource Name (Optional)',
          hintText: 'e.g. posts, user_data',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      const SizedBox(height: 12),
      ElevatedButton.icon(
        icon: _isLoading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.preview_outlined, size: 16),
        label: const Text('Fetch & Inspect'),
        onPressed: _isLoading ? null : _fetchAndPreview,
      ),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(
          _error!,
          style: TextStyle(color: Colors.red.shade700, fontSize: 12),
        ),
      ],
      if (_preview != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(
              alpha: 0.25,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ready: ${_preview!.rows.length} rows, ${_preview!.columns.length} columns detected',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Columns: ${_preview!.columns.map((c) => "${c.field} (${c.type.name})").join(", ")}',
                style: const TextStyle(fontSize: 11),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ];

    if (isMobile) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('New Web Datasource'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton.tonal(
                  onPressed: _preview != null && !_isLoading ? _createAndLoad : null,
                  child: const Text('Create'),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...formFields,
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.table_chart_outlined, size: 18),
                  label: const Text('Create DataGrid'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _preview != null && !_isLoading ? _createAndLoad : null,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.cloud_download_outlined),
          SizedBox(width: 8),
          Text('New Datasource from Web (GET)'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: formFields,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _preview != null && !_isLoading ? _createAndLoad : null,
          child: const Text('Create DataGrid'),
        ),
      ],
    );
  }
}
