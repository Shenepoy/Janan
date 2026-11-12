# Temporary Flutter 3.50 compatibility copy

Source: https://pub.dev/packages/safaeh/versions/0.12.0 (published archive).
Upstream file hashes and license are retained. Only Material/Cupertino imports,
localizations, required type migrations, and package dependencies are adapted
for the standalone UI packages. Remove when an upstream migrated release exists.
Do not publish this copy as an upstream package release.

Also includes the unreleased `SafaehTabView` from the Safaeh source repository
(commit `1b33bc5520bfecc1a321c141b1f558e4391df41b`,
`lib/src/tab_view.dart`), tested upstream in `test/tab_view_test.dart`. This is
an original widget composed from Flutter primitives, not a copy of inline_tab_view.
It keeps small tab forms mounted, animates their height, and excludes inactive
focus, semantics, and tickers. Replace this snapshot with a Safaeh release that
exports the component; do not switch to 1.0.0, which does not yet contain it.
