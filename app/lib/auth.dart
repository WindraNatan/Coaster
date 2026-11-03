// Login Firebase (Email/Password) lewat REST, tanpa SDK. Token disimpan di
// SharedPreferences dan ditempel ke setiap request RTDB sebagai ?auth=..., karena rules
// menolak akses anonim.
// ponytail: satu akun pemilik, bukan multi-user. Kalau nanti tiap coaster punya pemilik
// sendiri, ganti pembatas path jadi /users/{uid}/smart_coaster dan rules-nya cukup $uid.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'project_config.dart';

const _kToken = 'shc_id_token';
const _kExp = 'shc_id_token_exp';
const _kEmail = 'shc_auth_email';
const _kUid = 'shc_uid';
const _kRefresh = 'shc_refresh_token';
const _kApiKey = 'shc_api_key';
const _kDeviceUid = 'shc_device_uid';

/// Perpanjang ID token memakai refresh token, tanpa minta password lagi.
Future<AuthSession?> refreshSession(AuthSession s, {http.Client? client}) async {
  final key = await loadApiKey();
  if (key.isEmpty || s.refreshToken.isEmpty) return null;
  final c = client ?? http.Client();
  try {
    final res = await c
        .post(
          Uri.parse(
              'https://securetoken.googleapis.com/v1/token?key=${Uri.encodeComponent(key)}'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: 'grant_type=refresh_token&refresh_token=${Uri.encodeComponent(s.refreshToken)}',
        )
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final token = data['id_token']?.toString() ?? '';
    if (token.isEmpty) return null;
    final expiresIn = int.tryParse(data['expires_in']?.toString() ?? '3600') ?? 3600;
    final session = AuthSession(
        token,
        s.email,
        s.uid,
        DateTime.now().millisecondsSinceEpoch + expiresIn * 1000,
        data['refresh_token']?.toString() ?? s.refreshToken,
        s.deviceUid);
    await saveSession(session);
    return session;
  } catch (_) {
    return null;
  } finally {
    if (client == null) c.close();
  }
}

const authErrorText = <String, String>{
  'EMAIL_EXISTS': 'Email ini sudah terdaftar. Pakai tombol Masuk.',
  'WEAK_PASSWORD': 'Password minimal 6 karakter.',
  'MISSING_PASSWORD': 'Password wajib diisi.',
  'EMAIL_NOT_FOUND': 'Email belum terdaftar di Firebase Authentication.',
  'INVALID_PASSWORD': 'Password salah.',
  'INVALID_LOGIN_CREDENTIALS': 'Email atau password salah.',
  'INVALID_EMAIL': 'Format email tidak valid.',
  'USER_DISABLED': 'Akun ini dinonaktifkan.',
  'TOO_MANY_ATTEMPTS_TRY_LATER': 'Terlalu banyak percobaan. Coba lagi nanti.',
  'CONFIGURATION_NOT_FOUND': 'API key salah atau Authentication belum diaktifkan.',
};

class AuthSession {
  final String token;
  final String email;
  final String uid;
  final int expiresAtMs;
  final String refreshToken;

  /// UID alat yang ditautkan akun ini. Berbeda dari [uid] (UID akun): data
  /// telemetri hidup di node milik alat, sama seperti firmware dan web PWA.
  final String deviceUid;

  const AuthSession(this.token, this.email, this.uid, this.expiresAtMs,
      [this.refreshToken = '', this.deviceUid = '']);

  bool get valid =>
      token.isNotEmpty &&
      uid.isNotEmpty &&
      DateTime.now().millisecondsSinceEpoch < expiresAtMs - 300000;

  String get suffix => token.isEmpty ? '' : '?auth=${Uri.encodeComponent(token)}';

  /// Node data milik alat. Kalau alat belum ditautkan, jatuh ke node akun supaya
  /// instalasi lama tetap berfungsi; [AuthSession.hasDevice] membedakan keduanya
  /// bagi pemanggil yang perlu tahu.
  String coasterUrl(String base) => '$base/users/'
      '${Uri.encodeComponent(deviceUid.isEmpty ? uid : deviceUid)}/smart_coaster';

  bool get hasDevice => deviceUid.isNotEmpty;

  AuthSession copyWith({String? deviceUid, String? refreshToken}) => AuthSession(
      token, email, uid, expiresAtMs, refreshToken ?? this.refreshToken,
      deviceUid ?? this.deviceUid);
}

/// Klaim kode alat 8 karakter: baca `/claims/<kode>`, lalu tulis tautan
/// `/links/<uid akun>/<uid alat>`. Rules menolak kalau kode tidak menunjuk alat itu.
Future<String> claimDevice({
  required String base,
  required String code,
  required AuthSession session,
  http.Client? client,
}) async {
  final c = client ?? http.Client();
  final clean = code.trim().toUpperCase();
  if (clean.length != 8) throw Exception('Kode alat harus 8 karakter.');
  try {
    final res = await c
        .get(Uri.parse('$base/claims/${Uri.encodeComponent(clean)}.json${session.suffix}'))
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) throw Exception('Gagal membaca kode (HTTP ${res.statusCode}).');
    final deviceUid = jsonDecode(res.body);
    if (deviceUid is! String || deviceUid.isEmpty) {
      throw Exception('Kode tidak dikenali. Cek lagi di Serial Monitor (115200 baud).');
    }
    final put = await c
        .put(
          Uri.parse('$base/links/${Uri.encodeComponent(session.uid)}/'
              '${Uri.encodeComponent(deviceUid)}.json${session.suffix}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'code': clean, 'at': DateTime.now().millisecondsSinceEpoch}),
        )
        .timeout(const Duration(seconds: 12));
    if (put.statusCode != 200) {
      throw Exception('Gagal menautkan alat (HTTP ${put.statusCode}).');
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(_kDeviceUid, deviceUid);
    return deviceUid;
  } catch (e) {
    if (e is Exception) rethrow;
    throw Exception('Gagal menautkan alat: jaringan bermasalah.');
  } finally {
    if (client == null) c.close();
  }
}

/// Baca tautan yang sudah ada di `/links/<uid akun>`, supaya menginstal ulang
/// aplikasi tidak perlu mengetik kode alat lagi. Nilai kosong kalau belum ada
/// tautan.
///
/// Butuh `.read` di level `links/$ownerUid` pada firebase-rules.json: izin RTDB
/// tidak naik ke node induk, jadi `.read` yang hanya ada di `$deviceUid` membuat
/// permintaan ini selalu 401.
Future<String> discoverDevice({
  required String base,
  required AuthSession session,
  http.Client? client,
}) async {
  final c = client ?? http.Client();
  try {
    final res = await c
        .get(Uri.parse(
            '$base/links/${Uri.encodeComponent(session.uid)}.json${session.suffix}'))
        // Timeout pendek: ini jalur bonus. Kalau gagal, boot tetap lanjut dengan
        // node akun, dan pengguna masih bisa menautkan manual lewat tombol.
        .timeout(const Duration(seconds: 4));
    if (res.statusCode != 200) return '';
    final data = jsonDecode(res.body);
    if (data is! Map || data.isEmpty) return '';
    // Bisa ada lebih dari satu alat; pakai yang terakhir ditautkan.
    String best = '';
    var bestAt = -1;
    data.forEach((k, v) {
      if (k is! String || k.isEmpty) return;
      final at = v is Map ? (v['at'] as num?)?.toInt() ?? 0 : 0;
      if (at >= bestAt) {
        bestAt = at;
        best = k;
      }
    });
    return best;
  } catch (_) {
    // Jaringan/aturan bermasalah bukan kegagalan boot: tetap pakai fallback.
    return '';
  } finally {
    if (client == null) c.close();
  }
}

/// UID alat yang sudah ditautkan, atau kosong. Dipakai saat boot sebelum
/// [claimDevice] pernah dipanggil di perangkat ini.
Future<String> loadDeviceUid() async {
  final p = await SharedPreferences.getInstance();
  return p.getString(_kDeviceUid) ?? '';
}

/// Simpan sesi ke penyimpanan lokal. Nilai kosong menghapus semuanya.
Future<void> saveSession(AuthSession? s) async {
  final p = await SharedPreferences.getInstance();
  if (s == null) {
    await p.remove(_kToken);
    await p.remove(_kExp);
    await p.remove(_kEmail);
    await p.remove(_kUid);
    await p.remove(_kRefresh);
    await p.remove(_kDeviceUid);
    return;
  }
  await p.setString(_kToken, s.token);
  await p.setInt(_kExp, s.expiresAtMs);
  await p.setString(_kEmail, s.email);
  await p.setString(_kUid, s.uid);
  if (s.refreshToken.isNotEmpty) await p.setString(_kRefresh, s.refreshToken);
  // Harus menimpa, bukan hanya menulis saat terisi: kalau dibiarkan, akun B
  // yang login setelah akun A mewarisi UID alat A, melewati penemuan tautan,
  // dan membaca node milik akun lain.
  if (s.deviceUid.isEmpty) {
    await p.remove(_kDeviceUid);
  } else {
    await p.setString(_kDeviceUid, s.deviceUid);
  }
}

Future<AuthSession?> loadSession() async {
  final p = await SharedPreferences.getInstance();
  final token = p.getString(_kToken) ?? '';
  if (token.isEmpty) return null;
  return AuthSession(token, p.getString(_kEmail) ?? '',
      p.getString(_kUid) ?? '', p.getInt(_kExp) ?? 0,
      p.getString(_kRefresh) ?? '', p.getString(_kDeviceUid) ?? '');
}

// Nilai tersimpan (diketik pengguna) menang; kalau kosong, pakai tetapan build.
// refreshSession() memakai fungsi ini, jadi tanpa cadangan tetapan, instalasi
// baru berhasil login sekali lalu kehilangan sesi setelah token kedaluwarsa.
Future<String> loadApiKey() async {
  final p = await SharedPreferences.getInstance();
  final stored = (p.getString(_kApiKey) ?? '').trim();
  return stored.isNotEmpty ? stored : kFirebaseApiKey;
}

Future<void> saveApiKey(String key) async {
  final p = await SharedPreferences.getInstance();
  await p.setString(_kApiKey, key.trim());
}

/// Tukar email+password jadi ID token. Melempar pesan siap tampil kalau gagal.
Future<AuthSession> signIn({
  required String email,
  required String password,
  required String apiKey,
  bool register = false,
  http.Client? client,
}) async {
  if (apiKey.trim().isEmpty) throw Exception('Isi Web API Key proyek Firebase dulu.');
  final c = client ?? http.Client();
  try {
    final res = await c
        .post(
          Uri.parse('https://identitytoolkit.googleapis.com/v1/'
              '${register ? 'accounts:signUp' : 'accounts:signInWithPassword'}'
              '?key=${Uri.encodeComponent(apiKey.trim())}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(
              {'email': email.trim(), 'password': password, 'returnSecureToken': true}),
        )
        .timeout(const Duration(seconds: 12));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      final code =
          (data['error'] as Map?)?['message']?.toString().split(' ').first ?? 'HTTP ${res.statusCode}';
      throw Exception(authErrorText[code] ?? code);
    }
    final token = data['idToken']?.toString() ?? '';
    final expiresIn = int.tryParse(data['expiresIn']?.toString() ?? '3600') ?? 3600;
    final uid = data['localId']?.toString() ?? '';
    if (uid.isEmpty) throw Exception('Respons Firebase tidak memuat UID.');
    final session = AuthSession(
        token,
        data['email']?.toString() ?? email.trim(),
        uid,
        DateTime.now().millisecondsSinceEpoch + expiresIn * 1000,
        data['refreshToken']?.toString() ?? '');
    await saveSession(session);
    return session;
  } finally {
    if (client == null) c.close();
  }
}
