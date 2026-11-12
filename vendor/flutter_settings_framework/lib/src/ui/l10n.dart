/// Shared i18n / RTL helpers for settings chrome.
library;

import 'package:material_ui/material_ui.dart';

/// Isolates Latin codes, hex, versions, and numerals from ambient RTL.
class SettingsLtr extends StatelessWidget {
  const SettingsLtr({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: child,
    );
  }
}

/// End-pointing chevron (forward / open).
///
/// Always uses the LTR glyph. [Icons.chevron_right] already sets
/// [IconData.matchTextDirection], so [Icon] mirrors it in RTL. Picking
/// [Icons.chevron_left] in Arabic would flip twice and point the wrong way.
Icon settingsChevronEnd(
  BuildContext context, {
  Color? color,
  double? size,
}) {
  assert(debugCheckHasDirectionality(context));
  return Icon(
    Icons.chevron_right,
    color: color,
    size: size,
  );
}

/// Section › title in LTR, section ‹ title in RTL.
String settingsBreadcrumb(
  String section,
  String title,
  TextDirection direction,
) {
  final sep = direction == TextDirection.rtl ? ' ‹ ' : ' › ';
  return '$section$sep$title';
}

/// Package fallback empty-search copy with locale-appropriate quotes.
String settingsEmptySearchFallback(String query, TextDirection direction) {
  final quoted = direction == TextDirection.rtl ? '«$query»' : '"$query"';
  return 'No settings found for $quoted';
}

/// Undo chrome when the host does not pass [AppSnackbar.undo] a label.
String settingsUndoLabel(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'ar'
      ? 'تراجع'
      : 'Undo';
}

/// Material palette name for color-picker rows.
String settingsMaterialColorName(BuildContext context, MaterialColor color) {
  final ar = Localizations.localeOf(context).languageCode == 'ar';
  final names = ar ? _materialColorNamesAr : _materialColorNamesEn;
  return names[color.toARGB32()] ?? (ar ? 'لون' : 'Color');
}

const _materialColorNamesEn = <int, String>{
  0xFFF44336: 'Red',
  0xFFE91E63: 'Pink',
  0xFF9C27B0: 'Purple',
  0xFF673AB7: 'Deep Purple',
  0xFF3F51B5: 'Indigo',
  0xFF2196F3: 'Blue',
  0xFF03A9F4: 'Light Blue',
  0xFF00BCD4: 'Cyan',
  0xFF009688: 'Teal',
  0xFF4CAF50: 'Green',
  0xFF8BC34A: 'Light Green',
  0xFFCDDC39: 'Lime',
  0xFFFFEB3B: 'Yellow',
  0xFFFFC107: 'Amber',
  0xFFFF9800: 'Orange',
  0xFFFF5722: 'Deep Orange',
  0xFF795548: 'Brown',
  0xFF9E9E9E: 'Grey',
  0xFF607D8B: 'Blue Grey',
};

const _materialColorNamesAr = <int, String>{
  0xFFF44336: 'أحمر',
  0xFFE91E63: 'وردي',
  0xFF9C27B0: 'بنفسجي',
  0xFF673AB7: 'بنفسجي غامق',
  0xFF3F51B5: 'نيلي',
  0xFF2196F3: 'أزرق',
  0xFF03A9F4: 'أزرق فاتح',
  0xFF00BCD4: 'سماوي',
  0xFF009688: 'أخضر مزرق',
  0xFF4CAF50: 'أخضر',
  0xFF8BC34A: 'أخضر فاتح',
  0xFFCDDC39: 'ليموني',
  0xFFFFEB3B: 'أصفر',
  0xFFFFC107: 'كهرماني',
  0xFFFF9800: 'برتقالي',
  0xFFFF5722: 'برتقالي غامق',
  0xFF795548: 'بني',
  0xFF9E9E9E: 'رمادي',
  0xFF607D8B: 'رمادي مزرق',
};
