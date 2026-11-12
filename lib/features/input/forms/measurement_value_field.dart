import 'package:blood_pressure_app/theme/app_text.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Large labeled numeric field used by the blood-pressure and weight forms.
class MeasurementValueField extends StatefulWidget {
  /// Create a measurement value field.
  const MeasurementValueField({
    super.key,
    required this.label,
    this.unit,
    this.accent,
    this.controller,
    this.focusNode,
    this.keyboardType = TextInputType.number,
    this.inputFormatters = const [],
    this.onChanged,
    this.validator,
    this.errorText,
    this.textAlign = TextAlign.center,
    this.autofocus = false,
  });

  /// Visible label above the value.
  final String label;

  /// Unit shown under the value.
  final String? unit;

  /// Accent for the label.
  final Color? accent;

  /// Text controller.
  final TextEditingController? controller;

  /// Optional focus node.
  final FocusNode? focusNode;

  /// Keyboard for the value.
  final TextInputType keyboardType;

  /// Input filters.
  final List<TextInputFormatter> inputFormatters;

  /// Called when the value changes.
  final ValueChanged<String>? onChanged;

  /// When set, a [TextFormField] is used.
  final FormFieldValidator<String>? validator;

  /// Error shown on a plain [TextField].
  final String? errorText;

  /// Alignment of the typed value.
  final TextAlign textAlign;

  /// Whether to focus on first build.
  final bool autofocus;

  @override
  State<MeasurementValueField> createState() => _MeasurementValueFieldState();
}

class _MeasurementValueFieldState extends State<MeasurementValueField> {
  bool _dismissReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _dismissReady = true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ring = widget.accent ?? theme.colorScheme.primary;
    final valueStyle = theme.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
      height: 1.1,
      color: theme.colorScheme.onSurface,
    );
    final decoration = InputDecoration(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      isDense: true,
      contentPadding: EdgeInsets.zero,
      hintText: '—',
      hintStyle: valueStyle?.copyWith(color: theme.colorScheme.outline),
      errorText: widget.errorText,
      errorMaxLines: 4,
      errorStyle: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.error,
      ),
    );

    void dismissFocus(PointerDownEvent _) {
      if (!_dismissReady) return;
      FocusScope.of(context).unfocus();
    }

    final field = widget.validator != null
        ? TextFormField(
            focusNode: widget.focusNode,
            controller: widget.controller,
            autofocus: widget.autofocus,
            keyboardType: widget.keyboardType,
            inputFormatters: widget.inputFormatters,
            onChanged: widget.onChanged,
            onTapOutside: dismissFocus,
            validator: widget.validator,
            textAlign: widget.textAlign,
            decoration: decoration,
            style: valueStyle,
          )
        : TextField(
            focusNode: widget.focusNode,
            controller: widget.controller,
            autofocus: widget.autofocus,
            keyboardType: widget.keyboardType,
            inputFormatters: widget.inputFormatters,
            onChanged: widget.onChanged,
            onTapOutside: dismissFocus,
            textAlign: widget.textAlign,
            decoration: decoration,
            style: valueStyle,
          );

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: widget.textAlign == TextAlign.center
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Text(
              widget.label,
              style: AppText.label(context, color: ring),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Semantics(
                label: [widget.label, ?widget.unit].join(', '),
                child: field,
              ),
            ),
          ),
          if (widget.unit != null) ...[
            const SizedBox(height: 2),
            ExcludeSemantics(
              child: Text(widget.unit!, style: AppText.subtitle(context)),
            ),
          ],
        ],
      ),
    );
  }
}
