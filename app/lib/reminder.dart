import 'dart:io';

import 'package:flutter/services.dart';

/// Jembatan ke lapisan native pengingat minum.
///
/// Suara pilihan pengguna tidak bisa dipasang ke kanal notifikasi Android 8+,
/// karena suara kanal terkunci saat kanal dibuat. Karena itu lapisan native
/// memutar file audio sendiri, sementara notifikasi tetap tampil di layar.
class ReminderService {
  static const _ch = MethodChannel('shc/reminder');

  /// Batas bawah hanya untuk mencegah alarm di masa lalu. Nilai ini TIDAK boleh
  /// membulatkan jadwal alat: mode demo memakai interval 15 dtk, dan clamp satu
  /// menit dulu membuat alarm berbunyi setelah minum sudah lewat.
  static const minLead = Duration(seconds: 5);

  /// Menaikkan lead hanya bila alarm jatuh di masa lalu. Dipisah supaya bisa
  /// diuji tanpa Android.
  static Duration clampLead(Duration lead) => lead < minLead ? minLead : lead;

  static Future<bool> ensureChannel() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _ch.invokeMethod<bool>('ensureChannel') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> schedule({
    required Duration lead,
    String? sound,
    bool vibrate = true,
  }) async {
    if (!Platform.isAndroid) return false;
    final at = DateTime.now().add(clampLead(lead));
    try {
      return await _ch.invokeMethod<bool>('schedule', {
        'atMs': at.millisecondsSinceEpoch,
        'sound': sound,
        'vibrate': vibrate,
      }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> cancel() async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('cancel');
    } catch (_) {}
  }

  /// Memutar cuplikan audio pilihan pengguna tanpa menampilkan notifikasi.
  static Future<bool> preview(String? sound) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _ch.invokeMethod<bool>('preview', {'sound': sound}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Izin alarm tepat waktu (Android 12+). Tanpa izin, pengingat masih jalan
  /// tetapi bisa meleset beberapa menit.
  /// Android 13+ mewajibkan izin runtime; deklarasi manifest saja tidak cukup.
  static Future<bool> canNotify() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _ch.invokeMethod<bool>('canNotify') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Meminta izin notifikasi. Mengembalikan true bila sudah/boleh.
  static Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _ch.invokeMethod<bool>('requestNotificationPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> canExact() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _ch.invokeMethod<bool>('canExact') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<Duration?> timeLeft() async {
    if (!Platform.isAndroid) return null;
    try {
      final ms = await _ch.invokeMethod<int>('isScheduled') ?? 0;
      return ms > 0 ? Duration(milliseconds: ms) : null;
    } catch (_) {
      return null;
    }
  }
}

/// Jadwal alarm yang sedang terpasang, dipakai untuk memutuskan apakah perlu
/// dipasang ulang.
class ReminderPlan {
  final String state;
  final DateTime target;
  const ReminderPlan(this.state, this.target);

  @override
  bool operator ==(Object other) =>
      other is ReminderPlan && other.state == state && other.target == target;

  @override
  int get hashCode => Object.hash(state, target);
}

/// State yang boleh memicu pengingat. Alert isi ulang atau curang punya arti
/// berbeda; membiarkan alarmnya berbunyi berarti berbohong soal sebabnya.
bool stateAllowsReminder(String canonicalState) =>
    canonicalState == 'ALERT_DRINK' ||
    canonicalState == 'TIMING' ||
    canonicalState == 'STABLE';

/// Apakah jadwal perlu dipasang ulang.
///
/// Perbandingan memakai deadline absolut, bukan sisa detik. Ambang pada sisa
/// detik membuat siklus demo 15->0->15 selalu terlewat, sehingga alarm hanya
/// berbunyi sekali. Toleransi [tolerance] mencegah pemasangan ulang pada setiap
/// event stream; dengan poll 20 detik nilainya 10 detik, jadi tiap poll memang
/// memasang ulang, dan itu disengaja karena tiap pemasangan memakai deadline
/// baru dari sisa waktu yang baru dihitung.
bool shouldScheduleReminder({
  required String state,
  required DateTime target,
  ReminderPlan? current,
  Duration tolerance = const Duration(seconds: 10),
}) {
  if (current == null) return true;
  if (current.state != state) return true;
  final drift = target.difference(current.target).abs();
  return drift > tolerance;
}
