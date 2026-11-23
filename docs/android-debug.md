# Android debug app

Use the public FOSS debug build to try local changes alongside an installed
Janan release. It includes the food and water diary, combined chronological
history, shared date selector, and compact period overview. Hosted features
are not part of this build.

| Build | Android application ID | Launcher label |
| --- | --- | --- |
| Production release | `com.shenepoy.janan` | Janan (localized) |
| FOSS release | `com.shenepoy.janan.foss` | Janan (localized) |
| Production debug | `com.shenepoy.janan.debug` | Janan Debug / الجنان تجريبي |
| FOSS debug | `com.shenepoy.janan.foss.debug` | Janan Debug / الجنان تجريبي |

The debug build type adds `.debug` to the application ID and `-debug` to the
version name. Its launcher label comes from debug-only resources. Release
labels and IDs are unchanged. Android keeps each application ID's database,
preferences, permissions, and notifications separate. The debug app starts
with its own empty diary; it does not automatically copy release data.

## Build

From the repository root, using the pinned Flutter SDK:

```bash
.fvm/flutter_sdk/bin/flutter build apk --debug --flavor foss
```

Output: `build/app/outputs/flutter-apk/app-foss-debug.apk`. The build uses the
Android debug signing key. A local debug build does not require a release
version bump, tag, Play upload, or GitHub publication.

## Install alongside existing apps

Discover the device with PolyScreen `mobile_devices_list`, then discover its
logical display with `mobile_displays_list`. Use the exact Samsung serial for
installation and that display ID for launch and UI validation.

Before installing, inspect the APK with the SDK's `aapt2 dump badging` command.
Confirm its package is exactly `com.shenepoy.janan.foss.debug`, its application
label identifies it as debug, and the output contains `application-debuggable`.

```bash
JANAN_DEVICE='exact-serial-from-device-discovery'
JANAN_APK='build/app/outputs/flutter-apk/app-foss-debug.apk'
adb -s "$JANAN_DEVICE" shell am get-current-user
adb -s "$JANAN_DEVICE" shell dumpsys package com.shenepoy.janan.foss.debug
adb -s "$JANAN_DEVICE" install --user 0 "$JANAN_APK"
```

Use the user ID returned by `am get-current-user` in place of `0` if different.
For a first installation, the package inspection should report that it cannot
find the FOSS debug package. The install command intentionally omits `-r`, so
it fails instead of replacing an existing package. If the debug package already
exists, stop and decide whether updating that debug app is intended. Do not
uninstall or clear either release or debug data to work around an install error.

After installing, launch `com.shenepoy.janan.foss.debug` through PolyScreen and
verify the UI. Compare the original packages' version, code path, and update
timestamp before and after installation to confirm they were not updated.
Use ADB only for installation and package diagnostics; use PolyScreen for UI.

## Samsung validation — 2026-11-13

Target: Samsung `SM-S721B`, Android user `0`, logical display `0`.
The device already had production `26.11.1` (code `2085`) and a separate
production-debug `26.10.5` (code `78`). The new FOSS debug build is
`26.11.1-debug` (code `85`) with package `com.shenepoy.janan.foss.debug`.

Installed successfully with `adb install --user 0` without replacement flags.
After installation, both pre-existing packages retained their exact code path,
version, first-install timestamp, and last-update timestamp. PolyScreen launched
the new package successfully and confirmed that its Arabic onboarding rendered
on display `0`. No ADB UI fallback was used.

Verified APK metadata: `application-debuggable`, English label `Janan Debug`,
Arabic label `الجنان تجريبي`. SHA-256 of the installed APK:

```text
9ef9fc7f8a31634d7991bc3a1749867e8c834e5489df1ad69f419ba1ccce92dc
```

The feature's 11 focused widget tests and Flutter analysis passed before this
debug-label change; the final Android debug build and APK metadata checks passed.

### Sheet investigation follow-up

An intermediate opaque-sheet experiment was installed into the same FOSS debug
package on the Samsung without clearing its data. The regular production and
older production-debug packages were not targeted. That experiment is superseded
in source by Hisab's tuned-glass preset and Safaeh 1.1.1's existing Android
transition. See [shared-ui.md](shared-ui.md#android-sheet-rendering-2026-11-13)
for the emulator tests, trace results, and limitations.

The corrected debug APK has been installed and checked on the emulator. It has
not yet replaced the intermediate Samsung debug APK after the request to move
testing to the emulator. The corrected APK's SHA-256 is:

```text
869c15c487eaa39e7d7ca10f9032c7e232031330e6587a27394cffa8fb030b63
```

### Full-page food editor follow-up

The food editor now matches the full-page measurement forms, with an optional
nutrition section and a floating Save action. History has a single horizontal
inset, and floating controls clear the measured navigation bar at large text.
The current debug APK was built and installed on the emulator only. Its SHA-256:

```text
ff04dcd54c3486c711d7a219d83c9a015d05b044a3f7445ebfb821acbf6bee95
```

See [shared-ui.md](shared-ui.md#food-entry-and-diary-layout-2026-11-13) for
validation. This build has not been installed on the Samsung.

### Food hub follow-up

Option 20 is implemented: local food search, persistent favorites, saved meals,
a review basket, custom portions, and atomic multi-food saves. The current
FOSS debug APK was installed and validated on the emulator only. SHA-256:

```text
4bb756cd3ac647063a9ccf2949ec899e1c72e00c2489362b20e0a51f5d67dc46
```

All 28 focused tests and Flutter analysis passed. Samsung's installed apps were
not updated. See [shared-ui.md](shared-ui.md#food-hub--selected-option-20-2026-11-13).

### FAB tab transition follow-up (2026-11-13)

Built and installed `app-foss-debug.apk` on Pixel_10_Pro, `emulator-5554`, display
0 only. Package: `com.shenepoy.janan.foss.debug`. This build also includes the
combined food search/add control. No Samsung installation was changed.

SHA-256: `2b82a798c068e56d038d1357a0f3c74e30c9e63e39ebbb7350dfd903c474a22f`.

Validation: 58 nutrition/shell tests passed, analysis clean, PolyScreen tab
switching and food/water entry checked. See `docs/shared-ui.md` for the cause
and regression coverage.

### Water hold-and-drag follow-up

Installed the updated FOSS debug build on Pixel_10_Pro (`emulator-5554`,
logical display 0), package `com.shenepoy.janan.foss.debug`. Samsung and
production builds were not changed. The emulator is left on Food & water;
its preview preferences are Bottle / 500 mL.

APK SHA-256:
`2226b469d7000f80165eb1f1271fe31e905308db92fd4e3bf25b31ba37c0217d`.

All 75 focused tests pass and analysis is clean. PolyScreen verified hold,
review, preferences, persistence across reinstall/relaunch, and system Back
returning to the same food tab. Continuous hold/drag validation used the
explicitly documented raw ADB motion-event fallback in `docs/shared-ui.md`.
No test drinks were saved on the emulator.

### Daily water target and animated panel (2026-11-14)

The latest FOSS debug APK is installed on Pixel_10_Pro (`emulator-5554`, display
0), package `com.shenepoy.janan.foss.debug`. It restores the animated water FAB,
uses a user-configured daily target, and opens the medicine-style Safaeh genie
panel on tap. Long-press amount review remains available.

APK SHA-256:
`3836aa6486bef5ade5af3d27b04f395cdf99e138596aa174f9360950886ca838`.

Validation: 73 focused nutrition, overlay, shell and settings tests passed;
Flutter analysis is clean. The daily-fill regression was rerun after isolating
wave painting with a RepaintBoundary. PolyScreen checked Settings target entry,
panel logging, Undo, long-press review and Android Back. Two stationary-screen
captures confirm changing wave pixels within the water button. All UI actions
in this follow-up used PolyScreen; raw ADB was used only for installation.

The emulator contains demo data: a 2000 mL target and one 500 mL drink for
November 14. These are visual test fixtures, not app defaults. The app starts
with no target. No Samsung or production installation was updated.


### Configurable water vessels and reminders (2026-11-14)

Installed and validated the FOSS debug APK on Pixel_10_Pro (`emulator-5554`,
logical display 0), package `com.shenepoy.janan.foss.debug`. Samsung and release
installations were not changed.

APK SHA-256:
`6973620479548c65bf7a806ba527d84059070afcd9a39687ac52fccd670249e0`.

Includes 1–4 configurable vessels, one-tap logging, blue blurred hold control
with animated water, and optional daily reminders that adjust after drinking.
83 focused Flutter tests pass, analysis is clean, and Android native unit tests
pass. Actual notification delivery with the Dart app closed and cold navigation
were checked. See the final water-vessels section in `docs/shared-ui.md` for
coverage and the documented held-pointer ADB fallback.

Warm notification navigation also passed from Measurements. Temporary reminder
times were removed and notifications disabled after testing; the final native
schedule reports no pending alarm. The emulator is left on the three-bottle
water panel, with its original 500 mL demo intake and 2000 mL target.


### Independent Food and Water settings (2026-11-14)

The latest FOSS debug APK includes separate feature switches in Settings and
onboarding, one Food overview preference, and the shared Water preferences page.
Installed on Pixel_10_Pro (`emulator-5554`, display 0) only. Existing emulator data
was preserved; Samsung and production installations were not updated.

APK SHA-256:
`5b595eebaa294c8cd89018ac180ead4ccc4e9f069f7c80f1cccef9ee8ae20086`.

220 focused tests pass across runs, including all-language small-phone onboarding
checks. Analysis is clean. PolyScreen verified feature gating and native reminder
pause/resume. Both tracking features are enabled for preview; reminders are off.

### Direct FAB selection on navigation taps (2026-11-16)

Navigation taps now select the destination's FAB immediately instead of deriving
it from each intermediate page during the viewport animation. Settings hides the
actions; rapid retaps follow the latest destination, and an interrupting swipe
returns action selection to the visible page.

The frame-by-frame shell regression failed before the fix and passes after it.
All 47 shell/action tests pass, Flutter analysis is clean, and the FOSS debug APK
built and was installed on `emulator-5556`, logical display `0`, preserving data.
PolyScreen verified Statistics' Export action, navigation through Measurements
and Settings, and Water's final FAB. A recorded transition also showed no
intermediate Weight or Water FAB between Statistics and Measurements.
All device UI interaction used PolyScreen; raw ADB was used only for package
diagnostics and installation. The emulator is left on Water.
