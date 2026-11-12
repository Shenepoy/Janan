import 'package:material_ui/material_ui.dart';

/// Unicode FSI (U+2068) / PDI (U+2069): isolate user-generated content inside
/// mixed-direction strings (e.g. `"$title – $amount"`, translated templates).
///
/// Display-only — never persist the result.
String safaehIsolateBidi(String text) => '\u2068$text\u2069';

/// Strip bidi isolates for equality / test helpers.
String safaehUnwrapBidiIsolates(String text) =>
    text.replaceAll('\u2068', '').replaceAll('\u2069', '');

/// Base direction for standalone UGC so truncation ellipsis follows the
/// content's script, not only the ambient UI locale.
///
/// Returns null when [text] has no strong directional characters (inherit).
TextDirection? safaehResolveUserTextDirection(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  var sawRtl = false;
  var sawLtr = false;
  for (final unit in trimmed.runes) {
    if (_isRtl(unit)) {
      sawRtl = true;
    } else if (_isLtr(unit)) {
      sawLtr = true;
    }
    if (sawRtl && sawLtr) break;
  }
  if (!sawRtl && !sawLtr) return null;
  // First strong character wins, matching typical bidi first-strong.
  for (final unit in trimmed.runes) {
    if (_isRtl(unit)) return TextDirection.rtl;
    if (_isLtr(unit)) return TextDirection.ltr;
  }
  return null;
}

/// Align UGC to the ambient UI start edge (right in RTL, left in LTR).
TextAlign safaehResolveUiStartTextAlign(TextDirection uiDirection) {
  return uiDirection == TextDirection.rtl ? TextAlign.right : TextAlign.left;
}

bool _isRtl(int unit) {
  return (unit >= 0x0590 && unit <= 0x08FF) ||
      (unit >= 0xFB1D && unit <= 0xFDFF) ||
      (unit >= 0xFE70 && unit <= 0xFEFF);
}

bool _isLtr(int unit) {
  return (unit >= 0x0041 && unit <= 0x005A) ||
      (unit >= 0x0061 && unit <= 0x007A) ||
      (unit >= 0x00C0 && unit <= 0x024F) ||
      (unit >= 0x0400 && unit <= 0x04FF) ||
      (unit >= 0x3040 && unit <= 0x30FF) ||
      (unit >= 0x4E00 && unit <= 0x9FFF) ||
      (unit >= 0xAC00 && unit <= 0xD7AF);
}

/// Grapheme-safe hard elide (emoji / ZWJ / flags stay intact).
String safaehElideGraphemes(
  String text, {
  required int maxGraphemes,
  String ellipsis = '…',
  bool trimInput = true,
}) {
  assert(maxGraphemes >= 0);
  final source = trimInput ? text.trim() : text;
  if (source.isEmpty || maxGraphemes == 0) {
    return maxGraphemes == 0 && source.isNotEmpty ? ellipsis : source;
  }
  final ch = Characters(source);
  if (ch.length <= maxGraphemes) return source;
  return '${ch.take(maxGraphemes).string}$ellipsis';
}

/// Displays user-generated text with a content-based [textDirection] so
/// truncation / ellipsis follow the script order rather than only the UI
/// locale.
///
/// Default [textAlign] follows the ambient UI start edge so Latin names stay
/// beside leading avatars/icons in RTL layouts.
class SafaehUserText extends StatelessWidget {
  const SafaehUserText(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap = true,
    this.textWidthBasis,
    this.strutStyle,
    this.semanticsLabel,
    this.maxGraphemes,
  });

  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool softWrap;
  final TextWidthBasis? textWidthBasis;
  final StrutStyle? strutStyle;
  final String? semanticsLabel;

  /// Optional grapheme budget before layout ellipsis.
  final int? maxGraphemes;

  @override
  Widget build(BuildContext context) {
    final display = maxGraphemes != null
        ? safaehElideGraphemes(data, maxGraphemes: maxGraphemes!)
        : data;
    final resolvedAlign =
        textAlign ?? safaehResolveUiStartTextAlign(Directionality.of(context));
    return Text(
      display,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: resolvedAlign,
      softWrap: softWrap,
      textWidthBasis: textWidthBasis,
      strutStyle: strutStyle,
      semanticsLabel: semanticsLabel ?? data,
      textDirection: safaehResolveUserTextDirection(display),
    );
  }
}
