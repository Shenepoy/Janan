package com.shenepoy.janan

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Called on the reminder worker queue; permission and Activity work stays on main. */
internal class ReminderNotificationHandler(
    private val notifications: MethodChannel.MethodCallHandler,
    private val onMainThread: (() -> Unit) -> Unit,
) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "zonedSchedule", "cancel", "cancelAll" -> notifications.onMethodCall(call, result)
            else -> onMainThread {
                try {
                    notifications.onMethodCall(call, result)
                } catch (error: RuntimeException) {
                    result.error("error", error.message, null)
                }
            }
        }
    }
}
