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
