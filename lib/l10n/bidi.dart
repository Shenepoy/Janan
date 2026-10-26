import 'package:flutter/painting.dart';
import 'package:safaeh/safaeh.dart';

export 'package:safaeh/safaeh.dart'
    show
        safaehIsolateBidi,
        safaehUnwrapBidiIsolates,
        safaehResolveUserTextDirection,
        safaehResolveUiStartTextAlign,
        safaehElideGraphemes;

/// Display-only bidi isolate. Prefer [safaehIsolateBidi] in new code.
String isolateBidi(String text) => safaehIsolateBidi(text);

/// Strip bidi isolates for equality / test helpers.
String unwrapBidiIsolates(String text) => safaehUnwrapBidiIsolates(text);

/// Keep readings and SI units LTR inside RTL copy.
String isolateLtr(String text) => safaehIsolateBidi(text);

/// Keeps inline format codes intact in Arabic Markdown without changing prose
/// direction or fenced code blocks. Use only for display.
String isolateMarkdownCodes(String markdown) => markdown.replaceAllMapped(
  RegExp(r'(?<!`)`([^`\n]+)`(?!`)'),
  (match) => isolateLtr(match[0]!),
);

/// Base direction for standalone user-generated copy.
TextDirection? resolveUserTextDirection(String text) =>
    safaehResolveUserTextDirection(text);
