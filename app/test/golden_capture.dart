// Golden widget test untuk tangkapan layar aplikasi.
//
// Dashboard butuh sesi Firebase nyata; tidak ada kredensial uji di repo, jadi
// jalan pintas yang jujur adalah merender widget dengan MockClient yang sama
// seperti cloud_flow_test.dart. Hasilnya PNG asli dari aplikasi, bukan gambar
// buatan tangan.
//
// Ini ALAT TANGKAP, bukan tes: baris jam di dashboard memakai waktu nyata,
// sehingga perbandingan piksel akan gagal 42 px setiap kali menit berganti.
// Nama berkas sengaja tanpa akhiran _test.dart agar tidak ikut suite.
//
// Tangkap ulang: flutter test test/golden_capture.dart --update-goldens
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:smart_coaster/auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_coaster/main.dart';

const _url = 'https://proyek-rtdb.asia-southeast1.firebasedatabase.app';
const _session = AuthSession(
    'test-token', 'test@example.com', 'uid-akun', 9999999999999, '', 'uid-test');

final _telemetry = jsonEncode({
  'weight_g': 315.0,
  'water_ml': 185.0,
  'temp_c': 27.4,
  'humidity_pct': 60,
  'remaining_sec': 423,
  'target_interval_min': 30,
  'total_ml': 750,
  'drink_count': 3,
  'refill_count': 1,
  'cheat_count': 0,
  'muted': false,
  'fsm_state': 'TIMING',
});

final _config = jsonEncode({
  'timer_mode': 'MANUAL',
  'manual_interval_min': 30,
  'empty_cup_weight_g': 130,
  'muted': false,
});

MockClient _client() => MockClient((req) async {
      if (req.url.path.endsWith('/telemetry.json')) {
        return Response(_telemetry, 200);
      }
      if (req.url.path.endsWith('/config.json')) {
        return Response(_config, 200);
      }
      return Response('null', 200);
    });

Future<void> _pump(WidgetTester tester, Size size) async {
  // Plugin preferensi tidak punya implementasi di lingkungan widget test;
  // nilai tiruan cukup, karena yang diuji adalah tampilan.
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: DashboardScreen(
      url: _url,
      session: _session,
      onChangeUrl: () {},
      client: _client(),
    ),
  ));
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

Future<void> _loadFonts() async {
  final gro = FontLoader('SpaceGrotesk');
  for (final f in ['SpaceGrotesk-Regular.ttf', 'SpaceGrotesk-Medium.ttf', 'SpaceGrotesk-Bold.ttf']) {
    gro.addFont(File('assets/fonts/$f').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await gro.load();

  final mono = FontLoader('JetBrainsMono');
  for (final f in ['JetBrainsMono-Regular.ttf', 'JetBrainsMono-SemiBold.ttf']) {
    mono.addFont(File('assets/fonts/$f').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await mono.load();
}

void main() {
  setUpAll(_loadFonts);
  testWidgets('dashboard tampilan ponsel', (tester) async {
    await _pump(tester, const Size(390, 1280));
    await expectLater(
      find.byType(DashboardScreen),
      matchesGoldenFile('goldens/app-dashboard-hp.png'),
    );
  });

  testWidgets('dashboard tampilan lebar', (tester) async {
    await _pump(tester, const Size(820, 1000));
    await expectLater(
      find.byType(DashboardScreen),
      matchesGoldenFile('goldens/app-dashboard-lebar.png'),
    );
  });
}
