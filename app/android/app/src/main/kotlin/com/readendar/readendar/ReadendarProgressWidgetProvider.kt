package com.readendar.readendar

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.RemoteViews
import kotlin.math.roundToInt

class ReadendarProgressWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val initialState = if (WidgetStore.hasCachedSummary(context)) {
            DataState.OK
        } else {
            DataState.LOADING
        }
        ids.forEach {
            render(context, manager, it, WidgetStore.cachedSummary(context), initialState)
        }
        refresh(context, manager, ids)
    }

    private fun refresh(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val pending = goAsync()
        Thread {
            try {
                val result = WidgetApi.loadSummaryWithState(context)
                val state = if (result.hasUsableData) {
                    DataState.OK
                } else {
                    DataState.ERROR
                }
                ids.forEach { render(context, manager, it, result.summary, state) }
            } finally {
                pending.finish()
            }
        }.start()
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_REFRESH) {
            val widgetId = intent.getIntExtra(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID,
            )
            if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                refresh(
                    context,
                    AppWidgetManager.getInstance(context),
                    intArrayOf(widgetId),
                )
            }
            return
        }
        if (
            intent.action == ACTION_OPEN_KEYPAD ||
            intent.action == ACTION_CYCLE_FIELD ||
            intent.action == ACTION_DIGIT ||
            intent.action == ACTION_BACKSPACE ||
            intent.action == ACTION_CANCEL_KEYPAD ||
            intent.action == ACTION_SAVE
        ) {
            val widgetId = intent.getIntExtra(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID,
            )
            if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return
            val book = selectedBook(context, widgetId) ?: return
            val manager = AppWidgetManager.getInstance(context)
            when (intent.action) {
                ACTION_OPEN_KEYPAD -> {
                    val preserveFailedDraft =
                        mutationState(context, widgetId) == MutationState.ERROR
                    Metric.entries.forEach { candidate ->
                        val initial = if (preserveFailedDraft) {
                            draftValue(context, widgetId, book, candidate)
                        } else {
                            actualValue(book, candidate).coerceIn(0, maxValue(book, candidate))
                        }
                        WidgetStore.put(
                            context,
                            draftKey(widgetId, book.id, candidate),
                            initial.toString(),
                        )
                        WidgetStore.put(
                            context,
                            originalKey(widgetId, book.id, candidate),
                            initial.toString(),
                        )
                    }
                    WidgetStore.put(context, editKey(widgetId), "true")
                    WidgetStore.put(context, replaceKey(widgetId), "true")
                    WidgetStore.put(context, mutationKey(widgetId), MutationState.IDLE.name)
                    render(
                        context,
                        manager,
                        widgetId,
                        WidgetStore.cachedSummary(context),
                        DataState.OK,
                    )
                }
                ACTION_CYCLE_FIELD -> {
                    val next = metric(context, widgetId).next()
                    WidgetStore.put(context, metricKey(widgetId), next.wire)
                    WidgetStore.put(context, replaceKey(widgetId), "true")
                    WidgetStore.put(context, mutationKey(widgetId), MutationState.IDLE.name)
                    render(
                        context,
                        manager,
                        widgetId,
                        WidgetStore.cachedSummary(context),
                        DataState.OK,
                    )
                }
                ACTION_DIGIT -> {
                    val selectedMetric = metric(context, widgetId)
                    val digit = intent.getIntExtra(EXTRA_DIGIT, 0).coerceIn(0, 9)
                    val current = draftValue(context, widgetId, book, selectedMetric)
                    val replace = WidgetStore.get(context, replaceKey(widgetId)) == "true"
                    val next = (
                        if (replace) {
                            digit.toLong()
                        } else {
                            current.toLong() * 10L + digit
                        }
                    ).coerceIn(0L, maxValue(book, selectedMetric).toLong()).toInt()
                    WidgetStore.put(
                        context,
                        draftKey(widgetId, book.id, selectedMetric),
                        next.toString(),
                    )
                    WidgetStore.put(context, replaceKey(widgetId), "false")
                    WidgetStore.put(context, mutationKey(widgetId), MutationState.IDLE.name)
                    render(
                        context,
                        manager,
                        widgetId,
                        WidgetStore.cachedSummary(context),
                        DataState.OK,
                    )
                }
                ACTION_BACKSPACE -> {
                    val selectedMetric = metric(context, widgetId)
                    val current = draftValue(context, widgetId, book, selectedMetric)
                    WidgetStore.put(
                        context,
                        draftKey(widgetId, book.id, selectedMetric),
                        (current / 10).toString(),
                    )
                    WidgetStore.put(context, replaceKey(widgetId), "false")
                    WidgetStore.put(context, mutationKey(widgetId), MutationState.IDLE.name)
                    render(
                        context,
                        manager,
                        widgetId,
                        WidgetStore.cachedSummary(context),
                        DataState.OK,
                    )
                }
                ACTION_CANCEL_KEYPAD -> {
                    Metric.entries.forEach { candidate ->
                        val original = WidgetStore.get(
                            context,
                            originalKey(widgetId, book.id, candidate),
                        )?.toIntOrNull() ?: actualValue(book, candidate)
                        WidgetStore.put(
                            context,
                            draftKey(widgetId, book.id, candidate),
                            original.coerceIn(0, maxValue(book, candidate)).toString(),
                        )
                    }
                    WidgetStore.put(context, editKey(widgetId), "false")
                    WidgetStore.put(context, mutationKey(widgetId), MutationState.IDLE.name)
                    render(
                        context,
                        manager,
                        widgetId,
                        WidgetStore.cachedSummary(context),
                        DataState.OK,
                    )
                }
                ACTION_SAVE -> {
                    val selectedMetric = metric(context, widgetId)
                    val value = draftValue(context, widgetId, book, selectedMetric)
                    val optimistic = optimisticProgress(book, selectedMetric, value)
                    val optimisticSummary = WidgetApi.persistProgress(
                        context,
                        book.id,
                        optimistic,
                    )
                    persistDrafts(context, widgetId, book.id, optimistic)
                    WidgetStore.put(context, editKey(widgetId), "false")
                    WidgetStore.put(context, mutationKey(widgetId), MutationState.SAVING.name)
                    render(
                        context,
                        manager,
                        widgetId,
                        optimisticSummary,
                        DataState.OK,
                    )
                    ReadendarWidgetProvider.renderCachedAll(context)
                    val pending = goAsync()
                    Thread {
                        try {
                            val update = WidgetApi.updateProgress(
                                context,
                                book.id,
                                selectedMetric.wire,
                                value,
                            )
                            WidgetApi.persistProgress(context, book.id, update)
                            persistDrafts(context, widgetId, book.id, update)
                            WidgetStore.put(
                                context,
                                mutationKey(widgetId),
                                MutationState.SAVED.name,
                            )
                        } finally {
                            Handler(Looper.getMainLooper()).post {
                                try {
                                    // Main-thread rendering intentionally uses
                                    // disk-cached covers only. A completion
                                    // label must never wait on cover downloads.
                                    renderAll(context)
                                    ReadendarWidgetProvider.renderCachedAll(context)
                                } finally {
                                    val terminalState = mutationState(context, widgetId)
                                    Handler(Looper.getMainLooper()).postDelayed({
                                        if (mutationState(context, widgetId) == terminalState) {
                                            WidgetStore.put(
                                                context,
                                                mutationKey(widgetId),
                                                MutationState.IDLE.name,
                                            )
                                            renderAll(context)
                                            ReadendarWidgetProvider.renderCachedAll(context)
                                        }
                                        pending.finish()
                                    }, feedbackDurationMillis)
                                }
                            }
                        }
                    }.start()
                }
            }
            return
        }
        if (intent.action != ACTION_NEXT && intent.action != ACTION_SELECT) return
        val widgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        )
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return
        val books = WidgetStore.cachedSummary(context).readingBooks
        if (books.isEmpty()) return
        val selectedID = WidgetStore.get(context, selectionKey(widgetId))
        val current = books.indexOfFirst { it.id == selectedID }
        val requestedID = intent.getStringExtra(EXTRA_BOOK_ID)
        val requestedIndex = books.indexOfFirst { it.id == requestedID }
        val nextIndex = if (intent.action == ACTION_SELECT && requestedIndex >= 0) {
            requestedIndex
        } else if (current < 0) {
            0
        } else {
            (current + 1) % books.size
        }
        val next = books[nextIndex]
        WidgetStore.put(context, selectionKey(widgetId), next.id)
        WidgetStore.put(context, editKey(widgetId), "false")
        WidgetStore.put(context, mutationKey(widgetId), MutationState.IDLE.name)
        val manager = AppWidgetManager.getInstance(context)
        val summary = WidgetStore.cachedSummary(context)
        render(
            context,
            manager,
            widgetId,
            summary,
            DataState.OK,
        )
        if (next.coverUrl.isNotBlank()) {
            val pending = goAsync()
            Thread {
                try {
                    if (WidgetStore.get(context, selectionKey(widgetId)) == next.id) {
                        render(context, manager, widgetId, summary, DataState.OK)
                    }
                } finally {
                    pending.finish()
                }
            }.start()
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        appWidgetIds.forEach {
            WidgetStore.remove(context, selectionKey(it))
            WidgetStore.remove(context, metricKey(it))
            WidgetStore.remove(context, mutationKey(it))
            WidgetStore.remove(context, editKey(it))
            WidgetStore.remove(context, replaceKey(it))
        }
    }

    companion object {
        private const val feedbackDurationMillis = 1_500L
        private const val ACTION_NEXT = "com.readendar.readendar.PROGRESS_WIDGET_NEXT"
        private const val ACTION_SELECT = "com.readendar.readendar.PROGRESS_WIDGET_SELECT"
        private const val ACTION_REFRESH = "com.readendar.readendar.PROGRESS_WIDGET_REFRESH"
        private const val ACTION_OPEN_KEYPAD =
            "com.readendar.readendar.PROGRESS_WIDGET_OPEN_KEYPAD"
        private const val ACTION_CYCLE_FIELD =
            "com.readendar.readendar.PROGRESS_WIDGET_CYCLE_FIELD"
        private const val ACTION_DIGIT = "com.readendar.readendar.PROGRESS_WIDGET_DIGIT"
        private const val ACTION_BACKSPACE =
            "com.readendar.readendar.PROGRESS_WIDGET_BACKSPACE"
        private const val ACTION_CANCEL_KEYPAD =
            "com.readendar.readendar.PROGRESS_WIDGET_CANCEL_KEYPAD"
        private const val ACTION_SAVE = "com.readendar.readendar.PROGRESS_WIDGET_SAVE"
        private const val EXTRA_BOOK_ID = "bookId"
        private const val EXTRA_DIGIT = "digit"

        private enum class DataState { OK, LOADING, STALE, ERROR }
        private enum class MutationState { IDLE, SAVING, SAVED, ERROR }
        private enum class Metric(val wire: String) {
            PAGE("page"),
            CHAPTER("chapter");

            fun next(): Metric = entries[(ordinal + 1) % entries.size]
        }

        fun renderAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, ReadendarProgressWidgetProvider::class.java),
            )
            val summary = WidgetStore.cachedSummary(context)
            val state = if (WidgetStore.hasCachedSummary(context)) DataState.OK else DataState.LOADING
            ids.forEach { render(context, manager, it, summary, state) }
        }

        private fun render(
            context: Context,
            manager: AppWidgetManager,
            widgetId: Int,
            summary: Summary,
            state: DataState,
        ) {
            val dark = WTheme.isDark(context)
            val colors = WTheme.colors(context, dark)
            val themeResources = WTheme.resources(context, dark)
            val views = RemoteViews(
                context.packageName,
                R.layout.readendar_progress_widget,
            )
            views.setInt(R.id.pwdg_root, "setBackgroundResource", themeResources.root)
            views.setTextColor(R.id.pwdg_brand, colors.secondary)
            views.setTextViewText(
                R.id.pwdg_brand,
                ReadendarWidgetProvider.brandWordmark(context, dark),
            )
            views.setInt(
                R.id.pwdg_card,
                "setBackgroundResource",
                themeResources.surface,
            )
            views.setTextColor(R.id.pwdg_title, colors.primary)
            views.setTextColor(R.id.pwdg_author, colors.secondary)
            views.setTextColor(R.id.pwdg_pages, colors.secondary)
            views.setTextColor(R.id.pwdg_percentage, colors.secondary)
            views.setTextColor(R.id.pwdg_chapter, colors.secondary)
            views.setTextColor(R.id.pwdg_separator_1, colors.secondary)
            views.setTextColor(R.id.pwdg_separator_2, colors.secondary)
            views.setInt(R.id.pwdg_page_icon, "setColorFilter", colors.secondary)
            views.setInt(R.id.pwdg_chapter_icon, "setColorFilter", colors.secondary)
            views.setInt(
                R.id.pwdg_save,
                "setBackgroundResource",
                themeResources.button,
            )
            views.setTextColor(
                R.id.pwdg_save,
                colors.onAccent,
            )
            views.setTextColor(R.id.pwdg_empty_text, colors.secondary)
            views.setTextColor(R.id.pwdg_empty_action, WTheme.accent(context, dark))
            views.setInt(R.id.pwdg_empty_icon, "setColorFilter", colors.secondary)
            views.setViewVisibility(R.id.pwdg_header, View.VISIBLE)
            views.setViewVisibility(R.id.pwdg_keypad, View.GONE)
            // Clear recycled row actions before handling loading/empty states.
            views.setOnClickPendingIntent(R.id.pwdg_card, null)

            val keypadControlBackground = themeResources.control
            keypadControlIDs.forEach {
                views.setInt(it, "setBackgroundResource", keypadControlBackground)
                views.setTextColor(it, colors.primary)
            }
            views.setInt(
                R.id.pwdg_keypad_field,
                "setBackgroundResource",
                keypadControlBackground,
            )
            views.setTextColor(R.id.pwdg_keypad_field_label, colors.primary)
            views.setTextColor(R.id.pwdg_keypad_field_chevron, colors.secondary)
            views.setInt(
                R.id.pwdg_key_submit,
                "setBackgroundResource",
                themeResources.button,
            )
            views.setTextColor(
                R.id.pwdg_key_submit,
                colors.onAccent,
            )
            views.setTextColor(R.id.pwdg_keypad_value, colors.primary)

            val books = summary.readingBooks
            if (books.isEmpty()) {
                // Clear populated-state header actions explicitly. RemoteViews
                // updates can reuse the existing hierarchy, so relying on the
                // XML default would leak the previous reading strip here.
                progressStripIDs.forEach {
                    views.setViewVisibility(it, View.GONE)
                    views.setOnClickPendingIntent(it, null)
                }
                views.setViewVisibility(R.id.pwdg_content, View.GONE)
                views.setViewVisibility(R.id.pwdg_empty, View.VISIBLE)
                when (state) {
                    DataState.LOADING -> {
                        views.setImageViewResource(
                            R.id.pwdg_empty_icon,
                            R.drawable.wdg_ic_page,
                        )
                        views.setTextViewText(R.id.pwdg_empty_text, Strings.get(context, "loading"))
                        views.setViewVisibility(R.id.pwdg_empty_action, View.GONE)
                        views.setOnClickPendingIntent(R.id.pwdg_empty, null)
                    }
                    DataState.ERROR, DataState.STALE -> {
                        views.setImageViewResource(
                            R.id.pwdg_empty_icon,
                            R.drawable.wdg_ic_fetch_error,
                        )
                        views.setTextViewText(R.id.pwdg_empty_text, Strings.get(context, "fetch_error"))
                        views.setViewVisibility(R.id.pwdg_empty_action, View.VISIBLE)
                        views.setTextViewText(R.id.pwdg_empty_action, Strings.get(context, "retry"))
                        views.setOnClickPendingIntent(
                            R.id.pwdg_empty_action,
                            refreshIntent(context, widgetId),
                        )
                        views.setOnClickPendingIntent(R.id.pwdg_empty, null)
                    }
                    DataState.OK -> {
                        views.setImageViewResource(
                            R.id.pwdg_empty_icon,
                            R.drawable.wdg_ic_page,
                        )
                        views.setTextViewText(R.id.pwdg_empty_text, Strings.get(context, "empty"))
                        views.setViewVisibility(R.id.pwdg_empty_action, View.VISIBLE)
                        views.setTextViewText(
                            R.id.pwdg_empty_action,
                            Strings.get(context, "go_library"),
                        )
                        views.setOnClickPendingIntent(
                            R.id.pwdg_empty,
                            deepLink(context, widgetId, "library"),
                        )
                    }
                }
                manager.updateAppWidget(widgetId, views)
                return
            }

            views.setViewVisibility(R.id.pwdg_empty, View.GONE)
            views.setViewVisibility(R.id.pwdg_content, View.VISIBLE)
            val storedID = WidgetStore.get(context, selectionKey(widgetId))
            val index = books.indexOfFirst { it.id == storedID }.let { if (it < 0) 0 else it }
            val book = books[index]
            if (storedID != null && book.id != storedID) {
                WidgetStore.remove(context, selectionKey(widgetId))
            }
            if (isEditing(context, widgetId)) {
                views.setViewVisibility(R.id.pwdg_header, View.GONE)
                views.setViewVisibility(R.id.pwdg_content, View.GONE)
                views.setViewVisibility(R.id.pwdg_empty, View.GONE)
                views.setViewVisibility(R.id.pwdg_keypad, View.VISIBLE)
                renderKeypad(context, views, widgetId, book)
                manager.updateAppWidget(widgetId, views)
                return
            }
            val visibleBooks = if (books.size > 1) {
                List(minOf(books.size, progressStripIDs.size)) { offset ->
                    books[(index + offset) % books.size]
                }
            } else {
                emptyList()
            }
            progressStripIDs.forEachIndexed { stripIndex, viewID ->
                val stripBook = visibleBooks.getOrNull(stripIndex)
                val bitmap = stripBook
                    ?.coverUrl
                    ?.takeIf { it.isNotBlank() }
                    ?.let { ReadendarWidgetProvider.offMainCover(context, it) }
                if (stripBook != null && bitmap != null) {
                    views.setImageViewBitmap(viewID, bitmap)
                    views.setViewVisibility(viewID, View.VISIBLE)
                    views.setContentDescription(viewID, stripBook.title)
                    views.setOnClickPendingIntent(
                        viewID,
                        selectIntent(context, widgetId, stripBook.id),
                    )
                } else {
                    views.setViewVisibility(viewID, View.GONE)
                    views.setOnClickPendingIntent(viewID, null)
                }
            }
            views.setTextViewText(R.id.pwdg_title, book.title)
            views.setTextViewText(R.id.pwdg_author, book.author)
            views.setOnClickPendingIntent(
                R.id.pwdg_card,
                deepLink(context, widgetId, "book/${book.id}"),
            )
            views.setContentDescription(R.id.pwdg_card, book.title)
            views.setTextViewText(
                R.id.pwdg_pages,
                fraction(book.currentPage, book.pageCount),
            )
            views.setTextViewText(
                R.id.pwdg_percentage,
                effectiveProgress(book)?.let { "$it%" } ?: "—",
            )
            views.setTextViewText(
                R.id.pwdg_chapter,
                fraction(book.currentChapter, book.chapterCount),
            )
            effectiveProgress(book)?.let {
                views.setViewVisibility(R.id.pwdg_progress, View.VISIBLE)
                views.setProgressBar(R.id.pwdg_progress, 100, it, false)
            } ?: views.setViewVisibility(R.id.pwdg_progress, View.GONE)
            val mutation = mutationState(context, widgetId)
            views.setTextViewText(
                R.id.pwdg_save,
                when (mutation) {
                    MutationState.SAVING -> Strings.get(context, "saving")
                    MutationState.SAVED -> Strings.get(context, "updated")
                    MutationState.ERROR -> Strings.get(context, "fetch_error")
                    MutationState.IDLE -> Strings.get(context, "update_progress")
                },
            )
            val controlsEnabled = mutation != MutationState.SAVING
            views.setOnClickPendingIntent(
                R.id.pwdg_save,
                if (controlsEnabled) openKeypadIntent(context, widgetId) else null,
            )
            views.setContentDescription(
                R.id.pwdg_save,
                Strings.get(context, "update_progress"),
            )
            views.setContentDescription(
                R.id.pwdg_content,
                buildString {
                    append(book.title)
                    append(". ")
                    append(Strings.get(context, "pages"))
                    append(": ")
                    append(fraction(book.currentPage, book.pageCount))
                    append(". ")
                    append(Strings.get(context, "percentage"))
                    append(": ")
                    append(effectiveProgress(book)?.let { "$it%" } ?: "—")
                    append(". ")
                    append(Strings.get(context, "chapter"))
                    append(": ")
                    append(fraction(book.currentChapter, book.chapterCount))
                    append(". ")
                    append(Strings.get(context, "update_progress"))
                },
            )
            val bitmap = book.coverUrl
                .takeIf { it.isNotBlank() }
                ?.let { ReadendarWidgetProvider.offMainCover(context, it) }
            if (bitmap == null) {
                views.setTextViewText(
                    R.id.pwdg_cover_fallback,
                    book.title.firstOrNull()?.uppercase() ?: "?",
                )
                views.setViewVisibility(R.id.pwdg_cover_fallback, View.VISIBLE)
                views.setViewVisibility(R.id.pwdg_cover, View.GONE)
            } else {
                views.setImageViewBitmap(R.id.pwdg_cover, bitmap)
                views.setViewVisibility(R.id.pwdg_cover_fallback, View.GONE)
                views.setViewVisibility(R.id.pwdg_cover, View.VISIBLE)
            }
            views.setOnClickPendingIntent(R.id.pwdg_content, null)
            manager.updateAppWidget(widgetId, views)
        }

        private val progressStripIDs = intArrayOf(
            R.id.pwdg_book_0,
            R.id.pwdg_book_1,
            R.id.pwdg_book_2,
            R.id.pwdg_book_3,
        )

        private val keypadDigitIDs = intArrayOf(
            R.id.pwdg_key_0,
            R.id.pwdg_key_1,
            R.id.pwdg_key_2,
            R.id.pwdg_key_3,
            R.id.pwdg_key_4,
            R.id.pwdg_key_5,
            R.id.pwdg_key_6,
            R.id.pwdg_key_7,
            R.id.pwdg_key_8,
            R.id.pwdg_key_9,
        )

        private val keypadControlIDs = keypadDigitIDs + intArrayOf(
            R.id.pwdg_keypad_cancel,
            R.id.pwdg_key_backspace,
        )

        private fun renderKeypad(
            context: Context,
            views: RemoteViews,
            widgetId: Int,
            book: Book,
        ) {
            val selectedMetric = metric(context, widgetId)
            val draft = draftValue(context, widgetId, book, selectedMetric)
            views.setTextViewText(
                R.id.pwdg_keypad_field_label,
                metricLabel(context, selectedMetric),
            )
            views.setImageViewResource(
                R.id.pwdg_keypad_field_icon,
                if (selectedMetric == Metric.PAGE) {
                    R.drawable.wdg_ic_page
                } else {
                    R.drawable.wdg_ic_chapter
                },
            )
            views.setInt(
                R.id.pwdg_keypad_field_icon,
                "setColorFilter",
                WTheme.accent(context, WTheme.isDark(context)),
            )
            views.setTextViewText(
                R.id.pwdg_keypad_value,
                keypadValue(draft, book, selectedMetric),
            )
            views.setContentDescription(
                R.id.pwdg_keypad_field,
                metricLabel(context, selectedMetric) + ". " +
                    Strings.get(context, "next_field"),
            )
            keypadDigitIDs.forEachIndexed { digit, viewID ->
                views.setOnClickPendingIntent(viewID, digitIntent(context, widgetId, digit))
                views.setContentDescription(viewID, digit.toString())
            }
            views.setOnClickPendingIntent(
                R.id.pwdg_key_backspace,
                backspaceIntent(context, widgetId),
            )
            views.setContentDescription(
                R.id.pwdg_key_backspace,
                Strings.get(context, "backspace"),
            )
            views.setOnClickPendingIntent(
                R.id.pwdg_keypad_cancel,
                cancelKeypadIntent(context, widgetId),
            )
            views.setContentDescription(
                R.id.pwdg_keypad_cancel,
                Strings.get(context, "cancel"),
            )
            views.setOnClickPendingIntent(
                R.id.pwdg_keypad_field,
                cycleFieldIntent(context, widgetId),
            )
            views.setOnClickPendingIntent(
                R.id.pwdg_key_submit,
                saveIntent(context, widgetId),
            )
            views.setContentDescription(
                R.id.pwdg_key_submit,
                Strings.get(context, "save"),
            )
        }

        private fun selectionKey(widgetId: Int) = "wdg_progress_selected_$widgetId"
        private fun metricKey(widgetId: Int) = "wdg_progress_metric_$widgetId"
        private fun mutationKey(widgetId: Int) = "wdg_progress_mutation_$widgetId"
        private fun editKey(widgetId: Int) = "wdg_progress_editing_$widgetId"
        private fun replaceKey(widgetId: Int) = "wdg_progress_replace_$widgetId"
        private fun draftKey(widgetId: Int, bookID: String, metric: Metric) =
            "wdg_progress_draft_${widgetId}_${bookID}_${metric.wire}"
        private fun originalKey(widgetId: Int, bookID: String, metric: Metric) =
            "wdg_progress_original_${widgetId}_${bookID}_${metric.wire}"

        private fun metric(context: Context, widgetId: Int): Metric {
            val stored = WidgetStore.get(context, metricKey(widgetId))
            return Metric.entries.firstOrNull { it.wire == stored } ?: Metric.PAGE
        }

        private fun mutationState(context: Context, widgetId: Int): MutationState =
            runCatching {
                MutationState.valueOf(
                    WidgetStore.get(context, mutationKey(widgetId)) ?: MutationState.IDLE.name,
                )
            }.getOrDefault(MutationState.IDLE)

        private fun isEditing(context: Context, widgetId: Int): Boolean =
            WidgetStore.get(context, editKey(widgetId)) == "true"

        private fun selectedBook(context: Context, widgetId: Int): Book? {
            val books = WidgetStore.cachedSummary(context).readingBooks
            if (books.isEmpty()) return null
            val selectedID = WidgetStore.get(context, selectionKey(widgetId))
            val match = books.firstOrNull { it.id == selectedID }
            if (match != null) return match
            if (selectedID != null) {
                WidgetStore.remove(context, selectionKey(widgetId))
            }
            return books.first()
        }

        private fun actualValue(book: Book, metric: Metric): Int = when (metric) {
            Metric.PAGE -> book.currentPage
            Metric.CHAPTER -> book.currentChapter
        } ?: 0

        private fun valueFor(update: WidgetApi.ProgressUpdate, metric: Metric): Int = when (metric) {
            Metric.PAGE -> update.currentPage
            Metric.CHAPTER -> update.currentChapter
        } ?: 0

        private fun optimisticProgress(
            book: Book,
            metric: Metric,
            value: Int,
        ): WidgetApi.ProgressUpdate = when (metric) {
            Metric.PAGE -> WidgetApi.ProgressUpdate(
                currentPage = value,
                currentChapter = book.currentChapter,
                currentPercentage = book.pageCount
                    ?.takeIf { it > 0 }
                    ?.let { total ->
                        ((value.toLong() * 100L) / total.toLong())
                            .coerceAtMost(100L)
                            .toInt()
                    },
            )
            Metric.CHAPTER -> WidgetApi.ProgressUpdate(
                currentPage = book.currentPage,
                currentChapter = value.takeUnless { it == 0 },
                currentPercentage = book.progressPct,
            )
        }

        private fun persistDrafts(
            context: Context,
            widgetId: Int,
            bookID: String,
            update: WidgetApi.ProgressUpdate,
        ) {
            Metric.entries.forEach { candidate ->
                WidgetStore.put(
                    context,
                    draftKey(widgetId, bookID, candidate),
                    valueFor(update, candidate).toString(),
                )
            }
        }

        private fun draftValue(
            context: Context,
            widgetId: Int,
            book: Book,
            metric: Metric,
        ): Int = WidgetStore.get(context, draftKey(widgetId, book.id, metric))
            ?.toIntOrNull()
            ?.coerceIn(0, maxValue(book, metric))
            ?: actualValue(book, metric).coerceIn(0, maxValue(book, metric))

        private fun maxValue(book: Book, metric: Metric): Int = when (metric) {
            Metric.PAGE -> book.pageCount?.takeIf { it > 0 } ?: 10_000_000
            Metric.CHAPTER -> book.chapterCount?.takeIf { it > 0 } ?: 10_000_000
        }

        private fun keypadValue(value: Int, book: Book, metric: Metric): String {
            val total = when (metric) {
                Metric.PAGE -> book.pageCount
                Metric.CHAPTER -> book.chapterCount
            }?.takeIf { it > 0 } ?: return value.toString()
            return "$value/$total"
        }

        private fun metricLabel(context: Context, metric: Metric): String = Strings.get(
            context,
            when (metric) {
                Metric.PAGE -> "pages"
                Metric.CHAPTER -> "chapter"
            },
        )

        private fun selectIntent(
            context: Context,
            widgetId: Int,
            bookID: String,
        ): PendingIntent = PendingIntent.getBroadcast(
            context,
            "$widgetId:$bookID".hashCode(),
            Intent(context, ReadendarProgressWidgetProvider::class.java)
                .setAction(ACTION_SELECT)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                .putExtra(EXTRA_BOOK_ID, bookID),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        private fun refreshIntent(context: Context, widgetId: Int): PendingIntent =
            PendingIntent.getBroadcast(
                context,
                "refresh:$widgetId".hashCode(),
                Intent(context, ReadendarProgressWidgetProvider::class.java)
                    .setAction(ACTION_REFRESH)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        private fun openKeypadIntent(context: Context, widgetId: Int): PendingIntent =
            PendingIntent.getBroadcast(
                context,
                "open-keypad:$widgetId".hashCode(),
                Intent(context, ReadendarProgressWidgetProvider::class.java)
                    .setAction(ACTION_OPEN_KEYPAD)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        private fun cycleFieldIntent(context: Context, widgetId: Int): PendingIntent =
            PendingIntent.getBroadcast(
                context,
                "cycle-field:$widgetId".hashCode(),
                Intent(context, ReadendarProgressWidgetProvider::class.java)
                    .setAction(ACTION_CYCLE_FIELD)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        private fun digitIntent(
            context: Context,
            widgetId: Int,
            digit: Int,
        ): PendingIntent = PendingIntent.getBroadcast(
            context,
            "digit:$widgetId:$digit".hashCode(),
            Intent(context, ReadendarProgressWidgetProvider::class.java)
                .setAction(ACTION_DIGIT)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                .putExtra(EXTRA_DIGIT, digit),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        private fun backspaceIntent(context: Context, widgetId: Int): PendingIntent =
            PendingIntent.getBroadcast(
                context,
                "backspace:$widgetId".hashCode(),
                Intent(context, ReadendarProgressWidgetProvider::class.java)
                    .setAction(ACTION_BACKSPACE)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        private fun cancelKeypadIntent(context: Context, widgetId: Int): PendingIntent =
            PendingIntent.getBroadcast(
                context,
                "cancel-keypad:$widgetId".hashCode(),
                Intent(context, ReadendarProgressWidgetProvider::class.java)
                    .setAction(ACTION_CANCEL_KEYPAD)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        private fun saveIntent(context: Context, widgetId: Int): PendingIntent =
            PendingIntent.getBroadcast(
                context,
                "save:$widgetId".hashCode(),
                Intent(context, ReadendarProgressWidgetProvider::class.java)
                    .setAction(ACTION_SAVE)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        private fun fraction(current: Int?, total: Int?): String = when {
            current == null -> "—"
            total == null -> current.toString()
            else -> "$current / $total"
        }

        /// Pages are the display source of truth when page + total are known.
        /// An explicit percentage is used only when derivation is impossible;
        /// a page without a total suppresses a conflicting stored percentage.
        private fun effectiveProgress(book: Book): Int? {
            val page = book.currentPage
            val total = book.pageCount?.takeIf { it > 0 }
            if (page != null && total != null) {
                return ((page.toDouble() / total) * 100).roundToInt().coerceIn(0, 100)
            }
            if (page != null) return null
            return book.progressPct?.coerceIn(0, 100)
        }

        private fun deepLink(
            context: Context,
            widgetId: Int,
            path: String,
        ): PendingIntent {
            val uri = "${WidgetStore.scheme(context)}://$path"
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uri))
                .setPackage(context.packageName)
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP,
                )
            return PendingIntent.getActivity(
                context,
                "$widgetId:$uri".hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
