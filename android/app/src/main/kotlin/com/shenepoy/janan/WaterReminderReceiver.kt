package com.shenepoy.janan

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONArray

/** A single self-renewing alarm, independent from medicine notification IDs. */
class WaterReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        WaterReminderScheduler.receive(context, intent)
    }
}

internal object WaterReminderScheduler {
    private const val PREFS = "water_reminder_runtime"
    private const val CHANNEL = "water_reminders"
    private const val ACTION = "com.shenepoy.janan.WATER_REMINDER"
    // Medicine IDs are positive hashes. This separate ID is also its request code.
    const val NOTIFICATION_ID = -14001
    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private fun alarmIntent(context: Context, at: Long = 0): PendingIntent = PendingIntent.getBroadcast(
        context, NOTIFICATION_ID,
        Intent(context, WaterReminderReceiver::class.java).setAction(ACTION).putExtra("at", at),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    @Synchronized
    fun consumeTap(context: Context, intent: Intent): Boolean {
        if (intent.action != "com.shenepoy.janan.OPEN_WATER") return false
        val token = intent.getLongExtra("waterReminderAt", 0)
        val state = prefs(context)
        if (token <= 0 || state.getLong("openedReminderAt", 0) == token) return false
        return state.edit().putLong("openedReminderAt", token).commit()
    }

    fun nextScheduled(context: Context): Long? = prefs(context).getLong("next", 0).takeIf { it > 0 }

    @Synchronized
    fun configure(context: Context, args: Map<*, *>): Long? {
        val times = (args["minutes"] as? List<*>)?.filterIsInstance<Number>()
            ?.map { it.toInt() }?.filter { it in 0..1439 }?.distinct()?.sorted()?.take(8).orEmpty()
        check(prefs(context).edit()
            .putBoolean("enabled", args["enabled"] == true && times.isNotEmpty())
            .putString("minutes", JSONArray(times).toString())
            .putInt("pauseMinutes", ((args["pauseMinutes"] as? Number)?.toInt() ?: 0).coerceIn(0, 240))
            .putLong("lastDrinkMs", (args["lastDrinkMs"] as? Number)?.toLong() ?: 0)
            .putString("title", args["title"] as? String ?: "Water break")
            .putString("body", args["body"] as? String ?: "Tap to log your cup or bottle.")
            .commit()) { "Could not save water reminder preferences" }
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
        return schedule(context)
    }

    @Synchronized
    fun receive(context: Context, intent: Intent) {
        val state = prefs(context)
        val expected = state.getLong("next", 0)
        if (intent.action == ACTION && state.getBoolean("enabled", false) &&
            expected > 0 && intent.getLongExtra("at", 0) == expected &&
            expected <= System.currentTimeMillis()) {
            // A drink logged in the same minute must not revive this reminder.
            state.edit().putLong("deliveredThrough", expected).commit()
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(NotificationChannel(CHANNEL,
                state.getString("title", "Water break"), NotificationManager.IMPORTANCE_DEFAULT))
            val tap = PendingIntent.getActivity(context, NOTIFICATION_ID,
                Intent(context, MainActivity::class.java)
                    .setAction("com.shenepoy.janan.OPEN_WATER")
                    .putExtra("route", "/nutrition")
                    .putExtra("waterReminderAt", expected)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val notification = NotificationCompat.Builder(context, CHANNEL)
                .setSmallIcon(R.drawable.ic_water_reminder)
                .setContentTitle(state.getString("title", "Water break"))
                .setContentText(state.getString("body", "Tap to log your cup or bottle."))
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setAutoCancel(true).setContentIntent(tap).build()
            if (NotificationManagerCompat.from(context).areNotificationsEnabled()) {
                try { manager.notify(NOTIFICATION_ID, notification) } catch (_: SecurityException) { }
            }
        }
        schedule(context)
    }

    private fun schedule(context: Context): Long? {
        val state = prefs(context)
        val alarms = context.getSystemService(AlarmManager::class.java)
        alarms.cancel(alarmIntent(context))
        val enabled = state.getBoolean("enabled", false)
        if (!enabled) {
            state.edit().putLong("next", 0).apply()
            return null
        }
        val times = JSONArray(state.getString("minutes", "[]"))
        val next = nextWaterReminder(System.currentTimeMillis(),
            (0 until times.length()).map { times.getInt(it) },
            state.getLong("lastDrinkMs", 0), state.getInt("pauseMinutes", 0),
            deliveredThroughMs = state.getLong("deliveredThrough", 0))
        state.edit().putLong("next", next ?: 0).apply()
        if (next != null) {
            val intent = alarmIntent(context, next)
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarms.canScheduleExactAlarms()) {
                try {
                    alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, intent)
                } catch (_: SecurityException) {
                    alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, intent)
                }
            } else {
                alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, intent)
            }
        }
        return next
    }
}
