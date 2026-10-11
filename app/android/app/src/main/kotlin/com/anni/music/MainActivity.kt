package com.anni.music

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.media.audiofx.AudioEffect
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : AudioServiceFragmentActivity() {
    companion object {
        private const val CHANNEL = "com.anni.music/native_audio"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setRingtone" -> {
                    val filePath = call.argument<String>("filePath")
                    val title = call.argument<String>("title") ?: "Anni Ringtone"
                    if (filePath.isNullOrBlank()) {
                        result.error("INVALID_ARGUMENTS", "filePath is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val success = setDeviceRingtone(filePath, title)
                        result.success(success)
                    } catch (e: Exception) {
                        result.error("RINGTONE_ERROR", e.localizedMessage ?: "Failed to set ringtone", null)
                    }
                }
                "openEqualizerSession" -> {
                    val audioSessionId = call.argument<Int>("audioSessionId") ?: 0
                    try {
                        val intent = Intent(AudioEffect.ACTION_DISPLAY_AUDIO_EFFECT_CONTROL_PANEL).apply {
                            putExtra(AudioEffect.EXTRA_AUDIO_SESSION, audioSessionId)
                            putExtra(AudioEffect.EXTRA_PACKAGE_NAME, applicationContext.packageName)
                            putExtra(AudioEffect.EXTRA_CONTENT_TYPE, AudioEffect.CONTENT_TYPE_MUSIC)
                        }
                        if (intent.resolveActivity(packageManager) != null) {
                            startActivityForResult(intent, 1001)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("EQUALIZER_ERROR", e.localizedMessage ?: "Failed to open equalizer", null)
                    }
                }
                "updateHomeWidget" -> {
                    val title = call.argument<String>("title") ?: "Anni Music"
                    val artist = call.argument<String>("artist") ?: "Your music. Your world."
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                    try {
                        AnniMusicWidgetProvider.updateWidgetState(
                            applicationContext,
                            title = title,
                            artist = artist,
                            isPlaying = isPlaying
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WIDGET_ERROR", e.localizedMessage ?: "Failed to update home widget", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setDeviceRingtone(filePath: String, title: String): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.System.canWrite(applicationContext)) {
            val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS).apply {
                data = Uri.parse("package:${applicationContext.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            return false
        }

        val sourceFile = File(filePath)
        if (!sourceFile.exists()) {
            return false
        }

        val resolver = applicationContext.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, "${title.replace("[^a-zA-Z0-9 _-]".toRegex(), "")}.mp3")
            put(MediaStore.MediaColumns.TITLE, title)
            put(MediaStore.MediaColumns.MIME_TYPE, "audio/mpeg")
            put(MediaStore.Audio.Media.IS_RINGTONE, true)
            put(MediaStore.Audio.Media.IS_NOTIFICATION, false)
            put(MediaStore.Audio.Media.IS_ALARM, false)
            put(MediaStore.Audio.Media.IS_MUSIC, false)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.MediaColumns.RELATIVE_PATH, "Ringtones/AnniMusic")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
        }

        val collectionUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }

        val newUri = resolver.insert(collectionUri, values) ?: return false

        resolver.openOutputStream(newUri)?.use { outputStream ->
            FileInputStream(sourceFile).use { inputStream ->
                inputStream.copyTo(outputStream)
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val completeValues = ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }
            resolver.update(newUri, completeValues, null, null)
        }

        RingtoneManager.setActualDefaultRingtoneUri(
            applicationContext,
            RingtoneManager.TYPE_RINGTONE,
            newUri
        )
        return true
    }
}
