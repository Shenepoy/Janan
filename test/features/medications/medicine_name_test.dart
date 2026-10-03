import 'package:blood_pressure_app/features/medications/medicine_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('names within the limit stay whole', () {
    expect(compactMedicineName('Aspirin'), 'Aspirin');
    expect(compactMedicineName('  Zinc '), 'Zinc');
  });

  test('several words become initials', () {
    expect(compactMedicineName('Test Lisinopril'), 'TL');
    expect(compactMedicineName('Vitamin D'), 'VD');
    expect(compactMedicineName('Blood pressure pill extra'), 'BPP');
  });

  test('one long word is cut with an ellipsis', () {
    expect(compactMedicineName('Acetaminophen'), 'Acetami…');
    expect(compactMedicineName('Acetaminophen', limit: 4), 'Ace…');
  });

  test('Arabic and Chinese names stay in their script', () {
    expect(compactMedicineName('فيتامين د'), 'فيتام…');
    expect(compactMedicineName('对乙酰氨基酚'), '对乙酰…');
    expect(compactMedicineName('Витамин Д'), 'ВД');
  });
}
