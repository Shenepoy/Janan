import 'package:characters/characters.dart';

/// Latin and Cyrillic countdown labels may show this many characters.
const medicineNameLimit = 8;

/// Short label for a countdown.
///
/// The script of [name] chooses the cutoff. Anything longer is cut with an
/// ellipsis. [wide] is the larger in-app timer.
String compactMedicineName(String name, {int? limit, bool wide = false}) {
  final trimmed = name.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (trimmed.isEmpty) return trimmed;
  final resolved = limit ?? _nameLimit(trimmed) * (wide ? 2 : 1);
  if (trimmed.characters.length <= resolved) return trimmed;
  final keep = resolved - 1;
  if (keep <= 0) return '…';
  return '${trimmed.characters.take(keep)}…';
}

int _nameLimit(String name) {
  var script = _Script.cased;
  for (final grapheme in name.characters) {
    final next = _script(grapheme);
    if (next == _Script.other) continue;
    if (next == _Script.wide) return 4;
    if (next == _Script.arabic) script = _Script.arabic;
    if (script != _Script.arabic) script = next;
  }
  return switch (script) {
    _Script.arabic => 6,
    _Script.wide => 4,
    _ => medicineNameLimit,
  };
}

enum _Script { cased, arabic, wide, other }

_Script _script(String grapheme) {
  if (grapheme.isEmpty) return _Script.other;
  final rune = grapheme.runes.first;
  if (_cased(rune)) return _Script.cased;
  if (_arabic(rune) || (rune >= 0x0590 && rune <= 0x05FF)) {
    return _Script.arabic;
  }
  if (_wide(rune)) return _Script.wide;
  return _Script.other;
}

bool _cased(int rune) =>
    rune <= 0x024F ||
    (rune >= 0x0370 && rune <= 0x03FF) ||
    (rune >= 0x0400 && rune <= 0x052F) ||
    (rune >= 0x1E00 && rune <= 0x1EFF);

bool _arabic(int rune) =>
    (rune >= 0x0600 && rune <= 0x06FF) ||
    (rune >= 0x0750 && rune <= 0x077F) ||
    (rune >= 0x08A0 && rune <= 0x08FF) ||
    (rune >= 0xFB50 && rune <= 0xFDFF) ||
    (rune >= 0xFE70 && rune <= 0xFEFF);

bool _wide(int rune) =>
    (rune >= 0x0B80 && rune <= 0x0BFF) ||
    (rune >= 0x3040 && rune <= 0x30FF) ||
    (rune >= 0x3400 && rune <= 0x4DBF) ||
    (rune >= 0x4E00 && rune <= 0x9FFF) ||
    (rune >= 0xAC00 && rune <= 0xD7AF);
