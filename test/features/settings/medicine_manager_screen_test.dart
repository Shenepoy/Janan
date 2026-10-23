import 'package:blood_pressure_app/core/repository/repository_providers.dart';
import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/settings/medicine_manager_screen.dart';
import 'package:blood_pressure_app/model/med_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../util.dart';

void main() {
  testWidgets('editing catalog medicine updates it without deleting it', (
    tester,
  ) async {
    usePhoneTestSurface(tester);
    const original = Medicine(designation: 'Original medicine');
    final medicines = _EditingMedicines([original]);
    await pumpApp(
      tester,
      await materialApp(
        const MedicineManagerScreen(),
        store: MockHealthStore()..medRepo = medicines,
        overrides: [
          medCacheProvider.overrideWithValue(MedCache(medicines, [original])),
          medicationScheduleRepositoryProvider.overrideWithValue(
            _EmptySchedules(),
          ),
        ],
      ),
    );

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Renamed medicine',
    );
    await tester.tap(find.text('Save medicine'));
    await tester.pumpAndSettle();

    expect(medicines.edited, isTrue);
    expect(find.text('Renamed medicine'), findsOneWidget);
    expect(find.text('Original medicine'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _EditingMedicines extends MockMedRepo {
  _EditingMedicines(super.meds);
  bool edited = false;

  @override
  Future<void> update(Medicine original, Medicine replacement) async {
    edited = true;
    await super.update(original, replacement);
  }

  @override
  Future<void> remove(Medicine value) async =>
      fail('Editing must retain the medicine identity');
}

class _EmptySchedules implements MedicationScheduleRepository {
  @override
  Future<List<MedicationSchedule>> getAll() async => [];

  @override
  Future<List<DoseOccurrence>> getOccurrences(DateTime date) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected call: $invocation');
}
