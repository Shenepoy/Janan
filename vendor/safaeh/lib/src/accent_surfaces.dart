import 'package:material_ui/material_ui.dart';

import 'theme.dart';

/// Appearance preference: tone down decorative accent fills.
@immutable
class SafaehAccentStyle extends ThemeExtension<SafaehAccentStyle> {
  const SafaehAccentStyle({this.subtleAccents = false});

  final bool subtleAccents;

  @override
  SafaehAccentStyle copyWith({bool? subtleAccents}) {
    return SafaehAccentStyle(
      subtleAccents: subtleAccents ?? this.subtleAccents,
    );
  }

  @override
  SafaehAccentStyle lerp(ThemeExtension<SafaehAccentStyle>? other, double t) {
    if (other is! SafaehAccentStyle) return this;
    if (t < 0.5) return this;
    return other;
  }
}

extension SafaehAccentStyleContext on BuildContext {
  /// When true, prefer flat surfaces over accent gradients / tints.
  bool get safaehSubtleAccents =>
      Theme.of(this).extension<SafaehAccentStyle>()?.subtleAccents ?? false;
}

/// Shared decorations for bordered panels and accent heroes.
abstract final class SafaehAccentSurfaces {
  /// Flat bordered surface used for list/form chrome.
  static BoxDecoration flatPanel(
    ColorScheme colorScheme, {
    double? radius,
    BuildContext? context,
  }) {
    final resolved =
        radius ?? (context != null ? SafaehTheme.of(context).radius : 16);
    return BoxDecoration(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(resolved),
      border: Border.all(
        color: colorScheme.outlineVariant.withValues(alpha: 0.45),
      ),
    );
  }

  /// Hero/summary panel; when [subtle] is true, matches [flatPanel].
  static BoxDecoration panel(
    ColorScheme colorScheme, {
    required bool subtle,
    Color? accentContainer,
    Color? accentBorder,
    double? radius,
    BuildContext? context,
  }) {
    final resolved =
        radius ?? (context != null ? SafaehTheme.of(context).radius : 16);
    if (subtle) {
      return flatPanel(colorScheme, radius: resolved, context: context);
    }
    final container = accentContainer ?? colorScheme.primaryContainer;
    final border = accentBorder ?? colorScheme.primary;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(resolved),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          container.withValues(alpha: 0.9),
          colorScheme.surfaceContainerLow,
        ],
      ),
      border: Border.all(color: border.withValues(alpha: 0.14)),
    );
  }

  static Color sectionBar(ColorScheme colorScheme, {required bool subtle}) {
    return subtle ? colorScheme.outlineVariant : colorScheme.primary;
  }

  static Color emphasizedFill(ColorScheme colorScheme, {required bool subtle}) {
    return subtle
        ? colorScheme.surfaceContainerLow
        : colorScheme.primaryContainer.withValues(alpha: 0.35);
  }

  static Color emphasizedBorder(
    ColorScheme colorScheme, {
    required bool subtle,
  }) {
    return subtle
        ? colorScheme.outlineVariant.withValues(alpha: 0.45)
        : colorScheme.primary.withValues(alpha: 0.22);
  }
}

/// Applies [SafaehAccentStyle] without dropping other theme extensions.
ThemeData withSafaehAccentStyle(
  ThemeData theme, {
  required bool subtleAccents,
}) {
  final exts = List<ThemeExtension<dynamic>>.from(
    theme.extensions.values.where((e) => e is! SafaehAccentStyle),
  )..add(SafaehAccentStyle(subtleAccents: subtleAccents));
  return theme.copyWith(extensions: exts);
}
