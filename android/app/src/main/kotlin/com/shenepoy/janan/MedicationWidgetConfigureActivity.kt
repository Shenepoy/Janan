package com.shenepoy.janan

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.ScrollView
import android.widget.TextView

class MedicationWidgetConfigureActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)
        val widgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        val choices = MedicationWidgetStore.choices(this)
        val current = MedicationWidgetStore.scheduleId(this, widgetId)
        var selected = choices.firstOrNull { it.id == current }?.id ?: ""

        val density = resources.displayMetrics.density
        fun dp(value: Int) = (value * density).toInt()

        val group = RadioGroup(this).apply {
            orientation = RadioGroup.VERTICAL
        }
        for (choice in choices) {
            group.addView(
                RadioButton(this).apply {
                    text = choice.name
                    tag = choice.id
                    id = View.generateViewId()
                    isChecked = choice.id == selected
                    textSize = 16f
                    setPadding(dp(8), dp(12), dp(8), dp(12))
                },
            )
        }
        group.setOnCheckedChangeListener { radioGroup, checkedId ->
            selected = radioGroup.findViewById<RadioButton>(checkedId)?.tag as? String ?: ""
        }

        val done = Button(this).apply {
            text = getString(R.string.medication_widget_configure_done)
            setOnClickListener {
                MedicationWidgetStore.saveScheduleId(
                    this@MedicationWidgetConfigureActivity,
                    widgetId,
                    selected,
                )
                val manager = AppWidgetManager.getInstance(this@MedicationWidgetConfigureActivity)
                MedicationHomeWidgetProvider().onUpdate(
                    this@MedicationWidgetConfigureActivity,
                    manager,
                    intArrayOf(widgetId),
                )
                setResult(
                    RESULT_OK,
                    Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId),
                )
                finish()
            }
        }

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(24), dp(20), dp(20))
            addView(
                TextView(context).apply {
                    text = getString(R.string.medication_widget_configure_title)
                    textSize = 22f
                    setPadding(0, 0, 0, dp(8))
                },
            )
            addView(
                TextView(context).apply {
                    text = getString(R.string.medication_widget_configure_prompt)
                    textSize = 16f
                    setPadding(0, 0, 0, dp(8))
                },
            )
            addView(group)
            addView(
                done,
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ).apply { topMargin = dp(12) },
            )
        }
        setContentView(
            ScrollView(this).apply {
                fitsSystemWindows = true
                addView(content)
            },
        )
    }
}
