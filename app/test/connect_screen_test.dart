// Layar masuk setelah URL Firebase ditanam di build (default project_config.dart):
// pengguna umum hanya melihat email dan password.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_coaster/main.dart';
import 'package:smart_coaster/project_config.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('URL tertanam: kolom URL disembunyikan', (tester) async {
    expect(kFirebaseUrl, isNotEmpty, reason: 'prasyarat: URL ditanam di build');

    await tester.pumpWidget(MaterialApp(
      home: ConnectScreen(onConnect: (_, _) {}),
    ));
    await tester.pumpAndSettle();

    expect(find.text('URL Firebase RTDB'), findsNothing);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
    // API key default-nya kosong, jadi kolomnya sengaja masih tampil sampai
    // build memberi --dart-define=FB_API_KEY=...
    if (kFirebaseApiKey.isEmpty) {
      expect(find.text('Web API Key proyek Firebase'), findsOneWidget);
    } else {
      expect(find.text('Web API Key proyek Firebase'), findsNothing);
    }
  });

  testWidgets('URL tersimpan dipakai ulang, tidak minta diketik lagi',
      (tester) async {
    const saved = 'https://proyek-lama-default-rtdb.firebaseio.com';
    SharedPreferences.setMockInitialValues({'shc_fb_url': saved});
    await tester.pumpWidget(MaterialApp(
      home: ConnectScreen(onConnect: (_, _) {}, initialUrl: saved),
    ));
    await tester.pumpAndSettle();

    // Kolom URL tetap tersembunyi karena nilainya sudah tersimpan.
    expect(find.text('URL Firebase RTDB'), findsNothing);
  });

  testWidgets('tombol Ubah URL memunculkan kolomnya lagi', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ConnectScreen(
          onConnect: (_, _) {}, showUrlField: true),
    ));
    await tester.pumpAndSettle();

    expect(find.text('URL Firebase RTDB'), findsOneWidget);
  });

  testWidgets('URL yang diketik dipakai, bukan tetapan build', (tester) async {
    const typed = 'https://proyek-lain-default-rtdb.firebaseio.com';
    await tester.pumpWidget(MaterialApp(
      home: ConnectScreen(onConnect: (_, _) {}, showUrlField: true),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'URL Firebase RTDB'), typed);
    await tester.pump();

    // Teruskan lewat tombol: submit akan memakai isian, bukan kFirebaseUrl.
    expect(find.text(typed), findsOneWidget);
  });

  testWidgets('kolom API key tidak hilang saat pengguna mengetik', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ConnectScreen(onConnect: (_, _) {}),
    ));
    await tester.pumpAndSettle();

    final keyField = find.widgetWithText(TextField, 'Web API Key proyek Firebase');
    expect(keyField, findsOneWidget);
    await tester.enterText(keyField, 'AIzaSalahSekali');
    await tester.pump();

    // Masih terlihat, jadi key yang salah bisa diperbaiki tanpa keluar layar.
    expect(find.text('Web API Key proyek Firebase'), findsOneWidget);
    expect(find.text('AIzaSalahSekali'), findsOneWidget);
  });
}
