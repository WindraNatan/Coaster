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
                "preview" -> result.success(Reminder.preview(this, call.argument<String>("sound")))
                "isScheduled" -> result.success(Reminder.timeLeftMs(this))
                "ensureChannel" -> {
                    Reminder.ensureChannel(this)
                    result.success(true)
                }
                "canExact" -> result.success(Reminder.canExact(this))
                "canNotify" -> result.success(Reminder.canNotify(this))
                "requestNotificationPermission" -> {
                    // Manifest saja tidak cukup di Android 13+: notify() dibuang
                    // diam-diam tanpa izin runtime.
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                        Reminder.canNotify(this)
                    ) {
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

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 71) return
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == android.content.pm.PackageManager.PERMISSION_GRANTED
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
    }
}

/// Menjadwalkan pengingat minum dan menampilkan notifikasinya.
///
/// Suara pilihan pengguna TIDAK dipasang ke kanal notifikasi: Android 8+ mengunci
/// konfigurasi kanal saat dibuat, dan setiap ganti audio berarti kanal baru yang
/// menumpuk di Pengaturan. Audio diputar ReminderSoundService, notifikasi tetap
/// tampil lewat kanal bersuara senyap.
object Reminder {
    // Dua kanal dengan ID stabil: kanal menyimpan setelan getar saat dibuat, jadi
    // pilihan getar ON/OFF butuh kanal berbeda. ID-nya tetap supaya daftar kanal
    // di Pengaturan tidak tumbuh setiap pengguna mengubah pilihan.
    private const val CHANNEL_ID = "shc_reminder"
    private const val CHANNEL_ID_NO_VIB = "shc_reminder_no_vibrate"
    const val NOTIF_ID = 1001
    private const val ALARM_REQ = 2001

    fun ensureChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val mgr = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channels = listOf(
            Triple(CHANNEL_ID, "Pengingat minum", true),
            Triple(CHANNEL_ID_NO_VIB, "Pengingat minum (tanpa getar)", false)
        )
        for ((id, name, vib) in channels) {
            if (mgr.getNotificationChannel(id) != null) continue
            val c = NotificationChannel(id, name, NotificationManager.IMPORTANCE_HIGH).apply {
                // Bunyi ditangani service; kanal senyap mencegah bunyi ganda.
                setSound(null, null)
                enableVibration(vib)
                enableLights(true)
            }
            mgr.createNotificationChannel(c)
        }
    }

    private fun channelFor(vibrate: Boolean) =
        if (vibrate) CHANNEL_ID else CHANNEL_ID_NO_VIB

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
        // setExactAndAllowWhileIdle menembus Doze. Tanpa izin alarm tepat, turun ke
        // setAndAllowWhileIdle: meleset beberapa menit lebih baik daripada senyap.
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
        am.cancel(alarmIntent(ctx, null, true))
    }

    fun timeLeftMs(ctx: Context): Long {
        val prefs = ctx.getSharedPreferences("shc_reminder", Context.MODE_PRIVATE)
        val at = prefs.getLong("atMs", 0L)
        return (at - System.currentTimeMillis()).coerceAtLeast(0L)
    }

    /// Memutar cuplikan audio tanpa notifikasi, untuk tombol Uji.
    fun preview(ctx: Context, sound: String?): Boolean = try {
        val mp = MediaPlayer()
        mp.setAudioAttributes(alarmAttributes())
        mp.setDataSource(ctx, soundUri(ctx, sound))
        mp.setOnCompletionListener { it.release() }
        mp.prepare()
        mp.start()
        true
    } catch (_: Exception) {
        false
    }

    fun alarmAttributes() = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ALARM)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    fun soundUri(ctx: Context, sound: String?): Uri =
        if (sound.isNullOrEmpty()) {
            Uri.parse("android.resource://${ctx.packageName}/" + R.raw.reminder_default)
        } else {
            Uri.parse(sound)
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

    fun buildNotification(ctx: Context, vibrate: Boolean = true): Notification {
        val open = PendingIntent.getActivity(
            ctx, 0, Intent(ctx, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return Notification.Builder(ctx, channelFor(vibrate))
            .setContentTitle("Waktunya minum")
            .setContentText("Angkat gelas dan minum sedikit air.")
            // Small icon notifikasi harus drawable satu warna; launcher
            // adaptive-icon tidak boleh dipakai di sini.
            .setSmallIcon(R.drawable.ic_stat_coaster)
            .setContentIntent(open)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_ALARM)
            .build()
    }

    fun showNow(ctx: Context, sound: String?, vibrate: Boolean) {
        ensureChannel(ctx)
        val mgr = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        mgr.notify(NOTIF_ID, buildNotification(ctx, vibrate))

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
        // Audio diputar di FOREGROUND SERVICE, bukan di sini: onReceive kembali
        // segera, lalu proses boleh dibunuh dan MediaPlayer berhenti di tengah lagu.
        val svc = Intent(ctx, ReminderSoundService::class.java).putExtra("sound", sound)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ctx.startForegroundService(svc)
            } else {
                ctx.startService(svc)
            }
        } catch (_: Exception) {
            // Sebagian OEM menolak startForegroundService dari background.
            // Notifikasi sudah tampil, jadi pengingat tidak hilang.
        }
    }
}
