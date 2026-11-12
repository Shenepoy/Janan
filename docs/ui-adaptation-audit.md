# Main-app UI adaptation audit

Reviewed 12 November 2026. This is a source/layout audit of the Flutter main app,
not a claim that every route has been exercised on a physical device. The
separate private admin and report viewer are outside this pass.

## Updated in this pass

| Page | Change |
| --- | --- |
| Body profile | Centered settings frame; responsive height/year fields; personal-details and body-composition cards; autosave explanation; English and Arabic copy |
| Range limits | Separate BMI and blood-pressure cards in the shared settings frame |
| Warning values | Shared card and centered floating action; themed help link; long translated action labels fit |
| Bluetooth devices | Paired-device and import-settings cards; centered content |
| Add Bluetooth device | Same centered frame for scanning, connection and empty states |
| Health Connect | Centered content and separate weight/blood-pressure cards; existing permission behavior retained |
| Export columns | Built-in/custom settings cards; centered editor list |
| Export format help | Readable centered Markdown column |
| Delete data | Centered destructive-action card with existing confirmation flows |
| Version/debug | Centered content; copied name comes from the package, not the upstream app; native database-rescue action is not created on web |
| Support destinations | Settings and error-report links point to the current `Shenepoy/Janan` origin |

`SettingsPageFrame` now supplies a common 720-pixel content cap, safe insets,
and centered app-bar titles. Existing graph/export subpages use the same frame
through `SettingsSubpage`. The shared bottom-action label wraps up to two lines
without losing the existing press animation.

## Already adapted

Home, Weight, Statistics and the settings catalog already use Janan's shell,
Safaeh content bands, dashboard sections and selection overlays. Measurement
and weight details use the newer entry/detail form components. Graph settings,
graph markings and export/import already use settings cards. Time-format help
already has a centered 720-pixel layout. Onboarding already has responsive
width constraints and Janan-specific copy.

## Additional findings for a separate design pass

These pages have newer Janan functionality/components, but still contain
full-width or older page-level layouts. They were identified, not redesigned
by this Body profile change:

- Medicine catalog and add/edit medicine: existing modern controls and floating
  save action, but no desktop content-width cap.
- Medication schedules, dose/history details and reminder settings: custom
  Janan flows; page-level spacing and desktop widths need a coordinated pass.
- Local health-tools hub and the six tool detail/editor flows: basic list/card
  layouts; need consistent widths, responsive actions and RTL trailing icons.
- Critical-error recovery screen: intentionally boots without the normal
  app/settings state. It still has a red full-width header and basic text/actions;
  any redesign must retain that independence and verify recovery behavior.
- Library-owned logs/licenses: retain library layouts; audit through their
  actual routes before replacing them.

Upstream attribution and protocol references are intentional. Package metadata
and README still contain the previous fork URL; those are documentation/release
metadata outside this page-design change.

## Validation

The layout matrix covers Body profile, ranges, warnings, Bluetooth devices,
delete-data, export columns and Markdown help at 360 and 1440 pixels in English
and Arabic, light and dark themes, with 1.4x text. It checks centered bounds,
overflow and scrolling to the bottom. Existing settings, export/import and
keyboard/editor tests cover settings mutations and the reused floating action.
See `test/features/settings/settings_page_layout_test.dart`.

Validation result: 174 settings/export/editor tests and 36 focused page-review
tests pass on Flutter 3.47.1 with published Safaeh 0.12.0. Analysis is clean.
Phone and landscape review captures cover the updated platform-dependent pages
as well. PolyScreen reported no connected physical devices.

The FOSS web build (Wasm plus JavaScript fallback and offline shell) passes.
The isolated browser preview opens Body profile and reports both desktop fields
at the same vertical position. Browser screenshots returned a blank Flutter
canvas despite working semantic controls and no reported console errors, so
visual acceptance here relies on widget-rendered captures, not a browser-pixel
pass. No deployment or physical-device validation was performed.
