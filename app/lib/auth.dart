// Autentikasi Firebase REST tanpa SDK; token dikirim lewat query ?auth=.
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

  /// UID perangkat tertaut; telemetri berada di node perangkat, bukan akun.
  final String deviceUid;

  const AuthSession(this.token, this.email, this.uid, this.expiresAtMs,
      [this.refreshToken = '', this.deviceUid = '']);

  bool get valid =>
      token.isNotEmpty &&
      uid.isNotEmpty &&
      DateTime.now().millisecondsSinceEpoch < expiresAtMs - 300000;

  String get suffix => token.isEmpty ? '' : '?auth=${Uri.encodeComponent(token)}';

  String get silentSuffix => token.isEmpty
      ? '?print=silent'
      : '?auth=${Uri.encodeComponent(token)}&print=silent';

  /// Node data perangkat, fallback ke node akun jika belum ditautkan.
  String coasterUrl(String base) => '$base/users/'
      '${Uri.encodeComponent(deviceUid.isEmpty ? uid : deviceUid)}/smart_coaster';

  bool get hasDevice => deviceUid.isNotEmpty;

  AuthSession copyWith({String? deviceUid, String? refreshToken}) => AuthSession(
      token, email, uid, expiresAtMs, refreshToken ?? this.refreshToken,
      deviceUid ?? this.deviceUid);
}

/// Tautkan kode 8 karakter lewat `/claims/<kode>` lalu tulis `/links/<uid>/<deviceUid>`.
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

/// Baca tautan di `/links/<uid>` agar login ulang tidak perlu klaim lagi.
/// Butuh .read di level links/$ownerUid (izin RTDB tidak naik ke induk).
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
        // Timeout pendek agar kegagalan discovery tidak menghambat boot.
        .timeout(const Duration(seconds: 4));
    if (res.statusCode != 200) return '';
    final data = jsonDecode(res.body);
    if (data is! Map || data.isEmpty) return '';
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
    return '';
  } finally {
    if (client == null) c.close();
  }
}

/// Baca kode klaim dari /private, fallback ke node lama.
Future<String> findOwnClaimCode({
  required String base,
  required AuthSession session,
  http.Client? client,
}) async {
  if (session.uid.isEmpty || session.token.isEmpty) return '';
  final c = client ?? http.Client();
  final uid = Uri.encodeComponent(session.uid);
  final paths = [
    '$base/users/$uid/private/claimCode.json${session.suffix}',
    '$base/users/$uid/smart_coaster/claimCode.json${session.suffix}',
  ];
  try {
    for (final p in paths) {
      final res = await c.get(Uri.parse(p)).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is String && decoded.trim().isNotEmpty) {
          return decoded.trim().toUpperCase();
        }
      }
    }
    return '';
  } catch (_) {
    return '';
  } finally {
    if (client == null) c.close();
  }
}

Future<String> loadDeviceUid() async {
  final p = await SharedPreferences.getInstance();
  return p.getString(_kDeviceUid) ?? '';
}

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
  // Timpa atau hapus _kDeviceUid agar akun berikutnya tidak mewarisi perangkat lama.
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

// Fallback ke kFirebaseApiKey agar refreshSession() bekerja pada instalasi baru.
Future<String> loadApiKey() async {
  final p = await SharedPreferences.getInstance();
  final stored = (p.getString(_kApiKey) ?? '').trim();
  return stored.isNotEmpty ? stored : kFirebaseApiKey;
}

Future<void> saveApiKey(String key) async {
  final p = await SharedPreferences.getInstance();
  await p.setString(_kApiKey, key.trim());
}

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
