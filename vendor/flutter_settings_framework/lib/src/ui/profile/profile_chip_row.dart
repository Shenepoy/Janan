import 'package:material_ui/material_ui.dart';

/// One chip in [ProfileChipRow].
class ProfileChip {
  const ProfileChip({
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final Widget label;
  final bool selected;
  final VoidCallback? onTap;
}

/// Horizontal wrap of selectable status / filter chips.
class ProfileChipRow extends StatelessWidget {
  const ProfileChipRow({
    super.key,
    required this.chips,
  });

  final List<ProfileChip> chips;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final chip in chips)
            FilterChip(
              label: chip.label,
              selected: chip.selected,
              onSelected: chip.onTap == null ? null : (_) => chip.onTap!(),
            ),
        ],
      ),
    );
  }
}
