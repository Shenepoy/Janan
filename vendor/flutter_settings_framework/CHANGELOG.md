# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

Tags are `vX.Y.Z` and must match `version:` in [`pubspec.yaml`](pubspec.yaml).
See [VERSIONING.md](VERSIONING.md).

## [Unreleased]

## [0.11.0] - 2026-10-16

### Added

- `SettingsSectionNavigation` coordinates expansion, latest-request wins,
  cancellation, and scroll-spy suppression for section navigation.
- `SettingsSectionList` keeps bounded catalog anchors measurable so page-index
  navigation can animate directly to distant sections.

### Changed

- Registry pages use coordinated navigation and measurable stacked sections.
- Depend on Safaeh ^0.12.0.


### Changed

- Align CI and version checks with Safaeh: require a CHANGELOG heading for
  the current pubspec version, exclude `example/` from the package analyzer,
  and drop the per-push publish dry-run (Release still dry-runs before
  pub.dev).

## [0.10.0] - 2026-10-10

### Added

- `SettingsCollapsibleSubsection` starts closed, turns its chevron over
  200 ms, and grows downward so rows above the header stay put.
- Search opens the subsection that owns the result before scrolling to it.

### Changed

- Depend on Safaeh **^0.9.0**.

## [0.9.0] - 2026-09-18

### Added
- `RegistrySettingsPage` host seams for external search and page-index:
  `showSearch`, `scrollController`, `scrollViewKey`, `sectionKeys`,
  `bodyOverlay`, and `RegistrySettingsPageState.selectSearchResult`.

### Changed
- Depend on Safaeh **^0.5.0** and re-export its current public API from
  `package:flutter_settings_framework/safaeh.dart` (list/status chrome,
  info/action sheets, material theme seams). Hosts no longer need a
  `dependency_overrides` pin to use Safaeh 0.5.
- Example catalog uses Safaeh 0.5 chrome: material theme seams, glyphs,
  LTR text, info sheets, bordered lists, and empty/search headers.

## [0.8.0] - 2026-09-10

### Added
- Opt-in Safaeh integration via `package:flutter_settings_framework/safaeh.dart`.
- Edadat section adapters for Safaeh's wide and overlay page indexes.
- Safaeh-backed settings search trigger, glass overlay, compact result list,
  and explicit clear/close behavior.

### Changed
- Raise the minimum Dart/Flutter versions to 3.11 to match Safaeh.

## [0.7.2] - 2026-08-22

### Fixed
- **`SplitScreenLayout`**: wrap list and detail panes in `Material` so
  `ListTile` ink is visible under Flutter 3.47's ancestor-color assert.

### Changed
- Pin Flutter **3.47.1** (Dart 3.13.1) with FVM (`.fvmrc`) and the same
  version in CI / Release.
- Dependencies: `flutter_riverpod` ^3.4.2, `shared_preferences` ^2.5.5,
  `easy_localization` ^3.0.8.

## [0.7.1] - 2026-08-22

### Fixed
- Rename the package `docs/` directory to `doc/` so `dart pub publish` passes
  pub.dev layout validation.
- Release GitHub Pages waits for an in-flight CI deploy instead of failing the
  tag workflow.

## [0.7.0] - 2026-08-22

### Added
- **Profile chrome**: reusable slot-based widgets for account surfaces
  (`ProfileSettingsCard`, hero metric, KPI strip, budget card, notifications,
  section header, status banner, placeholder, session / linked-account /
  action / security tiles, plan card, chips, timeline, copy row, stat grid).
- **`SettingsLtr` / `settingsBreadcrumb` / `settingsChevronEnd`**: shared RTL
  helpers for settings chrome.
- Example **Account** dashboard with interactive dummy data and a **See all
  sessions** sheet (this device vs other devices, per-device and bulk sign-out).
- Example language/theme overlay chrome with circular theme reveal.
- **GitHub Pages** is now a CI job after tests on `main` (and again on release
  tags), so [zyzto.github.io/Edadat](https://zyzto.github.io/Edadat/) tracks
  the published catalog.

### Changed
- Search indexing and jump-to highlighting are stricter with multi-word and
  locale-aware terms.
- Settings tiles, sections, and responsive helpers share the new l10n chrome.
- Screenshots refreshed for the hosted catalog.

## [0.6.0] - 2026-08-07

Packaging milestone (relicense + branding + first pub.dev publish path). No
public API feature changes. See [VERSIONING.md](VERSIONING.md) for the
milestone exception to the usual MINOR = features rule.

### Changed
- **License**: CC BY-NC-SA 4.0 → **MPL-2.0**.
- **Branding**: Edadat / إعدادات logo, bilingual READMEs (`README.md`,
  `README.ar.md`), pub-style install docs.
- **Docs honesty**: market Riverpod adapter + UI as what ships today (no
  Provider/Bloc adapters); clarify stream/callback core vs Riverpod UI.
- **CI / release**: example `dart analyze` on CI; Release workflow publishes
  to pub.dev via OIDC after verify + GitHub Release.

### Fixed
- Example README no longer claims `flutter run` without platform folders.
- `example/pubspec.lock` synced to the package version.

## [0.5.1] - 2026-07-30

### Fixed
- **`SettingAnchorRegistry.scrollTo`**: use `jumpTo` + a single
  `ensureVisible` instead of an animated pan that flickered when hosts also
  scrolled to the section.

## [0.5.0] - 2026-07-30

Baseline release under the new tag/CI system (`v0.5.0`).

### Added
- **`ActionSetting`**: non-persisted settings for action/navigation rows that
  remain searchable and jump-targetable.
- **`SettingType.action`**: skipped by storage read/write.
- **SearchIndex**: indexes section titles onto member settings; tracks
  term→locale so `SearchResult.matchedLocale` is populated; multi-word queries
  require every distinct query word to match.
- **`SettingsSearchBarMode`**: `persistent` (full-width) and `compact` (icon).
- **`SettingAnchorRegistry` / `SettingAnchor` / `scrollToSetting`**: scroll-to
  and temporary highlight for search result selection.
- **`RegistrySettingsPage`**: persistent search under the app bar; result tap
  expands section and scrolls/highlights the setting.
- **`buildSearchResultWidgets`**: optional breadcrumb + `onResultSelected`.
- **`PreIndexedLocalizationProvider`**: true bilingual search indexing.
- Versioning docs, `scripts/check_version.sh`, `scripts/release.sh`.
- GitHub Actions: CI (analyze + test) and Release (tag verify + GitHub Release).
- Unit tests for SearchIndex and SettingsController.

### Documentation
- README: pin consumers to `ref: vX.Y.Z`; PreIndexed boot; ActionSetting;
  synonyms; `visible` vs `order` for search exclusion.

## [0.3.0] - 2026-07-30

Pre-tag history (folded into 0.5.0 baseline).

### Added
- ActionSetting, bilingual search UX, persistent search, jump-to highlight.

## [0.2.0] - 2026-02-13

### Fixed
- Global change stream now fires for undo/import operations.

### Improved
- Removed `VoidCallback` typedef that shadowed Flutter's built-in type.

### Deprecated
- `EasyLocalizationAdapter` / `MapLocalizationProvider` stubs — use
  `EasyLocalizationAdapterImpl` / `PreIndexedLocalizationProvider`.
- Auto-dispose setting provider helpers — use `createSettingProvider`.

## [0.1.0] - 2025-01-15

### Added
- Initial release of flutter_settings_framework.
