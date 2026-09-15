import 'package:blood_pressure_app/model/storage/convert_util.dart';
import 'package:easy_localization/easy_localization.dart';

/// Different range types supported by the interval switcher.
enum TimeStep {
  day,
  month,
  year,
  lifetime,
  week,
  last7Days,
  last30Days,
  custom;

  /// Recreate a TimeStep from a number created with [TimeStep.serialize].
  factory TimeStep.deserialize(Object? value) {
    final int? intValue = ConvertUtil.parseInt(value);
    assert(intValue == null || intValue >= 0 && intValue <= 7);
    return switch (intValue) {
      null => TimeStep.last7Days,
      0 => TimeStep.day,
      1 => TimeStep.month,
      2 => TimeStep.year,
      3 => TimeStep.lifetime,
      4 => TimeStep.week,
      5 => TimeStep.last7Days,
      6 => TimeStep.last30Days,
      7 => TimeStep.custom,
      _ => TimeStep.last7Days,
    };
  }

  /// Select a displayable string from `localizations`.
  String localize() => switch (this) {
    TimeStep.day => 'day'.tr(),
    TimeStep.month => 'month'.tr(),
    TimeStep.year => 'year'.tr(),
    TimeStep.lifetime => 'lifetime'.tr(),
    TimeStep.week => 'week'.tr(),
    TimeStep.last7Days => 'last7Days'.tr(),
    TimeStep.last30Days => 'last30Days'.tr(),
    TimeStep.custom => 'custom'.tr(),
  };

  int serialize() => switch (this) {
    TimeStep.day => 0,
    TimeStep.month => 1,
    TimeStep.year => 2,
    TimeStep.lifetime => 3,
    TimeStep.week => 4,
    TimeStep.last7Days => 5,
    TimeStep.last30Days => 6,
    TimeStep.custom => 7,
  };
}
