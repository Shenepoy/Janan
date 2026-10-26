package com.shenepoy.janan

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class ReminderNotificationHandlerTest {
    @Test
    fun alarmChangesStayOnWorkerAndReturnPluginResults() {
        val mainThread = Thread.currentThread()
        val calls = mutableListOf<String>()
        val result = RecordingResult()
        val handler = ReminderNotificationHandler(
            { call, reply ->
                assertFalse(Thread.currentThread() === mainThread)
                calls.add(call.method)
                reply.success(call.method)
            },
            { throw AssertionError("Alarm work must not be sent to main") },
        )
        val worker = Executors.newSingleThreadExecutor()
        try {
            for (method in listOf("cancelAll", "zonedSchedule", "cancel")) {
                worker.submit { handler.onMethodCall(MethodCall(method, null), result) }
                    .get(5, TimeUnit.SECONDS)
            }
            assertEquals(listOf("cancelAll", "zonedSchedule", "cancel"), calls)
            assertEquals(calls, result.successes)
        } finally {
            worker.shutdownNow()
        }
    }

    @Test
    fun activityAndPermissionCallsAreDispatchedToMain() {
        val mainThread = Thread.currentThread()
        val pending = mutableListOf<() -> Unit>()
        val result = RecordingResult()
        val handler = ReminderNotificationHandler(
            { call, reply ->
                assertTrue(Thread.currentThread() === mainThread)
                reply.success(call.method)
            },
            { pending.add(it) },
        )
        val worker = Executors.newSingleThreadExecutor()
        val methods = listOf(
            "initialize", "requestNotificationsPermission", "requestExactAlarmsPermission",
            "getNotificationAppLaunchDetails",
        )
        try {
            for (method in methods) {
                worker.submit { handler.onMethodCall(MethodCall(method, null), result) }
                    .get(5, TimeUnit.SECONDS)
            }
            assertTrue(result.successes.isEmpty())
            pending.forEach { it() }
            assertEquals(methods, result.successes)
        } finally {
            worker.shutdownNow()
        }
    }

    private class RecordingResult : MethodChannel.Result {
        val successes = mutableListOf<Any?>()
        override fun success(result: Any?) { successes.add(result) }
        override fun error(code: String, message: String?, details: Any?) {
            throw AssertionError("$code: $message")
        }
        override fun notImplemented() { throw AssertionError("Unimplemented") }
    }
}
