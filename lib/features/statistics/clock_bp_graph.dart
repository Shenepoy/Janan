import 'dart:math' as math;

import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/statistics/chart/chart_pressure_scale.dart';
import 'package:blood_pressure_app/features/statistics/chart/chart_tooltip.dart';
import 'package:blood_pressure_app/model/blood_pressure_analyzer.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hourly averages. Pulse has a separate bpm scale from pressure.
class ClockBpGraph extends ConsumerStatefulWidget {
  const ClockBpGraph({super.key, required this.measurements});

  final List<BloodPressureRecord> measurements;

  @override
  ConsumerState<ClockBpGraph> createState() => _ClockBpGraphState();
}

class _ClockBpGraphState extends ConsumerState<ClockBpGraph> {
  int? _touchedHour;
  final _visible = [true, true, true];

  @override
  Widget build(BuildContext context) {
    final localeTag = Localizations.localeOf(context).toString();
    final analyzer = BloodPressureAnalyzer(widget.measurements);
    final groups = analyzer.groupAnalyzers();
    final settings = ref.watch(appSettingsProvider);
    final scale = ChartPressureScale(settings.preferredPressureUnit);
    final theme = Theme.of(context);
    final colors = [settings.sysColor, settings.diaColor, settings.pulColor];
    final labels = ['sysLong'.tr(), 'diaLong'.tr(), 'pulLong'.tr()];
    final shortLabels = ['sysShort'.tr(), 'diaShort'.tr(), 'pulShort'.tr()];
    final units = [scale.unit.name, scale.unit.name, 'bpm'.tr()];
    final decoColor = theme.colorScheme.onSurface.withAlpha(76);
    final visibleIndices = [
      for (var i = 0; i < 3; i++)
        if (_visible[i]) i,
    ];
    double pressureOrZero(Pressure? value) =>
        value == null ? 0 : scale.pressure(value);
    final series = [
      [
        for (final hour in groups)
          pressureOrZero(hour.avgSys ?? analyzer.avgSys),
      ],
      [
        for (final hour in groups)
          pressureOrZero(hour.avgDia ?? analyzer.avgDia),
      ],
      [
        for (final hour in groups)
          scale.pulse(hour.avgPul ?? analyzer.avgPul ?? 0),
      ],
    ];
    final hour = _touchedHour;
    Widget? tooltip;
    if (hour != null) {
      final observed = [
        groups[hour].avgSys != null,
        groups[hour].avgDia != null,
        groups[hour].avgPul != null,
      ];
      final anyObserved = visibleIndices.any((index) => observed[index]);
      tooltip = IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: chartTooltipColor(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text.rich(
              TextSpan(
                text: TimeOfDay(hour: hour, minute: 0).format(context),
                style: chartTooltipTitleStyle(context),
                children: [
                  if (!anyObserved)
                    TextSpan(text: '\n${'clockNoReadings'.tr()}'),
                  for (final index in visibleIndices)
                    TextSpan(
                      text:
                          '\n${shortLabels[index]} ${observed[index] ? '${index == 2 ? scale.pulseFromCoordinate(series[index][hour]).round() : scale.format(series[index][hour])} ${units[index]}' : 'clockOverallAverage'.tr()}',
                      style: chartTooltipValueStyle(context, colors[index]),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final controlsWidth =
            144.0 * math.max(1.0, MediaQuery.textScalerOf(context).scale(1));
        final besideChart =
            MediaQuery.orientationOf(context) == Orientation.landscape &&
            constraints.maxWidth >= controlsWidth + 24 + 180;
        final controls = Wrap(
          direction: besideChart ? Axis.vertical : Axis.horizontal,
          spacing: 8,
          runSpacing: 4,
          children: [
            for (var i = 0; i < 3; i++)
              FilterChip(
                showCheckmark: false,
                key: ValueKey('clock-series-$i'),
                label: Text(labels[i]),
                avatar: Icon(Icons.circle, color: colors[i], size: 10),
                selected: _visible[i],
                onSelected: _visible[i] && visibleIndices.length == 1
                    ? null
                    : (selected) => setState(() {
                        _visible[i] = selected;
                        _touchedHour = null;
                      }),
              ),
          ],
        );
        final scaleCaption = Padding(
          padding: besideChart
              ? const EdgeInsets.only(bottom: 4)
              : const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'chartSeparateScales'.tr(
              namedArgs: {'unit': scale.unit.name, 'bpm': 'bpm'.tr()},
            ),
            key: const ValueKey('clock-scale-caption'),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: besideChart ? TextAlign.start : TextAlign.center,
          ),
        );
        final chart = LayoutBuilder(
          builder: (context, constraints) {
            final side = math.min(
              constraints.maxWidth,
              besideChart
                  ? (MediaQuery.sizeOf(context).height * 0.55).clamp(
                      220.0,
                      280.0,
                    )
                  : math.max(180.0, MediaQuery.sizeOf(context).height * 0.5),
            );
            return SizedBox.square(
              dimension: side,
              child: Padding(
                padding: EdgeInsets.all(
                  besideChart
                      ? math.max(
                          16.0,
                          12 * MediaQuery.textScalerOf(context).scale(1),
                        )
                      : 24,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    RadarChart(
                      RadarChartData(
                        radarShape: RadarShape.circle,
                        radarBackgroundColor: Colors.transparent,
                        radarBorderData: BorderSide(color: decoColor, width: 3),
                        tickBorderData: BorderSide(color: decoColor, width: 2),
                        gridBorderData: BorderSide(color: decoColor, width: 2),
                        tickCount: 3,
                        ticksTextStyle: const TextStyle(
                          color: Colors.transparent,
                        ),
                        titleTextStyle: theme.textTheme.bodySmall,
                        titlePositionPercentageOffset: 0.08,
                        getTitle: (index, angle) =>
                            RadarChartTitle(text: index.isOdd ? '' : '$index'),
                        dataSets: [
                          for (final index in visibleIndices)
                            RadarDataSet(
                              fillColor: colors[index].withAlpha(60),
                              borderColor: colors[index],
                              borderWidth: 3,
                              entryRadius: 2,
                              dataEntries: [
                                for (final value in series[index])
                                  RadarEntry(value: value),
                              ],
                            ),
                        ],
                        radarTouchData: RadarTouchData(
                          touchCallback: (event, response) {
                            final next = event.isInterestedForInteractions
                                ? response?.touchedSpot?.touchedRadarEntryIndex
                                : null;
                            if (next != _touchedHour) {
                              setState(() => _touchedHour = next);
                            }
                          },
                        ),
                      ),
                      key: ValueKey<String>(localeTag),
                      duration: Duration.zero,
                    ),
                    if (tooltip != null)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Center(child: tooltip),
                      ),
                  ],
                ),
              ),
            );
          },
        );
        if (!besideChart) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [controls, scaleCaption, chart],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            scaleCaption,
            Row(
              children: [
                SizedBox(
                  width: controlsWidth,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: controls,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: Center(child: chart)),
              ],
            ),
          ],
        );
      },
    );
  }
}
