import 'package:blood_pressure_app/features/old_bluetooth/logic/characteristics/ble_measurement_data.dart';
import 'package:blood_pressure_app/features/old_bluetooth/ui/input_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';

/// Indication of a successful bluetooth measurement.
class MeasurementSuccess extends StatelessWidget {
  /// Indicate a successful while taking a bluetooth measurement.
  const MeasurementSuccess({super.key,
    required this.onTap,
    required this.data,
  });

  /// Data decoded from bluetooth.
  final BleMeasurementData data;

  /// Called when the user requests closing.
  final void Function() onTap;
  
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: InputCard(
      onClosed: onTap,
      child: Center(
        child: ListTileTheme(
          data: ListTileThemeData(
            iconColor: Colors.orange,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.done, color: Colors.green),
              const SizedBox(height: 8,),
              Text('measurementSuccess'.tr(),
                style: Theme.of(context).textTheme.titleMedium,),
              const SizedBox(height: 8,),
              ListTile(
                title: Text('meanArterialPressure'.tr()),
                subtitle: Text(data.meanArterialPressure.round().toString()),
              ),
              if (data.userID != null)
                ListTile(
                  title: Text('userID'.tr()),
                  subtitle: Text(data.userID!.toString()),
                ),
              if (data.status?.bodyMovementDetected ?? false)
                ListTile(
                  title: Text('bodyMovementDetected'.tr()),
                  leading: Icon(Icons.directions_walk),
                ),
              if (data.status?.cuffTooLose ?? false)
                ListTile(
                  title: Text('cuffTooLoose'.tr()),
                  leading: Icon(Icons.space_bar),
                ),
              if (data.status?.improperMeasurementPosition ?? false)
                ListTile(
                  title: Text('improperMeasurementPosition'.tr()),
                  leading: Icon(Icons.emoji_people),
                ),
              if (data.status?.irregularPulseDetected ?? false)
                ListTile(
                  title: Text('irregularPulseDetected'.tr()),
                  leading: Icon(Icons.heart_broken),
                ),
              if (data.status?.pulseRateExceedsUpperLimit ?? false)
                ListTile(
                  title: Text('pulseRateExceedsUpperLimit'.tr()),
                  leading: Icon(Icons.monitor_heart),
                ),
              if (data.status?.pulseRateIsLessThenLowerLimit ?? false)
                ListTile(
                  title: Text('pulseRateLessThanLowerLimit'.tr()),
                  leading: Icon(Icons.monitor_heart),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  
}
