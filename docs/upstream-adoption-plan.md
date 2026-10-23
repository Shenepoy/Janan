# Upstream adoption plan

Status: Bluetooth correction and statistics improvements implemented locally;
validation notes below. Reviewed October 21, 2026. Last N days remains deferred.

## Comparison baseline

Janan is currently `26.10.8+81`, commit `43e32b11`, with existing uncommitted UI work. This comparison includes the current source; no application changes are part of this plan. The README's older Janan version is not the baseline.

Upstream's latest release is [v1.8.16, published October 11, 2026](https://github.com/derdilla/blood-pressure-monitor-fl/releases/tag/v1.8.16). Its current main is [`631cb49a48971155a195a62938a77648f548ac14`](https://github.com/derdilla/blood-pressure-monitor-fl/commit/631cb49a48971155a195a62938a77648f548ac14), October 18. The local `upstream/main` reference is stale at `17aba3d00f2e995c88f094702344adf494c5f031`, August 19. The [19-commit comparison](https://github.com/derdilla/blood-pressure-monitor-fl/compare/17aba3d00f2e995c88f094702344adf494c5f031...631cb49a48971155a195a62938a77648f548ac14) identifies the newer work. Release notes alone would incorrectly count several features already inherited by Janan.

The only main change after v1.8.16 is [vector-only upstream app icons, PR 767](https://github.com/derdilla/blood-pressure-monitor-fl/pull/767). It provides no compelling product addition for Janan's separate branding.

## Recommended scope and order

| Order | Change | Current Janan gap | Relative effort |
|---|---|---|---|
| 1 | Review Beurer decoding quirks | Special decoding still applies to BM48 and ELITE900 as well as BM85 | Small implementation; hardware evidence needed |
| 2 | Mean/median distribution control and pressure-unit consistency | Distribution has mean only; several charts explicitly use mmHg | Medium |
| 3 | Clock chart series controls and responsive sizing | All three series always shown; chart size follows screen width | Small to medium |
| 4 | Expandable chart explanations | Statistics sections have titles without explanations | Small |
| 5 | Rolling last N days | Fixed last 7/30 days and fixed custom dates already exist | Medium |

Effort is a relative planning estimate, not a delivery commitment. Port the behavior into Janan's Riverpod, fl_chart, settings, and localization patterns; avoid a blanket upstream merge across its different repository and persistence architecture.

## 1. Bluetooth quirk correction

Upstream [PR 740](https://github.com/derdilla/blood-pressure-monitor-fl/pull/740) narrowed its special byte-order/user-ID handling to BM85. Janan already excludes BM59 from that handling, but still includes BM48 and ELITE900 in `GattBloodPressureProfile.isKnownBigEndianDevice`.

Proposed work:

- Check existing packet fixtures and any available real device captures before changing BM48/ELITE900 behavior.
- Apply BM85-specific decoding only to evidence-backed models; ordinary recognition of a device is separate from special decoding.
- Add regression coverage for normal little-endian packets, BM85 big-endian packets, optional user IDs, status flags, and disconnect immediately after data delivery.
- Reconcile both current and legacy Bluetooth paths if both remain selectable.

Relevant local sources: [GATT profile](../lib/features/bluetooth/logic/devices/gatt_blood_pressure_profile.dart), [legacy current-reader path](../lib/features/bluetooth/logic/ble_read_cubit.dart), [decoder](../lib/features/bluetooth/logic/characteristics/ble_measurement_data.dart).

Separately, upstream [PR 741](https://github.com/derdilla/blood-pressure-monitor-fl/pull/741) documents Medisana BU 572. Consider adding the upstream compatibility report with attribution to [our device documentation](bluetooth.md); this does not establish that Janan itself has tested that device.

## 2. Distribution controls and pressure units

Upstream [PR 750](https://github.com/derdilla/blood-pressure-monitor-fl/pull/750) adds a mean/median selector and preferred-unit conversion for distributions. [PR 749](https://github.com/derdilla/blood-pressure-monitor-fl/pull/749) also addresses preferred units in the trend chart while adding interaction details.

Janan's distribution currently marks minimum, arithmetic mean, and maximum. Add a compact Mean / Median control beside the existing SYS / DIA / pulse selection. This switches the central statistic, not the underlying frequency counts. Keep mean as the initial mode.

Implementation requirements:

- Compute median from a sorted copy of non-null raw values. The inspected upstream implementation indexes `rawValues` without sorting; do not copy that behavior.
- Calculate summary values before display rounding. Cover odd/even counts, duplicates, outliers, empty input, and one reading.
- Audit axes, tooltips, reference lines, and summaries against the chosen pressure unit. Distribution and clock currently explicitly use mmHg; trend tooltips use integer formatting.
- Use deliberate decimal precision and histogram bins for kPa. Pulse remains in bpm. Avoid placing pressure converted to kPa and pulse in bpm on an unexplained shared radial scale; define that clock presentation before extending unit conversion there.

Local sources: [distribution component](../lib/features/statistics/value_distribution.dart), [metric selector](../lib/features/statistics/blood_pressure_distribution.dart), [analyzer](../lib/model/blood_pressure_analyzer.dart), [trend chart](../lib/features/statistics/value_graph.dart).

## 3. Clock chart controls

Upstream [PR 751](https://github.com/derdilla/blood-pressure-monitor-fl/pull/751) adds systolic, diastolic, and pulse visibility switches, prevents hiding the final series, and constrains chart size for short screens.

Adapt this as interactive legend chips in Janan's existing chart style. Start with all series visible, require one visible series, and make selected state accessible without relying on color. Widget-local state is sufficient for the initial scope; upstream does not persist these switches.

Size from the available card constraints and screen height. Check portrait, landscape, large text, and Arabic RTL. Hidden series must disappear from tooltips as well as the plotted data.

Local source: [clock chart](../lib/features/statistics/clock_bp_graph.dart).

## 4. Statistics explanations

Upstream [PR 756](https://github.com/derdilla/blood-pressure-monitor-fl/pull/756) adds expandable explanations for the distribution and clock charts. Add an accessible info action in Janan's existing statistics section headers.

Explain what frequency bars mean, how mean differs from median, and that each clock point groups readings around the hour within roughly plus/minus 30 minutes. Explicitly state the current fallback: an hour without measurements displays the overall average. A tooltip should identify such an hour as having no readings rather than presenting that fallback as an observed hourly average. This tooltip clarification is a Janan improvement proposed from the local behavior, not an upstream addition.

Write concise English and Arabic text describing the actual implementation. Local sources: [statistics screen](../lib/screens/statistics_screen.dart), [section component](../lib/features/statistics/dashboard/dashboard_section.dart), [hour grouping](../lib/model/blood_pressure_analyzer.dart).

## 5. Rolling last N days

Upstream [PR 748](https://github.com/derdilla/blood-pressure-monitor-fl/pull/748) adds an arbitrary trailing-day selector. Janan already has last 7 days, last 30 days, and a custom calendar range; the useful addition is an automatically advancing configurable window, such as 14 or 90 days.

Add a Last N days option to the current range controls. Store N explicitly rather than encoding it as a fixed date range. Define N as N local calendar days including today, advancing with the local date. Reject zero, negative, fractional, and unreasonable values. Retain existing serialized enum IDs, especially custom range ID 7.

Confirm how the shared range affects home, statistics, weight, medication summaries, and exports before adding it to every surface. Test midnight rollover, daylight-saving boundaries, restart persistence, previous-window comparisons, and range paging. Upstream's duration-based implementation should not be copied without checking its inclusive-day behavior.

Local sources: [range picker](../lib/features/data_picker/interval_picker.dart), [time steps](../lib/model/storage/types/time_step.dart), [interval storage](../lib/model/storage/types/interval_storage_setting.dart).

## Already covered or not worth porting

- Chart interaction details: Janan's trend, distribution, home, and clock charts already have touch tooltips. Use PR 749 for a units/formatting audit rather than rebuilding this feature.
- Custom export presets, CSV/PDF/Excel/database export, Microlife support, Bluetooth auto-import, and Health Connect are already present. They are not new opportunities from this comparison.
- Upstream package rearrangement, build tooling, and integration-test removal do not justify adopting changes to Janan's separate architecture and CI.
- Upstream icon changes should not replace Janan's artwork.
- No new upstream profiles, medication reminders, or scale support were established in the reviewed delta; do not invent them as release additions.

## Delivery and validation plan

1. A focused Bluetooth compatibility change after fixture review, with device documentation updated separately as appropriate.
2. A statistics change containing mean/median, chart unit corrections, clock controls, and explanations. Keep calculation and UI work reviewable in separate commits.
3. A separate rolling-range change because its storage and filtering effects span multiple features.

For implementation, run focused calculation, serialization, and widget checks plus repository-required checks. Validate affected UI in English/Arabic, both themes, portrait/landscape, and large text. Emulator interaction must use PolyScreen device/display discovery and semantic tools per AGENTS.md. Bluetooth hardware behavior needs packet evidence or actual hardware; emulator UI checks alone cannot establish compatibility.

The initial planning pass used source inspection and upstream release/commit/PR evidence without changing the application.

## Implementation and validation

Implemented the BM85-only quirk rule inside the existing modular GATT profile,
mean/median selection, preferred pressure units in distribution and trend charts,
clock series controls and responsive sizing, and expandable chart explanations.
Median uses a sorted copy of unrounded values. Pulse retains a separate bpm scale;
the trend chart has a right-hand pulse axis. Clock tooltips use the selected
pressure unit and disclose missing hourly data. English and Arabic strings are
provided, with English fallback text in the remaining catalogs.

The full non-golden suite passed (776 tests). A subsequent statistics pass also
passed (46 tests), including an added kPa chart regression. Analyzer passed with
21 informational findings outside the changed statistics code. Debug APK built
and installed successfully. The two clock golden baselines were visually
reviewed and updated for the new controls and responsive sizing. The final full
golden check passed all seven tests.

PolyScreen selected exact serial `emulator-5554` and logical display `0`
(2856 × 1280, rotation 3). Semantic UI validation confirmed the median selected
state and changed summary, help expansion, clock series deselection, and Arabic
RTL controls. Captures:

- English help: `mobile://artifacts/display-0-1792547256162-23df8502-7525-4c55-90ba-cb45d1ea1e1d.png`
- Arabic median: `mobile://artifacts/display-0-1792547424801-5ef48345-0161-4d7f-95b2-e23f041fa9cf.png`

Widget checks cover English/Arabic portrait/landscape with 2× text; clock goldens
cover light/dark themes. No raw ADB UI fallback was used. The language picker
was tapped using screenshot-confirmed node bounds because PolyScreen incorrectly
reported its visible options as covered by the dismiss backdrop.

BM85 and BM59 captured packets pass decoding with the actual profile flags.
BM48/ELITE900 physical compatibility remains unverified; no captures or hardware
were available. Existing saved readings are unchanged. No release was published.

### Distribution simplification

The mean/median feature was subsequently removed at the user's request. The
distribution again shows only the metric tabs and original minimum/average/maximum
summary. Mean/Median controls, the unit chip, median calculation, and associated
strings/tests were removed. Preferred-unit formatting remains.
