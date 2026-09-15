import 'package:blood_pressure_app/features/bluetooth/ui/input_card.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Indication of a failure while taking a bluetooth measurement.
class MeasurementFailure extends StatelessWidget with Loggable {
  /// Indicate a failure while taking a bluetooth measurement.
  const MeasurementFailure({super.key, required this.onTap, required this.reason});

  /// Called when the user requests closing.
  final void Function() onTap;
  /// Likely reason why the measurement failed
  final String reason;

  @override
  Widget build(BuildContext context) {
    logWarning('MeasurementFailure reason: $reason');
    return GestureDetector(
      onTap: onTap,
      child: InputCard(
        onClosed: onTap,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 8,),
              Text('errMeasurementRead'.tr()),
              if (reason.trim().isNotEmpty) ...[
                const SizedBox(height: 8,),
                Text(
                  reason,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 4,),
              Text('tapToClose'.tr()),
              const SizedBox(height: 8,),
            ],
          ),
        ),
      ),
    );
  }
}
