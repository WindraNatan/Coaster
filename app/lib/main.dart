import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

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

// Palet Clean Nordic / Porcelain Light:
// porcelain white surface, slate 50 background, deep sky water accent.
const _bg = Color(0xFFF8FAFC);
const _panel = Color(0xFFFFFFFF);
const _panel2 = Color(0xFFF1F5F9);
const _line = Color(0xFFE2E8F0);
const _ink = Color(0xFF0F172A);
const _dim = Color(0xFF64748B);
const _water = Color(0xFF0284C7);
const _ok = Color(0xFF059669);
const _warn = Color(0xFFD97706);
const _alarm = Color(0xFFE11D48);

const _cardShadow = [
  BoxShadow(
    color: Color(0x0A0F172A),
    blurRadius: 18,
    offset: Offset(0, 4),
  ),
  BoxShadow(
    color: Color(0x050F172A),
    blurRadius: 4,
    offset: Offset(0, 1),
  ),
];

const _display = 'SpaceGrotesk';
const _mono = 'JetBrainsMono';

const _pollInterval = Duration(seconds: 20);
const _glassDisplayMl = 500.0;

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

String _fmtTargetMnt(double m) {
  if (m < 1) return '${(m * 60).round()} detik';
  final n = (m * 10).round() / 10;
  return n == n.roundToDouble()
      ? '${n.toInt()} menit'
      : '${n.toStringAsFixed(1)} menit';
}

void main() => runApp(const CoasterApp());

class CoasterApp extends StatelessWidget {
  const CoasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Hydration Coaster',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: _bg,
        fontFamily: _display,
        colorScheme: const ColorScheme.light(
          surface: _panel,
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
  final http.Client? client;
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
    final effective = (saved != null && saved.isNotEmpty) ? saved : kFirebaseUrl;
    if (!mounted) return;
    setState(() {
      _savedUrl = effective;
      _session = (session != null && session.valid) ? session : null;
      _url = (effective.isNotEmpty && _session != null) ? effective : null;
    });

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
  bool _claiming = false;

  void _editUrl() => setState(() { _url = null; _editingUrl = true; });

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
  final http.Client? client;
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
    loadApiKey().then((k) {
      if (!mounted) return;
      setState(() {
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

  String get _urlValue {
    final typed = _ctrl.text.trim();
    return typed.isNotEmpty ? typed : kFirebaseUrl;
  }

  String get _keyValue {
    final typed = _key.text.trim();
    return typed.isNotEmpty ? typed : kFirebaseApiKey;
  }

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
      backgroundColor: _bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _line),
                boxShadow: _cardShadow,
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Smart Hydration',
                      style: TextStyle(
                          fontFamily: _display,
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                          letterSpacing: -0.5)),
                  Text('Coaster',
                      style: TextStyle(
                          fontFamily: _display,
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                          color: _water,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 8),
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
                        labelStyle: _monoStyle(12, color: _dim),
                        hintText:
                            'https://nama-proyek-default-rtdb.asia-southeast1.firebasedatabase.app',
                        hintStyle: _monoStyle(11, color: _dim),
                        filled: true,
                        fillColor: _panel2,
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _line)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _water, width: 2)),
                        errorText: _error,
                        errorStyle: _monoStyle(11, color: _alarm),
                      ),
                    ),
                    const SizedBox(height: 10),
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
                      labelStyle: _monoStyle(12, color: _dim),
                      filled: true,
                      fillColor: _panel2,
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _line)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _water, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _pass,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    style: _monoStyle(13, color: _ink),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: _monoStyle(12, color: _dim),
                      filled: true,
                      fillColor: _panel2,
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _line)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _water, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_needsKey)
                    TextField(
                      controller: _key,
                      autocorrect: false,
                      style: _monoStyle(13, color: _ink),
                      decoration: InputDecoration(
                        labelText: 'Web API Key proyek Firebase',
                        labelStyle: _monoStyle(12, color: _dim),
                        helperText: 'Project settings → General → Web API Key',
                        helperStyle: _monoStyle(11, color: _dim),
                        filled: true,
                        fillColor: _panel2,
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _line)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _water, width: 2)),
                        errorText: _authError,
                        errorStyle: _monoStyle(11, color: _alarm),
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (_authError != null) ...[
                    Text(_authError!,
                        style: _monoStyle(12, color: _alarm), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _water,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      style: _monoStyle(12, color: _water, weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
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
  final http.Client? client;
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

class TlmStreamState {
  final Map<String, dynamic> json = <String, dynamic>{};

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
  double? _hintTargetLama;
  CloudConfig? _cfg;
  String? _error;
  bool _loading = true;
  bool _remindOn = false;
  String? _remindSound;
  bool _remindVibrate = true;
  Duration? _remindLeft;
  bool _exactOk = true;
  Timer? _remindTick;
  bool _polling = false;
  DateTime? _lastSync;
  DateTime? _frameAt;
  DateTime? _streamFrameAt;
  DateTime? _cfgFrameAt;
  Timer? _timer;
  StreamSubscription<String>? _streamSub;
  Timer? _streamRetry;
  late final http.Client _client;

  late final AnimationController _pulse;
  final _intervalCtrl = TextEditingController();
  final _emptyCupCtrl = TextEditingController();

  String get _base => widget.url;

  void _catatUbahTimer() {
    setState(() {
      _hintTargetLama =
          (_t?.canonicalState == 'TIMING') ? _t!.targetIntervalMin : null;
    });
  }

  void _segarkanHintTimer() {
    final t = _t;
    final lama = _hintTargetLama;
    if (lama == null || t == null) return;
    if (t.canonicalState != 'TIMING' ||
        (t.targetIntervalMin - lama).abs() > 0.01) {
      _hintTargetLama = null;
    }
  }

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
    } catch (_) {}
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
    _cfgFrameAt = DateTime.now();
    setState(() => _cfg = CloudConfig.fromJson(Map<String, dynamic>.from(_cfgCache)));
  }

  void _onStreamLine(String line) {
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
      _segarkanHintTimer();
      _streamFrameAt = DateTime.now();
      _error = null;
      _loading = false;
      _lastSync = DateTime.now();
    });
    _trackHeartbeat(_t!);
    _dayMl = _computeDayMl(_t!);
    _maybeReloadHistory(_t!);
    _syncReminderOnData();
  }

  void _restartStream() {
    _streamSub?.cancel();
    _streamSub = null;
    _streamRetry?.cancel();
    if (!mounted) return;
    _streamRetry = Timer(const Duration(milliseconds: 800), () async {
      if (!mounted) return;
      try {
        final renewed = await refreshSession(_session, client: _client);
        if (renewed != null && mounted) setState(() => _session = renewed);
      } catch (_) {}
      _openStream();
    });
  }

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
    _emptyCupCtrl.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
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
        Map<String, dynamic>? cMap;
        if (results[1].statusCode == 200) {
          final cRaw = jsonDecode(results[1].body);
          if (cRaw is Map) {
            cMap = Map<String, dynamic>.from(cRaw);
            c = CloudConfig.fromJson(cMap);
            if (_cfg == null) {
              _intervalCtrl.text = c.manualIntervalMin.toString();
              _emptyCupCtrl.text = c.emptyCupWeightG.toStringAsFixed(0);
            }
          }
        }
        if (!mounted) return;
        final usang = _streamFrameAt != null && _streamFrameAt!.isAfter(mulai);
        final cfgUsang = _cfgFrameAt != null && _cfgFrameAt!.isAfter(mulai);
        setState(() {
          if (!usang) {
            if (_frameIsNew(t)) _frameAt = DateTime.now();
            _t = t;
            _segarkanHintTimer();
          }
          if (!cfgUsang) _cfg = c;
          _error = null;
          _loading = false;
          _lastSync = DateTime.now();
        });
        if (!cfgUsang && cMap != null) {
          _cfgCache
            ..clear()
            ..addAll(cMap);
          _cfgState.json
            ..clear()
            ..addAll(cMap);
        }
        if (!usang) {
          _stream.json
            ..clear()
            ..addAll(Map<String, dynamic>.from(tRaw));
          _trackHeartbeat(t);
          _dayMl = _computeDayMl(t);
          _maybeReloadHistory(t);
          _syncReminderOnData();
        }
      } else {
        if (!mounted) return;
        setState(() {
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      try {
        final renewed = await refreshSession(_session, client: _client);
        if (renewed != null && mounted) setState(() => _session = renewed);
      } catch (_) {}
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

  Future<bool> _setSession({required String ownerUid, required bool active}) async {
    try {
      final res = await _client
          .put(
            Uri.parse('${_session.coasterUrl(_base)}/session.json${_session.suffix}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'owner': ownerUid,
              'active': active,
              'at': DateTime.now().millisecondsSinceEpoch,
            }),
          )
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> _mulaiSesi() async {
    final pilih = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                  'Pilih mode timer dulu. Pilihan ini yang dipakai alat selama sesi berjalan.',
                  style: _monoStyle(12, color: _dim)),
            ),
            for (final opt in const [
              ('DEMO', 'Demo 15 detik'),
              ('AUTO_DHT', 'Otomatis (sesuaikan dengan suhu ruangan)'),
              ('MANUAL', 'Manual tetap'),
            ])
              ListTile(
                title: Text(opt.$2, style: _monoStyle(13, color: _ink, weight: FontWeight.w500)),
                onTap: () => Navigator.pop(ctx, opt.$1),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (pilih == null || !mounted) return;
    await _setMode(pilih);
    final ok = await _setSession(ownerUid: _session.uid, active: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(ok ? 'Sesi dimulai.' : 'Gagal memulai sesi.')));
  }

  Future<void> _akhiriSesi() async {
    final ok = await _setSession(ownerUid: '', active: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Sesi ditutup. Alat tidur.' : 'Gagal menutup sesi.')));
  }

  void _setMuted(bool v) {
    HapticFeedback.selectionClick();
    setState(() => _cfg = (_cfg ?? _defaultCfg).copyWith(muted: v));
    _patchConfig({'muted': v});
  }

  Future<void> _setMode(String mode) async {
    HapticFeedback.selectionClick();
    setState(() => _cfg = (_cfg ?? _defaultCfg).copyWith(timerMode: mode));
    await _patchConfig({'timer_mode': mode});
    _catatUbahTimer();
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
    _catatUbahTimer();
  }

  void _sendEmptyCup() {
    final text = _emptyCupCtrl.text.trim();
    final v = double.tryParse(text);
    if (v == null || v < 35.0 || v > 300.0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Berat gelas kosong harus 35 sampai 300 gram.')));
      return;
    }
    setState(() => _cfg = (_cfg ?? _defaultCfg).copyWith(emptyCupWeightG: v));
    _patchConfig({'empty_cup_weight_g': v});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Berat gelas kosong (${v.toStringAsFixed(0)} g) disimpan.')));
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
        return _dim;
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
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _line, height: 1),
        ),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                    letterSpacing: .1)),
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _syncLine(),
                    const SizedBox(height: 14),
                    if (_loading)
                      _card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              const CircularProgressIndicator(color: _water),
                              const SizedBox(height: 16),
                              Text('Menghubungkan ke Firebase…',
                                  style: _monoStyle(12, color: _dim)),
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
                                size: 36,
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
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  minimumSize: const Size(160, 44),
                                ),
                                child: Text('Coba lagi',
                                    style: _monoStyle(12, color: _water, weight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      _goalCard(t),
                      const SizedBox(height: 14),
                      _glassCard(t),
                      const SizedBox(height: 14),
                      _badgeCard(t, reduceMotion),
                      const SizedBox(height: 14),
                      _countdownCard(t),
                      const SizedBox(height: 14),
                      _reminderCard(),
                      const SizedBox(height: 14),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _envChip('Suhu', t.tempC, ' °C')),
                            const SizedBox(width: 14),
                            Expanded(
                                child: _envChip('Kelembapan', t.humidityPct, ' %')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _dailyCard(t),
                      if (_history.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _historyCard(),
                      ],
                      const SizedBox(height: 14),
                      _controlsCard(),
                      const SizedBox(height: 14),
                      Text(
                        'RTDB: ${Uri.parse(_base).host} · stream langsung · '
                        'skala gelas tampilan ${_glassDisplayMl.toInt()} ml.',
                        style: _monoStyle(11, color: _dim),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Pengingat minum ───────────────────────────────────────────────────────

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

  int _liveRemaining(Telemetry t) {
    final at = _frameAt ?? _lastSync;
    if (at == null) return t.remainingSec;
    final rem = t.remainingSec - DateTime.now().difference(at).inSeconds;
    return rem < 0 ? 0 : rem;
  }

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
                Text('Pengingat minum', style: _monoStyle(11, color: _dim, weight: FontWeight.w600)),
                const Spacer(),
                Switch(
                  value: _remindOn,
                  activeThumbColor: _water,
                  onChanged: _toggleRemind,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _remindOn
                  ? (_remindLeft != null
                      ? 'Berbunyi dalam ${Telemetry.mmss(_remindLeft!.inSeconds)}'
                      : 'Menunggu jadwal dari alat…')
                  : 'Nonaktif',
              style: _monoStyle(12, color: _remindOn ? _water : _dim, weight: FontWeight.w600),
            ),
            if (_remindOn) ...[
              const SizedBox(height: 10),
              Text(_remindSound == null
                      ? 'Nada: bawaan'
                      : 'Nada: ${_shortPath(_remindSound!)}',
                  style: _monoStyle(11, color: _dim), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _pickSound,
                    style: _reminderBtn(),
                    child: Text('Pilih audio', style: _monoStyle(11, color: _water, weight: FontWeight.w600)),
                  ),
                  OutlinedButton(
                    onPressed: _useDefaultSound,
                    style: _reminderBtn(),
                    child: Text('Nada bawaan', style: _monoStyle(11, color: _water, weight: FontWeight.w600)),
                  ),
                  OutlinedButton(
                    onPressed: () => ReminderService.preview(_remindSound),
                    style: _reminderBtn(),
                    child: Text('Uji', style: _monoStyle(11, color: _water, weight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('Getar', style: _monoStyle(11, color: _dim)),
                  const Spacer(),
                  Switch(
                    value: _remindVibrate,
                    activeThumbColor: _water,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      );

  String _shortPath(String uri) {
    final name = uri.split('/').last;
    return name.length > 28 ? '…${name.substring(name.length - 26)}' : name;
  }

  int? _lastHb;
  DateTime? _lastHbAt;

  void _trackHeartbeat(Telemetry t) {
    if (t.heartbeat == 0) return;
    if (t.heartbeat != _lastHb) {
      _lastHb = t.heartbeat;
      _lastHbAt = DateTime.now();
    }
  }

  List<MapEntry<String, Map<String, dynamic>>> _history = const [];
  bool _historyLoading = false;
  int? _historyDrinks;

  void _maybeReloadHistory(Telemetry t) {
    if (_historyDrinks == t.drinkCount) return;
    final pertama = _historyDrinks == null;
    _historyDrinks = t.drinkCount;
    if (!pertama) _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (_historyLoading) return;
    _historyLoading = true;
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
    } finally {
      _historyLoading = false;
    }
  }

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

  double _computeDayMl(Telemetry t) {
    final turun = t.totalMl < _dayBaseMl || t.drinkCount < _dayBaseDrink;
    if (_dayKey == null || turun) {
      _setDayFresh(_dayKey == null && !turun && t.totalMl > 0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _saveDayBase(t.totalMl, t.drinkCount);
      });
      return 0;
    }
    _setDayFresh(false);
    return (t.totalMl - _dayBaseMl).clamp(0, double.infinity).toDouble();
  }

  void _setDayFresh(bool nilai) {
    if (_dayFresh == nilai) return;
    _dayFresh = nilai;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  double _dayMl = 0;
  bool _dayFresh = false;

  Widget _goalCard(Telemetry t) {
    final ml = _dayMl;
    final pct = _goalMl > 0 ? (ml / _goalMl).clamp(0.0, 1.0) : 0.0;
    final percentInt = (pct * 100).round();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _water,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text('Hari ini', style: _monoStyle(12, color: _ink, weight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _panel2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _line),
                ),
                child: Text('Target $_goalMl ml',
                    style: _monoStyle(11, color: _dim, weight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: SizedBox(
              width: 148,
              height: 148,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(148, 148),
                    painter: _RadialRingPainter(
                      progress: pct,
                      trackColor: _panel2,
                      progressColor: _water,
                      strokeWidth: 11,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$percentInt%',
                        style: _monoStyle(30, color: _ink, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${ml.toStringAsFixed(0)} / $_goalMl ml',
                        style: _monoStyle(12, color: _water, weight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _panel2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Status Hidrasi', style: _monoStyle(11, color: _dim)),
                Text(
                  pct >= 1.0
                      ? 'Target harian terpenuhi'
                      : '${(_goalMl - ml > 0 ? (_goalMl - ml) : 0).toStringAsFixed(0)} ml lagi',
                  style: _monoStyle(11, color: pct >= 1.0 ? _ok : _ink, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (_dayFresh) ...[
            const SizedBox(height: 10),
            Text(
              'Hari baru: hitungan dimulai dari posisi saat aplikasi dibuka.',
              style: _monoStyle(10, color: _dim),
            ),
          ],
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
          Text('Riwayat', style: _monoStyle(11, color: _dim, weight: FontWeight.w600)),
          const SizedBox(height: 10),
          for (final e in _history)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(e.key, style: _monoStyle(12, color: _ink))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _water.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${(e.value['total_ml'] as num? ?? 0).toStringAsFixed(1)} ml',
                      style: _monoStyle(12, color: _water, weight: FontWeight.w600),
                    ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (stale ? _alarm : _water).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('CLOUD',
                style: _monoStyle(10, color: stale ? _alarm : _water, weight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
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
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry? padding, Color? color}) => Container(
        decoration: BoxDecoration(
          color: color ?? _panel,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(20),
          boxShadow: _cardShadow,
        ),
        padding: padding ?? const EdgeInsets.all(18),
        child: child,
      );

  Widget _glassCard(Telemetry t) {
    final fill = (t.waterMl / _glassDisplayMl).clamp(0.0, 1.0);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 110,
                height: 156,
                child: CustomPaint(
                  painter: _GlassPainter(
                    fill: fill,
                    present: t.cupPresent,
                    water: _water,
                    line: _line,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Berat', style: _monoStyle(11, color: _dim)),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(t.weightG.toStringAsFixed(1),
                            style: _monoStyle(34,
                                color: _ink, weight: FontWeight.w700)),
                        const SizedBox(width: 4),
                        Text('gram', style: _monoStyle(11, color: _dim)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('Air terdeteksi', style: _monoStyle(11, color: _dim)),
                    const SizedBox(height: 2),
                    Text('${t.waterMl.toStringAsFixed(0)} ml',
                        style: _monoStyle(18, color: _water, weight: FontWeight.w600)),
                    if (!t.cupPresent) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _warn.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Gelas tidak di tatakan',
                            style: _monoStyle(11, color: _warn, weight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Skala gelas tampilan: ${_glassDisplayMl.toInt()} ml',
              style: _monoStyle(11, color: _dim)),
        ],
      ),
    );
  }

  Widget _badgeCard(Telemetry t, bool reduceMotion) {
    final color = _stateColor(t.canonicalState);
    final name = t.stateName;
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
            borderRadius: BorderRadius.circular(20),
            boxShadow: _cardShadow,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: TextStyle(
                      fontFamily: _display,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
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
    final progress = (timing && targetSec > 0)
        ? (1 - rem / targetSec).clamp(0.0, 1.0)
        : 0.0;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: timing ? _water : _dim,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text('Sisa waktu', style: _monoStyle(12, color: _ink, weight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _panel2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _line),
                ),
                child: Text('target ${_fmtTargetMnt(t.targetIntervalMin)}',
                    style: _monoStyle(11, color: _dim)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(timing ? Telemetry.mmss(rem) : '--:--',
              style: _monoStyle(36, color: _ink, weight: FontWeight.w700)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: label == 'Suhu' ? _warn : _water,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(label, style: _monoStyle(11, color: _dim, weight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Text('${value.toStringAsFixed(1)}$unit',
                style: _monoStyle(22, color: _ink, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(label == 'Suhu' ? 'Sensor DHT11' : 'Kelembapan ruang',
                style: _monoStyle(10, color: _dim)),
          ],
        ),
      );

  Widget _dailyCard(Telemetry t) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _ok,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text('Akumulasi sesi', style: _monoStyle(12, color: _ink, weight: FontWeight.w700)),
                const Spacer(),
                Text('${t.totalMl.toStringAsFixed(1)} ml',
                    style: _monoStyle(20, color: _water, weight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _countCell('Minum', '${t.drinkCount}', _ok, isFirst: true),
                _countCell('Isi ulang', '${t.refillCount}', _water),
                _countCell('Tegukan kecil', '${t.cheatCount}', _alarm, isLast: true),
              ],
            ),
          ],
        ),
      );

  Widget _countCell(String label, String value, Color color, {bool isFirst = false, bool isLast = false}) => Expanded(
        child: Semantics(
          label: '$label: $value',
          excludeSemantics: true,
          child: Container(
            margin: EdgeInsets.only(
              left: isFirst ? 0 : 4,
              right: isLast ? 0 : 4,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: _panel2,
              border: Border.all(color: _line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(value,
                    style: _monoStyle(20, color: color, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(label, style: _monoStyle(11, color: _dim)),
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
          Text('Kontrol', style: _monoStyle(11, color: _water, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('Buzzer', style: _monoStyle(13, color: _ink, weight: FontWeight.w500))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (muted ? _warn : _ok).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(muted ? 'OFF' : 'ON',
                    style: _monoStyle(11, color: muted ? _warn : _ok, weight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Switch(
                value: muted,
                activeThumbColor: _water,
                onChanged: _setMuted,
              ),
            ],
          ),
          const Divider(color: _line, height: 24),
          Text('Mode timer', style: _monoStyle(12, color: _ink, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'DEMO',
                  label: Text('DEMO 15 dtk', style: TextStyle(fontFamily: _mono, fontSize: 11))),
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
                  states.contains(WidgetState.selected) ? _water.withValues(alpha: 0.12) : _panel2),
              foregroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected) ? _water : _dim),
              side: WidgetStateProperty.all(const BorderSide(color: _line)),
            ),
            onSelectionChanged: (s) => _setMode(s.first),
          ),
          if (mode == 'MANUAL') ...[
            const SizedBox(height: 14),
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
                      labelStyle: _monoStyle(11, color: _dim),
                      filled: true,
                      fillColor: _panel2,
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _line)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _water, width: 2)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _sendInterval,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(88, 44),
                  ),
                  child: Text('Kirim', style: _monoStyle(12, color: _water, weight: FontWeight.w600)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emptyCupCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: _monoStyle(13, color: _ink),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Berat gelas kosong (g)',
                    labelStyle: _monoStyle(11, color: _dim),
                    filled: true,
                    fillColor: _panel2,
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _line)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _water, width: 2)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _sendEmptyCup,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(88, 44),
                ),
                child: Text('Simpan', style: _monoStyle(12, color: _water, weight: FontWeight.w600)),
              ),
            ],
          ),
          if (_hintTargetLama != null) ...[
            const SizedBox(height: 10),
            Text(
              'Pengaturan baru aktif siklus berikutnya (saat ini masih memakai target ${_fmtTargetMnt(_hintTargetLama!)}).',
              style: _monoStyle(11, color: _warn),
            ),
          ],
          const Divider(color: _line, height: 24),
          Text('Sesi', style: _monoStyle(12, color: _ink, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_t?.standby == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('Mode siaga aktif. Sesi belum dimulai, alarm dan timer berhenti.',
                  style: _monoStyle(11, color: _warn)),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _mulaiSesi,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(0, 44),
                  ),
                  child: Text('Mulai sesi', style: _monoStyle(12, color: _water, weight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _akhiriSesi,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(0, 44),
                  ),
                  child: Text('Akhiri sesi', style: _monoStyle(12, color: _dim, weight: FontWeight.w500)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Kalibrasi bobot kosong dapat disimpan via cloud atau USB.',
              style: _monoStyle(11, color: _dim)),
          if (widget.onClaimDevice != null) ...[
            const Divider(color: _line, height: 24),
            Text('Alat', style: _monoStyle(12, color: _ink, weight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              _session.hasDevice
                  ? 'tertaut: ${_session.deviceUid}'
                  : 'belum tertaut ke alat',
              style: _monoStyle(11, color: _session.hasDevice ? _ok : _warn, weight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: widget.onClaimDevice,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  minimumSize: const Size(0, 44),
                ),
                child: Text(_session.hasDevice ? 'Ganti alat' : 'Tautkan alat',
                    style: _monoStyle(12, color: _water, weight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Layar klaim alat ────────────────────────────────────────────────────────

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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _line),
                      boxShadow: _cardShadow,
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Tautkan alat',
                            style: TextStyle(fontFamily: _display, fontSize: 28,
                                fontWeight: FontWeight.w600, color: _ink, height: 1.15)),
                        const SizedBox(height: 10),
                        Text('Masukkan kode 8 karakter dari alat.',
                            style: _monoStyle(12, color: _ink, weight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        Text('Masukkan 8 karakter kode alat dari stiker perangkat atau log koneksi. '
                            'Kode yang sama dapat digunakan di aplikasi web.',
                            style: _monoStyle(11, color: _dim)),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _code,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.go,
                          onSubmitted: (_) => _submit(),
                          maxLength: 8,
                          style: _monoStyle(22, color: _ink, weight: FontWeight.w700),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: 'A1B2C3D4',
                            hintStyle: _monoStyle(22, color: _dim.withValues(alpha: 0.5)),
                            filled: true,
                            fillColor: _panel2,
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _line)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _water, width: 2)),
                            errorText: _error,
                            errorStyle: _monoStyle(11, color: _alarm),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: _busy ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: _water,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(_busy ? 'Menautkan…' : 'Tautkan',
                                style: _monoStyle(13, color: Colors.white, weight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Sudah ditautkan di perangkat lain? Cukup masukkan kodenya sekali lagi.',
                            style: _monoStyle(11, color: _dim), textAlign: TextAlign.center),
                        if (widget.onCancel != null) ...[
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _busy ? null : widget.onCancel,
                            child: Text('Lewati untuk sekarang',
                                style: _monoStyle(12, color: _dim)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

// ── Gelas: Nordic tumbler visualizer + coaster pedestal ─────────────────────

class _GlassPainter extends CustomPainter {
  final double fill; // 0..1
  final bool present;
  final Color water;
  final Color line;

  _GlassPainter({
    required this.fill,
    required this.present,
    required this.water,
    required this.line,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Coaster pedestal di bagian bawah
    final coasterRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h - 14, w * 0.84, 8),
      const Radius.circular(4),
    );
    final coasterPaint = Paint()
      ..color = present ? line : line.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(coasterRect, coasterPaint);

    final coasterRim = Paint()
      ..color = present ? line.withValues(alpha: 0.8) : line.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(coasterRect, coasterRim);

    // Dimensi tumbler kaca
    const insetX = 14.0;
    const topY = 12.0;
    final bottomY = h - 16.0;
    final glassRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(insetX, topY, w - insetX, bottomY),
      const Radius.circular(12),
    );

    // Latar belakang frost porselen saat gelas ada
    if (present) {
      final frostPaint = Paint()
        ..color = const Color(0xFFF1F5F9).withValues(alpha: 0.6)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(glassRect, frostPaint);
    }

    // Kolom air dengan Nordic water gradient
    if (present && fill > 0) {
      final totalWaterHeight = (bottomY - topY - 4) * fill;
      final waterTopY = bottomY - totalWaterHeight;
      final waterRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(insetX + 2, waterTopY, w - insetX - 2, bottomY - 2),
        const Radius.circular(10),
      );

      canvas.save();
      canvas.clipRRect(glassRect);

      final waterPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF38BDF8),
            water,
          ],
        ).createShader(Rect.fromLTRB(insetX, waterTopY, w - insetX, bottomY));
      canvas.drawRRect(waterRect, waterPaint);

      // Garis permukaan meniskus air
      final meniscusPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(insetX + 6, waterTopY + 1),
        Offset(w - insetX - 6, waterTopY + 1),
        meniscusPaint,
      );

      // Refleksi vertikal halus pada sisi kiri tumbler
      final reflectPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(insetX + 5, waterTopY + 4, 3, totalWaterHeight - 8),
          const Radius.circular(2),
        ),
        reflectPaint,
      );

      canvas.restore();
    }

    // Garis luar kontur gelas
    final glassOutline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = present ? line : line.withValues(alpha: 0.4);

    if (present) {
      canvas.drawRRect(glassRect, glassOutline);

      // Garis ketebalan dasar gelas khas Nordic glassware
      final baseLine = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = line.withValues(alpha: 0.6);
      canvas.drawLine(
        Offset(insetX + 4, bottomY - 6),
        Offset(w - insetX - 4, bottomY - 6),
        baseLine,
      );

      // Skala takaran halus di samping gelas (25%, 50%, 75%)
      final tickPaint = Paint()
        ..color = line.withValues(alpha: 0.7)
        ..strokeWidth = 1;
      for (final fraction in [0.25, 0.50, 0.75]) {
        final tickY = bottomY - (bottomY - topY) * fraction;
        canvas.drawLine(
          Offset(w - insetX - 6, tickY),
          Offset(w - insetX - 2, tickY),
          tickPaint,
        );
      }
    } else {
      final dashPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = line.withValues(alpha: 0.5);
      canvas.drawRRect(glassRect, dashPaint);
    }
  }

  @override
  bool shouldRepaint(_GlassPainter old) =>
      old.fill != fill ||
      old.present != present ||
      old.water != water ||
      old.line != line;
}

// ── Visualizer Cincin Hidrasi Melingkar (Circular Radial Progress Ring) ──────
class _RadialRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  const _RadialRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    this.strokeWidth = 11.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // Lingkar latar porselen
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Lingkar progres aktif
    if (progress > 0) {
      final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // Mulai tepat dari arah jam 12 (-90 derajat)
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadialRingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.progressColor != progressColor ||
      old.strokeWidth != strokeWidth;
}
