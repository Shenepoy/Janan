import 'package:material_ui/material_ui.dart';

/// Shared type for card titles and supporting lines.
abstract final class AppText {
  /// Section / card heading.
  static TextStyle title(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.25,
      color: colors.onSurface,
    );
  }

  /// Date, comparison, and other supporting text next to a title.
  static TextStyle subtitle(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.3,
      color: colors.onSurfaceVariant,
    );
  }

  /// Colored field caption (sys / date / dose).
  static TextStyle label(BuildContext context, {Color? color}) {
    final colors = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: color ?? colors.onSurfaceVariant,
    );
  }
}
