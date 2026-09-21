// Periodic background refresh for the Readendar home-screen widget.
//
// Supplements the AppWidgetProviderInfo's updatePeriodMillis (system-driven,
// not always honored promptly by OEM battery optimizers) and the reactive
// goAsync() self-fetch in ReadendarWidgetProvider.onUpdate. Enqueued as a
// unique periodic work request (15 min floor) from onEnabled/onDisabled.
//
// WidgetApi's calls are synchronous/blocking (plain HttpURLConnection, no
// suspend functions), matching the rest of this widget's networking style —
// so this is a plain Worker rather than a CoroutineWorker, doing its blocking
// work in doWork() (already invoked off the main thread by WorkManager).

package com.readendar.readendar

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters

class ReadendarWidgetWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        return try {
            ReadendarWidgetProvider.refreshAndRenderAll(applicationContext)
            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }
}
