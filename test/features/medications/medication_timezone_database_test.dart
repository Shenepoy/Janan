import 'package:blood_pressure_app/features/medications/medication_timezone_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolves the Asia/Kuwait timezone reported by Android', () {
    initializeMedicationTimezoneDatabase();

    expect(medicationTimezone('Asia/Kuwait').name, 'Asia/Kuwait');
  });
}
