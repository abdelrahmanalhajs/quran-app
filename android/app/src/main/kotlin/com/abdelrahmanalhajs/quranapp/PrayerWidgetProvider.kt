package com.abdelrahmanalhajs.quranapp

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Small (2x1) home-screen widget: the next prayer, its time, and a live
 * countdown to it. The countdown is a [android.widget.Chronometer] in
 * count-down mode, which ticks on the home screen without waking the app.
 * See [PrayerTimesWidgetProvider] for the larger widget with all five times.
 */
class PrayerWidgetProvider : HomeWidgetProvider() {

    companion object {
        private const val ROLLOVER_REQUEST_CODE = 4201
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
                context, PrayerWidgetProvider::class.java, ROLLOVER_REQUEST_CODE, next.epochMillis
            )
        }

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.prayer_widget)
            if (next != null) {
                views.setViewVisibility(R.id.widget_row, View.VISIBLE)
                views.setViewVisibility(R.id.widget_countdown, View.VISIBLE)
                views.setViewVisibility(R.id.widget_label, View.GONE)
                views.setTextViewText(R.id.widget_name, next.name)
                views.setTextViewText(R.id.widget_time, next.time)
                PrayerWidgetCommon.startCountdown(views, R.id.widget_countdown, next)
            } else {
                views.setViewVisibility(R.id.widget_row, View.GONE)
                views.setViewVisibility(R.id.widget_countdown, View.GONE)
                views.setViewVisibility(R.id.widget_label, View.VISIBLE)
                views.setTextViewText(R.id.widget_label, data?.placeholder ?: "")
                views.setChronometer(R.id.widget_countdown, SystemClock.elapsedRealtime(), null, false)
            }
            PrayerWidgetCommon.applyDirection(views, R.id.widget_root, data)
            PrayerWidgetCommon.setOpenAppOnClick(context, views, R.id.widget_root)
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
