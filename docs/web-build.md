# Shared Flutter web client

## Public privacy and deletion pages

Static, JavaScript-free policy pages are included in `web/` and copied by the
normal Flutter web build:

- `/privacy/` and `/ar/privacy/`
- `/delete-account/` and `/ar/delete-account/`

The hosted canonical origin is `https://janan.shenepoy.com`.
Both languages use `web/legal.css`, the existing favicon, and the approved
privacy/deletion contact `shenepoy@gmail.com`. Keep the English and Arabic
content aligned. These pages distinguish the local diary from optional account
features; they do not claim that disabled hosted AI or checkout is available.
Review the processor disclosures before enabling those features, and update
retention details when provider retention settings are finalized.

Initial publication on 2026-11-13 adds only these five static files to the
existing client Hosting release. All 94 non-reserved live client files were
matched to the existing distributable artifact using Firebase's compressed-file
hashes before staging the addition. The app binaries, source bundle, service
worker, admin site, report site and backend were not rebuilt or modified.
Validation covers all four pages' local links, locale/direction, contact links
and script-free HTML, plus browser layout checks including Arabic at 390 px.

The browser target uses the same free local diary, repositories and Safaeh UI
as the mobile app. Like Hisab, it builds PowerSync's browser worker locally and
emits WebAssembly plus the JavaScript fallback. There is no PowerSync service
connection and no account requirement for local diary features.

## Build

Use the pinned Flutter version and the committed dependency lock:

```sh
FLUTTER_BIN=/path/to/flutter bash scripts/ci/build_web.sh
python3 -m http.server 5182 --bind 127.0.0.1 --directory build/web
```

The script downloads the SQLite WASM asset for the resolved PowerSync version,
compiles `tool/powersync_worker.dart`, and bundles the local renderer assets.
Serve the entire output directory over localhost or HTTPS, including
`sqlite3.wasm`, `powersync_db.worker.js`, CanvasKit/Skwasm, fonts and translations.
The CI web job checks this pipeline independently of the Android build.

Release validation must use published Safaeh 0.12.0, as recorded in the lockfile.
An ignored `pubspec_overrides.yaml` may point at the user's development checkout;
do not publish that build. Validate in a disposable source copy without the
local override rather than modifying the user's Safaeh repository.

## Storage and capabilities

- The browser database is PowerSync's persistent SQLite worker, using the same
  local-only schema. Opening failure never switches silently to a volatile diary.
- Settings use browser preferences. SQLite import/export uses file bytes and
  an isolated in-memory SQLite instance only for the portable backup; the actual
  diary remains durable. Settings ZIP files are read without filesystem extraction.
- Native database migration stays in `health_database_native.dart`. Native
  reminders, Health Connect and Bluetooth are unavailable in the browser;
  capability choices and settings explain this in all 25 shipped languages.
- Browser storage can be cleared or evicted. A browser diary is not a cloud
  backup. The paid overlay's account isolation/sync still needs web adaptation.
- The build now includes a versioned static shell for offline cold starts after
  one successful online installation. The browser still controls storage eviction.
  Installation UX, private browsing, cache eviction/recovery, HTTPS and alternate
  browser validation remain release checks; see the offline validation below.

## Browser storage diagnostic

Build a separate, non-distributable diagnostic entry point:

```sh
flutter build web --wasm --no-wasm-dry-run --no-web-resources-cdn \
  --target tool/web_storage_check.dart --output build/storage-check
python3 -m http.server 5184 --bind 127.0.0.1 --directory build/storage-check
```

Prepare the worker/WASM first using the normal build script. Press **Run storage
check**. It opens uniquely named test databases, verifies close/reopen and
portable SQLite integrity, clears its own source diary, and restores the bytes
into a fresh target. It checks Unicode, readings, weight, medicine relationships,
taken/skipped/snoozed doses, all six health tools, repeated import without
duplicates, durable reopen, update and delete, then clears its synthetic rows.
Never deploy this diagnostic as the customer app.

## Validation — 2026-11-07

- Published Safaeh: analysis passed; Wasm + JavaScript release build passed;
  3,147 tests passed, 9 opt-in tests skipped. After the browser header adjustment,
  all 31 focused shell tests passed. Native migration logic is unchanged.
- Chromium: onboarding, native capability choices, synthetic reading creation,
  reload persistence, desktop/mobile Safaeh layouts and Arabic/light appearance.
  The separate browser storage diagnostic passed its complete round trip.
- Local Safaeh development override produced stale form input and a blank view
  after reload. Replacing only the served build with the published-package build
  fixed the same browser origin without clearing storage. The development
  package was not edited; investigate it separately before adopting its changes.
- Some labels on an already-open page stay in the prior language until reload.
  Live locale switching needs a follow-up before cutover; persisted Arabic works.
- No native device was reachable through PolyScreen. Native UI smoke validation,
  Firefox/Safari, actual browser download/file-picker flows and full page parity
  remain pending. Screenshots are ignored under `build/web-audit/`.
- No production deployment or paid feature enablement was performed.

## Responsive graph limit

Settings → Blood pressure → Chart settings → Maximum graphs on wide screens
sets a persisted limit from 1 to 5 (default 5). The chart area uses a responsive
grid and reduces the count when available width/height or larger text would make
plots too small. Portrait phone layouts retain one chart. Lowering the count or
resizing does not erase the saved chart order. The menu on each graph swaps its
selection with an existing graph rather than creating duplicates.

Available charts are daily range, classification, pulse pressure, medication
timing (when medications are enabled), and a pulse trend in bpm. Pulse averages
use recorded pulse values, independently of pulse pressure. This remains free
local functionality.

The follow-up passes 26 focused chart/settings/catalog tests, four English/Arabic
settings layout checks, static analysis and the Wasm + JavaScript build. Browser
validation includes all five cards fitting at 1700×1000 and the 1–5 settings picker.
Changing the limit to three survived reloading the app and reopening settings;
the preview was then restored to five.

## Desktop navigation

On desktop platforms, side-navigation buttons animate pages vertically in tab
order. The outer pager does not accept wheel, trackpad or drag scrolling;
scrollable content inside each page continues to work, including at either end
of its scroll range. Narrow desktop windows use the bottom bar and horizontal
button transitions. Mobile swipe navigation is unchanged.

All 36 shell tests pass, covering Windows/macOS/Linux, both text directions,
vertical animation, wheel input, inner-list scrolling and resizing without
losing the selected tab. Static analysis and the Wasm + JavaScript build pass.
The desktop browser preview was checked with navigation clicks and scrolling
both the measurements screen and settings, including the end of its list.

## Sanity recheck — 2026-11-08

Rechecked all current public source changes in a disposable source copy with
published Safaeh (the development override was left untouched): static analysis
is clean, **3,157 tests pass with 9 opt-in skips**, and the worker plus Wasm/JS
release build succeeds. This includes the graph-count and desktop-navigation
follow-ups. PolyScreen still reports no connected devices. Existing cross-browser,
native UI, live locale switching and offline web release gates above remain open.


## Live locale fix — 2026-11-09

The app now passes EasyLocalization's loaded provider locale to MaterialApp,
rather than its mutable controller locale during an in-flight asset load.
This prevents a settings rebuild from registering old strings under the new
language. A delayed-asset regression verifies English → Arabic → English without
reloading; Settings and desktop-shell translation tests also pass. This closes
the code-level live-locale blocker above without changing persisted language
preferences or the restored FAB/app-bar motion.


## Offline shell and accessible inputs — 2026-11-09

The shared web pipeline now generates `janan_service_worker.js` after compilation.
The cache contains only an explicit list of static app files, fonts/translations,
renderer assets, the SQLite worker and build metadata. Each download is checked
against its build SHA-256 integrity value. A partial installation is discarded;
the previous complete version remains available. Changes to either assets or
worker behavior create a separate cache version.

Only bare diary navigation and allowlisted static assets use this cache. APIs,
account/recovery/consent paths, reports, other origins, POSTs, authorized requests
and arbitrary query parameters bypass it. The sole query exception is the
numeric `version.json?cachebuster=…` generated by package_info_plus: it returns
metadata from the running build. Browser testing found that omitting this file
prevented offline startup during upgrade checks; a regression locks down this
exact request and rejects extra/query-secret variants.

Updates download without taking over open tabs. Close all tabs for this Janan
origin and reopen to activate a waiting version. The app never forces a reload,
calls skipWaiting/clients.claim, or deletes diary databases. Notices dismiss when
interaction resumes and pass through pointer input, so they cannot cover Save.
Readiness is announced after installation; an existing registration alone is not
proof that browser storage has not been evicted. No offline shell is installed
from credential-bearing entry links.

Validation: eight JavaScript behavior tests plus two build-manifest tests pass;
CI runs them before the web build. A local browser opened a newly updated diary
with its asset server stopped, retained a synthetic measurement, and saved an
edit while that server was unavailable. HTTP checks confirmed the server was
unreachable. Update installation displayed the close/reopen notice while the
previous version stayed usable. This is Chromium embedded-browser evidence,
not Firefox/Safari, installed-PWA, or physical-device coverage.

The same browser check exposed unnamed input fields. Measurement inputs now
announce their own translated name and unit; the note field announces its
purpose. Two semantics regressions failed with the previous em-dash-only label
and pass after the fix. All 69 input-form tests pass with clean focused analysis.
The visible field styling and free local functionality are unchanged.

Service-worker lifecycle reference:
[MDN: Using Service Workers](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API/Using_Service_Workers).


## Cache eviction recovery — 2026-11-09

A missing cached app file is now restored after a successful integrity-checked
network fetch. If browser cache access or writes fail, verified online use still
works without clearing storage. If the bare diary shell is missing and cannot be
fetched, a bilingual recovery page asks the user to reconnect and retry. It never
resets the diary, caches authentication responses, or forces a waiting update.
Eleven worker/registration tests and two manifest tests pass.

In an isolated Chromium browser origin, removing the cached WebAssembly asset
was repaired by reopening the app. Removing all static app caches with the server
stopped displayed recovery guidance; reconnect/retry then restored the app and
retained a synthetic measurement and previously edited note. This covers static
Cache Storage eviction only. Entire site-data deletion, IndexedDB loss, private
browsing restrictions and real backup restoration remain separate release checks.


## Browser backup recovery — 2026-11-09

The actual client exported a synthetic SQLite diary through the browser download
flow. A fresh origin completed onboarding with an empty diary, imported that
file through the normal file picker, and retained the reading and edited note
after reopening. Re-importing the same file and attempting a malformed `.db`
left the recovered data intact: a second browser export matched every row in
all 14 tables of the original file, with SQLite integrity `ok`. This fixture
contains one reading and one note; empty tables are compared too.

The expanded browser storage diagnostic separately passes source-diary clearing,
recovery of readings/weight/Unicode and medication relationships, all three dose
outcomes, all six health-tool kinds, duplicate import, and durable reopen. The
diagnostic uses unique database names and cleans its own rows only. Six focused
core backup/import tests and diagnostic analysis pass; the Wasm/JS diagnostic
build succeeds using the published Safaeh dependency.

This verifies portable database recovery in Chromium. It does not establish
whole-site eviction behavior, cloud disaster recovery,
Firefox/Safari, private browsing or installed-PWA behavior. One automation tab
became unresponsive during reload; a new tab on the same origin successfully
read the restored diary. No production data or account was involved.

Settings ZIP recovery also passes through the actual download/file-picker flow.
The isolated source changed Compact table rows from off to on after backup;
restoring the ZIP and restarting returned it to off. Re-exported JSON matched
all seven archive entries, and all six settings-loader tests pass.


## Bundled UI fonts — 2026-11-12

Register the existing Noto Arabic, Tamil, Japanese and Chinese assets under
`flutter.fonts`, not only `flutter.assets` (the latter previously served PDF
exports). The shared theme uses these local fallback families and prefers
Japanese Han forms when the UI locale is Japanese. Noto Color Emoji is bundled
with its upstream revision, checksum and OFL license. This avoids depending on
Flutter's external fallback-font CDN, which the hosted CSP intentionally blocks.

Regression tests inspect the generated runtime manifest and rasterize real
script/emoji glyphs. The multilingual layout audit now loads that same manifest
instead of registering otherwise undeclared fonts just for tests. All 430
Arabic/Japanese/Chinese/Tamil layout cases, the font tests and 21 live-locale/
settings tests pass; static analysis is clean. Font cmap auditing covers every
visible scalar used by those translations, including Traditional Chinese.
