import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/statistics/chart/chart_legend.dart';
import 'package:blood_pressure_app/features/statistics/chart/chart_tooltip.dart';
import 'package:blood_pressure_app/model/blood_pressure_analyzer.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A graph that displays the averages blood pressure values across by time in
/// the familiar shape of a clock.
class ClockBpGraph extends ConsumerStatefulWidget {
  /// Create a clock shaped graph of average by time.
  const ClockBpGraph({super.key, required this.measurements});

  /// All measurements used to generate the graph.
  final List<BloodPressureRecord> measurements;

  @override
  ConsumerState<ClockBpGraph> createState() => _ClockBpGraphState();
}

class _ClockBpGraphState extends ConsumerState<ClockBpGraph> {
  RadarTouchedSpot? _touched;

  @override
  Widget build(BuildContext context) {
    final localeTag = Localizations.localeOf(context).toString();
    final analyzer = BloodPressureAnalyzer(widget.measurements);
    final groups = analyzer.groupAnalyzers();
    final settings = ref.watch(appSettingsProvider);
    final theme = Theme.of(context);
    final decoColor = (theme.brightness == Brightness.dark
            ? Colors.white
            : Colors.black)
        .withAlpha(76);

    List<RadarEntry> entries(double Function(BloodPressureAnalyzer hour) read) => [
      for (final hour in groups)
        RadarEntry(value: read(hour)),
    ];

    final sysEntries = entries((hour) =>
        (hour.avgSys ?? analyzer.avgSys)?.mmHg.toDouble() ?? 0);
    final diaEntries = entries((hour) =>
        (hour.avgDia ?? analyzer.avgDia)?.mmHg.toDouble() ?? 0);
    final pulEntries = entries((hour) =>
        (hour.avgPul ?? analyzer.avgPul)?.toDouble() ?? 0);

    Widget? tooltip;
    if (_touched != null) {
      final hour = _touched!.touchedRadarEntryIndex;
      tooltip = DecoratedBox(
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
                TextSpan(
                  text: '\n${'sysShort'.tr()} ${sysEntries[hour].value.round()}',
                  style: chartTooltipValueStyle(context, settings.sysColor),
                ),
                TextSpan(
                  text: '\n${'diaShort'.tr()} ${diaEntries[hour].value.round()}',
                  style: chartTooltipValueStyle(context, settings.diaColor),
                ),
                TextSpan(
                  text: '\n${'pulShort'.tr()} ${pulEntries[hour].value.round()}',
                  style: chartTooltipValueStyle(context, settings.pulColor),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox.square(
      dimension: MediaQuery.sizeOf(context).width,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          children: [
            ChartLegend(items: [
              ('sysShort'.tr(), settings.sysColor),
              ('diaShort'.tr(), settings.diaColor),
              ('pulShort'.tr(), settings.pulColor),
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: Stack(
                children: [
                  RadarChart(
                    RadarChartData(
                      radarShape: RadarShape.circle,
                      radarBackgroundColor: Colors.transparent,
                      radarBorderData: BorderSide(color: decoColor, width: 3),
                      tickBorderData: BorderSide(color: decoColor, width: 2),
                      gridBorderData: BorderSide(color: decoColor, width: 2),
                      tickCount: 3,
                      ticksTextStyle: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(0),
                      ),
                      titleTextStyle: theme.textTheme.bodyMedium,
                      titlePositionPercentageOffset: 0.08,
                      getTitle: (index, angle) {
                        if (index.isOdd) return const RadarChartTitle(text: '');
                        return RadarChartTitle(text: index.toString());
                      },
                      dataSets: [
                        RadarDataSet(
                          fillColor: settings.sysColor.withAlpha(102),
                          borderColor: settings.sysColor,
                          borderWidth: 3,
                          entryRadius: 2,
                          dataEntries: sysEntries,
                        ),
                        RadarDataSet(
                          fillColor: settings.diaColor.withAlpha(102),
                          borderColor: settings.diaColor,
                          borderWidth: 3,
                          entryRadius: 2,
                          dataEntries: diaEntries,
                        ),
                        RadarDataSet(
                          fillColor: settings.pulColor.withAlpha(102),
                          borderColor: settings.pulColor,
                          borderWidth: 3,
                          entryRadius: 2,
                          dataEntries: pulEntries,
                        ),
                      ],
                      radarTouchData: RadarTouchData(
                        touchCallback: (event, response) {
                          final spot = response?.touchedSpot;
                          if (!event.isInterestedForInteractions || spot == null) {
                            if (_touched != null) setState(() => _touched = null);
                            return;
                          }
                          if (_touched != spot) setState(() => _touched = spot);
                        },
                      ),
                    ),
                    key: ValueKey<String>(localeTag),
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
          ],
        ),
      ),
    );
  }
}
