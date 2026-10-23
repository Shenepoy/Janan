import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_snapshot.dart';
import 'package:blood_pressure_app/model/blood_pressure/pressure_unit.dart';

/// Converts chart coordinates while keeping pulse on its own bpm scale.
class ChartPressureScale {
  const ChartPressureScale(this.unit);

  final PressureUnit unit;

  int get digits => unit == PressureUnit.kPa ? 1 : 0;
  double get factor => unit == PressureUnit.kPa ? Pressure.mmHg(1).kPa : 1;
  double pressure(Pressure value) => pressureInUnit(value, unit)!;
  double fromMmHg(num value) => value * factor;
  double pulse(num bpm) => bpm * factor;
  double pulseFromCoordinate(num value) => value / factor;
  String format(num value) =>
      formatDashboardNumber(value.toDouble(), digits: digits);
}
