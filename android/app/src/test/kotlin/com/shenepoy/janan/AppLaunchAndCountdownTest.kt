package com.shenepoy.janan

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class AppLaunchAndCountdownTest {
    @Test
    fun overlappingRequestCodesStillHaveDistinctActivityIdentities() {
        val app = "com.shenepoy.janan"
        val widget = medicationWidgetLaunchIdentity(app, 1)
        val result = bluetoothResultLaunchIdentity(app)
        val status = bluetoothStatusLaunchIdentity(app)
        assertNotEquals(widget.action, result.action)
        assertNotEquals(widget.action, status.action)
        assertNotEquals(result.action, status.action)
        assertNotEquals(widget.action, medicationWidgetLaunchIdentity(app, 2).action)
    }

    @Test
    fun countdownDistinguishesRemainingAndOverdueMinutesAndHours() {
        fun text(delta: Long, overdue: Boolean) =
            medicationWidgetCountdownText(delta, overdue, "Now", "h", "m")
        assertEquals("5m", text(5 * 60_000L, false))
        assertEquals("+5m", text(5 * 60_000L, true))
        assertEquals("2h", text(61 * 60_000L, false))
        assertEquals("+1h", text(61 * 60_000L, true))
        assertEquals("Now", text(0L, true))
    }
}
