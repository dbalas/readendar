package com.readendar.readendar

import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Play In-App Updates availability for the current install and track.
 * Failures (sideload, missing Play Store, API errors) report unavailable.
 * Replies at most once so a Dart timeout cannot race a second success.
 */
object PlayAppUpdate {
    fun check(activity: android.app.Activity, result: MethodChannel.Result) {
        val replied = AtomicBoolean(false)
        fun reply(available: Boolean, code: Int) {
            if (!replied.compareAndSet(false, true)) return
            try {
                result.success(
                    hashMapOf(
                        "available" to available,
                        "availableVersionCode" to code,
                    ),
                )
            } catch (_: Exception) {
                // Engine already dropped the reply (Dart timed out, isolate gone).
            }
        }
        if (activity.isFinishing || activity.isDestroyed) {
            reply(false, 0)
            return
        }
        try {
            val manager = AppUpdateManagerFactory.create(activity)
            manager.appUpdateInfo
                .addOnSuccessListener { info ->
                    if (activity.isFinishing || activity.isDestroyed) {
                        reply(false, 0)
                        return@addOnSuccessListener
                    }
                    reply(
                        info.updateAvailability() ==
                            UpdateAvailability.UPDATE_AVAILABLE,
                        info.availableVersionCode(),
                    )
                }
                .addOnFailureListener { reply(false, 0) }
        } catch (_: Exception) {
            reply(false, 0)
        }
    }
}
