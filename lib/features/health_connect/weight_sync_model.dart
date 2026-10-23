import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/health_connect/sync_model.dart';
import 'package:health/health.dart';

class WeightSyncModel extends SyncModel {
  WeightSyncModel({required this.weightRepo, required this.health});

  final BodyweightRepository weightRepo;
  final Health health;

  bool _syncing = false;
  @override
  bool get syncing => _syncing;

  int _progress = 0;
  @override
  double get progress => _progress / 7;

  @override
  Future<void> sync() async {
    if (_syncing) return;
    // performance: We load all data into memory at once; this might is fine
    // since there are not that many records. Measuring every day fpr 100 years
    // will yield 36525 records, or about 500 kB. 30 days would yield ~ 1 kB.

    _syncing = true;
    _progress = 0;
    notifyListeners();

    try {
      final granted = await health.requestPermissionsIfMissing([
        HealthDataType.WEIGHT,
      ]);
      if (!granted) throw StateError('Health data permission was not granted');
      final now = DateTime.now();
      DateTime start = now.subtract(Duration(days: 30));
      if (await health.isHealthDataHistoryAuthorized() ||
          await health.requestHealthDataHistoryAuthorization()) {
        start = DateTime(0);
      }
      _progress += 1;
      notifyListeners();

      final healthConnectData = await health
          .getHealthDataFromTypes(
            types: [HealthDataType.WEIGHT],
            startTime: start,
            endTime: now,
          )
          .then(
            (dataList) => {
              for (final x in dataList)
                x.dateFrom.secondsSinceEpoch: BodyweightRecord(
                  time: DateTimeS.fromSecondsSinceEpoch(
                    x.dateFrom.secondsSinceEpoch,
                  ),
                  weight: Weight.kg(
                    (x.value as NumericHealthValue).numericValue.toDouble(),
                  ),
                ),
            },
          );
      _progress += 1;
      notifyListeners();

      final appData = await weightRepo
          .get(DateRange(start: start, end: now))
          .then(
            (dataList) => {
              for (final x in dataList) x.time.secondsSinceEpoch: x,
            },
          );
      _progress += 1;
      notifyListeners();

      // Detect records only on device, or with new value
      final healthConnectOnlyData = [
        for (final x in healthConnectData.values)
          if (appData[x.time.secondsSinceEpoch]?.weight != x.weight) x,
      ];
      _progress += 1;
      notifyListeners();

      // Detect records only in app
      final appOnlyData = [
        for (final x in appData.values)
          if (!healthConnectData.containsKey(x.time.secondsSinceEpoch)) x,
      ];
      _progress += 1;
      notifyListeners();

      await Future.forEach(healthConnectOnlyData, weightRepo.add);
      _progress += 1;
      notifyListeners();

      await Future.forEach(appOnlyData, (record) async {
        final written = await health.writeHealthData(
          type: HealthDataType.WEIGHT,
          value: record.weight.kg,
          startTime: record.time,
          recordingMethod: RecordingMethod.manual,
        );
        if (!written) throw StateError('Health data write failed');
      });
      _progress += 1;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }
}
