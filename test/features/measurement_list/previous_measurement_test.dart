import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/measurement_list/previous_measurement.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../model/export_import/record_formatter_test.dart';
import '../../util.dart';

void main() {
  test('returns the next older weight in a newest-first list', () {
    final newer = BodyweightRecord(time: DateTime(2024, 2), weight: Weight.kg(80));
    final older = BodyweightRecord(time: DateTime(2024, 1), weight: Weight.kg(81));
    expect(previousWeightInList([newer, older], 0), older);
    expect(previousWeightInList([newer, older], 1), isNull);
  });

  test('skips medicine-only blood-pressure rows', () {
    final current = mockEntry(time: DateTime(2024, 3), sys: 120);
    final medicineOnly = mockEntry(
      time: DateTime(2024, 2),
      intake: (mockMedicine(designation: 'pill'), 1),
    );
    final older = mockEntry(time: DateTime(2024, 1), sys: 130);
    expect(
      previousBloodPressureInList([current, medicineOnly, older], 0),
      older,
    );
    expect(previousBloodPressureInList([current], 0), isNull);
  });

  test('loads the most recent older weight from the repository', () async {
    final repo = MockBodyweightRepository();
    final current = BodyweightRecord(time: DateTime(2024, 3), weight: Weight.kg(80));
    final older = BodyweightRecord(time: DateTime(2024, 2), weight: Weight.kg(81));
    final oldest = BodyweightRecord(time: DateTime(2024, 1), weight: Weight.kg(82));
    await repo.add(current);
    await repo.add(oldest);
    await repo.add(older);
    expect(await loadOlderWeight(repo, current.time), older);
    expect(await loadOlderWeight(repo, oldest.time), isNull);
  });

  test('loads the most recent older blood-pressure record', () async {
    final repo = MockBloodPressureRepository();
    await repo.add(BloodPressureRecord(time: DateTime(2024, 3), sys: Pressure.mmHg(120)));
    await repo.add(BloodPressureRecord(time: DateTime(2024, 1), sys: Pressure.mmHg(140)));
    await repo.add(BloodPressureRecord(time: DateTime(2024, 2), sys: Pressure.mmHg(130)));
    final older = await loadOlderBloodPressure(repo, DateTime(2024, 3));
    expect(older?.sys?.mmHg, 130);
  });
}
