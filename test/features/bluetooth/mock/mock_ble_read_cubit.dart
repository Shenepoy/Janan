import 'package:blood_pressure_app/core/state/state_holder.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/ble_read_cubit.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/characteristics/ble_measurement_data.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/characteristics/ble_measurement_status.dart';
import 'package:flutter_test/flutter_test.dart';

class MockBleReadCubit extends StateHolder<BleReadState> with Fake
    implements BleReadCubit {
  MockBleReadCubit(): super(BleReadSuccess(
    BleMeasurementData(
      systolic: 123,
      diastolic: 456,
      pulse: 67,
      meanArterialPressure: 123456,
      isMMHG: true,
      userID: 3,
      status: BleMeasurementStatus(
        bodyMovementDetected: true,
        cuffTooLose: true,
        irregularPulseDetected: true,
        pulseRateInRange: true,
        pulseRateExceedsUpperLimit: true,
        pulseRateIsLessThenLowerLimit: true,
        improperMeasurementPosition: true,
      ),
      timestamp: DateTime.now(),
    ),
  ));

}
