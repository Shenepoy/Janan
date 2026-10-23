import 'dart:io';

import 'package:blood_pressure_app/core/database/powersync_schema.dart'
    as current;
import 'package:blood_pressure_app/core/repository/powersync_medicine_intake_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_repository.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';

void main() {
  test(
    'an existing database keeps its intake units when snapshot columns are added',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'janan_snapshot_migration_',
      );
      final path = '${directory.path}/health.db';
      var db = PowerSyncDatabase(
        schema: const Schema([
          Table.localOnly('medicines', [
            Column.text('designation'),
            Column.integer('color'),
            Column.real('default_dose_mg'),
            Column.text('dose_unit'),
            Column.integer('removed'),
          ]),
          Table.localOnly('intakes', [
            Column.integer('timestamp_unix_s'),
            Column.text('med_id'),
            Column.real('dosis_mg'),
            Column.text('occurrence_id'),
          ]),
        ]),
        path: path,
      );
      addTearDown(() async {
        await db.close();
        directory.deleteSync(recursive: true);
      });
      await db.initialize();
      await db.execute(
        "INSERT INTO medicines (id, designation, default_dose_mg, dose_unit, removed) VALUES ('legacy-med', 'Legacy', 5, 'mg', 0)",
      );
      await db.execute(
        "INSERT INTO intakes (id, timestamp_unix_s, med_id, dosis_mg) VALUES ('legacy-intake', 1700000000, 'legacy-med', 5)",
      );
      await db.close();
      db = PowerSyncDatabase(schema: current.schema, path: path);
      await db.initialize();
      final medicines = PowerSyncMedicineRepository(db);
      await medicines.update(
        (await medicines.getAll()).single,
        Medicine(
          designation: 'Edited',
          dosis: Weight.mg(1),
          unit: MedicationUnit.tablet,
        ),
      );
      final saved = (await PowerSyncMedicineIntakeRepository(
        db,
      ).get(DateRange.all())).single;
      expect(saved.medicine.designation, 'Legacy');
      expect(saved.medicine.unit, MedicationUnit.mg);
      expect(saved.dosis.mg, 5);
    },
  );
}
