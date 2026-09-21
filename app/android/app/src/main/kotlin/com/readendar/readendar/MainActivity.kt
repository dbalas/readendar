package com.readendar.readendar

import android.appwidget.AppWidgetManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * Hosts a small method channel so the Dart "Open with Readendar" flow can read a
 * supported library CSV delivered as a `content://` URI. The intent-filter hands
 * the app a content URI (not a readable `file://` path), which Dart's `File`
 * can't open — so we read it here via the ContentResolver. Size is capped to
 * mirror the Dart-side limit and avoid OOM on a hostile file.
 *
 * Also hosts the widget pin channel: the `home_widget` plugin's
 * `requestPinWidget` doesn't pass a successCallback to
 * `AppWidgetManager.requestPinAppWidget`, so it can't tell the Dart side
 * whether the user actually completed the system's pin dialog (see
 * WidgetPinReceiver). We call the platform API directly here instead, wiring
 * our own successCallback PendingIntent.
 */
class MainActivity : FlutterActivity() {
    private val contentChannelName = "readendar/content"
    private val widgetPinChannelName = "readendar/widget_pin"
    private val notificationSettingsChannelName = "readendar/notification_settings"
    private val speechChannelName = "readendar/speech"
    private val maxBytes = 10 * 1024 * 1024
    private val sharePendingQuoteKey = "share.pendingQuoteText"
    private val homeWidgetPrefs = "HomeWidgetPreferences"

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        remapShareIntent(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        remapShareIntent(intent)
        super.onNewIntent(intent)
        setIntent(intent)
    }

    /**
     * Android share-sheet parity for the iOS Share Extension: stage shared
     * text into HomeWidgetPreferences, then rewrite the intent as
     * `readendar://share/quote`.
     */
    private fun remapShareIntent(intent: Intent?) {
        if (intent == null) return
        if (intent.action != Intent.ACTION_SEND) return
        val type = (intent.type ?: "").lowercase()
        val text = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim().orEmpty()
        if (text.isEmpty()) return
        if (!type.startsWith("text/") && !looksLikeHttpUrl(text)) return
        stageQuoteAndRewrite(intent, text)
    }

    private fun stageQuoteAndRewrite(intent: Intent, text: String) {
        getSharedPreferences(homeWidgetPrefs, MODE_PRIVATE)
            .edit()
            .putString(sharePendingQuoteKey, text)
            .commit()
        rewriteAsView(intent, "readendar://share/quote")
        intent.removeExtra(Intent.EXTRA_TEXT)
        intent.removeExtra(Intent.EXTRA_SUBJECT)
    }

    private fun rewriteAsView(intent: Intent, uri: String) {
        intent.action = Intent.ACTION_VIEW
        intent.data = Uri.parse(uri)
        intent.type = null
    }

    private fun looksLikeHttpUrl(text: String): Boolean {
        val t = text.lowercase()
        return t.startsWith("http://") || t.startsWith("https://")
    }


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, contentChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "readContentUri" -> {
                        val uriString = call.argument<String>("uri")
                        if (uriString == null) {
                            result.success(null)
                        } else {
                            try {
                                result.success(readUri(Uri.parse(uriString)))
                            } catch (e: Exception) {
                                result.success(null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, widgetPinChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPinWidget" -> {
                        // "events" (default) or "quotes" — pins the matching provider.
                        val provider = call.argument<String>("provider") ?: "events"
                        result.success(requestPinWidget(provider))
                    }
                    "saveQuotesWidgetConfig" -> {
                        // In-app edit of an existing quotes widget instance: persist
                        // its per-appWidgetId config + re-render it immediately.
                        result.success(
                            saveQuotesWidgetConfig(
                                call.argument<Int>("appWidgetId"),
                                call.argument<String>("config"),
                            ),
                        )
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationSettingsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openBatteryOptimizationSettings" ->
                        result.success(openBatteryOptimizationSettings())
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, speechChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isOnDeviceRecognitionAvailable" -> result.success(
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                            SpeechRecognizer.isOnDeviceRecognitionAvailable(applicationContext),
                    )
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "readendar/play_app_update")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "check" -> PlayAppUpdate.check(this, result)
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Returns true if the system's pin dialog was shown; false if unsupported.
     * [providerKey] selects which widget to pin: "quotes" → the quotes provider,
     * anything else → the events provider.
     */
    private fun requestPinWidget(providerKey: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
        if (!appWidgetManager.isRequestPinAppWidgetSupported) return false
        return try {
            val providerClass = when (providerKey) {
                "quotes" -> ReadendarQuotesWidgetProvider::class.java
                "progress" -> ReadendarProgressWidgetProvider::class.java
                else -> ReadendarWidgetProvider::class.java
            }
            val provider = ComponentName(this, providerClass)
            val requestCode = when (providerKey) {
                "quotes" -> 2
                "progress" -> 1
                else -> 0
            }
            // Mutable: the OS fills EXTRA_APPWIDGET_ID on the success
            // callback. IMMUTABLE makes ColorOS/API 31+ throw or silently
            // skip the callback, so Dart never sees a completed pin.
            val pinFlags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_MUTABLE
                } else {
                    0
                }
            val successCallback = PendingIntent.getBroadcast(
                this,
                requestCode,
                Intent(this, WidgetPinReceiver::class.java)
                    .setAction(WidgetPinReceiver.ACTION_WIDGET_PINNED),
                pinFlags,
            )
            appWidgetManager.requestPinAppWidget(provider, Bundle(), successCallback)
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Persists [configJson] for the quotes widget instance [appWidgetId] and
     * re-renders it so the change shows immediately. Returns false on a missing
     * id or unparseable config.
     */
    private fun saveQuotesWidgetConfig(appWidgetId: Int?, configJson: String?): Boolean {
        if (appWidgetId == null || appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return false
        val config = QuotesWidgetConfig.fromPendingJson(configJson) ?: return false
        QuotesWidgetPrefs.save(applicationContext, appWidgetId, config)
        // renderWithCoverRefresh (not renderQuoteWidget): this runs on the main
        // thread, where the cover resolver returns null; the async second pass
        // fetches the cover so the coverGradient background / thumbnail appear
        // immediately instead of after the next WorkManager tick.
        ReadendarQuotesWidgetProvider.renderWithCoverRefresh(
            applicationContext,
            AppWidgetManager.getInstance(applicationContext),
            appWidgetId,
            QuotesStore.cached(applicationContext),
        )
        return true
    }

    /**
     * Opens the standard Android battery-optimization allowlist. We avoid
     * REQUEST_IGNORE_BATTERY_OPTIMIZATIONS and its direct exemption prompt:
     * Readendar already uses exact AlarmManager alarms, while this screen gives
     * users on aggressive OEM firmware (notably ColorOS) a policy-safe path to
     * relax the vendor restriction themselves.
     */
    private fun openBatteryOptimizationSettings(): Boolean {
        val intents = listOf(
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName"),
            ),
        )
        for (intent in intents) {
            try {
                startActivity(intent)
                return true
            } catch (_: Exception) {
                // Try the generic app details fallback below.
            }
        }
        return false
    }

    /** Reads up to [maxBytes] of a content URI; returns null if missing or too big. */
    private fun readUri(uri: Uri): ByteArray? {
        contentResolver.openInputStream(uri)?.use { input ->
            val buffer = ByteArrayOutputStream()
            val chunk = ByteArray(8192)
            var total = 0
            while (true) {
                val n = input.read(chunk)
                if (n < 0) break
                total += n
                if (total > maxBytes) return null
                buffer.write(chunk, 0, n)
            }
            return buffer.toByteArray()
        }
        return null
    }
}
