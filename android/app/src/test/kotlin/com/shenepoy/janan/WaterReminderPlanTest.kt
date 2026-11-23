package com.shenepoy.janan

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.ZoneId
import java.time.ZonedDateTime

class WaterReminderPlanTest {
    private val zone = ZoneId.of("Asia/Riyadh")
    private fun at(value: String, z: ZoneId = zone) = ZonedDateTime.parse(value + "[" + z.id + "]").toInstant().toEpochMilli()
    private val now = at("2026-11-14T12:00:00+03:00")

    @Test fun fixedTimesReturnNextAndRepeatTomorrow() {
        assertEquals(at("2026-11-14T13:00:00+03:00"), nextWaterReminder(now, listOf(540, 780, 1020), 0, 0, zone))
        assertEquals(at("2026-11-15T09:00:00+03:00"), nextWaterReminder(at("2026-11-14T18:00:00+03:00"), listOf(540, 780, 1020), 0, 0, zone))
    }
    @Test fun nearbyTimesMergeAndDoNotReplayAfterDelivery() {
        val drink = at("2026-11-14T12:55:00+03:00")
        val times = listOf(780, 810, 1020)
        val delayed = at("2026-11-14T13:55:00+03:00")
        assertEquals(delayed, nextWaterReminder(drink, times, drink, 60, zone))
        assertEquals(at("2026-11-14T17:00:00+03:00"), nextWaterReminder(delayed + 100, times, drink, 60, zone))
    }
    @Test fun undoRestoresUpcomingBaseTime() {
        val drink = at("2026-11-14T12:55:00+03:00")
        assertEquals(at("2026-11-14T13:00:00+03:00"), nextWaterReminder(drink, listOf(780), 0, 60, zone))
    }
    @Test fun remindersBeforeDrinkDoNotReturnAsNewReminders() {
        val drink = at("2026-11-14T13:05:00+03:00")
        assertEquals(at("2026-11-14T17:00:00+03:00"), nextWaterReminder(drink, listOf(780, 1020), drink, 60, zone))
    }
    @Test fun lateNightDrinkNeverIntroducesOvernightNotification() {
        val drink = at("2026-11-14T23:40:00+03:00")
        assertEquals(at("2026-11-15T09:00:00+03:00"), nextWaterReminder(drink, listOf(540, 1430), drink, 60, zone))
    }
    @Test fun historicalAndFutureEntriesDoNotMoveTodaysTimes() {
        for (drink in listOf(at("2026-11-13T12:55:00+03:00"), at("2026-11-14T12:55:00+03:00"))) {
            assertEquals(at("2026-11-14T13:00:00+03:00"), nextWaterReminder(now, listOf(780), drink, 60, zone))
        }
    }
    @Test fun tomorrowRetainsItsOriginalTimes() {
        val drink = at("2026-11-14T12:55:00+03:00")
        assertEquals(at("2026-11-15T13:00:00+03:00"), nextWaterReminder(at("2026-11-14T18:00:00+03:00"), listOf(780), drink, 60, zone))
    }
    @Test fun disabledAdjustmentAndInvalidTimes() {
        assertEquals(at("2026-11-14T13:00:00+03:00"), nextWaterReminder(now, listOf(-1, 780, 780, 1440), now, 0, zone))
        assertNull(nextWaterReminder(now, emptyList(), now, 60, zone))
    }
    @Test fun daylightSavingUsesCalendarDaysAndHandlesMissingHour() {
        val ny = ZoneId.of("America/New_York")
        val start = at("2026-03-08T01:50:00-05:00", ny)
        assertEquals(at("2026-03-08T03:30:00-04:00", ny), nextWaterReminder(start, listOf(150), 0, 0, ny))
        val after = at("2026-03-08T04:00:00-04:00", ny)
        assertEquals(at("2026-03-09T02:30:00-04:00", ny), nextWaterReminder(after, listOf(150), 0, 0, ny))
    }
    @Test fun drinkingInDeliveryMinuteDoesNotReviveTheDeliveredReminder() {
        val delivered = at("2026-11-14T13:00:00+03:00")
        assertEquals(at("2026-11-14T17:00:00+03:00"), nextWaterReminder(delivered + 10000,
            listOf(780, 1020), delivered, 60, zone, deliveredThroughMs = delivered))
    }
    @Test fun fallbackHourDoesNotDeliverTwice() {
        val ny = ZoneId.of("America/New_York")
        val after = at("2026-11-01T01:45:00-04:00", ny)
        assertEquals(at("2026-11-02T01:30:00-05:00", ny), nextWaterReminder(after, listOf(90), 0, 0, ny))
    }
}
