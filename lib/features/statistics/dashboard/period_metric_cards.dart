import 'dart:ui' as ui;

import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_change.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_change_chip.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_info.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_info_dialog.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_section.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_snapshot.dart';
import 'package:blood_pressure_app/model/blood_pressure/pressure_unit.dart';
import 'package:blood_pressure_app/model/blood_pressure_analyzer.dart';
import 'package:blood_pressure_app/theme/app_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// SYS / DIA / PUL averages for the selected range, grouped in one card.
class PeriodMetricCards extends ConsumerWidget {
  /// Create the period averages card.
  const PeriodMetricCards({
    super.key,
    required this.period,
    this.previous,
  });

  /// Analyzer for the visible range.
  final BloodPressureAnalyzer period;

  /// Analyzer for the previous window, when loaded.
  final BloodPressureAnalyzer? previous;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Localizations.localeOf(context);
    final settings = ref.watch(appSettingsProvider);
    final unit = settings.preferredPressureUnit;
    final columns = [
      if (period.avgSys != null)
        _MetricColumn(
          key: const Key('period_metric_sys'),
          title: 'sysShort'.tr(),
          color: settings.sysColor,
          kind: MetricKind.sys,
          average: period.avgSys,
          min: period.minSys,
          max: period.maxSys,
          previousAverage: previous?.avgSys,
          unit: unit,
          isPulse: false,
        ),
      if (period.avgDia != null)
        _MetricColumn(
          key: const Key('period_metric_dia'),
          title: 'diaShort'.tr(),
          color: settings.diaColor,
          kind: MetricKind.dia,
          average: period.avgDia,
          min: period.minDia,
          max: period.maxDia,
          previousAverage: previous?.avgDia,
          unit: unit,
          isPulse: false,
        ),
      if (period.avgPul != null)
        _MetricColumn(
          key: const Key('period_metric_pul'),
          title: 'pulShort'.tr(),
          color: settings.pulColor,
          kind: MetricKind.pulse,
          pulseAverage: period.avgPul,
          pulseMin: period.minPul,
          pulseMax: period.maxPul,
          previousPulse: previous?.avgPul,
          unit: unit,
          isPulse: true,
        ),
    ];
    if (columns.isEmpty) return const SizedBox.shrink();

    return DashboardSection(
      icon: Icons.stacked_line_chart,
      title: 'dashboardAverages'.tr(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < columns.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: columns[i]),
          ],
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    super.key,
    required this.title,
    required this.color,
    required this.kind,
    required this.unit,
    required this.isPulse,
    this.average,
    this.min,
    this.max,
    this.previousAverage,
    this.pulseAverage,
    this.pulseMin,
    this.pulseMax,
    this.previousPulse,
  });

  final String title;
  final Color color;
  final MetricKind kind;
  final PressureUnit unit;
  final bool isPulse;
  final Pressure? average;
  final Pressure? min;
  final Pressure? max;
  final Pressure? previousAverage;
  final int? pulseAverage;
  final int? pulseMin;
  final int? pulseMax;
  final int? previousPulse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final digits = isPulse || unit == PressureUnit.mmHg ? 0 : 1;
    final current = isPulse
        ? pulseAverage?.toDouble()
        : pressureInUnit(average, unit);
    final previous = isPulse
        ? previousPulse?.toDouble()
        : pressureInUnit(previousAverage, unit);
    final formatted = isPulse
        ? formatDashboardNumber(pulseAverage?.toDouble(), digits: 0)
        : formatDashboardPressure(average, unit);
    final minText = isPulse
        ? formatDashboardNumber(pulseMin?.toDouble(), digits: 0)
        : formatDashboardPressure(min, unit);
    final maxText = isPulse
        ? formatDashboardNumber(pulseMax?.toDouble(), digits: 0)
        : formatDashboardPressure(max, unit);
    final change = current == null || previous == null
        ? null
        : MetricChange(
            current: current,
            previous: previous,
            unchangedEpsilon: unit == PressureUnit.kPa && !isPulse ? 0.05 : 0.5,
          );

    return InkWell(
      onTap: current == null
          ? null
          : () => showMetricInfo(
              context,
              kind: kind,
              current: current,
              formattedValue: formatted,
            ),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label(context, color: color),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Text(
                  formatted,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (change != null && change.hasComparison)
                        Semantics(
                          label: 'dashboardVsPreviousPeriod'.tr(),
                          child: MetricChangeChip(
                            change: change,
                            fractionDigits: digits,
                            compact: true,
                          ),
                        ),
                      Text(
                        'dashboardMinMax'.tr(namedArgs: {
                          'min': minText,
                          'max': maxText,
                        }),
                        textDirection: ui.TextDirection.ltr,
              style: AppText.subtitle(context),
                      ),
                    ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
