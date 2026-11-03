import 'dart:io';

import 'package:flutter/services.dart';

/// Jembatan ke lapisan native pengingat minum.
///
/// Suara pilihan pengguna tidak bisa dipasang ke kanal notifikasi Android 8+,
/// karena suara kanal terkunci saat kanal dibuat. Karena itu lapisan native
/// memutar file audio sendiri, sementara notifikasi tetap tampil di layar.
class ReminderService {
  static const _ch = MethodChannel('shc/reminder');

  /// Batas minimum pengingat: satu menit, supaya salah ketik tidak membuat
  /// alarm berbunyi berulang kali tanpa henti.
  static const minLead = Duration(minutes: 1);

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
    final at = DateTime.now().add(lead < minLead ? minLead : lead);
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
