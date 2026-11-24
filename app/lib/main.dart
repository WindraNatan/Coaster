import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth.dart';
import 'painters.dart';
import 'project_config.dart';
import 'reminder.dart';
import 'telemetry.dart';
import 'theme.dart';

const _pollInterval = Duration(seconds: 20);
const _glassDisplayMl = 500.0;

const _defaultCfg = CloudConfig(
  timerMode: 'AUTO_DHT',
  manualIntervalMin: 30,
  emptyCupWeightG: 130,
  muted: false,
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
      theme: buildShcTheme(),
      home: const RootPage(),
    );
  }
}

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
  bool _editingUrl = false;
  bool _claiming = false;

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
      session = await refreshSession(session, client: widget.client);
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
        setState(() {
          _session = _session!.copyWith(deviceUid: found);
        });
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
        setState(() {
          _session = _session!.copyWith(deviceUid: found);
        });
        saveSession(_session!);
      });
    }
  }

  void _editUrl() => setState(() {
        _url = null;
        _editingUrl = true;
      });

  Future<void> _logout() async {
    await saveSession(null);
    if (!mounted) return;
    setState(() {
      _url = null;
      _session = null;
      _claiming = false;
      _editingUrl = false;
    });
  }

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
        showUrlField: _editingUrl,
      );
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
        onCancel: () => setState(() {
          _claiming = false;
        }),
      );
    }
    return DashboardScreen(
      key: ValueKey('$url/${session.deviceUid}'),
      url: url,
      session: session,
      onChangeUrl: _editUrl,
      client: widget.client,
      onClaimDevice: () => setState(() {
        _claiming = true;
      }),
      onLogout: _logout,
    );
  }
}

class ConnectScreen extends StatefulWidget {
  final void Function(String url, AuthSession session) onConnect;
  final String? initialUrl;
  final AuthSession? initialSession;
  final bool showUrlField;
  final bool showKeyField;
  final http.Client? client;
  const ConnectScreen({
    super.key,
    required this.onConnect,
    this.initialUrl,
    this.initialSession,
    this.showUrlField = false,
    this.showKeyField = false,
    this.client,
  });

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

  late final bool _needsUrl = widget.showUrlField ||
      (kFirebaseUrl.isEmpty && (_ctrl.text.trim().isEmpty));
  bool _storedKeyMissing = true;
  bool get _needsKey =>
      widget.showKeyField || (kFirebaseApiKey.isEmpty && _storedKeyMissing);

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
    setState(() {
      _busy = true;
      _authError = null;
      _error = null;
    });
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
      backgroundColor: ShcPalette.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                decoration: shcCardDecoration(radius: 20),
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/brand-logo.png',
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            excludeFromSemantics: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Smart Hydration Coaster',
                                style: shcSans(
                                  18,
                                  color: ShcPalette.ink,
                                  weight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                'Pendamping hidrasi harianmu',
                                style: shcSans(12, color: ShcPalette.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Masuk untuk memantau isi gelas, jadwal pengingat, dan riwayat minummu.',
                      style: shcSans(13, color: ShcPalette.inkSoft, height: 1.5),
                    ),
                    const SizedBox(height: 22),
                    if (_needsUrl) ...[
                      TextField(
                        controller: _ctrl,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.next,
                        style: shcMono(13, color: ShcPalette.ink),
                        decoration: shcInputDecoration(
                          label: 'URL Firebase RTDB',
                          hint:
                              'https://nama-proyek-default-rtdb.asia-southeast1.firebasedatabase.app',
                          error: _error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Salin alamat Realtime Database dari proyek Firebase milikmu.',
                        style: shcSans(12, color: ShcPalette.muted, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      style: shcSans(14, color: ShcPalette.ink, weight: FontWeight.w500),
                      decoration: shcInputDecoration(label: 'Email'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _pass,
                      obscureText: true,
                      textInputAction: _needsKey ? TextInputAction.next : TextInputAction.done,
                      onSubmitted: _needsKey ? null : (_) => _submit(),
                      autofillHints: const [AutofillHints.password],
                      style: shcSans(14, color: ShcPalette.ink, weight: FontWeight.w500),
                      decoration: shcInputDecoration(label: 'Password'),
                    ),
                    if (_needsKey) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _key,
                        autocorrect: false,
                        style: shcMono(13, color: ShcPalette.ink),
                        decoration: shcInputDecoration(
                          label: 'Web API Key proyek Firebase',
                          helper: 'Project settings > General > Web API Key',
                          error: _authError,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (_authError != null && !_needsKey) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: ShcPalette.dangerBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ShcPalette.dangerBorder),
                        ),
                        child: Text(
                          _authError!,
                          style: shcSans(12, color: ShcPalette.danger, weight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(
                        _busy
                            ? 'Sebentar...'
                            : (_registerMode ? 'Buat akun' : 'Masuk'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _registerMode = !_registerMode),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        foregroundColor: ShcPalette.accent,
                      ),
                      child: Text(
                        _registerMode
                            ? 'Sudah punya akun? Masuk'
                            : 'Belum punya akun? Daftar',
                        style: shcSans(13, color: ShcPalette.accent, weight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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

class DashboardScreen extends StatefulWidget {
  final String url;
  final AuthSession session;
  final VoidCallback onChangeUrl;
  final VoidCallback? onClaimDevice;
  final Future<void> Function()? onLogout;
  final http.Client? client;
  const DashboardScreen({
    super.key,
    required this.url,
    required this.session,
    required this.onChangeUrl,
    this.onClaimDevice,
    this.onLogout,
    this.client,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
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
  StreamSubscription<String>? _cfgSub;
  Timer? _streamRetry;
  late final http.Client _client;

  final TlmStreamState _stream = TlmStreamState();
  final TlmStreamState _cfgState = TlmStreamState();
  String _streamBuf = '';
  final Map<String, dynamic> _cfgCache = {};
  String _cfgBuf = '';

  final _intervalCtrl = TextEditingController();
  final _emptyCupCtrl = TextEditingController();

  int? _lastHb;
  DateTime? _lastHbAt;

  List<MapEntry<String, Map<String, dynamic>>> _history = const [];
  bool _historyLoading = false;
  int? _historyDrinks;

  int _goalMl = 2000;
  DateTime? _dayKey;
  double _dayBaseMl = 0;
  int _dayBaseDrink = 0;
  double _dayMl = 0;
  bool _dayFresh = false;
  ReminderPlan? _plan;

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
          .listen(
            _onStreamLine,
            onError: (_) => _restartStream(),
            onDone: _restartStream,
            cancelOnError: true,
          );
      _openCfgStream();
    } catch (_) {
      _restartStream();
    }
  }

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
        _client
            .get(Uri.parse('$base/telemetry.json${_session.suffix}'))
            .timeout(const Duration(seconds: 8)),
        _client
            .get(Uri.parse('$base/config.json${_session.suffix}'))
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
          .showSnackBar(SnackBar(content: Text('Gagal mengirim pengaturan: $e')));
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
      backgroundColor: ShcPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Text(
                  'Mulai sesi baru',
                  style: shcSans(16, color: ShcPalette.ink, weight: FontWeight.w700),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Pilih cara tatakan mengatur jadwal pengingat minum selama sesi berjalan.',
                  style: shcSans(12, color: ShcPalette.inkSoft, height: 1.4),
                ),
              ),
              const Divider(color: ShcPalette.hairline, height: 1),
              for (final opt in const [
                ('DEMO', 'Demo 15 detik', 'Siklus cepat 15 detik untuk demonstrasi.'),
                ('AUTO_DHT', 'Otomatis (sesuaikan dengan suhu ruangan)', 'Jeda menyesuaikan suhu dan kelembapan.'),
                ('MANUAL', 'Manual tetap', 'Memakai jeda menit pilihanmu sendiri.'),
              ])
                ListTile(
                  title: Text(
                    opt.$2,
                    style: shcSans(14, color: ShcPalette.ink, weight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    opt.$3,
                    style: shcSans(12, color: ShcPalette.muted),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: ShcPalette.muted),
                  onTap: () => Navigator.pop(ctx, opt.$1),
                ),
            ],
          ),
        ),
      ),
    );
    if (pilih == null || !mounted) return;
    await _setMode(pilih);
    final ok = await _setSession(ownerUid: _session.uid, active: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Sesi dimulai.' : 'Gagal memulai sesi.')),
    );
  }

  Future<void> _akhiriSesi() async {
    final ok = await _setSession(ownerUid: '', active: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Sesi diakhiri. Tatakan masuk mode istirahat.' : 'Gagal menutup sesi.')),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Interval harus 1 sampai 180 menit.')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berat gelas kosong harus 35 sampai 300 gram.')),
      );
      return;
    }
    setState(() => _cfg = (_cfg ?? _defaultCfg).copyWith(emptyCupWeightG: v));
    _patchConfig({'empty_cup_weight_g': v});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Berat gelas kosong (${v.toStringAsFixed(0)} g) disimpan.')),
    );
  }

  Future<void> _editGoalSheet() async {
    final saved = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ShcPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _GoalSheetBody(initialGoal: _goalMl),
    );
    if (saved == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('goal_ml', saved);
    if (!mounted) return;
    setState(() => _goalMl = saved);
  }

  _StateTone _stateTone(String s) {
    switch (s) {
      case 'STABLE':
        return const _StateTone(
          fg: ShcPalette.ok,
          bg: ShcPalette.okBg,
          border: ShcPalette.okBorder,
          icon: Icons.check_circle_outline,
        );
      case 'TIMING':
        return const _StateTone(
          fg: ShcPalette.accent,
          bg: ShcPalette.accentSoft,
          border: ShcPalette.hairline,
          icon: Icons.timer_outlined,
        );
      case 'ALERT_DRINK':
      case 'ALERT_REFILL':
        return const _StateTone(
          fg: ShcPalette.warn,
          bg: ShcPalette.warnBg,
          border: ShcPalette.warnBorder,
          icon: Icons.notifications_active_outlined,
        );
      case 'ALERT_CHEAT':
        return const _StateTone(
          fg: ShcPalette.danger,
          bg: ShcPalette.dangerBg,
          border: ShcPalette.dangerBorder,
          icon: Icons.warning_amber_rounded,
        );
      default:
        return const _StateTone(
          fg: ShcPalette.inkSoft,
          bg: ShcPalette.surface,
          border: ShcPalette.hairline,
          icon: Icons.pause_circle_outline,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final statusIcon = _t != null && _error == null
        ? Icons.cloud_done_outlined
        : _error != null
            ? Icons.cloud_off_outlined
            : Icons.sync;
    final statusColor = _t != null && _error == null
        ? ShcPalette.ok
        : _error != null
            ? ShcPalette.danger
            : ShcPalette.muted;
    final statusLabel = _error != null
        ? 'Koneksi bermasalah'
        : _t != null
            ? 'Terhubung'
            : 'Menghubungkan';

    return Scaffold(
      backgroundColor: ShcPalette.canvas,
      appBar: AppBar(
        backgroundColor: ShcPalette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: SizedBox(
            height: 1,
            width: double.infinity,
            child: ColoredBox(color: ShcPalette.hairline),
          ),
        ),
        titleSpacing: 16,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/brand-logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Smart Hydration Coaster',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: shcSans(
                    16,
                    color: ShcPalette.ink,
                    weight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: statusLabel,
              child: Icon(
                statusIcon,
                size: 18,
                color: statusColor,
                semanticLabel: statusLabel,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Menu akun dan perangkat',
            icon: const Icon(Icons.more_vert, color: ShcPalette.inkSoft),
            color: ShcPalette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: ShcPalette.hairline),
            ),
            onSelected: (value) {
              if (value == 'claim' && widget.onClaimDevice != null) {
                widget.onClaimDevice!();
              } else if (value == 'url') {
                widget.onChangeUrl();
              } else if (value == 'logout' && widget.onLogout != null) {
                widget.onLogout!();
              }
            },
            itemBuilder: (context) => [
              if (widget.onClaimDevice != null)
                PopupMenuItem<String>(
                  value: 'claim',
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 18, color: ShcPalette.accent),
                      const SizedBox(width: 10),
                      Text(
                        _session.hasDevice ? 'Ganti alat' : 'Tautkan alat',
                        style: shcSans(13, weight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              PopupMenuItem<String>(
                value: 'url',
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz, size: 18, color: ShcPalette.inkSoft),
                    const SizedBox(width: 10),
                    Text('Ubah URL', style: shcSans(13, weight: FontWeight.w500)),
                  ],
                ),
              ),
              if (widget.onLogout != null)
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(Icons.logout, size: 18, color: ShcPalette.danger),
                      const SizedBox(width: 10),
                      Text(
                        'Keluar',
                        style: shcSans(13, color: ShcPalette.danger, weight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 880;
            final maxW = isWide ? 1080.0 : 560.0;
            final outerPad = isWide
                ? const EdgeInsets.symmetric(horizontal: 24, vertical: 20)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 14);

            return RefreshIndicator(
              color: ShcPalette.accent,
              backgroundColor: ShcPalette.surface,
              onRefresh: () async {
                await _poll();
                await _loadHistory();
                await _syncReminder();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: outerPad,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: _buildBody(t, isWide),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(Telemetry? t, bool isWide) {
    if (_loading) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Column(
                children: [
                  const CircularProgressIndicator(color: ShcPalette.accent),
                  const SizedBox(height: 16),
                  Text(
                    'Menghubungkan ke Firebase…',
                    style: shcSans(13, color: ShcPalette.inkSoft, weight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (t == null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(
                    _error != null ? Icons.cloud_off : Icons.hourglass_empty,
                    color: _error != null ? ShcPalette.danger : ShcPalette.muted,
                    size: 36,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _error != null
                        ? 'Gagal membaca cloud:\n$_error'
                        : 'Belum ada data telemetry.\n'
                            'Pastikan tatakan gelas menyala dan terhubung Wi-Fi 2,4 GHz.',
                    textAlign: TextAlign.center,
                    style: shcSans(13, color: ShcPalette.ink, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _poll,
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final gap = isWide ? 16.0 : 12.0;

    final envRow = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _envChip('Suhu', t.tempC, ' °C')),
          SizedBox(width: gap),
          Expanded(child: _envChip('Kelembapan', t.humidityPct, ' %')),
        ],
      ),
    );

    final footerNote = Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Text(
        'Sinkron online aktif (${Uri.parse(_base).host}), skala gelas ${_glassDisplayMl.toInt()} ml.',
        style: shcSans(11, color: ShcPalette.muted),
        textAlign: TextAlign.center,
      ),
    );

    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _syncLine(),
          SizedBox(height: gap),
          _glassCard(t),
          SizedBox(height: gap),
          _badgeCard(t),
          SizedBox(height: gap),
          _countdownCard(t),
          SizedBox(height: gap),
          _goalCard(t),
          SizedBox(height: gap),
          envRow,
          SizedBox(height: gap),
          _dailyCard(t),
          if (_history.isNotEmpty) ...[
            SizedBox(height: gap),
            _historyCard(),
          ],
          SizedBox(height: gap),
          _reminderCard(),
          SizedBox(height: gap),
          _controlsCard(),
          SizedBox(height: gap),
          footerNote,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: FocusTraversalGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _syncLine(),
                    SizedBox(height: gap),
                    _glassCard(t),
                    SizedBox(height: gap),
                    _badgeCard(t),
                    SizedBox(height: gap),
                    _countdownCard(t),
                    SizedBox(height: gap),
                    _goalCard(t),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 7,
              child: FocusTraversalGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    envRow,
                    SizedBox(height: gap),
                    _dailyCard(t),
                    if (_history.isNotEmpty) ...[
                      SizedBox(height: gap),
                      _historyCard(),
                    ],
                    SizedBox(height: gap),
                    _reminderCard(),
                    SizedBox(height: gap),
                    _controlsCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: gap),
        footerNote,
      ],
    );
  }

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin notifikasi ditolak. Pengingat tidak bisa berbunyi.'),
          ),
        );
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
        const SnackBar(content: Text('Tidak bisa membaca berkas audio itu.')),
      );
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
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Pengingat minum',
                      style: shcSans(13, color: ShcPalette.ink, weight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: 'Pengingat minum',
                  child: Switch(
                    value: _remindOn,
                    onChanged: _toggleRemind,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _remindOn
                  ? (_remindLeft != null
                      ? 'Berbunyi dalam ${Telemetry.mmss(_remindLeft!.inSeconds)}'
                      : 'Menunggu jadwal dari tatakan...')
                  : 'Nonaktif',
              style: shcSans(
                12,
                color: _remindOn ? ShcPalette.accent : ShcPalette.inkSoft,
                weight: FontWeight.w500,
              ),
            ),
            if (_remindOn) ...[
              const SizedBox(height: 10),
              Text(
                _remindSound == null
                    ? 'Nada: bawaan'
                    : 'Nada: ${_shortPath(_remindSound!)}',
                style: shcSans(12, color: ShcPalette.muted),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _pickSound,
                    style: _reminderBtn(),
                    child: const Text('Pilih audio'),
                  ),
                  OutlinedButton(
                    onPressed: _useDefaultSound,
                    style: _reminderBtn(),
                    child: const Text('Nada bawaan'),
                  ),
                  OutlinedButton(
                    onPressed: () => ReminderService.preview(_remindSound),
                    style: _reminderBtn(),
                    child: const Text('Uji'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Getar',
                      style: shcSans(12, color: ShcPalette.inkSoft, weight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    label: 'Getar saat pengingat',
                    child: Switch(
                      value: _remindVibrate,
                      onChanged: (v) async {
                        setState(() => _remindVibrate = v);
                        await _saveReminderPrefs();
                        await _syncReminder();
                      },
                    ),
                  ),
                ],
              ),
              if (!_exactOk)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Izin alarm tepat waktu belum aktif. Pengingat bisa meleset beberapa menit; '
                    'aktifkan di Pengaturan > Aplikasi > Alarm & pengingat.',
                    style: shcSans(11, color: ShcPalette.warn, weight: FontWeight.w500),
                  ),
                ),
            ],
          ],
        ),
      );

  ButtonStyle _reminderBtn() => OutlinedButton.styleFrom(
        foregroundColor: ShcPalette.accent,
        side: const BorderSide(color: ShcPalette.controlBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      );

  String _shortPath(String uri) {
    final name = uri.split('/').last;
    return name.length > 28 ? '…${name.substring(name.length - 26)}' : name;
  }

  void _trackHeartbeat(Telemetry t) {
    if (t.heartbeat == 0) return;
    if (t.heartbeat != _lastHb) {
      _lastHb = t.heartbeat;
      _lastHbAt = DateTime.now();
    }
  }

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
          .map((e) => MapEntry(e.key as String, Map<String, dynamic>.from(e.value as Map)))
          .toList()
        ..sort((a, b) => b.key.compareTo(a.key));
      if (!mounted) return;
      setState(() => _history = entries.take(7).toList());
    } catch (_) {
    } finally {
      _historyLoading = false;
    }
  }

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
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Hari ini',
                    style: shcSans(14, color: ShcPalette.ink, weight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: InkWell(
                  onTap: _editGoalSheet,
                  borderRadius: BorderRadius.circular(10),
                  child: Semantics(
                    label: 'Ubah target minum harian $_goalMl ml',
                    excludeSemantics: true,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: ShcPalette.subtle,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'Target $_goalMl ml',
                                style: shcSans(12, color: ShcPalette.inkSoft, weight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.edit_outlined, size: 14, color: ShcPalette.inkSoft),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Semantics(
              label: 'Progres hidrasi hari ini $percentInt persen, ${ml.toStringAsFixed(0)} dari $_goalMl ml',
              excludeSemantics: true,
              child: SizedBox(
                width: 144,
                height: 144,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(144, 144),
                      painter: HydrationRingPainter(
                        progress: pct,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$percentInt%',
                              style: shcMono(28, color: ShcPalette.ink, weight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${ml.toStringAsFixed(0)} / $_goalMl ml',
                              style: shcMono(12, color: ShcPalette.accent, weight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: ShcPalette.subtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: MergeSemantics(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Status hidrasi',
                      style: shcSans(12, color: ShcPalette.inkSoft),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      pct >= 1.0
                          ? 'Target harian terpenuhi'
                          : '${(_goalMl - ml > 0 ? (_goalMl - ml) : 0).toStringAsFixed(0)} ml lagi',
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: shcSans(
                        12,
                        color: pct >= 1.0 ? ShcPalette.ok : ShcPalette.ink,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_dayFresh) ...[
            const SizedBox(height: 10),
            Text(
              'Hari baru: hitungan dimulai dari posisi saat aplikasi dibuka.',
              style: shcSans(11, color: ShcPalette.muted),
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
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Riwayat',
                    style: shcSans(14, color: ShcPalette.ink, weight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '7 hari terakhir',
                style: shcSans(11, color: ShcPalette.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          HistoryBarsList(entries: _history, goalMl: _goalMl),
        ],
      ),
    );
  }

  Widget _syncLine() {
    final stale = _lastHbAt != null &&
        DateTime.now().difference(_lastHbAt!).inSeconds > 90;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: shcCardDecoration(
        color: stale ? ShcPalette.dangerBg : ShcPalette.surface,
        borderColor: stale ? ShcPalette.dangerBorder : ShcPalette.hairline,
        radius: 12,
      ),
      child: Row(
        children: [
          Icon(
            stale ? Icons.sync_problem : Icons.cloud_done_outlined,
            size: 16,
            color: stale ? ShcPalette.danger : ShcPalette.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              stale
                  ? 'Alat tidak mengirim data (${DateTime.now().difference(_lastHbAt!).inSeconds} detik)'
                  : _lastSync == null
                      ? 'Menunggu pembaruan pertama...'
                      : 'Sinkron online ${TimeOfDay.fromDateTime(_lastSync!).format(context)}',
              style: shcSans(
                12,
                color: stale ? ShcPalette.danger : ShcPalette.inkSoft,
                weight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsetsGeometry? padding,
    Color? color,
    Color? borderColor,
  }) =>
      Container(
        decoration: shcCardDecoration(color: color, borderColor: borderColor),
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
              Semantics(
                label: 'Ilustrasi gelas berisi ${t.waterMl.toStringAsFixed(0)} ml',
                child: SizedBox(
                  width: 108,
                  height: 152,
                  child: CustomPaint(
                    painter: CoasterGlassPainter(
                      fill: fill,
                      present: t.cupPresent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MergeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Berat', style: shcSans(12, color: ShcPalette.inkSoft)),
                          const SizedBox(height: 2),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    t.weightG.toStringAsFixed(1),
                                    style: shcMono(32, color: ShcPalette.ink, weight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 5),
                                  Text('gram', style: shcSans(12, color: ShcPalette.muted)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    MergeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Air terdeteksi', style: shcSans(12, color: ShcPalette.inkSoft)),
                          const SizedBox(height: 2),
                          Text(
                            '${t.waterMl.toStringAsFixed(0)} ml',
                            style: shcMono(18, color: ShcPalette.accent, weight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    if (!t.cupPresent) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: ShcPalette.warnBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ShcPalette.warnBorder),
                        ),
                        child: Text(
                          'Gelas tidak di tatakan',
                          style: shcSans(11, color: ShcPalette.warn, weight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Kapasitas gelas acuan: ${_glassDisplayMl.toInt()} ml',
            style: shcSans(12, color: ShcPalette.muted),
          ),
        ],
      ),
    );
  }

  Widget _badgeCard(Telemetry t) {
    final tone = _stateTone(t.canonicalState);
    return Semantics(
      container: true,
      liveRegion: true,
      child: _card(
        color: tone.bg,
        borderColor: tone.border,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(tone.icon, color: tone.fg, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.stateName,
                    style: shcSans(
                      20,
                      color: tone.fg,
                      weight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.reason,
                    style: shcSans(13, color: ShcPalette.ink, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
            children: [
              Expanded(
                child: Text(
                  'Sisa waktu',
                  style: shcSans(13, color: ShcPalette.ink, weight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ShcPalette.subtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'target ${_fmtTargetMnt(t.targetIntervalMin)}',
                    overflow: TextOverflow.ellipsis,
                    style: shcSans(11, color: ShcPalette.inkSoft, weight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              timing ? Telemetry.mmss(rem) : '--:--',
              style: shcMono(34, color: ShcPalette.ink, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            label: timing ? 'Sisa waktu ${Telemetry.mmss(rem)}' : 'Penghitung waktu berhenti',
            excludeSemantics: true,
            child: Container(
              decoration: BoxDecoration(
                color: ShcPalette.subtle,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: ShcPalette.controlBorder.withValues(alpha: 0.45),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation(ShcPalette.accent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _envChip(String label, double value, String unit) {
    final isTemp = label == 'Suhu';
    return _card(
      padding: const EdgeInsets.all(16),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isTemp ? Icons.thermostat_outlined : Icons.water_drop_outlined,
                  size: 16,
                  color: isTemp ? ShcPalette.warn : ShcPalette.accent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: shcSans(12, color: ShcPalette.inkSoft, weight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${value.toStringAsFixed(1)}$unit',
                style: shcMono(22, color: ShcPalette.ink, weight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isTemp ? 'Suhu ruangan' : 'Kelembapan ruang',
              style: shcSans(11, color: ShcPalette.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dailyCard(Telemetry t) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Akumulasi sesi',
                    overflow: TextOverflow.ellipsis,
                    style: shcSans(13, color: ShcPalette.ink, weight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${t.totalMl.toStringAsFixed(1)} ml',
                      style: shcMono(19, color: ShcPalette.accent, weight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: ShcPalette.subtle,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    _countCell('Minum', '${t.drinkCount}', ShcPalette.ok),
                    const VerticalDivider(color: ShcPalette.hairline, width: 1),
                    _countCell('Isi ulang', '${t.refillCount}', ShcPalette.accent),
                    const VerticalDivider(color: ShcPalette.hairline, width: 1),
                    _countCell('Tegukan kecil', '${t.cheatCount}', ShcPalette.warn),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _countCell(String label, String value, Color color) => Expanded(
        child: Semantics(
          label: '$label: $value',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: shcMono(20, color: color, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: shcSans(11, color: ShcPalette.inkSoft),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
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
          Semantics(
            header: true,
            child: Text(
              'Pengaturan',
              style: shcSans(14, color: ShcPalette.ink, weight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Buzzer',
                  style: shcSans(13, color: ShcPalette.ink, weight: FontWeight.w500),
                ),
              ),
              ExcludeSemantics(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: muted ? ShcPalette.warnBg : ShcPalette.okBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: muted ? ShcPalette.warnBorder : ShcPalette.okBorder,
                    ),
                  ),
                  child: Text(
                    muted ? 'OFF' : 'ON',
                    style: shcSans(
                      11,
                      color: muted ? ShcPalette.warn : ShcPalette.ok,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: 'Bisukan buzzer',
                child: Switch(
                  value: muted,
                  onChanged: _setMuted,
                ),
              ),
            ],
          ),
          const Divider(color: ShcPalette.hairline, height: 24),
          Text(
            'Mode pengingat',
            style: shcSans(13, color: ShcPalette.ink, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: 'DEMO',
                label: FittedBox(fit: BoxFit.scaleDown, child: Text('DEMO 15 dtk')),
              ),
              ButtonSegment(
                value: 'AUTO_DHT',
                label: FittedBox(fit: BoxFit.scaleDown, child: Text('AUTO_DHT')),
              ),
              ButtonSegment(
                value: 'MANUAL',
                label: FittedBox(fit: BoxFit.scaleDown, child: Text('MANUAL')),
              ),
            ],
            selected: {mode},
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
              textStyle: WidgetStatePropertyAll(
                shcSans(11, weight: FontWeight.w700),
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? ShcPalette.accentSoft
                    : ShcPalette.subtle,
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? ShcPalette.accent
                    : ShcPalette.inkSoft,
              ),
              side: const WidgetStatePropertyAll(
                BorderSide(color: ShcPalette.controlBorder),
              ),
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
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _sendInterval(),
                    style: shcMono(13, color: ShcPalette.ink),
                    decoration: shcInputDecoration(
                      label: 'Interval dasar (menit)',
                      dense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _sendInterval,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(84, 48)),
                  child: const Text('Kirim'),
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
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _sendEmptyCup(),
                  style: shcMono(13, color: ShcPalette.ink),
                  decoration: shcInputDecoration(
                    label: 'Berat gelas kosong (g)',
                    dense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _sendEmptyCup,
                style: OutlinedButton.styleFrom(minimumSize: const Size(84, 48)),
                child: const Text('Simpan'),
              ),
            ],
          ),
          if (_hintTargetLama != null) ...[
            const SizedBox(height: 10),
            Semantics(
              container: true,
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: ShcPalette.warnBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ShcPalette.warnBorder),
                ),
                child: Text(
                  'Pengaturan baru aktif siklus berikutnya (saat ini masih memakai target ${_fmtTargetMnt(_hintTargetLama!)}).',
                  style: shcSans(12, color: ShcPalette.warn, weight: FontWeight.w500),
                ),
              ),
            ),
          ],
          const Divider(color: ShcPalette.hairline, height: 24),
          Text(
            'Sesi minum',
            style: shcSans(13, color: ShcPalette.ink, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_t?.standby == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Mode istirahat aktif. Pengingat dan hitungan sedang berhenti.',
                style: shcSans(12, color: ShcPalette.warn, weight: FontWeight.w500),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _mulaiSesi,
                  child: const Text('Mulai sesi'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _akhiriSesi,
                  child: const Text('Akhiri sesi'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Kalibrasi bobot gelas kosong bisa langsung disimpan lewat cloud.',
            style: shcSans(11, color: ShcPalette.muted),
          ),
          if (widget.onClaimDevice != null) ...[
            const Divider(color: ShcPalette.hairline, height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tatakan tertaut',
                        style: shcSans(13, color: ShcPalette.ink, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _session.hasDevice
                            ? 'Perangkat tersambung ke akun'
                            : 'Belum ada perangkat ditautkan',
                        style: shcSans(
                          12,
                          color: _session.hasDevice ? ShcPalette.ok : ShcPalette.warn,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: widget.onClaimDevice,
                  child: Text(_session.hasDevice ? 'Ganti alat' : 'Tautkan alat'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StateTone {
  final Color fg;
  final Color bg;
  final Color border;
  final IconData icon;

  const _StateTone({
    required this.fg,
    required this.bg,
    required this.border,
    required this.icon,
  });
}

class ClaimScreen extends StatefulWidget {
  final String url;
  final AuthSession session;
  final void Function(String deviceUid) onClaimed;
  final VoidCallback? onCancel;
  final http.Client? client;
  const ClaimScreen({
    super.key,
    required this.url,
    required this.session,
    required this.onClaimed,
    this.onCancel,
    this.client,
  });

  @override
  State<ClaimScreen> createState() => _ClaimScreenState();
}

class _ClaimScreenState extends State<ClaimScreen> {
  final _code = TextEditingController();
  String? _error;
  String? _info;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final deviceUid = await claimDevice(
        base: widget.url,
        code: _code.text,
        session: widget.session,
        client: widget.client,
      );
      if (!mounted) return;
      widget.onClaimed(deviceUid);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _findOwn() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final linked = await discoverDevice(
        base: widget.url,
        session: widget.session,
        client: widget.client,
      );
      if (linked.isNotEmpty) {
        final updated = widget.session.copyWith(deviceUid: linked);
        await saveSession(updated);
        if (!mounted) return;
        widget.onClaimed(linked);
        return;
      }
      final code = await findOwnClaimCode(
        base: widget.url,
        session: widget.session,
        client: widget.client,
      );
      if (!mounted) return;
      if (code.isNotEmpty) {
        _code.text = code;
        setState(() {
          _info = 'Kode ditemukan: $code. Tekan tombol Tautkan.';
        });
      } else {
        setState(() {
          _error = 'Belum ada kode tersimpan di akun. Ketik 8 karakter dari stiker atau panduan alat.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal mencari tatakan. Periksa jaringan lalu coba lagi.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: ShcPalette.canvas,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  decoration: shcCardDecoration(radius: 20),
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Tautkan alat',
                        style: shcSans(
                          24,
                          color: ShcPalette.ink,
                          weight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Masukkan kode 8 karakter dari stiker tatakan atau panduan alat agar data sinkron di HP dan web.',
                        style: shcSans(13, color: ShcPalette.inkSoft, height: 1.45),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _code,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _submit(),
                        maxLength: 8,
                        style: shcMono(
                          22,
                          color: ShcPalette.ink,
                          weight: FontWeight.w600,
                          letterSpacing: 3,
                        ),
                        decoration: shcInputDecoration(
                          label: 'Kode tatakan (8 karakter)',
                          hint: 'A1B2C3D4',
                          error: _error,
                        ).copyWith(counterText: ''),
                      ),
                      if (_info != null) ...[
                        const SizedBox(height: 10),
                        Semantics(
                          container: true,
                          liveRegion: true,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: ShcPalette.okBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: ShcPalette.okBorder),
                            ),
                            child: Text(
                              _info!,
                              style: shcSans(12, color: ShcPalette.ok, weight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: Text(_busy ? 'Menautkan...' : 'Tautkan'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _findOwn,
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('Cari tatakan saya'),
                      ),
                      if (widget.onCancel != null) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _busy ? null : widget.onCancel,
                          style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                          child: Text(
                            'Lewati untuk sekarang',
                            style: shcSans(13, color: ShcPalette.inkSoft, weight: FontWeight.w500),
                          ),
                        ),
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

class _GoalSheetBody extends StatefulWidget {
  final int initialGoal;
  const _GoalSheetBody({required this.initialGoal});

  @override
  State<_GoalSheetBody> createState() => _GoalSheetBodyState();
}

class _GoalSheetBodyState extends State<_GoalSheetBody> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialGoal.toString());
  String? _err;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final val = int.tryParse(_ctrl.text.trim());
    if (val == null || val < 500 || val > 6000) {
      setState(() => _err = 'Target harus antara 500 dan 6000 ml.');
      return;
    }
    Navigator.pop(context, val);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Atur target harian',
                      style: shcSans(16, color: ShcPalette.ink, weight: FontWeight.w700),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: ShcPalette.inkSoft),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Masukkan target minum harian antara 500 sampai 6000 ml.',
              style: shcSans(12, color: ShcPalette.inkSoft),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              style: shcMono(15, color: ShcPalette.ink, weight: FontWeight.w600),
              decoration: shcInputDecoration(
                label: 'Target minum (ml)',
                error: _err,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: const Text('Simpan target'),
            ),
          ],
        ),
      ),
    );
  }
}
