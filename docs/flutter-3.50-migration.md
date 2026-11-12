# Flutter 3.50 migration

The application and the private Flutter admin, recipient viewer, and Plus overlay
use Flutter 3.50.0 / Dart 3.14.0. FVM, editor configuration, CI, and package locks
use the same toolchain. Application version numbers are unchanged.

## UI packages

Application imports and tests use `material_ui` 1.11.0 instead of the deprecated
SDK Material library. Existing Material 3 styling, Safaeh surfaces, navigation,
and light/dark themes are retained. Modern Material localization delegates are
registered alongside Easy Localization, with the Arabic Western-digit override
first. The small remaining Cupertino imports use `cupertino_ui` 1.1.6.

The initial migration used compatibility copies of Safaeh 0.12.0,
flutter_settings_framework 0.11.0, and inline_tab_view 1.0.2. Safaeh and the
settings framework have since published Material UI-compatible 1.0.0 releases. `vendor/` contains minimal
compatibility copies from their published sources, retaining licenses, original
file hashes, and package-specific patch notes. They do not depend on a sibling
working tree or change the pub cache. Replace them when compatible upstream
releases are published. The admin and recipient viewer carry the same Safaeh
copy in the private repo.

The application wraps legacy Markdown/log-viewer descendants with Flutter's
recommended temporary `MaterialUiCompatibilityBridge`. This provides inherited
theme/localization state; it does not replace the app's modern Material types.
The tooltip test helper explicitly finds modern Tooltip widgets because the SDK
finder's excluded-semantics case still checks the legacy Tooltip class.

## Web

All Flutter build pipelines already used `--wasm`, producing Wasm and JavaScript
fallback builds with locally hosted renderer assets. Their bootstrap now opts in
to Wasm for Blink, WebKit, and Gecko. Supported browsers choose Wasm; older
browsers retain the loader's JavaScript fallback. The public offline shell and
SQLite/PowerSync browser worker are retained.

Content-hashed filename mode is deliberately not enabled in this migration:
the existing offline manifest and hosting checks use the current output names,
and hosting already serves entry points with no-store/revalidation. The optional
experimental browser-native text renderer is also unchanged.

## Android

Gradle 9.5.0 (with distribution checksum), AGP 9.3.1, and Kotlin 2.4.20 match
Flutter 3.50's template defaults. Existing plugin overlays and FOSS/production
flavors remain in place. No validation bypass flag is used.

## Validation and distribution

Run `flutter analyze`, `dart analyze vendor`, the complete `flutter test` suite,
`bash scripts/ci/build_web.sh --release`, and an Android debug build. In the
private repo run its package/composition checks, admin/sharing suites, and the
composed Plus UI suite and Wasm build. Check packaged Firebase HTTP headers,
routing, Wasm MIME types, and JavaScript fallback files with the existing smoke
scripts.

This migration does not publish a release or cut the deployed Refine admin over
to Flutter. Browser validation uses a local preview. Safari/Firefox runtime and
physical-device acceptance remain separate from successful Wasm compilation.

## Validation completed — 2026-11-12

- Public app and vendor analysis: clean. Full client suite: 3,252 passed,
  nine skipped. Missing Body profile translations exposed by that suite were
  completed across the remaining 23 locales.
- Android FOSS debug APK: built with the pinned Gradle/AGP/Kotlin toolchain.
- FOSS and composed Plus: Wasm and JavaScript fallback builds passed, including
  the offline shell and SQLite/PowerSync worker packaging.
- Private overlay: 118 UI tests passed (one integration skip); cloud package:
  44 passed. Admin: 108 passed (one integration skip); viewer: 20 passed (one
  integration skip). Their analysis and Wasm/JavaScript builds passed.
- Private composition/source-bundle/auth-vendor checks and 13 hosting tests
  passed. Packaged Firebase HTTP smoke checks passed for admin (16 checks) and
  recipient viewer (11 checks).
- Chromium local preview: onboarding, navigation, dark theme, saving a synthetic
  120/80 reading with pulse 70, and persistence after reload verified. Screenshot:
  `build/ui-audit/flutter-350-settings.png` (local evidence, not source).

No connected mobile device was available. Safari/Firefox runtime, native-device
UI, and production auth flows have not been revalidated by this toolchain change.
The local integration skips remain explicit; compilation is not evidence of
successful live purchases, hosted AI, or a production Flutter cutover.

References:
- https://flutter.dev/blog/whats-new-in-flutter-3-50
- https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui

## Content-sized tab forms

Janan now uses `SafaehTabView` in its input form switcher. The inline_tab_view
dependency and its vendored patch have been removed. The original component is
implemented and tested in the Safaeh repository and mirrored into the Safaeh
snapshot here and in the cloud overlay until a release includes it. It keeps
form state, animates height changes, and disables inactive focus, semantics, and
tickers. Reduced motion disables the height animation. Tab selection remains
button/controller driven. No package release is made by this change.

Validation for the replacement: Safaeh analyzer clean and all 276 package tests
passed, including nine focused tab-view cases. Janan analyzer clean and all 94
input/editor tests passed. The tab cases cover growing/shrinking height, draft
retention, hidden focus/semantics, ticker exclusion, reduced-motion changes,
controller replacement, rapid navigation, child reordering, and globally keyed
forms.

## Published UI dependencies — Janan 26.11.0

Safaeh 1.1.0 now includes SafaehTabView, and flutter_settings_framework 1.0.0
supports the standalone Material UI packages. The app uses both published
packages with a committed lockfile. All three temporary UI compatibility
directories have been removed. Historical validation above describes the
intermediate migration; the release runs the complete CI checks again.
