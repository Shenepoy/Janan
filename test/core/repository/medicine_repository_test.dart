import 'dart:io';

import 'package:blood_pressure_app/core/repository/powersync_medicine_intake_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_repository.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';

import '../powersync_probe.dart';

void main() {
  bool available = false;
  PowerSyncDatabase? db;
  String? dbPath;

  setUpAll(() async {
    available = await powerSyncAvailable();
    if (!available) return;
    final opened = await openTempHealthDb();
    db = opened.$1;
    dbPath = opened.$2;
  });

  tearDownAll(() async {
    final opened = db;
    if (opened == null) return;
    await opened.close();
    final path = dbPath;
    if (path != null) {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
  });

  test('upsert does not duplicate and can revive a removed medicine', () async {
    if (!available) return;
    final repo = PowerSyncMedicineRepository(db!);
    const med = Medicine(designation: 'Amlodipine', color: 0xFF00AA00);

    await repo.add(med);
    await repo.add(med);
    expect(await repo.getAll(), [med]);

    await repo.remove(med);
    expect(await repo.getAll(), isEmpty);

    await repo.upsert(med);
    expect(await repo.getAll(), [med]);
  });

  test('editing a medicine retains its identity for linked records', () async {
    expect(available, isTrue, reason: 'PowerSync must run this regression');
    final repo = PowerSyncMedicineRepository(db!);
    const original = Medicine(designation: 'Original', color: 1);
    const edited = Medicine(designation: 'Renamed', color: 2);
    await repo.add(original);
    final id = await repo.idFor(original);
    final intakeRepo = PowerSyncMedicineIntakeRepository(db!);
    final time = DateTime(2026, 10, 23, 8);
    await intakeRepo.add(
      MedicineIntake(time: time, medicine: original, dosis: Weight.mg(5)),
    );

    await repo.update(original, edited);

    expect(await repo.idFor(edited), id);
    expect(await repo.idFor(original), isNull);
    final intakes = await intakeRepo.get(DateRange.all());
    expect(intakes.singleWhere((i) => i.time == time).medicine, original);
  });

  test('intakes of a soft-deleted medicine still store', () async {
    if (!available) return;
    final medRepo = PowerSyncMedicineRepository(db!);
    final intakeRepo = PowerSyncMedicineIntakeRepository(db!);
    const med = Medicine(designation: 'RemovedMed', color: 1);
    await medRepo.add(med);
    await medRepo.remove(med);

    final intake = MedicineIntake(
      time: DateTimeS.fromSecondsSinceEpoch(1_700_000_000),
      dosis: Weight.mg(5),
      medicine: med,
    );
    await intakeRepo.add(intake);
    final stored = await intakeRepo.get(DateRange.all());
    expect(stored, contains(intake));
  });
}
