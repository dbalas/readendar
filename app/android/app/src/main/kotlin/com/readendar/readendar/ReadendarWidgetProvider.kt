// Readendar home-screen widget (Android).
//
// Product data is local. The app writes `wdg_cached_summary`; this provider
// renders that cache. Taps enqueue `wdg_pending_ops` so the next app open
// applies them to SQLite. Deep links: readendar://book/{id},
// readendar://event/{id}.
//
// Two layouts:
//   - readendar_widget_medium: a "READENDAR" wordmark + a currently-reading
//     cover strip on top, then a SCROLLABLE list of upcoming events rendered as
//     app-style rows (cover + title/author + type icon/label + time). On API 31+
//     the list is a RemoteViews.RemoteCollectionItems parcel (no
//     notifyAppWidgetViewDataChanged). Pre-31 keeps WidgetListService.
//   - readendar_widget_small: for narrow cells, just the next event's day +
//     title (no room for the list).
// A WorkManager periodic job (ReadendarWidgetWorker) supplements the
// system-driven updatePeriodMillis + the reactive goAsync() self-fetch in
// onUpdate.

package com.readendar.readendar

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Looper
import android.text.SpannableString
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.text.style.StrikethroughSpan
import android.view.View
import android.widget.RemoteViews
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequest
import androidx.work.WorkManager
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.TimeUnit

class ReadendarWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        // Render the cached snapshot immediately, then refresh off the main thread.
        for (id in ids) renderForWidget(context, mgr, id, WidgetStore.cachedSummary(context), hadFetchError = false)
        val pending = goAsync()
        Thread {
            try {
                var fetchFailed = false
                val summary = try {
                    val result = WidgetApi.loadSummaryWithState(context)
                    fetchFailed = !result.hasUsableData
                    result.summary
                } catch (e: Exception) {
                    fetchFailed = true
                    WidgetStore.cachedSummary(context)
                }
                for (id in ids) renderForWidget(context, mgr, id, summary, hadFetchError = fetchFailed)
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
        // Re-render immediately with the cached snapshot so the resize feels
        // instant; a full self-fetch isn't needed just for a layout swap.
        renderForWidget(context, mgr, appWidgetId, WidgetStore.cachedSummary(context), hadFetchError = false)
    }

    override fun onEnabled(context: Context) {
        // First widget instance placed: start the periodic background refresh.
        // 15 minutes is WorkManager's floor for PeriodicWorkRequest.
        val request = PeriodicWorkRequest.Builder(ReadendarWidgetWorker::class.java, 15, TimeUnit.MINUTES).build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            WORK_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            request,
        )
    }

    override fun onDisabled(context: Context) {
        // Last widget instance removed: stop the periodic background refresh.
        WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        // No-op: there is one global cached-summary snapshot (wdg_cached_summary),
        // not per-widget-id state, so there's nothing to clean up per deleted id
        // today. Overridden explicitly (rather than relying on the default) so
        // future per-widget state doesn't get silently unhandled here.
    }

    companion object {
        internal const val WORK_NAME = "readendar_widget_refresh"

        /** Width (dp) below which the small layout is used instead of medium. */
        private const val SMALL_WIDTH_THRESHOLD_DP = 180

        /** Max reading-book covers shown in the medium header strip. */
        private const val MAX_STRIP_COVERS = 4

        /** Shared refresh entry point: used by onUpdate, onAppWidgetOptionsChanged and the Worker. */
        internal fun refreshAndRenderAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, ReadendarWidgetProvider::class.java))
            if (ids.isEmpty()) return
            var fetchFailed = false
            val summary = try {
                val result = WidgetApi.loadSummaryWithState(context)
                fetchFailed = !result.hasUsableData
                result.summary
            } catch (e: Exception) {
                fetchFailed = true
                WidgetStore.cachedSummary(context)
            }
            for (id in ids) renderForWidget(context, mgr, id, summary, hadFetchError = fetchFailed)
        }

        /** Re-render all widgets from the current cached snapshot (no network). */
        internal fun renderCachedAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, ReadendarWidgetProvider::class.java))
            if (ids.isEmpty()) return
            val s = WidgetStore.cachedSummary(context)
            for (id in ids) renderForWidget(context, mgr, id, s, hadFetchError = false)
        }

        /** Picks the layout for this widget instance's current size and renders it. */
        internal fun renderForWidget(
            context: Context,
            mgr: AppWidgetManager,
            id: Int,
            s: Summary,
            hadFetchError: Boolean,
        ) {
            val options = mgr.getAppWidgetOptions(id)
            val minWidthDp = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, Int.MAX_VALUE) ?: Int.MAX_VALUE
            if (minWidthDp in 0 until SMALL_WIDTH_THRESHOLD_DP) {
                mgr.updateAppWidget(id, renderSmall(context, s, hadFetchError))
            } else {
                renderMedium(context, mgr, id, s, hadFetchError)
            }
        }

        // --- medium: wordmark + reading strip + scrollable event list ---

        private fun renderMedium(
            context: Context,
            mgr: AppWidgetManager,
            id: Int,
            s: Summary,
            hadFetchError: Boolean,
        ) {
            val dark = WTheme.isDark(context)
            val c = WTheme.colors(context, dark)
            val themeResources = WTheme.resources(context, dark)
            val views = RemoteViews(context.packageName, R.layout.readendar_widget_medium)
            views.setInt(R.id.wdg_root, "setBackgroundResource", themeResources.root)
            // Wordmark: one view (uniform letter-spacing), "READ" tinted accent
            // via a span, "ENDAR" left at the muted base color.
            views.setTextColor(R.id.wdg_brand, c.secondary)
            views.setTextViewText(R.id.wdg_brand, brandWordmark(context, dark))

            val isError = hadFetchError && s.events.isEmpty() && s.readingBooks.isEmpty()
            views.setTextViewText(R.id.wdg_empty_text, Strings.get(context, if (isError) "fetch_error" else "empty_events"))
            views.setTextColor(R.id.wdg_empty_text, c.secondary)
            views.setImageViewResource(R.id.wdg_empty_icon, if (isError) R.drawable.wdg_ic_fetch_error else R.drawable.wdg_ic_empty_events)
            views.setInt(R.id.wdg_empty_icon, "setColorFilter", c.secondary)

            // "Open calendar to see more" footer, only when the summary was capped.
            if (s.hasMore) {
                views.setViewVisibility(R.id.wdg_more, View.VISIBLE)
                views.setTextViewText(R.id.wdg_more, Strings.get(context, "see_more"))
                views.setTextColor(R.id.wdg_more, WTheme.accent(context, dark))
                views.setOnClickPendingIntent(R.id.wdg_more, deepLink(context, "calendar"))
            } else {
                views.setViewVisibility(R.id.wdg_more, View.GONE)
            }

            // Reading-book cover strip (up to MAX_STRIP_COVERS). Only shown with
            // 2+ books — a single book alone in the header is just noise. Covers
            // are fetched off the main thread only (the instant cached render
            // runs on the main thread and would otherwise hit
            // NetworkOnMainThread → null).
            val stripIds = intArrayOf(R.id.wdg_book_0, R.id.wdg_book_1, R.id.wdg_book_2, R.id.wdg_book_3)
            val books = if (s.readingBooks.size > 1) s.readingBooks.take(MAX_STRIP_COVERS) else emptyList()
            for (i in stripIds.indices) {
                val b = books.getOrNull(i)
                val bmp = b?.coverUrl?.takeIf { it.isNotBlank() }?.let { offMainCover(context, it) }
                if (b != null && bmp != null) {
                    views.setImageViewBitmap(stripIds[i], bmp)
                    views.setViewVisibility(stripIds[i], View.VISIBLE)
                    views.setOnClickPendingIntent(stripIds[i], deepLink(context, "book/${b.id}"))
                } else {
                    views.setViewVisibility(stripIds[i], View.GONE)
                }
            }

            views.setEmptyView(R.id.wdg_event_list, R.id.wdg_empty)
            views.setPendingIntentTemplate(R.id.wdg_event_list, actionTemplate(context))

            // API 31+: embed the collection in the RemoteViews parcel and skip
            // notifyAppWidgetViewDataChanged. The Intent-adapter + notify path is
            // deprecated (API 35) and NPEs on Android 15/16 when the platform's
            // async conversion calls replaceRemoteCollections on a null
            // getAppWidgetViews() result mid-update.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val coverCache = HashMap<String, Bitmap?>()
                val items = RemoteViews.RemoteCollectionItems.Builder()
                    .setHasStableIds(false)
                    .setViewTypeCount(1)
                for ((i, e) in s.events.withIndex()) {
                    items.addItem(
                        i.toLong(),
                        buildEventRow(context, e) { url ->
                            coverCache.getOrPut(url) { offMainCover(context, url) }
                        },
                    )
                }
                views.setRemoteAdapter(R.id.wdg_event_list, items.build())
                mgr.updateAppWidget(id, views)
            } else {
                // Pre-31: unique service intent per widget id so instances don't
                // share a cached adapter. Factory reads the cached summary.
                val serviceIntent = Intent(context, WidgetListService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                    data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }
                views.setRemoteAdapter(R.id.wdg_event_list, serviceIntent)
                mgr.updateAppWidget(id, views)
                mgr.notifyAppWidgetViewDataChanged(id, R.id.wdg_event_list)
            }
        }

        // --- small: single next event (or reading book) ---

        private fun renderSmall(context: Context, s: Summary, hadFetchError: Boolean): RemoteViews {
            val dark = WTheme.isDark(context)
            val c = WTheme.colors(context, dark)
            val themeResources = WTheme.resources(context, dark)
            val views = RemoteViews(context.packageName, R.layout.readendar_widget_small)
            views.setInt(R.id.wdg_root, "setBackgroundResource", themeResources.root)
            views.setTextColor(R.id.wdg_brand, c.secondary)

            val next = s.events.firstOrNull()
            if (next != null) {
                val typeColor = WTheme.eventColor(next.type, dark)
                val hasBookTitle = !next.bookTitle.isNullOrBlank()
                val label = next.title?.takeIf { it.isNotBlank() } ?: Strings.typeLabel(context, next.type)
                views.setTextViewText(R.id.wdg_event_day, Strings.relativeDay(context, next.dateLocal))
                views.setTextColor(R.id.wdg_event_day, typeColor)
                views.setTextViewText(R.id.wdg_event_title, if (hasBookTitle) next.bookTitle else label)
                views.setTextColor(R.id.wdg_event_title, c.primary)
                views.setOnClickPendingIntent(R.id.wdg_root, deepLink(context, "event/${next.id}"))
            } else {
                val b = s.readingBooks.firstOrNull()
                val emptyText = if (b == null && hadFetchError) {
                    Strings.get(context, "fetch_error")
                } else {
                    Strings.get(context, "empty")
                }
                views.setTextViewText(R.id.wdg_event_day, Strings.get(context, "reading"))
                views.setTextColor(R.id.wdg_event_day, WTheme.accent(context, dark))
                views.setTextViewText(R.id.wdg_event_title, b?.title ?: emptyText)
                views.setTextColor(R.id.wdg_event_title, c.primary)
                val uri = b?.let { "book/${it.id}" } ?: "home"
                views.setOnClickPendingIntent(R.id.wdg_root, deepLink(context, uri))
            }
            return views
        }

        /** "READENDAR" with the "READ" prefix tinted in the accent color. */
        internal fun brandWordmark(context: Context, dark: Boolean): SpannableString {
            val s = SpannableString("READENDAR")
            s.setSpan(ForegroundColorSpan(WTheme.accent(context, dark)), 0, 4, Spanned.SPAN_INCLUSIVE_EXCLUSIVE)
            return s
        }

        /**
         * Cover bitmap for a render pass. Off the main thread it self-fetches
         * (persisting to [CoverDiskCache]); on the main thread it may not touch
         * the network (NetworkOnMainThread), but it still returns the
         * last-known-good bytes from disk instead of null. Without that disk
         * fallback, any main-thread re-render — the optimistic repaint after a
         * row toggle (renderCachedAll) or a resize (onAppWidgetOptionsChanged) —
         * would blank every reading-strip cover, making the books appear to
         * vanish until the next background refresh repainted them.
         */
        private fun localCoverBitmap(url: String): Bitmap? {
            val path = when {
                url.startsWith("file:") -> Uri.parse(url).path
                url.startsWith("/") -> url
                else -> null
            } ?: return null
            val file = File(path)
            if (!file.isFile) return null
            return BitmapFactory.decodeFile(file.path)
        }

        internal fun offMainCover(context: Context, url: String): Bitmap? =
            if (Looper.myLooper() == Looper.getMainLooper()) diskCover(context, url) else fetchCoverBitmap(context, url)

        /** Last-known-good cover from disk (no network; safe on any thread). */
        private fun diskCover(context: Context, url: String): Bitmap? {
            localCoverBitmap(url)?.let { return it }
            val bytes = CoverDiskCache.read(context, url) ?: return null
            return BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        }

        /**
         * Fetches a cover over the network, persisting the bytes to
         * [CoverDiskCache] on success. On any network failure, falls back to the
         * last successfully-fetched bytes on disk instead of returning null —
         * without this, a transient failure during a periodic background
         * refresh (Doze, a TLS blip, etc.) would make a cover that was already
         * showing fine disappear from the widget.
         */
        internal fun fetchCoverBitmap(context: Context, url: String): Bitmap? {
            localCoverBitmap(url)?.let { return it }
            var c: HttpURLConnection? = null
            val fresh = try {
                c = (URL(url).openConnection() as HttpURLConnection).apply {
                    connectTimeout = 5000
                    readTimeout = 5000
                }
                if (c.responseCode != 200) null else c.inputStream.readBytes()
            } catch (e: Exception) {
                null
            } finally {
                c?.disconnect()
            }
            if (fresh != null) {
                CoverDiskCache.write(context, url, fresh)
                return BitmapFactory.decodeByteArray(fresh, 0, fresh.size)
            }
            val stale = CoverDiskCache.read(context, url) ?: return null
            return BitmapFactory.decodeByteArray(stale, 0, stale.size)
        }

        /** Concrete per-element deep link (reading strip covers, small widget). */
        private fun deepLink(context: Context, path: String): PendingIntent {
            val scheme = WidgetStore.scheme(context)
            val uri = "$scheme://$path"
            // SINGLE_TOP + CLEAR_TOP so the tap reuses the already-running app
            // task (launchMode=singleTop → onNewIntent) instead of spawning a
            // second instance. NEW_TASK is implicit from the launcher context.
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uri)).setPackage(context.packageName)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            return PendingIntent.getActivity(context, uri.hashCode(), intent, flags)
        }

        /**
         * Template for the event list. A collection has a SINGLE template, but
         * rows need two behaviours (open the detail vs toggle completion), so it
         * targets [WidgetActionReceiver] as a broadcast and each row's fill-in
         * intent carries an rdwidget:// action URI the receiver dispatches on.
         * Must be MUTABLE on API 31+ so the fill-in can set the data.
         */
        internal fun actionTemplate(context: Context): PendingIntent {
            val intent = Intent(context, WidgetActionReceiver::class.java).setAction(WidgetActionReceiver.ACTION)
            val mutable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
            return PendingIntent.getBroadcast(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or mutable)
        }

        /**
         * One app-style event row for the medium widget's scrollable list.
         * Shared by the API 31+ [RemoteViews.RemoteCollectionItems] path and the
         * pre-31 [WidgetListFactory] binder path. [cover] is injected so each
         * caller can keep its own URL→bitmap cache for the render pass.
         */
        internal fun buildEventRow(
            context: Context,
            e: Event,
            cover: (String) -> Bitmap?,
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.readendar_widget_event_row)
            val dark = WTheme.isDark(context)
            val c = WTheme.colors(context, dark)
            val themeResources = WTheme.resources(context, dark)
            val typeColor = WTheme.eventColor(e.type, dark)

            // Background sits on the inner card so its rounded top/bottom border is
            // never clipped by the ListView item bounds.
            views.setInt(R.id.wdg_row_card, "setBackgroundResource", themeResources.surface)

            val hasBook = !e.bookTitle.isNullOrBlank()
            val eventLabel = Strings.typeLabel(context, e.type)

            // Complete/uncomplete toggle: a tinted check-circle, filled+success when
            // done. Completable types only (start/finish/abandoned aren't). The
            // fill-in intent queues wdg_pending_ops for the next app open.
            val completable = e.type !in setOf("start", "finish", "abandoned")
            if (completable) {
                views.setViewVisibility(R.id.wdg_row_check, View.VISIBLE)
                if (e.isCompleted) {
                    views.setImageViewResource(R.id.wdg_row_check, R.drawable.wdg_ic_check_filled)
                    views.setInt(R.id.wdg_row_check, "setColorFilter", WTheme.success(dark))
                } else {
                    views.setImageViewResource(R.id.wdg_row_check, R.drawable.wdg_ic_check_circle)
                    views.setInt(R.id.wdg_row_check, "setColorFilter", c.secondary)
                }
                views.setOnClickFillInIntent(
                    R.id.wdg_row_check,
                    Intent().apply { data = Uri.parse("rdwidget://toggle?id=${e.id}&done=${if (e.isCompleted) 1 else 0}") },
                )
            } else {
                views.setViewVisibility(R.id.wdg_row_check, View.GONE)
            }

            // Line 1: the book title (else the event's own title / type label when
            // the book can't be resolved). Completed rows are struck-through + dimmed.
            val leftTitle = if (hasBook) e.bookTitle!! else (e.title?.takeIf { it.isNotBlank() } ?: eventLabel)
            views.setTextViewText(R.id.wdg_row_title, if (e.isCompleted) strike(leftTitle) else leftTitle)
            views.setTextColor(R.id.wdg_row_title, if (e.isCompleted) c.secondary else c.primary)

            // Line 2: the event's own progress/milestone (e.g. "Página 143"), else
            // the author. Guarded against ever repeating line 1 (when the book
            // wasn't resolved, line 1 IS the milestone title, so line 2 stays empty).
            val milestone = e.title?.takeIf { it.isNotBlank() && it != leftTitle && it != eventLabel }
            val secondary = milestone ?: e.bookAuthor?.takeIf { hasBook && it.isNotBlank() }
            if (secondary != null) {
                views.setTextViewText(R.id.wdg_row_author, secondary)
                views.setTextColor(R.id.wdg_row_author, c.secondary)
                views.setViewVisibility(R.id.wdg_row_author, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.wdg_row_author, View.GONE)
            }

            // Cover: artwork, else a periwinkle initial chip, else (no book) hidden.
            val bmp = if (hasBook) e.bookCoverUrl?.takeIf { it.isNotBlank() }?.let { cover(it) } else null
            when {
                bmp != null -> {
                    views.setViewVisibility(R.id.wdg_row_cover_wrap, View.VISIBLE)
                    views.setImageViewBitmap(R.id.wdg_row_cover, bmp)
                    views.setViewVisibility(R.id.wdg_row_cover, View.VISIBLE)
                    views.setViewVisibility(R.id.wdg_row_cover_fallback, View.GONE)
                }
                hasBook -> {
                    views.setViewVisibility(R.id.wdg_row_cover_wrap, View.VISIBLE)
                    views.setViewVisibility(R.id.wdg_row_cover, View.GONE)
                    views.setTextViewText(R.id.wdg_row_cover_fallback, e.bookTitle!!.take(1).uppercase())
                    views.setViewVisibility(R.id.wdg_row_cover_fallback, View.VISIBLE)
                }
                else -> views.setViewVisibility(R.id.wdg_row_cover_wrap, View.GONE)
            }

            // Event type: tinted icon + label + time/relative-day subtitle.
            views.setImageViewResource(R.id.wdg_row_type_icon, WTheme.iconRes(e.type))
            views.setInt(R.id.wdg_row_type_icon, "setColorFilter", typeColor)
            views.setTextViewText(R.id.wdg_row_type_label, eventLabel)
            views.setTextColor(R.id.wdg_row_type_label, c.primary)
            val sub = listOfNotNull(Strings.relativeDay(context, e.dateLocal), e.timeLocal).joinToString(" · ")
            views.setTextViewText(R.id.wdg_row_sub, sub)
            views.setTextColor(R.id.wdg_row_sub, typeColor)

            // Row tap: open the event detail. Routed through WidgetActionReceiver
            // (same template as the check toggle — a collection has ONE template).
            views.setOnClickFillInIntent(
                R.id.wdg_row_card,
                Intent().apply { data = Uri.parse("rdwidget://open?id=${e.id}") },
            )
            return views
        }

        private fun strike(s: String): CharSequence =
            SpannableString(s).apply { setSpan(StrikethroughSpan(), 0, s.length, Spanned.SPAN_INCLUSIVE_EXCLUSIVE) }
    }
}

// --- shared storage (home_widget SharedPreferences) ---

object WidgetStore {
    private const val PREFS = "HomeWidgetPreferences"
    fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    fun get(context: Context, key: String): String? = prefs(context).getString(key, null)
    fun put(context: Context, key: String, value: String) = prefs(context).edit().putString(key, value).apply()
    fun remove(context: Context, key: String) = prefs(context).edit().remove(key).apply()
    fun scheme(context: Context): String = get(context, "wdg_scheme")?.takeIf { it.isNotBlank() } ?: "readendar"
    fun cachedSummary(context: Context): Summary =
        get(context, "wdg_cached_summary")?.let { runCatching { Summary.parse(JSONObject(it)) }.getOrNull() } ?: Summary.EMPTY
    fun hasCachedSummary(context: Context): Boolean =
        get(context, "wdg_cached_summary")?.let {
            runCatching { Summary.parse(JSONObject(it)) }.isSuccess
        } == true
}

// --- persistent cover cache (last-known-good bytes, survives fetch failures) ---

/**
 * Disk cache for cover bytes, keyed by an MD5 hash of the URL. Both the
 * reading-strip covers (renderMedium) and the event-row covers (buildEventRow)
 * go through this: periodic background refreshes self-fetch over the network
 * with no retry, so without a persistent fallback a cover that loaded fine
 * once would silently disappear the next time that fetch hit a transient
 * failure (Doze, a TLS blip, no connectivity at refresh time). Trimmed to
 * [MAX_ENTRIES] by oldest modification time so it can't grow unbounded.
 */
object CoverDiskCache {
    private const val DIR_NAME = "widget_covers"
    private const val MAX_ENTRIES = 60

    private fun dir(context: Context): File {
        val d = File(context.cacheDir, DIR_NAME)
        if (!d.exists()) d.mkdirs()
        return d
    }

    private fun keyFor(url: String): String {
        val digest = MessageDigest.getInstance("MD5").digest(url.toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it) }
    }

    fun read(context: Context, url: String): ByteArray? {
        val local = when {
            url.startsWith("file:") -> Uri.parse(url).path?.let { File(it) }
            url.startsWith("/") -> File(url)
            else -> null
        }
        if (local != null && local.isFile) {
            return runCatching { local.readBytes() }.getOrNull()
        }
        val f = File(dir(context), keyFor(url))
        return if (f.exists()) runCatching { f.readBytes() }.getOrNull() else null
    }

    /**
     * Writes atomically (temp file + rename) so a concurrent [read] can never
     * observe a half-written file. The strip covers (goAsync thread) and the
     * event-row covers (RemoteCollectionItems / binder factory) can write the
     * same URL at the same time; a torn read there would decode to null and
     * flash the fallback chip — the exact symptom this cache exists to prevent.
     * rename() over an existing target is atomic on the local filesystem.
     */
    fun write(context: Context, url: String, bytes: ByteArray) {
        runCatching {
            val target = File(dir(context), keyFor(url))
            val tmp = File(target.parentFile, "${target.name}.${Thread.currentThread().id}.tmp")
            tmp.writeBytes(bytes)
            if (!tmp.renameTo(target)) {
                // Some filesystems refuse rename onto an existing file: fall back
                // to a direct overwrite and clean up the temp.
                target.writeBytes(bytes)
                tmp.delete()
            }
        }
        trim(context)
    }

    private fun trim(context: Context) {
        val files = dir(context).listFiles { f -> !f.name.endsWith(".tmp") } ?: return
        if (files.size <= MAX_ENTRIES) return
        files.sortedBy { it.lastModified() }
            .take(files.size - MAX_ENTRIES)
            .forEach { it.delete() }
    }
}

// --- theme (effective light/dark, driven by wdg_theme override or system) ---

object WTheme {
    // GENERATED_WIDGET_THEME_CATALOG_START
    data class WColors(
        val bg: Int,
        val surface: Int,
        val surface2: Int,
        val primary: Int,
        val secondary: Int,
        val line: Int,
        val lineStrong: Int,
        val accent: Int,
        val accent2: Int,
        val onAccent: Int,
    )

    data class WResources(
        val root: Int,
        val surface: Int,
        val control: Int,
        val button: Int,
    )

    private data class Palette(val light: Array<String>, val dark: Array<String>)

    private val palettes = mapOf(
        "original" to Palette(arrayOf("#FFFAF5EF", "#FFFFFFFF", "#FFF7F7F5", "#FF0F1014", "#FF5E5E5B", "#FFE5E5E0", "#FFC9C9C2", "#FF7479D6", "#FF2A8F7D", "#FFFFFFFF"), arrayOf("#FF0E1018", "#FF161A26", "#FF1F2433", "#FFF2F2F5", "#FF808290", "#1AF2F2F5", "#33F2F2F5", "#FFA8ADDD", "#FF64BCAC", "#FF0F1014")),
        "jade" to Palette(arrayOf("#FFF1F7F3", "#FFFCFDFC", "#FFDDECE4", "#FF11261D", "#FF577065", "#FFC4D9CE", "#FF8FAD9E", "#FF12614A", "#FFA06A1B", "#FFFFFFFF"), arrayOf("#FF071410", "#FF0E211A", "#FF173328", "#FFEEF8F2", "#FF839F91", "#FF29483B", "#FF3F6754", "#FF8DD9B7", "#FFE2B865", "#FF0B2418")),
        "celestial" to Palette(arrayOf("#FFF3F4FC", "#FFFCFCFF", "#FFE4E8F8", "#FF111A3B", "#FF5F6988", "#FFC9CFE6", "#FF939DC4", "#FF263E91", "#FF9C6A19", "#FFFFFFFF"), arrayOf("#FF070B1C", "#FF10162C", "#FF192344", "#FFF3F4FF", "#FF8C94B5", "#FF2D385C", "#FF46537B", "#FFE5C276", "#FF7EA6FF", "#FF241A06")),
        "ocean" to Palette(arrayOf("#FFEDF6F8", "#FFFBFEFF", "#FFDDEDF1", "#FF10242A", "#FF5B747B", "#FFC4DCE1", "#FF9EC3CC", "#FF1F7666", "#FF5A5FBC", "#FFFFFFFF"), arrayOf("#FF081419", "#FF102128", "#FF17313A", "#FFEAF5F7", "#FF7F9AA1", "#FF27444D", "#FF3A5D67", "#FF64BCAC", "#FFA8ADDD", "#FF081419")),
        "noir" to Palette(arrayOf("#FFF1F1EE", "#FFFFFFFF", "#FFE4E4E0", "#FF0A0A0A", "#FF626262", "#FFC7C7C2", "#FF18181A", "#FF18181A", "#FF5E5E5B", "#FFFFFFFF"), arrayOf("#FF050506", "#FF121214", "#FF1D1D20", "#FFF7F7F5", "#FF92928D", "#FF343438", "#FFEFEFEC", "#FFF2F2F2", "#FFA3A39C", "#FF0A0A0A")),
        "sapphire" to Palette(arrayOf("#FFF0F4FF", "#FFFCFDFF", "#FFDFE7FB", "#FF111B3D", "#FF61719D", "#FFC8D3EF", "#FF8FA3D8", "#FF2454C7", "#FFC4512C", "#FFFFFFFF"), arrayOf("#FF070C1B", "#FF10182D", "#FF192643", "#FFF4F7FF", "#FF8999C3", "#FF2B3A60", "#FF435A8D", "#FF8CB4FF", "#FFFF8D68", "#FF0A1734")),
        "velvet" to Palette(arrayOf("#FFF8F1F5", "#FFFFFBFD", "#FFF0DEE8", "#FF2C1321", "#FF7B5B6D", "#FFE1C6D4", "#FFC49BAD", "#FF7B244D", "#FF9C672D", "#FFFFFFFF"), arrayOf("#FF160911", "#FF25101B", "#FF381829", "#FFFFF0F7", "#FFA98296", "#FF53243C", "#FF773454", "#FFE8A6C5", "#FFF0C77F", "#FF321020")),
        "aurora" to Palette(arrayOf("#FFF3F0FF", "#FFFCFBFF", "#FFE8E2FF", "#FF1E1738", "#FF71658E", "#FFD2C8F3", "#FFB2A4E2", "#FF6346C7", "#FF168B91", "#FFFFFFFF"), arrayOf("#FF0C0B1D", "#FF15142B", "#FF222044", "#FFF2F0FF", "#FF938DBA", "#FF39365F", "#FF555184", "#FFA995FF", "#FF62D5D1", "#FF1E1738")),
        "arcade" to Palette(arrayOf("#FFF4FFD6", "#FFFFFFFF", "#FFE5FF7A", "#FF11110E", "#FF5A5C3D", "#FFB7CC4B", "#FF748300", "#FF4B008F", "#FFB80065", "#FFFFFFFF"), arrayOf("#FF08080B", "#FF111116", "#FF1D1D23", "#FFF5FFE0", "#FF909B80", "#FF3A3A42", "#FF60606B", "#FFC8FF00", "#FFFF3BBA", "#FF101200")),
        "pop" to Palette(arrayOf("#FFFFF4B8", "#FFFFFDF4", "#FFBFE8FF", "#FF17143A", "#FF5C5679", "#FFD8A92E", "#FF7B5C00", "#FF2447C6", "#FFB72E47", "#FFFFFFFF"), arrayOf("#FF17142B", "#FF211D3B", "#FF332B57", "#FFFFF6C7", "#FFA79CC9", "#FF48416A", "#FF6C628F", "#FFFFD84D", "#FFFF6B78", "#FF241800")),
        "ethereal" to Palette(arrayOf("#FFF4F1FF", "#FFFDFCFF", "#FFEAE4FF", "#FF18122F", "#FF70668D", "#FFD8CEF2", "#FFAA9ACF", "#FF5A3FC0", "#FF9A650E", "#FFFFFFFF"), arrayOf("#FF070815", "#FF111326", "#FF1C203A", "#FFF8F5FF", "#FF9B90BA", "#FF343956", "#FF555E86", "#FFB6A2FF", "#FFF2CA72", "#FF1A1238")),
        "stormbound" to Palette(arrayOf("#FFF3EFEA", "#FFFFFCF8", "#FFE4DDD5", "#FF1D1718", "#FF6E6062", "#FFCFC3BB", "#FF9D8B83", "#FF6D1A2A", "#FF5C47B7", "#FFFFFFFF"), arrayOf("#FF090A0D", "#FF15171C", "#FF242832", "#FFF5F2F3", "#FF9C9195", "#FF383B44", "#FF5A5E69", "#FFC5B6FF", "#FFE06672", "#FF151020")),
        "evercourt" to Palette(arrayOf("#FFF6F2F7", "#FFFFFCFF", "#FFE9E1EF", "#FF21182C", "#FF74667F", "#FFD3C6DA", "#FFA794B2", "#FF463087", "#FF8B5812", "#FFFFFFFF"), arrayOf("#FF080B19", "#FF14182A", "#FF242A46", "#FFF8F4FF", "#FF9E94B2", "#FF373E5E", "#FF596283", "#FFE5C76B", "#FF9D86FF", "#FF221A08")),
        "neon_moon" to Palette(arrayOf("#FFF1F3F8", "#FFFCFDFF", "#FFE0E6F1", "#FF171A2A", "#FF687088", "#FFC6CEDD", "#FF929CB2", "#FF8A1954", "#FF08788D", "#FFFFFFFF"), arrayOf("#FF070914", "#FF11182A", "#FF1A2942", "#FFF4F7FF", "#FF8998B5", "#FF2A3B58", "#FF425E82", "#FF44D9F2", "#FFFF5BA6", "#FF061A20")),
        "trail" to Palette(arrayOf("#FFF5F1E8", "#FFFFFDF8", "#FFE8E0D2", "#FF261D15", "#FF79695A", "#FFD8CABA", "#FFAA9580", "#FF7B3F18", "#FF2D6A75", "#FFFFFFFF"), arrayOf("#FF100C09", "#FF1F1711", "#FF35271D", "#FFFBF5EC", "#FFA89582", "#FF4B382A", "#FF74543D", "#FFE9A65D", "#FF72CAD0", "#FF2A1404")),
        "serpents" to Palette(arrayOf("#FFF2F3ED", "#FFFDFEF9", "#FFE1E5D7", "#FF18201B", "#FF687469", "#FFC7D0C2", "#FF91A18F", "#FF175D4D", "#FF8B6418", "#FFFFFFFF"), arrayOf("#FF050A08", "#FF0E1813", "#FF192A21", "#FFF1F8F3", "#FF879A8D", "#FF2B4135", "#FF476352", "#FFD6BE6B", "#FF5ED6A2", "#FF201A05")),
        "thorn_crown" to Palette(arrayOf("#FFF3F2E9", "#FFFFFEF8", "#FFE2E4D3", "#FF1C2419", "#FF697363", "#FFC9CDBA", "#FF989E84", "#FF3E5B2D", "#FF7D2D46", "#FFFFFFFF"), arrayOf("#FF08110B", "#FF121E15", "#FF203024", "#FFF3F6EA", "#FF909D84", "#FF334438", "#FF506352", "#FFC5D98F", "#FFE586A0", "#FF14200D")),
        "iridescent" to Palette(arrayOf("#FFF0F3F4", "#FFFCFEFF", "#FFDFE5E8", "#FF15191D", "#FF657078", "#FFC6CFD4", "#FF929FA7", "#FF45318D", "#FF087C83", "#FFFFFFFF"), arrayOf("#FF050609", "#FF101216", "#FF1B1F26", "#FFF5F7FA", "#FF909BA6", "#FF303640", "#FF4D5663", "#FF70E6E0", "#FFFF71C8", "#FF071A1C")),
        "last_light" to Palette(arrayOf("#FFF2F5F6", "#FFFFFFFF", "#FFDCE5E8", "#FF142027", "#FF637681", "#FFC2D0D6", "#FF8EA5AF", "#FF1E4D73", "#FF9A421D", "#FFFFFFFF"), arrayOf("#FF05080C", "#FF10161C", "#FF1B252E", "#FFF3F7F9", "#FF8B9DA6", "#FF2B3942", "#FF465C67", "#FFFF735E", "#FFF4BF55", "#FF240702")),
    )

    private val resources = mapOf(
        "original_light" to WResources(R.drawable.rd_theme_original_light_root, R.drawable.rd_theme_original_light_surface, R.drawable.rd_theme_original_light_control, R.drawable.rd_theme_original_light_button),
        "original_dark" to WResources(R.drawable.rd_theme_original_dark_root, R.drawable.rd_theme_original_dark_surface, R.drawable.rd_theme_original_dark_control, R.drawable.rd_theme_original_dark_button),
        "jade_light" to WResources(R.drawable.rd_theme_jade_light_root, R.drawable.rd_theme_jade_light_surface, R.drawable.rd_theme_jade_light_control, R.drawable.rd_theme_jade_light_button),
        "jade_dark" to WResources(R.drawable.rd_theme_jade_dark_root, R.drawable.rd_theme_jade_dark_surface, R.drawable.rd_theme_jade_dark_control, R.drawable.rd_theme_jade_dark_button),
        "celestial_light" to WResources(R.drawable.rd_theme_celestial_light_root, R.drawable.rd_theme_celestial_light_surface, R.drawable.rd_theme_celestial_light_control, R.drawable.rd_theme_celestial_light_button),
        "celestial_dark" to WResources(R.drawable.rd_theme_celestial_dark_root, R.drawable.rd_theme_celestial_dark_surface, R.drawable.rd_theme_celestial_dark_control, R.drawable.rd_theme_celestial_dark_button),
        "ocean_light" to WResources(R.drawable.rd_theme_ocean_light_root, R.drawable.rd_theme_ocean_light_surface, R.drawable.rd_theme_ocean_light_control, R.drawable.rd_theme_ocean_light_button),
        "ocean_dark" to WResources(R.drawable.rd_theme_ocean_dark_root, R.drawable.rd_theme_ocean_dark_surface, R.drawable.rd_theme_ocean_dark_control, R.drawable.rd_theme_ocean_dark_button),
        "noir_light" to WResources(R.drawable.rd_theme_noir_light_root, R.drawable.rd_theme_noir_light_surface, R.drawable.rd_theme_noir_light_control, R.drawable.rd_theme_noir_light_button),
        "noir_dark" to WResources(R.drawable.rd_theme_noir_dark_root, R.drawable.rd_theme_noir_dark_surface, R.drawable.rd_theme_noir_dark_control, R.drawable.rd_theme_noir_dark_button),
        "sapphire_light" to WResources(R.drawable.rd_theme_sapphire_light_root, R.drawable.rd_theme_sapphire_light_surface, R.drawable.rd_theme_sapphire_light_control, R.drawable.rd_theme_sapphire_light_button),
        "sapphire_dark" to WResources(R.drawable.rd_theme_sapphire_dark_root, R.drawable.rd_theme_sapphire_dark_surface, R.drawable.rd_theme_sapphire_dark_control, R.drawable.rd_theme_sapphire_dark_button),
        "velvet_light" to WResources(R.drawable.rd_theme_velvet_light_root, R.drawable.rd_theme_velvet_light_surface, R.drawable.rd_theme_velvet_light_control, R.drawable.rd_theme_velvet_light_button),
        "velvet_dark" to WResources(R.drawable.rd_theme_velvet_dark_root, R.drawable.rd_theme_velvet_dark_surface, R.drawable.rd_theme_velvet_dark_control, R.drawable.rd_theme_velvet_dark_button),
        "aurora_light" to WResources(R.drawable.rd_theme_aurora_light_root, R.drawable.rd_theme_aurora_light_surface, R.drawable.rd_theme_aurora_light_control, R.drawable.rd_theme_aurora_light_button),
        "aurora_dark" to WResources(R.drawable.rd_theme_aurora_dark_root, R.drawable.rd_theme_aurora_dark_surface, R.drawable.rd_theme_aurora_dark_control, R.drawable.rd_theme_aurora_dark_button),
        "arcade_light" to WResources(R.drawable.rd_theme_arcade_light_root, R.drawable.rd_theme_arcade_light_surface, R.drawable.rd_theme_arcade_light_control, R.drawable.rd_theme_arcade_light_button),
        "arcade_dark" to WResources(R.drawable.rd_theme_arcade_dark_root, R.drawable.rd_theme_arcade_dark_surface, R.drawable.rd_theme_arcade_dark_control, R.drawable.rd_theme_arcade_dark_button),
        "pop_light" to WResources(R.drawable.rd_theme_pop_light_root, R.drawable.rd_theme_pop_light_surface, R.drawable.rd_theme_pop_light_control, R.drawable.rd_theme_pop_light_button),
        "pop_dark" to WResources(R.drawable.rd_theme_pop_dark_root, R.drawable.rd_theme_pop_dark_surface, R.drawable.rd_theme_pop_dark_control, R.drawable.rd_theme_pop_dark_button),
        "ethereal_light" to WResources(R.drawable.rd_theme_ethereal_light_root, R.drawable.rd_theme_ethereal_light_surface, R.drawable.rd_theme_ethereal_light_control, R.drawable.rd_theme_ethereal_light_button),
        "ethereal_dark" to WResources(R.drawable.rd_theme_ethereal_dark_root, R.drawable.rd_theme_ethereal_dark_surface, R.drawable.rd_theme_ethereal_dark_control, R.drawable.rd_theme_ethereal_dark_button),
        "stormbound_light" to WResources(R.drawable.rd_theme_stormbound_light_root, R.drawable.rd_theme_stormbound_light_surface, R.drawable.rd_theme_stormbound_light_control, R.drawable.rd_theme_stormbound_light_button),
        "stormbound_dark" to WResources(R.drawable.rd_theme_stormbound_dark_root, R.drawable.rd_theme_stormbound_dark_surface, R.drawable.rd_theme_stormbound_dark_control, R.drawable.rd_theme_stormbound_dark_button),
        "evercourt_light" to WResources(R.drawable.rd_theme_evercourt_light_root, R.drawable.rd_theme_evercourt_light_surface, R.drawable.rd_theme_evercourt_light_control, R.drawable.rd_theme_evercourt_light_button),
        "evercourt_dark" to WResources(R.drawable.rd_theme_evercourt_dark_root, R.drawable.rd_theme_evercourt_dark_surface, R.drawable.rd_theme_evercourt_dark_control, R.drawable.rd_theme_evercourt_dark_button),
        "neon_moon_light" to WResources(R.drawable.rd_theme_neon_moon_light_root, R.drawable.rd_theme_neon_moon_light_surface, R.drawable.rd_theme_neon_moon_light_control, R.drawable.rd_theme_neon_moon_light_button),
        "neon_moon_dark" to WResources(R.drawable.rd_theme_neon_moon_dark_root, R.drawable.rd_theme_neon_moon_dark_surface, R.drawable.rd_theme_neon_moon_dark_control, R.drawable.rd_theme_neon_moon_dark_button),
        "trail_light" to WResources(R.drawable.rd_theme_trail_light_root, R.drawable.rd_theme_trail_light_surface, R.drawable.rd_theme_trail_light_control, R.drawable.rd_theme_trail_light_button),
        "trail_dark" to WResources(R.drawable.rd_theme_trail_dark_root, R.drawable.rd_theme_trail_dark_surface, R.drawable.rd_theme_trail_dark_control, R.drawable.rd_theme_trail_dark_button),
        "serpents_light" to WResources(R.drawable.rd_theme_serpents_light_root, R.drawable.rd_theme_serpents_light_surface, R.drawable.rd_theme_serpents_light_control, R.drawable.rd_theme_serpents_light_button),
        "serpents_dark" to WResources(R.drawable.rd_theme_serpents_dark_root, R.drawable.rd_theme_serpents_dark_surface, R.drawable.rd_theme_serpents_dark_control, R.drawable.rd_theme_serpents_dark_button),
        "thorn_crown_light" to WResources(R.drawable.rd_theme_thorn_crown_light_root, R.drawable.rd_theme_thorn_crown_light_surface, R.drawable.rd_theme_thorn_crown_light_control, R.drawable.rd_theme_thorn_crown_light_button),
        "thorn_crown_dark" to WResources(R.drawable.rd_theme_thorn_crown_dark_root, R.drawable.rd_theme_thorn_crown_dark_surface, R.drawable.rd_theme_thorn_crown_dark_control, R.drawable.rd_theme_thorn_crown_dark_button),
        "iridescent_light" to WResources(R.drawable.rd_theme_iridescent_light_root, R.drawable.rd_theme_iridescent_light_surface, R.drawable.rd_theme_iridescent_light_control, R.drawable.rd_theme_iridescent_light_button),
        "iridescent_dark" to WResources(R.drawable.rd_theme_iridescent_dark_root, R.drawable.rd_theme_iridescent_dark_surface, R.drawable.rd_theme_iridescent_dark_control, R.drawable.rd_theme_iridescent_dark_button),
        "last_light_light" to WResources(R.drawable.rd_theme_last_light_light_root, R.drawable.rd_theme_last_light_light_surface, R.drawable.rd_theme_last_light_light_control, R.drawable.rd_theme_last_light_light_button),
        "last_light_dark" to WResources(R.drawable.rd_theme_last_light_dark_root, R.drawable.rd_theme_last_light_dark_surface, R.drawable.rd_theme_last_light_dark_control, R.drawable.rd_theme_last_light_dark_button),
    )
// GENERATED_WIDGET_THEME_CATALOG_END

    /** Explicit widget brightness override, falling back to the system mode. */
    fun isDark(context: Context): Boolean = when (WidgetStore.get(context, "wdg_theme")) {
        "dark" -> true
        "light" -> false
        else -> (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
    }

    private fun values(context: Context, dark: Boolean): Array<String> {
        val id = WidgetStore.get(context, "wdg_app_theme") ?: "original"
        val palette = palettes[id] ?: palettes.getValue("original")
        return if (dark) palette.dark else palette.light
    }

    fun colors(context: Context, dark: Boolean): WColors {
        val v = values(context, dark)
        return WColors(
            bg = Color.parseColor(v[0]),
            surface = Color.parseColor(v[1]),
            surface2 = Color.parseColor(v[2]),
            primary = Color.parseColor(v[3]),
            secondary = Color.parseColor(v[4]),
            line = Color.parseColor(v[5]),
            lineStrong = Color.parseColor(v[6]),
            accent = Color.parseColor(v[7]),
            accent2 = Color.parseColor(v[8]),
            onAccent = Color.parseColor(v[9]),
        )
    }

    fun accent(context: Context, dark: Boolean): Int = colors(context, dark).accent

    fun resources(context: Context, dark: Boolean): WResources {
        val requested = WidgetStore.get(context, "wdg_app_theme") ?: "original"
        val id = requested.takeIf(palettes::containsKey) ?: "original"
        return resources.getValue("${id}_${if (dark) "dark" else "light"}")
    }

    /** "Completed" accent for the row check toggle. */
    fun success(dark: Boolean): Int = Color.parseColor(if (dark) "#82B373" else "#3E9B57")

    // Event-type hues — a 1:1 port of EventType.color / _darkColor (event_icon.dart).
    private val light = mapOf(
        "start" to "#5A5FBC", "finish" to "#487539", "abandoned" to "#8F2F35",
        "chapter_milestone" to "#2A8F7D", "page_milestone" to "#7479D6", "deadline" to "#B97D26",
        "book_return" to "#36572B", "release" to "#B97D26",
    )
    private val darkHues = mapOf(
        "start" to "#A8ADDD", "finish" to "#82B373", "abandoned" to "#D26669",
        "chapter_milestone" to "#64BCAC", "page_milestone" to "#A8ADDD", "deadline" to "#E5A848",
        "book_return" to "#82B373", "release" to "#EBB35A",
    )

    fun eventColor(type: String, dark: Boolean): Int {
        val hue = (if (dark) darkHues else light)[type] ?: (if (dark) "#A8ADDD" else "#7479D6")
        return Color.parseColor(hue)
    }

    fun iconRes(type: String): Int = when (type) {
        "start" -> R.drawable.wdg_ic_start
        "finish" -> R.drawable.wdg_ic_finish
        "abandoned" -> R.drawable.wdg_ic_abandoned
        "chapter_milestone" -> R.drawable.wdg_ic_chapter
        "page_milestone" -> R.drawable.wdg_ic_page
        "deadline" -> R.drawable.wdg_ic_deadline
        "book_return" -> R.drawable.wdg_ic_book_return
        "release" -> R.drawable.wdg_ic_release
        else -> R.drawable.wdg_ic_page
    }
}

// --- model ---

data class Book(
    val id: String,
    val title: String,
    val author: String,
    val coverUrl: String,
    val progressPct: Int?,
    val currentPage: Int?,
    val pageCount: Int?,
    val currentChapter: Int?,
    val chapterCount: Int?,
)
data class Event(
    val id: String,
    val bookId: String?,
    val bookTitle: String?,
    val bookAuthor: String?,
    val bookCoverUrl: String?,
    val type: String,
    val title: String?,
    val status: String,
    val dateLocal: String,
    val timeLocal: String?,
    val tz: String?,
) {
    val isCompleted: Boolean get() = status == "completed"
}

data class Summary(val readingBooks: List<Book>, val events: List<Event>, val hasMore: Boolean = false) {
    companion object {
        val EMPTY = Summary(emptyList(), emptyList())
        fun parse(o: JSONObject): Summary {
            val books = o.optJSONArray("readingBooks")?.let { arr ->
                (0 until arr.length()).map { arr.getJSONObject(it) }.map {
                    Book(
                        it.optString("id"),
                        it.optString("title"),
                        it.optString("author"),
                        it.optString("coverUrl"),
                        if (it.isNull("progressPct")) null else it.optInt("progressPct"),
                        if (it.isNull("currentPage")) null else it.optInt("currentPage"),
                        if (it.isNull("pageCount")) null else it.optInt("pageCount"),
                        if (it.isNull("currentChapter")) null else it.optInt("currentChapter"),
                        if (it.isNull("chapterCount")) null else it.optInt("chapterCount"),
                    )
                }
            } ?: emptyList()
            val events = o.optJSONArray("events")?.let { arr ->
                (0 until arr.length()).map { arr.getJSONObject(it) }.map {
                    Event(
                        it.optString("id"),
                        it.optString("bookId").ifEmpty { null },
                        it.optString("bookTitle").ifEmpty { null },
                        it.optString("bookAuthor").ifEmpty { null },
                        it.optString("bookCoverUrl").ifEmpty { null },
                        it.optString("type"),
                        it.optString("title").ifEmpty { null },
                        it.optString("status").ifEmpty { "active" },
                        it.optString("dateLocal"),
                        it.optString("timeLocal").ifEmpty { null },
                        it.optString("tz").ifEmpty { null },
                    )
                }
            } ?: emptyList()
            return Summary(books, events, o.optBoolean("hasMore", false))
        }
    }
}

// --- local snapshot (app writes wdg_cached_summary) ---

object WidgetApi {
    data class SummaryLoad(
        val summary: Summary,
        val hasUsableData: Boolean,
        val live: Boolean = false,
    )
    data class ProgressUpdate(
        val currentPage: Int?,
        val currentChapter: Int?,
        val currentPercentage: Int?,
    )

    private fun enqueuePendingOp(context: Context, op: JSONObject) {
        val raw = WidgetStore.get(context, "wdg_pending_ops") ?: "[]"
        val arr = try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
        arr.put(op)
        WidgetStore.put(context, "wdg_pending_ops", arr.toString())
    }

    private fun localProgressUpdate(
        context: Context,
        bookID: String,
        field: String,
        value: Int,
    ): ProgressUpdate {
        val book = WidgetStore.cachedSummary(context).readingBooks.firstOrNull { it.id == bookID }
        var page = book?.currentPage
        var chapter = book?.currentChapter
        var pct = book?.progressPct
        if (field == "chapter") {
            chapter = value
        } else {
            page = value
            val pages = book?.pageCount
            if (pages != null && pages > 0) {
                pct = ((value * 100) / pages).coerceIn(0, 100)
            }
        }
        return ProgressUpdate(
            currentPage = page,
            currentChapter = chapter,
            currentPercentage = pct,
        )
    }

    fun loadSummary(context: Context): Summary = loadSummaryWithState(context).summary

    fun loadSummaryWithState(context: Context): SummaryLoad = cachedSummaryLoad(context)

    private fun cachedSummaryLoad(context: Context) = SummaryLoad(
        WidgetStore.cachedSummary(context),
        WidgetStore.hasCachedSummary(context),
        live = false,
    )

    fun toggleComplete(context: Context, eventID: String, complete: Boolean): Boolean {
        enqueuePendingOp(
            context,
            JSONObject()
                .put("op", "complete")
                .put("eventId", eventID)
                .put("complete", complete),
        )
        return true
    }

    fun updateProgress(
        context: Context,
        bookID: String,
        field: String,
        value: Int,
    ): ProgressUpdate {
        enqueuePendingOp(
            context,
            JSONObject()
                .put("op", "progress")
                .put("bookId", bookID)
                .put("field", field)
                .put("value", value),
        )
        return localProgressUpdate(context, bookID, field, value)
    }

    /** Replace one book's progress in the shared summary for optimistic or durable rendering. */
    fun persistProgress(
        context: Context,
        bookID: String,
        update: ProgressUpdate,
    ): Summary {
        val cached = WidgetStore.cachedSummary(context)
        val patched = cached.copy(
            readingBooks = cached.readingBooks.map { book ->
                if (book.id != bookID) {
                    book
                } else {
                    book.copy(
                        progressPct = update.currentPercentage,
                        currentPage = update.currentPage,
                        currentChapter = update.currentChapter,
                    )
                }
            },
        )
        cache(context, patched)
        return patched
    }

    /** Persist an (optimistically-updated) snapshot so the list re-reads it. */
    fun persist(context: Context, s: Summary) = cache(context, s)

    fun loadQuotesJson(context: Context): String? =
        WidgetStore.get(context, "wdg_quotes_cache")

    private fun cache(context: Context, s: Summary) {
        val o = JSONObject()
        o.put("readingBooks", org.json.JSONArray().apply {
            s.readingBooks.forEach {
                put(
                    JSONObject()
                        .put("id", it.id)
                        .put("title", it.title)
                        .put("author", it.author)
                        .put("coverUrl", it.coverUrl)
                        .put("progressPct", it.progressPct ?: JSONObject.NULL)
                        .put("currentPage", it.currentPage ?: JSONObject.NULL)
                        .put("pageCount", it.pageCount ?: JSONObject.NULL)
                        .put("currentChapter", it.currentChapter ?: JSONObject.NULL)
                        .put("chapterCount", it.chapterCount ?: JSONObject.NULL),
                )
            }
        })
        o.put("events", org.json.JSONArray().apply {
            s.events.forEach {
                put(JSONObject().put("id", it.id).put("bookId", it.bookId ?: "").put("bookTitle", it.bookTitle ?: "")
                    .put("bookAuthor", it.bookAuthor ?: "").put("bookCoverUrl", it.bookCoverUrl ?: "")
                    .put("type", it.type).put("title", it.title ?: "").put("status", it.status).put("dateLocal", it.dateLocal)
                    .put("timeLocal", it.timeLocal ?: "").put("tz", it.tz ?: ""))
            }
        })
        o.put("hasMore", s.hasMore)
        WidgetStore.put(context, "wdg_cached_summary", o.toString())
    }
}

// --- localized chrome strings (keyed by wdg_locale) ---

object Strings {
    // Chrome strings are keyed by base language (2-letter); date formatting uses
    // the FULL locale tag so regional variants order day/month correctly
    // (en-US "Jun 15" vs en-GB "15 Jun"), matching the iOS widget + in-app preview.
    private fun lang(context: Context) = (WidgetStore.get(context, "wdg_locale") ?: "es").take(2)
    private fun localeOf(context: Context): java.util.Locale =
        java.util.Locale.forLanguageTag(WidgetStore.get(context, "wdg_locale") ?: "es")
    private val table = mapOf(
        "reading" to mapOf("es" to "Leyendo"),
        "empty" to mapOf("es" to "Añade una lectura"),
        "empty_events" to mapOf("es" to "No hay eventos próximos"),
        "see_more" to mapOf("es" to "Ver más en el calendario"),
        "today" to mapOf("es" to "Hoy"),
        "tomorrow" to mapOf("es" to "Mañana"),
        // Distinct from "empty": shown when a fetch just failed and there's no
        // live payload to show (see renderMedium/renderSmall's hadFetchError).
        "fetch_error" to mapOf("es" to "No se pudo actualizar"),
        "loading" to mapOf("es" to "Actualizando…"),
        "retry" to mapOf("es" to "Reintentar"),
        "pages" to mapOf("es" to "Páginas"),
        "percentage" to mapOf("es" to "Porcentaje"),
        "chapter" to mapOf("es" to "Capítulo"),
        "update_progress" to mapOf("es" to "Actualizar progreso"),
        "save" to mapOf("es" to "Guardar"),
        "saving" to mapOf("es" to "Guardando…"),
        "updated" to mapOf("es" to "Actualizado"),
        "decrease" to mapOf("es" to "Reducir"),
        "increase" to mapOf("es" to "Aumentar"),
        "next_field" to mapOf("es" to "Cambiar campo"),
        "cancel" to mapOf("es" to "Cancelar"),
        "backspace" to mapOf("es" to "Borrar"),
        "next_book" to mapOf("es" to "Libro siguiente"),
        "go_library" to mapOf("es" to "Ir a la biblioteca"),
    )
    // Full event-type labels — mirror the app's eventType* ARB keys (event_icon.dart).
    private val types = mapOf(
        "start" to mapOf("es" to "Inicio"),
        "finish" to mapOf("es" to "Fin"),
        "abandoned" to mapOf("es" to "Abandono"),
        "chapter_milestone" to mapOf("es" to "Hito de capítulo"),
        "page_milestone" to mapOf("es" to "Hito de página"),
        "deadline" to mapOf("es" to "Fecha límite"),
        "book_return" to mapOf("es" to "Devolución de libro"),
        "release" to mapOf("es" to "Lanzamiento"),
    )
    fun get(context: Context, key: String) = table[key]?.get(lang(context)) ?: table[key]?.get("es") ?: key
    fun typeLabel(context: Context, type: String) = types[type]?.get(lang(context)) ?: types[type]?.get("es") ?: type

    /** "Today"/"Tomorrow" for near dates (matches the iOS widget), else a short localized date. */
    fun relativeDay(context: Context, dateLocal: String): String {
        val day = runCatching {
            java.time.LocalDate.parse(dateLocal, java.time.format.DateTimeFormatter.ISO_LOCAL_DATE)
        }.getOrNull() ?: return dateLocal
        val today = java.time.LocalDate.now(java.time.ZoneOffset.UTC)
        return when (day) {
            today -> get(context, "today")
            today.plusDays(1) -> get(context, "tomorrow")
            else -> {
                val locale = localeOf(context)
                // Locale-appropriate "month day" skeleton (US→"MMM d", GB→"d MMM").
                val pattern = android.text.format.DateFormat.getBestDateTimePattern(locale, "MMMd")
                day.format(java.time.format.DateTimeFormatter.ofPattern(pattern, locale))
            }
        }
    }
}

// --- collection service backing the scrollable event list ---

class WidgetListService : android.widget.RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory = WidgetListFactory(applicationContext)
}

/**
 * Pre-API-31 binder for the scrollable event list. Reads the cached summary
 * (written by WidgetApi before notifyAppWidgetViewDataChanged). Row layout is
 * owned by [ReadendarWidgetProvider.buildEventRow].
 */
class WidgetListFactory(private val context: Context) : android.widget.RemoteViewsService.RemoteViewsFactory {
    private var events: List<Event> = emptyList()
    private val coverCache = HashMap<String, Bitmap?>()

    override fun onCreate() {}
    override fun onDataSetChanged() { events = WidgetStore.cachedSummary(context).events }
    override fun onDestroy() { coverCache.clear() }
    override fun getCount(): Int = events.size
    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = false

    override fun getViewAt(position: Int): RemoteViews {
        val e = events.getOrNull(position)
            ?: return RemoteViews(context.packageName, R.layout.readendar_widget_event_row)
        return ReadendarWidgetProvider.buildEventRow(context, e) { url ->
            coverCache.getOrPut(url) { ReadendarWidgetProvider.fetchCoverBitmap(context, url) }
        }
    }
}

// --- collection click dispatcher (open detail vs complete toggle) ------------

/**
 * Receives the single collection-template broadcast and dispatches on the row's
 * fill-in `rdwidget://` action: `open` launches the event detail; `toggle`
 * optimistically flips the cached completion, then calls the widget
 * complete/uncomplete endpoint off the main thread and re-renders.
 */
class WidgetActionReceiver : android.content.BroadcastReceiver() {
    companion object {
        const val ACTION = "com.readendar.readendar.WIDGET_ACTION"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val data = intent.data ?: return
        when (data.host) {
            "open" -> {
                val id = data.getQueryParameter("id") ?: return
                val scheme = WidgetStore.scheme(context)
                // NEW_TASK is required to startActivity from a receiver, but on
                // its own it spawns a fresh task per tap. CLEAR_TOP + SINGLE_TOP
                // make it reuse the running app instance (onNewIntent) instead.
                context.startActivity(
                    Intent(Intent.ACTION_VIEW, Uri.parse("$scheme://event/$id"))
                        .setPackage(context.packageName)
                        .addFlags(
                            Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP,
                        ),
                )
            }
            "toggle" -> {
                val id = data.getQueryParameter("id") ?: return
                val currentlyDone = data.getQueryParameter("done") == "1"
                val complete = !currentlyDone
                // Optimistic: flip the cached status + re-render so the check
                // responds instantly, before the network round-trip.
                val cached = WidgetStore.cachedSummary(context)
                val flipped = cached.copy(events = cached.events.map {
                    if (it.id == id) it.copy(status = if (complete) "completed" else "active") else it
                })
                WidgetApi.persist(context, flipped)
                ReadendarWidgetProvider.renderCachedAll(context)

                val pending = goAsync()
                Thread {
                    try {
                        if (WidgetApi.toggleComplete(context, id, complete)) {
                            // Re-fetch authoritative state (also advances book
                            // progress server-side) and re-render.
                            ReadendarWidgetProvider.refreshAndRenderAll(context)
                        } else {
                            // Toggle failed (e.g. offline): revert the optimistic
                            // flip so the row can't stick in a false state. Don't
                            // re-fetch — loadSummary would just fall back to the
                            // (now reverted) cache anyway.
                            WidgetApi.persist(context, cached)
                            ReadendarWidgetProvider.renderCachedAll(context)
                        }
                    } finally {
                        pending.finish()
                    }
                }.start()
            }
        }
    }
}
