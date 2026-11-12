import 'package:material_ui/material_ui.dart';

/// Compact color-chip legend for sys / dia / pul series.
class ChartLegend extends StatelessWidget {
  /// Create a legend from [items] of label and color.
  const ChartLegend({super.key, required this.items});

  /// Entries shown left to right.
  final List<(String, Color)> items;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: item.$2,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(item.$1, style: style),
            ],
          ),
      ],
    );
  }
}
