package com.shenepoy.janan

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

internal object MedicationWidgetStore {
    private const val PREFS = "medication_widget"
    private const val SUMMARY = "summary"

    data class Choice(val id: String, val name: String)

    fun scheduleId(context: Context, widgetId: Int): String =
        preferences(context).getString(widgetKey(widgetId), "") ?: ""

    fun saveScheduleId(context: Context, widgetId: Int, scheduleId: String) {
        preferences(context).edit().putString(widgetKey(widgetId), scheduleId).apply()
    }

    fun clearScheduleId(context: Context, widgetId: Int) {
        preferences(context).edit().remove(widgetKey(widgetId)).apply()
    }

    fun choices(context: Context): List<Choice> {
        val all = Choice("", context.getString(R.string.medication_widget_shows_all))
        val raw = rawSummary(context).trim()
        if (!raw.startsWith("{")) return listOf(all)
        return try {
            val encoded = JSONObject(raw).optJSONArray("choices") ?: return listOf(all)
            val parsed = buildList {
                for (index in 0 until encoded.length()) {
                    val item = encoded.optJSONObject(index) ?: continue
                    val name = item.optString("name").trim().ifEmpty { all.name }
                    add(Choice(item.optString("id"), name))
                }
            }
            if (parsed.isEmpty()) listOf(all) else parsed
        } catch (_: Exception) {
            listOf(all)
        }
    }

    fun viewFor(context: Context, widgetId: Int): JSONObject? {
        val raw = rawSummary(context).trim()
        if (raw.isEmpty()) return null
        return try {
            if (raw.startsWith("[")) {
                JSONArray(raw).optJSONObject(0)
            } else {
                val views = JSONObject(raw).optJSONObject("views") ?: return null
                val selected = scheduleId(context, widgetId)
                views.optJSONObject(selected) ?: views.optJSONObject("")
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun rawSummary(context: Context): String =
        preferences(context).getString(SUMMARY, "") ?: ""

    private fun preferences(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun widgetKey(widgetId: Int) = "widget_$widgetId"
}
