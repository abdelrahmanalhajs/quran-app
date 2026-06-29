package com.abdelrahmanalhajs.quranapp

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.SystemClock
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Calendar

/**
 * Home-screen widget showing the next prayer and a live countdown to it.
 *
 * The Flutter side saves the five prayer times (and their localized names)
 * via home_widget; this provider picks the next one relative to "now" each
 * time it renders, so the widget advances through the day on its own. The
 * countdown is an Android [android.widget.Chronometer] in count-down mode,
 * which ticks on the home screen by itself without waking the app.
 *
 * The Chronometer itself never "rolls over" to the next prayer on its own —
 * once its target time passes it just keeps counting past zero showing a
 * meaningless negative duration until something re-renders the widget. The
 * OS-driven [updatePeriodMillis] (android/app/src/main/res/xml/prayer_widget_info.xml)
 * is every 30 minutes, so without [scheduleRollover] the widget could sit
 * showing that stale/negative countdown for up to half an hour after a
 * prayer's time actually arrives instead of immediately switching to the
 * next one — the exact bug being fixed here.
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
        // "HH:mm,HH:mm,HH:mm,HH:mm,HH:mm" for fajr,dhuhr,asr,maghrib,isha.
        val times = widgetData.getString("prayer_times", null)?.split(",")
        // Matching localized names, same order.
        val names = widgetData.getString("prayer_names", null)?.split(",")
        val placeholder = widgetData.getString("prayer_placeholder", "Open the app to set your location")

        val next = if (times != null && times.size == 5 && names != null && names.size == 5) {
            nextPrayer(times, names)
        } else null

        if (next != null) {
            scheduleRollover(context, next.epochMillis)
        }

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.prayer_widget)

            if (next != null) {
                views.setViewVisibility(R.id.widget_row, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.widget_countdown, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.widget_label, android.view.View.GONE)
                views.setTextViewText(R.id.widget_name, next.name)
                views.setTextViewText(R.id.widget_time, next.time)
                val base = SystemClock.elapsedRealtime() +
                    (next.epochMillis - System.currentTimeMillis())
                views.setChronometer(R.id.widget_countdown, base, null, true)
                views.setChronometerCountDown(R.id.widget_countdown, true)
            } else {
                views.setViewVisibility(R.id.widget_row, android.view.View.GONE)
                views.setViewVisibility(R.id.widget_countdown, android.view.View.GONE)
                views.setViewVisibility(R.id.widget_label, android.view.View.VISIBLE)
                views.setTextViewText(R.id.widget_label, placeholder)
                views.setChronometer(R.id.widget_countdown, SystemClock.elapsedRealtime(), null, false)
            }

            context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { launch ->
                val pending = PendingIntent.getActivity(
                    context, 0, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pending)
            }

            appWidgetManager.updateAppWidget(id, views)
        }
    }

    /**
     * Wakes this provider up exactly when the currently-shown prayer's time
     * arrives, so the widget re-renders onto the *next* prayer immediately
     * instead of waiting for the next periodic update (up to 30 minutes
     * late, displaying a stale/negative countdown in the meantime).
     */
    private fun scheduleRollover(context: Context, epochMillis: Long) {
        val intent = Intent(context, PrayerWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            val ids = AppWidgetManager.getInstance(context)
                .getAppWidgetIds(ComponentName(context, PrayerWidgetProvider::class.java))
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        val pending = PendingIntent.getBroadcast(
            context,
            ROLLOVER_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pending)
        try {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                epochMillis + 1000,
                pending
            )
        } catch (_: SecurityException) {
            // Exact-alarm permission not granted (Android 13+ without the
            // user's OK) — the 30-minute periodic update still applies, this
            // is purely the "make it instant" improvement on top of that.
            alarmManager.set(AlarmManager.RTC_WAKEUP, epochMillis + 1000, pending)
        }
    }

    private data class NextPrayer(val name: String, val time: String, val epochMillis: Long)

    /** First prayer time still ahead of now; if all have passed, Fajr tomorrow. */
    private fun nextPrayer(times: List<String>, names: List<String>): NextPrayer? {
        val now = Calendar.getInstance()
        for (i in times.indices) {
            val cal = atTime(times[i]) ?: continue
            if (cal.after(now)) {
                return NextPrayer(names[i], times[i], cal.timeInMillis)
            }
        }
        val fajr = atTime(times[0]) ?: return null
        fajr.add(Calendar.DAY_OF_YEAR, 1)
        return NextPrayer(names[0], times[0], fajr.timeInMillis)
    }

    private fun atTime(hhmm: String): Calendar? {
        val parts = hhmm.split(":")
        if (parts.size != 2) return null
        val h = parts[0].toIntOrNull() ?: return null
        val m = parts[1].toIntOrNull() ?: return null
        return Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, h)
            set(Calendar.MINUTE, m)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
    }
}
