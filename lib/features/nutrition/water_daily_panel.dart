import 'package:blood_pressure_app/core/widgets/app_sheet.dart';
import 'package:blood_pressure_app/features/nutrition/nutrition_strings.dart';
import 'package:blood_pressure_app/features/nutrition/water_bottles.dart';
import 'package:blood_pressure_app/features/nutrition/water_intake.dart';
import 'package:blood_pressure_app/features/nutrition/water_vessel.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:material_ui/material_ui.dart';

/// One tap on a saved vessel logs its capacity. All configuration stays above it.
class WaterDailyPanel extends ConsumerStatefulWidget {
  const WaterDailyPanel({
    super.key,
    required this.day,
    required this.maxHeight,
    required this.elevation,
    required this.onLog,
  });
  final DateTime day;
  final double maxHeight;
  final double elevation;
  final Future<void> Function(int) onLog;
  @override
  ConsumerState<WaterDailyPanel> createState() => _WaterDailyPanelState();
}

class _WaterDailyPanelState extends ConsumerState<WaterDailyPanel> {
  String? _saving;
  bool _failed = false;
  Future<void> _log(WaterBottle bottle) async {
    if (_saving != null) return;
    setState(() {
      _saving = bottle.id;
      _failed = false;
    });
    try {
      await widget.onLog(bottle.ml);
      if (mounted) Navigator.of(context).pop('logged');
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = null;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvidersProvider);
    final target = ref.watch(settings.provider(waterDailyTargetSetting));
    final bottles = ref.watch(waterBottlesProvider);
    final intake = ref.watch(waterDayIntakeProvider(widget.day));
    final total = intake.asData?.value;
    String t(String key) => nutritionText(context, key);
    String number(num value) =>
        NumberFormat.decimalPattern(context.locale.toString()).format(value);
    final scheme = Theme.of(context).colorScheme;
    Widget action(String key, IconData icon, String tooltip, String result) =>
        IconButton(
          key: ValueKey(key),
          tooltip: t(tooltip),
          visualDensity: VisualDensity.compact,
          onPressed: _saving != null
              ? null
              : () => Navigator.of(context).pop(result),
          icon: Icon(icon, size: 21),
        );
    return Material(
      key: const ValueKey('water-daily-panel'),
      elevation: widget.elevation,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 360, maxHeight: widget.maxHeight),
        child: AppSheetBody(
          surface: false,
          feedback: !_failed
              ? null
              : Semantics(
                  liveRegion: true,
                  child: Text(
                    t('failed'),
                    style: TextStyle(color: scheme.error),
                  ),
                ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t('water'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  action(
                    'water-panel-schedule',
                    Icons.notifications_outlined,
                    'waterSchedule',
                    'schedule',
                  ),
                  action(
                    'water-panel-settings',
                    Icons.tune,
                    'waterPreferences',
                    'settings',
                  ),
                  action(
                    'water-panel-edit',
                    Icons.edit_outlined,
                    'waterAmountAndTime',
                    'edit',
                  ),
                  action('water-panel-close', Icons.close, 'cancel', 'close'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat.MMMd(context.locale.toString()).format(widget.day),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${total == null ? '—' : number(total)} ${t('ml')}${target > 0 ? ' / ${number(target)} ${t('ml')}' : ''}',
                key: const ValueKey('water-day-total'),
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (target > 0 && total != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (total / target).clamp(0, 1),
                    minHeight: 4,
                    color: waterBlue,
                    semanticsLabel: t('waterDailyTarget'),
                  ),
                ),
              ],
              if (intake.hasError) Text(t('loadError')),
              const SizedBox(height: 20),
              Text(
                t('waterTapBottle'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      bottles.items.length == 1 || constraints.maxWidth < 220
                      ? 1
                      : bottles.items.length == 3 &&
                            constraints.maxWidth >= 300 &&
                            MediaQuery.textScalerOf(context).scale(16) <= 20
                      ? 3
                      : 2;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 10) / columns;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final bottle in bottles.items)
                        SizedBox(
                          width: width,
                          child: OutlinedButton(
                            key: ValueKey('water-bottle-log-${bottle.id}'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 14,
                              ),
                              backgroundColor: waterBlue.withValues(alpha: .08),
                              side: BorderSide(
                                color: waterBlue.withValues(alpha: .22),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            onPressed: _saving != null
                                ? null
                                : () => _log(bottle),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_saving == bottle.id)
                                  const SizedBox.square(
                                    dimension: 64,
                                    child: Padding(
                                      padding: EdgeInsets.all(18),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                else
                                  WaterVesselView(
                                    vessel: bottle.vessel,
                                    fill: .7,
                                    size: 64,
                                  ),
                                Text(
                                  '${number(bottle.ml)} ${t('ml')}',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  bottle.name.isEmpty
                                      ? t(bottle.vessel.name)
                                      : bottle.name,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
