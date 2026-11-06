import 'dart:convert';

import 'package:blood_pressure_app/core/database/health_write.dart';
import 'package:blood_pressure_app/features/health_tools/health_tool_kind.dart';
import 'package:blood_pressure_app/features/health_tools/medicine_supply.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

/// All tools use the same local transaction and full-database backup lifecycle.
class HealthToolsRepository {
  HealthToolsRepository(this.database);
  final PowerSyncDatabase database;

  Future<List<Map<String, Object?>>> list(HealthToolKind kind) async =>
      (await database.getAll(
        'SELECT * FROM ${kind.table} ORDER BY timestamp_unix_s DESC',
      )).map(Map<String, Object?>.from).toList();

  Stream<List<Map<String, Object?>>> watch(HealthToolKind kind) => database
      .watch('SELECT * FROM ${kind.table} ORDER BY timestamp_unix_s DESC')
      .map((rows) => rows.map(Map<String, Object?>.from).toList());

  Future<String> save(
    HealthToolKind kind,
    Map<String, Object?> values, {
    String? id,
  }) async {
    validate(kind, values);
    final identity = id ?? const Uuid().v4();
    await writeHealthTransaction(database, (tx) async {
      final columns = ['timestamp_unix_s', ...kind.fields.map((f) => f.name)];
      await tx.execute(
        'INSERT OR REPLACE INTO ${kind.table}(id,${columns.join(',')}) VALUES(${List.filled(columns.length + 1, '?').join(',')})',
        [identity, ...columns.map((key) => values[key])],
      );
    });
    return identity;
  }

  void validate(HealthToolKind kind, Map<String, Object?> values) {
    final allowed = {'timestamp_unix_s', ...kind.fields.map((f) => f.name)};
    if (values.keys.any((key) => !allowed.contains(key))) {
      throw ArgumentError('Unknown field');
    }
    if (values['timestamp_unix_s'] is! int) {
      throw ArgumentError('Date required');
    }
    for (final field in kind.fields) {
      final value = values[field.name];
      if (value == null || value == '') {
        if (field.required) throw ArgumentError(field.name);
        continue;
      }
      if (field.numeric) {
        if (value is! num ||
            !value.isFinite ||
            (field.minimum != null && value < field.minimum!) ||
            (field.maximum != null && value > field.maximum!)) {
          throw ArgumentError(field.name);
        }
      } else if (value is! String ||
          value.length > 8000 ||
          (field.options.isNotEmpty && !field.options.contains(value))) {
        throw ArgumentError(field.name);
      }
    }
    if (kind == HealthToolKind.personalTarget) {
      final min = values['minimum'] as num?;
      final max = values['maximum'] as num?;
      if (min == null && max == null ||
          min != null && max != null && min > max) {
        throw ArgumentError('target');
      }
      final units = switch (values['metric']) {
        'systolic' || 'diastolic' => ['mmHg', 'kPa'],
        'pulse' => ['bpm'],
        'weight' => ['kg', 'lb'],
        _ => <String>[],
      };
      if (!units.contains(values['unit'])) throw ArgumentError('unit');
    }
    for (final key in ['medicine_ids_json', 'reading_ids_json']) {
      if (values[key] != null && values[key] != '') {
        final ids = jsonDecode(values[key] as String);
        if (ids is! List || ids.any((id) => id is! String)) {
          throw ArgumentError(key);
        }
      }
    }
  }

  Future<void> remove(HealthToolKind kind, String id) =>
      writeHealthTransaction(database, (tx) async {
        await tx.execute('DELETE FROM ${kind.table} WHERE id=?', [id]);
      });

  /// One watched query covers ledger, logs, schedules and completed occurrences.
  Stream<List<Map<String, Object?>>> watchSupply(
    String medicineId,
  ) => database.watch(
    "SELECT 'adjustment' kind,json_object('quantity',quantity,'unit',unit,'timestamp_unix_s',timestamp_unix_s) data FROM refill_adjustments WHERE med_id=? "
    "UNION ALL SELECT 'intake',json_object('dosis_mg',dosis_mg,'medicine_snapshot_json',medicine_snapshot_json,'timestamp_unix_s',timestamp_unix_s) FROM intakes WHERE med_id=? "
    "UNION ALL SELECT 'schedule',json_object('id',id,'active',active,'ended',ended,'dose_amount',dose_amount,'dose_unit',dose_unit,'time_minutes_json',time_minutes_json,'weekdays_mask',weekdays_mask,'start_date',start_date,'end_date',end_date) FROM medication_schedules WHERE med_id=? "
    "UNION ALL SELECT 'occurrence',json_object('id',o.id,'status',o.status) FROM dose_occurrences o JOIN medication_schedules s ON s.id=o.schedule_id WHERE s.med_id=?",
    parameters: [medicineId, medicineId, medicineId, medicineId],
  );

  MedicineSupply supplyFromRows(
    List<Map<String, Object?>> rows,
    String unit,
    DateTime now,
  ) {
    List<Map<String, Object?>> of(String kind) => rows
        .where((r) => r['kind'] == kind)
        .map(
          (r) =>
              Map<String, Object?>.from(jsonDecode(r['data'] as String) as Map),
        )
        .toList();
    return estimateMedicineSupply(
      adjustments: of('adjustment'),
      intakes: of('intake'),
      schedules: of('schedule'),
      occurrences: of('occurrence'),
      unit: unit,
      now: now,
    );
  }

  Future<double?> stock(String medicineId, String unit) async => supplyFromRows(
    await watchSupply(medicineId).first,
    unit,
    DateTime.now(),
  ).remaining;
}
