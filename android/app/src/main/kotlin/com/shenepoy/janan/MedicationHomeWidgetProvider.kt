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
import android.graphics.RectF
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

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
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
        val raw = context.getSharedPreferences("medication_widget", Context.MODE_PRIVATE)
            .getString("summary", "[]") ?: "[]"
        val doses = try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
        val next = doses.optJSONObject(0)
        val now = System.currentTimeMillis()
        val targetAt = next?.optLong("scheduledAtMs", 0L) ?: 0L
        val hasDose = next != null && targetAt > 0L
        val overdue = hasDose && targetAt <= now
        val configuredColor = next?.optInt("color", DEFAULT_MEDICINE_COLOR)
            ?: DEFAULT_MEDICINE_COLOR
        val medicineColor = configuredColor.takeIf { it != 0 } ?: DEFAULT_MEDICINE_COLOR
        val ringColor = when {
            overdue -> OVERDUE_COLOR
            hasDose && targetAt - now <= SOON_MILLIS -> SOON_COLOR
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
        val statusOverdue = widgetLabel(
            "statusOverdue",
            R.string.medication_widget_status_overdue,
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
            progressRing(context, ringProgress(targetAt, now, hasDose), ringColor),
        )
        if (hasDose) {
            val fallbackMedicine = context.getString(
                R.string.medication_widget_medicine,
            )
            val name = next.optString("name", fallbackMedicine).trim().ifEmpty {
                fallbackMedicine
            }
            val storedStatus = next.optString("status", "pending")
            val label = when {
                overdue -> statusOverdue
                storedStatus == "snoozed" -> statusSnoozed
                targetAt - now <= SOON_MILLIS -> statusSoon
                else -> statusNextDose
            }
            views.setTextViewText(R.id.widget_status, label)
            views.setTextColor(R.id.widget_status, ringColor)
            views.setTextViewText(R.id.widget_medicine, name)
            views.setViewVisibility(R.id.widget_medicine, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.widget_countdown, android.view.View.VISIBLE)

            val delta = targetAt - now
            if (overdue) {
                views.setTextViewText(
                    R.id.widget_countdown,
                    countdownText(
                        now - targetAt,
                        overdue = true,
                        nowLabel = nowLabel,
                        hourUnit = hourUnit,
                        minuteUnit = minuteUnit,
                    ),
                )
                views.setTextColor(R.id.widget_countdown, OVERDUE_COLOR)
            } else {
                views.setTextViewText(
                    R.id.widget_countdown,
                    countdownText(
                        delta,
                        overdue = false,
                        nowLabel = nowLabel,
                        hourUnit = hourUnit,
                        minuteUnit = minuteUnit,
                    ),
                )
                views.setTextColor(R.id.widget_countdown, TEXT_COLOR)
            }
            views.setContentDescription(
                R.id.widget_root,
                "$name, $label",
            )
        } else {
            views.setTextViewText(R.id.widget_status, statusAllSet)
            views.setTextColor(R.id.widget_status, medicineColor)
            views.setTextViewText(R.id.widget_medicine, noDoseDue)
            views.setViewVisibility(R.id.widget_medicine, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.widget_countdown, android.view.View.GONE)
            views.setContentDescription(R.id.widget_root, noMedicineDoseDue)
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

    private fun ringProgress(targetAt: Long, now: Long, hasDose: Boolean): Float {
        if (!hasDose) return 0.13f
        if (targetAt <= now) return 0.98f
        val elapsedFraction = 1f - (targetAt - now).toFloat() / RING_HORIZON_MILLIS
        return elapsedFraction.coerceIn(0.06f, 0.94f)
    }

    private fun countdownText(
        deltaMillis: Long,
        overdue: Boolean,
        nowLabel: String,
        hourUnit: String,
        minuteUnit: String,
    ): String {
        if (deltaMillis <= 0L) return if (overdue) "+$nowLabel" else nowLabel
        val minutes = if (overdue) {
            (deltaMillis / MINUTE_MILLIS).coerceAtLeast(1L)
        } else {
            (deltaMillis + MINUTE_MILLIS - 1L) / MINUTE_MILLIS
        }
        val value = if (minutes >= 60L) {
            val hours = if (overdue) minutes / 60L else (minutes + 59L) / 60L
            "$hours$hourUnit"
        } else {
            "$minutes$minuteUnit"
        }
        return if (overdue) "+$value" else value
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

    private fun progressRing(context: Context, progress: Float, color: Int): Bitmap {
        val density = context.resources.displayMetrics.density
        val pixels = (RING_BITMAP_DP * density).toInt().coerceAtLeast(96)
        val bitmap = Bitmap.createBitmap(pixels, pixels, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val stroke = RING_STROKE_DP * density
        val inset = stroke / 2f + 1f
        val bounds = RectF(inset, inset, pixels - inset, pixels - inset)
        val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            this.color = color
            alpha = 48
        }
        val arcPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
            this.color = color
        }
        canvas.drawArc(bounds, 0f, 360f, false, trackPaint)
        canvas.drawArc(bounds, -90f, 360f * progress, false, arcPaint)
        return bitmap
    }

    companion object {
        const val ACTION_DOSE_REFRESH = "com.shenepoy.janan.action.DOSE_WIDGET_REFRESH"
        private const val WIDGET_REFRESH_REQUEST = 7412
        private const val DEFAULT_MEDICINE_COLOR = 0xff92dccf.toInt()
        private const val OVERDUE_COLOR = 0xfff27670.toInt()
        private const val SOON_COLOR = 0xffffc857.toInt()
        private const val TEXT_COLOR = 0xfff0f7f5.toInt()
        private const val SOON_MILLIS = 60 * 60 * 1000L
        private const val MINUTE_MILLIS = 60 * 1000L
        private const val HOUR_MILLIS = 60 * MINUTE_MILLIS
        private const val RING_HORIZON_MILLIS = 24 * 60 * 60 * 1000f
        private const val RING_BITMAP_DP = 144
        private const val RING_STROKE_DP = 7f
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
