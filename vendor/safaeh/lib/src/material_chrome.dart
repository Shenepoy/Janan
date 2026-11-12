import 'package:material_ui/material_ui.dart';

/// Radii and chrome metrics passed to [applySafaehMaterialChrome].
class SafaehMaterialRadii {
  const SafaehMaterialRadii({
    this.card = 12,
    this.input = 12,
    this.chip = 16,
    this.snackBar = 8,
    this.appBarCenterTitle = true,
    this.appBarElevation = 0,
    this.dividerThickness = 1,
    this.dividerSpacing = 1,
    this.inputDefaultBorderWidth = 1,
    this.inputFocusedBorderWidth = 2,
    this.cardElevation = 0,
  });

  final double card;
  final double input;
  final double chip;
  final double snackBar;
  final bool appBarCenterTitle;
  final double appBarElevation;
  final double dividerThickness;
  final double dividerSpacing;
  final double inputDefaultBorderWidth;
  final double inputFocusedBorderWidth;
  final double cardElevation;
}

/// Shared text scale used by host theme builders.
TextTheme scaleSafaehTextTheme(TextTheme baseTextTheme, double scaleFactor) {
  return TextTheme(
    displayLarge: baseTextTheme.displayLarge?.copyWith(
      fontSize: (baseTextTheme.displayLarge?.fontSize ?? 57) * scaleFactor,
    ),
    displayMedium: baseTextTheme.displayMedium?.copyWith(
      fontSize: (baseTextTheme.displayMedium?.fontSize ?? 45) * scaleFactor,
    ),
    displaySmall: baseTextTheme.displaySmall?.copyWith(
      fontSize: (baseTextTheme.displaySmall?.fontSize ?? 36) * scaleFactor,
    ),
    headlineLarge: baseTextTheme.headlineLarge?.copyWith(
      fontSize: (baseTextTheme.headlineLarge?.fontSize ?? 32) * scaleFactor,
    ),
    headlineMedium: baseTextTheme.headlineMedium?.copyWith(
      fontSize: (baseTextTheme.headlineMedium?.fontSize ?? 28) * scaleFactor,
    ),
    headlineSmall: baseTextTheme.headlineSmall?.copyWith(
      fontSize: (baseTextTheme.headlineSmall?.fontSize ?? 24) * scaleFactor,
    ),
    titleLarge: baseTextTheme.titleLarge?.copyWith(
      fontSize: (baseTextTheme.titleLarge?.fontSize ?? 22) * scaleFactor,
    ),
    titleMedium: baseTextTheme.titleMedium?.copyWith(
      fontSize: (baseTextTheme.titleMedium?.fontSize ?? 16) * scaleFactor,
    ),
    titleSmall: baseTextTheme.titleSmall?.copyWith(
      fontSize: (baseTextTheme.titleSmall?.fontSize ?? 14) * scaleFactor,
    ),
    bodyLarge: baseTextTheme.bodyLarge?.copyWith(
      fontSize: (baseTextTheme.bodyLarge?.fontSize ?? 16) * scaleFactor,
    ),
    bodyMedium: baseTextTheme.bodyMedium?.copyWith(
      fontSize: (baseTextTheme.bodyMedium?.fontSize ?? 14) * scaleFactor,
    ),
    bodySmall: baseTextTheme.bodySmall?.copyWith(
      fontSize: (baseTextTheme.bodySmall?.fontSize ?? 12) * scaleFactor,
    ),
    labelLarge: baseTextTheme.labelLarge?.copyWith(
      fontSize: (baseTextTheme.labelLarge?.fontSize ?? 14) * scaleFactor,
    ),
    labelMedium: baseTextTheme.labelMedium?.copyWith(
      fontSize: (baseTextTheme.labelMedium?.fontSize ?? 12) * scaleFactor,
    ),
    labelSmall: baseTextTheme.labelSmall?.copyWith(
      fontSize: (baseTextTheme.labelSmall?.fontSize ?? 11) * scaleFactor,
    ),
  );
}

/// Material chrome shared by host theme factories.
///
/// Hosts still own fonts, seed colors, and their own [ThemeExtension]s.
/// Call this, then `copyWith(extensions:)` for host tokens.
ThemeData applySafaehMaterialChrome(
  ThemeData theme, {
  required ColorScheme colorScheme,
  required TextTheme textTheme,
  required Color dividerColor,
  required Color outlineColor,
  required Color errorColor,
  required Color primarySeed,
  Color? iconColor,
  bool alwaysShowScrollbars = false,
  PageTransitionsTheme? pageTransitionsTheme,
  SafaehMaterialRadii radii = const SafaehMaterialRadii(),
}) {
  return theme.copyWith(
    colorScheme: colorScheme,
    textTheme: textTheme,
    pageTransitionsTheme: pageTransitionsTheme ?? theme.pageTransitionsTheme,
    iconTheme: IconThemeData(color: iconColor ?? colorScheme.onSurface),
    scrollbarTheme: alwaysShowScrollbars
        ? ScrollbarThemeData(
            thumbVisibility: WidgetStateProperty.all(true),
            trackVisibility: WidgetStateProperty.all(true),
          )
        : theme.scrollbarTheme,
    appBarTheme: AppBarTheme(
      centerTitle: radii.appBarCenterTitle,
      elevation: radii.appBarElevation,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      iconTheme: IconThemeData(color: colorScheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: radii.cardElevation,
      shadowColor: colorScheme.brightness == Brightness.dark
          ? Colors.black.withValues(alpha: 0.45)
          : colorScheme.shadow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radii.card),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      color: colorScheme.surfaceContainerHighest,
    ),
    dividerTheme: DividerThemeData(
      color: dividerColor,
      thickness: radii.dividerThickness,
      space: radii.dividerSpacing,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radii.input),
        borderSide: BorderSide(
          color: outlineColor,
          width: radii.inputDefaultBorderWidth,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radii.input),
        borderSide: BorderSide(
          color: outlineColor,
          width: radii.inputDefaultBorderWidth,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radii.input),
        borderSide: BorderSide(
          color: primarySeed,
          width: radii.inputFocusedBorderWidth,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radii.input),
        borderSide: BorderSide(
          color: errorColor,
          width: radii.inputDefaultBorderWidth,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radii.chip),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colorScheme.surfaceContainerHighest,
      contentTextStyle: TextStyle(color: colorScheme.onSurface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radii.snackBar),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
