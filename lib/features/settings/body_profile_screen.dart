import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/features/settings/settings_subpage.dart';
import 'package:blood_pressure_app/features/settings/tiles/dropdown_list_tile.dart';
import 'package:blood_pressure_app/model/body_sex.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:material_ui/material_ui.dart';

/// Height, age, sex, and athlete mode used for scale body composition.
class BodyProfileScreen extends ConsumerWidget {
  /// Create a screen to edit the body-composition profile.
  const BodyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return SettingsSubpage(
      title: Text('bodyProfile'.tr()),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Icon(
                    Icons.accessibility_new_rounded,
                    size: 32,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'bodyProfileIntro'.tr(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'bodyProfileAutoSave'.tr(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SettingsPageCard(
          sectionId: 'body-profile-details',
          title: 'bodyProfileDetails'.tr(),
          icon: Icons.person_outline,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final fields = [
                    _NumberTile(
                      key: const ValueKey('body-height'),
                      icon: Icons.height,
                      label: 'bodyHeightCm'.tr(),
                      value: settings.bodyHeightCm,
                      onChanged: (value) =>
                          ref.updateSetting(bodyHeightCmSetting, value ?? 0),
                    ),
                    _NumberTile(
                      key: const ValueKey('body-birth-year'),
                      icon: Icons.cake_outlined,
                      label: 'birthYear'.tr(),
                      value: settings.birthYear?.toDouble(),
                      integer: true,
                      onChanged: (value) => ref.updateSetting(
                        birthYearSetting,
                        value?.round() ?? 0,
                      ),
                    ),
                  ];
                  if (constraints.maxWidth >= 480 &&
                      MediaQuery.textScalerOf(context).scale(16) <= 24) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: fields[0]),
                        const SizedBox(width: 16),
                        Expanded(child: fields[1]),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      fields[0],
                      const SizedBox(height: 16),
                      fields[1],
                    ],
                  );
                },
              ),
            ),
            DropDownListTile<BodySex?>(
              leading: const Icon(Icons.wc),
              title: Text('bodySex'.tr()),
              value: settings.bodySex,
              items: [
                DropdownMenuItem(
                  value: BodySex.female,
                  child: Text('bodySexFemale'.tr()),
                ),
                DropdownMenuItem(
                  value: BodySex.male,
                  child: Text('bodySexMale'.tr()),
                ),
              ],
              onChanged: (value) {
                if (value != null) ref.setBodySex(value);
              },
            ),
          ],
        ),
        SettingsPageCard(
          sectionId: 'body-profile-estimates',
          title: 'bodyProfileEstimates'.tr(),
          icon: Icons.monitor_weight_outlined,
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.directions_run),
              title: Text('athleteMode'.tr()),
              subtitle: Text('athleteModeDesc'.tr()),
              value: settings.athleteMode,
              onChanged: (value) =>
                  ref.updateSetting(athleteModeSetting, value),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'bodyCompositionEstimated'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NumberTile extends StatefulWidget {
  const _NumberTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.integer = false,
  });

  final IconData icon;
  final String label;
  final double? value;
  final bool integer;
  final ValueChanged<double?> onChanged;

  @override
  State<_NumberTile> createState() => _NumberTileState();
}

class _NumberTileState extends State<_NumberTile> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value == null
          ? ''
          : widget.integer
          ? widget.value!.round().toString()
          : widget.value.toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    decoration: InputDecoration(
      labelText: widget.label,
      prefixIcon: Icon(widget.icon),
      border: const OutlineInputBorder(),
    ),
    keyboardType: TextInputType.numberWithOptions(decimal: !widget.integer),
    inputFormatters: [
      FilteringTextInputFormatter.allow(
        widget.integer ? RegExp(r'[0-9]') : RegExp(r'[0-9,.]'),
      ),
    ],
    onChanged: (text) {
      if (text.isEmpty) {
        widget.onChanged(null);
        return;
      }
      final value = double.tryParse(text.replaceAll(',', '.'));
      if (value != null) widget.onChanged(value);
    },
  );
}
