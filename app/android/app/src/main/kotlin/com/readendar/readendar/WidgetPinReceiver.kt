// Receives the system's pin-success broadcast for the "one-tap add widget"
// flow (see MainActivity's readendar/widget_pin channel). AppWidgetManager
// fires this only when the user actually confirms the launcher's pin dialog —
// unlike the request call itself, this is a genuine completion signal. Writes
// a flag into the shared_preferences-compatible store so the Dart side can
// show a "widget added" confirmation the next time it resumes.
package com.readendar.readendar

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class WidgetPinReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit()
            .putBoolean(FLAG_KEY, true)
            .apply()
    }

    companion object {
        const val ACTION_WIDGET_PINNED = "com.readendar.readendar.ACTION_WIDGET_PINNED"
        const val FLAG_KEY = "flutter.wdg_pin_success"
    }
}
