import 'package:blood_pressure_app/domain/units/weight.dart';

/// Body weight at a specific time.
class BodyweightRecord {
  /// Create a body weight measurement.
  const BodyweightRecord({
    this.id,
    required this.time,
    required this.weight,
    this.impedanceOhm,
  });

  /// Stable storage identity; absent only for new or legacy imported records.
  final String? id;

  /// Timestamp when the weight was measured.
  final DateTime time;

  /// Weight at [time].
  final Weight weight;

  /// Foot-to-foot bio-impedance in ohms, when a scale reported it.
  final double? impedanceOhm;

  BodyweightRecord copyWith({
    String? id,
    DateTime? time,
    Weight? weight,
    double? impedanceOhm,
  }) => BodyweightRecord(
    id: id ?? this.id,
    time: time ?? this.time,
    weight: weight ?? this.weight,
    impedanceOhm: impedanceOhm ?? this.impedanceOhm,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BodyweightRecord &&
          time == other.time &&
          weight == other.weight &&
          impedanceOhm == other.impedanceOhm;

  @override
  int get hashCode => Object.hash(time, weight, impedanceOhm);
}
