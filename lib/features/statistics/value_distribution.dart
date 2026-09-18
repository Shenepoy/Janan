import 'dart:math';

import 'package:blood_pressure_app/features/statistics/chart/chart_tooltip.dart';
import 'package:blood_pressure_app/features/statistics/chart/time_axis_titles.dart';
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
  });

  /// Raw list of all values to calculate the distribution from.
  final Iterable<int> values;

  /// Color of the data bars on the graph.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final localeTag = Localizations.localeOf(context).toString();
    if (values.isEmpty) {
      return Center(
        child: SafaehStatusBody(message: Text('errNoData'.tr())),
      );
    }
    return _ValueDistributionChart(
      key: ValueKey<String>(localeTag),
      values: values,
      color: color,
    );
  }
}

class _ValueDistributionChart extends StatefulWidget {
  const _ValueDistributionChart({
    super.key,
    required this.values,
    required this.color,
  });

  final Iterable<int> values;
  final Color color;

  @override
  State<_ValueDistributionChart> createState() => _ValueDistributionChartState();
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
    final distribution = <int, int>{};
    var sum = 0;
    for (final v in widget.values) {
      distribution[v] = (distribution[v] ?? 0) + 1;
      sum += v;
    }
    final minVal = distribution.keys.reduce(min);
    final maxVal = distribution.keys.reduce(max);
    final avg = (sum / widget.values.length).round();
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            ),
          ],
        ),
    ];

    return Semantics(
      label: [
        'minOf'.tr(namedArgs: {'txt': '$minVal'}),
        'avgOf'.tr(namedArgs: {'txt': '$avg'}),
        'maxOf'.tr(namedArgs: {'txt': '$maxVal'}),
      ].join(', '),
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
                getDrawingHorizontalLine: (_) => FlLine(
                  color: theme.dividerColor,
                  strokeWidth: 1,
                ),
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
                        text = 'minOf'.tr(namedArgs: {'txt': '$minVal'});
                      } else if (v == maxVal && maxVal != minVal) {
                        text = 'maxOf'.tr(namedArgs: {'txt': '$maxVal'});
                      } else if (v == avg && avg != minVal && avg != maxVal) {
                        text = 'avgOf'.tr(namedArgs: {'txt': '$avg'});
                      } else {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
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
                      '${group.x}\n${'occurrenceCount'.tr(namedArgs: {
                        'count': '$count',
                      })}',
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
