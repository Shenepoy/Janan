import 'package:blood_pressure_app/features/input/forms/entry_form_section.dart';
import 'package:blood_pressure_app/features/input/forms/form_base.dart';
import 'package:blood_pressure_app/features/settings/tiles/color_picker_list_tile.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Form to enter freeform text and select color.
class NoteForm extends FormBase<(String?, Color?)> {
  /// Create form to enter freeform text and select color.
  const NoteForm({super.key, super.initialValue});

  @override
  NoteFormState createState() => NoteFormState();
}

/// State of form to enter freeform text and select color.
class NoteFormState extends FormStateBase<(String?, Color?), NoteForm> {
  late final TextEditingController _controller;

  final FocusNode _focusNode = FocusNode();

  Color? _color;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue?.$1);
    _color = widget.initialValue?.$2;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  bool validate() => true;

  @override
  (String?, Color?)? save() {
    final String? text = _controller.text.isEmpty ? null : _controller.text;
    if (text == null && _color == null) return null;
    return (text, _color);
  }

  @override
  bool isEmptyInputFocused() => _focusNode.hasFocus && _controller.text.isEmpty;

  @override
  void fillForm((String?, Color?)? value) => setState(() {
    if (value == null) {
      _controller.text = '';
      _color = null;
    } else {
      if (value.$1 != null) _controller.text = value.$1!;
      if (value.$2 != null) _color = value.$2!;
    }
  });

  @override
  bool get isEmpty => _controller.text.isEmpty;

  @override
  bool get isDirty =>
      _controller.text != (widget.initialValue?.$1 ?? '') ||
      _color != widget.initialValue?.$2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EntryFormSection(
      title: 'addNote'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: TextFormField(
              focusNode: _focusNode,
              controller: _controller,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: '—',
                hintStyle: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              minLines: 1,
              maxLines: 4,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 8),
          Theme(
            data: theme.copyWith(
              listTileTheme: const ListTileThemeData(
                dense: true,
                minVerticalPadding: 0,
                contentPadding: EdgeInsets.zero,
                horizontalTitleGap: 12,
              ),
            ),
            child: ColorSelectionListTile(
              title: Text(
                'color'.tr(),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              swatchAtEnd: true,
              showQuickColors: true,
              onMainColorChanged: (Color value) => setState(() {
                _color = (value == Colors.transparent) ? null : value;
              }),
              initialColor: _color ?? Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
