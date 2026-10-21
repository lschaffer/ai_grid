import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import '../controllers/ai_grid_controller.dart';
import '../models/ai_grid_column.dart';
import '../models/ai_grid_editing_options.dart';

/// Modal popup form dialog for adding or editing rows in [AiGrid].
///
/// Supports DevExtreme-style popup editing with:
/// - Only displaying columns where [AiGridColumn.isEditable] is `true`.
/// - Automatic column ordering via [AiGridColumn.editorIndex].
/// - Flexible form layouts: [AiGridFormLayoutMode.row], [AiGridFormLayoutMode.wrap],
///   [AiGridFormLayoutMode.grid], and [AiGridFormLayoutMode.custom].
/// - Standard Material editors: text, number, currency, date picker, switch/boolean, dropdown/select.
/// - Custom column [AiGridColumn.editorBuilder] overrides.
/// - Validation feedback and [AiGridEditingOptions.beforeSave] lifecycle enforcement.
class AiGridFormDialog extends StatefulWidget {
  final AiGridController controller;
  final String? title;

  const AiGridFormDialog({
    super.key,
    required this.controller,
    this.title,
  });

  /// Opens the [AiGridFormDialog] modally.
  ///
  /// Returns `true` if saved successfully, or `false`/`null` if cancelled.
  static Future<bool?> show(
    BuildContext context, {
    required AiGridController controller,
    String? title,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Dismiss',
      barrierColor: const Color(0x80000000),
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        Widget content = AiGridFormDialog(
          controller: controller,
          title: title,
        );

        final hasLoc = Localizations.of<MaterialLocalizations>(
                dialogContext, MaterialLocalizations) !=
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

        return SafeArea(
          child: content,
        );
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
  State<AiGridFormDialog> createState() => _AiGridFormDialogState();
}

class _AiGridFormDialogState extends State<AiGridFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _textControllers = {};
  bool _isSaving = false;
  String? _generalError;

  @override
  void initState() {
    super.initState();
    _initTextControllers();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _initTextControllers() {
    final draft = widget.controller.draftRow ?? {};
    for (final col in widget.controller.columns) {
      if (col.isEditable) {
        final val = draft[col.field];
        String strVal = '';
        if (val != null) {
          if (val is DateTime) {
            strVal = DateFormat('yyyy-MM-dd').format(val);
          } else {
            strVal = val.toString();
          }
        }
        _textControllers[col.field] = TextEditingController(text: strVal);
      }
    }
  }

  List<AiGridColumn> _getOrderedEditableColumns() {
    final editableCols = widget.controller.columns
        .where((c) => c.isEditable)
        .toList();

    editableCols.sort((a, b) {
      if (a.editorIndex != null && b.editorIndex != null) {
        return a.editorIndex!.compareTo(b.editorIndex!);
      }
      if (a.editorIndex != null) return -1;
      if (b.editorIndex != null) return 1;
      return 0;
    });

    return editableCols;
  }

  AiGridEditorType _resolveEditorType(AiGridColumn col) {
    if (col.editorType != null) return col.editorType!;
    switch (col.type) {
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
        return AiGridEditorType.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final options = widget.controller.editingOptions;
    final draft = widget.controller.draftRow ?? {};
    final isAdding = widget.controller.isAddingRow;

    final dialogTitle = widget.title ??
        options.popupTitle ??
        (isAdding ? 'Add Record' : 'Edit Record');

    final orderedColumns = _getOrderedEditableColumns();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      elevation: 8,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: options.popupWidth,
          maxHeight: options.popupHeight ??
              (MediaQuery.sizeOf(context).height * 0.85),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dialog Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surfaceContainerHighest
                    : const Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? colorScheme.outlineVariant.withAlpha(80)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      dialogTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Close',
                    onPressed: _isSaving ? null : _onCancel,
                  ),
                ],
              ),
            ),

            // Form Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_generalError != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colorScheme.error.withAlpha(120),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 20,
                                color: colorScheme.error,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _generalError!,
                                  style: TextStyle(
                                    color: colorScheme.onErrorContainer,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      _buildFormContent(
                        context,
                        options.formLayout,
                        orderedColumns,
                        draft,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Dialog Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surfaceContainerHighest
                    : const Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? colorScheme.outlineVariant.withAlpha(80)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Cancel'),
                    onPressed: _isSaving ? null : _onCancel,
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(_isSaving ? 'Saving...' : 'Save'),
                    onPressed: _isSaving ? null : _onSave,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormContent(
    BuildContext context,
    AiGridFormLayout layout,
    List<AiGridColumn> columns,
    Map<String, dynamic> draft,
  ) {
    if (layout.mode == AiGridFormLayoutMode.custom && layout.formBuilder != null) {
      return layout.formBuilder!(
        context,
        draft,
        (col, val) => widget.controller.updateDraftValue(col, val),
      );
    }

    final fieldWidgets = columns
        .map((col) => _buildColumnField(context, col, draft))
        .toList();

    switch (layout.mode) {
      case AiGridFormLayoutMode.wrap:
        return Wrap(
          spacing: layout.fieldSpacing,
          runSpacing: layout.rowSpacing,
          children: fieldWidgets
              .map((w) => SizedBox(
                    width: layout.fieldWidth ?? 240.0,
                    child: w,
                  ))
              .toList(),
        );

      case AiGridFormLayoutMode.grid:
        final colsCount = layout.columns ?? 2;
        final rows = <Widget>[];
        for (var i = 0; i < fieldWidgets.length; i += colsCount) {
          final rowChildren = <Widget>[];
          for (var j = 0; j < colsCount; j++) {
            if (j > 0) rowChildren.add(SizedBox(width: layout.fieldSpacing));
            final index = i + j;
            if (index < fieldWidgets.length) {
              rowChildren.add(Expanded(child: fieldWidgets[index]));
            } else {
              rowChildren.add(const Expanded(child: SizedBox()));
            }
          }
          if (rows.isNotEmpty) {
            rows.add(SizedBox(height: layout.rowSpacing));
          }
          rows.add(Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rowChildren,
          ));
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );

      case AiGridFormLayoutMode.row:
      case AiGridFormLayoutMode.custom:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < fieldWidgets.length; i++) ...[
              if (i > 0) SizedBox(height: layout.rowSpacing),
              fieldWidgets[i],
            ],
          ],
        );
    }
  }

  Widget _buildColumnField(
    BuildContext context,
    AiGridColumn col,
    Map<String, dynamic> draft,
  ) {
    final value = draft[col.field];
    final errorText = widget.controller.validationErrors[col.field];

    if (col.editorBuilder != null) {
      return col.editorBuilder!(
        context,
        value,
        (newVal) => widget.controller.updateDraftValue(col.field, newVal),
      );
    }

    final editorType = _resolveEditorType(col);

    switch (editorType) {
      case AiGridEditorType.boolean:
        return _buildBooleanField(context, col, value, errorText);

      case AiGridEditorType.select:
        return _buildSelectField(context, col, value, errorText);

      case AiGridEditorType.date:
      case AiGridEditorType.dateTime:
        return _buildDateField(context, col, value, errorText);

      case AiGridEditorType.currency:
        return _buildCurrencyField(context, col, value, errorText);

      case AiGridEditorType.number:
        return _buildNumberField(context, col, value, errorText);

      case AiGridEditorType.text:
        return _buildTextField(context, col, value, errorText);
    }
  }

  Widget _buildTextField(
    BuildContext context,
    AiGridColumn col,
    dynamic value,
    String? errorText,
  ) {
    final controller = _textControllers[col.field]!;
    final placeholder = col.editorOptions?['placeholder'] as String?;

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: col.title,
        hintText: placeholder,
        border: const OutlineInputBorder(),
        errorText: errorText,
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  controller.clear();
                  widget.controller.updateDraftValue(col.field, null);
                },
              )
            : null,
      ),
      onChanged: (val) {
        widget.controller.updateDraftValue(col.field, val.isEmpty ? null : val);
      },
      validator: col.validator != null ? (v) => col.validator!(v) : null,
    );
  }

  Widget _buildNumberField(
    BuildContext context,
    AiGridColumn col,
    dynamic value,
    String? errorText,
  ) {
    final controller = _textControllers[col.field]!;
    final placeholder = col.editorOptions?['placeholder'] as String?;

    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(
        labelText: col.title,
        hintText: placeholder,
        border: const OutlineInputBorder(),
        errorText: errorText,
      ),
      onChanged: (val) {
        final parsed = num.tryParse(val);
        widget.controller.updateDraftValue(
          col.field,
          parsed ?? (val.isEmpty ? null : val),
        );
      },
      validator: col.validator != null
          ? (v) => col.validator!(num.tryParse(v ?? '') ?? v)
          : null,
    );
  }

  Widget _buildCurrencyField(
    BuildContext context,
    AiGridColumn col,
    dynamic value,
    String? errorText,
  ) {
    final controller = _textControllers[col.field]!;
    final prefix = col.editorOptions?['prefix'] as String? ?? '\$ ';

    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(
        labelText: col.title,
        prefixText: prefix,
        border: const OutlineInputBorder(),
        errorText: errorText,
      ),
      onChanged: (val) {
        final parsed = num.tryParse(val);
        widget.controller.updateDraftValue(
          col.field,
          parsed ?? (val.isEmpty ? null : val),
        );
      },
      validator: col.validator != null
          ? (v) => col.validator!(num.tryParse(v ?? '') ?? v)
          : null,
    );
  }

  Widget _buildDateField(
    BuildContext context,
    AiGridColumn col,
    dynamic value,
    String? errorText,
  ) {
    final controller = _textControllers[col.field]!;
    final isDateTime = col.editorType == AiGridEditorType.dateTime;

    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () => _pickDate(context, col, controller),
      decoration: InputDecoration(
        labelText: col.title,
        border: const OutlineInputBorder(),
        errorText: errorText,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                tooltip: 'Clear',
                onPressed: () {
                  controller.clear();
                  widget.controller.updateDraftValue(col.field, null);
                },
              ),
            IconButton(
              icon: Icon(
                isDateTime
                    ? Icons.access_time_outlined
                    : Icons.calendar_today_outlined,
                size: 18,
              ),
              tooltip: isDateTime ? 'Select Date & Time' : 'Select Date',
              onPressed: () => _pickDate(context, col, controller),
            ),
          ],
        ),
      ),
      validator: col.validator != null ? (v) => col.validator!(v) : null,
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    AiGridColumn col,
    TextEditingController controller,
  ) async {
    final currentVal = widget.controller.draftRow?[col.field];
    DateTime initialDate = DateTime.now();
    if (currentVal is DateTime) {
      initialDate = currentVal;
    } else if (currentVal != null) {
      final parsed = DateTime.tryParse(currentVal.toString());
      if (parsed != null) initialDate = parsed;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      if (col.editorType == AiGridEditorType.dateTime) {
        if (!context.mounted) return;
        final pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(initialDate),
        );
        final dt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          pickedTime?.hour ?? 0,
          pickedTime?.minute ?? 0,
        );
        final formatted = DateFormat('yyyy-MM-dd HH:mm').format(dt);
        controller.text = formatted;
        widget.controller.updateDraftValue(col.field, formatted);
      } else {
        final formatted = DateFormat('yyyy-MM-dd').format(picked);
        controller.text = formatted;
        widget.controller.updateDraftValue(col.field, formatted);
      }
    }
  }

  Widget _buildBooleanField(
    BuildContext context,
    AiGridColumn col,
    dynamic value,
    String? errorText,
  ) {
    final boolVal = value == true || value.toString().toLowerCase() == 'true';
    final theme = Theme.of(context);

    return FormField<bool>(
      initialValue: boolVal,
      validator: col.validator != null ? (v) => col.validator!(v) : null,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: (state.hasError || errorText != null)
                      ? theme.colorScheme.error
                      : theme.colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: SwitchListTile(
                dense: true,
                title: Text(col.title),
                value: boolVal,
                onChanged: (val) {
                  state.didChange(val);
                  widget.controller.updateDraftValue(col.field, val);
                },
              ),
            ),
            if (state.hasError || errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 12),
                child: Text(
                  state.errorText ?? errorText!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSelectField(
    BuildContext context,
    AiGridColumn col,
    dynamic value,
    String? errorText,
  ) {
    final options = <String>[];
    if (col.selectOptions != null) {
      options.addAll(col.selectOptions!);
    } else if (col.editorOptions?['items'] is List) {
      for (final item in col.editorOptions!['items'] as List) {
        options.add(item.toString());
      }
    }

    final strVal = value?.toString();
    final effectiveValue = options.contains(strVal) ? strVal : null;

    return DropdownButtonFormField<String>(
      initialValue: effectiveValue,
      decoration: InputDecoration(
        labelText: col.title,
        border: const OutlineInputBorder(),
        errorText: errorText,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      icon: const Icon(Icons.arrow_drop_down),
      items: options
          .map((opt) => DropdownMenuItem<String>(
                value: opt,
                child: Text(opt),
              ))
          .toList(),
      onChanged: (val) {
        widget.controller.updateDraftValue(col.field, val);
      },
      validator: col.validator != null ? (v) => col.validator!(v) : null,
    );
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSaving = true;
      _generalError = null;
    });

    try {
      final err = await widget.controller.saveEdit();
      if (!mounted) return;
      if (err != null) {
        setState(() {
          _isSaving = false;
          _generalError = err;
        });
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _generalError = e.toString();
      });
    }
  }

  void _onCancel() {
    widget.controller.cancelEdit();
    Navigator.of(context).pop(false);
  }
}
