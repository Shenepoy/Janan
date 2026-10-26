package com.shenepoy.janan

import org.junit.Assert.assertEquals
import org.junit.Test

class MedicationWidgetRingsTest {
    private fun ring(name: String, at: Long, dueUntil: Long) = WidgetRing(
        at = at,
        dotted = false,
        colors = intArrayOf(0x123456),
        times = longArrayOf(at),
        intervals = longArrayOf(86_400_000L),
        status = "pending",
        dueUntils = longArrayOf(dueUntil),
        names = arrayOf(name),
    )

    @Test
    fun oneReminderShowsOneRingDespiteFutureOccurrences() {
        val rings = listOf(ring("Medicine", 2_000, 3_000), ring("Medicine", 4_000, 5_000))
        assertEquals(listOf(2_000L), selectMedicationWidgetRings(rings, 1_000).map { it.at })
    }

    @Test
    fun followingOccurrencePromotesAfterCurrentDueWindowEnds() {
        val rings = listOf(ring("Medicine", 2_000, 3_000), ring("Medicine", 4_000, 5_000))
        assertEquals(listOf(4_000L), selectMedicationWidgetRings(rings, 3_000).map { it.at })
    }

    @Test
    fun distinctMedicinesKeepTheirRings() {
        val rings = listOf(ring("First", 2_000, 3_000), ring("Second", 4_000, 5_000))
        assertEquals(2, selectMedicationWidgetRings(rings, 1_000).size)
    }

    @Test
    fun differentMedicinesWithTheSameNameKeepTheirRings() {
        val first = ring("Medicine", 2_000, 3_000).copy(medicineKeys = arrayOf("id-1"))
        val second = ring("Medicine", 4_000, 5_000).copy(medicineKeys = arrayOf("id-2"))
        assertEquals(2, selectMedicationWidgetRings(listOf(first, second), 1_000).size)
    }

    @Test
    fun nextOnlyHidesQueuedMedicinesUntilPromotion() {
        val rings = listOf(ring("First", 2_000, 3_000), ring("Second", 4_000, 5_000))
        assertEquals(listOf(2_000L), selectMedicationWidgetRings(rings, 1_000, false).map { it.at })
        assertEquals(listOf(4_000L), selectMedicationWidgetRings(rings, 3_000, false).map { it.at })
    }

    @Test
    fun sharedRingDropsRepeatedMedicineAndKeepsOtherMedicine() {
        val first = ring("First", 2_000, 3_000)
        val shared = WidgetRing(
            at = 4_000,
            dotted = true,
            colors = intArrayOf(1, 2),
            times = longArrayOf(4_000, 4_000),
            intervals = longArrayOf(86_400_000, 86_400_000),
            status = "pending",
            dueUntils = longArrayOf(5_000, 5_000),
            names = arrayOf("First", "Second"),
        )
        val shown = selectMedicationWidgetRings(listOf(first, shared), 1_000)
        assertEquals(2, shown.size)
        assertEquals(listOf("Second"), shown.last().names.toList())
        assertEquals(false, shown.last().dotted)
    }
}
