// Per-instance configuration for the quotes widget, launched by the OS when
// the widget is added (android:configure) and on long-press → Reconfigure
// (API 28+, widgetFeatures="reconfigurable").
//
// Native by necessity: the config runs before/without the Flutter engine.
// It reads the shared wdg_quotes_cache snapshot for its quote/book pickers
// (fetching once through WidgetApi when the cache is empty and a token
// exists), writes QuotesWidgetPrefs for this appWidgetId, and — critically —
// calls setResult(RESULT_OK) before finish(): returning RESULT_CANCELED from
// an APPWIDGET_CONFIGURE activity makes the launcher DELETE the widget.

package com.readendar.readendar

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.ScrollView
import android.widget.TextView

class ReadendarQuotesConfigActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private var payload: QuotesPayload = QuotesPayload.EMPTY

    private lateinit var modeGroup: RadioGroup
    private lateinit var cadenceGroup: RadioGroup
    private lateinit var pickerLabel: TextView
    private lateinit var pickerGroup: RadioGroup

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Default to CANCELED so backing out of a fresh add removes the widget
        // (the OS contract); saving flips it to OK.
        setResult(RESULT_CANCELED)
        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        // In-app add flow: the config screen already picked mode/source/cadence
        // and stashed it as the pending config. Apply it to this fresh instance
        // and finish WITHOUT showing the native form — the user configured it in
        // the app. (A long-press → Reconfigure has no pending config and falls
        // through to the form below.) Clear the handoff so a later manual add
        // doesn't inherit a stale choice.
        val pending = QuotesWidgetConfig.fromPendingJson(
            WidgetStore.get(this, QuotesWidgetConfig.PENDING_KEY),
        )
        if (pending != null) {
            WidgetStore.remove(this, QuotesWidgetConfig.PENDING_KEY)
            QuotesWidgetPrefs.save(this, appWidgetId, pending)
            // Async cover pass so a coverGradient instance shows its blurred
            // cover right after add, not the flat fallback (this is the main thread).
            ReadendarQuotesWidgetProvider.renderWithCoverRefresh(
                this,
                AppWidgetManager.getInstance(this),
                appWidgetId,
                QuotesStore.cached(this),
            )
            setResult(
                RESULT_OK,
                android.content.Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId),
            )
            finish()
            return
        }

        payload = QuotesStore.cached(this)
        buildUi(QuotesWidgetPrefs.config(this, appWidgetId))

        if (payload.quotes.isEmpty()) {
            // Cold add before the app ever pushed the cache: fetch once with the
            // shared widget token so the pickers have content.
            Thread {
                val fresh = runCatching { QuotesPayload.parse(WidgetApi.loadQuotesJson(this)) }
                    .getOrDefault(QuotesPayload.EMPTY)
                if (fresh.quotes.isNotEmpty()) runOnUiThread {
                    // The fetch can outlive the activity (user saved/finished, or
                    // a rotation recreated it) — don't touch a dead view tree.
                    if (isFinishing || isDestroyed) return@runOnUiThread
                    payload = fresh
                    // Only repopulate the (previously empty) picker list from the
                    // fetched quotes — do NOT rebuild the whole form, which would
                    // reset the mode/cadence the user may have already chosen while
                    // the fetch was in flight.
                    rebuildPicker(QuotesWidgetPrefs.config(this, appWidgetId))
                }
            }.start()
        }
    }

    private fun buildUi(config: QuotesWidgetConfig) {
        val dark = WTheme.isDark(this)
        val colors = WTheme.colors(this, dark)
        val accent = WTheme.accent(this, dark)
        val s = { key: String -> ConfigStrings.get(this, key) }

        fun label(text: String) = TextView(this).apply {
            this.text = text
            setTextColor(colors.secondary)
            textSize = 12f
            setPadding(0, dp(16), 0, dp(4))
            isAllCaps = true
        }

        fun radio(id: Int, text: String, checked: Boolean) = RadioButton(this).apply {
            this.id = id
            this.text = text
            setTextColor(colors.primary)
            isChecked = checked
        }

        modeGroup = RadioGroup(this).apply {
            addView(radio(1, s("modeAll"), config.mode == "all"))
            addView(radio(2, s("modeFavorites"), config.mode == "favorites"))
            addView(radio(3, s("modeBook"), config.mode == "book"))
            addView(radio(4, s("modeFixed"), config.mode == "fixed"))
            setOnCheckedChangeListener { _, _ -> rebuildPicker(config) }
        }

        // IDs offset from modeGroup's 1-4 (and pickerGroup's 100+/200+): unique
        // view IDs in one Activity tree so instance-state save/restore on a
        // config change (rotation) can't dispatch a restore to the wrong radio.
        cadenceGroup = RadioGroup(this).apply {
            addView(radio(11, s("cadence1h"), config.cadence == "1h"))
            addView(radio(12, s("cadence6h"), config.cadence == "6h"))
            addView(radio(13, s("cadenceDaily"), config.cadence != "1h" && config.cadence != "6h"))
        }

        pickerLabel = label("")
        pickerGroup = RadioGroup(this)

        val save = Button(this).apply {
            text = s("save")
            setTextColor(Color.WHITE)
            setBackgroundColor(accent)
            setOnClickListener { saveAndFinish() }
        }

        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(20), dp(20), dp(20))
            addView(TextView(this@ReadendarQuotesConfigActivity).apply {
                text = s("title")
                setTextColor(colors.primary)
                textSize = 18f
                setTypeface(typeface, android.graphics.Typeface.BOLD)
            })
            addView(label(s("modeLabel")))
            addView(modeGroup)
            addView(pickerLabel)
            addView(pickerGroup)
            addView(label(s("cadenceLabel")))
            addView(cadenceGroup)
            addView(save, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = dp(20) })
        }

        val scroll = ScrollView(this).apply {
            setBackgroundColor(colors.bg)
            addView(column)
        }
        setContentView(scroll)
        rebuildPicker(config)
    }

    /** The conditional third section: a quote picker (fixed) or book picker (book). */
    private fun rebuildPicker(config: QuotesWidgetConfig) {
        val dark = WTheme.isDark(this)
        val colors = WTheme.colors(this, dark)
        val s = { key: String -> ConfigStrings.get(this, key) }
        pickerGroup.removeAllViews()
        when (modeGroup.checkedRadioButtonId) {
            4 -> { // fixed quote
                pickerLabel.text = s("pickQuote")
                pickerLabel.visibility = View.VISIBLE
                pickerGroup.visibility = View.VISIBLE
                payload.quotes.take(30).forEachIndexed { i, q ->
                    pickerGroup.addView(RadioButton(this).apply {
                        id = 100 + i
                        tag = q.id
                        text = "«${q.text.take(60)}» — ${q.bookTitle}"
                        setTextColor(colors.primary)
                        isChecked = q.id == config.quoteId
                    })
                }
            }
            3 -> { // one book
                pickerLabel.text = s("pickBook")
                pickerLabel.visibility = View.VISIBLE
                pickerGroup.visibility = View.VISIBLE
                val books = payload.quotes.map { it.bookId to it.bookTitle }.distinctBy { it.first }
                books.take(30).forEachIndexed { i, (id, title) ->
                    pickerGroup.addView(RadioButton(this).apply {
                        this.id = 200 + i
                        tag = id
                        text = title
                        setTextColor(colors.primary)
                        isChecked = id == config.bookId
                    })
                }
            }
            else -> {
                pickerLabel.visibility = View.GONE
                pickerGroup.visibility = View.GONE
            }
        }
    }

    private fun saveAndFinish() {
        val mode = when (modeGroup.checkedRadioButtonId) {
            2 -> "favorites"
            3 -> "book"
            4 -> "fixed"
            else -> "all"
        }
        val cadence = when (cadenceGroup.checkedRadioButtonId) {
            11 -> "1h"
            12 -> "6h"
            else -> "daily"
        }
        val picked = pickerGroup.findViewById<RadioButton>(pickerGroup.checkedRadioButtonId)?.tag as? String
        // The appearance style isn't part of this native form (the rich picker
        // lives in the in-app config screen, reached by TAPPING the widget) —
        // preserve whatever the instance already had so a Reconfigure here can't
        // silently reset it to the default.
        // Same for the "show note" toggle — it lives only in the in-app config
        // screen, so a native Reconfigure must not silently reset it.
        val existing = QuotesWidgetPrefs.config(this, appWidgetId)
        QuotesWidgetPrefs.save(
            this,
            appWidgetId,
            QuotesWidgetConfig(
                mode = mode,
                quoteId = if (mode == "fixed") picked else null,
                bookId = if (mode == "book") picked else null,
                cadence = cadence,
                style = existing.style,
                showNote = existing.showNote,
            ),
        )
        ReadendarQuotesWidgetProvider.renderWithCoverRefresh(
            this,
            AppWidgetManager.getInstance(this),
            appWidgetId,
            payload,
        )
        // RESULT_OK before finish or the launcher deletes a freshly-added widget.
        setResult(RESULT_OK, android.content.Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId))
        finish()
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
}

/** Localized config strings, keyed by wdg_locale like the widget strings. */
object ConfigStrings {
    private val tables = mapOf(
        "es" to mapOf(
            "title" to "Widget de citas", "modeLabel" to "Qué mostrar",
            "modeAll" to "Rotar todas las citas", "modeFavorites" to "Rotar favoritas",
            "modeBook" to "Rotar un libro", "modeFixed" to "Una cita fija",
            "pickQuote" to "Elige la cita", "pickBook" to "Elige el libro",
            "cadenceLabel" to "Cambiar cita", "cadence1h" to "Cada hora",
            "cadence6h" to "Cada 6 horas", "cadenceDaily" to "Cada día", "save" to "Guardar",
        ),
    )

    fun get(context: android.content.Context, key: String): String {
        val locale = WidgetStore.get(context, "wdg_locale")?.take(2) ?: "es"
        return tables[locale]?.get(key) ?: tables["es"]!![key] ?: key
    }
}
