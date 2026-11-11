package com.abdelrahmanalhajs.quranapp

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.graphics.Typeface
import android.os.SystemClock
import android.text.SpannableString
import android.text.style.StyleSpan
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Larger (3x3, resizable) home-screen widget: the next prayer with a live
 * countdown on top, then all five of today's prayer times with the next one
 * highlighted. Shares its data and logic with [PrayerWidgetProvider] via
 * [PrayerWidgetCommon].
 */
class PrayerTimesWidgetProvider : HomeWidgetProvider() {

    companion object {
        private const val ROLLOVER_REQUEST_CODE = 4202
        private val ROW_IDS = intArrayOf(R.id.row_0, R.id.row_1, R.id.row_2, R.id.row_3, R.id.row_4)
        private val NAME_IDS = intArrayOf(R.id.name_0, R.id.name_1, R.id.name_2, R.id.name_3, R.id.name_4)
        private val TIME_IDS = intArrayOf(R.id.time_0, R.id.time_1, R.id.time_2, R.id.time_3, R.id.time_4)
        private val NORMAL = Color.parseColor("#D6F0E4")
        private val HIGHLIGHT = Color.parseColor("#FFD27A")
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val data = PrayerWidgetCommon.read(widgetData)
        val next = data?.let { PrayerWidgetCommon.nextPrayer(it) }
        if (next != null) {
            PrayerWidgetCommon.scheduleRollover(
                context, PrayerTimesWidgetProvider::class.java, ROLLOVER_REQUEST_CODE, next.epochMillis
            )
        }

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.prayer_widget_large)
            if (data != null && next != null) {
                views.setViewVisibility(R.id.widget_header, View.VISIBLE)
                views.setViewVisibility(R.id.widget_rows, View.VISIBLE)
                views.setViewVisibility(R.id.widget_placeholder, View.GONE)
                views.setTextViewText(R.id.widget_label, data.label)
                views.setTextViewText(R.id.widget_name, "${next.name}  ${next.time}")
                views.setTextViewText(R.id.widget_remaining, data.remainingLabel)
                PrayerWidgetCommon.startCountdown(views, R.id.widget_countdown, next)

                for (i in 0 until 5) {
                    val isNext = i == next.index
                    views.setTextViewText(NAME_IDS[i], bold(data.names[i], isNext))
                    views.setTextViewText(TIME_IDS[i], bold(data.times[i], isNext))
                    views.setTextColor(NAME_IDS[i], if (isNext) HIGHLIGHT else NORMAL)
                    views.setTextColor(TIME_IDS[i], if (isNext) HIGHLIGHT else NORMAL)
                    views.setInt(
                        ROW_IDS[i], "setBackgroundResource",
                        if (isNext) R.drawable.prayer_widget_row_highlight else R.drawable.prayer_widget_row_plain
                    )
                }
            } else {
                views.setViewVisibility(R.id.widget_header, View.GONE)
                views.setViewVisibility(R.id.widget_rows, View.GONE)
                views.setViewVisibility(R.id.widget_placeholder, View.VISIBLE)
                views.setTextViewText(R.id.widget_placeholder, data?.placeholder ?: "")
                views.setChronometer(R.id.widget_countdown, SystemClock.elapsedRealtime(), null, false)
            }
            PrayerWidgetCommon.applyDirection(views, R.id.widget_root, data)
            PrayerWidgetCommon.setOpenAppOnClick(context, views, R.id.widget_root)
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun bold(text: String, on: Boolean): CharSequence {
        if (!on) return text
        return SpannableString(text).apply { setSpan(StyleSpan(Typeface.BOLD), 0, length, 0) }
    }
}
