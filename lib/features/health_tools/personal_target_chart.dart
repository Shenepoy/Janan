import 'dart:math' as math;

import 'package:blood_pressure_app/features/health_tools/health_tools_repository.dart';
import 'package:blood_pressure_app/features/health_tools/health_tools_strings.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

/// Converts saved values without rounding the target boundaries.
double targetValueInUnit(double value, String from, String to) {
  if (from == to) return value;
  if (from == 'mmHg' && to == 'kPa') return value * .133322;
  if (from == 'kPa' && to == 'mmHg') return value / .133322;
  if (from == 'kg' && to == 'lb') return value / .45359237;
  if (from == 'lb' && to == 'kg') return value * .45359237;
  throw ArgumentError('Incompatible units');
}

/// Half-open target periods: a new saved target replaces both previous bounds.
List<({double start, double end, double? minimum, double? maximum})>
targetPeriods(
  List<Map<String, Object?>> rows,
  String metric,
  String unit,
  double start,
  double end,
) {
  final targets = rows.where((r) => r['metric'] == metric).toList()
    ..sort((a, b) {
      final time = (a['timestamp_unix_s'] as num).compareTo(
        b['timestamp_unix_s'] as num,
      );
      return time != 0
          ? time
          : (a['id'] as String).compareTo(b['id'] as String);
    });
  return [
    for (var i = 0; i < targets.length; i++)
      if ((targets[i]['timestamp_unix_s'] as num) < end &&
          (i + 1 == targets.length ||
              (targets[i + 1]['timestamp_unix_s'] as num) > start) &&
          (i + 1 == targets.length ||
              targets[i + 1]['timestamp_unix_s'] !=
                  targets[i]['timestamp_unix_s']))
        (
          start: math.max(
            start,
            (targets[i]['timestamp_unix_s'] as num).toDouble(),
          ),
          end: math.min(
            end,
            i + 1 == targets.length
                ? end
                : (targets[i + 1]['timestamp_unix_s'] as num).toDouble(),
          ),
          minimum: targets[i]['minimum'] == null
              ? null
              : targetValueInUnit(
                  (targets[i]['minimum'] as num).toDouble(),
                  targets[i]['unit'] as String,
                  unit,
                ),
          maximum: targets[i]['maximum'] == null
              ? null
              : targetValueInUnit(
                  (targets[i]['maximum'] as num).toDouble(),
                  targets[i]['unit'] as String,
                  unit,
                ),
        ),
  ];
}

/// A local, reactive comparison of recorded values and dated saved targets.
class PersonalTargetChart extends StatefulWidget {
  const PersonalTargetChart({super.key, required this.repository});
  final HealthToolsRepository repository;
  @override
  State<PersonalTargetChart> createState() => _PersonalTargetChartState();
}

class _PersonalTargetChartState extends State<PersonalTargetChart> {
  String _metric = 'systolic';
  String _unit = 'mmHg';
  int _days = 90;
  late Stream<List<Map<String, Object?>>> _rows;
  late DateTime _end;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _end = DateTime.now();
    final since =
        _end.subtract(Duration(days: _days)).millisecondsSinceEpoch ~/ 1000;
    // Each emission is a coherent snapshot of readings and target history.
    _rows = widget.repository.database.watch(
      "SELECT 'target' kind,id,timestamp_unix_s,metric,unit,minimum,maximum,NULL value FROM personal_targets "
      "UNION ALL SELECT 'reading',id,timestamp_unix_s,'systolic','kPa',NULL,NULL,sys_kpa FROM blood_pressure WHERE timestamp_unix_s>=? AND sys_kpa IS NOT NULL "
      "UNION ALL SELECT 'reading',id,timestamp_unix_s,'diastolic','kPa',NULL,NULL,dia_kpa FROM blood_pressure WHERE timestamp_unix_s>=? AND dia_kpa IS NOT NULL "
      "UNION ALL SELECT 'reading',id,timestamp_unix_s,'pulse','bpm',NULL,NULL,pul FROM blood_pressure WHERE timestamp_unix_s>=? AND pul IS NOT NULL "
      "UNION ALL SELECT 'reading',id,timestamp_unix_s,'weight','kg',NULL,NULL,weight_kg FROM weights WHERE timestamp_unix_s>=? AND weight_kg IS NOT NULL",
      parameters: [since, since, since, since],
    );
  }

  @override
  void didUpdateWidget(covariant PersonalTargetChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository.database != widget.repository.database) _reload();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'tools.targetChart'.toolTr(context),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButton<String>(
                isExpanded: true,
                value: _metric,
                items: [
                  for (final m in ['systolic', 'diastolic', 'pulse', 'weight'])
                    DropdownMenuItem(
                      value: m,
                      child: Text('tools.options.$m'.toolTr(context)),
                    ),
                ],
                onChanged: (m) => setState(() {
                  _metric = m!;
                  _unit = m == 'weight'
                      ? 'kg'
                      : m == 'pulse'
                      ? 'bpm'
                      : 'mmHg';
                }),
              ),
              DropdownButton<String>(
                isExpanded: true,
                value: _unit,
                items: [
                  for (final u
                      in _metric == 'weight'
                          ? ['kg', 'lb']
                          : _metric == 'pulse'
                          ? ['bpm']
                          : ['mmHg', 'kPa'])
                    DropdownMenuItem(
                      value: u,
                      child: Text('tools.options.$u'.toolTr(context)),
                    ),
                ],
                onChanged: (u) => setState(() => _unit = u!),
              ),
              DropdownButton<int>(
                isExpanded: true,
                value: _days,
                items: [
                  for (final d in [30, 90, 365])
                    DropdownMenuItem(
                      value: d,
                      child: Text('$d ${'tools.days'.toolTr(context)}'),
                    ),
                ],
                onChanged: (d) => setState(() {
                  _days = d!;
                  _reload();
                }),
              ),
            ],
          ),
          Text('tools.targetChartHint'.toolTr(context)),
          const SizedBox(height: 12),
          StreamBuilder(
            key: ValueKey((widget.repository.database, _days)),
            stream: _rows,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('tools.loadError'.toolTr(context));
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final end = DateTime.now().millisecondsSinceEpoch / 1000;
              final start =
                  _end.subtract(Duration(days: _days)).millisecondsSinceEpoch /
                  1000;
              final data = snapshot.data!;
              final points = [
                for (final r in data)
                  if (r['kind'] == 'reading' &&
                      r['metric'] == _metric &&
                      (r['timestamp_unix_s'] as num) <= end &&
                      (r['timestamp_unix_s'] as num) >= start)
                    FlSpot(
                      (r['timestamp_unix_s'] as num).toDouble(),
                      targetValueInUnit(
                        (r['value'] as num).toDouble(),
                        r['unit'] as String,
                        _unit,
                      ),
                    ),
              ]..sort((a, b) => a.x.compareTo(b.x));
              final targets = targetPeriods(
                data.where((r) => r['kind'] == 'target').toList(),
                _metric,
                _unit,
                start,
                end,
              );
              if (points.isEmpty && targets.isEmpty) {
                return Text('tools.empty'.toolTr(context));
              }
              final color = Theme.of(context).colorScheme.primary;
              final bars = [
                LineChartBarData(
                  spots: points,
                  color: color,
                  barWidth: 0,
                  dotData: const FlDotData(show: true),
                ),
                for (final t in targets)
                  for (final value in [t.minimum, t.maximum])
                    if (value != null)
                      LineChartBarData(
                        spots: [FlSpot(t.start, value), FlSpot(t.end, value)],
                        color: Theme.of(context).colorScheme.tertiary,
                        barWidth: 2,
                        dashArray: [5, 4],
                        dotData: const FlDotData(show: false),
                      ),
              ];
              final values = bars
                  .expand((b) => b.spots)
                  .map((p) => p.y)
                  .toList();
              final low = values.reduce(math.min),
                  high = values.reduce(math.max);
              final pad = math.max(1.0, (high - low) * .15);
              return SizedBox(
                height: 230,
                child: LineChart(
                  LineChartData(
                    minX: start,
                    maxX: end,
                    minY: low - pad,
                    maxY: high + pad,
                    lineBarsData: bars,
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: .12),
                        strokeWidth: .5,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 48,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          minIncluded: false,
                          maxIncluded: false,
                          reservedSize: 30,
                          interval: (end - start) / 3,
                          getTitlesWidget: (v, meta) => Text(
                            DateFormat.Md(context.locale.toString()).format(
                              DateTime.fromMillisecondsSinceEpoch(
                                (v * 1000).round(),
                              ),
                            ),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItems: (spots) => [
                          for (final spot in spots)
                            if (spot.barIndex == 0)
                              LineTooltipItem(
                                '${DateFormat.yMd(context.locale.toString()).add_Hm().format(DateTime.fromMillisecondsSinceEpoch((spot.x * 1000).round()))}\n${spot.y.toStringAsFixed(1)} $_unit',
                                TextStyle(color: color),
                              )
                            else
                              null,
                        ],
                      ),
                    ),
                  ),
                  duration: Duration.zero,
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}
