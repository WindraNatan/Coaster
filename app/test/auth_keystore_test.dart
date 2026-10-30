// Regresi: refreshSession() mengambil API key dari loadApiKey(). Kalau fungsi
// itu hanya membaca SharedPreferences, instalasi baru berhasil login sekali
// lalu sesi mati saat token kedaluwarsa (±55 menit) karena key kosong.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_coaster/auth.dart';
import 'package:smart_coaster/project_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('penyimpanan kosong: loadApiKey memakai tetapan build', () async {
    SharedPreferences.setMockInitialValues({});
    expect(kFirebaseApiKey, isNotEmpty, reason: 'prasyarat: key ditanam');
    expect(await loadApiKey(), kFirebaseApiKey);
  });

  test('nilai tersimpan menang atas tetapan build', () async {
    SharedPreferences.setMockInitialValues({'shc_api_key': 'AIzaDARI_PENGGUNA'});
    expect(await loadApiKey(), 'AIzaDARI_PENGGUNA');
  });

  test('nilai tersimpan kosong/spasi diabaikan', () async {
    SharedPreferences.setMockInitialValues({'shc_api_key': '   '});
    expect(await loadApiKey(), kFirebaseApiKey);
  });
}
