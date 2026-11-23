package com.shenepoy.janan

import android.app.ActivityOptions
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/** User-initiated widget taps open without a launcher-owned task zoom. */
class MedicationWidgetTapReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val widgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        )
        val provider = AppWidgetManager.getInstance(context).getAppWidgetInfo(widgetId)?.provider
        if (provider != ComponentName(context, MedicationHomeWidgetProvider::class.java)) return
        val identity = medicationWidgetLaunchIdentity(context.packageName, widgetId)
        if (intent.action != identity.action) return
        val launch = Intent(context, MedicationWidgetActionActivity::class.java).apply {
            action = identity.action
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            sourceBounds = intent.sourceBounds
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION
        }
        context.startActivity(
            launch,
            ActivityOptions.makeCustomAnimation(context, 0, 0).toBundle(),
        )
    }
}
