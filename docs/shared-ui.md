# Shared UI ownership

Janan uses the published Safaeh and Edadat packages. Local path overrides are
development tools and are not part of a release dependency resolution.

## Android sheet rendering (2026-11-13)

The water editor uses `showResponsiveSheet` → Safaeh `showSafaeh`.
Food now uses the full-page form described below; the sheet measurements here
were collected before that change.
The resolved dependency is the published **Safaeh 1.1.1**; its
`adaptive_sheet.dart` matches the sibling Safaeh checkout.

Hisab's integration separates sheet appearance from floating navigation:
`lib/core/theme/safaeh_theme.dart` selects
`SafaehFloatingAppearance.tunedGlass()`, and its responsive-sheet wrapper
leaves native Android `slideUp` unset. Safaeh 1.1.1 already removes the
whole-sheet fade on Android while preserving blur. See the shared package's
`doc/host-integration.md` and `test/sheet_motion_test.dart`; the documented
Samsung comparison used profile mode and discarded the first of four openings.

Janan now follows that integration. `appSheetAppearance` supplies tuned glass
(36% transparency, sigma 12) to sheets and dialogs, independently of navigation
glass. It does not replace Safaeh's motion or add another opacity transition.
The experimental Android zero-blur/opaque override has been removed. Earlier
debug-only comparisons of that override did not establish that glass needed
to be removed from production.

The Janan integration regression test exercises its actual wrapper on Android
and iOS in light and dark themes. It verifies that the sheet starts offscreen,
retains tuned blur, reaches the bottom edge, and has no fractional-opacity
ancestor on Android during either opening or dismissal. iOS retains its fade.
The test failed with the experimental opaque override and passes with the
shared preset.

### Emulator validation

Pixel 10 Pro AVD, `emulator-5558`, display 0, 1280×2856, host GPU. PolyScreen
performed all taps, typing, scrolling, and dismissals; ADB was used only for
installation and diagnostics. The first opening was discarded for each build,
then three repeated food openings were measured with Flutter VM timeline
`Frame` and `GPURasterizer::Draw` events.

| Build / appearance | UI p95 across three runs | Raster p95 across three runs |
| --- | --- | --- |
| Debug, original navigation glass | 8.8 / 5.8 / 6.1 ms | 16.8 / 16.7 / 16.2 ms |
| Debug, Hisab tuned glass | 6.5 / 5.8 / 4.7 ms | 15.3 / 18.5 / 15.7 ms |
| Profile, Hisab tuned glass | 1.4 / 1.1 / 1.4 ms | 16.9 / 3.5 / 16.9 ms |

In profile mode, keyboard opening plus typing had UI p95 3.2 ms and raster p95
31.2 ms (four raster samples over 16.67 ms). Water drag dismissal had UI p95
0.8 ms and raster p95 17.3 ms. The emulator therefore does **not** demonstrate
uniformly smooth rendering: host GPU scheduling remains variable. These short
traces are not physical-device release benchmarks, and 16.67 ms is a 60 Hz
budget, not a 120 Hz target.

Functional checks passed for repeated opening/closing, entering and saving a
food item, selecting and saving 500 mL of water, combined history/totals, and
drag dismissal. All 19 focused sheet/nutrition tests and Flutter analysis
passed. Both debug and x64 profile APKs built and ran on the emulator.
The profile app is temporary test infrastructure. No application timing logs
or experimental widget-caching changes are retained.

## Food entry and diary layout (2026-11-13)

Food detail entry, editing, and reuse use a full page with `EntryFormSection`,
`SafaehContentBand`, and `FormBottomAction`, matching measurement entry. Food
name is the only required field. Meal chips and separate date/time controls
stay visible; optional nutrition expands into two columns when space permits,
and one column at larger text sizes. The bounded form keeps fields mounted
while scrolling so validation includes fields outside the viewport. A dirty
back action offers Keep editing / Discard. Water remains a quick Safaeh sheet.

History uses a lazy, unified food/water list with one 16 px horizontal inset
instead of nested card padding. Summary and recent-food cards keep their usual
margins. The shell measures the floating navigation bar's height for FAB and
content clearance, including wrapped labels at large text sizes.

Widget coverage includes English/Arabic, portrait/landscape at 150% text,
food save/reuse, water save/edit/delete/undo, discard protection, and keyboard
status-bar clearance. The shared Android/iOS sheet regression suite remains
applicable to water and other sheets.

All 62 focused nutrition, sheet, and shell tests passed, as did Flutter
analysis. The final FOSS debug APK was installed on `emulator-5558`, display 0.
PolyScreen verified food entry (Oats with fruit, 1 bowl, 320 kcal, 12 g protein),
keyboard-aware Save positioning, optional nutrition expansion, adding 500 mL
of water, combined history and totals, and reopening food in the edit page.
No ADB UI fallback was used; ADB only installed the APK. Samsung was not updated.


## Food hub — selected option 20 (2026-11-13)

The food FAB opens `FoodHub`: local search with Recent, Favorites, and Meals
choices; full-width food rows; stars; multi-add; a Create food fallback; and a
floating Review meal action. Existing diary foods populate the library without
requiring re-entry. Creating a food prepares a basket item; it does not log the
food before final review. Meal and date/time are set once in the basket review,
not separately in the Create food form. Existing diary edits remain direct.

Review supports half/single/double portions, custom positive multipliers up to
100, editing the base portion, removing items, meal/time selection, and an
optional name to save the basket as a reusable meal. Leaving an unsaved basket
asks whether to discard it. Unknown nutrients stay null when scaling; totals
identify partial data. Library records retain the base portion so reusing a
scaled meal never compounds its nutrient multiplier.

`FoodLibrary.logMeal` validates all foods before one observed health transaction
writes diary entries, reusable food snapshots, and an optional saved meal.
`nutrition_foods` and `nutrition_meals` are local-only PowerSync tables, included
in portable export and idempotent import. Favorites survive repeated logging.
Saved meals can be deleted in the Meals tab; Settings > Delete includes an
independent saved-food/favorites/meal reset that preserves diary entries.
Food identity uses a normalized name; the library keeps the most recently
stored base portion for that name. No online database or recognition service is
configured by this change.

Validation: 28 focused tests passed (nutrition UI, library transactions,
backup/import/export, period selection and native sheets), plus Flutter
analysis and FOSS debug compilation. English/Arabic hub and basket layouts
passed portrait and landscape tests at 150% text. PolyScreen on
`emulator-5558`, display 0 verified favoriting, creating Greek yogurt, a two-food
basket with doubled oats (640 kcal), unknown yogurt nutrition, saving a named
meal, combined diary totals, and reopening that meal with its original
multipliers. ADB was used only to install; no ADB UI fallback was used. The final
APK was installed on the emulator, not Samsung.

## Ownership

| Behavior | Owner |
| --- | --- |
| Native camera bounds and orientation freshness | Safaeh `SafaehDeviceCutoutScope` |
| Camera exclusion bands and floating-control placement | Safaeh `SafaehDisplayCutoutLayout` and `SafaehCutoutAwareFabLocation` |
| Navigation rail geometry, edge attachment, and camera avoidance | Safaeh sidenav |
| Anchored modal placement and moving trigger tracking | Safaeh anchored popout |
| Wide sheet horizontal safe-area handling | Safaeh adaptive sheet |
| Animated cycle action | Safaeh `SafaehCycleButton` |
| Section expansion and latest-request navigation coordination | Edadat `SettingsSectionNavigation` |
| Measurable bounded section catalog | Edadat `SettingsSectionList` |
| Chart types, datasets, filters, persistence, and excluding duplicate charts | Janan |
| Top chrome clearance, compact landscape rules, and app destinations | Janan |
| Floating editor save bar for reminders, medicines, and readings | Janan `FormBottomAction` |

The shell wraps its content in the cutout scope. Janan supplies its navigation
and app-bar clearances to floating controls rather than hard-coding these
dimensions into the package. Domain records and chart calculations stay here.

Settings marks section layout changes before navigation, holds the requested
index selection while the coordinator is navigating, and resumes its scroll
spy when navigation settles. Manual list dragging cancels pending navigation.
The eager section list is for a bounded settings catalog, not an unbounded
measurement list.

Package tests exercise the shared interfaces. Janan's Home, Settings, shell,
and sheet-helper tests verify the application integration, including rotation,
camera placement, chart uniqueness, and rapid section selection.

Medicine and measurement entry use full editor pages with a titled top app bar,
a back button, and the same floating save action as reminder entry. The save bar
stays above the keyboard; scrolling forms reserve its clearance, including the
bottom safe area. These editor headers remain at the top regardless of the
legacy bottom-app-bar setting. Medicine pickers and Bluetooth import still use
the existing form controls. Reading edits retain their discard confirmation.

The editor update passed 793 tests and all seven golden checks. Layout tests
cover medicine and blood-pressure forms in English/Arabic, portrait/landscape,
with 1.5× text and keyboard insets. The debug build was installed and both pages
were reviewed using PolyScreen on `emulator-5554`, logical display `0`.

Medicine and note editors offer an inline color palette with accessible names,
48 dp touch targets and a selection ring. The label, choices, and More colors
action share one row, adapting the number of choices to the available width
and retaining saved custom colors. More colors opens the
shared Safaeh palette; notes also offer No color. Other settings retain the
compact list-tile picker. English and Arabic color names are included.

The color selector update passed 795 tests and seven golden checks, with no new
analyzer findings. PolyScreen validation on `emulator-5554`, display `0`, covered
medicine and reading forms, immediate preview updates, clearing note colors,
and opening/dismissing the full palette. No raw ADB UI fallback was used.

The single-row refinement passed 28 focused selector and editor tests, including
English/Arabic portrait and landscape layouts with enlarged text and keyboard
insets.

Landscape rail motion now uses Safaeh's interpolated surface width directly for
its destination rows. Previously each row animated that changing width again,
so the selected pill lagged behind the edge and was clipped during closing.
Overlay labels and the title fade with the available width, destination icons
stay anchored, and Janan's floating header uses the same cubic easing and
respects reduced motion.

The shared implementation and frame regression tests are in the sibling
`../Safaeh` checkout. The ignored `pubspec_overrides.yaml` connects it for local
development; the published dependency and lockfile remain unchanged. A Safaeh
package release and dependency update are needed to distribute the shared fix.
Validation passed 245 Safaeh tests, 26 Janan shell tests, both focused analyzer
checks, and an Android debug build. PolyScreen on `emulator-5554`, logical
display `0`, verified opening/closing and captured a recording whose intermediate
frames retain the selected pill's rounded edge. Tests cover LTR/RTL, label
fading, and reversal during closing. ADB was used to lock landscape rotation
because PolyScreen has no orientation setter; taps and captures used PolyScreen.

## Food tab FAB transition correction (2026-11-13)

Embedded food/water actions now use the shell's `NavigationActionButtons`
position, including its navigation, snackbar and cutout clearance. The diary no
longer mounts its own FAB column inside the sliding PageView. Standalone diary
screens retain their actions. `NutritionDiaryActions` opens the same food hub
and water editor using the selected diary period.

The original regression test observed an 80 logical-pixel horizontal FAB shift
on a partial/reversed page swipe. It now passes. A second test exposed ignored
taps back to the still-selected tab during navigation; `_go` now permits that
retarget while the PageController is scrolling. Frame-by-frame portrait and
landscape checks cover fixed anchors, no duplicate action sets, and rapid
retargeting. All 58 nutrition/shell tests passed; Flutter analysis is clean.

PolyScreen validation on Pixel_10_Pro (`emulator-5554`, display 0) confirmed
Measurements and Food & water actions share centers (1148, 2412), with their
secondary actions at (1148, 2208), and both food/water entry routes open. ADB
was used for installation only; there was no raw ADB UI fallback.

## Water vessel and hold-to-adjust control

Water preferences (Settings → General) stores a glass, mug, bottle, or sports
bottle and a default serving of 150, 250, 330, 500, 750, or 1000 mL. These use
registered Edadat keys (`water_vessel`, `water_serving_ml`), so they participate
in settings backup, restore, and reset. The selected vessel is also the water
FAB illustration. A normal tap opens the daily water panel described below;
its Other amount or time action retains the editable water form, initialized
with the selected serving.

A long press keeps its pointer attached to the FAB and inserts a centered
OverlayEntry. Moving up increases the amount; down decreases it. Every 8 logical
pixels changes the amount by 25 mL, clamped to 25–2000 mL for this quick control.
This is an input range, not a daily goal. Haptics occur at the start and when
crossing 100 mL increments. The illustrated fill represents one configured
serving and caps at full; the numeric amount remains authoritative above it.
The enlarged surface animates for 180 ms and respects reduced motion. Only the
small overlay and vessel repaint while dragging, without backdrop blur. The
separate FAB wave animation is described below.

Release enters review without writing. The review shows the entry date and
provides a slider, plus/minus buttons, preferences shortcut, Cancel, and an
explicit Log water action. Logging uses the selected diary period, guards
against duplicate requests, preserves the amount on failure, and offers Undo.
Pointer cancellation and app backgrounding remove the preview. Local route
history consumes Android Back; the shell permits internal history to handle
Back before its normal return-to-Measurements behavior. The FAB tooltip does
not claim long presses; its accessible label/hint explains the gesture.

Validation covers relative dragging, min/max limits, release without writing,
log/undo, cancellation, actual system Back dispatch, setting both defaults,
settings reload/backup restore, duplicate-save prevention, failure/retry, and
English/Arabic large-text portrait/landscape layout. The focused nutrition,
shell, settings registry, and translation suites contain 75 passing tests.

Device validation: Pixel_10_Pro, `emulator-5554`, logical display 0. PolyScreen
opened the preview and preferences and verified the glass/bottle selection.
For continuous hold-then-drag only, raw ADB `input touchscreen -d 0 motionevent`
DOWN/MOVE/UP was used because PolyScreen exposes complete swipes but no held
pointer sequence. PolyScreen accessibility reads confirmed 250 → 500 → 375 mL
before release. The remainder of UI interaction and captures used PolyScreen.


## Daily water fill and anchored panel (2026-11-14)

The water FAB uses a two-layer wave painter and shows the selected day's actual
mL total. Fill is that total divided by the daily target, clamped visually to
100%; excess intake remains visible numerically. The target is user chosen in
Settings → General → Water preferences, stored in the registered Edadat key
`water_daily_target_ml`, and included in settings backup/restore. It starts
unset (0); no suggested health target is imposed. Without a target, the wave
is decorative and the panel explicitly says the target is not set.

The daily total watches the local database between calendar-day boundaries,
independently of the selected period's aggregate. It uses today when the
selected range contains today, otherwise the range's last day, matching entry
behavior. Midnight invalidates the day selection. Writes, edits, deletes and
Undo update the total through the database stream. Wave repainting is limited
to the FAB; it pauses behind routes, in background, and with reduced motion.

Tap opens Safaeh 1.1.1's anchored genie surface, as used by the medicine FAB.
The one-item panel shows Water, its date, daily intake and optional target,
quick serving chips, Log water, Other amount or time, and preferences. It
scrolls within the available safe height. Saving is guarded and errors keep
its selected amount for retry. The existing centered hold-and-slide control
and explicit review-before-save behavior remain available.

Regression coverage includes optional target validation and Arabic digits,
settings reload/backup restore, day isolation, target-based fill and overflow,
panel logging and Undo, plus English/Arabic large-text portrait/landscape
controls. The widget test fixture now sets both physical size and pixel ratio
so the Navigator's MediaQuery and anchored follower use the same viewport.

Validation result: 73 focused tests passed and analysis is clean. PolyScreen on
Pixel_10_Pro (`emulator-5554`, logical display 0) confirmed target entry, daily
intake updating after a 500 mL log, Undo removing a second log, long-press
review, and Back returning to Food & water. Two captures of the stationary FAB
had 1258 changed pixels in its 168×168 device-pixel region, confirming the wave
animates. A RepaintBoundary isolates that paint. Raw ADB was used only to install
the debug APK; there was no direct ADB UI fallback in this follow-up.


## Water vessels and daily reminders (2026-11-14)

This supersedes the single-serving panel and hold-preview layout above. The
water FAB still animates the selected day's intake against the user's optional
daily target. Tap opens the existing Safaeh 1.1.1 medicine-style genie modal:
1–4 saved vessels, capacity and optional name, and one tap to save with Undo.
The header holds reminders, preferences, custom amount/time and close. Three
vessels fit in one row at normal phone text size; large text uses fewer columns
and scrolls within the safe height.

Water preferences let users add/edit/remove glass, mug, bottle and sports-bottle
profiles, choose 25–5000 mL capacities, and star the default for holding. The last
profile cannot be deleted. The registered `water_bottles` JSON setting writes
profiles and default together and participates in settings backup/reset. Empty
or malformed data falls back to the existing vessel/serving preferences; an
upgrade does not silently replace the user's old default.

While held, the center contains only the enlarged default vessel and mL number,
with a softly blurred blue backdrop. Sliding adjusts the amount; water waves
animate inside the vessel via a painter listenable and isolated repaint boundary.
The FAB wave pauses behind the hold overlay. Reduced-motion settings stop both
animations. Releasing still enters explicit review, so a cancelled gesture does
not log a drink. The header's custom-amount action remains available without
holding.

Reminders are opt-in, Android-only, and stored in `water_reminders`. Users choose
up to eight daily local times and optionally a delay after drinking (15–120
minutes in the picker). The latest actual, non-future water entry drives the
adjustment; Undo, edits and deletion replan through the database stream. Nearby
scheduled reminders coalesce at the end of the delay. Earlier/delivered reminders
are not revived; a same-minute drink cannot replay an already delivered alarm.
Adjustments do not cross midnight or change tomorrow's regular schedule.

A native self-renewing AlarmManager alarm schedules one upcoming notification,
so it continues without a running Dart engine or a finite scheduling horizon.
Boot, app update, timezone/time changes and exact-alarm permission grants rebuild
it. The preferences screen requests notification access, reports approximate
timing if exact-alarm access is unavailable, and shows the next reminder.
The water alarm/channel/negative notification ID are independent of medicine
notifications. Medicine refresh cancels the plugin's pending medicine alarms in
one batch and dismisses only positive active IDs, preserving water reminders.

A reminder tap selects Food & water in the existing root shell. Cold launch
starts that tab as the single root route. Native fresh-tap tokens distinguish a
new notification from Android's retained task intent after process death; Flutter
fragment restoration cannot override a fresh water destination.

Validation: 83 focused Flutter tests pass, Flutter analysis is clean, and the
Android native unit suite passes, including 11 water-planner cases covering
coalescing, Undo, midnight, historical/future entries, delivered slots, and DST.
Widget coverage includes 1–4 bottle choices, profile migration/default changes,
backup restore, one-tap saving/Undo, hold gestures, English/Arabic large text and
landscape, plus repeated external tab selection preserving the mounted shell.

PolyScreen validation used Pixel_10_Pro (`emulator-5554`), logical display 0.
Created Glass 500 mL, Bottle 330 mL and Gym 1200 mL, starred Gym, and verified the
compact three-choice panel. A continuous hold/drag changed 1200 → 950 mL while
showing only vessel and number; Back cancelled without a write. This held-pointer
sequence used raw ADB `input touchscreen -d 0 motionevent DOWN/MOVE/UP` because
PolyScreen does not expose a retained pointer. All other UI input and captures
used PolyScreen. Raw ADB also handled installation, logs and process diagnostics.
A 330 mL drink moved the actual native alarm from 01:02 to 01:16; Undo restored
01:02 and the 500 mL daily total. The alarm fired after the app process was killed,
and tapping it cold-opened Food & water without duplicate-shell/GlobalKey errors.

A second real alarm at 01:04 was tapped while Measurements was already mounted;
it switched the existing shell to Food & water with no Flutter errors. The
temporary 01:04 time was removed, reminders were turned off (`next = 0`), and
the regular 09:00 / 13:00 / 17:00 times remain available. The emulator retains
only its original 500 mL demo drink, 2000 mL target and three demo vessels.


## Food and water feature settings (2026-11-14)

Food and Water tracking now have independent switches in onboarding and their
own Settings sections. The registered `food_tracking_enabled` and
`water_tracking_enabled` values default to true, preserving the existing diary
on upgrade. Disabling either hides its action, history and overview values;
it never deletes entries or vessel/target preferences. Navigation and the title
adapt to Food, Water or Food & water. Disabling both removes the destination and
safely rebases the selected tab. The Health tools shortcut follows the same gates.

Food has one display preference, `food_nutrition_totals`: show energy and nutrient
totals in the overview. It does not alter saved nutrition or the food editor.
Water has one preferences link for the existing daily target, saved cups/bottles
and reminder schedule. The former General link was moved, not duplicated.
Dependent settings disable with their feature and preserve their values.
Onboarding uses the same registry and opens the same Water preferences screen.
Its six tracking choices use a compact two-column phone layout at normal text
size; larger text retains a scrollable, roomier layout.

Turning Water tracking off cancels the native alarm and active water notification
while retaining the user's opted-in reminder schedule. Re-enabling tracking
resumes that schedule; an opted-out schedule stays off. The reminders screen
cannot enable notifications while Water tracking is disabled.

Validation: 220 focused tests passed across settings, onboarding, diary, backup,
and shell suites after targeted reruns. This includes all 51 onboarding copy/
phone-fit checks (all supported locales at 360×640 and 390×844), independent
feature combinations, data preservation after re-enabling, hidden nutrition
totals, reactive dependent controls, shared onboarding preferences, and settings
backup/reload. Flutter analysis and the debug APK build pass.

PolyScreen checked `emulator-5554`, logical display 0: Food off produces Water
history with a single water FAB; both off removes the diary destination; enabling
tracking restores it. With daily reminders enabled, disabling Water changed the
native schedule to `enabled=false, next=0`; re-enabling restored the saved 09:00
alarm. Testing ended with Food/Water enabled and reminders off. No data was
cleared. Raw ADB was used only for install and read-only native diagnostics; all
UI actions used PolyScreen.

## Safaeh 1.2.5 and Hisab performance adaptations (2026-11-14)

Reviewed the Hisab app, its cloud overlay (including settings optimization
`857fb11`), and Safaeh's 1.2.5 host guide. Janan now requires the published
Safaeh 1.2.5 package; no local dependency override is needed.

- Shared option/action sheets use `SafaehSheetTemplate` and opaque
  `SafaehSheetSurface` rows. Long choice lists build lazily and retain the
  existing deferred entrance for the language picker. Immediate choices still
  dismiss with their value and have no redundant submit button.
- Shared form/deletion footers and the custom time-format editor use the new
  template so actions remain reachable while content scrolls. The water editor
  uses its pinned feedback/footer slots and `SafaehSheetActionButton`, with the
  existing validation, duplicate-save guard, error/retry and persistence policy.
  Safaeh alone owns the route's safe-area and keyboard insets.
- App-wide sheet content defaults use an opaque white light surface and the
  active dark Material surface. The existing tuned-glass route and optimized
  Android slide remain intact.
- `LazySettingsList` adapts Hisab's row-level delegate and card outlines. It
  mounts viewport rows instead of the old whole-catalog `Column`; expanded
  subsections also yield individual rows. Each row subscribes to its own
  settings providers only when mounted. Stable setting keys preserve identity.
- Index/search navigation locates unmounted rows using overlapping viewport
  steps and then measured alignment. Steps animate unless reduced motion is
  enabled. New selections and manual drags cancel obsolete reveals. Scroll-spy
  tracking works when a section's header is outside the viewport. Headers expose
  their expansion action to accessibility services.

Other Hisab techniques were considered individually. Its two-page shell's
adjacent-page preparation would also preload charts/data pages in Janan's larger
shell, so it was not enabled globally. Receipt image decode/cache changes,
cloud startup, currency caching, database polling and mobile-web rendering
policies target different data/platform paths and were not copied wholesale.
The new sheet data loader remains available for future asynchronous editors;
these local choice sheets do not need an artificial data-loading layer. Existing
retained shell pages, water repaint isolation/reduced-motion behavior, and
separate cached CI jobs already implement related improvements.

Validation includes settings/index/search/locale and shell suites, shared
sheets, input/deletion dialogs, export column editors, settings editors and
English/Arabic nutrition flows. Focused regressions verify fewer than 20 mounted
settings anchors on first open, fewer than 30 built rows in a 200-choice sheet,
selection of its final row, disabled choices, and a footer above a simulated
keyboard. These establish bounded UI work; no Janan frame-time speedup is claimed
from Hisab's separate benchmark. Flutter analysis and the FOSS Android debug
build pass.

PolyScreen validation uses `emulator-5554`, logical display 0: language sheet
appearance/selection, search reaching the previously unmounted nutrition setting,
and the water editor's opaque reading surface and pinned save action. PolyScreen
reports the modal barrier as occluding sheet controls, so those taps use the
visible control bounds confirmed by capture. All device UI input uses PolyScreen;
raw ADB is used only for APK installation and diagnostics.

## App-wide sheet revamp (2026-11-14)

All app-owned bottom sheets now share the Safaeh 1.2.5 content system.
`AppSheetBody` supplies readable surfaces, scrolling content, feedback, and
footer slots. `AppSheetAction` owns its activity animation, respects reduced
motion, and supports working, failed, and destructive states. Feature code
continues to own validation, persistence, and return values.

Coverage includes text/number editors, integer and slider settings, time-format
presets and custom formats, colors, medicine selection, action menus,
confirmations, metric explanations, health-tool forms and linked-reading
selection, onboarding preferences, export, water bottles/targets, food quantity
and discard/delete flows. The calendar, medication-dose, water-daily and
Bluetooth panels also use the template while retaining their anchored motions.
Native date/time selectors and the full-screen import/export-column editors
remain their respective screen types.

Actions stay outside body scrolling when space permits. With less than 220 dp
of body height, forms scroll their actions too, preventing landscape-keyboard
overflow. The field subtree remains mounted across this change so unfinished
text, selection and focus survive keyboard resizing. Long pickers build rows
lazily; immediate selections have no extra confirmation step. Settings search
also caps its panel to the resized page body, rather than the full display.

Validation: a 500-test regression batch passed across shared sheets, settings,
input forms, health tools/nutrition, onboarding, medications, Bluetooth,
export-column UI and the Arabic home filter. After the search-height fix, all
23 settings-screen tests passed, including its new keyboard regression. New
sheet tests cover Arabic at 1.6x text with portrait/landscape keyboards,
validation and keyboard submission, draft preservation during resizing, and
slider dismissal versus committing once. The final water-editor adaptation
also passed all 31 nutrition/water tests. Flutter analysis reports no issues;
the FOSS Android debug APK builds successfully.

PolyScreen inspected logical display 0 on `emulator-5554` and
`emulator-5556`. The first exposed the search-height issue; the second verified
the dark onboarding preferences sheet and its nested pressure-unit picker,
including selected-state appearance and returning to the parent sheet. No
health records were created or deleted. PolyScreen's hierarchy reports the
modal barrier as covering sheet controls; capture-confirmed control bounds
were used for those taps. All device UI input used PolyScreen; raw ADB was
limited to installation and read-only diagnostics.
