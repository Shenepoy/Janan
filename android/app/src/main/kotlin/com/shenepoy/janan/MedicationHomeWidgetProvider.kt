package com.shenepoy.janan

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PathMeasure
import android.graphics.RectF
import org.json.JSONObject
import android.os.Build
import android.widget.RemoteViews
import org.json.JSONArray

class MedicationHomeWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (widgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId)
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        for (widgetId in appWidgetIds) {
            MedicationWidgetStore.clearScheduleId(context, widgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        // Cold boot drops AlarmManager timers. Redraw from the saved dose
        // times and schedule the next refresh. Dose notifications are restored
        // separately by ScheduledNotificationBootReceiver.
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            intent.action == Intent.ACTION_TIME_CHANGED ||
            intent.action == Intent.ACTION_DATE_CHANGED ||
            intent.action == Intent.ACTION_TIMEZONE_CHANGED
        ) {
            val manager = AppWidgetManager.getInstance(context)
            val provider = ComponentName(context, MedicationHomeWidgetProvider::class.java)
            onUpdate(context, manager, manager.getAppWidgetIds(provider))
        }
    }

    private fun updateWidget(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
    ) {
        val views = RemoteViews(context.packageName, R.layout.medication_widget)
        val next = MedicationWidgetStore.viewFor(context, widgetId)
        val now = System.currentTimeMillis()
        val targetAt = next?.optLong("scheduledAtMs", 0L) ?: 0L
        val hasDose = next != null && targetAt > 0L
        val overdue = hasDose && targetAt <= now
        val medicineColor = next?.widgetColor("color") ?: DEFAULT_MEDICINE_COLOR
        val ringColor = when {
            overdue -> OVERDUE_COLOR
            hasDose && targetAt - now <= SOON_MILLIS -> YELLOW_COLOR
            hasDose -> GREEN_COLOR
            else -> medicineColor
        }
        fun widgetLabel(key: String, fallbackResource: Int): String {
            val fallback = context.getString(fallbackResource)
            return next?.optString(key, fallback) ?: fallback
        }
        val statusAllSet = widgetLabel(
            "statusAllSet",
            R.string.medication_widget_status_all_set,
        )
        val statusSnoozed = widgetLabel(
            "statusSnoozed",
            R.string.medication_widget_status_snoozed,
        )
        val statusSoon = widgetLabel("statusSoon", R.string.medication_widget_status_soon)
        val statusNextDose = widgetLabel(
            "statusNextDose",
            R.string.medication_widget_status_next_dose,
        )
        val noDoseDue = widgetLabel(
            "noDoseDue",
            R.string.medication_widget_no_dose_due,
        )
        val noMedicineDoseDue = widgetLabel(
            "noMedicineDoseDue",
            R.string.medication_widget_no_medicine_dose_due,
        )
        val nowLabel = widgetLabel("now", R.string.medication_widget_now)
        val hourUnit = widgetLabel(
            "hourUnit",
            R.string.medication_widget_hour_unit,
        )
        val minuteUnit = widgetLabel(
            "minuteUnit",
            R.string.medication_widget_minute_unit,
        )

        views.setImageViewBitmap(
            R.id.widget_progress_ring,
            progressRings(context, reminderRings(next), now, flash = false),
        )
        views.setImageViewBitmap(
            R.id.widget_progress_ring_siren,
            progressRings(context, reminderRings(next), now, flash = overdue),
        )
        views.setInt(
            R.id.widget_ring_flipper,
            "setFlipInterval",
            if (overdue) 420 else 86_400_000,
        )
        if (hasDose) {
            val fallbackMedicine = context.getString(
                R.string.medication_widget_medicine,
            )
            val name = next.optString("name", fallbackMedicine).trim().ifEmpty {
                fallbackMedicine
            }
            val shortName = next.optString("shortName", "").trim().ifEmpty {
                compactMedicineName(name)
            }
            val storedStatus = next.optString("status", "pending")
            val label = when {
                storedStatus == "snoozed" -> statusSnoozed
                targetAt - now <= SOON_MILLIS -> statusSoon
                else -> statusNextDose
            }
            if (overdue) {
                views.setViewVisibility(R.id.widget_status, android.view.View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_status, android.view.View.VISIBLE)
                views.setTextViewText(R.id.widget_status, label)
                views.setTextColor(R.id.widget_status, ringColor)
            }
            views.setTextViewText(R.id.widget_medicine, shortName)
            views.setViewVisibility(R.id.widget_medicine, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.widget_countdown, android.view.View.VISIBLE)

            views.setTextViewText(
                R.id.widget_countdown,
                countdownText(
                    if (overdue) now - targetAt else targetAt - now,
                    overdue = overdue,
                    nowLabel = nowLabel,
                    hourUnit = hourUnit,
                    minuteUnit = minuteUnit,
                ),
            )
            views.setTextColor(R.id.widget_countdown, ringColor)
            views.setContentDescription(
                R.id.widget_root,
                if (overdue) name else "$name, $label",
            )
        } else {
            val pinned = next?.optString("name")?.trim().orEmpty()
            val medicineLabel = if (pinned.isEmpty()) {
                noDoseDue
            } else {
                next?.optString("shortName", "")?.trim()?.ifEmpty {
                    compactMedicineName(pinned)
                } ?: compactMedicineName(pinned)
            }
            views.setViewVisibility(R.id.widget_status, android.view.View.VISIBLE)
            views.setTextViewText(R.id.widget_status, statusAllSet)
            views.setTextColor(R.id.widget_status, medicineColor)
            views.setTextViewText(R.id.widget_medicine, medicineLabel)
            views.setViewVisibility(R.id.widget_medicine, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.widget_countdown, android.view.View.GONE)
            views.setContentDescription(
                R.id.widget_root,
                if (pinned.isEmpty()) noMedicineDoseDue else "$pinned, $statusAllSet",
            )
        }

        scheduleRefresh(context, nextCountdownRefresh(targetAt, now, hasDose))

        val intent = Intent(context, MainActivity::class.java).apply {
            putExtra("route", "/medications/today")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            widgetId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
        manager.updateAppWidget(widgetId, views)
    }

    private fun scheduleRefresh(context: Context, triggerAtMillis: Long?) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, MedicationWidgetRefreshReceiver::class.java)
            .setAction(ACTION_DOSE_REFRESH)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            WIDGET_REFRESH_REQUEST,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarmManager.cancel(pendingIntent)
        if (triggerAtMillis == null || triggerAtMillis <= System.currentTimeMillis()) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            !alarmManager.canScheduleExactAlarms()
        ) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent,
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent,
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent,
            )
        }
    }

    private fun ringProgress(
        targetAt: Long,
        now: Long,
        hasDose: Boolean,
        intervalMs: Long = DAY_MILLIS,
    ): Float {
        if (!hasDose) return 0.12f
        if (targetAt <= now) return 1f
        val remaining = targetAt - now
        val span = if (intervalMs > 0L) intervalMs else DAY_MILLIS
        if (remaining >= span) return 0.08f
        val elapsed = 1f - remaining.toFloat() / span.toFloat()
        return elapsed.coerceIn(0.08f, 1f)
    }

    private fun countdownText(
        deltaMillis: Long,
        overdue: Boolean,
        nowLabel: String,
        hourUnit: String,
        minuteUnit: String,
    ): String {
        if (deltaMillis <= 0L) return nowLabel
        val minutes = if (overdue) {
            (deltaMillis / MINUTE_MILLIS).coerceAtLeast(1L)
        } else {
            (deltaMillis + MINUTE_MILLIS - 1L) / MINUTE_MILLIS
        }
        return if (minutes >= 60L) {
            val hours = if (overdue) minutes / 60L else (minutes + 59L) / 60L
            "$hours$hourUnit"
        } else {
            "$minutes$minuteUnit"
        }
    }

    private fun nextCountdownRefresh(
        targetAt: Long,
        now: Long,
        hasDose: Boolean,
    ): Long? {
        if (!hasDose) return null
        if (targetAt > now) {
            val remaining = targetAt - now
            val minutes = (remaining + MINUTE_MILLIS - 1L) / MINUTE_MILLIS
            val labelBoundary = if (remaining > SOON_MILLIS) {
                val hours = (minutes + 59L) / 60L
                targetAt - (hours - 1L) * HOUR_MILLIS
            } else {
                targetAt - (minutes - 1L).coerceAtLeast(0L) * MINUTE_MILLIS
            }
            val soonBoundary = targetAt - SOON_MILLIS
            return if (remaining > SOON_MILLIS) {
                minOf(labelBoundary, soonBoundary)
            } else {
                labelBoundary
            }
        }

        val elapsedMinutes = (now - targetAt) / MINUTE_MILLIS
        return if (elapsedMinutes < 60L) {
            targetAt + (elapsedMinutes + 1L) * MINUTE_MILLIS
        } else {
            targetAt + (elapsedMinutes / 60L + 1L) * HOUR_MILLIS
        }
    }

    private data class WidgetRing(
        val at: Long,
        val dotted: Boolean,
        val colors: IntArray,
        val times: LongArray,
        val intervals: LongArray,
        val status: String,
    )

    private data class RingMark(val progress: Float, val color: Int)

    private fun reminderRings(summary: JSONObject?): List<WidgetRing> {
        val encoded = summary?.optJSONArray("rings")
        if (encoded != null && encoded.length() > 0) {
            return List(encoded.length()) { index ->
                val ring = encoded.getJSONObject(index)
                val doses = ring.optJSONArray("doses")
                val colors = if (doses == null || doses.length() == 0) {
                    intArrayOf(DEFAULT_MEDICINE_COLOR)
                } else {
                    IntArray(doses.length()) { doseIndex ->
                        doses.getJSONObject(doseIndex).widgetColor("color")
                    }
                }
                val ringAt = ring.optLong("scheduledAtMs", 0L)
                val times = if (doses == null || doses.length() == 0) {
                    longArrayOf(ringAt)
                } else {
                    LongArray(doses.length()) { doseIndex ->
                        val at = doses.getJSONObject(doseIndex).optLong("scheduledAtMs", 0L)
                        if (at > 0L) at else ringAt
                    }
                }
                val intervals = if (doses == null || doses.length() == 0) {
                    longArrayOf(DAY_MILLIS)
                } else {
                    LongArray(doses.length()) { doseIndex ->
                        val interval = doses.getJSONObject(doseIndex).optLong("intervalMs", 0L)
                        if (interval > 0L) interval else DAY_MILLIS
                    }
                }
                WidgetRing(
                    at = ringAt,
                    dotted = ring.optBoolean("dotted", colors.size > 1),
                    colors = colors,
                    times = times,
                    intervals = intervals,
                    status = ring.optString("status", "pending"),
                )
            }
        }
        val at = summary?.optLong("scheduledAtMs", 0L) ?: 0L
        if (summary == null || at <= 0L) return emptyList()
        val color = summary.widgetColor("color")
        return listOf(
            WidgetRing(
                at = at,
                dotted = false,
                colors = intArrayOf(color),
                times = longArrayOf(at),
                intervals = longArrayOf(
                    summary.optLong("intervalMs", 0L).let { interval ->
                        if (interval > 0L) interval else DAY_MILLIS
                    },
                ),
                status = summary.optString("status", "pending"),
            ),
        )
    }

    private fun progressRings(
        context: Context,
        rings: List<WidgetRing>,
        now: Long,
        flash: Boolean,
    ): Bitmap {
        val density = context.resources.displayMetrics.density
        val pixels = (RING_BITMAP_DP * density).toInt().coerceAtLeast(96)
        val bitmap = Bitmap.createBitmap(pixels, pixels, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val stroke = pixels * RING_STROKE_FRACTION
        val layers = if (rings.isEmpty()) {
            listOf(
                WidgetRing(
                    0L,
                    false,
                    intArrayOf(DEFAULT_MEDICINE_COLOR),
                    longArrayOf(0L),
                    longArrayOf(DAY_MILLIS),
                    "pending",
                ),
            )
        } else {
            rings.take(2)
        }
        val outerSide = pixels - stroke
        val outerRadius = minOf(outerSide * RING_CORNER_FRACTION, outerSide / 2f)
        layers.forEachIndexed { index, ring ->
            val inset = stroke / 2f + index * stroke
            if (pixels <= inset * 2f + stroke) return@forEachIndexed
            val corner = maxOf(0f, outerRadius - index * stroke)
            val path = roundedSquareRingPath(
                RectF(inset, inset, pixels - inset, pixels - inset),
                corner,
            )
            val marks = if (rings.isEmpty()) {
                listOf(RingMark(1f, DEFAULT_MEDICINE_COLOR))
            } else {
                ringMarks(ring, now, flash && index == 0, inner = index > 0)
            }
            drawSharedRing(canvas, path, stroke, marks)
        }
        return bitmap
    }

    /** One arc per medicine. A shared time keeps each medicine color. */
    private fun ringMarks(
        ring: WidgetRing,
        now: Long,
        flash: Boolean,
        inner: Boolean,
    ): List<RingMark> {
        val overdue = ring.at > 0L && ring.at <= now
        if (!inner && overdue) {
            return listOf(RingMark(1f, if (flash) SIREN_COLOR else OVERDUE_COLOR))
        }
        if (ring.dotted && ring.colors.size > 1) {
            return ring.colors.take(3).mapIndexed { index, color ->
                val at = ring.times.getOrElse(index) { ring.at }
                val interval = ring.intervals.getOrElse(index) { DAY_MILLIS }
                var progress = if (at > 0L) ringProgress(at, now, true, interval) else 0.12f
                if (inner) progress = progress.coerceAtMost(INNER_OPEN_CAP)
                RingMark(progress, color)
            }
        }
        val interval = ring.intervals.firstOrNull() ?: DAY_MILLIS
        var progress = if (ring.at > 0L) ringProgress(ring.at, now, true, interval) else 0.12f
        if (inner) progress = progress.coerceAtMost(INNER_OPEN_CAP)
        val color = if (inner) {
            ring.colors.firstOrNull() ?: DEFAULT_MEDICINE_COLOR
        } else {
            ringPaintColor(ring, now, flash)
        }
        return listOf(RingMark(progress, color))
    }

    private fun ringPaintColor(ring: WidgetRing, now: Long, flash: Boolean): Int {
        if (flash) return SIREN_COLOR
        if (ring.dotted || ring.at <= 0L) return ring.colors.first()
        if (ring.at <= now) return OVERDUE_COLOR
        if (ring.at - now <= SOON_MILLIS) return YELLOW_COLOR
        return GREEN_COLOR
    }

    private fun drawSharedRing(
        canvas: Canvas,
        path: Path,
        stroke: Float,
        marks: List<RingMark>,
    ) {
        if (marks.isEmpty()) return
        val measure = PathMeasure(path, false)
        if (marks.size == 1) {
            val progress = marks.first().progress
            if (progress <= 0f) return
            if (progress >= 1f) {
                canvas.drawPath(path, strokePaint(marks.first().color, stroke))
                return
            }
            val segment = Path()
            val end = measure.length * progress.coerceIn(0f, 1f)
            if (measure.getSegment(0f, end, segment, true)) {
                segment.rLineTo(0f, 0f)
                canvas.drawPath(segment, strokePaint(marks.first().color, stroke))
            }
            return
        }
        val longest = marks.maxOf { it.progress }
        val shortest = marks.minOf { it.progress }
        if (longest - shortest < 0.01f) {
            drawBands(canvas, path, measure, marks, longest, stroke)
            return
        }
        val capped = marks.filter { it.progress >= INNER_OPEN_CAP - 0.01f }
        val shorter = marks
            .filter { it.progress < INNER_OPEN_CAP - 0.01f }
            .sortedByDescending { it.progress }
        if (capped.isNotEmpty()) {
            val cover = shorter.maxOfOrNull { it.progress } ?: 0f
            drawOpenBands(canvas, path, measure, capped, cover, stroke)
        }
        for (mark in shorter) {
            drawSpan(canvas, path, measure, 0f, mark.progress, mark.color, stroke, Paint.Cap.ROUND)
        }
    }

    private fun drawOpenBands(
        canvas: Canvas,
        path: Path,
        measure: PathMeasure,
        marks: List<RingMark>,
        cover: Float,
        stroke: Float,
    ) {
        val tail = INNER_OPEN_CAP - cover
        if (tail <= 0f || marks.isEmpty()) {
            drawBands(canvas, path, measure, marks, INNER_OPEN_CAP, stroke)
            return
        }
        val slice = tail / marks.size
        marks.forEachIndexed { index, mark ->
            val from = if (index == 0) 0f else cover + index * slice
            drawSpan(
                canvas,
                path,
                measure,
                from,
                cover + (index + 1) * slice,
                mark.color,
                stroke,
                Paint.Cap.BUTT,
            )
        }
    }

    private fun drawBands(
        canvas: Canvas,
        path: Path,
        measure: PathMeasure,
        marks: List<RingMark>,
        span: Float,
        stroke: Float,
    ) {
        val length = span.coerceIn(0f, 1f)
        if (length <= 0f || marks.isEmpty()) return
        val band = length / marks.size
        marks.forEachIndexed { index, mark ->
            drawSpan(
                canvas,
                path,
                measure,
                index * band,
                (index + 1) * band,
                mark.color,
                stroke,
                Paint.Cap.BUTT,
            )
        }
    }

    private fun drawSpan(
        canvas: Canvas,
        path: Path,
        measure: PathMeasure,
        from: Float,
        to: Float,
        color: Int,
        stroke: Float,
        cap: Paint.Cap,
    ) {
        if (to <= from) return
        if (from <= 0f && to >= 1f) {
            canvas.drawPath(path, strokePaint(color, stroke, cap))
            return
        }
        val segment = Path()
        val start = measure.length * from.coerceIn(0f, 1f)
        val end = measure.length * to.coerceIn(0f, 1f)
        if (end <= start) return
        if (measure.getSegment(start, end, segment, true)) {
            segment.rLineTo(0f, 0f)
            canvas.drawPath(segment, strokePaint(color, stroke, cap))
        }
    }

    /** ARGB colors from Flutter are larger than a signed 32-bit int in JSON. */
    private fun JSONObject.widgetColor(key: String): Int {
        val raw = opt(key) as? Number ?: return DEFAULT_MEDICINE_COLOR
        return raw.toLong().toInt().takeIf { it != 0 } ?: DEFAULT_MEDICINE_COLOR
    }

    private fun compactMedicineName(name: String): String {
        val trimmed = name.trim().replace(Regex("\\s+"), " ")
        if (trimmed.isEmpty()) return trimmed
        val limit = when {
            trimmed.any { wideNameLetter(it) } -> 4
            trimmed.any { arabicNameLetter(it) } -> 6
            else -> 8
        }
        if (trimmed.length <= limit) return trimmed
        if (limit <= 1) return "…"
        return trimmed.take(limit - 1) + "…"
    }

    private fun arabicNameLetter(letter: Char): Boolean {
        val rune = letter.code
        return rune in 0x0590..0x05FF ||
            rune in 0x0600..0x06FF ||
            rune in 0x0750..0x077F ||
            rune in 0x08A0..0x08FF ||
            rune in 0xFB50..0xFDFF ||
            rune in 0xFE70..0xFEFF
    }

    private fun wideNameLetter(letter: Char): Boolean {
        val rune = letter.code
        return rune in 0x0B80..0x0BFF ||
            rune in 0x3040..0x30FF ||
            rune in 0x3400..0x4DBF ||
            rune in 0x4E00..0x9FFF ||
            rune in 0xAC00..0xD7AF
    }

    private fun strokePaint(
        color: Int,
        stroke: Float,
        cap: Paint.Cap = Paint.Cap.ROUND,
    ) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = stroke
        strokeCap = cap
        strokeJoin = Paint.Join.ROUND
        this.color = color
    }

    /** Same top-center rounded-square track as the in-app countdown ring. */
    private fun roundedSquareRingPath(bounds: RectF, corner: Float): Path {
        val radius = minOf(corner, bounds.width() / 2f)
        return Path().apply {
            moveTo(bounds.centerX(), bounds.top)
            if (radius <= 0f) {
                lineTo(bounds.right, bounds.top)
                lineTo(bounds.right, bounds.bottom)
                lineTo(bounds.left, bounds.bottom)
                lineTo(bounds.left, bounds.top)
                close()
                return@apply
            }
            lineTo(bounds.right - radius, bounds.top)
            arcTo(
                RectF(
                    bounds.right - radius * 2f,
                    bounds.top,
                    bounds.right,
                    bounds.top + radius * 2f,
                ),
                -90f,
                90f,
                false,
            )
            lineTo(bounds.right, bounds.bottom - radius)
            arcTo(
                RectF(
                    bounds.right - radius * 2f,
                    bounds.bottom - radius * 2f,
                    bounds.right,
                    bounds.bottom,
                ),
                0f,
                90f,
                false,
            )
            lineTo(bounds.left + radius, bounds.bottom)
            arcTo(
                RectF(
                    bounds.left,
                    bounds.bottom - radius * 2f,
                    bounds.left + radius * 2f,
                    bounds.bottom,
                ),
                90f,
                90f,
                false,
            )
            lineTo(bounds.left, bounds.top + radius)
            arcTo(
                RectF(
                    bounds.left,
                    bounds.top,
                    bounds.left + radius * 2f,
                    bounds.top + radius * 2f,
                ),
                180f,
                90f,
                false,
            )
            close()
        }
    }

    companion object {
        const val ACTION_DOSE_REFRESH = "com.shenepoy.janan.action.DOSE_WIDGET_REFRESH"
        private const val WIDGET_REFRESH_REQUEST = 7412
        private const val DEFAULT_MEDICINE_COLOR = 0xff92dccf.toInt()
        private const val OVERDUE_COLOR = 0xffe53935.toInt()
        private const val SIREN_COLOR = 0xfffff6f4.toInt()
        private const val YELLOW_COLOR = 0xfff5c518.toInt()
        private const val GREEN_COLOR = 0xff2eaf62.toInt()
        private const val SOON_MILLIS = 60 * 60 * 1000L
        private const val MINUTE_MILLIS = 60 * 1000L
        private const val HOUR_MILLIS = 60 * MINUTE_MILLIS
        private const val DAY_MILLIS = 24 * HOUR_MILLIS
        private const val RING_BITMAP_DP = 144
        /** About 7dp once the bitmap is fitted into the widget. The in-app ring stays thicker. */
        private const val RING_STROKE_FRACTION = 7f / 74f
        private const val RING_CORNER_FRACTION = 0.28f

        /** Inner arcs stop here: the stroke length one moment before a dose is due. */
        private const val INNER_OPEN_CAP = 0.82f
    }
}

class MedicationWidgetRefreshReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != MedicationHomeWidgetProvider.ACTION_DOSE_REFRESH) return
        val manager = AppWidgetManager.getInstance(context)
        val provider = ComponentName(context, MedicationHomeWidgetProvider::class.java)
        val ids = manager.getAppWidgetIds(provider)
        MedicationHomeWidgetProvider().onUpdate(context, manager, ids)
    }
}
