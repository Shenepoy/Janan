import 'package:blood_pressure_app/components/fullscreen_dialog.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/input/forms/entry_form_section.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/tiles/color_picker_list_tile.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dialog to enter values for a [Medicine].
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
    final settings = ref.watch(appSettingsProvider);
    return FullscreenDialog(
      actionButtonText: 'btnSave'.tr(),
      onActionButtonPressed: _save,
      bottomAppBar: settings.bottomAppBars,
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
          children: [
            EntryFormSection(
              title: 'addMedication'.tr(),
              child: Column(
                children: [
                  TextFormField(
                    focusNode: nameFocusNode,
                    decoration: InputDecoration(
                      labelText: 'name'.tr(),
                      hintText: 'medicationNameHint'.tr(),
                      helperText: 'medicationNameHelper'.tr(),
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
                      suffixIconConstraints: const BoxConstraints(minWidth: 92),
                      suffixIcon: Semantics(
                        label: 'medicationUnit'.tr(),
                        button: true,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<MedicationUnit>(
                              key: const ValueKey('medication-unit-dropdown'),
                              value: _unit,
                              isDense: true,
                              alignment: AlignmentDirectional.centerEnd,
                              borderRadius: BorderRadius.circular(12),
                              items: [
                                for (final unit in MedicationUnit.values)
                                  DropdownMenuItem<MedicationUnit>(
                                    value: unit,
                                    child: Text(unit.labelKey.tr()),
                                  ),
                              ],
                              onChanged: (unit) {
                                if (unit == null) return;
                                setState(() => _unit = unit);
                              },
                            ),
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
    );
  }
}

/// Shows a full screen dialog to input a medicine.
///
/// The created medicine gets an index that was never in settings.
Future<Medicine?> showAddMedicineDialog(
  BuildContext context, {
  Medicine? initialValue,
}) => showDialog<Medicine?>(
  context: context,
  builder: (context) => AddMedicationDialog(initialValue: initialValue),
);
