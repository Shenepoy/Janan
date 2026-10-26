import 'dart:convert';

import 'package:blood_pressure_app/core/database/health_write.dart';
import 'package:blood_pressure_app/features/health_tools/health_tool_kind.dart';
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

  /// Inventory is recomputed from the ledger and recorded intakes, so editing,
  /// retrying or deleting an intake never accumulates duplicate deductions.
  /// Units must match explicitly; there is no assumed mg-to-tablet conversion.
  Future<double?> stock(String medicineId, String unit) async {
    final adjustments = await database.getAll(
      'SELECT quantity,timestamp_unix_s FROM refill_adjustments WHERE med_id=? AND unit=? ORDER BY timestamp_unix_s',
      [medicineId, unit],
    );
    if (adjustments.isEmpty) return null;
    var remaining = adjustments.fold<double>(
      0,
      (sum, row) => sum + (row['quantity'] as num).toDouble(),
    );
    final intakes = await database.getAll(
      'SELECT dosis_mg,medicine_snapshot_json FROM intakes WHERE med_id=? AND timestamp_unix_s>=?',
      [medicineId, adjustments.first['timestamp_unix_s']],
    );
    for (final intake in intakes) {
      final snapshot = intake['medicine_snapshot_json'];
      if (snapshot is! String) return null;
      final data = jsonDecode(snapshot) as Map<String, dynamic>;
      if (data['medicine_unit'] != unit) return null;
      remaining -= (intake['dosis_mg'] as num).toDouble();
    }
    return remaining;
  }
}
