package com.shenepoy.janan

/** Selects the shared alarm deadline from every installed widget's current view. */
internal fun nextMedicationWidgetRefresh(
    widgetIds: IntArray,
    deadlineFor: (Int) -> Long?,
): Long? = widgetIds.asSequence().mapNotNull(deadlineFor).minOrNull()
