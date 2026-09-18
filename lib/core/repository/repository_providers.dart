import 'package:blood_pressure_app/core/database/database_providers.dart';
import 'package:blood_pressure_app/core/repository/powersync_ble_blacklist_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_blood_pressure_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_bodyweight_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_intake_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_note_repository.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'repository_providers.g.dart';

@Riverpod(keepAlive: true)
BloodPressureRepository bloodPressureRepository(Ref ref) =>
    PowerSyncBloodPressureRepository(ref.watch(healthDatabaseProvider));

@Riverpod(keepAlive: true)
NoteRepository noteRepository(Ref ref) =>
    PowerSyncNoteRepository(ref.watch(healthDatabaseProvider));

@Riverpod(keepAlive: true)
MedicineRepository medicineRepository(Ref ref) =>
    PowerSyncMedicineRepository(ref.watch(healthDatabaseProvider));

@Riverpod(keepAlive: true)
MedicineIntakeRepository medicineIntakeRepository(Ref ref) =>
    PowerSyncMedicineIntakeRepository(ref.watch(healthDatabaseProvider));

@Riverpod(keepAlive: true)
BodyweightRepository bodyweightRepository(Ref ref) =>
    PowerSyncBodyweightRepository(ref.watch(healthDatabaseProvider));

/// Blocked BLE readings that must not be re-imported.
final bleBlacklistRepositoryProvider = Provider<BleBlacklistRepository>(
  (Ref ref) => PowerSyncBleBlacklistRepository(
    ref.watch(healthDatabaseProvider),
  ),
);
