package com.shenepoy.janan

import java.time.Instant
import java.time.ZoneId

/** Today's adjustments never move reminders into a new day or alter tomorrow. */
internal fun nextWaterReminder(
    nowMs: Long,
    minutes: List<Int>,
    lastDrinkMs: Long,
    pauseMinutes: Int,
    zone: ZoneId = ZoneId.systemDefault(),
    deliveredThroughMs: Long = 0,
): Long? {
    val now = Instant.ofEpochMilli(nowMs).atZone(zone)
    val drink = Instant.ofEpochMilli(lastDrinkMs).atZone(zone)
    val canAdjust = lastDrinkMs > 0 && lastDrinkMs <= nowMs && pauseMinutes > 0
    val floor = drink.plusMinutes(pauseMinutes.toLong())
    return (0L..2L).flatMap { offset ->
        val day = now.toLocalDate().plusDays(offset)
        minutes.distinct().filter { it in 0..1439 }.mapNotNull { minute ->
            val base = day.atTime(minute / 60, minute % 60).atZone(zone)
            if (base.toInstant().toEpochMilli() <= deliveredThroughMs) return@mapNotNull null
            val target = if (canAdjust && day == drink.toLocalDate() &&
                !base.isBefore(drink) && base.isBefore(floor)) floor else base
            target.toInstant().toEpochMilli().takeIf {
                it > nowMs && target.toLocalDate() == day
            }
        }
    }.minOrNull()
}
