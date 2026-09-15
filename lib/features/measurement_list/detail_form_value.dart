import 'package:blood_pressure_app/features/measurement_list/cartoon_hop.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_change.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_change_chip.dart';
import 'package:blood_pressure_app/theme/app_text.dart';
import 'package:flutter/material.dart';

/// Labeled reading with the unit beside it and the comparison under the unit.
class DetailFormValue extends StatelessWidget {
  /// Create a details field that matches the add-entry form.
  const DetailFormValue({
    super.key,
    this.label = '',
    required this.value,
    this.unit,
    this.accent,
    this.change,
    this.fractionDigits = 0,
    this.onTap,
    this.hopToken = 0,
  });

  /// Colored caption. Empty hides the label.
  final String label;

  /// Formatted current value.
  final String value;

  /// Unit shown beside [value].
  final String? unit;

  /// Caption color.
  final Color? accent;

  /// Comparison to the previous measurement.
  final MetricChange? change;

  /// Decimal places for the change chip.
  final int fractionDigits;

  /// Opens the metric description card.
  final VoidCallback? onTap;

  /// When non-zero, the value hops after an edit.
  final int hopToken;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ring = accent ?? theme.colorScheme.primary;
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: AppText.label(context, color: ring),
          ),
          const SizedBox(height: 4),
        ],
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                hopping(
                  hopToken,
                  Text(
                    value,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      height: 1.1,
                      color: value == '—'
                          ? theme.colorScheme.outline
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (unit != null || (change != null && change!.hasComparison)) ...[
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (unit != null)
                        Text(
                          unit!,
                          style: AppText.subtitle(context),
                        ),
                      if (change != null && change!.hasComparison)
                        MetricChangeChip(
                          change: change!,
                          fractionDigits: fractionDigits,
                          compact: true,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
    return Expanded(
      child: onTap == null
          ? child
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: child,
            ),
    );
  }
}

/// White section titles above a row of [DetailFormValue]s.
class DetailTitleRow extends StatelessWidget {
  /// One title per value column.
  const DetailTitleRow({super.key, required this.titles});

  /// Titles, leading to trailing.
  final List<Widget> titles;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < titles.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: titles[i]),
          ],
        ],
      ),
    );
}
