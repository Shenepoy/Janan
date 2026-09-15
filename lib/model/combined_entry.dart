import 'package:blood_pressure_app/domain/domain.dart';

/// Timestamped collection of values
class CombinedEntry {
  CombinedEntry({
    required this.time,
    Note? note,
    BloodPressureRecord? record,
    this.intake,
    BodyweightRecord? weight,
    List<MedicineIntake>? dayIntakes,
  }) : assert(note == null || note.time == time),
       assert(record == null || record.time == time),
       assert(weight == null || weight.time == time),
       _note = note,
       _record = record,
       _weight = weight,
       _dayIntakes = List<MedicineIntake>.of(dayIntakes ?? const []);

  final DateTime time;

  Note? _note;
  Note? get note => _note;
  set note(Note? value) {
    assert(value == null || value.time == time);
    _note = value;
  }

  BloodPressureRecord? _record;
  BloodPressureRecord? get record => _record;
  set record(BloodPressureRecord? value) {
    assert(value == null || value.time == time);
    _record = value;
  }

  MedicineIntake? intake;

  BodyweightRecord? _weight;
  BodyweightRecord? get weight => _weight;
  set weight(BodyweightRecord? value) {
    assert(value == null || value.time == time);
    _weight = value;
  }

  final List<MedicineIntake> _dayIntakes;

  /// Intakes logged on the same calendar day and shown on this row.
  ///
  /// Used when a dose was entered separately from this blood-pressure reading.
  List<MedicineIntake> get dayIntakes => List.unmodifiable(_dayIntakes);

  /// Same-timestamp [intake] plus [dayIntakes], oldest first.
  List<MedicineIntake> get allIntakes {
    final seen = <MedicineIntake>{};
    if (intake != null) seen.add(intake!);
    seen.addAll(_dayIntakes);
    return seen.toList()..sort((a, b) => a.time.compareTo(b.time));
  }

  /// Intake the add/edit form should load for this row.
  MedicineIntake? get formIntake {
    if (intake != null) return intake;
    if (_dayIntakes.isEmpty) return null;
    return _dayIntakes.reduce((a, b) => a.time.isAfter(b.time) ? a : b);
  }

  /// Whether this row is only a medicine log (no pressure or weight).
  bool get isMedicineOnly =>
      intake != null && _record == null && _weight == null;

  /// Systolic value of the measurement.
  Pressure? get sys => record?.sys;

  /// Diastolic value of the measurement.
  Pressure? get dia => record?.dia;

  /// Pulse value of the measurement in bpm.
  int? get pul => record?.pul;

  /// ARGB color in number format.
  ///
  /// Can also be obtained through the `Colors.toARGB32()` method in `dart:ui`.
  /// Sample value: `0xFF42A5F5`
  int? get color => note?.color;

  /// Copy with optional replacements.
  CombinedEntry copyWith({
    Note? note,
    BloodPressureRecord? record,
    MedicineIntake? intake,
    BodyweightRecord? weight,
    List<MedicineIntake>? dayIntakes,
    bool clearIntake = false,
  }) => CombinedEntry(
    time: time,
    note: note ?? _note,
    record: record ?? _record,
    intake: clearIntake ? null : (intake ?? this.intake),
    weight: weight ?? _weight,
    dayIntakes: dayIntakes ?? _dayIntakes,
  );

  @override
  String toString() =>
      'CombinedEntry($time, $sys, $dia, $pul, '
      '${note?.note}, $color, ${intake?.medicine}, ${intake?.dosis}, '
      '${weight?.weight}, dayIntakes: ${_dayIntakes.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CombinedEntry &&
          runtimeType == other.runtimeType &&
          time == other.time &&
          _note == other._note &&
          _record == other._record &&
          intake == other.intake &&
          _weight == other._weight &&
          _listEquals(_dayIntakes, other._dayIntakes);

  @override
  int get hashCode => Object.hash(
    time,
    _note,
    _record,
    intake,
    _weight,
    Object.hashAll(_dayIntakes),
  );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

DateTime _calendarDay(DateTime time) =>
    DateTime(time.year, time.month, time.day);

/// Utility methods to work on full entries.
extension CombinedEntryList on List<CombinedEntry> {
  /// Create a list that only contains the records field from the entries.
  List<BloodPressureRecord> get records =>
      map((e) => e.record).nonNulls.toList();

  /// Create a list that only contains the note field from the entries.
  List<Note> get notes => map((e) => e.note).nonNulls.toList();

  /// Get all medicines that appear anywhere in the list.
  List<Medicine> get distinctMedicines => <Medicine>{
    for (final e in this)
      for (final intake in e.allIntakes) intake.medicine,
  }.toList();

  /// Merges values at the same time from passed lists to FullEntries and
  /// creates list of them.
  ///
  /// In the resulting list every passed value is contained exactly once.
  static List<CombinedEntry> merged(
    List<BloodPressureRecord> records,
    List<Note> notes,
    List<MedicineIntake> intakes, [
    List<BodyweightRecord>? weights,
  ]) {
    final entries = <DateTime, CombinedEntry>{};

    for (final r in records) {
      entries.putIfAbsent(r.time, () => CombinedEntry(time: r.time));
      entries[r.time]!.record = r;
    }
    for (final n in notes) {
      if ((n.note?.isEmpty ?? true) && n.color == null) continue;
      entries.putIfAbsent(n.time, () => CombinedEntry(time: n.time));
      entries[n.time]!.note = n;
    }
    for (final i in intakes) {
      entries.putIfAbsent(i.time, () => CombinedEntry(time: i.time));
      entries[i.time]!.intake = i;
    }
    if (weights != null) {
      for (final w in weights) {
        entries.putIfAbsent(w.time, () => CombinedEntry(time: w.time));
        entries[w.time]!.weight = w;
      }
    }

    return entries.values.toList();
  }

  /// Hide standalone medicine rows when a blood-pressure reading exists that
  /// day, and attach those intakes to the last (newest) reading of the day.
  ///
  /// [newestFirst] must already be sorted newest to oldest.
  static List<CombinedEntry> forBloodPressureList(
    List<CombinedEntry> newestFirst,
  ) {
    final byDay = <DateTime, List<CombinedEntry>>{};
    for (final entry in newestFirst) {
      byDay.putIfAbsent(_calendarDay(entry.time), () => []).add(entry);
    }

    final hidden = <CombinedEntry>{};
    final extras = <CombinedEntry, List<MedicineIntake>>{};
    final notesToAttach = <CombinedEntry, Note>{};

    for (final dayEntries in byDay.values) {
      CombinedEntry? lastBp;
      for (final entry in dayEntries) {
        if (entry.record != null) {
          lastBp = entry;
          break;
        }
      }
      if (lastBp == null) continue;

      final attached = <MedicineIntake>[];
      for (final entry in dayEntries) {
        if (identical(entry, lastBp) || !entry.isMedicineOnly) continue;
        attached.addAll(entry.allIntakes);
        hidden.add(entry);
        final note = entry.note;
        if (note != null &&
            lastBp.note == null &&
            !notesToAttach.containsKey(lastBp)) {
          notesToAttach[lastBp] = note;
        }
      }
      if (attached.isNotEmpty) {
        attached.sort((a, b) => a.time.compareTo(b.time));
        extras[lastBp] = attached;
      }
    }

    return [
      for (final entry in newestFirst)
        if (!hidden.contains(entry))
          if (extras.containsKey(entry) || notesToAttach.containsKey(entry))
            entry.copyWith(
              note: notesToAttach[entry],
              dayIntakes: extras[entry],
            )
          else
            entry,
    ];
  }
}
