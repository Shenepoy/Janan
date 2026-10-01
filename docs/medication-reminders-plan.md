# Medication reminders

**Status:** Product and implementation plan
**First release:** Android
**Scope:** A local medication schedule, dose reminders, and an Android home-screen widget for Janan.

## Existing foundation

Janan already has a local medicine catalog (`Medicine`), actual dose records (`MedicineIntake`), a medication manager under Settings, and an add-medicine route. Data is stored in the local-only PowerSync database `health.db`; there is no account or remote sync. The reminder feature should extend this foundation and preserve existing medicine and intake history.

One storage behavior needs attention before scheduled doses are logged: the current intake repository replaces an intake with another intake at the same second. A schedule can have two different medicines due together, so the write path must preserve both records and remain safe to retry.

## Product goal and boundaries

Help one person remember and record medicines they have already been instructed to take. The feature records plans and actual doses; it does not prescribe doses, check interactions, or advise what to do after a missed dose.

The first release supports recurring schedules on selected weekdays, one or more fixed local times per day, one dose amount per schedule, and optional start and end dates. As-needed medicines, every-N-hours schedules, tapers, and different amounts at different times are later work. They can still be logged with the existing manual medicine entry flow.

## Domain terms

- **Medicine:** An item in the existing catalog, such as a named medication with a dose unit.
- **Medication schedule:** The user's recurring instruction for a medicine: dose amount and unit, local times, selected weekdays, and optional start and end dates.
- **Dose occurrence:** One planned dose at a particular local date and time. It can be upcoming, due, snoozed, taken, skipped, or unrecorded. “Unrecorded” means Janan has no take record; it does not claim the medicine was not taken.
- **Medicine intake:** The existing record of a dose actually taken. Marking a planned dose as taken creates or links an intake at the actual time.
- **Reminder:** An operating-system notification for a dose occurrence. It is a delivery mechanism, not the record of whether a dose was taken.

## MVP features

1. Create, edit, pause, resume, and end a medication schedule.
2. Choose an existing medicine or add one; set the amount, unit, daily times, weekdays, and optional date range.
3. See today's planned doses in time order, with clear upcoming, due, snoozed-until, taken, skipped, and unrecorded states.
4. Mark a dose taken, snooze it, or skip it from the app. A taken action records the actual time and connects the intake to its planned occurrence.
5. Open the relevant dose from a notification. Keep the notification text privacy-conscious and let the user choose whether medicine names appear on the lock screen.
6. Reconcile a dose logged through the existing medicine-entry form with the nearest uncompleted occurrence for the same medicine when the match is clear. Keep unrelated and historical intakes as standalone records.
7. Show whether notifications are enabled and provide a route to the required Android settings when they are not.
8. Keep schedules and dose history on-device. Include them in local database backups and delete them through the existing delete-data flow.

## Pages and entry points

| Page or surface | Contents and actions | Entry point |
|---|---|---|
| **Home dose countdown** | One compact 56 dp medicine-colored circle matching the Add measurement FAB, with a time-left arc and an hours/minutes readout (`2h`, `58m`, `+10m`). It omits the pill icon and routine “Next dose” caption; amber marks the final hour, while red shows overdue time with a `+` prefix. Empty state invites the user to set up a schedule. | Replaces the medicine FAB above Add measurement on the blood-pressure home tab |
| **Dose quick panel** | Grows and fades upward from the countdown control, stays attached to its upper edge, dims the page, and shows a compact next-dose card with Taken / Snooze / Skip actions plus later scheduled doses. After a medicine is marked Taken, defer its next occurrence card until four hours before that occurrence; keep nearer occurrences visible so frequent schedules, such as every two hours, still surface the next dose. | Home dose countdown |
| **Bluetooth sync popout** | Uses the Bluetooth status indicator as its anchor, opens with a short fade/scale transition, and dims the page. It shows live scan/import progress and can be dismissed from the panel or backdrop. | Bluetooth sync indicator |
| **Today's medicines** | Day agenda with dose, time, status, and Taken / Snooze / Skip actions. Notification taps open this page with the relevant dose selected. | Dose quick panel, notification, widget |
| **Medication schedules** | Active, paused, and ended schedules, grouped by medicine. Reuse the existing medication manager as the starting point. | Settings → Medications |
| **Add/edit schedule** | Medicine, dose and unit, one or more times, weekdays, start/end dates, and optional instructions. | Schedule list or medicine manager |
| **Schedule detail** | Current schedule, next due time, recent dose history, and pause/edit/end actions. | Schedule list or dose agenda |
| **Reminder settings** | Notification permission state, precise-timing access state, snooze duration, and lock-screen content preference. | Settings → Medications |

Keep the existing bottom navigation unchanged for the MVP. The countdown makes the new flow discoverable without making the current four-destination shell more crowded.

## Widget

Ship one compact circular 1 × 1 Android home-screen widget with the first release. It mirrors the in-app countdown: a medicine-colored progress ring, a minute-granularity time-left display (`2h`, `58m`, `+10m`), amber within an hour of the dose, and red overdue text with elapsed time. Tapping it opens Today's medicines. The widget does not mark a dose taken in the MVP.

The widget reads one prepared next-dose summary from app-shared preferences; it must not open the PowerSync database from a widget process. A scheduled widget refresh updates the whole-hour or whole-minute label and ring at the next label boundary, when the dose enters the one-hour window, and when it becomes overdue. Schedule edits and dose actions replace the summary and due-time refresh.

## Local data and application structure

Add domain types and repository interfaces for schedules and occurrences, following the existing `lib/domain/` and `lib/core/repository/` pattern. Expose schedule and today's-occurrence streams with Riverpod providers.

Proposed local-only tables:

- `medication_schedules`: medicine ID, dose amount, dose unit, local time slots, weekday recurrence, optional start/end dates, active/paused/ended state, and timestamps.
- `dose_occurrences`: schedule ID, local scheduled date/time, stable occurrence ID, status, optional snooze-until time, actual taken time, and linked intake ID.

Store dose amount and unit separately; do not assume the amount is always milligrams. Store recurrence as local wall-clock times and weekdays so a schedule stays at the user's intended time when daylight-saving rules change. Generate occurrences with stable IDs so app restarts and schedule reconciliation cannot duplicate them.

Update `lib/core/database/powersync_schema.dart` by adding local-only tables and columns only. Do not wipe or recreate `health.db`. Preserve old medicine and intake rows. Change intake upsert behavior so distinct medicines at the same timestamp can coexist, and make take actions idempotent by linking them to a dose occurrence. Update the data-package documentation, database export/import behavior where needed, and delete-data table clearing.

## Android setup

1. Add an adapter around a local-notification plugin; `flutter_local_notifications` is a candidate because it supports scheduled Android notifications and tap payloads. Keep it behind an app-owned `LocalReminderService` so its API does not leak into schedule logic.
2. Add a deterministic schedule calculator that creates local occurrences for the current day and reconciles the next fourteen days of operating-system notifications after schedule edits or app start. Expand lifecycle and time-zone reconciliation in a later hardening pass.
3. Add notification setup to the Android manifest and request notification permission in context when the user creates their first schedule. Android 13 and later require the `POST_NOTIFICATIONS` runtime permission for regular app notifications. Android 12 and later require special access for exact alarms; use precise alarms only when that access is granted, and explain that inexact reminders may be delayed. See [Android notification permission](https://developer.android.com/develop/ui/compose/notifications/notification-permission) and [Android alarm scheduling](https://developer.android.com/develop/background-work/services/alarms).
4. Add the Android app-widget receiver, metadata, and native 1 × 1 countdown layout. Share the next dose through app-shared preferences, then refresh at its near and due transitions. See [Android app widgets](https://developer.android.com/develop/ui/views/appwidgets).
5. Add translations through the existing `easy_localization` JSON assets and verify RTL layouts. Keep medical details out of notification previews by default or make their display an explicit setting.

## Delivery sequence

1. **Domain and persistence:** Schedule/occurrence types, schema additions, repository APIs, stable occurrence generation, and intake linking.
2. **In-app flow:** Schedule editor, medication schedule list, today's agenda, state actions, circular home countdown, and attached dose panel.
3. **Notifications:** Permission education, Android scheduling adapter, rescheduling on lifecycle/time changes, and notification deep links.
4. **Widget:** Android 1 × 1 countdown, shared next-dose summary, deep link to today's agenda, and near/due refreshes.
5. **Data lifecycle and polish:** Backup/delete integration, translations, empty and denied-permission states, theme/RTL review, and device validation for reboot and time changes.

## Release acceptance

- Existing medicine history still appears after upgrade; no database wipe is needed.
- Two medicines scheduled for the same time both remain visible and can both be recorded.
- Editing, pausing, or ending a schedule removes obsolete pending notifications and refreshes the widget.
- A reboot and a time-zone change rebuild upcoming reminders from local schedules without duplicates.
- Denying notification permission leaves the in-app agenda usable and clearly shows that OS reminders are off.
- Taking a dose from the agenda records an actual intake once; skipping or snoozing does not create a taken intake.
- The in-app circle and circular widget show time remaining, the amber near-dose state, red overdue time, and the medicine's name and color.
- The home circle opens a dimmed dose panel attached to the circle; the Bluetooth sync indicator opens a matching dimmed panel attached to that indicator.
- Existing manually entered, historical, export, import, and delete-data flows remain coherent.

## Later decisions

- iOS notifications and WidgetKit widget, using the same domain model but a native WidgetKit extension and shared app-group data.
- Direct Taken/Snooze actions on notifications and interactive widget controls.
- As-needed schedules, intervals, variable dose amounts, refill tracking, and caregiver or multi-profile support.
