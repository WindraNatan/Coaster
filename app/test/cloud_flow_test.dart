// Uji alur cloud DashboardScreen: loading -> data, error HTTP, DB kosong,
// dan PATCH kontrol (mute). Pakai MockClient lewat seam client.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:smart_coaster/auth.dart';
import 'package:smart_coaster/main.dart';
import 'package:smart_coaster/reminder.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _url = 'https://proyek-rtdb.asia-southeast1.firebasedatabase.app';
// _poll() menarik dua node terpisah: telemetry.json dan config.json. Mock harus
// mengembalikan badan yang sesuai per path, bukan satu node induk.
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

    await tester.pump(); // future _poll() selesai

    expect(find.text('315.0'), findsOneWidget); // berat gram
    expect(find.text('185 ml'), findsOneWidget); // air terdeteksi
    expect(find.text('07:03'), findsOneWidget); // mmss(423)
    expect(find.text('TIMING'), findsOneWidget); // badge state
    expect(find.text('750 ml'), findsOneWidget); // total harian
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

  testWidgets('state turunan ALERT_MISSING_CUP render sebagai ALERT REFILL',
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
    expect(find.text('ALERT REFILL'), findsOneWidget);
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

    // Kartu pengingat juga punya Switch, jadi cari yang satu baris dengan 'Buzzer'.
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

  // Regresi desinkronisasi mute: config adalah perintah (saklar pengguna),
  // telemetry adalah echo perangkat yang baru berubah setelah ESP32 poll config
  // (15 dtk). Kalau telemetry menang, saklar membalik sendiri beberapa detik
  // setelah diklik. Web memakai presedensi yang sama (web/index.html mutedFrom).
  testWidgets('telemetry.muted basi tidak menimpa config.muted',
      (tester) async {
    final staleTelemetry = jsonEncode({
      'weight_g': 315, 'water_ml': 185, 'temp_c': 27, 'humidity_pct': 60,
      'remaining_sec': 423, 'target_interval_min': 30, 'total_ml': 750,
      'drink_count': 3, 'refill_count': 1, 'cheat_count': 0,
      'fsm_state': 'TIMING',
      'muted': false, // echo lama: perangkat belum sempat membaca config baru
    });
    final client = MockClient((req) async => Response(
        req.url.path.endsWith('/config.json')
            ? jsonEncode({'timer_mode': 'MANUAL', 'manual_interval_min': 30,
                          'empty_cup_weight_g': 130, 'muted': true})
            : staleTelemetry,
        200));
    await _pumpApp(tester, client);
    for (var i = 0; i < 4; i++) { await tester.pump(); }
    // Pisahkan dua hipotesis kegagalan: field ini hanya muncul bila _cfg sudah
    // terisi dari body config (timer_mode MANUAL). Hilang -> mock/path bermasalah;
    // muncul tapi switch false -> presedensi muted yang rusak.
    expect(find.text('Interval dasar (menit)'), findsOneWidget);
    final sw = tester.widget<Switch>(find.descendant(
        of: find.ancestor(
            of: find.text('Buzzer'), matching: find.byType(Row)).first,
        matching: find.byType(Switch)));
    expect(sw.value, isTrue,
        reason: 'config.muted=true harus menang atas telemetry.muted=false yang basi');
  });

  // Regresi event stream: PATCH dari web/app sampai ke RTDB sebagai `event: patch`
  // dengan `path` sebagian, bukan `put` node penuh. Tanpa penanganan patch, field
  // yang berubah baru terlihat 20 dtk kemudian lewat poll cadangan.
  testWidgets('event patch sebagian diterapkan menurut path', (tester) async {
    final client = MockClient((req) async => Response(
        req.url.path.endsWith('/config.json') ? _configBody : _telemetryBody, 200));
    await _pumpApp(tester, client);
    await tester.pump();

    // Snapshot awal, lalu patch sebagian seperti tombol mute di aplikasi.
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

  // Regresi: sisa waktu alat tidak boleh dibulatkan. Mode demo memakai interval
  // 15 dtk, dan clamp satu menit dulu membuat alarm berbunyi setelah minum lewat.
  testWidgets('lead pengingat mengikuti sisa waktu alat, bukan clamp 1 menit', (tester) async {
    expect(ReminderService.clampLead(const Duration(seconds: 15)),
        const Duration(seconds: 15));
    expect(ReminderService.clampLead(const Duration(seconds: 1)),
        const Duration(seconds: 5), reason: 'hanya alarm di masa lalu yang dinaikkan');
    expect(ReminderService.clampLead(const Duration(minutes: 30)),
        const Duration(minutes: 30));
  });

  // Regresi: PATCH config dari web harus sampai lewat stream, bukan menunggu
  // poll. UI mendahulukan _cfg, jadi perubahan mute terlihat basi tanpa ini.
  testWidgets('stream config menerapkan mute dan mode', (tester) async {
    final st = TlmStreamState();
    st.apply('event: put\ndata: {"path":"/","data":{"timer_mode":"AUTO_DHT","muted":false}}\n\n');
    expect(st.json['muted'], false);
    st.apply('event: patch\ndata: {"path":"/","data":{"muted":true,"timer_mode":"MANUAL"}}\n\n');
    expect(st.json['muted'], true);
    expect(st.json['timer_mode'], 'MANUAL');
  });

  // Regresi penjadwalan pengingat. Dua bug nyata yang pernah terjadi:
  // (1) ambang pada sisa detik membuat siklus demo 15->0->15 selalu terlewat,
  //     sehingga alarm hanya berbunyi sekali;
  // (2) alarm alert lain (isi ulang/curang) dibiarkan menggantung.
  group('penjadwalan pengingat', () {
    final t0 = DateTime(2026, 11, 3, 10);

    test('siklus demo kedua tetap dijadwalkan', () {
      final first = t0.add(const Duration(seconds: 15));
      expect(shouldScheduleReminder(state: 'TIMING', target: first), isTrue);

      // Siklus berikutnya: target baru 15 dtk lagi, dan sebelumnya sudah lewat.
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

  testWidgets('mode MANUAL memperlihatkan field interval', (tester) async {
    final client = MockClient((req) async => Response(
        req.url.path.endsWith('/config.json') ? _configBody : _telemetryBody, 200));
    await _pumpApp(tester, client);
    await tester.pump();
    // config kirim timer_mode MANUAL → field interval muncul, terisi 30
    expect(find.text('Interval dasar (menit)'), findsOneWidget);
    expect(find.text('AUTO_DHT'), findsOneWidget);
  });

  // Dua node kecil, bukan seluruh /smart_coaster: daily/<tanggal> tumbuh tanpa
  // batas dan tidak pernah dibaca _poll(), jadi menariknya tiap 2,5 detik hanya
  // membakar kuota.
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
    // Telemetry boleh muncul dua kali: sekali dari _poll() dan sekali dari
    // stream SSE yang sengaja dibuka _startPolling(). Yang dilarang adalah
    // menarik node induk.
    expect(paths, contains('GET /users/uid-test/smart_coaster/config.json'));
    expect(paths, contains('GET /users/uid-test/smart_coaster/telemetry.json'));
    expect(paths.any((p) => p.endsWith('/smart_coaster.json')), isFalse,
        reason: 'node induk tidak boleh ditarik lagi');
  });

  // Node akun dipakai hanya sebagai cadangan saat alat belum ditautkan, supaya
  // instalasi lama tetap jalan. Alat tertaut wajib menang.
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

  // Beda UID: akun 19Wt…, alat uid-alat. Boot wajib baca /links lalu memakai
  // node ALAT, bukan node akun — inilah bedanya dengan jalur fallback.
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
    await tester.pump(); // _boot selesai
    await tester.pump(); // _poll selesai

    expect(paths, contains('GET /links/uid-akun.json'));
    expect(paths, contains('GET /users/uid-alat/smart_coaster/telemetry.json'));
    expect(paths, isNot(contains('GET /users/uid-akun/smart_coaster/telemetry.json')));
  });

  // /links ditolak (rules belum memuat blok itu) -> fallback node akun.
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

  // Instalasi baru: tidak ada sesi tersimpan, jadi _boot() tidak punya apa pun.
  // Login harus tetap menemukan tautan alat, bukan berhenti di node akun.
  testWidgets('login baru menemukan tautan alat', (tester) async {
    SharedPreferences.setMockInitialValues({}); // tanpa sesi
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
}
