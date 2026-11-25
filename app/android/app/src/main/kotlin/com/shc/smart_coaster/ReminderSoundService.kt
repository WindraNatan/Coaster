package com.shc.smart_coaster

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log

// Putar audio pengingat di foreground service agar tetap hidup sampai onCompletion.
// Kanal notifikasi Android 8+ mengunci suara, sehingga pemutaran dilakukan di sini.
class ReminderSoundService : Service() {
    private var player: MediaPlayer? = null
    private var wake: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Lepas pemutar lama dulu agar alarm beruntun tidak menumpuk audio.
        releasePlayer()
        val sound = intent?.getStringExtra("sound")
        val vibrate = intent?.getBooleanExtra("vibrate", true) ?: true
        startForegroundWithNotification(vibrate)

        val pm = getSystemService(POWER_SERVICE) as PowerManager
        wake = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "shc:reminderAudio").apply {
            acquire(120000)
        }

        try {
            player = MediaPlayer().apply {
                setAudioAttributes(Reminder.alarmAttributes())
                setDataSource(this@ReminderSoundService, Reminder.soundUri(this@ReminderSoundService, sound))
                setOnCompletionListener { stopSelfSafely() }
                setOnErrorListener { _, _, _ ->
                    stopSelfSafely()
                    true
                }
                prepare()
                start()
            }
        } catch (e: Exception) {
            Log.w("shc", "audio pengingat gagal: ${e.message}")
            stopSelfSafely()
        }
        // Jangan ulang audio jika proses dibunuh sistem.
        return START_NOT_STICKY
    }

    private fun startForegroundWithNotification(vibrate: Boolean) {
        val n = Reminder.buildNotification(this, vibrate)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                Reminder.NOTIF_ID, n,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(Reminder.NOTIF_ID, n)
        }
    }

    private fun releasePlayer() {
        try {
            player?.release()
        } catch (_: Exception) {
        }
        player = null
        wake?.takeIf { it.isHeld }?.release()
        wake = null
    }

    private fun stopSelfSafely() {
        releasePlayer()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_DETACH)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(false)
        }
        stopSelf()
    }

    override fun onDestroy() {
        releasePlayer()
        super.onDestroy()
    }
}
