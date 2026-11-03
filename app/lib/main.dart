import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth.dart';
import 'project_config.dart';
import 'telemetry.dart';

// Palet & tipografi mengikuti identitas web PWA (web/index.html :root):
// dark-teal surface, aksen cyan "water", angka monospace tabular.
const _bg = Color(0xFF0C1F27);
const _panel = Color(0xFF132B35);
const _panel2 = Color(0xFF0F242D);
const _line = Color(0xFF234654);
const _ink = Color(0xFFE2F1F3);
const _dim = Color(0xFF93B8C2);
const _water = Color(0xFF44C8E6);
const _ok = Color(0xFF5FD195);
const _warn = Color(0xFFF0C254);
const _alarm = Color(0xFFF26B6E);

const _display = 'SpaceGrotesk';
const _mono = 'JetBrainsMono';
const _pollInterval = Duration(milliseconds: 2500); // ritme poll PWA (cloud mode)
const _glassDisplayMl = 500.0; // skala tampilan gelas (gauge, bukan klaim volume)
// Nilai aman sebelum node config pertama kali terbaca firmware
// (BASE_INTERVAL_MS config.h = 30 menit; DEFAULT_EMPTY_CUP_G = 130 g).
const _defaultCfg = CloudConfig(
  timerMode: 'AUTO_DHT',
  manualIntervalMin: 30,
  emptyCupWeightG: 130,
  muted: false,
);

final _tabular = [const FontFeature.tabularFigures()];

TextStyle _monoStyle(double size, {Color? color, FontWeight? weight}) =>
    TextStyle(
      fontFamily: _mono,
      fontSize: size,
      color: color ?? _dim,
      fontWeight: weight,
      fontFeatures: _tabular,
    );

void main() => runApp(const CoasterApp());

class CoasterApp extends StatelessWidget {
  const CoasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Hydration Coaster',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        fontFamily: _display,
        colorScheme: const ColorScheme.dark(
          surface: _bg,
          primary: _water,
          secondary: _water,
          error: _alarm,
        ),
        dividerColor: _line,
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: _water,
          selectionHandleColor: _water,
        ),
      ),
      home: const RootPage(),
    );
  }
}

// ── Root: pilih antara layar koneksi (URL RTDB) dan dashboard ───────────────

class RootPage extends StatefulWidget {
  final http.Client? client; // seam untuk pengujian (MockClient)
  const RootPage({super.key, this.client});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  String? _url;
  String? _savedUrl;
  AuthSession? _session;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString('shc_fb_url');
    var session = await loadSession();
    if (session != null && !session.valid && session.refreshToken.isNotEmpty) {
      session = await refreshSession(session);
    }
    if (!mounted) return;
    // Urutan: URL yang pernah diketik pengguna (SharedPreferences) menang, lalu
    // tetapan build. Dengan begitu instalasi lama tetap jalan, dan instalasi baru
    // tidak perlu mengetik URL sama sekali.
    final effective = (saved != null && saved.isNotEmpty) ? saved : kFirebaseUrl;
    if (!mounted) return;
    setState(() {
      _savedUrl = effective;
      _session = (session != null && session.valid) ? session : null;
      _url = (effective.isNotEmpty && _session != null) ? effective : null;
    });
    // Tautan alat dipulihkan dari /links/<uid akun> setelah layar tampil, supaya
    // menginstal ulang aplikasi tidak perlu mengetik kode alat lagi dan boot
    // offline tidak tertahan menunggu jaringan. Gagal di sini bukan gagal boot:
    // fallback ke node akun tetap dipakai sampai pengguna menautkan manual.
    final s = _session;
    if (s != null && s.deviceUid.isEmpty && effective.isNotEmpty) {
      discoverDevice(base: effective, session: s, client: widget.client)
          .then((found) {
        if (!mounted || found.isEmpty) return;
        setState(() { _session = _session!.copyWith(deviceUid: found); });
        saveSession(_session!);
      });
    }
  }

  void _openDashboard(String url, AuthSession session) {
    setState(() {
      _url = url;
      _session = session;
      _editingUrl = false;
    });
    // Login baru tidak melewati _boot(), sedangkan signIn() tidak menghasilkan
    // deviceUid. Tanpa penemuan di sini, akun yang sudah tertaut ke alat lain
    // akan memakai node akun sampai aplikasi dijalankan ulang.
    if (session.deviceUid.isEmpty && url.isNotEmpty) {
      discoverDevice(base: url, session: session, client: widget.client)
          .then((found) {
        if (!mounted || found.isEmpty) return;
        setState(() { _session = _session!.copyWith(deviceUid: found); });
        saveSession(_session!);
      });
    }
  }

  bool _editingUrl = false;

  void _editUrl() => setState(() { _url = null; _editingUrl = true; });
  bool _claiming = false;

  @override
  Widget build(BuildContext context) {
    final url = _url;
    final session = _session;
    if (url == null || session == null) {
      return ConnectScreen(
          initialUrl: _savedUrl,
          onConnect: _openDashboard,
          initialSession: session,
          client: widget.client,
          showUrlField: _editingUrl);
    }
    if (_claiming) {
      return ClaimScreen(
          url: url,
          session: session,
          client: widget.client,
          onClaimed: (uid) => setState(() {
                _session = session.copyWith(deviceUid: uid);
                _claiming = false;
              }),
          onCancel: () => setState(() { _claiming = false; }));
    }
    return DashboardScreen(
        key: ValueKey('$url/${session.deviceUid}'),
        url: url,
        session: session,
        onChangeUrl: _editUrl,
        client: widget.client,
        onClaimDevice: () => setState(() { _claiming = true; }));
  }
}

// ── Layar koneksi ───────────────────────────────────────────────────────────

class ConnectScreen extends StatefulWidget {
  final void Function(String url, AuthSession session) onConnect;
  final String? initialUrl;
  final AuthSession? initialSession;
  final bool showUrlField;
  final bool showKeyField;
  final http.Client? client; // seam untuk pengujian (MockClient)
  const ConnectScreen({super.key, required this.onConnect, this.initialUrl,
      this.initialSession, this.showUrlField = false, this.showKeyField = false,
      this.client});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _ctrl = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _key = TextEditingController();
  String? _error;
  String? _authError;
  bool _busy = false;
  bool _registerMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null) _ctrl.text = widget.initialUrl!;
    final s = widget.initialSession;
    if (s != null) _email.text = s.email;
    // _storedKeyMissing hanya mencerminkan penyimpanan, bukan isi kolom, supaya
    // kolom tidak hilang saat pengguna sedang mengetik.
    loadApiKey().then((k) {
      if (!mounted) return;
      setState(() {
        // Key tersimpan tidak pernah diketik pengguna; ia ditulis otomatis oleh
        // saveApiKey(). Kalau dibiarkan menang atas tetapan build, build dengan
        // key baru tetap memakai key lama yang salah, dan karena kolomnya
        // tersembunyi tidak ada cara memperbaikinya selain hapus data aplikasi.
        _key.text = kFirebaseApiKey.isNotEmpty ? kFirebaseApiKey : k;
        _storedKeyMissing = _key.text.isEmpty;
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _email.dispose();
    _pass.dispose();
    _key.dispose();
    super.dispose();
  }

  // URL dan API key boleh datang dari tetapan build; kolomnya disembunyikan
  // supaya pengguna umum hanya melihat email dan password. Isian pengguna menang
  // atas tetapan build, sama seperti _boot() mendahulukan
  // URL tersimpan. Tanpa urutan ini, kolom yang muncul lewat "Ubah URL" akan
  // tampak bisa diketik padahal nilainya diabaikan.
  String get _urlValue {
    final typed = _ctrl.text.trim();
    return typed.isNotEmpty ? typed : kFirebaseUrl;
  }

  String get _keyValue {
    final typed = _key.text.trim();
    return typed.isNotEmpty ? typed : kFirebaseApiKey;
  }

  // Visibilitas kolom ditentukan sekali saat layar dibuka, bukan dari isi kolom.
  // Kalau bergantung pada _key.text, kolomnya hilang begitu pengguna mengetik
  // (setState saat _busy=true) sehingga key yang salah tidak bisa diperbaiki.
  late final bool _needsUrl = widget.showUrlField ||
      (kFirebaseUrl.isEmpty && (_ctrl.text.trim().isEmpty));
  bool _storedKeyMissing = true;
  bool get _needsKey =>
      widget.showKeyField || (kFirebaseApiKey.isEmpty && _storedKeyMissing);

  Future<void> _submit() async {
    final raw = _urlValue;
    if (raw.isEmpty) {
      setState(() => _error = 'URL wajib diisi.');
      return;
    }
    if (!raw.startsWith('https://')) {
      setState(() => _error = 'URL harus diawali https://');
      return;
    }
    final url = raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
    setState(() { _busy = true; _authError = null; _error = null; });
    try {
      // Simpan hanya kalau nilainya berasal dari pengguna, supaya tetapan build
      // tidak membeku di penyimpanan.
      if (kFirebaseApiKey.isEmpty) await saveApiKey(_keyValue);
      var existing = await loadSession();
      if (existing != null && !existing.valid && existing.refreshToken.isNotEmpty) {
        existing = await refreshSession(existing, client: widget.client);
      }
      final session = (existing != null && existing.valid)
          ? existing
          : await signIn(
              email: _email.text,
              password: _pass.text,
              apiKey: _keyValue,
              register: _registerMode,
              client: widget.client,
            );
      final p = await SharedPreferences.getInstance();
      await p.setString('shc_fb_url', url);
      if (!mounted) return;
      widget.onConnect(url, session);
    } catch (e) {
      if (!mounted) return;
      setState(() => _authError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Smart Hydration',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                        letterSpacing: .2)),
                Text('Coaster',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: _water,
                        letterSpacing: .2)),
                const SizedBox(height: 6),
                Text(
                  'Masuk untuk melihat tatakan gelasmu dari jauh.',
                  style: TextStyle(fontSize: 14, color: _dim, height: 1.5),
                ),
                const SizedBox(height: 28),
                if (_needsUrl) ...[
                  TextField(
                    controller: _ctrl,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _submit(),
                    style: _monoStyle(13, color: _ink),
                    decoration: InputDecoration(
                      labelText: 'URL Firebase RTDB',
                      labelStyle: _monoStyle(12),
                      hintText:
                          'https://nama-proyek-default-rtdb.asia-southeast1.firebasedatabase.app',
                      hintStyle: _monoStyle(11, color: _dim),
                      enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: _line)),
                      focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: _water, width: 2)),
                      errorText: _error,
                      errorStyle: _monoStyle(11, color: _alarm),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Salin URL dari Firebase Console → Realtime Database. '
                    'ESP32 menulis ke /users/<uid>/smart_coaster lewat Wi-Fi 2,4 GHz; '
                    'aplikasi ini membaca telemetry dan mengatur config.',
                    style: _monoStyle(11, color: _dim),
                  ),
                  const SizedBox(height: 20),
                ],
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  style: _monoStyle(13, color: _ink),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: _monoStyle(12),
                    enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: _line)),
                    focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: _water, width: 2)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  style: _monoStyle(13, color: _ink),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: _monoStyle(12),
                    enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: _line)),
                    focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: _water, width: 2)),
                  ),
                ),
                const SizedBox(height: 12),
                if (_needsKey)
                TextField(
                  controller: _key,
                  autocorrect: false,
                  style: _monoStyle(13, color: _ink),
                  decoration: InputDecoration(
                    labelText: 'Web API Key proyek Firebase',
                    labelStyle: _monoStyle(12),
                    helperText: 'Project settings → General → Web API Key',
                    helperStyle: _monoStyle(10, color: _dim),
                    enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: _line)),
                    focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: _water, width: 2)),
                    errorText: _authError,
                    errorStyle: _monoStyle(11, color: _alarm),
                  ),
                ),
                const SizedBox(height: 24),
                // Kolom API key bisa disembunyikan oleh tetapan build, jadi pesan
                // gagal masuk ditampilkan di sini supaya tidak hilang.
                if (_authError != null) ...[
                  Text(_authError!,
                      style: _monoStyle(12, color: _alarm), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _water,
                    foregroundColor: _bg,
                    minimumSize: const Size.fromHeight(48),
                    textStyle: TextStyle(
                        fontFamily: _mono,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                  child: Text(_busy
                      ? 'Sebentar...'
                      : (_registerMode ? 'Buat akun' : 'Masuk')),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _registerMode = !_registerMode),
                  child: Text(
                    _registerMode
                        ? 'Sudah punya akun? Masuk'
                        : 'Belum punya akun? Daftar',
                    style: _monoStyle(11, color: _water),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Dashboard ───────────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  final String url;
  final AuthSession session;
  final VoidCallback onChangeUrl;
  final VoidCallback? onClaimDevice;
  final http.Client? client; // seam untuk pengujian (MockClient)
  const DashboardScreen(
      {super.key,
      required this.url,
      required this.session,
      required this.onChangeUrl,
      this.onClaimDevice,
      this.client});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}


/// Cache node telemetry + penerapan event RTDB (`put`, `patch`) menurut `path`.
/// Dipisah dari widget supaya bisa diuji tanpa jaringan: PATCH kiriman aplikasi
/// dan web datang sebagai `event: patch` dengan path sebagian, dan kalau path
/// diabaikan field lain ikut terhapus.
class TlmStreamState {
  final Map<String, dynamic> json = <String, dynamic>{};

  /// Menerapkan satu blok SSE. Mengembalikan true bila ada data yang berubah.
  bool apply(String block) {
    String type = '';
    String payload = '';
    for (final line in block.split('\n')) {
      if (line.startsWith('event:')) {
        type = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        payload += line.substring(5).trim();
      }
    }
    if (payload.isEmpty) return false;
    dynamic decoded;
    try {
      decoded = jsonDecode(payload);
    } catch (_) {
      return false;
    }
    if (decoded is! Map) return false;
    final path = (decoded['path'] as String?) ?? '/';
    final data = decoded['data'];
    if (type == 'put') {
      if (data == null) {
        json.clear();
        return true;
      }
      if (path == '/') {
        json
          ..clear()
          ..addAll(Map<String, dynamic>.from(data as Map));
      } else {
        _setAtPath(path, data);
      }
      return true;
    }
    if (type == 'patch') {
      if (path == '/') {
        json.addAll(Map<String, dynamic>.from(data as Map));
      } else {
        _setAtPath(path, data);
      }
      return true;
    }
    return false;
  }

  void _setAtPath(String path, dynamic value) {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return;
    var cur = json;
    for (var i = 0; i < parts.length - 1; i++) {
      final nxt = cur[parts[i]];
      if (nxt is Map<String, dynamic>) {
        cur = nxt;
      } else {
        final m = <String, dynamic>{};
        cur[parts[i]] = m;
        cur = m;
      }
    }
    if (value == null) {
      cur.remove(parts.last);
    } else {
      cur[parts.last] = value;
    }
  }
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AuthSession _session = widget.session;
  Telemetry? _t;
  CloudConfig? _cfg;
  String? _error;
  bool _loading = true;
  bool _polling = false;
  DateTime? _lastSync;
  Timer? _timer;
  StreamSubscription<String>? _streamSub;
  Timer? _streamRetry;
  late final http.Client _client;

  late final AnimationController _pulse;
  final _intervalCtrl = TextEditingController();

  String get _base => widget.url;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? http.Client();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    WidgetsBinding.instance.addObserver(this);
    _poll();
    _startPolling();
  }

  void _startPolling() {
    // SSE dulu: satu request yang tetap terbuka, data berubah seketika tanpa
    // jeda 2,5 dtk. Poll lambat tetap ada sebagai jaring aman bila stream mati
    // di jaringan yang memblokir event-stream (mis. proxy kantor).
    _openStream();
    _timer ??= Timer.periodic(_pollInterval, (_) => _poll());
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
    _streamSub?.cancel();
    _streamSub = null;
    _streamRetry?.cancel();
    _streamRetry = null;
  }

  // Stream telemetry: setiap event `put` langsung diterapkan. Token 1 jam
  // ditangani dengan memperbarui sesi lalu membuka ulang stream — pengguna
  // tidak perlu masuk lagi.
  Future<void> _openStream() async {
    await _streamSub?.cancel();
    _streamSub = null;
    if (!mounted) return;
    final url = '${_session.coasterUrl(_base)}/telemetry.json${_session.suffix}';
    try {
      final req = http.Request('GET', Uri.parse(url))
        ..headers['Accept'] = 'text/event-stream';
      final res = await _client.send(req).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      _streamSub = res.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_onStreamLine, onError: (_) => _restartStream(),
              onDone: _restartStream, cancelOnError: true);
    } catch (_) {
      _restartStream();
    }
  }



  final TlmStreamState _stream = TlmStreamState();
  String _streamBuf = '';

  void _onStreamLine(String line) {
    // Blok SSE dipisah baris kosong; event: dan data: bisa lebih dari satu baris.
    if (line.isNotEmpty) {
      _streamBuf += '$line\n';
      return;
    }
    if (_streamBuf.isEmpty) return;
    final changed = _stream.apply(_streamBuf);
    _streamBuf = '';
    if (!changed || !mounted) return;
    setState(() {
      _t = Telemetry.fromJson(Map<String, dynamic>.from(_stream.json));
      _error = null;
      _loading = false;
      _lastSync = DateTime.now();
    });
  }

  void _restartStream() {
    _streamSub?.cancel();
    _streamSub = null;
    _streamRetry?.cancel();
    if (!mounted) return;
    // Simpan timer-nya supaya dispose() benar-benar membatalkan percobaan ulang.
    _streamRetry = Timer(const Duration(milliseconds: 800), () async {
      if (!mounted) return;
      // Coba segarkan sesi; kalau berhasil, stream dibuka dengan token baru.
      try {
        final renewed = await refreshSession(_session, client: _client);
        if (renewed != null && mounted) setState(() => _session = renewed);
      } catch (_) {}
      _openStream();
    });
  }

  // Ponsel di kantong tidak perlu mengunduh tiap 2,5 detik. Hentikan saat aplikasi
  // tidak terlihat, dan langsung ambil data segar begitu pengguna kembali.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _poll();
      _startPolling();
    } else {
      _stopPolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _streamRetry?.cancel();
    _streamRetry = null;
    _client.close();
    _pulse.dispose();
    _intervalCtrl.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      // Hanya dua node kecil. Sebelumnya seluruh /smart_coaster ditarik tiap 2,5
      // detik, termasuk daily/<tanggal> yang tumbuh tanpa batas, padahal _poll()
      // tidak pernah membacanya. Web sudah memakai pola yang sama.
      final base = _session.coasterUrl(_base);
      final results = await Future.wait([
        _client.get(Uri.parse('$base/telemetry.json${_session.suffix}'))
            .timeout(const Duration(seconds: 8)),
        _client.get(Uri.parse('$base/config.json${_session.suffix}'))
            .timeout(const Duration(seconds: 8)),
      ]);
      final res = results[0];
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final tRaw = jsonDecode(res.body);
      if (tRaw is Map) {
        final t = Telemetry.fromJson(Map<String, dynamic>.from(tRaw));
        CloudConfig? c = _cfg;
        if (results[1].statusCode == 200) {
          final cRaw = jsonDecode(results[1].body);
          if (cRaw is Map) {
            c = CloudConfig.fromJson(Map<String, dynamic>.from(cRaw));
            if (_cfg == null) {
              _intervalCtrl.text = c.manualIntervalMin.toString();
            }
          }
        }
        if (!mounted) return;
        setState(() {
          _t = t;
          _cfg = c;
          _error = null;
          _loading = false;
          _lastSync = DateTime.now();
        });
      } else {
        // Node kosong / telemetry belum pernah ditulis firmware.
        if (!mounted) return;
        setState(() {
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      // Error asli tampil dulu. Perpanjangan token hanya upaya lanjutan: kalau
      // gagal (jaringan putus, atau plugin prefs tidak ada di test), pengguna
      // tetap melihat penyebab sebenarnya, bukan dashboard basi tanpa pesan.
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      try {
        final renewed = await refreshSession(_session, client: _client);
        if (renewed != null && mounted) setState(() => _session = renewed);
      } catch (_) {
        // perpanjangan gagal; error asli sudah ditampilkan dan timer poll mencoba lagi
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _patchConfig(Map<String, dynamic> patch) async {
    try {
      final res = await _client
          .patch(
            Uri.parse('${_session.coasterUrl(_base)}/config.json${_session.suffix}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(patch),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal kirim config: $e')));
    }
  }

  void _setMuted(bool v) {
    setState(() => _cfg = (_cfg ?? _defaultCfg).copyWith(muted: v));
    _patchConfig({'muted': v});
  }

  void _setMode(String mode) {
    setState(() => _cfg = (_cfg ?? _defaultCfg).copyWith(timerMode: mode));
    _patchConfig({'timer_mode': mode});
  }

  void _sendInterval() {
    final text = _intervalCtrl.text.trim();
    final v = int.tryParse(text);
    if (v == null || v < kMinManualIntervalMin || v > kMaxManualIntervalMin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Interval harus 1 sampai 180 menit.')));
      return;
    }
    setState(() => _cfg = (_cfg ?? _defaultCfg).copyWith(manualIntervalMin: v));
    _patchConfig({'manual_interval_min': v});
  }

  Color _stateColor(String s) {
    switch (s) {
      case 'STABLE':
        return _ok;
      case 'TIMING':
        return _water;
      case 'ALERT_DRINK':
        return _warn;
      case 'ALERT_CHEAT':
        return _alarm;
      case 'ALERT_REFILL':
        return _warn;
      default:
        return _dim; // IDLE, LIFTED
    }
  }

  Duration _pulsePeriod(String s) {
    if (s == 'ALERT_CHEAT') return const Duration(milliseconds: 150);
    if (s == 'ALERT_REFILL') return const Duration(milliseconds: 750);
    return const Duration(milliseconds: 500);
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    if (t != null && t.isAlert && !reduceMotion) {
      if (!_pulse.isAnimating) {
        _pulse.repeat(reverse: true, period: _pulsePeriod(t.canonicalState));
      }
    } else if (_pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }

    final dotColor = _t != null && _error == null
        ? _ok
        : _error != null
            ? _alarm
            : _dim;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _panel2,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: dotColor),
            ),
            const SizedBox(width: 10),
            Text('Smart Hydration Coaster',
                style: TextStyle(
                    fontFamily: _display,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    letterSpacing: .2)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Ubah URL',
            icon: const Icon(Icons.swap_horiz, color: _dim),
            onPressed: widget.onChangeUrl,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _syncLine(),
              const SizedBox(height: 12),
              if (_loading)
                _card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(color: _water),
                        const SizedBox(height: 16),
                        Text('Menghubungkan ke Firebase…',
                            style: _monoStyle(12)),
                      ],
                    ),
                  ),
                )
              else if (t == null)
                _card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        Icon(
                          _error != null
                              ? Icons.cloud_off
                              : Icons.hourglass_empty,
                          color: _error != null ? _alarm : _dim,
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error != null
                              ? 'Gagal membaca cloud:\n$_error'
                              : 'Belum ada data telemetry.\n'
                                  'Pastikan ESP32 menyala dan terhubung Wi-Fi 2,4 GHz.',
                          textAlign: TextAlign.center,
                          style: _monoStyle(12, color: _ink),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _poll,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _line),
                            minimumSize: const Size(160, 44),
                          ),
                          child: Text('Coba lagi',
                              style: _monoStyle(12, color: _water)),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                _glassCard(t),
                const SizedBox(height: 12),
                _badgeCard(t, reduceMotion),
                const SizedBox(height: 12),
                _countdownCard(t),
                const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _envChip('SUHU', t.tempC, ' °C')),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _envChip('KELEMBABAN', t.humidityPct, ' %')),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _dailyCard(t),
                const SizedBox(height: 12),
                _controlsCard(),
                const SizedBox(height: 12),
                Text(
                  'RTDB: ${Uri.parse(_base).host} · poll 2,5 s · '
                  'angka dari firmware, bukan simulasi. '
                  'Skala gelas tampilan: ${_glassDisplayMl.toInt()} ml.',
                  style: _monoStyle(10, color: _dim),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _syncLine() => Row(
        children: [
          Text('CLOUD', style: _monoStyle(11, color: _water)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _lastSync == null
                  ? 'menunggu sinkron pertama…'
                  : 'sinkron ${TimeOfDay.fromDateTime(_lastSync!).format(context)}',
              style: _monoStyle(11),
            ),
          ),
        ],
      );

  Widget _card({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: _panel,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(14),
        child: child,
      );

  Widget _glassCard(Telemetry t) {
    final fill =
        (t.waterMl / _glassDisplayMl).clamp(0.0, 1.0);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                height: 150,
                child: CustomPaint(
                  painter: _GlassPainter(
                    fill: fill,
                    present: t.cupPresent,
                    water: _water,
                    line: _line,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BERAT', style: _monoStyle(10)),
                    const SizedBox(height: 4),
                    Text(t.weightG.toStringAsFixed(1),
                        style: _monoStyle(34,
                            color: _ink, weight: FontWeight.w600)),
                    Text('gram', style: _monoStyle(11)),
                    const SizedBox(height: 14),
                    Text('AIR TERDETEKSI', style: _monoStyle(10)),
                    const SizedBox(height: 4),
                    Text('${t.waterMl.toStringAsFixed(0)} ml',
                        style: _monoStyle(15, color: _water)),
                    const SizedBox(height: 14),
                    if (!t.cupPresent)
                      Text('Gelas tidak di tatakan',
                          style: _monoStyle(11, color: _warn)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Skala gelas tampilan: ${_glassDisplayMl.toInt()} ml',
              style: _monoStyle(10)),
        ],
      ),
    );
  }

  Widget _badgeCard(Telemetry t, bool reduceMotion) {
    final color = _stateColor(t.canonicalState);
    final name = t.canonicalState.replaceAll('_', ' ');
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final c = (t.isAlert && !reduceMotion)
            ? Color.lerp(color, _panel, _pulse.value * 0.6)!
            : color;
        return Container(
          decoration: BoxDecoration(
            color: _panel,
            border: Border.all(color: c, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: TextStyle(
                      fontFamily: _display,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: color,
                      letterSpacing: .4)),
              const SizedBox(height: 4),
              Text(t.reason, style: _monoStyle(12, color: _ink)),
            ],
          ),
        );
      },
    );
  }

  Widget _countdownCard(Telemetry t) {
    final targetSec = (t.targetIntervalMin * 60).round();
    final progress = targetSec > 0
        ? (1 - t.remainingSec / targetSec).clamp(0.0, 1.0)
        : 0.0;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('SISA WAKTU', style: _monoStyle(10)),
              const Spacer(),
              Text('target ${t.targetIntervalMin.toStringAsFixed(1)} menit',
                  style: _monoStyle(11)),
            ],
          ),
          const SizedBox(height: 6),
          Text(Telemetry.mmss(t.remainingSec),
              style: _monoStyle(34, color: _ink, weight: FontWeight.w600)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: _panel2,
              valueColor: const AlwaysStoppedAnimation(_water),
            ),
          ),
        ],
      ),
    );
  }

  Widget _envChip(String label, double value, String unit) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: _monoStyle(10)),
            const SizedBox(height: 6),
            Text('${value.toStringAsFixed(1)}$unit',
                style: _monoStyle(20, color: _ink, weight: FontWeight.w600)),
          ],
        ),
      );

  Widget _dailyCard(Telemetry t) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Firmware tidak punya jam (CLAUDE.md §4: tanpa NTP), jadi angkanya
                // kumulatif sejak reset manual, bukan per hari kalender.
                Text('TOTAL SEJAK RESET', style: _monoStyle(10)),
                const Spacer(),
                Text('${t.totalMl} ml',
                    style: _monoStyle(20, color: _water, weight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _countCell('MINUM', '${t.drinkCount}', _ok),
                _countCell('ISI ULANG', '${t.refillCount}', _water),
                _countCell('CURANG', '${t.cheatCount}', _alarm),
              ],
            ),
          ],
        ),
      );

  Widget _countCell(String label, String value, Color color) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: _panel2,
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(value,
                  style: _monoStyle(18, color: color, weight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(label, style: _monoStyle(10)),
            ],
          ),
        ),
      );

  Widget _controlsCard() {
    final cfg = _cfg;
    final mode = cfg?.timerMode ?? 'AUTO_DHT';
    final muted = cfg?.muted ?? _t?.muted ?? false;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('KONTROL', style: _monoStyle(10, color: _water)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('Buzzer', style: _monoStyle(12, color: _ink))),
              Text(muted ? 'OFF' : 'ON',
                  style: _monoStyle(11, color: muted ? _warn : _ok)),
              Switch(
                value: muted,
                activeThumbColor: _water,
                onChanged: _setMuted,
              ),
            ],
          ),
          const Divider(color: _line, height: 20),
          Text('Mode timer', style: _monoStyle(12, color: _ink)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'AUTO_DHT',
                  label: Text('AUTO_DHT', style: TextStyle(fontFamily: _mono, fontSize: 11))),
              ButtonSegment(
                  value: 'MANUAL',
                  label: Text('MANUAL', style: TextStyle(fontFamily: _mono, fontSize: 11))),
            ],
            selected: {mode},
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected) ? _water.withValues(alpha: 0.18) : _panel2),
              foregroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected) ? _water : _dim),
              side: WidgetStateProperty.all(const BorderSide(color: _line)),
            ),
            onSelectionChanged: (s) => _setMode(s.first),
          ),
          if (mode == 'MANUAL') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _intervalCtrl,
                    keyboardType: TextInputType.number,
                    style: _monoStyle(13, color: _ink),
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Interval dasar (menit)',
                      labelStyle: _monoStyle(11),
                      enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: _line)),
                      focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: _water, width: 2)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _sendInterval,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _line),
                    minimumSize: const Size(88, 44),
                  ),
                  child: Text('Kirim', style: _monoStyle(12, color: _water)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text('Kalibrasi gelas kosong dan tare lewat USB.',
              style: _monoStyle(10, color: _dim)),
          if (widget.onClaimDevice != null) ...[
            const Divider(color: _line, height: 20),
            Text('Node alat', style: _monoStyle(12, color: _ink)),
            const SizedBox(height: 2),
            Text(
              _session.hasDevice
                  ? 'tertaut: ${_session.deviceUid}'
                  : 'belum tertaut, memakai node akun',
              style: _monoStyle(10, color: _session.hasDevice ? _ok : _warn),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: widget.onClaimDevice,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _line),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  minimumSize: const Size(0, 44),
                ),
                child: Text(_session.hasDevice ? 'Ganti alat' : 'Tautkan alat',
                    style: _monoStyle(12, color: _water)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Layar klaim alat ────────────────────────────────────────────────────────
// Kode 8 karakter dibaca dari Serial Monitor alat, lalu ditukar jadi tautan supaya akun
// ini boleh membaca node alat. Sama seperti alur di web/login.html.
class ClaimScreen extends StatefulWidget {
  final String url;
  final AuthSession session;
  final void Function(String deviceUid) onClaimed;
  final VoidCallback? onCancel;
  final http.Client? client;
  const ClaimScreen({super.key, required this.url, required this.session,
      required this.onClaimed, this.onCancel, this.client});
  @override
  State<ClaimScreen> createState() => _ClaimScreenState();
}

class _ClaimScreenState extends State<ClaimScreen> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() { _busy = true; _error = null; });
    try {
      final deviceUid = await claimDevice(
          base: widget.url, code: _code.text, session: widget.session,
          client: widget.client);
      if (!mounted) return;
      widget.onClaimed(deviceUid);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            children: [
              Text('Tautkan alat',
                  style: TextStyle(fontFamily: _display, fontSize: 30,
                      fontWeight: FontWeight.w700, color: _ink, height: 1.15)),
              const SizedBox(height: 10),
              Text('Masukkan kode 8 karakter dari alat.',
                  style: _monoStyle(12, color: _ink)),
              const SizedBox(height: 6),
              // Tatakan tidak punya layar. Kode hanya dicetak firmware ke Serial,
              // jadi arahkan ke sana daripada mencari tampilan yang tidak ada.
              Text('Sambungkan alat ke komputer lewat USB, buka Serial Monitor '
                  '115200 baud, lalu lihat baris "[CLOUD] Kode klaim alat: XXXXXXXX". '
                  'Kode yang sama bisa dimasukkan di halaman Akun web PWA.',
                  style: _monoStyle(11, color: _dim)),
              const SizedBox(height: 28),
              TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _submit(),
                maxLength: 8,
                style: _monoStyle(20, color: _ink, weight: FontWeight.w600),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'A1B2C3D4',
                  hintStyle: _monoStyle(20, color: _dim),
                  enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: _line)),
                  focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: _water, width: 2)),
                  errorText: _error,
                  errorStyle: _monoStyle(11, color: _alarm),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(backgroundColor: _water),
                  child: Text(_busy ? 'Menautkan…' : 'Tautkan',
                      style: _monoStyle(13, color: _bg, weight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Sudah ditautkan di perangkat lain? Cukup masukkan kodenya sekali lagi.',
                  style: _monoStyle(10, color: _dim)),
              if (widget.onCancel != null) ...[
                const SizedBox(height: 24),
                TextButton(
                  onPressed: _busy ? null : widget.onCancel,
                  child: Text('Lewati, pakai node akun saja',
                      style: _monoStyle(11, color: _dim)),
                ),
              ],
            ],
          ),
        ),
      );
}

// ── Gelas: outline + kolom air proporsional water_ml ────────────────────────

class _GlassPainter extends CustomPainter {
  final double fill; // 0..1
  final bool present;
  final Color water;
  final Color line;
  _GlassPainter(
      {required this.fill,
      required this.present,
      required this.water,
      required this.line});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final inset = 8.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, w - inset * 2, h - inset * 2),
      const Radius.circular(10),
    );

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = present ? line : line.withValues(alpha: 0.4);
    canvas.drawRRect(rect, outline);

    if (present && fill > 0) {
      final waterH = (h - inset * 2) * fill;
      final waterRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(inset, h - inset - waterH, w - inset * 2, waterH),
        const Radius.circular(8),
      );
      canvas.save();
      canvas.clipRRect(rect);
      canvas.drawRRect(waterRect, Paint()..color = water.withValues(alpha: 0.85));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_GlassPainter old) =>
      old.fill != fill ||
      old.present != present ||
      old.water != water ||
      old.line != line;
}
