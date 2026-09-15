import 'package:blood_pressure_app/domain/domain.dart';
import 'package:sqflite/sqflite.dart';

/// Read-only access to the old `health_data_store` `bp.db` schema.
class LegacyBpDb {
  LegacyBpDb(this._db);

  final Database _db;

  static Future<bool> looksLikeLegacy(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='Timestamps'",
    );
    return tables.isNotEmpty;
  }

  Future<List<BloodPressureRecord>> bloodPressure() async {
    final results = await _db.rawQuery(
      'SELECT timestampUnixS, sys, dia, pul '
      'FROM Timestamps AS t '
      'LEFT JOIN Systolic AS s ON t.entryID = s.entryID '
      'LEFT JOIN Diastolic AS d ON t.entryID = d.entryID '
      'LEFT JOIN Pulse AS p ON t.entryID = p.entryID',
    );
    final records = <BloodPressureRecord>[];
    for (final r in results) {
      final timeS = r['timestampUnixS'] as int?;
      if (timeS == null) continue;
      final rec = BloodPressureRecord(
        time: DateTimeS.fromSecondsSinceEpoch(timeS),
        sys: _decodePressure(r['sys']),
        dia: _decodePressure(r['dia']),
        pul: _decodeInt(r['pul']),
      );
      if (rec.sys != null || rec.dia != null || rec.pul != null) {
        records.add(rec);
      }
    }
    return records;
  }

  Future<List<Note>> notes() async {
    try {
      final result = await _db.rawQuery(
        'SELECT t.timestampUnixS AS time, note, color '
        'FROM Timestamps AS t '
        'JOIN Notes AS n ON t.entryID = n.entryID '
        'WHERE n.note IS NOT NULL OR n.color IS NOT NULL',
      );
      return [
        for (final row in result)
          if (row['time'] is int)
            Note(
              time: DateTimeS.fromSecondsSinceEpoch(row['time'] as int),
              note: row['note'] as String?,
              color: row['color'] as int?,
            ),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<List<BodyweightRecord>> weights() async {
    try {
      final results = await _db.rawQuery(
        'SELECT timestampUnixS, weightKg, impedanceOhm '
        'FROM Timestamps AS t '
        'INNER JOIN Weight AS w ON t.entryID = w.entryID',
      );
      return [
        for (final r in results)
          BodyweightRecord(
            time: DateTimeS.fromSecondsSinceEpoch(r['timestampUnixS'] as int),
            weight: Weight.kg((r['weightKg'] as num).toDouble()),
            impedanceOhm: (r['impedanceOhm'] as num?)?.toDouble(),
          ),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<List<Medicine>> medicines({bool includeRemoved = true}) async => [
        for (final row in await medicineRows())
          if (includeRemoved || !row.removed) row.medicine,
      ];

  Future<List<({Medicine medicine, bool removed})>> medicineRows() async {
    try {
      final medData = await _db.query(
        'Medicine',
        columns: ['designation', 'defaultDose', 'color', 'removed'],
      );
      return [
        for (final m in medData)
          (
            medicine: Medicine(
              designation: m['designation'].toString(),
              dosis: _decodeMg(m['defaultDose']),
              color: m['color'] as int?,
            ),
            removed: m['removed'] == 1 || m['removed'] == true,
          ),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> looksLikeHealth(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE name='blood_pressure'",
    );
    return tables.isNotEmpty;
  }

  Future<List<MedicineIntake>> intakes() async {
    try {
      final results = await _db.rawQuery(
        'SELECT t.timestampUnixS, dosis, defaultDose, designation, color '
        'FROM Timestamps AS t '
        'JOIN Intake AS i ON t.entryID = i.entryID '
        'JOIN Medicine AS m ON m.medID = i.medID '
        'WHERE i.dosis IS NOT NULL',
      );
      return [
        for (final r in results)
          MedicineIntake(
            time: DateTimeS.fromSecondsSinceEpoch(r['timestampUnixS'] as int),
            dosis: _decodeMg(r['dosis'])!,
            medicine: Medicine(
              designation: r['designation'] as String,
              dosis: _decodeMg(r['defaultDose']),
              color: r['color'] as int?,
            ),
          ),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<({int bp, int notes, int weights, int medicines, int intakes})>
      counts() async => (
      bp: (await bloodPressure()).length,
      notes: (await notes()).length,
      weights: (await weights()).length,
      medicines: (await medicines()).length,
      intakes: (await intakes()).length,
    );

  Pressure? _decodePressure(Object? value) {
    if (value is! num) return null;
    return Pressure.kPa(value.toDouble());
  }

  int? _decodeInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  Weight? _decodeMg(Object? value) {
    if (value is! num) return null;
    return Weight.mg(value.toDouble());
  }
}
