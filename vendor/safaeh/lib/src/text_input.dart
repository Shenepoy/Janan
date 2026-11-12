import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'adaptive_sheet.dart';
import 'sheet_shell.dart';
import 'theme.dart';

/// Text field + action row used by [showSafaehTextInput].
class SafaehTextInputSheet extends StatefulWidget {
  const SafaehTextInputSheet({
    super.key,
    required this.title,
    required this.doneLabel,
    this.hint,
    this.initialValue = '',
    this.maxLines = 1,
    this.maxLength,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.onChanged,
    this.cancelLabel,
    this.showTitleInBody = true,
    this.titleBuilder,
    this.tabletBreakpoint,
    this.autofocus = true,
    this.validator,
  });

  final String title;
  final String doneLabel;
  final String? hint;
  final String initialValue;
  final int maxLines;
  final int? maxLength;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool autocorrect;
  final bool enableSuggestions;
  final ValueChanged<String>? onChanged;
  final String? cancelLabel;
  final bool showTitleInBody;
  final SafaehTitleBuilder? titleBuilder;
  final double? tabletBreakpoint;
  final bool autofocus;

  /// When this returns a string, submission stays open and shows that error.
  final String? Function(String value)? validator;

  @override
  State<SafaehTextInputSheet> createState() => _SafaehTextInputSheetState();
}

class _SafaehTextInputSheetState extends State<SafaehTextInputSheet> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant SafaehTextInputSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    final error = widget.validator?.call(text);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    safaehPop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SafaehTheme.of(context);
    final breakpoint = widget.tabletBreakpoint ?? tokens.tabletBreakpoint;
    final isWide = MediaQuery.sizeOf(context).width >= breakpoint;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    return buildSafaehSheetShell(
      showTitleInBody: widget.showTitleInBody && !isWide,
      title:
          widget.titleBuilder?.call(context, titleStyle) ??
          Text(widget.title, style: titleStyle),
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(tokens.radius),
          border: Border.all(color: cs.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: TextField(
            controller: _controller,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            inputFormatters: widget.inputFormatters,
            autocorrect: widget.obscureText ? false : widget.autocorrect,
            enableSuggestions: widget.obscureText
                ? false
                : widget.enableSuggestions,
            decoration: InputDecoration(
              hintText: widget.hint,
              errorText: _errorText,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            maxLength: widget.maxLength,
            autofocus: widget.autofocus,
            onChanged: (value) {
              if (_errorText != null) setState(() => _errorText = null);
              widget.onChanged?.call(value);
            },
            onSubmitted: (_) => _submit(),
          ),
        ),
      ),
      actions: [
        FilledButton(
          key: const ValueKey('safaeh_text_done'),
          onPressed: _submit,
          child: Text(widget.doneLabel),
        ),
      ],
    );
  }
}

/// Adaptive text field. Returns the trimmed value, or `null` if dismissed.
///
/// Hosts pass [doneLabel] / [cancelLabel] — no `.tr()` here.
Future<String?> showSafaehTextInput({
  required BuildContext context,
  required String title,
  required String doneLabel,
  String? hint,
  String initialValue = '',
  int maxLines = 1,
  int? maxLength,
  bool obscureText = false,
  TextInputType? keyboardType,
  TextInputAction? textInputAction,
  List<TextInputFormatter>? inputFormatters,
  bool autocorrect = true,
  bool enableSuggestions = true,
  ValueChanged<String>? onChanged,
  String? cancelLabel,
  SafaehTitleBuilder? titleBuilder,
  double Function(BuildContext context)? railWidthOf,
  SafaehTransition? fadeScale,
  SafaehTransition? slideUp,
  SafaehPhoneSheetPlacement phonePlacement = SafaehPhoneSheetPlacement.bottom,
  double? tabletBreakpoint,
  Duration? motion,
  Curve? enterCurve,
  Curve? exitCurve,
  double? maxWidth,
  double? maxHeight,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
  bool showTitleInBody = true,
  SafaehRouteOptions? route,
  String? Function(String value)? validator,
}) {
  return showSafaeh<String?>(
    context: context,
    title: title,
    titleBuilder: titleBuilder,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    barrierDismissible: barrierDismissible,
    tabletBreakpoint: tabletBreakpoint,
    motion: motion,
    enterCurve: enterCurve,
    exitCurve: exitCurve,
    railWidthOf: railWidthOf,
    fadeScale: fadeScale,
    slideUp: slideUp,
    phonePlacement: phonePlacement,
    useRootNavigator: useRootNavigator,
    paintPhoneTitle: !showTitleInBody,
    route: route,
    child: SafaehTextInputSheet(
      title: title,
      doneLabel: doneLabel,
      hint: hint,
      initialValue: initialValue,
      maxLines: maxLines,
      maxLength: maxLength,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      onChanged: onChanged,
      cancelLabel: cancelLabel,
      showTitleInBody: showTitleInBody,
      titleBuilder: titleBuilder,
      tabletBreakpoint: tabletBreakpoint,
      validator: validator,
    ),
  );
}
