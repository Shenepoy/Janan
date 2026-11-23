import 'package:blood_pressure_app/features/health_tools/health_tool_kind.dart';
import 'package:blood_pressure_app/features/health_tools/health_tool_screen.dart';
import 'package:blood_pressure_app/features/health_tools/health_tools_strings.dart';
import 'package:blood_pressure_app/features/nutrition/nutrition_screen.dart';
import 'package:blood_pressure_app/features/nutrition/nutrition_strings.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

class HealthToolsScreen extends ConsumerWidget {
  const HealthToolsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text('tools.title'.toolTr(context))),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('tools.local'.toolTr(context)),
          ),
          if (settings.nutritionEnabled)
            ListTile(
              leading: Icon(
                settings.foodTrackingEnabled
                    ? Symbols.grocery
                    : Icons.local_drink_outlined,
              ),
              title: Text(
                nutritionTitle(
                  context,
                  food: settings.foodTrackingEnabled,
                  water: settings.waterTrackingEnabled,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const NutritionScreen(),
                ),
              ),
            ),
          for (final kind in HealthToolKind.values.where(
            (kind) =>
                kind != HealthToolKind.foodDiary &&
                kind != HealthToolKind.waterDiary,
          ))
            ListTile(
              leading: Icon(switch (kind) {
                HealthToolKind.foodDiary => Symbols.grocery,
                HealthToolKind.waterDiary => Icons.water_drop_outlined,
                HealthToolKind.labObservation => Icons.science_outlined,
                HealthToolKind.diaryContext => Icons.edit_note,
                HealthToolKind.refillAdjustment => Icons.medication_outlined,
                HealthToolKind.personalTarget => Icons.track_changes,
                HealthToolKind.emergencyCard =>
                  Icons.contact_emergency_outlined,
                HealthToolKind.measurementSession => Icons.timer_outlined,
              }),
              title: Text('tools.${kind.name}'.toolTr(context)),
              subtitle: Text('tools.hints.${kind.name}'.toolTr(context)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => HealthToolScreen(kind: kind),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
