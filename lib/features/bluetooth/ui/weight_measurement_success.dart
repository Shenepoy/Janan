import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_weight_data.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/eufy_body_composition.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/input_card.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/body_profile_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Indication of a successful scale reading.
class WeightMeasurementSuccess extends ConsumerWidget {
  /// Indicate a successful weight measurement.
  const WeightMeasurementSuccess({
    super.key,
    required this.onTap,
    required this.data,
  });

  /// Weight decoded from the scale.
  final BleWeightData data;

  /// Called when the user requests closing.
  final void Function() onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final unit = settings.weightUnit;
    final value = unit.extract(data.asBodyweightRecord().weight);
    final composition = EufyBodyComposition.fromRecord(
      data.asBodyweightRecord(),
      settings,
    );
    return GestureDetector(
      onTap: onTap,
      child: InputCard(
        onClosed: onTap,
        child: Center(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Icon(Icons.done, color: Colors.green),
              const SizedBox(height: 8),
              Text(
                'measurementSuccess'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.scale),
                title: Text('weight'.tr()),
                subtitle: Text('${value.toStringAsFixed(1)} ${unit.displayName}'),
              ),
              if (composition != null) ...[
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text('bodyCompositionEstimated'.tr()),
                ),
                ListTile(
                  leading: const Icon(Icons.pie_chart_outline),
                  title: Text('bodyFat'.tr()),
                  subtitle: Text('${composition.bodyFatPercent.toStringAsFixed(1)} %'),
                ),
                ListTile(
                  leading: const Icon(Icons.fitness_center),
                  title: Text('muscleMass'.tr()),
                  subtitle: Text('${composition.muscleKg.toStringAsFixed(1)} kg'),
                ),
                ListTile(
                  leading: const Icon(Icons.accessibility),
                  title: Text('boneMass'.tr()),
                  subtitle: Text('${composition.boneKg.toStringAsFixed(1)} kg'),
                ),
                ListTile(
                  leading: const Icon(Icons.water_drop_outlined),
                  title: Text('bodyWater'.tr()),
                  subtitle: Text('${composition.waterPercent.toStringAsFixed(1)} %'),
                ),
                ListTile(
                  leading: const Icon(Icons.monitor_weight_outlined),
                  title: Text('leanBodyMass'.tr()),
                  subtitle: Text('${composition.lbmKg.toStringAsFixed(1)} kg'),
                ),
                ListTile(
                  leading: const Icon(Icons.local_fire_department_outlined),
                  title: Text('bmr'.tr()),
                  subtitle: Text('${composition.bmrKcal} kcal'),
                ),
              ] else if (data.impedance != null && !settings.hasBodyProfile)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text('bodyProfileIncomplete'.tr()),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute<void>(builder:
                        (context) => const BodyProfileScreen()));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
