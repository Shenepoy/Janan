import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/statistics/chart/chart_pressure_scale.dart';
import 'package:blood_pressure_app/model/blood_pressure/pressure_unit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kPa pressure coordinates and independent pulse scale round trip', () {
    const scale = ChartPressureScale(PressureUnit.kPa);
    expect(scale.pressure(Pressure.mmHg(120)), closeTo(15.99864, 1e-6));
    expect(scale.format(scale.pressure(Pressure.mmHg(120))), '16');
    expect(scale.pulseFromCoordinate(scale.pulse(72)), closeTo(72, 1e-9));
    expect(scale.fromMmHg(140), closeTo(18.66508, 1e-6));
  });
}
