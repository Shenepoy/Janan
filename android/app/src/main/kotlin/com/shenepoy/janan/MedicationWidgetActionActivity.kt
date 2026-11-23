package com.shenepoy.janan

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.os.Build
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** A separate translucent task keeps the launcher behind the anchored panel. */
class MedicationWidgetActionActivity : MainActivity() {
    private var windowChannel: MethodChannel? = null
    private var entryComplete = false
    private val entryWaiters = mutableListOf<MethodChannel.Result>()
    private var settingsSnapshot: Map<String, *> = emptyMap<String, Any>()

    private fun savedSettings(): Map<String, *> =
        getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE).all

    override fun getBackgroundMode() = BackgroundMode.transparent
    override fun getInitialRoute() = "/medications/widget"

    private fun prepareLaunch(intent: Intent): Map<String, Any> {
        val widgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        )
        val scheduleId = MedicationWidgetStore.scheduleId(this, widgetId)
        intent.putExtra("route", "/medications/widget")
        intent.putExtra("scheduleId", scheduleId)
        val launch = mutableMapOf<String, Any>("scheduleId" to scheduleId)
        intent.sourceBounds?.let { bounds ->
            for ((key, value) in mapOf(
                "widgetLeft" to bounds.left,
                "widgetTop" to bounds.top,
                "widgetRight" to bounds.right,
                "widgetBottom" to bounds.bottom,
            )) {
                val logical = value.toDouble() / resources.displayMetrics.density
                intent.putExtra(key, logical)
                launch[key] = logical
            }
        }
        return launch
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        prepareLaunch(intent)
        settingsSnapshot = savedSettings()
        super.onCreate(savedInstanceState)
        // Flutter owns both the stationary scrim fade and the panel morph.
        if (Build.VERSION.SDK_INT >= 34) {
            overrideActivityTransition(OVERRIDE_TRANSITION_OPEN, 0, 0)
            overrideActivityTransition(OVERRIDE_TRANSITION_CLOSE, 0, 0)
        } else {
            @Suppress("DEPRECATION")
            overridePendingTransition(0, 0)
        }
    }

    override fun onEnterAnimationComplete() {
        super.onEnterAnimationComplete()
        entryComplete = true
        entryWaiters.toList().forEach { it.success(null) }
        entryWaiters.clear()
    }

    override fun onStop() {
        entryComplete = false
        super.onStop()
    }

    override fun onDestroy() {
        entryWaiters.toList().forEach {
            it.error("window_closed", "Widget window closed before entry completed", null)
        }
        entryWaiters.clear()
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        val launch = prepareLaunch(intent)
        setIntent(intent)
        super.onNewIntent(intent)
        // Another activity may have changed language, theme, or reminder
        // preferences while this Flutter isolate was stopped. Reboot that
        // isolate only then; ordinary repeated taps keep the fast path.
        if (settingsSnapshot != savedSettings()) {
            recreate()
            return
        }
        windowChannel?.invokeMethod("open", launch)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        windowChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.shenepoy.janan/widget_window",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    // Launchers can override cross-task animations. Keep the
                    // Flutter host transparent until that system motion ends.
                    "waitForEntry" -> {
                        if (entryComplete) result.success(null)
                        else entryWaiters.add(result)
                    }
                    "dismiss" -> {
                        // Retain this stopped task for the next tap. Android is
                        // free to reclaim it; no service or wake lock is held.
                        settingsSnapshot = savedSettings()
                        moveTaskToBack(true)
                        @Suppress("DEPRECATION")
                        overridePendingTransition(0, 0)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
}
