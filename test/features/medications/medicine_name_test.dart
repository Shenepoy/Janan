import 'package:blood_pressure_app/features/medications/medicine_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('names within the limit stay whole', () {
    expect(compactMedicineName('Aspirin'), 'Aspirin');
    expect(compactMedicineName('  Zinc '), 'Zinc');
  });

  test('several words are cut with an ellipsis', () {
    expect(compactMedicineName('Test Lisinopril'), 'Test Li…');
    expect(compactMedicineName('Vitamin D'), 'Vitamin…');
    expect(compactMedicineName('Blood pressure pill extra'), 'Blood p…');
  });

  test('one long word is cut with an ellipsis', () {
    expect(compactMedicineName('Acetaminophen'), 'Acetami…');
    expect(compactMedicineName('Acetaminophen', limit: 4), 'Ace…');
  });

  test('Arabic and Chinese names stay in their script', () {
    expect(compactMedicineName('فيتامين د'), 'فيتام…');
    expect(compactMedicineName('对乙酰氨基酚'), '对乙酰…');
    expect(compactMedicineName('Витамин Д'), 'Витамин…');
  });
}
