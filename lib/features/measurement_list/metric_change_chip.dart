import 'package:blood_pressure_app/features/measurement_list/cartoon_hop.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_change.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';

/// Arrow and delta for a metric versus the previous measurement.
class MetricChangeChip extends StatelessWidget {
  /// Create a compact change indicator.
  const MetricChangeChip({
    super.key,
    required this.change,
    this.unit = '',
    this.fractionDigits = 1,
    this.compact = false,
  });

  /// Computed difference to render.
  final MetricChange change;

  /// Unit shown after the delta, when the value changed.
  final String unit;

  /// Decimal places for the absolute delta.
  final int fractionDigits;

  /// Smaller icon and type for table cells.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!change.hasComparison) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final color = switch (change.tone) {
      MetricChangeTone.better => Colors.green,
      MetricChangeTone.worse => Colors.red,
      MetricChangeTone.neutral => theme.colorScheme.onSurface,
    };
    final textStyle = (compact ? theme.textTheme.labelSmall : theme.textTheme.bodySmall)
        ?.copyWith(color: color);
    if (change.isUnchanged) {
      return Text(
        '—',
        style: textStyle,
        semanticsLabel: 'noChange'.tr(),
      );
    }
    final icon = change.increased ? Icons.arrow_upward : Icons.arrow_downward;
    final delta = change.formatAbsDelta(fractionDigits);
    final label = unit.isEmpty ? delta : '$delta $unit';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: compact ? 12 : 16, color: color),
        const SizedBox(width: 2),
        Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: textStyle,
        ),
      ],
    );
  }
}

/// List row with an optional [MetricChangeChip] as the trailing widget.
class MetricDetailTile extends StatelessWidget {
  /// Create a details row for one metric.
  const MetricDetailTile({
    super.key,
    required this.title,
    required this.value,
    this.leading,
    this.change,
    this.unit = '',
    this.fractionDigits = 1,
    this.onTap,
    this.hopToken = 0,
  });

  /// Metric name.
  final String title;

  /// Formatted current value.
  final String value;

  /// Optional leading icon.
  final Widget? leading;

  /// Comparison to the previous measurement.
  final MetricChange? change;

  /// Unit for the change chip.
  final String unit;

  /// Decimal places for the change chip.
  final int fractionDigits;

  /// Opens the metric description card.
  final VoidCallback? onTap;

  /// When non-zero, the value hops after an edit.
  final int hopToken;

  @override
  Widget build(BuildContext context) {
    final valueText = Text(value);
    return ListTile(
      leading: leading,
      title: Text(title),
      subtitle: hopToken == 0
          ? valueText
          : CartoonHop(playToken: hopToken, child: valueText),
      onTap: onTap,
      trailing: change == null || !change!.hasComparison
          ? null
          : MetricChangeChip(
              change: change!,
              unit: unit,
              fractionDigits: fractionDigits,
            ),
    );
  }
}
