// Uji alur cloud DashboardScreen: loading -> data, error HTTP, DB kosong,
// dan PATCH kontrol (mute). Pakai MockClient lewat seam client.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:smart_coaster/auth.dart';
import 'package:smart_coaster/main.dart';

const _url = 'https://proyek-rtdb.asia-southeast1.firebasedatabase.app';

final _telemetryBody = jsonEncode({
  'telemetry': {
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
  },
  'config': {
    'timer_mode': 'MANUAL',
    'manual_interval_min': 30,
    'empty_cup_weight_g': 130,
    'muted': false,
  },
});

Future<void> _pumpApp(WidgetTester tester, MockClient client) async {
  await tester.pumpWidget(MaterialApp(
    home: DashboardScreen(
      url: _url,
      session: const AuthSession('test-token', 'test@example.com', 'uid-test', 9999999999999),
      onChangeUrl: () {},
      client: client,
    ),
  ));
}

void main() {
  testWidgets('loading lalu data telemetry ter-render', (tester) async {
    final client = MockClient((req) async {
      if (req.url.path == '/users/uid-test/smart_coaster.json') {
        return Response(_telemetryBody, 200);
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
      'telemetry': {
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
      },
    });
    final client = MockClient((req) async => Response(body, 200));
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
      return Response(_telemetryBody, 200);
    });
    await _pumpApp(tester, client);
    await tester.pump();
    expect(find.text('aktif'), findsOneWidget);

    await tester.ensureVisible(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(patches, ['/users/uid-test/smart_coaster/config.json {"muted":true}']);
    expect(find.text('muted'), findsOneWidget);
  });

  testWidgets('mode MANUAL memperlihatkan field interval', (tester) async {
    final client = MockClient((req) async => Response(_telemetryBody, 200));
    await _pumpApp(tester, client);
    await tester.pump();
    // config kirim timer_mode MANUAL → field interval muncul, terisi 30
    expect(find.text('Interval dasar (menit)'), findsOneWidget);
    expect(find.text('AUTO_DHT'), findsOneWidget);
  });

  testWidgets('poll memakai GET node induk, bukan config.json',
      (tester) async {
    final paths = <String>[];
    final client = MockClient((req) async {
      paths.add('${req.method} ${req.url.path}');
      return Response(_telemetryBody, 200);
    });
    await _pumpApp(tester, client);
    await tester.pump();
    expect(paths, ['GET /users/uid-test/smart_coaster.json']);
  });
}
