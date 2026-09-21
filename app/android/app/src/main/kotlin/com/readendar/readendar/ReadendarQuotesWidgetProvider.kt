// Readendar QUOTES home-screen widget (Android).
//
// Second widget, independent from the events widget: renders ONE saved quote
// (serif-italic passage + book footer + favorite star) from the shared
// wdg_quotes_cache snapshot (pushed by the app after every quote mutation).
//
// PER-INSTANCE configuration (ReadendarQuotesConfigActivity, launched by the
// OS on add and on reconfigure): mode (fixed quote / rotate all / rotate
// favorites / rotate one book) + rotation cadence (hourly / six-hourly /
// daily). Stored in QuotesWidgetPrefs keyed by appWidgetId.
//
// Rotation is DETERMINISTIC and stateless: candidates keep the snapshot's
// stable newest-first order and the shown index is `timeBucket % count`,
// where the bucket is the local epoch hour / 6-hour block / day. Every render
// inside a bucket shows the same quote on every code path (system update,
// WorkManager tick, app push), and the same formula drives the iOS timeline
// and the in-app preview/daily notification, so all surfaces agree.

package com.readendar.readendar

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import android.net.Uri
import android.os.Bundle
import android.text.SpannableString
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.view.View
import android.widget.RemoteViews
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequest
import androidx.work.Worker
import androidx.work.WorkerParameters
import androidx.work.WorkManager
import org.json.JSONObject
import java.util.TimeZone
import java.util.concurrent.TimeUnit

class ReadendarQuotesWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        // A one-tap system pin (requestPinAppWidget) does NOT launch the
        // configure activity, so a freshly-pinned instance would otherwise keep
        // default prefs. Adopt the app-chosen pending config here — this fires
        // for every new instance regardless of how it was added. (On the picker
        // path the config activity already consumed + cleared it, so this no-ops.)
        QuotesWidgetPrefs.applyPendingConfigToNewInstances(context, ids)
        // Render the cached snapshot immediately, then refresh off the main
        // thread. Parse the cache once, not once per widget instance.
        val cached = QuotesStore.cached(context)
        for (id in ids) renderQuoteWidget(context, mgr, id, cached)
        val pending = goAsync()
        Thread {
            try {
                val payload = try {
                    QuotesPayload.parse(WidgetApi.loadQuotesJson(context))
                } catch (e: Exception) {
                    QuotesStore.cached(context)
                }
                for (id in ids) renderQuoteWidget(context, mgr, id, payload)
            } finally {
                pending.finish()
            }
        }.start()
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        mgr: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, mgr, appWidgetId, newOptions)
        renderQuoteWidget(context, mgr, appWidgetId, QuotesStore.cached(context))
    }

    override fun onEnabled(context: Context) {
        // 15 minutes is WorkManager's floor; rotation granularity comes from the
        // bucket formula at render time, not from wakeup frequency.
        val request = PeriodicWorkRequest.Builder(ReadendarQuotesWidgetWorker::class.java, 15, TimeUnit.MINUTES).build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            WORK_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            request,
        )
    }

    override fun onDisabled(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        // Per-instance config is keyed by appWidgetId — drop it with the widget.
        for (id in appWidgetIds) QuotesWidgetPrefs.clear(context, id)
    }

    companion object {
        internal const val WORK_NAME = "readendar_quotes_widget_refresh"

        /** Shared refresh entry point (onUpdate thread + the Worker). */
        internal fun refreshAndRenderAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, ReadendarQuotesWidgetProvider::class.java))
            if (ids.isEmpty()) return
            val payload = try {
                QuotesPayload.parse(WidgetApi.loadQuotesJson(context))
            } catch (e: Exception) {
                QuotesStore.cached(context)
            }
            for (id in ids) renderQuoteWidget(context, mgr, id, payload)
        }

        /** Renders all instances from the current cache (config activity save). */
        internal fun renderAllFromCache(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, ReadendarQuotesWidgetProvider::class.java))
            val cached = QuotesStore.cached(context)
            for (id in ids) renderQuoteWidget(context, mgr, id, cached)
        }

        internal fun renderQuoteWidget(
            context: Context,
            mgr: AppWidgetManager,
            appWidgetId: Int,
            payload: QuotesPayload,
        ) {
            val dark = WTheme.isDark(context)
            val config = QuotesWidgetPrefs.config(context, appWidgetId)
            // Appearance: "auto" follows the theme, every other style is a fixed
            // brand palette matching the share card (see QuotesStyle).
            val pal = QuotesStyle.palette(context, dark, config.style)
            val views = RemoteViews(context.packageName, R.layout.readendar_quotes_widget)

            // Wordmark: "READ" tinted + "ENDAR" muted, from the palette (matches
            // the events widget's brand mark; single view, uniform spacing).
            views.setTextColor(R.id.qwdg_brand, pal.endar)
            views.setTextViewText(R.id.qwdg_brand, brandWordmark(pal.read))
            views.setTextColor(R.id.qwdg_text, pal.text)
            views.setTextColor(R.id.qwdg_book_title, pal.text)
            views.setTextColor(R.id.qwdg_book_meta, pal.meta)
            views.setTextColor(R.id.qwdg_note, pal.meta)
            views.setTextColor(R.id.qwdg_empty, pal.meta)
            views.setTextColor(R.id.qwdg_star, pal.star)

            val quote = QuotesRotation.pick(
                payload.quotes,
                config,
                System.currentTimeMillis(),
                TimeZone.getDefault(),
            )
            val scheme = WidgetStore.scheme(context)

            // Resolve the cover bitmap once — it feeds both the footer thumbnail
            // and, for the cover style, the blurred background.
            val cover = if (quote != null && quote.bookCoverUrl.isNotBlank()) {
                CoverDiskCache.read(context, quote.bookCoverUrl)?.let { BitmapFactory.decodeByteArray(it, 0, it.size) }
                    ?: if (android.os.Looper.getMainLooper() != android.os.Looper.myLooper()) {
                        ReadendarWidgetProvider.fetchCoverBitmap(context, quote.bookCoverUrl)
                    } else null
            } else null

            // Background: solid colour / gradient drawable / blurred cover + scrim.
            applyBackground(views, pal, cover)

            if (quote == null) {
                views.setViewVisibility(R.id.qwdg_body, View.GONE)
                views.setViewVisibility(R.id.qwdg_empty, View.VISIBLE)
                views.setTextViewText(R.id.qwdg_empty, QuoteStrings.get(context, "empty"))
                // No quotes to configure yet — tap adds the first quote.
                views.setOnClickPendingIntent(R.id.qwdg_root, deepLink(context, "$scheme://quote/new"))
            } else {
                views.setViewVisibility(R.id.qwdg_body, View.VISIBLE)
                views.setViewVisibility(R.id.qwdg_empty, View.GONE)
                views.setTextViewText(R.id.qwdg_text, "«${quote.text}»")
                views.setTextViewText(R.id.qwdg_book_title, quote.bookTitle)
                val meta = buildList {
                    if (quote.bookAuthor.isNotBlank()) add(quote.bookAuthor)
                    quote.page?.let { add(QuoteStrings.get(context, "page").format(it)) }
                }.joinToString(" · ")
                views.setTextViewText(R.id.qwdg_book_meta, meta)
                views.setViewVisibility(R.id.qwdg_star, if (quote.favorite) View.VISIBLE else View.GONE)

                // Private note: shown only when this instance's config opts in
                // and the quote actually has one.
                if (config.showNote && quote.note.isNotBlank()) {
                    views.setTextViewText(R.id.qwdg_note, quote.note.trim())
                    views.setViewVisibility(R.id.qwdg_note, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.qwdg_note, View.GONE)
                }

                if (cover != null) {
                    views.setImageViewBitmap(R.id.qwdg_cover, cover)
                    views.setViewVisibility(R.id.qwdg_cover, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.qwdg_cover, View.GONE)
                }

                // Tap the widget → open the app on THIS instance's config editor
                // (carries the appWidgetId + current config so a save can target
                // and re-render exactly this instance).
                views.setOnClickPendingIntent(
                    R.id.qwdg_root,
                    deepLink(context, configDeepLink(scheme, appWidgetId, config)),
                )
            }
            mgr.updateAppWidget(appWidgetId, views)
        }

        /** Applies the style's background: solid colour, a corner-to-corner brand
         *  gradient, or (cover style) a cheaply-blurred cover under a scrim.
         *  Every render sets exactly one background + toggles the two overlay
         *  layers, so switching styles never leaves a stale layer showing. */
        private fun applyBackground(views: RemoteViews, pal: QPalette, cover: Bitmap?) {
            when {
                pal.rootResource != null -> {
                    views.setViewVisibility(R.id.qwdg_bg, View.GONE)
                    views.setViewVisibility(R.id.qwdg_scrim, View.GONE)
                    views.setViewVisibility(R.id.qwdg_gradient, View.GONE)
                    views.setInt(R.id.qwdg_root, "setBackgroundResource", pal.rootResource)
                }
                pal.cover -> {
                    views.setViewVisibility(R.id.qwdg_gradient, View.GONE)
                    // Solid fill under the image so a missing cover still reads.
                    views.setInt(R.id.qwdg_root, "setBackgroundColor", pal.bg)
                    if (cover != null) {
                        views.setImageViewBitmap(R.id.qwdg_bg, cheapBlur(cover))
                        views.setViewVisibility(R.id.qwdg_bg, View.VISIBLE)
                        views.setViewVisibility(R.id.qwdg_scrim, View.VISIBLE)
                    } else {
                        views.setViewVisibility(R.id.qwdg_bg, View.GONE)
                        views.setViewVisibility(R.id.qwdg_scrim, View.GONE)
                    }
                }
                pal.gradient != null -> {
                    views.setViewVisibility(R.id.qwdg_bg, View.GONE)
                    views.setViewVisibility(R.id.qwdg_scrim, View.GONE)
                    // A code-rendered bitmap on a fitXY ImageView: the diagonal
                    // stretches to the widget rect, so the gradient runs true
                    // corner-to-corner at ANY aspect ratio — matching the Flutter
                    // (topLeft→bottomRight) and iOS (.topLeading→.bottomTrailing)
                    // gradients, which a fixed-angle GradientDrawable can't.
                    views.setImageViewBitmap(R.id.qwdg_gradient, gradientBitmap(pal.gradient))
                    views.setViewVisibility(R.id.qwdg_gradient, View.VISIBLE)
                    views.setInt(R.id.qwdg_root, "setBackgroundColor", pal.gradient[0])
                }
                else -> {
                    views.setViewVisibility(R.id.qwdg_bg, View.GONE)
                    views.setViewVisibility(R.id.qwdg_scrim, View.GONE)
                    views.setViewVisibility(R.id.qwdg_gradient, View.GONE)
                    views.setInt(R.id.qwdg_root, "setBackgroundColor", pal.bg)
                }
            }
        }

        /** A square linear gradient (top-left→bottom-right) stretched to the
         *  widget by the fitXY ImageView. */
        private fun gradientBitmap(colors: IntArray): Bitmap {
            val size = 200
            val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val paint = Paint().apply {
                shader = LinearGradient(
                    0f, 0f, size.toFloat(), size.toFloat(),
                    colors, null, Shader.TileMode.CLAMP,
                )
            }
            Canvas(bmp).drawRect(0f, 0f, size.toFloat(), size.toFloat(), paint)
            return bmp
        }

        /** A cheap blur with no deprecated RenderScript: downscale hard, then let
         *  the ImageView (centerCrop) upscale it back — soft enough behind a
         *  scrim. */
        private fun cheapBlur(src: Bitmap): Bitmap {
            val w = 36
            val h = (src.height.toFloat() / src.width.coerceAtLeast(1) * w).toInt().coerceAtLeast(1)
            return Bitmap.createScaledBitmap(src, w, h, true)
        }

        /** Renders immediately from [payload], then re-renders OFF the main
         *  thread so the cover resolver (main-thread-guarded, see renderQuoteWidget)
         *  can fetch the blurred cover + footer thumbnail. Used by the in-app save
         *  paths (config activity, tap-to-edit channel), which run on the main
         *  thread and would otherwise show the flat fallback until the next
         *  WorkManager tick. */
        internal fun renderWithCoverRefresh(
            context: Context,
            mgr: AppWidgetManager,
            appWidgetId: Int,
            payload: QuotesPayload,
        ) {
            renderQuoteWidget(context, mgr, appWidgetId, payload)
            Thread { renderQuoteWidget(context, mgr, appWidgetId, payload) }.start()
        }

        /** readendar://widget-quotes-config?wid=..&mode=..&cadence=..[&quoteId/bookId]. */
        private fun configDeepLink(scheme: String, appWidgetId: Int, config: QuotesWidgetConfig): String {
            val b = Uri.Builder()
                .scheme(scheme)
                .authority("widget-quotes-config")
                .appendQueryParameter("wid", appWidgetId.toString())
                .appendQueryParameter("mode", config.mode)
                .appendQueryParameter("cadence", config.cadence)
                .appendQueryParameter("style", config.style)
                .appendQueryParameter("showNote", config.showNote.toString())
            config.quoteId?.let { b.appendQueryParameter("quoteId", it) }
            config.bookId?.let { b.appendQueryParameter("bookId", it) }
            return b.build().toString()
        }

        /** "READENDAR" with the "READ" prefix tinted [readColor] (the rest keeps
         *  the qwdg_brand text colour set from the palette). Matches events. */
        private fun brandWordmark(readColor: Int): SpannableString {
            val s = SpannableString("READENDAR")
            s.setSpan(ForegroundColorSpan(readColor), 0, 4, Spanned.SPAN_INCLUSIVE_EXCLUSIVE)
            return s
        }

        private fun deepLink(context: Context, uri: String): PendingIntent {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uri)).setPackage(context.packageName)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            return PendingIntent.getActivity(context, uri.hashCode(), intent, flags)
        }
    }
}

/** Supplements updatePeriodMillis so bucket boundaries land within ~15 min. */
class ReadendarQuotesWidgetWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        ReadendarQuotesWidgetProvider.refreshAndRenderAll(applicationContext)
        return Result.success()
    }
}

// --- per-instance configuration (mode + source + cadence) ---

data class QuotesWidgetConfig(
    val mode: String, // "fixed" | "all" | "favorites" | "book"
    val quoteId: String?,
    val bookId: String?,
    val cadence: String, // "1h" | "6h" | "daily"
    // Appearance: "auto" (follow app theme) or a fixed brand palette matching
    // the share card — "lightElegant"|"minimal"|"dark"|"coverGradient"|
    // "gradientSunset"|"gradientForest"|"gradientOcean"|"gradientDusk"|
    // "parchment"|"mist"|"pine"|"honey"|"noirGold"
    // (mirrors QuoteWidgetStyle / QuoteCardStyle in Dart).
    val style: String = "auto",
    // When true, a shown quote's private note is rendered. Off by default
    // (mirrors the share-time opt-in).
    val showNote: Boolean = false,
) {
    companion object {
        /** Parses the app-pushed pending-config JSON (wdg_quotes_pending_config,
         *  written by the in-app config screen). Null when absent/blank. */
        const val PENDING_KEY = "wdg_quotes_pending_config"

        fun fromPendingJson(json: String?): QuotesWidgetConfig? {
            if (json.isNullOrBlank()) return null
            return runCatching {
                val o = JSONObject(json)
                QuotesWidgetConfig(
                    mode = normalizeMode(o.optString("mode", "all").ifBlank { "all" }),
                    quoteId = if (o.has("quoteId") && !o.isNull("quoteId")) o.optString("quoteId") else null,
                    bookId = if (o.has("bookId") && !o.isNull("bookId")) o.optString("bookId") else null,
                    cadence = o.optString("cadence", "daily").ifBlank { "daily" },
                    style = o.optString("style", "auto").ifBlank { "auto" },
                    showNote = o.optBoolean("showNote", false),
                )
            }.getOrNull()
        }

        fun normalizeMode(mode: String): String =
            if (mode == "pinned") "favorites" else mode
    }
}

object QuotesWidgetPrefs {
    private const val PREFS = "QuotesWidgetPrefs"
    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun normalizeMode(mode: String): String = QuotesWidgetConfig.normalizeMode(mode)

    fun config(context: Context, appWidgetId: Int): QuotesWidgetConfig {
        val stored = prefs(context).getString("qw_mode_$appWidgetId", "all") ?: "all"
        val mode = normalizeMode(stored)
        if (stored == "pinned") {
            prefs(context).edit().putString("qw_mode_$appWidgetId", mode).apply()
        }
        return QuotesWidgetConfig(
            mode = mode,
            quoteId = prefs(context).getString("qw_quote_$appWidgetId", null),
            bookId = prefs(context).getString("qw_book_$appWidgetId", null),
            cadence = prefs(context).getString("qw_cadence_$appWidgetId", "daily") ?: "daily",
            style = prefs(context).getString("qw_style_$appWidgetId", "auto") ?: "auto",
            showNote = prefs(context).getBoolean("qw_shownote_$appWidgetId", false),
        )
    }

    fun save(context: Context, appWidgetId: Int, config: QuotesWidgetConfig) {
        prefs(context).edit()
            .putString("qw_mode_$appWidgetId", QuotesWidgetConfig.normalizeMode(config.mode))
            .putString("qw_quote_$appWidgetId", config.quoteId)
            .putString("qw_book_$appWidgetId", config.bookId)
            .putString("qw_cadence_$appWidgetId", config.cadence)
            .putString("qw_style_$appWidgetId", config.style)
            .putBoolean("qw_shownote_$appWidgetId", config.showNote)
            .apply()
    }

    fun clear(context: Context, appWidgetId: Int) {
        prefs(context).edit()
            .remove("qw_mode_$appWidgetId")
            .remove("qw_quote_$appWidgetId")
            .remove("qw_book_$appWidgetId")
            .remove("qw_cadence_$appWidgetId")
            .remove("qw_style_$appWidgetId")
            .remove("qw_shownote_$appWidgetId")
            .apply()
    }

    /**
     * Applies the app-chosen pending config (wdg_quotes_pending_config) to any of
     * [ids] that has no saved config yet, then clears it. This is how a widget
     * added via the one-tap system pin adopts the mode/cadence/style the user
     * picked in-app: `requestPinAppWidget` does NOT launch the configure activity
     * (only the picker/drag add does), so onUpdate is the one hook that always
     * fires for a fresh instance. An already-configured instance (prefs present)
     * is left untouched, so a periodic update / reconfigure never re-applies a
     * stale pending config.
     */
    fun applyPendingConfigToNewInstances(context: Context, ids: IntArray) {
        val pending = QuotesWidgetConfig.fromPendingJson(
            WidgetStore.get(context, QuotesWidgetConfig.PENDING_KEY),
        ) ?: return
        val prefs = prefs(context)
        var consumed = false
        for (id in ids) {
            // "qw_mode_$id" absent ⇒ never configured ⇒ a freshly-added instance.
            if (!prefs.contains("qw_mode_$id")) {
                save(context, id, pending)
                consumed = true
            }
        }
        if (consumed) WidgetStore.remove(context, QuotesWidgetConfig.PENDING_KEY)
    }
}

// --- model (wdg_quotes_cache contract — see widget_models.dart) ---

data class WQuote(
    val id: String,
    val text: String,
    val page: Int?,
    val favorite: Boolean,
    // The owner's private note; rendered only when the instance's config opts in.
    val note: String,
    val bookId: String,
    val bookTitle: String,
    val bookAuthor: String,
    val bookCoverUrl: String,
)

data class QuotesPayload(val quotes: List<WQuote>) {
    companion object {
        val EMPTY = QuotesPayload(emptyList())
        fun parse(json: String?): QuotesPayload {
            if (json.isNullOrBlank()) return EMPTY
            return runCatching {
                val obj = JSONObject(json)
                val arr = obj.optJSONArray("annotations") ?: obj.optJSONArray("quotes") ?: return EMPTY
                QuotesPayload((0 until arr.length()).mapNotNull { i ->
                    val it = arr.getJSONObject(i)
                    val category = it.optString("category")
                    if (category.isNotEmpty() && category != "quote") return@mapNotNull null
                    WQuote(
                        it.optString("id"),
                        run {
                            val body = it.optString("body")
                            if (body.isNotEmpty()) body else it.optString("text")
                        },
                        if (it.isNull("page")) null else it.optInt("page"),
                        if (it.has("favorite") && !it.isNull("favorite")) {
                            it.optBoolean("favorite")
                        } else {
                            false
                        },
                        run {
                            val commentary = it.optString("commentary")
                            if (commentary.isNotEmpty()) commentary else it.optString("note")
                        },
                        it.optString("bookId"),
                        it.optString("bookTitle"),
                        it.optString("bookAuthor"),
                        it.optString("bookCoverUrl"),
                    )
                })
            }.getOrDefault(EMPTY)
        }
    }
}

object QuotesStore {
    fun cached(context: Context): QuotesPayload =
        QuotesPayload.parse(WidgetStore.get(context, "wdg_quotes_cache"))
}

// --- deterministic rotation (same bucket formula as iOS + the app preview) ---

object QuotesRotation {
    /**
     * The quote an instance shows right now: its mode filters the candidates
     * (snapshot order is stable newest-first), then `bucket % count` picks —
     * every render inside a time bucket agrees, no persisted rotation state.
     */
    fun pick(quotes: List<WQuote>, config: QuotesWidgetConfig, nowMillis: Long, zone: TimeZone): WQuote? {
        if (quotes.isEmpty()) return null
        if (config.mode == "fixed") {
            return quotes.firstOrNull { it.id == config.quoteId } ?: quotes.first()
        }
        val candidates = when (config.mode) {
            "favorites" -> quotes.filter { it.favorite }
            "book" -> quotes.filter { it.bookId == config.bookId }
            else -> quotes
        }.ifEmpty { quotes }
        // floorMod (not %): guarantees a non-negative index even if a
        // misconfigured device clock ever makes the bucket negative — Kotlin's
        // % keeps the dividend's sign and would throw IndexOutOfBounds.
        val idx = Math.floorMod(bucket(config.cadence, nowMillis, zone), candidates.size.toLong()).toInt()
        return candidates[idx]
    }

    /** Local-time bucket: epoch hour / 6-hour block / day. */
    fun bucket(cadence: String, nowMillis: Long, zone: TimeZone): Long {
        val local = nowMillis + zone.getOffset(nowMillis)
        return when (cadence) {
            "1h" -> local / 3_600_000L
            "6h" -> local / 21_600_000L
            else -> local / 86_400_000L // daily
        }
    }
}

// --- appearance palette (mirrors Dart paletteFor + QuoteWidgetStyle) ---

/** Resolved colours for one style. [gradient] non-null = a top-left→bottom-right
 *  gradient with those stops ([bg] is the fallback fill); [cover] true =
 *  blurred-cover background ([bg] is the fallback fill). */
class QPalette(
    val bg: Int,
    val gradient: IntArray?,
    val cover: Boolean,
    val text: Int,
    val meta: Int,
    val read: Int,
    val endar: Int,
    val star: Int,
    val rootResource: Int? = null,
)

object QuotesStyle {
    private fun c(hex: String) = Color.parseColor(hex)

    /**
     * The palette for a [style] wire string. "auto" follows the widget theme
     * (WTheme); every other value is a FIXED brand palette identical in light and
     * dark — the same set the share card offers (QuoteCardStyle in Dart), so the
     * widget and the shared image read as the same styles.
     */
    fun palette(context: Context, dark: Boolean, style: String): QPalette {
        val star = c("#DD9D2B")
        val white = c("#FFFFFF")
        val paper200 = c("#EFEFEC")
        fun gradient(startHex: String, endHex: String, meta: Int = paper200) = QPalette(
            c(startHex), intArrayOf(c(startHex), c(endHex)), false, white, meta, white, meta, star,
        )
        return when (style) {
            "lightElegant" -> QPalette(c("#F7F7F5"), null, false, c("#0F1014"), c("#525250"), c("#5A5FBC"), c("#1F1F1F"), star)
            "minimal" -> QPalette(c("#FFFFFF"), null, false, c("#0F1014"), c("#7A7A74"), c("#5A5FBC"), c("#1F1F1F"), star)
            "dark" -> QPalette(c("#0F1014"), null, false, c("#F7F7F5"), c("#A3A39C"), c("#8E94D3"), c("#E5E5E0"), star)
            "coverGradient" -> QPalette(c("#1B1E48"), null, true, white, c("#E5E5E0"), white, paper200, star)
            "gradientSunset" -> gradient("#B23F45", "#E0A03A")
            "gradientForest" -> gradient("#2A8F7D", "#5B924C")
            "gradientOcean" -> gradient("#7479D6", "#2A8F7D")
            "gradientDusk" -> gradient("#7479D6", "#B23F45")
            "parchment" -> QPalette(c("#FAF5EF"), null, false, c("#0F1014"), c("#5E5E5B"), c("#8F2F35"), c("#2A2A2A"), star)
            "mist" -> QPalette(c("#E2E4F4"), null, false, c("#161617"), c("#44489A"), c("#44489A"), c("#2A2A2A"), star)
            "pine" -> QPalette(c("#103D35"), null, false, white, c("#97D6C8"), white, c("#C9E9E0"), star)
            "honey" -> QPalette(c("#F7E2B5"), null, false, c("#0F1014"), c("#644111"), c("#644111"), c("#1F1F1F"), star)
            "noirGold" -> QPalette(c("#28090B"), null, false, c("#F7F7F5"), c("#C9C9C2"), star, c("#E5E5E0"), star)
            else -> { // "auto" (and any unknown value) → theme-adaptive.
                val cols = WTheme.colors(context, dark)
                QPalette(
                    cols.bg,
                    null,
                    false,
                    cols.primary,
                    cols.secondary,
                    cols.accent,
                    cols.secondary,
                    star,
                    WTheme.resources(context, dark).root,
                )
            }
        }
    }
}

// --- localized strings (inline table keyed by wdg_locale, like Strings) ---

object QuoteStrings {
    private val tables = mapOf(
        "es" to mapOf("empty" to "Añade tu primera cita", "page" to "p. %d"),
    )

    fun get(context: Context, key: String): String {
        val locale = WidgetStore.get(context, "wdg_locale")?.take(2) ?: "es"
        return tables[locale]?.get(key) ?: tables["es"]!![key] ?: key
    }
}
