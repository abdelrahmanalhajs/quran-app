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
import java.util.Calendar

/**
 * Shared logic for the home-screen prayer widgets ([PrayerWidgetProvider],
 * [PrayerTimesWidgetProvider]). The Flutter side (lib/core/services/
 * prayer_widget.dart) saves today's five prayer times and their localized
 * names via home_widget; each widget picks the next prayer relative to "now"
 * whenever it renders, so it advances through the day on its own.
 */
internal object PrayerWidgetCommon {

    data class Data(
        val times: List<String>,
        val names: List<String>,
        val label: String,
        val placeholder: String,
        val isArabic: Boolean,
    )

    data class NextPrayer(val index: Int, val name: String, val time: String, val epochMillis: Long)

    fun read(widgetData: SharedPreferences): Data? {
        val label = widgetData.getString("prayer_label", "Next prayer") ?: "Next prayer"
        val placeholder = widgetData.getString("prayer_placeholder", "Open the app to set your location")
            ?: "Open the app to set your location"
        val isArabic = (widgetData.getString("prayer_lang", "ar") ?: "ar") == "ar"
        val times = widgetData.getString("prayer_times", null)?.split(",")
        val names = widgetData.getString("prayer_names", null)?.split(",")
        if (times == null || names == null || times.size != 5 || names.size != 5) {
            return Data(emptyList(), emptyList(), label, placeholder, isArabic)
        }
        return Data(times, names, label, placeholder, isArabic)
    }

    /** First prayer time still ahead of now; if all have passed, Fajr tomorrow. */
    fun nextPrayer(data: Data): NextPrayer? {
        if (data.times.size != 5) return null
        val now = Calendar.getInstance()
        for (i in data.times.indices) {
            val cal = atTime(data.times[i]) ?: continue
            if (cal.after(now)) return NextPrayer(i, data.names[i], data.times[i], cal.timeInMillis)
        }
        val fajr = atTime(data.times[0]) ?: return null
        fajr.add(Calendar.DAY_OF_YEAR, 1)
        return NextPrayer(0, data.names[0], data.times[0], fajr.timeInMillis)
    }

    /** Starts [chronometerId] counting down to [next]. */
    fun startCountdown(views: RemoteViews, chronometerId: Int, next: NextPrayer) {
        val base = SystemClock.elapsedRealtime() + (next.epochMillis - System.currentTimeMillis())
        views.setChronometer(chronometerId, base, null, true)
        views.setChronometerCountDown(chronometerId, true)
    }

    /** Lays the widget out right-to-left when the app is in Arabic. */
    fun applyDirection(views: RemoteViews, rootId: Int, data: Data?) {
        views.setInt(
            rootId, "setLayoutDirection",
            if (data?.isArabic != false) android.view.View.LAYOUT_DIRECTION_RTL
            else android.view.View.LAYOUT_DIRECTION_LTR
        )
    }

    fun setOpenAppOnClick(context: Context, views: RemoteViews, rootId: Int) {
        context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { launch ->
            val pending = PendingIntent.getActivity(
                context, 0, launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(rootId, pending)
        }
    }

    /**
     * Wakes [provider] up exactly when the shown prayer's time arrives, so
     * the widget re-renders onto the *next* prayer immediately instead of
     * waiting for the 30-minute periodic update. A Chronometer never rolls
     * over on its own — it just counts past zero into negative time.
     */
    fun scheduleRollover(context: Context, provider: Class<*>, requestCode: Int, epochMillis: Long) {
        val intent = Intent(context, provider).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            val ids = AppWidgetManager.getInstance(context)
                .getAppWidgetIds(ComponentName(context, provider))
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        val pending = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pending)
        try {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMillis + 1000, pending)
        } catch (_: SecurityException) {
            // Exact-alarm permission not granted (Android 13+) — the periodic
            // update still applies; this only makes the rollover instant.
            alarmManager.set(AlarmManager.RTC_WAKEUP, epochMillis + 1000, pending)
        }
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
