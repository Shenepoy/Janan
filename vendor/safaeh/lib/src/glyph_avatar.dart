import 'package:material_ui/material_ui.dart';

/// Circle (or rounded-square) glyph for groups, senders, and list leadings.
///
/// Use [SafaehSidenavAvatar] for the rail profile plate (primary fill,
/// two-letter initials). This is icon-or-letter chrome for list tiles.
class SafaehGlyphAvatar extends StatelessWidget {
  const SafaehGlyphAvatar({
    super.key,
    this.icon,
    this.letter,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
    this.square = false,
  });

  final IconData? icon;

  /// First grapheme of [letter], or `?` when empty / null.
  final String? letter;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bg = backgroundColor ?? cs.primaryContainer;
    final fg = foregroundColor ?? cs.onPrimaryContainer;
    final size = radius * 2;
    final raw = (letter ?? '?').trim();
    final glyph = raw.isEmpty ? '?' : raw.characters.first.toUpperCase();
    final child = icon != null
        ? Icon(icon, color: fg, size: radius)
        : Text(
            glyph,
            style: theme.textTheme.titleMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          );
    if (square) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius * 0.45),
        ),
        alignment: Alignment.center,
        child: child,
      );
    }
    return CircleAvatar(radius: radius, backgroundColor: bg, child: child);
  }
}
