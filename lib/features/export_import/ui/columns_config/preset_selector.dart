import 'package:blood_pressure_app/core/repository/repo_context.dart';
import 'package:blood_pressure_app/features/export_import/model/export_active_preset.dart';
import 'package:blood_pressure_app/features/export_import/model/export_preset.dart';
import 'package:blood_pressure_app/features/settings/tiles/dropdown_list_tile.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';

class PresetSelector extends StatelessWidget {
  const PresetSelector({super.key});

  @override
  Widget build(BuildContext context) => DropDownListTile<String>(
    title: Text('exportFieldsPreset'.tr()),
    value: getPreset(context),
    items: [
      for (final preset in context.exportSettings.allPresets)
        DropdownMenuItem(
          value: preset.id,
          child: Text(preset.localize()),
        ),
    ],
    onChanged: (selectedPreset) {
      if (selectedPreset == null) return;
      setPreset(context, selectedPreset);
    },
  );

  String? getPreset(BuildContext context) => readActivePresetId(context);

  void setPreset(BuildContext context, String presetId) =>
      writeActivePresetId(context, presetId);
}
