package com.shenepoy.janan

import android.Manifest
import android.app.LocaleManager
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.LocaleList
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec

class MainActivity: FlutterFragmentActivity() {
    private var hideStatusBarForCompactLandscape = false

    override fun onCreate(savedInstanceState: Bundle?) {
        // Android retains the task's original intent after process death. A
        // restored reminder is no longer a new tap: let Flutter boot normally.
        // This must run before super attaches receive_intent / notifications.
        val restoringReminder = savedInstanceState != null &&
            (intent.getStringExtra("route") == "/medications/today" ||
                intent.action == "SELECT_NOTIFICATION" ||
                intent.action == "SELECT_FOREGROUND_NOTIFICATION_ACTION")
        if (restoringReminder) {
            intent = Intent(this, MainActivity::class.java)
                .setAction(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_LAUNCHER)
        }
        // FlutterFragment also saves the widget's initial route in its arguments.
        // Recreate it so that route cannot override the app's normal startup.
        super.onCreate(if (restoringReminder) null else savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes = window.attributes.apply {
                layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
    }

    companion object {
        private const val CHANNEL =
            "com.shenepoy.janan/bluetooth_foreground_service"
        private const val NOTIFICATION_PERMISSION_REQUEST = 4101
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        // Serial across alarm changes and widget drawing. Permission dialogs
        // still run on main through the notification handler's dispatcher.
        val reminderQueue = messenger.makeBackgroundTaskQueue()
        val notifications = flutterEngine.plugins.get(FlutterLocalNotificationsPlugin::class.java)
            as? FlutterLocalNotificationsPlugin
        if (notifications != null) {
            val mainHandler = Handler(Looper.getMainLooper())
            MethodChannel(
                messenger,
                "dexterous.com/flutter/local_notifications",
                StandardMethodCodec.INSTANCE,
                reminderQueue,
            ).setMethodCallHandler(
                ReminderNotificationHandler(notifications) { action ->
                    mainHandler.post { action() }
                },
            )
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val text = call.argument<String>("text")
                        ?: "Scanning for Bluetooth devices"
                    try {
                        BluetoothScanForegroundService.start(this, text)
                        requestNotificationPermissionIfNeeded()
                        result.success(null)
                    } catch (_: RuntimeException) {
                        result.error("FOREGROUND_SERVICE_UNAVAILABLE", null, null)
                    }
                }
                "update" -> {
                    val text = call.argument<String>("text")
                        ?: "Scanning for Bluetooth devices"
                    try {
                        BluetoothScanForegroundService.update(this, text)
                        result.success(null)
                    } catch (_: RuntimeException) {
                        result.error("FOREGROUND_SERVICE_UNAVAILABLE", null, null)
                    }
                }
                "stop" -> {
                    try {
                        BluetoothScanForegroundService.stop(this)
                        result.success(null)
                    } catch (_: RuntimeException) {
                        result.error("FOREGROUND_SERVICE_UNAVAILABLE", null, null)
                    }
                }
                "finish" -> {
                    val text = call.argument<String>("text")
                    try {
                        BluetoothScanForegroundService.finish(this, text)
                        result.success(null)
                    } catch (_: RuntimeException) {
                        result.error("FOREGROUND_SERVICE_UNAVAILABLE", null, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.shenepoy.janan/system_ui",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setStatusBarVisible" -> {
                    val visible = call.argument<Boolean>("visible") ?: true
                    hideStatusBarForCompactLandscape = !visible
                    setStatusBarVisible(visible)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            messenger,
            "com.shenepoy.janan/medication_widget",
            StandardMethodCodec.INSTANCE,
            reminderQueue,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    val summary = call.argument<String>("summary") ?: "[]"
                    getSharedPreferences("medication_widget", MODE_PRIVATE)
                        .edit()
                        .putString("summary", summary)
                        .apply()
                    val manager = AppWidgetManager.getInstance(this)
                    val provider = ComponentName(this, MedicationHomeWidgetProvider::class.java)
                    val ids = manager.getAppWidgetIds(provider)
                    MedicationHomeWidgetProvider().onUpdate(this, manager, ids)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.shenepoy.janan/app_locale",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "set" -> {
                    val tag = call.argument<String>("tag").orEmpty()
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val locales = if (tag.isEmpty()) {
                            LocaleList.getEmptyLocaleList()
                        } else {
                            LocaleList.forLanguageTags(tag)
                        }
                        getSystemService(LocaleManager::class.java)
                            .applicationLocales = locales
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) return
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST,
        )
    }

    private fun setStatusBarVisible(visible: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val controller = window.insetsController ?: return
            controller.systemBarsBehavior =
                WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            if (visible) {
                controller.show(WindowInsets.Type.statusBars())
            } else {
                controller.hide(WindowInsets.Type.statusBars())
            }
            return
        }

        val decorView = window.decorView
        val statusBarFlags =
            View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        decorView.systemUiVisibility = if (visible) {
            decorView.systemUiVisibility and statusBarFlags.inv()
        } else {
            decorView.systemUiVisibility or statusBarFlags
        }
    }
}
