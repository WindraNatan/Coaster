import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth.dart';
import 'project_config.dart';
import 'reminder.dart';
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
// Jaring aman saja: data datang lewat stream SSE. Poll 20 dtk dipakai bila
// stream mati (proxy memblokir event-stream). 2,5 dtk membakar kuota RTDB
// tanpa menambah kesegaran, karena SSE sudah lebih cepat.
const _pollInterval = Duration(seconds: 20);
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
                        fontWeight: FontWeight.w500,
                        color: _ink,
                        letterSpacing: .2)),
                Text('Coaster',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w500,
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
                    helperStyle: _monoStyle(11, color: _dim),
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
  bool _remindOn = false;
  String? _remindSound;      // URI audio pilihan pengguna; null = nada bawaan
  bool _remindVibrate = true;
  Duration? _remindLeft;
  bool _exactOk = true;
  Timer? _remindTick;
  bool _polling = false;
  DateTime? _lastSync;
  // Saat snapshot ini pertama terlihat. Dipisah dari _lastSync: poll 20
  // detik dan event config bisa mengirim ulang telemetri yang sama, dan
  // memakai _lastSync sebagai jangkar membuat countdown melompat naik.
  DateTime? _frameAt;
  // Waktu frame SSE terakhir diterapkan. Poll yang berangkat sebelum ini
  // membawa data lebih lama, dan menerapkannya memundurkan countdown.
  DateTime? _streamFrameAt;
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
    _loadReminder();
    _loadGoal();
    _loadHistory();
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
    _cfgSub?.cancel();
    _cfgSub = null;
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
      _openCfgStream();
    } catch (_) {
      _restartStream();
    }
  }



  final TlmStreamState _stream = TlmStreamState();
  final TlmStreamState _cfgState = TlmStreamState();
  String _streamBuf = '';


  StreamSubscription<String>? _cfgSub;
  final Map<String, dynamic> _cfgCache = {};
  String _cfgBuf = '';

  /// Stream config terpisah: mute dan mode berasal dari sini, dan UI
  /// mendahulukan _cfg, jadi tanpa stream ini tombol dari web terlihat basi.
  Future<void> _openCfgStream() async {
    await _cfgSub?.cancel();
    _cfgSub = null;
    if (!mounted) return;
    final url = '${_session.coasterUrl(_base)}/config.json${_session.suffix}';
    try {
      final req = http.Request('GET', Uri.parse(url))
        ..headers['Accept'] = 'text/event-stream';
      final res = await _client.send(req).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      _cfgSub = res.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_onCfgLine, cancelOnError: true);
    } catch (_) {
      // Poll GET tetap menjadi cadangan.
    }
  }

  void _onCfgLine(String line) {
    if (line.isNotEmpty) {
      _cfgBuf += '$line\n';
      return;
    }
    if (_cfgBuf.isEmpty) return;
    final changed = _cfgState.apply(_cfgBuf);
    _cfgBuf = '';
    if (!changed || !mounted) return;
    _cfgCache
      ..clear()
      ..addAll(_cfgState.json);
    setState(() => _cfg = CloudConfig.fromJson(Map<String, dynamic>.from(_cfgCache)));
  }

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
      final baru = Telemetry.fromJson(Map<String, dynamic>.from(_stream.json));
      if (_frameIsNew(baru)) _frameAt = DateTime.now();
      _t = baru;
      _streamFrameAt = DateTime.now();
      _error = null;
      _loading = false;
      _lastSync = DateTime.now();
    });
    _trackHeartbeat(_t!);
    _dayMl = _computeDayMl(_t!);
    _syncReminderOnData();
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
    _cfgSub?.cancel();
    _remindTick?.cancel();
    _remindTick = null;
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
      final mulai = DateTime.now();
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
        // Frame SSE yang tiba setelah permintaan berangkat lebih baru daripada
        // hasil poll. Config tetap dipakai, telemetrinya dibuang.
        final usang = _streamFrameAt != null && _streamFrameAt!.isAfter(mulai);
        setState(() {
          if (!usang) {
            if (_frameIsNew(t)) _frameAt = DateTime.now();
            _t = t;
          }
          _cfg = c;
          _error = null;
          _loading = false;
          _lastSync = DateTime.now();
        });
        if (!usang) {
          _trackHeartbeat(t);
          _dayMl = _computeDayMl(t);
          _syncReminderOnData();
        }
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
    HapticFeedback.selectionClick();
    setState(() => _cfg = (_cfg ?? _defaultCfg).copyWith(muted: v));
    _patchConfig({'muted': v});
  }

  void _setMode(String mode) {
    HapticFeedback.selectionClick();
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
            Expanded(
              child: Text('Smart Hydration Coaster',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                    fontFamily: _display,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _ink,
                    letterSpacing: .2)),
            ),
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
        child: RefreshIndicator(
          color: _water,
          backgroundColor: _panel,
          onRefresh: () async {
            await _poll();
            await _syncReminder();
          },
          child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                _goalCard(t),
                const SizedBox(height: 12),
                _reminderCard(),
                const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _envChip('Suhu', t.tempC, ' °C')),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _envChip('Kelembapan', t.humidityPct, ' %')),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _dailyCard(t),
                const SizedBox(height: 12),
                _historyCard(),
                _controlsCard(),
                const SizedBox(height: 12),
                Text(
                  'RTDB: ${Uri.parse(_base).host} · stream langsung · '
                  'skala gelas tampilan ${_glassDisplayMl.toInt()} ml.',
                  style: _monoStyle(11, color: _dim),
                ),
              ],
            ],
          ),
          ),
        ),
      ),
    );
  }


  // ── Pengingat minum ───────────────────────────────────────────────────────
  // Pengingat dijadwalkan ulang setiap kali sisa waktu dari alat berubah, supaya
  // alarm di ponsel mengikuti jadwal alat — bukan tebakan jam sendiri. Nilai
  // disimpan di SharedPreferences agar tetap berlaku setelah aplikasi ditutup.
  Future<void> _loadReminder() async {
    final prefs = await SharedPreferences.getInstance();
    _remindOn = prefs.getBool('remind_on') ?? false;
    _remindSound = prefs.getString('remind_sound');
    _remindVibrate = prefs.getBool('remind_vibrate') ?? true;
    _exactOk = await ReminderService.canExact();
    await ReminderService.ensureChannel();
    if (_remindOn) _syncReminder();
    if (!mounted) return;
    setState(() {});
    _startRemindTick();
  }

  /// Sisa waktu yang benar-benar berjalan. Alat hanya mengirim snapshot
  /// saat ada perubahan lain atau heartbeat, jadi angka mentah membeku lalu
  /// melompat. Kurangi sendiri dengan waktu sejak snapshot tiba.
  int _liveRemaining(Telemetry t) {
    final at = _frameAt ?? _lastSync;
    if (at == null) return t.remainingSec;
    final rem = t.remainingSec - DateTime.now().difference(at).inSeconds;
    return rem < 0 ? 0 : rem;
  }

  /// Apakah snapshot ini benar-benar baru. Counter hb adalah penanda yang
  /// pasti; firmware lama tanpa hb dinilai dari sisa waktu yang naik.
  bool _frameIsNew(Telemetry t) {
    final prev = _t;
    if (prev == null) return true;
    if (t.heartbeat > 0 || prev.heartbeat > 0) {
      return t.heartbeat != prev.heartbeat;
    }
    return t.remainingSec > prev.remainingSec + 1;
  }

  void _startRemindTick() {
    _remindTick?.cancel();
    _remindTick = Timer.periodic(const Duration(seconds: 1), (_) async {
      final left = await ReminderService.timeLeft();
      if (!mounted) return;
      // Digambar ulang tiap detik: kartu sisa waktu menghitung sendiri dari
      // snapshot terakhir, jadi angkanya harus ikut berjalan.
      setState(() => _remindLeft = left);
    });
  }

  Future<void> _saveReminderPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remind_on', _remindOn);
    await prefs.setBool('remind_vibrate', _remindVibrate);
    if (_remindSound == null) {
      await prefs.remove('remind_sound');
    } else {
      await prefs.setString('remind_sound', _remindSound!);
    }
  }

  /// Menjadwalkan alarm mengikuti sisa waktu yang dilaporkan alat. Dipanggil saat
  /// data masuk dan saat pengguna menyalakan pengingat.

  // Jadwal alarm dibandingkan lewat deadline absolut; aturannya ada di
  // ReminderPlan/shouldScheduleReminder agar bisa diuji tanpa widget.
  ReminderPlan? _plan;

  void _syncReminderOnData() {
    if (!_remindOn) return;
    final t = _t;
    if (t == null) return;
    if (!stateAllowsReminder(t.canonicalState)) {
      if (_plan != null) {
        _plan = null;
        ReminderService.cancel();
      }
      return;
    }
    final rem = _liveRemaining(t);
    if (rem <= 0) return;
    final target = DateTime.now().add(Duration(seconds: rem));
    if (!shouldScheduleReminder(
        state: t.canonicalState, target: target, current: _plan)) {
      return;
    }
    _plan = ReminderPlan(t.canonicalState, target);
    _syncReminder();
  }

  Future<void> _syncReminder() async {
    if (!_remindOn) {
      await ReminderService.cancel();
      return;
    }
    final t = _t;
    if (t == null) return;
    // Tanpa sisa waktu tidak ada yang bisa dijadwalkan; alarm yang sudah ada
    // dibatalkan supaya tidak berbunyi di waktu yang tidak lagi berlaku.
    final rem = _liveRemaining(t);
    if (rem <= 0) {
      await ReminderService.cancel();
      _plan = null;
      return;
    }
    await ReminderService.schedule(
      lead: Duration(seconds: rem),
      sound: _remindSound,
      vibrate: _remindVibrate,
    );
  }

  Future<void> _toggleRemind(bool on) async {
    HapticFeedback.selectionClick();
    if (on) {
      // Izin notifikasi diminta di sini, saat pengguna jelas meminta pengingat.
      // Tanpa izin, alarm berbunyi tanpa apa pun yang terlihat di layar.
      final allowed = await ReminderService.requestNotificationPermission();
      if (!allowed && mounted) {
        setState(() => _remindOn = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Izin notifikasi ditolak. Pengingat tidak bisa berbunyi.')));
        return;
      }
    }
    setState(() => _remindOn = on);
    await _saveReminderPrefs();
    if (on) {
      _exactOk = await ReminderService.canExact();
      await _syncReminder();
      await ReminderService.preview(_remindSound);
    } else {
      await ReminderService.cancel();
      setState(() => _remindLeft = null);
    }
  }

  Future<void> _pickSound() async {
    final files = await FilePicker.pickFiles(type: FileType.audio);
    final picked = files.isEmpty ? null : files.first.path;
    if (picked == null) return;
    // URI content:// dari pemilih Android hanya bisa dibaca selama izin sementara
    // berlaku; alarm berbunyi berjam-jam kemudian, jadi berkasnya disalin dulu ke
    // penyimpanan aplikasi. Tanpa salinan, alarm akan senyap.
    final dir = await getApplicationDocumentsDirectory();
    final ext = picked.contains('.') ? picked.split('.').last : 'audio';
    final dest = File('${dir.path}/remind_sound.$ext');
    try {
      await File(picked).copy(dest.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak bisa membaca berkas audio itu.')));
      return;
    }
    setState(() => _remindSound = 'file://${dest.path}');
    await _saveReminderPrefs();
    await _syncReminder();
    await ReminderService.preview(_remindSound);
  }

  Future<void> _useDefaultSound() async {
    setState(() => _remindSound = null);
    await _saveReminderPrefs();
    await _syncReminder();
    await ReminderService.preview(null);
  }

  Widget _reminderCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Pengingat minum', style: _monoStyle(11)),
                const Spacer(),
                Switch(value: _remindOn, onChanged: _toggleRemind),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _remindOn
                  ? (_remindLeft != null
                      ? 'Berbunyi dalam ${Telemetry.mmss(_remindLeft!.inSeconds)}'
                      : 'Menunggu jadwal dari alat…')
                  : 'Nonaktif',
              style: _monoStyle(12, color: _remindOn ? _water : _dim),
            ),
            if (_remindOn) ...[
              const SizedBox(height: 10),
              Text(_remindSound == null
                      ? 'Nada: bawaan'
                      : 'Nada: ${_shortPath(_remindSound!)}',
                  style: _monoStyle(11), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _pickSound,
                    style: _reminderBtn(),
                    child: Text('Pilih audio', style: _monoStyle(11, color: _water)),
                  ),
                  OutlinedButton(
                    onPressed: _useDefaultSound,
                    style: _reminderBtn(),
                    child: Text('Nada bawaan', style: _monoStyle(11, color: _water)),
                  ),
                  OutlinedButton(
                    onPressed: () => ReminderService.preview(_remindSound),
                    style: _reminderBtn(),
                    child: Text('Uji', style: _monoStyle(11, color: _water)),
                  ),
                ],
              ),
              Row(
                children: [
                  Text('Getar', style: _monoStyle(11)),
                  Switch(
                    value: _remindVibrate,
                    onChanged: (v) async {
                      setState(() => _remindVibrate = v);
                      await _saveReminderPrefs();
                      await _syncReminder();
                    },
                  ),
                ],
              ),
              if (!_exactOk)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Izin alarm tepat waktu belum aktif. Pengingat bisa meleset beberapa menit; '
                    'aktifkan di Pengaturan › Aplikasi › Alarm & pengingat.',
                    style: _monoStyle(11, color: _warn),
                  ),
                ),
            ],
          ],
        ),
      );

  ButtonStyle _reminderBtn() => OutlinedButton.styleFrom(
        side: const BorderSide(color: _line),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      );

  String _shortPath(String uri) {
    final name = uri.split('/').last;
    return name.length > 28 ? '…${name.substring(name.length - 26)}' : name;
  }

  // Firmware menaikkan `hb` tiap push. Angka berat dan suhu bisa identik
  // antar-kiriman, jadi hanya counter ini yang membedakan alat diam dari mati.
  int? _lastHb;
  DateTime? _lastHbAt;

  void _trackHeartbeat(Telemetry t) {
    if (t.heartbeat == 0) return; // firmware lama: belum mengirim hb
    if (t.heartbeat != _lastHb) {
      _lastHb = t.heartbeat;
      _lastHbAt = DateTime.now();
    }
  }


  // Riwayat harian: web menulis /daily/<tanggal> saat statistik berubah. App
  // membacanya sekali saat dashboard dibuka, bukan tiap poll — node ini tumbuh
  // dan app tidak butuh real-time untuk data kemarin.
  List<MapEntry<String, Map<String, dynamic>>> _history = const [];
  bool _historyLoaded = false;

  Future<void> _loadHistory() async {
    if (_historyLoaded) return;
    _historyLoaded = true;
    try {
      final url = '${_session.coasterUrl(_base)}/daily.json${_session.suffix}';
      final res = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final raw = jsonDecode(res.body);
      if (raw is! Map) return;
      final entries = raw.entries
          .where((e) => e.value is Map)
          .map((e) => MapEntry(e.key as String,
              Map<String, dynamic>.from(e.value as Map)))
          .toList()
        ..sort((a, b) => b.key.compareTo(a.key));
      if (!mounted) return;
      setState(() => _history = entries.take(7).toList());
    } catch (_) {
      // Riwayat tidak wajib: dashboard tetap jalan tanpa node ini.
    }
  }


  // ── Target harian ─────────────────────────────────────────────────────────
  // Alat tidak punya jam (tanpa NTP): angka dari alat kumulatif sejak reset
  // manual. "Hari ini" = selisih terhadap nilai saat tanggal berganti, disimpan
  // di perangkat. Tanpa baseline, hari baru langsung terisi semua air kemarin.
  int _goalMl = 2000;
  DateTime? _dayKey;
  double _dayBaseMl = 0;
  int _dayBaseDrink = 0;

  String _todayKey() =>
      '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-'
      '${DateTime.now().day.toString().padLeft(2, '0')}';

  Future<void> _loadGoal() async {
    final prefs = await SharedPreferences.getInstance();
    _goalMl = prefs.getInt('goal_ml') ?? 2000;
    final key = prefs.getString('day_base_date') ?? '';
    if (key == _todayKey()) {
      _dayBaseMl = prefs.getDouble('day_base_ml') ?? 0;
      _dayBaseDrink = prefs.getInt('day_base_drink') ?? 0;
      _dayKey = DateTime.now();
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _saveDayBase(double ml, int drink) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('day_base_date', _todayKey());
    await prefs.setDouble('day_base_ml', ml);
    await prefs.setInt('day_base_drink', drink);
    _dayKey = DateTime.now();
    _dayBaseMl = ml;
    _dayBaseDrink = drink;
  }

  /// Angka harian. Baseline dipasang ulang saat tanggal berganti atau saat
  /// hitungan alat turun (tombol reset di alat), supaya selisih tidak negatif.
  double _computeDayMl(Telemetry t) {
    final turun = t.totalMl < _dayBaseMl || t.drinkCount < _dayBaseDrink;
    if (_dayKey == null || turun) {
      // Baseline baru dipasang pada nilai saat ini, jadi hari ini dimulai dari
      // nol. Mengembalikan totalMl di sini akan mengklaim semua air yang diminum
      // berhari-hari lalu sebagai milik hari ini.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _saveDayBase(t.totalMl, t.drinkCount);
      });
      return 0;
    }
    return (t.totalMl - _dayBaseMl).clamp(0, double.infinity).toDouble();
  }

  double _dayMl = 0;

  Widget _goalCard(Telemetry t) {
    final ml = _dayMl;
    final pct = _goalMl > 0 ? (ml / _goalMl).clamp(0.0, 1.0) : 0.0;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Hari ini', style: _monoStyle(11)),
              const Spacer(),
              Text('${(pct * 100).round()}%  ${ml.toStringAsFixed(0)} / $_goalMl ml',
                  style: _monoStyle(11, color: _water)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: _panel2,
              valueColor: const AlwaysStoppedAnimation(_water),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyCard() {
    if (_history.isEmpty) return const SizedBox.shrink();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Riwayat', style: _monoStyle(11, color: _dim)),
          const SizedBox(height: 8),
          for (final e in _history)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(e.key, style: _monoStyle(12, color: _ink))),
                  Text(
                    '${(e.value['total_ml'] as num? ?? 0).toStringAsFixed(1)} ml',
                    style: _monoStyle(12, color: _water),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _syncLine() {
    final stale = _lastHbAt != null &&
        DateTime.now().difference(_lastHbAt!).inSeconds > 90;
    return Row(
      children: [
        Text('CLOUD',
            style: _monoStyle(11, color: stale ? _alarm : _water)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            stale
                ? 'Alat tidak mengirim data (${DateTime.now().difference(_lastHbAt!).inSeconds} detik)'
                : _lastSync == null
                    ? 'menunggu sinkron pertama…'
                    : 'sinkron ${TimeOfDay.fromDateTime(_lastSync!).format(context)}',
            style: _monoStyle(11, color: stale ? _alarm : _ink),
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: _panel,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(16),
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
                    Text('Berat', style: _monoStyle(11)),
                    const SizedBox(height: 4),
                    Text(t.weightG.toStringAsFixed(1),
                        style: _monoStyle(34,
                            color: _ink, weight: FontWeight.w600)),
                    Text('gram', style: _monoStyle(11)),
                    const SizedBox(height: 14),
                    Text('Air terdeteksi', style: _monoStyle(11)),
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
              style: _monoStyle(11)),
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
                      fontWeight: FontWeight.w500,
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
    final timing = t.canonicalState == 'TIMING';
    final rem = _liveRemaining(t);
    // Sisa 0 saat timer belum mulai bukan berarti waktunya habis: tanpa
    // gerbang ini bar terlihat penuh dan seolah alarm sudah lewat.
    final progress = (timing && targetSec > 0)
        ? (1 - rem / targetSec).clamp(0.0, 1.0)
        : 0.0;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Sisa waktu', style: _monoStyle(11)),
              const Spacer(),
              Text('target ${t.targetIntervalMin.toStringAsFixed(1)} menit',
                  style: _monoStyle(11)),
            ],
          ),
          const SizedBox(height: 6),
          Text(timing ? Telemetry.mmss(rem) : '--:--',
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
            Text(label, style: _monoStyle(11)),
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
                Text('Total sejak reset', style: _monoStyle(11)),
                const Spacer(),
                Text('${t.totalMl.toStringAsFixed(1)} ml',
                    style: _monoStyle(20, color: _water, weight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _countCell('Minum', '${t.drinkCount}', _ok),
                _countCell('Isi ulang', '${t.refillCount}', _water),
                _countCell('Curang', '${t.cheatCount}', _alarm),
              ],
            ),
          ],
        ),
      );

  // Tanpa Semantics, pembaca layar membacakan angka dan label sebagai dua teks
  // lepas tanpa hubungan. Label gabungan membuat satu sel terbaca utuh.
  Widget _countCell(String label, String value, Color color) => Expanded(
        child: Semantics(
          label: '$label: $value',
          excludeSemantics: true,
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 12),
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
                Text(label, style: _monoStyle(11)),
              ],
            ),
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
          Text('Kontrol', style: _monoStyle(11, color: _water)),
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
              style: _monoStyle(11, color: _dim)),
          if (widget.onClaimDevice != null) ...[
            const Divider(color: _line, height: 20),
            Text('Node alat', style: _monoStyle(12, color: _ink)),
            const SizedBox(height: 2),
            Text(
              _session.hasDevice
                  ? 'tertaut: ${_session.deviceUid}'
                  : 'belum tertaut, memakai node akun',
              style: _monoStyle(11, color: _session.hasDevice ? _ok : _warn),
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
                      fontWeight: FontWeight.w500, color: _ink, height: 1.15)),
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
                  style: _monoStyle(11, color: _dim)),
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
