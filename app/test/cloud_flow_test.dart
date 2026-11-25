import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:smart_coaster/auth.dart';
import 'package:smart_coaster/main.dart';
import 'package:smart_coaster/reminder.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _url = 'https://proyek-rtdb.asia-southeast1.firebasedatabase.app';
// _poll() menarik telemetry.json dan config.json terpisah; mock harus membedakan path.
final _telemetryBody = jsonEncode({
  'weight_g': 315,
  'water_ml': 185,
  'temp_c': 27,
  'humidity_pct': 60,
  'remaining_sec': 423,
  'target_interval_min': 45,
  'total_ml': 750,
  'drink_count': 3,
  'refill_count': 1,
  'cheat_count': 0,
  'muted': false,
  'fsm_state': 'TIMING',
});
final _configBody = jsonEncode({
  'timer_mode': 'MANUAL',
  'manual_interval_min': 30,
  'empty_cup_weight_g': 130,
  'muted': false,
});

Future<void> _pumpApp(WidgetTester tester, MockClient client) async {
  await tester.pumpWidget(MaterialApp(
    home: DashboardScreen(
      url: _url,
      session: const AuthSession('test-token', 'test@example.com', 'uid-akun', 9999999999999,
          '', 'uid-test'),
      onChangeUrl: () {},
      client: client,
    ),
  ));
}

void main() {
  testWidgets('loading lalu data telemetry ter-render', (tester) async {
    final client = MockClient((req) async {
      if (req.url.path == '/users/uid-test/smart_coaster/telemetry.json') {
        return Response(_telemetryBody, 200);
      }
        if (req.url.path == '/users/uid-test/smart_coaster/config.json') {
        return Response(_configBody, 200);
      }
      return Response('{}', 200);
    });

    await _pumpApp(tester, client);
    expect(find.text('Menghubungkan ke Firebase…'), findsOneWidget);

    await tester.pump();

    expect(find.text('315.0'), findsOneWidget);
    expect(find.text('185 ml'), findsOneWidget);
    expect(find.text('07:03'), findsOneWidget);
    expect(find.text('TIMING'), findsOneWidget);
    expect(find.text('750.0 ml'), findsOneWidget);
    expect(find.text('27.0 °C'), findsOneWidget);
    expect(find.text('60.0 %'), findsOneWidget);
    expect(find.text('Gelas tidak di tatakan'), findsNothing);
  });

  testWidgets('error HTTP menampilkan pesan dan tombol coba lagi',
      (tester) async {
    final client = MockClient(
        (req) async => Response('boom', 500, request: req));
    await _pumpApp(tester, client);
    await tester.pump();
    expect(find.textContaining('Gagal membaca cloud:'), findsOneWidget);
    expect(find.textContaining('HTTP 500'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Coba lagi'), findsOneWidget);
  });

  testWidgets('DB kosong (null) menampilkan empty state', (tester) async {
    final client = MockClient((req) async => Response('null', 200));
    await _pumpApp(tester, client);
    await tester.pump();
    expect(find.textContaining('Belum ada data telemetry.'), findsOneWidget);
  });

  testWidgets('state turunan ALERT_MISSING_CUP render sebagai badge REFILL',
      (tester) async {
    final body = jsonEncode({
      'weight_g': 0,
      'water_ml': 0,
      'temp_c': 27,
      'humidity_pct': 60,
      'remaining_sec': 0,
      'target_interval_min': 30,
      'total_ml': 0,
      'drink_count': 0,
      'refill_count': 0,
      'cheat_count': 0,
      'muted': false,
      'fsm_state': 'ALERT_MISSING_CUP',
    });
    final client = MockClient((req) async => Response(
        req.url.path.endsWith('/config.json') ? _configBody : body, 200));
    await _pumpApp(tester, client);
    await tester.pump();
    expect(find.text('REFILL'), findsOneWidget);
    expect(find.text('gelas belum kembali ke tatakan'), findsOneWidget);
    expect(find.text('Gelas tidak di tatakan'), findsOneWidget);
  });

  testWidgets('toggle mute mengirim PATCH muted ke config.json',
      (tester) async {
    final patches = <String>[];
    final client = MockClient((req) async {
      if (req.method == 'PATCH') {
        patches.add('${req.url.path} ${req.body}');
        return Response('{}', 200);
      }
      return Response(
          req.url.path.endsWith('/config.json') ? _configBody : _telemetryBody, 200);
    });
    await _pumpApp(tester, client);
    await tester.pump();
    expect(find.text('ON'), findsOneWidget);

    // Pengingat juga memakai Switch, jadi pilih yang satu baris dengan 'Buzzer'.
    final buzzerSwitch = find.descendant(
        of: find.ancestor(
            of: find.text('Buzzer'), matching: find.byType(Row)).first,
        matching: find.byType(Switch));
    await tester.ensureVisible(buzzerSwitch);
    await tester.pump();
    await tester.tap(buzzerSwitch);
    await tester.pump();

    expect(patches, ['/users/uid-test/smart_coaster/config.json {"muted":true}']);
    expect(find.text('OFF'), findsOneWidget);
  });

  testWidgets('akhiri sesi menulis owner kosong dan active:false',
      (tester) async {
    final puts = <String>[];
    final client = MockClient((req) async {
      if (req.method == 'PUT' && req.url.path.endsWith('/session.json')) {
        puts.add('${req.url.path} ${req.body}');
        return Response('{}', 200);
      }
      return Response(
          req.url.path.endsWith('/config.json') ? _configBody : _telemetryBody, 200);
    });
    await _pumpApp(tester, client);
    await tester.pump();

    final tombol = find.text('Akhiri sesi');
    await tester.ensureVisible(tombol);
    await tester.pump();
    await tester.tap(tombol);
    await tester.pump();

    expect(puts, hasLength(1));
    expect(puts.first, startsWith('/users/uid-test/smart_coaster/session.json '));
    expect(puts.first, contains('"owner":""'));
    expect(puts.first, contains('"active":false'));
  });

  testWidgets('mulai sesi minta konfirmasi mode, patch mode dulu baru buka sesi',
      (tester) async {
    final urutan = <String>[];
    final client = MockClient((req) async {
      if (req.method == 'PATCH' || req.method == 'PUT') {
        urutan.add('${req.method} ${req.url.path} ${req.body}');
      }
      return Response('{}', 200);
    });
    await _pumpApp(tester, client);
    await tester.pump();

    final tombol = find.text('Mulai sesi');
    await tester.ensureVisible(tombol);
    await tester.pump();
    await tester.tap(tombol);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Demo 15 detik'), findsOneWidget);
    expect(urutan, isEmpty);

    await tester.tap(find.text('Demo 15 detik'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(urutan, hasLength(2));
    expect(urutan[0], 'PATCH /users/uid-test/smart_coaster/config.json {"timer_mode":"DEMO"}');
    expect(urutan[1], contains('PUT /users/uid-test/smart_coaster/session.json'));
    expect(urutan[1], contains('"owner":"uid-akun"'));
    expect(urutan[1], contains('"active":true'));
  });

  // Config adalah perintah pengguna sedangkan telemetry echo tertunda dari perangkat.
  testWidgets('telemetry.muted basi tidak menimpa config.muted',
      (tester) async {
    final staleTelemetry = jsonEncode({
      'weight_g': 315, 'water_ml': 185, 'temp_c': 27, 'humidity_pct': 60,
      'remaining_sec': 423, 'target_interval_min': 30, 'total_ml': 750,
      'drink_count': 3, 'refill_count': 1, 'cheat_count': 0,
      'fsm_state': 'TIMING',
      'muted': false,
    });
    final client = MockClient((req) async => Response(
        req.url.path.endsWith('/config.json')
            ? jsonEncode({'timer_mode': 'MANUAL', 'manual_interval_min': 30,
                          'empty_cup_weight_g': 130, 'muted': true})
            : staleTelemetry,
        200));
    await _pumpApp(tester, client);
    for (var i = 0; i < 4; i++) { await tester.pump(); }
    expect(find.text('Interval dasar (menit)'), findsOneWidget);
    final sw = tester.widget<Switch>(find.descendant(
        of: find.ancestor(
            of: find.text('Buzzer'), matching: find.byType(Row)).first,
        matching: find.byType(Switch)));
    expect(sw.value, isTrue,
        reason: 'config.muted=true harus menang atas telemetry.muted=false yang basi');
  });

  testWidgets('event patch sebagian diterapkan menurut path', (tester) async {
    final client = MockClient((req) async => Response(
        req.url.path.endsWith('/config.json') ? _configBody : _telemetryBody, 200));
    await _pumpApp(tester, client);
    await tester.pump();

    final state = TlmStreamState();
    state.apply('event: put\ndata: {"path":"/","data":{"weight_g":300,"muted":false,'
        '"fsm_state":"TIMING","water_ml":150,"temp_c":27,"humidity_pct":60,'
        '"remaining_sec":100,"target_interval_min":30,"total_ml":500,'
        '"drink_count":2,"refill_count":1,"cheat_count":0}}\n\n');
    expect(state.json['weight_g'], 300);
    expect(state.json['muted'], false);

    state.apply('event: patch\ndata: {"path":"/","data":{"muted":true}}\n\n');
    expect(state.json['muted'], true);
    expect(state.json['weight_g'], 300, reason: 'field lain tidak boleh hilang');

    state.apply('event: patch\ndata: {"path":"/weight_g","data":340}\n\n');
    expect(state.json['weight_g'], 340);
  });

  testWidgets('lead pengingat mengikuti sisa waktu alat, bukan clamp 1 menit', (tester) async {
    expect(ReminderService.clampLead(const Duration(seconds: 15)),
        const Duration(seconds: 15));
    expect(ReminderService.clampLead(const Duration(seconds: 1)),
        const Duration(seconds: 5), reason: 'hanya alarm di masa lalu yang dinaikkan');
    expect(ReminderService.clampLead(const Duration(minutes: 30)),
        const Duration(minutes: 30));
  });

  testWidgets('stream config menerapkan mute dan mode', (tester) async {
    final st = TlmStreamState();
    st.apply('event: put\ndata: {"path":"/","data":{"timer_mode":"AUTO_DHT","muted":false}}\n\n');
    expect(st.json['muted'], false);
    st.apply('event: patch\ndata: {"path":"/","data":{"muted":true,"timer_mode":"MANUAL"}}\n\n');
    expect(st.json['muted'], true);
    expect(st.json['timer_mode'], 'MANUAL');
  });

  group('penjadwalan pengingat', () {
    final t0 = DateTime(2026, 11, 3, 10);

    test('siklus demo kedua tetap dijadwalkan', () {
      final first = t0.add(const Duration(seconds: 15));
      expect(shouldScheduleReminder(state: 'TIMING', target: first), isTrue);

      final second = t0.add(const Duration(seconds: 30));
      expect(
          shouldScheduleReminder(
              state: 'TIMING',
              target: second,
              current: ReminderPlan('TIMING', first)),
          isTrue,
          reason: 'jarak 15 dtk harus lolos; ambang 20 dtk dulu memblokirnya');
    });

    test('event stream berulang tidak memasang ulang alarm', () {
      final target = t0.add(const Duration(minutes: 5));
      expect(
          shouldScheduleReminder(
              state: 'TIMING',
              target: target.add(const Duration(seconds: 3)),
              current: ReminderPlan('TIMING', target)),
          isFalse,
          reason: 'geseran 3 dtk masih dalam toleransi');
      expect(
          shouldScheduleReminder(
              state: 'ALERT_DRINK',
              target: target,
              current: ReminderPlan('TIMING', target)),
          isTrue,
          reason: 'perubahan state wajib menjadwalkan ulang');
    });

    test('alert selain waktu minum tidak memicu alarm', () {
      expect(stateAllowsReminder('ALERT_REFILL'), isFalse);
      expect(stateAllowsReminder('ALERT_CHEAT'), isFalse);
      expect(stateAllowsReminder('LIFTED'), isFalse);
      expect(stateAllowsReminder('ALERT_DRINK'), isTrue);
      expect(stateAllowsReminder('TIMING'), isTrue);
    });

    test('lead 15 dtk tidak dibulatkan ke satu menit', () {
      expect(ReminderService.clampLead(const Duration(seconds: 15)),
          const Duration(seconds: 15));
      expect(ReminderService.clampLead(const Duration(seconds: 1)),
          const Duration(seconds: 5));
    });
  });

  testWidgets('target harian memakai selisih, bukan total kumulatif',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'goal_ml': 2000,
      'day_base_date': '${DateTime.now().year}-'
          '${DateTime.now().month.toString().padLeft(2, '0')}-'
          '${DateTime.now().day.toString().padLeft(2, '0')}',
      'day_base_ml': 600.0,
      'day_base_drink': 2,
    });
    final client = MockClient((req) async => Response(
        req.url.path.endsWith('/config.json') ? _configBody : _telemetryBody, 200));
    await _pumpApp(tester, client);
    for (var i = 0; i < 4; i++) { await tester.pump(); }
    expect(find.text('Hari ini'), findsOneWidget);
    expect(find.textContaining('150 / 2000 ml'), findsOneWidget,
        reason: 'selisih terhadap baseline, bukan 750 kumulatif');
  });

  testWidgets('mode MANUAL memperlihatkan field interval', (tester) async {
    final client = MockClient((req) async => Response(
        req.url.path.endsWith('/config.json') ? _configBody : _telemetryBody, 200));
    await _pumpApp(tester, client);
    await tester.pump();
    expect(find.text('Interval dasar (menit)'), findsOneWidget);
    expect(find.text('AUTO_DHT'), findsOneWidget);
  });

  testWidgets('ubah interval saat TIMING memberi tahu siklus berikutnya',
      (tester) async {
    var telemetry = jsonEncode({
      'weight_g': 315,
      'remaining_sec': 423,
      'target_interval_min': 30,
      'muted': false,
      'fsm_state': 'TIMING',
    });
    final client = MockClient((req) async => Response(
        req.url.path.endsWith('/config.json') ? _configBody : telemetry, 200));
    await _pumpApp(tester, client);
    await tester.pump();
    expect(find.textContaining('masih memakai target'), findsNothing);

    final field = find.ancestor(
        of: find.text('Interval dasar (menit)'), matching: find.byType(TextField));
    await tester.ensureVisible(field);
    await tester.pump();
    await tester.enterText(field, '60');
    final kirim = find.widgetWithText(OutlinedButton, 'Kirim');
    await tester.ensureVisible(kirim);
    await tester.pump();
    await tester.tap(kirim);
    await tester.pump();
    expect(find.textContaining('masih memakai target 30 menit'), findsOneWidget);

    telemetry = jsonEncode({
      'weight_g': 315,
      'remaining_sec': 3400,
      'target_interval_min': 60,
      'muted': false,
      'fsm_state': 'TIMING',
    });
    await tester.pump(const Duration(seconds: 21));
    await tester.pump();
    expect(find.textContaining('masih memakai target'), findsNothing);
  });

  testWidgets('ubah interval saat IDLE tidak memunculkan peringatan',
      (tester) async {
    final client = MockClient((req) async => Response(
        req.url.path.endsWith('/config.json')
            ? _configBody
            : jsonEncode({
                'weight_g': 0,
                'remaining_sec': 0,
                'target_interval_min': 30,
                'muted': false,
                'fsm_state': 'IDLE',
              }),
        200));
    await _pumpApp(tester, client);
    await tester.pump();
    final field = find.ancestor(
        of: find.text('Interval dasar (menit)'), matching: find.byType(TextField));
    await tester.ensureVisible(field);
    await tester.pump();
    await tester.enterText(field, '60');
    final kirim = find.widgetWithText(OutlinedButton, 'Kirim');
    await tester.ensureVisible(kirim);
    await tester.pump();
    await tester.tap(kirim);
    await tester.pump();
    expect(find.textContaining('masih memakai target'), findsNothing);
  });

  // Tarik node kecil saja karena /daily tumbuh terus dan tidak dibaca _poll().
  testWidgets('poll menarik dua node kecil, bukan seluruh node alat',
      (tester) async {
    final paths = <String>[];
    final client = MockClient((req) async {
      paths.add('${req.method} ${req.url.path}');
      return Response(
          req.url.path.endsWith('/config.json') ? _configBody : _telemetryBody, 200);
    });
    await _pumpApp(tester, client);
    await tester.pump();
    expect(paths, contains('GET /users/uid-test/smart_coaster/config.json'));
    expect(paths, contains('GET /users/uid-test/smart_coaster/telemetry.json'));
    expect(paths.any((p) => p.endsWith('/smart_coaster.json')), isFalse,
        reason: 'node induk tidak boleh ditarik lagi');
  });

  testWidgets('sesi tanpa deviceUid memakai node akun', (tester) async {
    final paths = <String>[];
    final client = MockClient((req) async {
      paths.add('${req.method} ${req.url.path}');
      return Response(_telemetryBody, 200);
    });
    await tester.pumpWidget(MaterialApp(
      home: DashboardScreen(
        url: _url,
        session: const AuthSession(
            'test-token', 'test@example.com', 'uid-akun', 9999999999999),
        onChangeUrl: () {},
        client: client,
      ),
    ));
    await tester.pump();
    expect(paths, contains('GET /users/uid-akun/smart_coaster/config.json'));
    expect(paths, contains('GET /users/uid-akun/smart_coaster/telemetry.json'));
    expect(paths.any((p) => p.endsWith('/smart_coaster.json')), isFalse);
  });

  testWidgets('boot membaca /links lalu memakai node alat', (tester) async {
    SharedPreferences.setMockInitialValues({
      'shc_id_token': 'tok',
      'shc_id_token_exp': 9999999999999,
      'shc_auth_email': 'a@b.c',
      'shc_uid': 'uid-akun',
      'shc_refresh_token': 'ref',
    });
    final paths = <String>[];
    final client = MockClient((req) async {
      paths.add('${req.method} ${req.url.path}');
      if (req.url.path == '/links/uid-akun.json') {
        return Response('{"uid-alat":{"code":"A1B2C3D4","at":123}}', 200);
      }
      if (req.url.path == '/users/uid-alat/smart_coaster/telemetry.json') {
        return Response(_telemetryBody, 200);
      }
        if (req.url.path == '/users/uid-alat/smart_coaster/config.json') {
        return Response(_configBody, 200);
      }
      return Response('null', 200);
    });

    await tester.pumpWidget(MaterialApp(home: RootPage(client: client)));
    await tester.pump();
    await tester.pump();

    expect(paths, contains('GET /links/uid-akun.json'));
    expect(paths, contains('GET /users/uid-alat/smart_coaster/telemetry.json'));
    expect(paths, isNot(contains('GET /users/uid-akun/smart_coaster/telemetry.json')));
  });

  testWidgets('boot tanpa /links jatuh ke node akun', (tester) async {
    SharedPreferences.setMockInitialValues({
      'shc_id_token': 'tok',
      'shc_id_token_exp': 9999999999999,
      'shc_auth_email': 'a@b.c',
      'shc_uid': 'uid-akun',
      'shc_refresh_token': 'ref',
    });
    final paths = <String>[];
    final client = MockClient((req) async {
      paths.add('${req.method} ${req.url.path}');
      if (req.url.path == '/links/uid-akun.json') {
        return Response('Unauthorized', 401);
      }
      if (req.url.path == '/users/uid-akun/smart_coaster/telemetry.json') {
        return Response(_telemetryBody, 200);
      }
        if (req.url.path == '/users/uid-akun/smart_coaster/config.json') {
        return Response(_configBody, 200);
      }
      return Response('null', 200);
    });

    await tester.pumpWidget(MaterialApp(home: RootPage(client: client)));
    await tester.pump();
    await tester.pump();

    expect(paths, contains('GET /links/uid-akun.json'));
    expect(paths, contains('GET /users/uid-akun/smart_coaster/telemetry.json'));
    expect(paths, isNot(contains('GET /users/uid-alat/smart_coaster/telemetry.json')));
  });

  testWidgets('login baru menemukan tautan alat', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final paths = <String>[];
    final client = MockClient((req) async {
      paths.add('${req.method} ${req.url.path}');
      if (req.url.path == '/v1/accounts:signInWithPassword') {
        return Response(
            jsonEncode({
              'idToken': 'tok',
              'localId': 'uid-akun',
              'email': 'a@b.c',
              'expiresIn': '3600',
              'refreshToken': 'ref',
            }),
            200);
      }
      if (req.url.path == '/links/uid-akun.json') {
        return Response('{"uid-alat":{"code":"A1B2C3D4","at":7}}', 200);
      }
      if (req.url.path == '/users/uid-alat/smart_coaster/telemetry.json') {
        return Response(_telemetryBody, 200);
      }
        if (req.url.path == '/users/uid-alat/smart_coaster/config.json') {
        return Response(_configBody, 200);
      }
      return Response('null', 200);
    });

    await tester.pumpWidget(MaterialApp(home: RootPage(client: client)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'a@b.c');
    await tester.enterText(find.byType(TextField).at(1), 'rahasia');
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(paths, contains('GET /links/uid-akun.json'));
    expect(paths, contains('GET /users/uid-alat/smart_coaster/telemetry.json'));
    expect(paths, isNot(contains('GET /users/uid-akun/smart_coaster/telemetry.json')));
  });

  testWidgets('hari baru tanpa aplikasi terbuka menampilkan catatan, bukan nol diam-diam',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final client = MockClient((req) async {
      if (req.url.path == '/users/uid-test/smart_coaster/telemetry.json') {
        return Response(_telemetryBody, 200);
      }
      if (req.url.path == '/users/uid-test/smart_coaster/config.json') {
        return Response(_configBody, 200);
      }
      return Response('{}', 200);
    });

    await _pumpApp(tester, client);
    await tester.pump();

    expect(find.textContaining('Hari baru'), findsOneWidget);
    expect(find.textContaining('0 / 2000 ml'), findsOneWidget, reason: 'hari ini mulai dari nol');
  });

  testWidgets('baseline hari ini sudah ada: capaian dan catatan sesuai selisih',
      (tester) async {
    String today() {
      final d = DateTime.now();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    SharedPreferences.setMockInitialValues({
      'day_base_date': today(),
      'day_base_ml': 600.0,
      'day_base_drink': 2,
    });
    final client = MockClient((req) async {
      if (req.url.path == '/users/uid-test/smart_coaster/telemetry.json') {
        return Response(_telemetryBody, 200);
      }
      if (req.url.path == '/users/uid-test/smart_coaster/config.json') {
        return Response(_configBody, 200);
      }
      return Response('{}', 200);
    });

    await _pumpApp(tester, client);
    await tester.pump();

    expect(find.textContaining('150 / 2000 ml'), findsOneWidget, reason: '750 - 600');
    expect(find.textContaining('Hari baru'), findsNothing);
  });

  testWidgets('riwayat dimuat ulang saat ada tegukan baru', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var dailyBody = '{}';
    var telemetry = _telemetryBody;
    var dailyGets = 0;
    final client = MockClient((req) async {
      if (req.url.path == '/users/uid-test/smart_coaster/daily.json') {
        dailyGets++;
        return Response(dailyBody, 200);
      }
      if (req.url.path == '/users/uid-test/smart_coaster/telemetry.json') {
        return Response(telemetry, 200);
      }
      if (req.url.path == '/users/uid-test/smart_coaster/config.json') {
        return Response(_configBody, 200);
      }
      return Response('{}', 200);
    });

    await _pumpApp(tester, client);
    await tester.pump();
    expect(find.text('Riwayat'), findsNothing, reason: 'node riwayat masih kosong');

    dailyBody = '{"2026-11-06":{"total_ml":1500.0,"drink_count":6}}';
    telemetry = jsonEncode({
      'weight_g': 315,
      'water_ml': 185,
      'temp_c': 27,
      'humidity_pct': 60,
      'remaining_sec': 400,
      'target_interval_min': 45,
      'total_ml': 750,
      'drink_count': 4,
      'refill_count': 1,
      'cheat_count': 0,
      'muted': false,
      'fsm_state': 'TIMING',
    });
    await tester.pump(const Duration(seconds: 21));
    await tester.pump();

    expect(dailyGets, 2, reason: 'satu saat dibuka, satu saat tegukan baru');
    expect(find.text('Riwayat'), findsOneWidget);
    expect(find.text('2026-11-06'), findsOneWidget);
  });

  testWidgets('layout adaptif bebas overflow di ponsel 360px dan tablet 960px',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    MockClient makeClient() => MockClient((req) async {
          if (req.url.path.endsWith('/telemetry.json')) {
            return Response(_telemetryBody, 200);
          }
          if (req.url.path.endsWith('/config.json')) {
            return Response(_configBody, 200);
          }
          if (req.url.path.endsWith('/daily.json')) {
            return Response('{"2026-11-22":{"total_ml":1500,"drink_count":5}}', 200);
          }
          return Response('{}', 200);
        });

    for (final sz in const [Size(360, 800), Size(960, 800)]) {
      await tester.binding.setSurfaceSize(sz);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpApp(tester, makeClient());
      await tester.pump();
      expect(find.text('315.0'), findsOneWidget);
      expect(find.text('Riwayat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('ubah target harian tersimpan di SharedPreferences',
      (tester) async {
    SharedPreferences.setMockInitialValues({'goal_ml': 2000});
    final client = MockClient((req) async => Response(
        req.url.path.endsWith('/config.json') ? _configBody : _telemetryBody, 200));
    await _pumpApp(tester, client);
    await tester.pump();

    final targetChip = find.text('Target 2000 ml');
    await tester.ensureVisible(targetChip);
    await tester.pump();
    await tester.tap(targetChip);
    await tester.pumpAndSettle();

    final goalField = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(goalField, '2500');
    await tester.tap(find.text('Simpan target'));
    await tester.pumpAndSettle();

    expect(find.text('Target 2500 ml'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('goal_ml'), 2500);
  });

  testWidgets('keluar akun lewat menu AppBar mengembalikan ke layar masuk',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'shc_id_token': 'tok',
      'shc_id_token_exp': 9999999999999,
      'shc_auth_email': 'a@b.c',
      'shc_uid': 'uid-akun',
      'shc_refresh_token': 'ref',
      'shc_device_uid': 'uid-alat',
    });
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/telemetry.json')) {
        return Response(_telemetryBody, 200);
      }
      if (req.url.path.endsWith('/config.json')) {
        return Response(_configBody, 200);
      }
      return Response('null', 200);
    });

    await tester.pumpWidget(MaterialApp(home: RootPage(client: client)));
    await tester.pump();
    await tester.pump();

    expect(find.byTooltip('Menu akun dan perangkat'), findsOneWidget);
    await tester.tap(find.byTooltip('Menu akun dan perangkat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
    expect(await loadSession(), isNull);
  });

  test('isRevokedEvent mendeteksi auth_revoked dan cancel tanpa memicu put/patch', () {
    expect(TlmStreamState.isRevokedEvent('event: auth_revoked\ndata: null\n\n'), isTrue);
    expect(TlmStreamState.isRevokedEvent('event: cancel\ndata: null\n\n'), isTrue);
    expect(TlmStreamState.isRevokedEvent('event: put\ndata: {"path":"/","data":{}}\n\n'), isFalse);
    expect(TlmStreamState.isRevokedEvent('event: keep-alive\ndata: null\n\n'), isFalse);
  });

  testWidgets('standby:true menampilkan --:-- meski fsm_state TIMING', (tester) async {
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/telemetry.json')) {
        return Response(
            jsonEncode({
              'weight_g': 315,
              'water_ml': 185,
              'temp_c': 27,
              'humidity_pct': 60,
              'remaining_sec': 15,
              'target_interval_min': 0.25,
              'total_ml': 0,
              'drink_count': 0,
              'refill_count': 0,
              'cheat_count': 0,
              'muted': false,
              'standby': true,
              'fsm_state': 'TIMING',
              'hb': 1,
            }),
            200);
      }
      if (req.url.path.endsWith('/config.json')) {
        return Response(_configBody, 200);
      }
      return Response('{}', 200);
    });

    await _pumpApp(tester, client);
    await tester.pump();
    expect(find.text('--:--'), findsOneWidget);
    expect(find.text('00:15'), findsNothing);
  });

  testWidgets('countdown TIMING turun tiap detik tanpa poll baru', (tester) async {
    var fakeNow = DateTime(2026, 11, 25, 1, 0, 0);
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/telemetry.json')) {
        return Response(
            jsonEncode({
              'weight_g': 315,
              'water_ml': 185,
              'temp_c': 27,
              'humidity_pct': 60,
              'remaining_sec': 15,
              'target_interval_min': 0.25,
              'total_ml': 0,
              'drink_count': 0,
              'refill_count': 0,
              'cheat_count': 0,
              'muted': false,
              'standby': false,
              'fsm_state': 'TIMING',
              'hb': 5,
            }),
            200);
      }
      if (req.url.path.endsWith('/config.json')) {
        return Response(_configBody, 200);
      }
      return Response('{}', 200);
    });

    await tester.pumpWidget(MaterialApp(
      home: DashboardScreen(
        url: _url,
        session: const AuthSession(
            'test-token', 'test@example.com', 'uid-akun', 9999999999999, '', 'uid-test'),
        onChangeUrl: () {},
        client: client,
        now: () => fakeNow,
      ),
    ));
    await tester.pump();
    expect(find.text('00:15'), findsOneWidget);

    fakeNow = fakeNow.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('00:12'), findsOneWidget);
  });

  testWidgets('PATCH config dan PUT session mengirim print=silent dan menerima HTTP 204',
      (tester) async {
    final writeUris = <Uri>[];
    final client = MockClient((req) async {
      if (req.method == 'PATCH' || req.method == 'PUT') {
        writeUris.add(req.url);
        return Response('', 204);
      }
      return Response(
          req.url.path.endsWith('/config.json') ? _configBody : _telemetryBody, 200);
    });
    await _pumpApp(tester, client);
    await tester.pump();

    final buzzerSwitch = find.descendant(
        of: find.ancestor(of: find.text('Buzzer'), matching: find.byType(Row)).first,
        matching: find.byType(Switch));
    await tester.ensureVisible(buzzerSwitch);
    await tester.pump();
    await tester.tap(buzzerSwitch);
    await tester.pump();

    final endBtn = find.text('Akhiri sesi');
    await tester.ensureVisible(endBtn);
    await tester.pump();
    await tester.tap(endBtn);
    await tester.pump();

    expect(writeUris, hasLength(2));
    expect(writeUris[0].path, endsWith('/config.json'));
    expect(writeUris[0].queryParameters['print'], 'silent');
    expect(writeUris[1].path, endsWith('/session.json'));
    expect(writeUris[1].queryParameters['print'], 'silent');
    expect(find.textContaining('Gagal'), findsNothing);
  });

  testWidgets('hb macet > 25 detik membekukan countdown, mengunci kendali, dan pulih saat hb naik',
      (tester) async {
    var fakeNow = DateTime(2026, 11, 25, 2, 0, 0);
    var hb = 5;
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/telemetry.json')) {
        return Response(
            jsonEncode({
              'weight_g': 315,
              'water_ml': 185,
              'temp_c': 27,
              'humidity_pct': 60,
              'remaining_sec': 15,
              'target_interval_min': 0.25,
              'total_ml': 0,
              'drink_count': 0,
              'refill_count': 0,
              'cheat_count': 0,
              'muted': false,
              'standby': false,
              'fsm_state': 'TIMING',
              'hb': hb,
            }),
            200);
      }
      if (req.url.path.endsWith('/config.json')) {
        return Response(_configBody, 200);
      }
      return Response('{}', 200);
    });

    await tester.pumpWidget(MaterialApp(
      home: DashboardScreen(
        url: _url,
        session: const AuthSession(
            'test-token', 'test@example.com', 'uid-akun', 9999999999999, '', 'uid-test'),
        onChangeUrl: () {},
        client: client,
        now: () => fakeNow,
      ),
    ));
    await tester.pump();
    expect(find.text('00:15'), findsOneWidget);
    expect(find.text('TIMING'), findsOneWidget);
    expect(find.byTooltip('Terhubung'), findsOneWidget);

    fakeNow = fakeNow.add(const Duration(seconds: 26));
    await tester.pump(const Duration(seconds: 26));

    expect(find.text('--:--'), findsOneWidget);
    expect(find.text('ALAT TERPUTUS'), findsOneWidget);
    expect(find.byTooltip('Alat terputus'), findsOneWidget);
    expect(find.text('Kendali dijeda saat tatakan tidak terhubung.'), findsOneWidget);

    final startBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Mulai sesi'));
    final endBtn = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Akhiri sesi'));
    expect(startBtn.onPressed, isNull);
    expect(endBtn.onPressed, isNull);

    hb = 6;
    await tester.tap(find.widgetWithText(TextButton, 'Cek'));
    await tester.pump();

    expect(find.text('TIMING'), findsOneWidget);
    expect(find.text('00:15'), findsOneWidget);
    expect(find.byTooltip('Terhubung'), findsOneWidget);
    final recoveredStart = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Mulai sesi'));
    expect(recoveredStart.onPressed, isNotNull);
  });
}
