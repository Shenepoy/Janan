import 'dart:math';
import 'package:blood_pressure_app/features/statistics/chart/chart_tooltip.dart';
import 'package:blood_pressure_app/features/statistics/chart/time_axis_titles.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_snapshot.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

/// A statistic that shows how often values occur in a list of values.
class ValueDistribution extends StatelessWidget {
  /// Create a statistic to show how often values occur.
  const ValueDistribution({
    super.key,
    required this.values,
    required this.color,
    this.fractionDigits = 0,
    this.unitLabel = '',
  });

  /// Raw list of all values to calculate the distribution from.
  final Iterable<num> values;

  /// Color of the data bars on the graph.
  final Color color;
  final int fractionDigits;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    final localeTag = Localizations.localeOf(context).toString();
    if (values.isEmpty) {
      return Center(child: SafaehStatusBody(message: Text('errNoData'.tr())));
    }
    return _ValueDistributionChart(
      key: ValueKey<String>(localeTag),
      values: values,
      color: color,
      fractionDigits: fractionDigits,
      unitLabel: unitLabel,
    );
  }
}

class _ValueDistributionChart extends StatefulWidget {
  const _ValueDistributionChart({
    super.key,
    required this.values,
    required this.color,
    required this.fractionDigits,
    required this.unitLabel,
  });

  final Iterable<num> values;
  final Color color;
  final int fractionDigits;
  final String unitLabel;

  @override
  State<_ValueDistributionChart> createState() =>
      _ValueDistributionChartState();
}

class _ValueDistributionChartState extends State<_ValueDistributionChart> {
  TransformationController? _transform;
  bool _isZoomed = false;

  TransformationController _ensureTransform() =>
      _transform ??= TransformationController()..addListener(_onTransform);

  @override
  void dispose() {
    _transform?.removeListener(_onTransform);
    _transform?.dispose();
    super.dispose();
  }

  void _onTransform() {
    final zoomed = (_transform!.value.getMaxScaleOnAxis() - 1.0).abs() > 0.01;
    if (zoomed == _isZoomed) return;
    _isZoomed = zoomed;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.values.map((value) => value.toDouble()).toList();
    final binFactor = pow(10, widget.fractionDigits).toDouble();
    final distribution = <int, int>{};
    for (final v in values) {
      final bin = (v * binFactor).round();
      distribution[bin] = (distribution[bin] ?? 0) + 1;
    }
    final minVal = distribution.keys.reduce(min);
    final maxVal = distribution.keys.reduce(max);
    final central =
        values.fold(0.0, (sum, value) => sum + value) / values.length;
    final centralBin = (central * binFactor).round();
    String formatted(num value) =>
        formatDashboardNumber(value.toDouble(), digits: widget.fractionDigits);
    final centralLabel = 'avgOf'.tr(namedArgs: {'txt': formatted(central)});
    final minLabel = 'minOf'.tr(
      namedArgs: {'txt': formatted(values.reduce(min))},
    );
    final maxLabel = 'maxOf'.tr(
      namedArgs: {'txt': formatted(values.reduce(max))},
    );
    final maxCount = distribution.values.reduce(max);
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall ?? const TextStyle();

    final groups = <BarChartGroupData>[
      for (var value = minVal; value <= maxVal; value++)
        BarChartGroupData(
          x: value,
          barRods: [
            BarChartRodData(
              toY: (distribution[value] ?? 0).toDouble(),
              color: widget.color,
              width: 8,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(3),
              ),
            ),
          ],
        ),
    ];

    return Semantics(
      label: [minLabel, centralLabel, maxLabel, widget.unitLabel].join(', '),
      child: Stack(
        children: [
          BarChart(
            BarChartData(
              minY: 0,
              maxY: max(1, maxCount).toDouble() + 1.25,
              alignment: BarChartAlignment.spaceAround,
              groupsSpace: 4,
              barGroups: groups,
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: theme.dividerColor, strokeWidth: 1),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  left: BorderSide(color: theme.dividerColor),
                  bottom: BorderSide(color: theme.dividerColor),
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    maxIncluded: false,
                    getTitlesWidget: (value, meta) => valueAxisTitle(
                      value: value,
                      meta: meta,
                      style: labelStyle,
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final v = value.round();
                      final String? text;
                      if (v == minVal) {
                        text = minLabel;
                      } else if (v == maxVal && maxVal != minVal) {
                        text = maxLabel;
                      } else if (v == centralBin &&
                          centralBin != minVal &&
                          centralBin != maxVal) {
                        text = centralLabel;
                      } else {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                        child: Text(text, style: labelStyle),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) => chartTooltipColor(context),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final count = rod.toY.round();
                    return BarTooltipItem(
                      '${formatted(group.x / binFactor)} ${widget.unitLabel}\n${'occurrenceCount'.tr(namedArgs: {'count': '$count'})}',
                      chartTooltipTitleStyle(context),
                    );
                  },
                ),
              ),
            ),
            duration: Duration.zero,
            transformationConfig: FlTransformationConfig(
              scaleAxis: FlScaleAxis.horizontal,
              minScale: 1,
              maxScale: 8,
              panEnabled: _isZoomed,
              transformationController: _ensureTransform(),
            ),
          ),
          if (_isZoomed)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                tooltip: 'resetZoom'.tr(),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.zoom_out_map, size: 20),
                onPressed: () => _transform!.value = Matrix4.identity(),
              ),
            ),
        ],
      ),
    );
  }
}
