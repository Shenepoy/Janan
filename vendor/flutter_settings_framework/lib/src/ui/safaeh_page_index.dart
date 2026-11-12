import 'package:material_ui/material_ui.dart';
import 'package:safaeh/safaeh.dart' as safaeh;

import '../core/setting_definition.dart';

/// Converts Edadat sections into Safaeh page-index entries.
///
/// Sections without a corresponding key are omitted. This lets hosts hide
/// feature-gated sections without maintaining a second list of index entries.
List<safaeh.SafaehPageIndexEntry> safaehSettingsPageIndexEntries({
  required Iterable<SettingSection> sections,
  required Map<String, GlobalKey> sectionKeys,
  required String Function(SettingSection section) labelBuilder,
}) {
  final entries = <safaeh.SafaehPageIndexEntry>[];
  for (final section in sections) {
    final key = sectionKeys[section.key];
    if (key == null) continue;
    entries.add(
      safaeh.SafaehPageIndexEntry(
        id: section.key,
        label: labelBuilder(section),
        key: key,
        icon: section.icon,
      ),
    );
  }
  return entries;
}

/// Safaeh's wide-layout page index backed by Edadat sections.
class SafaehSettingsPageIndex extends StatelessWidget {
  const SafaehSettingsPageIndex({
    super.key,
    required this.title,
    required this.sections,
    required this.sectionKeys,
    required this.labelBuilder,
    required this.activeId,
    required this.onSelect,
  });

  final String title;
  final List<SettingSection> sections;
  final Map<String, GlobalKey> sectionKeys;
  final String Function(SettingSection section) labelBuilder;
  final String? activeId;
  final ValueChanged<SettingSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final entries = safaehSettingsPageIndexEntries(
      sections: sections,
      sectionKeys: sectionKeys,
      labelBuilder: labelBuilder,
    );
    final sectionsById = <String, SettingSection>{
      for (final section in sections) section.key: section,
    };

    return safaeh.SafaehPageIndex(
      title: title,
      entries: entries,
      activeId: activeId,
      onSelect: (entry) {
        final section = sectionsById[entry.id];
        if (section != null) onSelect(section);
      },
    );
  }
}

/// Safaeh's narrow-layout page-index overlay backed by Edadat sections.
class SafaehSettingsPageIndexOverlay extends StatelessWidget {
  const SafaehSettingsPageIndexOverlay({
    super.key,
    required this.title,
    required this.sections,
    required this.sectionKeys,
    required this.labelBuilder,
    required this.activeId,
    required this.onSelect,
    this.bottomInset,
  });

  final String title;
  final List<SettingSection> sections;
  final Map<String, GlobalKey> sectionKeys;
  final String Function(SettingSection section) labelBuilder;
  final String? activeId;
  final ValueChanged<SettingSection> onSelect;
  final double? bottomInset;

  @override
  Widget build(BuildContext context) {
    final entries = safaehSettingsPageIndexEntries(
      sections: sections,
      sectionKeys: sectionKeys,
      labelBuilder: labelBuilder,
    );
    final sectionsById = <String, SettingSection>{
      for (final section in sections) section.key: section,
    };

    return safaeh.SafaehPageIndexOverlay(
      title: title,
      entries: entries,
      activeId: activeId,
      bottomInset: bottomInset,
      onSelect: (entry) {
        final section = sectionsById[entry.id];
        if (section != null) onSelect(section);
      },
    );
  }
}

/// Resolves the active Edadat section using Safaeh's scroll spy.
String? activeSafaehSettingsSectionId({
  required Iterable<SettingSection> sections,
  required Map<String, GlobalKey> sectionKeys,
  required BuildContext scrollContext,
  double activationOffset = 96,
}) {
  final targets = <(String, GlobalKey)>[];
  for (final section in sections) {
    final key = sectionKeys[section.key];
    if (key != null) targets.add((section.key, key));
  }
  return safaeh.safaehActivePageSectionId(
    sections: targets,
    scrollContext: scrollContext,
    activationOffset: activationOffset,
  );
}
