# Performance and battery audit — 2026-11-23

Scope: the current working checkout, including existing uncommitted UI work. This is a source-wide audit and regression-test sweep, with representative Android emulator validation. It is not a claim that every route was manually profiled, or that a battery-discharge percentage was measured.

## Findings and changes

| Area | Before | After |
| --- | --- | --- |
| Medicine indicator | A 30-second timer ran even with medicines disabled, with no schedules, behind overlays and in the background. A regression test reproduced the disabled/hidden rebuild. | The UI timer requires active schedules, a visible tab, a current route, and a foreground app; returning refreshes from wall time. |
| Kept-alive tabs | Shell pages retained active animation tickers after switching tabs. | Inactive tab subtrees receive `TickerMode(enabled: false)` while preserving page state and scroll positions. |
| Measurement sessions | The whole page rebuilt every second, including new selected-reading-average futures. Completed sessions continued ticking. | Only unfinished countdown labels tick. Lists and average queries are outside the ticking subtree; completed/hidden/background countdowns stop. |
| Stock estimates | Each mounted summary recalculated its forecast every minute regardless of app or route visibility. | Presentation refreshes pause when hidden; database-driven stock changes remain reactive. |
| Water reminder settings | A 20-second poll remained scheduled offscreen and in the background; unchanged status could refresh consumers. | Polls run only while the enabled feature is visible and foregrounded, cannot overlap, and publish changed status only. |
| Statistics comparison | Building a cached future still started a fresh database query whose result was discarded. Sliding-window keys also moved with build time. | Reuse the selected-range snapshot and one comparison future; reload only for range/filter/repository changes and database writes. |
| Linked reading details | Rebuilding a context card constructed a new watched SQL stream. | Keep the stream stable until the database or reading identity changes. |
| Version / emergency rescue export | Metadata and path futures were rebuilt; file existence and reading used synchronous disk calls on the UI isolate. | Cache page-lifetime futures and use asynchronous file stat/read for the rescue flow. |
| Legacy/file-backed settings persistence | The file backend synchronously rewrote settings JSON for each mutation. Normal Android settings already use SharedPreferences; this backend handles legacy/migration or explicitly supplied file storage. | Asynchronous batched writes combine bursts, serialize edits arriving during IO, and complete each caller only after persistence; failure and retry are covered. |
| Reduced-motion / covered overlays | Overdue flashing ignored reduced motion, and some progress/water animations stayed active behind modal routes. | Decorative loops honor reduced motion, the current route, and tab ticker visibility. Protocol work is unchanged. |
| Launcher medicine widget | Label/ring redraws used exact wakeup alarms, including while idle. | Visual-only refresh uses non-wakeup `RTC` alarms, retaining exact timing when permitted with a safe inexact fallback. Actual medicine and water notifications retain their wakeup alarms. Sleeping visual labels may catch up after the device wakes. |

## Preserved behavior

- Medicine and water notification scheduling, snooze, missed-dose shifting, and saved timestamps remain separate from presentation timers.
- BLE transfer keep-alives and transfer timeouts remain intact: those are protocol work, not decorative UI clocks.
- Finite modal transitions, dialogs, input focus, and reduced-motion settings remain supported. Shared lazy picker/settings lists remain lazy.
- Import/export work and data writes retain their existing validation and persistence paths.

## Additional validation repairs

The broad sweep exposed highlighted switch rows whose ink surface sat behind the search decoration; a transparent Material now sits below the highlight. It also exposed settings-consent tests that expected lazy offscreen rows to exist; they now use the real settings search-and-reveal path. It also exposed missing reminder shortcut translations and five existing English water/nutrition fallback sentences; the locale catalogs now have matching keys and localized labels.

## Coverage inventory

All 391 Dart source files were inventoried for periodic timers, repeating animation controllers, query futures/streams, route lifecycle, overlays, and settings controls. The 43 screen/dialog/sheet entry files below identify the explicit UI entry points; additional editor widgets, anchored popouts, notification receivers, and shared controls are covered by their call chains and regression suites.

| Entry file | Review focus |
| --- | --- |
| `lib/components/confirm_deletion_dialog.dart` | overlay lifecycle / lazy content |
| `lib/components/fullscreen_dialog.dart` | navigation / shared controls / finite transitions |
| `lib/components/input_dialog.dart` | overlay lifecycle / lazy content |
| `lib/core/layout/responsive_sheet.dart` | overlay lifecycle / lazy content |
| `lib/core/widgets/app_sheet.dart` | overlay lifecycle / lazy content |
| `lib/features/export_import/ui/add_export_column_dialog.dart` | reactive subscriptions; overlay lifecycle / lazy content |
| `lib/features/export_import/ui/export_column_management_screen.dart` | reactive subscriptions; overlay lifecycle / lazy content |
| `lib/features/export_import/ui/export_field_format_documentation_screen.dart` | navigation / shared controls / finite transitions |
| `lib/features/export_import/ui/import_preview_dialog.dart` | overlay lifecycle / lazy content |
| `lib/features/health_connect/health_connect_screen.dart` | reactive subscriptions; settings enablement / rebuilds |
| `lib/features/health_tools/health_tool_screen.dart` | query/future lifetime; reactive subscriptions; overlay lifecycle / lazy content |
| `lib/features/health_tools/health_tools_screen.dart` | reactive subscriptions |
| `lib/features/input/add_entry_dialog.dart` | overlay lifecycle / lazy content |
| `lib/features/measurement_list/measurement_detail_screen.dart` | reactive subscriptions |
| `lib/features/measurement_list/metric_info_dialog.dart` | overlay lifecycle / lazy content |
| `lib/features/measurement_list/weight_detail_screen.dart` | reactive subscriptions |
| `lib/features/medications/medication_history_screen.dart` | reactive subscriptions |
| `lib/features/medications/medication_reminder_settings_screen.dart` | query/future lifetime |
| `lib/features/medications/medications_screen.dart` | navigation / shared controls / finite transitions |
| `lib/features/nutrition/nutrition_screen.dart` | reactive subscriptions; overlay lifecycle / lazy content |
| `lib/features/nutrition/water_preferences_screen.dart` | reactive subscriptions; overlay lifecycle / lazy content |
| `lib/features/nutrition/water_reminder_screen.dart` | reactive subscriptions; settings enablement / rebuilds |
| `lib/features/onboarding/onboarding_screen.dart` | reactive subscriptions; overlay lifecycle / lazy content |
| `lib/features/settings/add_medication_dialog.dart` | overlay lifecycle / lazy content |
| `lib/features/settings/bluetooth_devices_screen.dart` | reactive subscriptions; overlay lifecycle / lazy content; settings enablement / rebuilds |
| `lib/features/settings/body_profile_screen.dart` | reactive subscriptions; settings enablement / rebuilds |
| `lib/features/settings/configure_warn_values_screen.dart` | reactive subscriptions; overlay lifecycle / lazy content |
| `lib/features/settings/delete_data_screen.dart` | overlay lifecycle / lazy content |
| `lib/features/settings/enter_timeformat_dialog.dart` | overlay lifecycle / lazy content |
| `lib/features/settings/export_import_screen.dart` | reactive subscriptions; settings enablement / rebuilds |
| `lib/features/settings/graph_markings_screen.dart` | reactive subscriptions; overlay lifecycle / lazy content |
| `lib/features/settings/graph_screen.dart` | reactive subscriptions; settings enablement / rebuilds |
| `lib/features/settings/medicine_manager_screen.dart` | reactive subscriptions; overlay lifecycle / lazy content |
| `lib/features/settings/range_limits_screen.dart` | reactive subscriptions; overlay lifecycle / lazy content |
| `lib/features/settings/time_formats_reference_screen.dart` | navigation / shared controls / finite transitions |
| `lib/features/settings/version_screen.dart` | query/future lifetime |
| `lib/features/statistics/dashboard/dashboard_date_range_sheet.dart` | navigation / shared controls / finite transitions |
| `lib/screens/add_entry_screen.dart` | navigation / shared controls / finite transitions |
| `lib/screens/error_reporting_screen.dart` | navigation / shared controls / finite transitions |
| `lib/screens/home_screen.dart` | reactive subscriptions |
| `lib/screens/settings_screen.dart` | reactive subscriptions; overlay lifecycle / lazy content; settings enablement / rebuilds |
| `lib/screens/statistics_screen.dart` | query/future lifetime; reactive subscriptions |
| `lib/screens/weight_screen.dart` | navigation / shared controls / finite transitions |

## Validation

- Baseline: `reminder_idle_performance_test.dart` failed in both visible and hidden configurations with a periodic rebuild while medicines were disabled. The same checks pass after the change.
- Focused regression run: all 18 checks passed, including foreground/route/tab timer gating, expired-deadline resume, reduced-motion idleness, comparison-query reuse, highlighted settings switches, catalog parity, and batched-settings persistence. The storage probe records 100 changes coalesced to one asynchronous write, two batches for edits made during in-flight IO, and successful recovery after an injected IO failure.
- Android unit suite: 25 tests, zero failures/errors; debug APK build succeeded.
- Emulator: PolyScreen selected `emulator-5554`, logical display `0`. A sample debug-only Amlodipine widget was added through the launcher picker, configured for the sample medicine, opened its pinned dose panel, and returned to the launcher with Back.
- Native alarm diagnostic: `DOSE_WIDGET_REFRESH` is `type=RTC` with `flags=0x0`, rather than `RTC_WAKEUP` or an idle-bypass alarm. Existing medicine notification alarms remain `RTC_WAKEUP`. The fallback when exact-alarm permission is absent is inexact and non-wakeup, so a visual countdown can update late; notifications are independent.
- Launcher UIAutomator could not obtain an idle hierarchy at two widget-picker steps; PolyScreen screenshot coordinates were used there. No raw ADB UI fallback was used. ADB was used for APK/package inspection, installation and alarm diagnostics.

- Final whole-repository Flutter analysis: no issues.
- Final full non-golden Flutter suite: **3,418 passed, 2 skipped**, zero failures. This includes the localized screen/dialog matrix in portrait and landscape with enlarged text. Golden-only tests remain governed by the repository CI policy.
- Final FOSS debug APK build succeeded, and APK metadata confirmed `com.shenepoy.janan.foss.debug`, `Janan Debug`, and `application-debuggable`. Updated only the emulator debug app, preserving its data.
- Final APK smoke: measurement → food/water → water popout → water reminder settings → native time picker → cancellation; notification-permission denial returned to the unchanged disabled reminder; statistics and settings navigation; manual-time switch off/on restored and persisted `true` in Android SharedPreferences; search revealed the highlighted usage switch; holding Taken opened the picker and cancellation left **0 recorded today**; Home/background and hot resume returned cleanly.
- Structured PolyScreen results: `dist/performance-ui-evidence.json`. Final screen: `dist/performance-final-screen.png`. Focused widget-alarm diagnostic: `dist/performance-widget-alarm.txt`.
- All task-owned disposable build directories were removed by their wrappers. No benchmark servers or debug instrumentation were left running.

The improvements remove unnecessary work and visual wakeups. No physical-device battery-discharge percentage, universal FPS improvement, or manual timing profile for every individual control is claimed. Raw logs and APKs are saved under ignored `dist/`. Disposable builds use `with-temp-build` and are removed at exit.


## Follow-up review

A second review added five failing regression cases and corrected three edge cases:

- A UI clock enabled long after its state mounted could keep stale data until its first periodic tick. It now refreshes after the activation frame as well as when returning from a hidden/background state. The regression verifies immediate first activation without restoring hidden/background periodic work.
- A fast failed statistics read could complete before FutureBuilder attached, and a repository update-stream error could escape the widget listener. Comparison futures now have an immediate error handler while preserving their errors for the UI, and the subscription routes errors into the comparison UI. Callbacks from a replaced repository are ignored.

- A caller could mutate a string list after queueing a file-backed settings write, or mutate a list returned by a read and affect a later save. String-list reads and writes now take defensive copies; both cases have regression coverage. Android’s normal SharedPreferences backend is unchanged.

Full repository analysis remained clean. The affected regression suite passed **180 tests**, including all medication tests, statistics tests, clock lifecycle checks, shell navigation, stock summaries, water preferences and file-backed settings persistence. The earlier full-suite run above predates these follow-up fixes; these cases were validated in the affected-suite rerun rather than rerunning the unchanged localization matrix.

The follow-up debug APK rebuilt successfully, installed on emulator-5554, and launched with its Settings navigation accessible through PolyScreen. Follow-up logs and APK are saved as `dist/performance-double-check-*`.
