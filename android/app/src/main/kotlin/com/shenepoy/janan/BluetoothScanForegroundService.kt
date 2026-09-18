package com.shenepoy.janan

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Keeps the process hosting the Dart BLE scan important while the activity is
 * in the background and provides Android's required foreground notification.
 */
class BluetoothScanForegroundService : Service() {
    companion object {
        private const val CHANNEL_ID = "bluetooth_sync"
        private const val NOTIFICATION_ID = 4102
        private const val RESULT_NOTIFICATION_ID = 4103
        private const val ACTION_START = "com.shenepoy.janan.BLE_START"
        private const val EXTRA_TEXT = "text"
        private const val DEFAULT_TEXT = "Scanning for Bluetooth devices"

        @Volatile
        private var pendingText = DEFAULT_TEXT

        @Volatile
        private var stopRequested = false

        @Volatile
        private var foregroundStarted = false

        fun start(context: Context, text: String) {
            pendingText = text
            stopRequested = false
            val intent = Intent(context, BluetoothScanForegroundService::class.java)
                .setAction(ACTION_START)
                .putExtra(EXTRA_TEXT, text)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun update(context: Context, text: String) {
            pendingText = text
            if (!foregroundStarted) return
            try {
                createNotificationChannel(context)
                context.getSystemService(NotificationManager::class.java)
                    .notify(NOTIFICATION_ID, buildNotification(context, text))
            } catch (_: RuntimeException) {
                // Notification restrictions must not crash the sync process.
            }
        }

        fun stop(context: Context) {
            stopRequested = true
            if (foregroundStarted) {
                context.stopService(
                    Intent(context, BluetoothScanForegroundService::class.java),
                )
            }
        }

        fun finish(context: Context, text: String?) {
            stop(context)
            if (text.isNullOrBlank()) return
            try {
                createNotificationChannel(context)
                context.getSystemService(NotificationManager::class.java)
                    .notify(RESULT_NOTIFICATION_ID, buildResultNotification(context, text))
            } catch (_: RuntimeException) {
                // Notification restrictions must not crash the sync process.
            }
        }

        private fun createNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Bluetooth sync",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Keeps Bluetooth meter synchronization active"
                setShowBadge(false)
            }
            context.getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }

        private fun buildNotification(context: Context, text: String): Notification {
            val openApp = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            return Notification.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
                .setContentTitle("Janan")
                .setContentText(text)
                .setContentIntent(openApp)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setCategory(Notification.CATEGORY_SERVICE)
                .build()
        }

        private fun buildResultNotification(context: Context, text: String): Notification {
            val openApp = PendingIntent.getActivity(
                context,
                1,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            return Notification.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
                .setContentTitle("Janan")
                .setContentText(text)
                .setContentIntent(openApp)
                .setOngoing(false)
                .setAutoCancel(true)
                .setOnlyAlertOnce(true)
                .setCategory(Notification.CATEGORY_STATUS)
                .build()
        }
    }

    private var notificationText = DEFAULT_TEXT

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        notificationText = intent?.getStringExtra(EXTRA_TEXT) ?: pendingText
        try {
            showNotification()
            foregroundStarted = true
        } catch (_: RuntimeException) {
            foregroundStarted = false
            stopSelf(startId)
            return START_NOT_STICKY
        }
        if (stopRequested) {
            stopRequested = false
            stopSelf(startId)
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        foregroundStarted = false
        stopRequested = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        createNotificationChannel(this)
    }

    private fun showNotification() {
        val notification = buildNotification(this, notificationText)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }
}
