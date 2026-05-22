package app.unrecorded.unrecorded_mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

// Minimal home screen widget — reads only status strings from HomeWidget storage.
// No scan payloads or device identifiers are stored.
class UnrecordedWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val status = widgetData.getString("widget_status", "Scanning paused") ?: "Scanning paused"
        val secondary = widgetData.getString("widget_secondary", "Tap to open") ?: "Tap to open"

        for (id in appWidgetIds) {
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openAppPendingIntent = PendingIntent.getActivity(
                context,
                id,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            val views = RemoteViews(context.packageName, R.layout.unrecorded_widget).apply {
                setTextViewText(R.id.widget_status, status)
                setTextViewText(R.id.widget_secondary, secondary)
                setOnClickPendingIntent(R.id.widget_root, openAppPendingIntent)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
