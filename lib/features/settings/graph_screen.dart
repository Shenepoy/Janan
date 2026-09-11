import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/configure_warn_values_screen.dart';
import 'package:blood_pressure_app/features/settings/graph_markings_screen.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/features/settings/tiles/slider_list_tile.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:safaeh/safaeh.dart';

class GraphScreen extends ConsumerWidget {
  const GraphScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text('graphSettings'.tr())),
      body: ListView(
        children: [
          ListTile(
            title: Text('customGraphMarkings'.tr()),
            leading: const Icon(Icons.legend_toggle_outlined),
            trailing: Icon(safaehChevronEnd(context)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const GraphMarkingsScreen(),
                ),
              );
            },
          ),
          SwitchListTile(
            title: Text('drawRegressionLines'.tr()),
            secondary: const Icon(Icons.trending_down_outlined),
            subtitle: Text('drawRegressionLinesDesc'.tr()),
            value: settings.drawRegressionLines,
            onChanged: (value) {
              ref.updateSetting(drawRegressionLinesSetting, value);
            },
          ),
          ListTile(
            leading: const Icon(Icons.warning_amber_outlined),
            title: Text('determineWarnValues'.tr()),
            subtitle: Text('aboutWarnValuesScreenDesc'.tr()),
            trailing: Icon(safaehChevronEnd(context)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const ConfigureWarnValuesScreen(),
                ),
              );
            },
          ),
          SliderListTile(
            title: Text('maxDataInterval'.tr()),
            subtitle: Text('maxDataIntervalDesc'.tr()),
            leading: const Icon(Icons.auto_graph_outlined),
            onChanged: (double value) {
              ref.updateSetting(interruptGraphAfterNDaysSetting, value.toInt());
            },
            value: settings.interruptGraphAfterNDays.toDouble(),
            min: 0,
            max: 30,
          ),
          ColorSettingsTile.fromSetting(
            setting: sysColorSetting,
            title: 'sysColor'.tr(),
            value: settings.sysColor.toARGB32(),
            onChanged: (color) => ref.updateSetting(sysColorSetting, color),
          ),
          ColorSettingsTile.fromSetting(
            setting: diaColorSetting,
            title: 'diaColor'.tr(),
            value: settings.diaColor.toARGB32(),
            onChanged: (color) => ref.updateSetting(diaColorSetting, color),
          ),
          ColorSettingsTile.fromSetting(
            setting: pulColorSetting,
            title: 'pulColor'.tr(),
            value: settings.pulColor.toARGB32(),
            onChanged: (color) => ref.updateSetting(pulColorSetting, color),
          ),
          SliderListTile(
            title: Text('graphLineThickness'.tr()),
            leading: const Icon(Icons.line_weight),
            onChanged: (double value) {
              ref.updateSetting(graphLineThicknessSetting, value);
            },
            value: settings.graphLineThickness,
            min: 1,
            max: 5,
          ),
          SliderListTile(
            title: Text('needlePinBarWidth'.tr()),
            subtitle: Text('needlePinBarWidthDesc'.tr()),
            leading: const Icon(Icons.line_weight),
            onChanged: (double value) {
              ref.updateSetting(needlePinBarWidthSetting, value);
            },
            value: settings.needlePinBarWidth,
            min: 1,
            max: 20,
          ),
        ],
      ),
    );
  }
}
