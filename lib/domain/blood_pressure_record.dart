import 'package:blood_pressure_app/domain/blood_pressure_arm.dart';
import 'package:blood_pressure_app/domain/units/pressure.dart';

/// Immutable representation of a blood pressure measurement.
class BloodPressureRecord {
  /// Create a immutable representation of a blood pressure measurement.
  const BloodPressureRecord({
    this.id,
    required this.time,
    this.sys,
    this.dia,
    this.pul,
    this.arm,
    this.source = BloodPressureRecordSource.manual,
  });

  static const Object _unset = Object();

  /// Stable storage identity; absent only for new or legacy imported records.
  final String? id;

  /// Timestamp when the measurement was taken.
  final DateTime time;

  /// Systolic value of the measurement.
  final Pressure? sys;

  /// Diastolic value of the measurement.
  final Pressure? dia;

  /// Pulse value of the measurement in bpm.
  final int? pul;

  /// Arm used for this reading, [BloodPressureArm.unknown] when explicitly
  /// recorded as unknown, or null when no arm has been set.
  final BloodPressureArm? arm;

  /// Origin of this reading.
  final BloodPressureRecordSource source;

  BloodPressureRecord copyWith({
    String? id,
    DateTime? time,
    Pressure? sys,
    Pressure? dia,
    int? pul,
    Object? arm = _unset,
    BloodPressureRecordSource? source,
  }) => BloodPressureRecord(
    id: id ?? this.id,
    time: time ?? this.time,
    sys: sys ?? this.sys,
    dia: dia ?? this.dia,
    pul: pul ?? this.pul,
    arm: identical(arm, _unset) ? this.arm : arm as BloodPressureArm?,
    source: source ?? this.source,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BloodPressureRecord &&
          time == other.time &&
          sys == other.sys &&
          dia == other.dia &&
          pul == other.pul &&
          arm == other.arm &&
          source == other.source;

  @override
  int get hashCode => Object.hash(time, sys, dia, pul, arm, source);
}
