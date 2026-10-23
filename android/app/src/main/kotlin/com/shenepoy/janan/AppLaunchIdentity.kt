package com.shenepoy.janan

/** Extras do not participate in PendingIntent identity; actions and data do. */
internal data class AppLaunchIdentity(val action: String)

internal fun medicationWidgetLaunchIdentity(packageName: String, widgetId: Int) =
    AppLaunchIdentity("$packageName.OPEN_MEDICATION_WIDGET.$widgetId")

internal fun bluetoothStatusLaunchIdentity(packageName: String) =
    AppLaunchIdentity("$packageName.OPEN_BLUETOOTH_STATUS")

internal fun bluetoothResultLaunchIdentity(packageName: String) =
    AppLaunchIdentity("$packageName.OPEN_BLUETOOTH_RESULT")
