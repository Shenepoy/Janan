package com.shenepoy.janan

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class MedicationWidgetRefreshPlanTest {
    @Test
    fun laterWidgetDoesNotDelayAnEarlierDose() {
        val deadlines = mapOf(10 to 1_000L, 20 to 5_000L)
        assertEquals(1_000L, nextMedicationWidgetRefresh(intArrayOf(10, 20), deadlines::get))
        assertEquals(1_000L, nextMedicationWidgetRefresh(intArrayOf(20, 10), deadlines::get))
    }

    @Test
    fun widgetWithNoDoseDoesNotCancelAnotherWidgetsRefresh() {
        val deadlines = mapOf(10 to 1_000L, 20 to null)
        assertEquals(1_000L, nextMedicationWidgetRefresh(intArrayOf(10, 20), deadlines::get))
    }

    @Test
    fun partialUpdateStillConsidersAllInstalledWidgets() {
        val installedIds = intArrayOf(10, 20, 30)
        val consulted = mutableListOf<Int>()
        val deadlines = mapOf(10 to 4_000L, 20 to 1_000L, 30 to 3_000L)
        val next = nextMedicationWidgetRefresh(installedIds) { id ->
            consulted.add(id)
            deadlines[id]
        }
        assertEquals(installedIds.toList(), consulted)
        assertEquals(1_000L, next)
    }

    @Test
    fun noInstalledWidgetsOrNoPendingDosesClearsTheAlarm() {
        assertNull(nextMedicationWidgetRefresh(intArrayOf()) { error("No widget to read") })
        assertNull(nextMedicationWidgetRefresh(intArrayOf(10, 20)) { null })
    }
}
