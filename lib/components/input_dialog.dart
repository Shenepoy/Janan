import 'package:blood_pressure_app/core/layout/responsive_sheet.dart';
import 'package:blood_pressure_app/core/widgets/app_sheet.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safaeh/safaeh.dart';

/// Creates a dialog for prompting a single user input.
Future<String?> showInputDialog(
  BuildContext context, {
  String? hintText,
  String? initialValue,
}) async => showAppTextInput(
  context: context,
  title: hintText ?? 'addNote'.tr(),
  hint: hintText,
  initialValue: initialValue ?? '',
  doneLabel: 'btnConfirm'.tr(),
);

/// Creates a dialog that only allows int and double inputs.
Future<double?> showNumberInputDialog(
  BuildContext context, {
  String? hintText,
  num? initialValue,
}) async {
  final result = await showAppTextInput(
    context: context,
    title: hintText ?? 'errNoValue'.tr(),
    hint: hintText,
    initialValue: initialValue?.toString() ?? '',
    doneLabel: 'btnConfirm'.tr(),
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp(r'([0-9]+(\.([0-9]*))?)')),
    ],
    validator: (text) {
      double? value = double.tryParse(text);
      value ??= int.tryParse(text)?.toDouble();
      if (text.isEmpty || value == null) {
        return 'errNaN'.tr();
      }
      return null;
    },
  );

  double? value = double.tryParse(result ?? '');
  value ??= int.tryParse(result ?? '')?.toDouble();
  return value;
}

/// Adaptive single-value editor using the same pinned action as larger forms.
Future<String?> showAppTextInput({
  required BuildContext context,
  required String title,
  required String doneLabel,
  String? hint,
  String initialValue = '',
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
  String? Function(String)? validator,
}) => showResponsiveSheet<String>(
  context: context,
  title: title,
  child: AppTextInputSheet(
    initialValue: initialValue,
    hint: hint,
    doneLabel: doneLabel,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    validator: validator,
  ),
);

class AppTextInputSheet extends StatefulWidget {
  const AppTextInputSheet({
    super.key,
    required this.initialValue,
    required this.doneLabel,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });
  final String initialValue, doneLabel;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String)? validator;
  @override
  State<AppTextInputSheet> createState() => _AppTextInputSheetState();
}

class _AppTextInputSheetState extends State<AppTextInputSheet> {
  late final _controller = TextEditingController(text: widget.initialValue);
  String? _error;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    final error = widget.validator?.call(value);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    safaehPop(context, value);
  }

  @override
  Widget build(BuildContext context) => AppSheetBody(
    footer: AppSheetAction(
      buttonKey: const ValueKey('safaeh_text_done'),
      label: widget.doneLabel,
      onPressed: _submit,
    ),
    child: TextField(
      controller: _controller,
      autofocus: true,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: widget.hint,
        errorText: _error,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
      onSubmitted: (_) => _submit(),
    ),
  );
}
