import 'dart:io';

import 'package:flutter/services.dart';

/// Jembatan MethodChannel ke pengingat native (audio diputar service terpisah).
class ReminderService {
  static const _ch = MethodChannel('shc/reminder');

  /// Batas bawah agar alarm tidak di masa lalu sambil tetap mendukung demo 15 detik.
  static const minLead = Duration(seconds: 5);

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

  static Future<bool> preview(String? sound) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _ch.invokeMethod<bool>('preview', {'sound': sound}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Android 13+ mewajibkan izin runtime POST_NOTIFICATIONS.
  static Future<bool> canNotify() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _ch.invokeMethod<bool>('canNotify') ?? false;
    } catch (_) {
      return false;
    }
  }

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

/// Hanya state siklus minum yang boleh menjadwalkan pengingat.
bool stateAllowsReminder(String canonicalState) =>
    canonicalState == 'ALERT_DRINK' ||
    canonicalState == 'TIMING' ||
    canonicalState == 'STABLE';

/// Bandingkan deadline absolut agar siklus demo 15 detik tidak terlewat.
/// Toleransi menahan penjadwalan ulang pada setiap event stream.
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
