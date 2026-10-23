import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/statistics/chart/chart_pressure_scale.dart';
import 'package:blood_pressure_app/features/statistics/value_distribution.dart';
import 'package:blood_pressure_app/theme/app_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Viewer for [ValueDistribution]s from [BloodPressureRecord]s.
///
/// Displays a tab bar with different value distributions for available sys, dia
/// and pul values from [BloodPressureRecord]s.
class BloodPressureDistribution extends ConsumerStatefulWidget {
  /// Create a [ValueDistribution] viewer of the data of measurements.
  const BloodPressureDistribution({super.key, required this.records});

  /// All records to include in statistics computations.
  ///
  /// When a records includes null values, those values are left out for
  /// computing this statistic. This means that no filtering of passed records
  /// is required.
  final Iterable<BloodPressureRecord> records;

  @override
  ConsumerState<BloodPressureDistribution> createState() =>
      _BloodPressureDistributionState();
}

class _BloodPressureDistributionState
    extends ConsumerState<BloodPressureDistribution>
    with TickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 3, vsync: this);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final settings = ref.watch(appSettingsProvider);
    final scale = ChartPressureScale(settings.preferredPressureUnit);
    final theme = Theme.of(context);
    final tabStyle = AppText.label(context, color: theme.colorScheme.onSurface);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(50),
          ),
          child: TabBar.secondary(
            labelStyle: tabStyle,
            unselectedLabelStyle: AppText.label(context),
            labelPadding: const EdgeInsets.symmetric(vertical: 16),
            indicator: BoxDecoration(
              color: switch (_controller.index) {
                0 => settings.sysColor,
                1 => settings.diaColor,
                2 => settings.pulColor,
                _ => Theme.of(context).colorScheme.primaryContainer,
              },
              borderRadius: BorderRadius.circular(50),
            ),
            dividerHeight: 0,
            controller: _controller,
            tabs: [
              Text('sysLong'.tr()),
              Text('diaLong'.tr()),
              Text('pulLong'.tr()),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: TabBarView(
              controller: _controller,
              children: [
                ValueDistribution(
                  key: const Key('sys-dist'),
                  values: widget.records
                      .map((e) => e.sys == null ? null : scale.pressure(e.sys!))
                      .nonNulls,
                  color: settings.sysColor,
                  fractionDigits: scale.digits,
                  unitLabel: settings.preferredPressureUnit.name,
                ),
                ValueDistribution(
                  key: const Key('dia-dist'),
                  values: widget.records
                      .map((e) => e.dia == null ? null : scale.pressure(e.dia!))
                      .nonNulls,
                  color: settings.diaColor,
                  fractionDigits: scale.digits,
                  unitLabel: settings.preferredPressureUnit.name,
                ),
                ValueDistribution(
                  key: const Key('pul-dist'),
                  values: widget.records.map((e) => e.pul).nonNulls,
                  color: settings.pulColor,
                  unitLabel: 'bpm'.tr(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
