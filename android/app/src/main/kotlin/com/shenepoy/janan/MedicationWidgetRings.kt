package com.shenepoy.janan

internal data class WidgetRing(
    val at: Long,
    val dotted: Boolean,
    val colors: IntArray,
    val times: LongArray,
    val intervals: LongArray,
    val status: String,
    val dueUntils: LongArray = longArrayOf(),
    val names: Array<String> = emptyArray(),
    val medicineKeys: Array<String> = emptyArray(),
)

/** Retains future occurrences for promotion, but draws each medicine only once. */
internal fun selectMedicationWidgetRings(
    rings: List<WidgetRing>,
    now: Long,
    showAll: Boolean = true,
): List<WidgetRing> {
    val seen = mutableSetOf<String>()
    return rings.mapNotNull { ring ->
        val live = withoutExpired(ring, now) ?: return@mapNotNull null
        val keep = live.times.indices.filter { index ->
            val key = live.medicineKeys.valueAt(index).ifBlank {
                live.names.valueAt(index)
            }
            // Older snapshots have names but no stable medicine IDs.
            (key.isBlank() || seen.add(key)) && (showAll || seen.size <= 1)
        }
        live.retaining(keep)
    }.take(if (showAll) 2 else 1)
}

private fun withoutExpired(ring: WidgetRing, now: Long): WidgetRing? {
    if (ring.times.isEmpty()) {
        val due = ring.dueUntils.firstOrNull() ?: 0L
        val expired = ring.at > 0L && ring.at <= now && due > 0L && now >= due
        return if (expired) null else ring
    }
    val keep = ring.times.indices.filter { index ->
        val doseAt = ring.times[index]
        val due = ring.dueUntils.valueAt(index)
        !(doseAt > 0L && doseAt <= now && due > 0L && now >= due)
    }
    return ring.retaining(keep)
}

private fun WidgetRing.retaining(keep: List<Int>): WidgetRing? {
    if (keep.isEmpty()) return null
    if (keep.size == times.size) return this
    return copy(
        at = times[keep.first()],
        dotted = keep.size > 1,
        colors = IntArray(keep.size) { colors.valueAt(keep[it], DEFAULT_MEDICINE_COLOR) },
        times = LongArray(keep.size) { times[keep[it]] },
        intervals = LongArray(keep.size) { intervals.valueAt(keep[it], DAY_MILLIS) },
        dueUntils = LongArray(keep.size) { dueUntils.valueAt(keep[it]) },
        names = Array(keep.size) { names.valueAt(keep[it]) },
        medicineKeys = Array(keep.size) { medicineKeys.valueAt(keep[it]) },
    )
}

private fun LongArray.valueAt(index: Int, fallback: Long = 0L): Long =
    if (index in indices) this[index] else fallback

private fun IntArray.valueAt(index: Int, fallback: Int): Int =
    if (index in indices) this[index] else fallback

private fun Array<String>.valueAt(index: Int): String =
    if (index in indices) this[index] else ""

private const val DEFAULT_MEDICINE_COLOR = 0xff92dccf.toInt()
private const val DAY_MILLIS = 86_400_000L
