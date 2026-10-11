package com.anni.music

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.view.KeyEvent
import android.widget.RemoteViews
import com.ryanheise.audioservice.MediaButtonReceiver

class AnniMusicWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val PREFS_NAME = "AnniMusicWidgetPrefs"
        private const val KEY_TITLE = "widget_track_title"
        private const val KEY_ARTIST = "widget_track_artist"
        private const val KEY_IS_PLAYING = "widget_is_playing"

        fun updateWidgetState(
            context: Context,
            title: String,
            artist: String,
            isPlaying: Boolean
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putString(KEY_TITLE, title)
                .putString(KEY_ARTIST, artist)
                .putBoolean(KEY_IS_PLAYING, isPlaying)
                .apply()

            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, AnniMusicWidgetProvider::class.java)
            val widgetIds = manager.getAppWidgetIds(component)
            if (widgetIds.isNotEmpty()) {
                val intent = Intent(context, AnniMusicWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
                }
                context.sendBroadcast(intent)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val homeWidgetPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

        val title = prefs.getString(KEY_TITLE, null)
            ?: homeWidgetPrefs.getString("title", "Anni Music")
            ?: "Anni Music"
        val artist = prefs.getString(KEY_ARTIST, null)
            ?: homeWidgetPrefs.getString("artist", "Your music. Your world.")
            ?: "Your music. Your world."
        val isPlaying = if (prefs.contains(KEY_IS_PLAYING)) {
            prefs.getBoolean(KEY_IS_PLAYING, false)
        } else {
            homeWidgetPrefs.getBoolean("isPlaying", false)
        }

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.anni_widget_layout)
            views.setTextViewText(R.id.widget_track_title, title)
            views.setTextViewText(R.id.widget_track_artist, artist)
            views.setImageViewResource(
                R.id.widget_btn_play_pause,
                if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
            )

            val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            // Tap root widget opens Anni Music MainActivity
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val launchPendingIntent = PendingIntent.getActivity(context, 0, launchIntent, pendingFlags)
            views.setOnClickPendingIntent(R.id.widget_root, launchPendingIntent)

            // Play / Pause Media Button Intent
            views.setOnClickPendingIntent(
                R.id.widget_btn_play_pause,
                buildMediaButtonPendingIntent(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, 101, pendingFlags)
            )

            // Next Track Media Button Intent
            views.setOnClickPendingIntent(
                R.id.widget_btn_next,
                buildMediaButtonPendingIntent(context, KeyEvent.KEYCODE_MEDIA_NEXT, 102, pendingFlags)
            )

            // Previous Track Media Button Intent
            views.setOnClickPendingIntent(
                R.id.widget_btn_prev,
                buildMediaButtonPendingIntent(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS, 103, pendingFlags)
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun buildMediaButtonPendingIntent(
        context: Context,
        keyCode: Int,
        requestCode: Int,
        flags: Int
    ): PendingIntent {
        val intent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            component = ComponentName(context, MediaButtonReceiver::class.java)
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        }
        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }
}
