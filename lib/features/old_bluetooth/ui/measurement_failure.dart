import 'package:blood_pressure_app/features/old_bluetooth/ui/input_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';

/// Indication of a failure while taking a bluetooth measurement.
class MeasurementFailure extends StatelessWidget {
  /// Indicate a failure while taking a bluetooth measurement.
  const MeasurementFailure({super.key, required this.onTap});

  /// Called when the user requests closing.
  final void Function() onTap;
  
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: InputCard(
      onClosed: onTap,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(height: 8,),
            Text('errMeasurementRead'.tr()),
            const SizedBox(height: 4,),
            Text('tapToClose'.tr()),
            const SizedBox(height: 8,),
          ],
        ),
      ),
    ),
  );
  
}
