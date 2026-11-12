import 'package:health/health.dart';
import 'package:test/test.dart';

void main() {
 test('health types are of units assumed in code', () {
   expect(dataTypeToUnit[HealthDataType.BLOOD_PRESSURE_SYSTOLIC], HealthDataUnit.MILLIMETER_OF_MERCURY);
   expect(dataTypeToUnit[HealthDataType.BLOOD_PRESSURE_DIASTOLIC], HealthDataUnit.MILLIMETER_OF_MERCURY);
 });
}
