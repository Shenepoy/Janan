import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/input/forms/entry_form_section.dart';
import 'package:blood_pressure_app/features/input/forms/form_base.dart';
import 'package:blood_pressure_app/features/input/forms/measurement_value_field.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Form to enter freeform text and select color.
class BloodPressureForm
    extends FormBase<({int? sys, int? dia, int? pul, BloodPressureArm? arm})> {
  /// Create form to enter freeform text and select color.
  const BloodPressureForm({super.key, super.initialValue});

  @override
  BloodPressureFormState createState() => BloodPressureFormState();
}

/// State of form to enter freeform text and select color.
class BloodPressureFormState
    extends
        FormStateBase<
          ({int? sys, int? dia, int? pul, BloodPressureArm? arm}),
          BloodPressureForm
        > {
  final _formKey = GlobalKey<FormState>();

  final _sysFocusNode = FocusNode();
  final _diaFocusNode = FocusNode();
  final _pulFocusNode = FocusNode();

  late final TextEditingController _sysController;
  late final TextEditingController _diaController;
  late final TextEditingController _pulController;
  BloodPressureArm? _arm;

  @override
  void initState() {
    super.initState();
    _sysController = TextEditingController(
      text: widget.initialValue?.sys?.toString() ?? '',
    );
    _diaController = TextEditingController(
      text: widget.initialValue?.dia?.toString() ?? '',
    );
    _pulController = TextEditingController(
      text: widget.initialValue?.pul?.toString() ?? '',
    );
    _arm = widget.initialValue?.arm;
    if (_focusSysOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sysFocusNode.requestFocus();
      });
    }
  }

  bool get _focusSysOnOpen =>
      widget.initialValue?.dia == null && widget.initialValue?.pul == null;

  @override
  void dispose() {
    _sysFocusNode.dispose();
    _diaFocusNode.dispose();
    _pulFocusNode.dispose();
    _sysController.dispose();
    _diaController.dispose();
    _pulController.dispose();
    super.dispose();
  }

  @override
  bool validate() {
    if (_sysController.text.isEmpty &&
        _diaController.text.isEmpty &&
        _pulController.text.isEmpty) {
      return true;
    }
    return _formKey.currentState?.validate() ?? false;
  }

  @override
  ({int? sys, int? dia, int? pul, BloodPressureArm? arm})? save() {
    if (!validate() ||
        (int.tryParse(_sysController.text) == null &&
            int.tryParse(_diaController.text) == null &&
            int.tryParse(_pulController.text) == null)) {
      return null;
    }
    return (
      sys: int.tryParse(_sysController.text),
      dia: int.tryParse(_diaController.text),
      pul: int.tryParse(_pulController.text),
      arm: _arm,
    );
  }

  @override
  bool isEmptyInputFocused() =>
      (_diaFocusNode.hasFocus && _diaController.text.isEmpty) ||
      (_pulFocusNode.hasFocus && _pulController.text.isEmpty);

  @override
  void fillForm(
    ({int? dia, int? pul, int? sys, BloodPressureArm? arm})? value,
  ) => setState(() {
    if (value == null) {
      _sysController.text = '';
      _diaController.text = '';
      _pulController.text = '';
      _arm = null;
    } else {
      if (value.dia != null) _diaController.text = value.dia.toString();
      if (value.pul != null) _pulController.text = value.pul.toString();
      if (value.sys != null) _sysController.text = value.sys.toString();
      _arm = value.arm;
    }
  });

  @override
  bool get isEmpty =>
      (_sysController.text.isEmpty &&
      _diaController.text.isEmpty &&
      _pulController.text.isEmpty);

  @override
  bool get isDirty =>
      _sysController.text != _text(widget.initialValue?.sys) ||
      _diaController.text != _text(widget.initialValue?.dia) ||
      _pulController.text != _text(widget.initialValue?.pul) ||
      _arm != widget.initialValue?.arm;

  String _text(int? value) => value?.toString() ?? '';

  Widget _buildValueInput({
    required String labelText,
    required Color accent,
    String? unit,
    FocusNode? focusNode,
    TextEditingController? controller,
    String? Function(String?)? validator,
    bool autofocus = false,
  }) => Expanded(
    child: MeasurementValueField(
      label: labelText,
      unit: unit,
      accent: accent,
      textAlign: TextAlign.start,
      autofocus: autofocus,
      focusNode: focusNode,
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (String value) {
        if (value.isNotEmpty && (int.tryParse(value) ?? -1) > 40) {
          FocusScope.of(context).nextFocus();
        }
      },
      validator: (String? value) {
        final settings = context.readAppSettings();
        if (!settings.allowMissingValues &&
            (value == null || value.isEmpty || int.tryParse(value) == null)) {
          return 'errNaN'.tr();
        } else if (settings.validateInputs &&
            (int.tryParse(value ?? '') ?? -1) <= 30) {
          return 'errLt30'.tr();
        } else if (settings.validateInputs &&
            (int.tryParse(value ?? '') ?? 0) >= 400) {
          // https://pubmed.ncbi.nlm.nih.gov/7741618/
          return 'errUnrealistic'.tr();
        }
        return validator?.call(value);
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final settings = context.readAppSettings();
    const unit = 'mmHg';
    return Form(
      key: _formKey,
      child: EntryFormSection(
        title: 'bloodPressure'.tr(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildValueInput(
                  focusNode: _sysFocusNode,
                  controller: _sysController,
                  labelText: 'sysLong'.tr(),
                  accent: settings.sysColor,
                  unit: unit,
                  autofocus: _focusSysOnOpen,
                ),
                const SizedBox(width: 12),
                _buildValueInput(
                  labelText: 'diaLong'.tr(),
                  controller: _diaController,
                  focusNode: _diaFocusNode,
                  accent: settings.diaColor,
                  unit: unit,
                  validator: (value) {
                    if (settings.validateInputs &&
                        (int.tryParse(value ?? '') ?? 0) >=
                            (int.tryParse(_sysController.text) ?? 1)) {
                      return 'errDiaGtSys'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(width: 12),
                _buildValueInput(
                  controller: _pulController,
                  focusNode: _pulFocusNode,
                  labelText: 'pulLong'.tr(),
                  accent: settings.pulColor,
                  unit: 'bpm',
                ),
              ],
            ),
            if (settings.trackArmSide) ...[
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('whichArm'.tr()),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('leftArm'.tr()),
                    selected: _arm == BloodPressureArm.left,
                    onSelected: (_) =>
                        setState(() => _arm = BloodPressureArm.left),
                  ),
                  ChoiceChip(
                    label: Text('rightArm'.tr()),
                    selected: _arm == BloodPressureArm.right,
                    onSelected: (_) =>
                        setState(() => _arm = BloodPressureArm.right),
                  ),
                  ChoiceChip(
                    label: Text('armUnknown'.tr()),
                    selected: _arm == BloodPressureArm.unknown,
                    onSelected: (_) =>
                        setState(() => _arm = BloodPressureArm.unknown),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
