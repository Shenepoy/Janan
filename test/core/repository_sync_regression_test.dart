import 'dart:io';
import 'package:blood_pressure_app/core/repository/powersync_blood_pressure_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_bodyweight_repository.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/health_connect/bp_sync_model.dart';
import 'package:blood_pressure_app/features/health_connect/weight_sync_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:powersync/powersync.dart';
import 'powersync_probe.dart';

void main() {
  late PowerSyncDatabase db;
  setUp(() async {
    final opened = await openTempHealthDb();
    db = opened.$1;
    addTearDown(() async {
      await db.close();
      final file = File(opened.$2);
      if (file.existsSync()) file.deleteSync();
    });
  });
  test('concurrent saves keep one blood pressure row', () async {
    final repo = PowerSyncBloodPressureRepository(db);
    final value = BloodPressureRecord(
      time: DateTime(2026, 10, 23),
      sys: Pressure.mmHg(120),
    );
    await Future.wait(List.generate(4, (_) => repo.add(value)));
    expect(await repo.get(DateRange.all()), hasLength(1));
  });
  test('concurrent saves keep one weight row', () async {
    final repo = PowerSyncBodyweightRepository(db);
    final value = BodyweightRecord(
      time: DateTime(2026, 10, 23),
      weight: Weight.kg(70),
    );
    await Future.wait(List.generate(4, (_) => repo.add(value)));
    expect(await repo.get(DateRange.all()), hasLength(1));
  });
  test('failed BP sync permits retry', () async {
    final model = BPSyncModel(
      bpRepo: PowerSyncBloodPressureRepository(db),
      health: _HealthProbe(failRead: true),
    );
    await expectLater(model.sync(), throwsStateError);
    expect(model.syncing, isFalse);
  });
  test('failed weight sync permits retry', () async {
    final model = WeightSyncModel(
      weightRepo: PowerSyncBodyweightRepository(db),
      health: _HealthProbe(failRead: true),
    );
    await expectLater(model.sync(), throwsStateError);
    expect(model.syncing, isFalse);
  });
  test('false BP SDK write is a recoverable sync failure', () async {
    final repo = PowerSyncBloodPressureRepository(db);
    await repo.add(
      BloodPressureRecord(
        time: DateTime(2026, 10, 22),
        sys: Pressure.mmHg(120),
        dia: Pressure.mmHg(80),
      ),
    );
    final model = BPSyncModel(
      bpRepo: repo,
      health: _HealthProbe(failWrite: true),
    );
    await expectLater(model.sync(), throwsStateError);
    expect(model.syncing, isFalse);
  });
  test('false weight SDK write is a recoverable sync failure', () async {
    final repo = PowerSyncBodyweightRepository(db);
    await repo.add(
      BodyweightRecord(time: DateTime(2026, 10, 22), weight: Weight.kg(70)),
    );
    final model = WeightSyncModel(
      weightRepo: repo,
      health: _HealthProbe(failWrite: true),
    );
    await expectLater(model.sync(), throwsStateError);
    expect(model.syncing, isFalse);
  });
  test(
    'health sync matches imported subsecond timestamp to stored seconds',
    () async {
      final repo = PowerSyncBodyweightRepository(db);
      final time = DateTime(2026, 10, 22, 8, 0, 0, 500);
      final health = _HealthProbe(time: time);
      await repo.add(BodyweightRecord(time: time, weight: Weight.kg(70)));
      await WeightSyncModel(weightRepo: repo, health: health).sync();
      expect(
        health.writes,
        0,
        reason: 'Reading is already present in both stores',
      );
    },
  );
}

class _HealthProbe extends Fake implements Health {
  _HealthProbe({this.failRead = false, this.failWrite = false, this.time});
  final bool failRead;
  final bool failWrite;
  final DateTime? time;
  int writes = 0;
  @override
  Future<bool?> hasPermissions(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) async => true;
  @override
  Future<bool> isHealthDataHistoryAuthorized() async => true;
  @override
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required List<HealthDataType> types,
    Map<HealthDataType, HealthDataUnit>? preferredUnits,
    required DateTime startTime,
    required DateTime endTime,
    List<RecordingMethod> recordingMethodsToFilter = const [],
  }) async {
    if (failRead) throw StateError('synthetic read failure');
    if (time == null) return [];
    return [
      HealthDataPoint(
        uuid: 'weight',
        value: NumericHealthValue(numericValue: 70),
        type: HealthDataType.WEIGHT,
        unit: HealthDataUnit.KILOGRAM,
        dateFrom: time!,
        dateTo: time!,
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'test',
        sourceId: 'test',
        sourceName: 'test',
      ),
    ];
  }

  @override
  Future<bool> writeHealthData({
    required double value,
    HealthDataUnit? unit,
    required HealthDataType type,
    required DateTime startTime,
    String? clientRecordId,
    double? clientRecordVersion,
    DateTime? endTime,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
  }) async {
    writes++;
    return !failWrite;
  }

  @override
  Future<bool> writeBloodPressure({
    required int systolic,
    required int diastolic,
    required DateTime startTime,
    String? clientRecordId,
    double? clientRecordVersion,
    DateTime? endTime,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
  }) async => !failWrite;
}
