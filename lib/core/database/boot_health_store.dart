import 'dart:io';

import 'package:blood_pressure_app/core/database/health_database.dart';
import 'package:blood_pressure_app/core/repository/powersync_blood_pressure_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_bodyweight_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_intake_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_note_repository.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/model/med_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:powersync/powersync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Local-only store opened before `runApp` so the root [ProviderScope] can
/// override `healthDatabaseProvider` and the repos. Reading the unimplemented
/// defaults poisons the root container and Home keeps showing that error.
class BootHealthStore {
  BootHealthStore({
    required this.database,
    required this.bpRepo,
    required this.noteRepo,
    required this.medRepo,
    required this.intakeRepo,
    required this.weightRepo,
    required this.medCache,
  });

  final PowerSyncDatabase database;
  final BloodPressureRepository bpRepo;
  final NoteRepository noteRepo;
  final MedicineRepository medRepo;
  final MedicineIntakeRepository intakeRepo;
  final BodyweightRepository weightRepo;
  final MedCache medCache;

  static Future<BootHealthStore> open() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      databaseFactory = databaseFactoryFfi;
    }
    final database = await HealthDatabase.open();
    final medRepo = PowerSyncMedicineRepository(database);
    return BootHealthStore(
      database: database,
      bpRepo: PowerSyncBloodPressureRepository(database),
      noteRepo: PowerSyncNoteRepository(database),
      medRepo: medRepo,
      intakeRepo: PowerSyncMedicineIntakeRepository(database),
      weightRepo: PowerSyncBodyweightRepository(database),
      medCache: MedCache(medRepo, await medRepo.getAll()),
    );
  }
}
