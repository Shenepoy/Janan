import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';

import 'adaptive_sheet.dart';
import 'debug_menu.dart';
import 'sheet_shell.dart';

final _placeholderPattern = RegExp(r'\{\{[^}]+\}\}|\{[^}]*\}');

/// Persistence for [SafaehL10nOverrideStore].
abstract class SafaehL10nPersistence {
  Future<String?> read();
  Future<void> write(String json);
}

/// Host i18n engine + bundled maps.
abstract class SafaehL10nBackend {
  List<String> get locales;
  String get currentLocale;
  Map<String, String> bundled(String locale);
  Map<String, String> overrides(String locale);
  Future<void> setOverride(String locale, String key, String value);
  Future<void> clearOverrides();
  Future<void> applyLive();
  Listenable get revision;
}

/// In-memory persistence used by tests and the example catalog.
class SafaehMemoryL10nPersistence implements SafaehL10nPersistence {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String json) async {
    value = json;
  }
}

/// Pure-Dart flatten / merge / reverse-lookup store.
class SafaehL10nOverrideStore {
  SafaehL10nOverrideStore({required this.locales, this.persistence});

  final List<String> locales;
  final SafaehL10nPersistence? persistence;
  final ValueNotifier<int> revision = ValueNotifier(0);
  bool editMode = false;

  final Map<String, Map<String, String>> _overrides = {};
  final Map<String, Map<String, dynamic>> _bundled = {};

  int get overrideCount =>
      _overrides.values.fold<int>(0, (sum, map) => sum + map.length);

  Map<String, String> overridesFor(String locale) =>
      Map<String, String>.unmodifiable(_localeMap(locale));

  void setBundled(String locale, Map<String, dynamic> data) {
    _bundled[locale] = _deepCopy(data);
  }

  Map<String, dynamic> bundledSnapshot(String locale) =>
      _deepCopy(_bundled[locale] ?? const {});

  Map<String, dynamic> merged(String locale) {
    return mergeOnto(_deepCopy(_bundled[locale] ?? const {}), locale);
  }

  Map<String, dynamic> mergeOnto(Map<String, dynamic> bundled, String locale) {
    final result = _deepCopy(bundled);
    for (final entry in _localeMap(locale).entries) {
      _applyOverride(result, entry.key, entry.value);
    }
    return result;
  }

  void set(String locale, String key, String value) {
    final original = lookupValue(_bundled[locale] ?? const {}, key);
    final map = _localeMap(locale);
    if (original != null && original == value) {
      map.remove(key);
    } else {
      map[key] = value;
    }
  }

  void remove(String locale, String key) {
    _localeMap(locale).remove(key);
  }

  Future<void> clearAll() async {
    for (final map in _overrides.values) {
      map.clear();
    }
    await save();
  }

  Future<void> load() async {
    final raw = await persistence?.read();
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      editMode = decoded['editMode'] == true;
      for (final locale in locales) {
        _localeMap(locale)
          ..clear()
          ..addAll(_stringMap(decoded[locale]));
      }
    } catch (_) {}
  }

  Future<void> save() async {
    await persistence?.write(jsonEncode(_toPersistedJson()));
  }

  String exportJson() {
    return const JsonEncoder.withIndent('  ').convert({
      for (final locale in locales)
        locale: Map<String, String>.from(_localeMap(locale)),
    });
  }

  List<String> findKeysForText(String text, String locale) {
    final needle = text.trim();
    if (needle.isEmpty) return const [];

    final exact = <String>[];
    final fuzzy = <String>[];
    final matched = <String>{};

    void consider(Map<String, dynamic> source) {
      final flat = flattenStrings(source);
      for (final entry in flat.entries) {
        if (matched.contains(entry.key)) continue;
        final value = entry.value.trim();
        if (value == needle) {
          exact.add(entry.key);
          matched.add(entry.key);
          continue;
        }
        if (_placeholderPattern.hasMatch(entry.value) &&
            _placeholderMatches(entry.value, needle)) {
          fuzzy.add(entry.key);
          matched.add(entry.key);
        }
      }
    }

    consider(merged(locale));
    consider(_bundled[locale] ?? const {});
    for (final other in locales) {
      if (other == locale) continue;
      consider(merged(other));
      consider(_bundled[other] ?? const {});
    }
    return [...exact, ...fuzzy];
  }

  Map<String, String> flattenStrings(
    Map<String, dynamic> map, [
    String prefix = '',
  ]) {
    final out = <String, String>{};
    map.forEach((key, value) {
      final path = prefix.isEmpty ? key : '$prefix.$key';
      if (value is String) {
        out[path] = value;
      } else if (value is Map) {
        out.addAll(flattenStrings(Map<String, dynamic>.from(value), path));
      }
    });
    return out;
  }

  String? lookupValue(Map<String, dynamic> map, String key) {
    final direct = map[key];
    if (direct is String) return direct;
    if (!key.contains('.')) return null;
    dynamic current = map;
    for (final part in key.split('.')) {
      if (current is! Map) return null;
      current = current[part];
    }
    return current is String ? current : null;
  }

  Map<String, String> _localeMap(String locale) {
    return _overrides.putIfAbsent(locale, () => <String, String>{});
  }

  Map<String, Object> _toPersistedJson() {
    return {
      'editMode': editMode,
      for (final locale in locales)
        locale: Map<String, String>.from(_localeMap(locale)),
    };
  }
}

/// Long-press wrapper that opens the localization editor.
class SafaehL10nEditOverlay extends StatefulWidget {
  const SafaehL10nEditOverlay({
    super.key,
    required this.backend,
    required this.store,
    required this.navigatorKey,
    required this.child,
    this.labels = const SafaehL10nEditorLabels(),
    this.onExit,
    this.onShare,
  });

  final SafaehL10nBackend backend;
  final SafaehL10nOverrideStore store;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final SafaehL10nEditorLabels labels;
  final VoidCallback? onExit;
  final Future<void> Function(BuildContext context, String json)? onShare;

  @override
  State<SafaehL10nEditOverlay> createState() => _SafaehL10nEditOverlayState();
}

class _SafaehL10nEditOverlayState extends State<SafaehL10nEditOverlay> {
  bool _sessionOpen = false;

  Future<void> _beginSession(Future<void> Function() action) async {
    setState(() => _sessionOpen = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _sessionOpen = false);
    }
  }

  BuildContext? get _navContext {
    final nav = widget.navigatorKey.currentContext;
    if (nav == null || !nav.mounted) return null;
    return nav;
  }

  Future<void> _onLongPress(Offset globalPosition) async {
    if (_sessionOpen) return;
    final texts = safaehCollectPlainTextsAt(context, globalPosition);
    await _beginSession(() => _handlePickedTexts(texts));
  }

  Future<void> _handlePickedTexts(List<String> texts) async {
    final locale = widget.backend.currentLocale;
    final keys = <String>{};
    for (final text in texts) {
      keys.addAll(widget.store.findKeysForText(text, locale));
    }
    if (keys.isEmpty) {
      await _openSearchSheet(initialQuery: texts.isEmpty ? '' : texts.first);
      return;
    }
    if (keys.length == 1) {
      await _openEditor(keys.first);
      return;
    }
    await _openCandidateSheet(keys.toList());
  }

  Future<void> _openCandidateSheet(List<String> keys) async {
    final nav = _navContext;
    if (nav == null) return;
    final locale = widget.backend.currentLocale;
    final selected = await _showLtrSheet<String>(
      context: nav,
      title: widget.labels.keysTitle,
      child: buildSafaehSheetShell(
        showTitleInBody: false,
        body: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final key in keys)
                Builder(
                  builder: (sheetContext) => ListTile(
                    title: Text(key),
                    subtitle: Text(
                      widget.store.lookupValue(
                            widget.store.merged(locale),
                            key,
                          ) ??
                          '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(key),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) await _openEditor(selected);
  }

  Future<void> _openSearchSheet({String initialQuery = ''}) async {
    final nav = _navContext;
    if (nav == null) return;
    final selected = await _showLtrSheet<String>(
      context: nav,
      title: widget.labels.searchTitle,
      child: _SafaehL10nSearchBody(
        store: widget.store,
        locales: widget.backend.locales,
        initialQuery: initialQuery,
        labels: widget.labels,
      ),
    );
    if (selected != null && mounted) await _openEditor(selected);
  }

  Future<void> _openEditor(String key) async {
    final nav = _navContext;
    if (nav == null) return;
    await _showLtrSheet<void>(
      context: nav,
      title: widget.labels.editTitle,
      child: _SafaehL10nEditorBody(
        translationKey: key,
        backend: widget.backend,
        store: widget.store,
        labels: widget.labels,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPressStart: (details) =>
              unawaited(_onLongPress(details.globalPosition)),
          child: widget.child,
        ),
        if (!_sessionOpen)
          Positioned(
            top: MediaQuery.paddingOf(context).top + kToolbarHeight,
            left: 8,
            right: 8,
            child: Material(
              color: colorScheme.errorContainer.withValues(alpha: 0.94),
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.translate,
                      size: 18,
                      color: colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.labels.banner,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: colorScheme.onErrorContainer),
                      ),
                    ),
                    IconButton(
                      tooltip: widget.labels.exitTooltip,
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.onExit,
                      icon: Icon(
                        Icons.close,
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Collects plain [RenderParagraph] strings under [globalPosition].
List<String> safaehCollectPlainTextsAt(
  BuildContext context,
  Offset globalPosition,
) {
  final texts = <String>[];
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderObject) return texts;
  void visit(RenderObject node) {
    if (node is RenderParagraph) {
      final box = node;
      if (box.hasSize &&
          box.paintBounds
              .shift(box.localToGlobal(Offset.zero))
              .contains(globalPosition)) {
        final text = box.text.toPlainText();
        if (text.trim().isNotEmpty) texts.add(text);
      }
    }
    node.visitChildren(visit);
  }

  visit(renderObject);
  return texts;
}

Future<T?> _showLtrSheet<T>({
  required BuildContext context,
  required String title,
  required Widget child,
}) {
  return showSafaeh<T>(
    context: context,
    title: title,
    titleBuilder: (ctx, style) => Text(
      title,
      style: style,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    maxHeight: MediaQuery.sizeOf(context).height * 0.75,
    child: Directionality(textDirection: TextDirection.ltr, child: child),
  );
}

class _SafaehL10nSearchBody extends StatefulWidget {
  const _SafaehL10nSearchBody({
    required this.store,
    required this.locales,
    required this.initialQuery,
    required this.labels,
  });

  final SafaehL10nOverrideStore store;
  final List<String> locales;
  final String initialQuery;
  final SafaehL10nEditorLabels labels;

  @override
  State<_SafaehL10nSearchBody> createState() => _SafaehL10nSearchBodyState();
}

class _SafaehL10nSearchBodyState extends State<_SafaehL10nSearchBody> {
  late final TextEditingController _controller;
  late List<({String key, String preview})> _hits;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _hits = _search(widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<({String key, String preview})> _search(String query) {
    final needle = query.trim().toLowerCase();
    final hits = <({String key, String preview})>[];
    final seen = <String>{};
    for (final locale in widget.locales) {
      final flat = widget.store.flattenStrings(widget.store.merged(locale));
      flat.forEach((key, value) {
        if (!seen.add(key)) return;
        if (needle.isEmpty ||
            key.toLowerCase().contains(needle) ||
            value.toLowerCase().contains(needle)) {
          hits.add((key: key, preview: value));
        }
      });
    }
    hits.sort((a, b) => a.key.compareTo(b.key));
    return hits.take(80).toList();
  }

  @override
  Widget build(BuildContext context) {
    return buildSafaehSheetShell(
      showTitleInBody: false,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              hintText: widget.labels.searchHint,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _hits = _search(value)),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final hit in _hits)
                  ListTile(
                    title: Text(hit.key),
                    subtitle: Text(
                      hit.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.of(context).pop(hit.key),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SafaehL10nEditorBody extends StatefulWidget {
  const _SafaehL10nEditorBody({
    required this.translationKey,
    required this.backend,
    required this.store,
    required this.labels,
  });

  final String translationKey;
  final SafaehL10nBackend backend;
  final SafaehL10nOverrideStore store;
  final SafaehL10nEditorLabels labels;

  @override
  State<_SafaehL10nEditorBody> createState() => _SafaehL10nEditorBodyState();
}

class _SafaehL10nEditorBodyState extends State<_SafaehL10nEditorBody> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final locale in widget.backend.locales)
        locale: TextEditingController(
          text:
              widget.store.overridesFor(locale)[widget.translationKey] ??
              widget.store.lookupValue(
                widget.store.merged(locale),
                widget.translationKey,
              ) ??
              '',
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    for (final entry in _controllers.entries) {
      widget.store.set(entry.key, widget.translationKey, entry.value.text);
      await widget.backend.setOverride(
        entry.key,
        widget.translationKey,
        entry.value.text,
      );
    }
    await widget.store.save();
    await widget.backend.applyLive();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return buildSafaehSheetShell(
      showTitleInBody: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.translationKey,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
          for (final locale in widget.backend.locales) ...[
            Text(locale, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            TextField(
              controller: _controllers[locale],
              maxLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => unawaited(_save()),
          child: Text(widget.labels.save),
        ),
      ],
    );
  }
}

Map<String, String> _stringMap(Object? raw) {
  if (raw is! Map) return {};
  final out = <String, String>{};
  raw.forEach((key, value) {
    if (key is String && value is String) {
      out[key] = value;
    }
  });
  return out;
}

Map<String, dynamic> _deepCopy(Map<String, dynamic> source) {
  final result = <String, dynamic>{};
  source.forEach((key, value) {
    if (value is Map) {
      result[key] = _deepCopy(Map<String, dynamic>.from(value));
    } else {
      result[key] = value;
    }
  });
  return result;
}

void _applyOverride(Map<String, dynamic> target, String key, String value) {
  if (!key.contains('.')) {
    target[key] = value;
    return;
  }
  final parts = key.split('.');
  Map<String, dynamic> current = target;
  for (var i = 0; i < parts.length - 1; i++) {
    final next = current[parts[i]];
    if (next is Map<String, dynamic>) {
      current = next;
    } else if (next is Map) {
      final copy = Map<String, dynamic>.from(next);
      current[parts[i]] = copy;
      current = copy;
    } else {
      target[key] = value;
      return;
    }
  }
  current[parts.last] = value;
}

bool _placeholderMatches(String template, String text) {
  final buffer = StringBuffer('^');
  var start = 0;
  for (final match in _placeholderPattern.allMatches(template)) {
    buffer.write(RegExp.escape(template.substring(start, match.start)));
    buffer.write('.*');
    start = match.end;
  }
  buffer.write(RegExp.escape(template.substring(start)));
  buffer.write(r'$');
  return RegExp(buffer.toString(), dotAll: true).hasMatch(text);
}
