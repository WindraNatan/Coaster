package com.shc.smart_coaster

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val ch = "shc/reminder"

    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 71) return
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == android.content.pm.PackageManager.PERMISSION_GRANTED
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
    }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, ch).setMethodCallHandler { call, result ->
            when (call.method) {
                "schedule" -> {
                    val atMs = (call.argument<Number>("atMs"))?.toLong() ?: 0L
                    val sound = call.argument<String>("sound")
                    val vibrate = call.argument<Boolean>("vibrate") ?: true
                    Reminder.schedule(this, atMs, sound, vibrate)
                    result.success(true)
                }
                "cancel" -> {
                    Reminder.cancel(this)
                    result.success(true)
                }
                "preview" -> {
                    val sound = call.argument<String>("sound")
                    result.success(Reminder.preview(this, sound))
                }
                "isScheduled" -> result.success(Reminder.timeLeftMs(this))
                "ensureChannel" -> {
                    Reminder.ensureChannel(this)
                    result.success(true)
                }
                "canExact" -> result.success(Reminder.canExact(this))
                "canNotify" -> result.success(Reminder.canNotify(this))
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                        result.success(true)
                    } else if (Reminder.canNotify(this)) {
                        result.success(true)
                    } else {
                        pendingPermissionResult = result
                        requestPermissions(
                            arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 71
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}

/// Menjadwalkan pengingat minum dan memutarnya dengan suara pilihan pengguna.
///
/// Kanal notifikasi Android 8+ mengunci suara saat kanal dibuat, jadi file audio
/// pilihan pengguna tidak bisa dipakai lewat konfigurasi kanal. Karena itu kanal
/// memakai suara senyap dan audionya diputar sendiri oleh receiver: MediaPlayer
/// membaca URI file milik pengguna, sementara notifikasi tetap tampil di layar.
object Reminder {
    private const val CHANNEL_ID = "shc_reminder"
    const val NOTIF_ID = 1001
    private const val ALARM_REQ = 2001
    private const val PREFS = "shc_reminder"

    fun ensureChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val mgr = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (mgr.getNotificationChannel(CHANNEL_ID) != null) return
        // setSound(null): bunyi ditangani MediaPlayer, bukan kanal. Tanpa ini,
        // notifikasi berbunyi dua kali (kanal + file pengguna).
        val c = NotificationChannel(CHANNEL_ID, "Pengingat minum", NotificationManager.IMPORTANCE_HIGH).apply {
            setSound(null, null)
            enableVibration(true)
            enableLights(true)
        }
        mgr.createNotificationChannel(c)
    }

    fun canNotify(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            val mgr = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            return mgr.areNotificationsEnabled()
        }
        return ctx.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    fun canExact(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return am.canScheduleExactAlarms()
    }

    fun schedule(ctx: Context, atMs: Long, sound: String?, vibrate: Boolean) {
        ensureChannel(ctx)
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = alarmIntent(ctx, sound, vibrate)
        // setExactAndAllowWhileIdle menembus Doze. Bila izin alarm tepat tidak ada,
        // jatuh ke setAndAllowWhileIdle: meleset beberapa menit lebih baik daripada
        // alarm yang tidak pernah berbunyi.
        try {
            if (canExact(ctx)) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, pi)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, pi)
            }
        } catch (_: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, pi)
        }
    }

    fun cancel(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(alarmIntent(ctx, null, false))
    }

    fun timeLeftMs(ctx: Context): Long {
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val at = prefs.getLong("atMs", 0L)
        return (at - System.currentTimeMillis()).coerceAtLeast(0L)
    }

    fun preview(ctx: Context, sound: String?): Boolean {
        return try {
            val mp = player(ctx, sound) ?: return false
            mp.setOnCompletionListener { it.release() }
            mp.start()
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun player(ctx: Context, sound: String?): MediaPlayer? {
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val mp = MediaPlayer()
        mp.setAudioAttributes(attrs)
        if (sound.isNullOrEmpty()) {
            mp.setDataSource(
                ctx,
                Uri.parse("android.resource://${ctx.packageName}/" + R.raw.reminder_default)
            )
        } else {
            mp.setDataSource(ctx, Uri.parse(sound))
        }
        mp.prepare()
        return mp
    }

    private fun alarmIntent(ctx: Context, sound: String?, vibrate: Boolean): PendingIntent {
        val i = Intent(ctx, ReminderReceiver::class.java).apply {
            putExtra("sound", sound)
            putExtra("vibrate", vibrate)
        }
        return PendingIntent.getBroadcast(
            ctx, ALARM_REQ, i,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /// Notifikasi yang sama dipakai service, jadi dibangun di satu tempat.
    fun buildNotification(ctx: Context): Notification {
        val open = PendingIntent.getActivity(
            ctx, 0, Intent(ctx, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return Notification.Builder(ctx, CHANNEL_ID)
            .setContentTitle("Waktunya minum")
            .setContentText("Angkat gelas dan minum sedikit air.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(open)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_ALARM)
            .build()
    }

    fun showNow(ctx: Context, sound: String?, vibrate: Boolean) {
        ensureChannel(ctx)
        val open = PendingIntent.getActivity(
            ctx, 0, Intent(ctx, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val n = buildNotification(ctx).let { base ->
            if (!vibrate) return@let base
            Notification.Builder.recoverBuilder(ctx, base)
                .setVibrate(longArrayOf(0, 400, 250, 400))
                .build()
        }
        val mgr = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        mgr.notify(NOTIF_ID, n)

        // Layar menyala supaya pengingat terlihat tanpa membuka aplikasi.
        try {
            val pm = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val wl = pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "shc:reminder"
            )
            wl.acquire(5000)
        } catch (_: Exception) {
        }
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        val sound = intent.getStringExtra("sound")
        val vibrate = intent.getBooleanExtra("vibrate", true)
        Reminder.showNow(ctx, sound, vibrate)
        // Audio diputar di FOREGROUND SERVICE, bukan di sini. onReceive kembali
        // segera setelah metode ini selesai, dan setelah itu proses aplikasi boleh
        // dimatikan: MediaPlayer lokal akan berhenti di tengah lagu.
        val svc = Intent(ctx, ReminderSoundService::class.java).putExtra("sound", sound)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ctx.startForegroundService(svc)
            } else {
                ctx.startService(svc)
            }
        } catch (_: Exception) {
            // Android 12+ menolak startForegroundService dari background pada
            // sebagian OEM. Notifikasi sudah tampil, jadi pengingat tidak hilang.
        }
    }
}
