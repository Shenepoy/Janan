import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/input/forms/entry_form_section.dart';
import 'package:blood_pressure_app/features/input/forms/form_base.dart';
import 'package:blood_pressure_app/features/input/forms/measurement_value_field.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A form to enter [Weight] in the preferred unit.
class WeightForm extends FormBase<Weight> {
  /// Create a form to enter [Weight] in the preferred unit.
  const WeightForm({super.key, super.initialValue});

  @override
  FormStateBase<Weight, WeightForm> createState() => WeightFormState();
}

/// State of a form to enter [Weight] in the preferred unit.
class WeightFormState extends FormStateBase<Weight, WeightForm> {
  final TextEditingController _controller = TextEditingController();

  String? _error;
  String _initialText = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _initialText = _format(widget.initialValue!);
      _controller.text = _initialText;
    }
  }

  String _format(Weight value) =>
      context.readAppSettings().weightUnit.extract(value).toString();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? _parse() =>
      double.tryParse(_controller.text.trim().replaceAll(',', '.'));

  @override
  bool validate() {
    if (_controller.text.isNotEmpty && _parse() == null) {
      setState(() => _error = 'errNaN'.tr());
      return false;
    }
    setState(() => _error = null);
    return true;
  }

  @override
  Weight? save() {
    if ((validate(), _parse()) case (true, final double x)) {
      return context.readAppSettings().weightUnit.store(x);
    }
    return null;
  }

  @override
  bool isEmptyInputFocused() => false;

  @override
  void fillForm(Weight? value) {
    setState(() {
      if (value == null) {
        _controller.text = '';
      } else {
        final w = context.readAppSettings().weightUnit.extract(value);
        _controller.text = w.toString();
      }
    });
  }

  @override
  bool get isEmpty => _controller.text.isEmpty;

  @override
  bool get isDirty => _controller.text != _initialText;

  @override
  Widget build(BuildContext context) {
    final settings = context.readAppSettings();
    return EntryFormSection(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: MeasurementValueField(
        label: 'weight'.tr(),
        unit: settings.weightUnit.displayName,
        controller: _controller,
        errorText: _error,
        autofocus: widget.initialValue == null,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9,.]'))],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    );
  }
}
