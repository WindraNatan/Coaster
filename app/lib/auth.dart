// Login Firebase (Email/Password) lewat REST, tanpa SDK. Token disimpan di
// SharedPreferences dan ditempel ke setiap request RTDB sebagai ?auth=..., karena rules
// menolak akses anonim.
// ponytail: satu akun pemilik, bukan multi-user. Kalau nanti tiap coaster punya pemilik
// sendiri, ganti pembatas path jadi /users/{uid}/smart_coaster dan rules-nya cukup $uid.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _kToken = 'shc_id_token';
const _kExp = 'shc_id_token_exp';
const _kEmail = 'shc_auth_email';
const _kUid = 'shc_uid';
const _kRefresh = 'shc_refresh_token';
const _kApiKey = 'shc_api_key';

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
        data['refresh_token']?.toString() ?? s.refreshToken);
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
  const AuthSession(this.token, this.email, this.uid, this.expiresAtMs,
      [this.refreshToken = '']);

  bool get valid =>
      token.isNotEmpty &&
      uid.isNotEmpty &&
      DateTime.now().millisecondsSinceEpoch < expiresAtMs - 300000;

  String get suffix => token.isEmpty ? '' : '?auth=${Uri.encodeComponent(token)}';

  /// Node milik akun ini. Rules menolak akses ke /users/<uid> milik orang lain.
  String coasterUrl(String base) =>
      '$base/users/${Uri.encodeComponent(uid)}/smart_coaster';
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
    return;
  }
  await p.setString(_kToken, s.token);
  await p.setInt(_kExp, s.expiresAtMs);
  await p.setString(_kEmail, s.email);
  await p.setString(_kUid, s.uid);
  if (s.refreshToken.isNotEmpty) await p.setString(_kRefresh, s.refreshToken);
}

Future<AuthSession?> loadSession() async {
  final p = await SharedPreferences.getInstance();
  final token = p.getString(_kToken) ?? '';
  if (token.isEmpty) return null;
  return AuthSession(token, p.getString(_kEmail) ?? '',
      p.getString(_kUid) ?? '', p.getInt(_kExp) ?? 0,
      p.getString(_kRefresh) ?? '');
}

Future<String> loadApiKey() async {
  final p = await SharedPreferences.getInstance();
  return p.getString(_kApiKey) ?? '';
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
