package com.shenepoy.janan

/** Formats remaining time or explicitly signed elapsed time after a dose. */
internal fun medicationWidgetCountdownText(
    deltaMillis: Long,
    overdue: Boolean,
    nowLabel: String,
    hourUnit: String,
    minuteUnit: String,
): String {
    if (deltaMillis <= 0L) return nowLabel
    val minutes = if (overdue) {
        (deltaMillis / 60_000L).coerceAtLeast(1L)
    } else {
        (deltaMillis + 59_999L) / 60_000L
    }
    val value = if (minutes >= 60L) {
        val hours = if (overdue) minutes / 60L else (minutes + 59L) / 60L
        "$hours$hourUnit"
    } else {
        "$minutes$minuteUnit"
    }
    return if (overdue) "+$value" else value
}
