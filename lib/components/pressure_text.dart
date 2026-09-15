import 'package:blood_pressure_app/components/nullable_text.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/model/blood_pressure/pressure_unit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A display [pressure] in the preferred pressure unit.
class PressureText extends ConsumerWidget {
  const PressureText(this.pressure, {super.key});

  final Pressure? pressure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(appSettingsProvider).preferredPressureUnit;
    return NullableText(
      switch (unit) {
        PressureUnit.mmHg => pressure?.mmHg,
        PressureUnit.kPa => pressure?.kPa.toStringAsFixed(1),
      }?.toString(),
    );
  }
}
