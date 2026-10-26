import 'package:blood_pressure_app/components/form_bottom_action.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/input/forms/entry_form_section.dart';
import 'package:blood_pressure_app/features/settings/tiles/color_picker_list_tile.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safaeh/safaeh.dart';

/// Full-page editor for a [Medicine].
class AddMedicationDialog extends ConsumerStatefulWidget {
  /// Create a dialog to enter values for a [Medicine].
  const AddMedicationDialog({super.key, this.initialValue});

  /// Medicine to use to prefill input fields.
  final Medicine? initialValue;

  @override
  ConsumerState<AddMedicationDialog> createState() =>
      _AddMedicationDialogState();
}

class _AddMedicationDialogState extends ConsumerState<AddMedicationDialog> {
  final formKey = GlobalKey<FormState>();
  final nameFocusNode = FocusNode();

  Color _color = Colors.transparent;

  String? _designation;

  /// Selected default dose amount in the chosen medication unit.
  double? _defaultDosis;

  MedicationUnit _unit = MedicationUnit.mg;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _color = Color(widget.initialValue!.color ?? 0);
      _designation = widget.initialValue!.designation;
      _defaultDosis = widget.initialValue!.dosis?.mg;
      _unit = widget.initialValue!.unit;
    }
    nameFocusNode.requestFocus();
  }

  @override
  void dispose() {
    nameFocusNode.dispose();
    super.dispose();
  }

  void _save() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    formKey.currentState?.save();
    final name = _designation?.trim() ?? '';
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      Medicine(
        designation: name,
        color: _color.toARGB32(),
        dosis: _defaultDosis == null ? null : Weight.mg(_defaultDosis!),
        unit: _unit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomClearance =
        FormBottomAction.clearance + MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          widget.initialValue == null
              ? 'addMedication'.tr()
              : 'editMedication'.tr(),
        ),
      ),
      body: FormBottomAction.overlay(
        label: 'saveMedication'.tr(),
        icon: const Icon(Icons.check),
        onPressed: _save,
        body: Form(
          key: formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 10, 16, bottomClearance),
            children: [
              EntryFormSection(
                title: 'reminderMedicineSection'.tr(),
                child: Column(
                  children: [
                    TextFormField(
                      focusNode: nameFocusNode,
                      decoration: InputDecoration(
                        labelText: 'name'.tr(),
                        hintText: 'medicationNameHint'.tr(),
                        helperText: 'medicationNameHelper'.tr(),
                        helperMaxLines: 3,
                      ),
                      initialValue: _designation,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'errNameRequired'.tr();
                        }
                        return null;
                      },
                      onSaved: (value) => _designation = value?.trim(),
                    ),
                    const SizedBox(height: 16),
                    ColorSelectionListTile(
                      title: Text('color'.tr()),
                      showQuickColors: true,
                      showTransparentColor: false,
                      onMainColorChanged: (value) => setState(() {
                        _color = value;
                      }),
                      initialColor: _color,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'defaultDosis'.tr(),
                        hintText: formatDoseAmount(1),
                        helperText: 'defaultDosisHint'.tr(),
                        helperMaxLines: 3,
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 92,
                        ),
                        suffixIcon: Semantics(
                          label: 'medicationUnit'.tr(),
                          button: true,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(end: 4),
                            child: SafaehAnchoredDropdownChip<MedicationUnit>(
                              key: const ValueKey('medication-unit-dropdown'),
                              icon: Icons.straighten,
                              label: _unit.labelKey.tr(),
                              selected: _unit,
                              options: [
                                for (final unit in MedicationUnit.values)
                                  SafaehDropdownOption(
                                    value: unit,
                                    label: unit.labelKey.tr(),
                                  ),
                              ],
                              onSelected: (unit) =>
                                  setState(() => _unit = unit),
                            ),
                          ),
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'([0-9]+(\.([0-9]*))?)'),
                        ),
                      ],
                      initialValue: _defaultDosis?.toString(),
                      onSaved: (value) => _defaultDosis =
                          double.tryParse(value ?? '') ??
                          int.tryParse(value ?? '')?.toDouble(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens a medicine editor page and returns the saved values to its caller.
Future<Medicine?> showAddMedicineDialog(
  BuildContext context, {
  Medicine? initialValue,
}) => Navigator.push<Medicine>(
  context,
  MaterialPageRoute<Medicine>(
    builder: (_) => AddMedicationDialog(initialValue: initialValue),
  ),
);
