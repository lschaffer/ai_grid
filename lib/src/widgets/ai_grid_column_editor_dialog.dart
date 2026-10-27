import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../controllers/ai_grid_controller.dart';
import '../models/ai_grid_column.dart';
import '../models/ai_grid_editing_options.dart';

/// Modal dialog for modifying dynamic column definitions (name/caption, data type,
/// editability, editor type, required validation rule, and width/maxWidth constraints).
///
/// Restricted to active, non-readonly dynamic DataGrids.
class AiGridColumnEditorDialog extends StatefulWidget {
  final AiGridController controller;
  final String field;

  const AiGridColumnEditorDialog({
    super.key,
    required this.controller,
    required this.field,
  });

  /// Opens the [AiGridColumnEditorDialog] modally.
  /// Returns `true` if the column was updated and saved.
  static Future<bool?> show(
    BuildContext context, {
    required AiGridController controller,
    required String field,
  }) {
    if (controller.activeDynamicDatasource?.isReadonly == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot edit columns on a read-only table.'),
        ),
      );
      return Future.value(false);
    }

    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: const Color(0x80000000),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        Widget content = AiGridColumnEditorDialog(
          controller: controller,
          field: field,
        );

        final hasLoc =
            Localizations.of<MaterialLocalizations>(
              dialogContext,
              MaterialLocalizations,
            ) !=
            null;
        if (!hasLoc) {
          content = Localizations(
            locale: const Locale('en', 'US'),
            delegates: const [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            child: content,
          );
        }

        return SafeArea(child: content);
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<AiGridColumnEditorDialog> createState() =>
      _AiGridColumnEditorDialogState();
}

class _AiGridColumnEditorDialogState extends State<AiGridColumnEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _widthController;
  late final TextEditingController _maxWidthController;

  late AiGridColumnType _selectedType;
  late bool _editable;
  late bool _required;
  AiGridEditorType? _selectedEditorType;
  bool _isSaving = false;

  AiGridColumn? get _existingCol => widget.controller.columns
      .where((c) => c.field == widget.field)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    final col = _existingCol;
    final initialTitle = col?.title ?? widget.field;
    _titleController = TextEditingController(text: initialTitle);

    _selectedType = col?.type ?? AiGridColumnType.text;
    _editable = col?.isEditable ?? true;
    _required = col?.required ?? false;

    _selectedEditorType =
        col?.editorType ?? _defaultEditorForType(_selectedType);

    final w = col?.width;
    _widthController = TextEditingController(
      text: w != null && w > 0 ? w.toStringAsFixed(0) : '',
    );

    final maxW = col?.maxWidth;
    _maxWidthController = TextEditingController(
      text: maxW != null && maxW > 0 ? maxW.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _widthController.dispose();
    _maxWidthController.dispose();
    super.dispose();
  }

  AiGridEditorType _defaultEditorForType(AiGridColumnType type) {
    switch (type) {
      case AiGridColumnType.number:
        return AiGridEditorType.number;
      case AiGridColumnType.currency:
        return AiGridEditorType.currency;
      case AiGridColumnType.date:
        return AiGridEditorType.date;
      case AiGridColumnType.datetime:
        return AiGridEditorType.dateTime;
      case AiGridColumnType.boolean:
        return AiGridEditorType.boolean;
      case AiGridColumnType.select:
        return AiGridEditorType.select;
      case AiGridColumnType.text:
      case AiGridColumnType.sparkline:
        return AiGridEditorType.text;
    }
  }

  List<AiGridEditorType> _compatibleEditorTypes(AiGridColumnType type) {
    switch (type) {
      case AiGridColumnType.number:
      case AiGridColumnType.currency:
        return const [AiGridEditorType.number, AiGridEditorType.currency];
      case AiGridColumnType.date:
        return const [AiGridEditorType.date, AiGridEditorType.dateTime];
      case AiGridColumnType.datetime:
        return const [AiGridEditorType.dateTime, AiGridEditorType.date];
      case AiGridColumnType.boolean:
        return const [AiGridEditorType.boolean];
      case AiGridColumnType.select:
        return const [AiGridEditorType.select, AiGridEditorType.text];
      case AiGridColumnType.text:
      case AiGridColumnType.sparkline:
        return const [AiGridEditorType.text, AiGridEditorType.select];
    }
  }

  String _formatEditorTypeName(AiGridEditorType editorType) {
    switch (editorType) {
      case AiGridEditorType.text:
        return 'Text Input';
      case AiGridEditorType.number:
        return 'Number Input';
      case AiGridEditorType.currency:
        return 'Currency Input (\$)';
      case AiGridEditorType.date:
        return 'Date Picker';
      case AiGridEditorType.dateTime:
        return 'Date & Time Picker';
      case AiGridEditorType.boolean:
        return 'Checkbox Toggle';
      case AiGridEditorType.select:
        return 'Select Dropdown';
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final title = _titleController.text.trim();
    final widthStr = _widthController.text.trim();
    final width = widthStr.isNotEmpty ? double.tryParse(widthStr) : null;
    final maxWStr = _maxWidthController.text.trim();
    final maxWidth = maxWStr.isNotEmpty ? double.tryParse(maxWStr) : null;

    try {
      final success = await widget.controller.updateColumnDefinition(
        field: widget.field,
        title: title,
        type: _selectedType,
        editable: _editable,
        required: _required,
        width: width,
        maxWidth: maxWidth,
        editorType: _editable ? _selectedEditorType : null,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Updated column "$title" successfully.')),
          );
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update column definition.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving column: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final activeDesc = widget.controller.activeDynamicDatasource;

    final compatibleEditors = _compatibleEditorTypes(_selectedType);
    final effectiveEditorType = compatibleEditors.contains(_selectedEditorType)
        ? _selectedEditorType!
        : compatibleEditors.first;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 520,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E24) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: isDark ? const Color(0xFF33333F) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 14, 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Column: ${widget.field}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (activeDesc != null)
                              Text(
                                activeDesc.title,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.textTheme.bodySmall?.color
                                      ?.withValues(alpha: 0.7),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Form Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Column Caption
                        Text(
                          'Column Caption / Header Name *',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            hintText: 'e.g. Valuation (\$M)',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Column caption cannot be empty';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Data Type Dropdown
                        Text(
                          'Data Type',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<AiGridColumnType>(
                          initialValue: _selectedType,
                          decoration: InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: AiGridColumnType.text,
                              child: Text('Text'),
                            ),
                            DropdownMenuItem(
                              value: AiGridColumnType.number,
                              child: Text('Number'),
                            ),
                            DropdownMenuItem(
                              value: AiGridColumnType.date,
                              child: Text('Date'),
                            ),
                            DropdownMenuItem(
                              value: AiGridColumnType.datetime,
                              child: Text('Date & Time'),
                            ),
                            DropdownMenuItem(
                              value: AiGridColumnType.currency,
                              child: Text('Currency'),
                            ),
                            DropdownMenuItem(
                              value: AiGridColumnType.boolean,
                              child: Text('Boolean (True / False)'),
                            ),
                            DropdownMenuItem(
                              value: AiGridColumnType.select,
                              child: Text('Select Options'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null && val != _selectedType) {
                              setState(() {
                                _selectedType = val;
                                _selectedEditorType = _defaultEditorForType(
                                  val,
                                );
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Editable Switch & Editor Type (dependent on data type)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF282832)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF383848)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Allow Editing (Inline & Form)',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Enables inline cell/row editing and form updates',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: theme.colorScheme.outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _editable,
                                    onChanged: (v) =>
                                        setState(() => _editable = v),
                                  ),
                                ],
                              ),
                              if (_editable) ...[
                                const Divider(height: 18),
                                Text(
                                  'Editor Control Type (derived from datatype)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<AiGridEditorType>(
                                  initialValue: effectiveEditorType,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                  items: compatibleEditors.map((e) {
                                    return DropdownMenuItem(
                                      value: e,
                                      child: Text(_formatEditorTypeName(e)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedEditorType = val);
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Validation Rules
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF282832)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF383848)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Required Field (Validation)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Disallows empty or blank values when saving edits',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: theme.colorScheme.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _required,
                                onChanged: (v) => setState(() => _required = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Width & Max Width (Rexz) Constraints
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Default Width (px)',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _widthController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      hintText: 'e.g. 140',
                                      isDense: true,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Max Width (px)',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _maxWidthController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      hintText: 'e.g. 350 (None)',
                                      isDense: true,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 1),

                // Footer Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(_isSaving ? 'Saving...' : 'Save Column'),
                        onPressed: _isSaving ? null : _handleSave,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
