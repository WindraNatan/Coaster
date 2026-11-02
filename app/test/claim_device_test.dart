// Alur klaim alat: kode 8 karakter -> /claims/<kode> -> /links/<akun>/<alat>.
// Membuktikan jalur REST persis dan bahwa UID alat (bukan UID akun) yang dipakai
// sebagai node data sesudahnya.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_coaster/auth.dart';

const _url = 'https://proyek-rtdb.asia-southeast1.firebasedatabase.app';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('klaim menulis /links akun/alat lalu menyimpan UID alat', () async {
    final calls = <String>[];
    final client = MockClient((req) async {
      calls.add('${req.method} ${req.url.path}');
      if (req.url.path == '/claims/A1B2C3D4.json') {
        return Response('"uid-alat"', 200);
      }
      return Response('{}', 200);
    });
    const session = AuthSession(
        'tok', 'a@b.c', 'uid-akun', 9999999999999, 'ref');

    final deviceUid = await claimDevice(
        base: _url, code: 'a1b2c3d4', session: session, client: client);

    expect(deviceUid, 'uid-alat');
    expect(calls, [
      'GET /claims/A1B2C3D4.json',
      'PUT /links/uid-akun/uid-alat.json',
    ]);
    expect(await loadDeviceUid(), 'uid-alat');
  });

  test('kode salah panjang ditolak sebelum menyentuh jaringan', () async {
    var dipanggil = false;
    final client = MockClient((req) async {
      dipanggil = true;
      return Response('"x"', 200);
    });
    await expectLater(
      claimDevice(
          base: _url,
          code: 'A1B2',
          session: const AuthSession('t', 'a@b.c', 'uid-akun', 9999999999999),
          client: client),
      throwsA(isA<Exception>()),
    );
    expect(dipanggil, isFalse);
  });

  test('kode tidak dikenali tidak menulis tautan', () async {
    final calls = <String>[];
    final client = MockClient((req) async {
      calls.add(req.method);
      return Response('null', 200);
    });
    await expectLater(
      claimDevice(
          base: _url,
          code: 'ZZZZZZZZ',
          session: const AuthSession('t', 'a@b.c', 'uid-akun', 9999999999999),
          client: client),
      throwsA(isA<Exception>()),
    );
    expect(calls, ['GET']);
  });

  // Tatakan tidak punya layar: pesan ini muncul tepat saat pengguna salah ketik,
  // jadi tidak boleh menyuruh mencari tampilan yang tidak ada.
  test('pesan kode salah mengarahkan ke Serial Monitor', () async {
    final client = MockClient((req) async => Response('null', 200));
    try {
      await claimDevice(
          base: _url,
          code: 'ZZZZZZZZ',
          session: const AuthSession('t', 'a@b.c', 'uid-akun', 9999999999999),
          client: client);
      fail('seharusnya melempar');
    } catch (e) {
      final pesan = e.toString();
      expect(pesan, contains('Serial Monitor'));
      expect(pesan, isNot(contains('layar')));
    }
  });

  test('refresh token mempertahankan deviceUid', () async {
    final client = MockClient((req) async => Response(
        jsonEncode({'id_token': 'baru', 'expires_in': '3600',
            'refresh_token': 'r2'}), 200));
    const s = AuthSession('lama', 'a@b.c', 'uid-akun', 1, 'r1', 'uid-alat');
    final baru = await refreshSession(s, client: client);
    expect(baru!.deviceUid, 'uid-alat');
    expect(baru.token, 'baru');
  });

  test('sesi menyimpan UID alat dan memulihkannya', () async {
    await saveSession(const AuthSession(
        'tok', 'a@b.c', 'uid-akun', 9999999999999, 'ref', 'uid-alat'));
    final s = await loadSession();
    expect(s!.deviceUid, 'uid-alat');
    expect(s.coasterUrl(_url), '$_url/users/uid-alat/smart_coaster');
  });

  // Akun B login setelah akun A tidak boleh mewarisi alat A: kalau tertinggal,
  // penemuan tautan dilewati dan B membaca node milik A.
  test('login akun lain menghapus UID alat sebelumnya', () async {
    await saveSession(const AuthSession(
        'tokA', 'a@b.c', 'uid-akun-a', 9999999999999, 'refA', 'uid-alat-a'));
    expect((await loadSession())!.deviceUid, 'uid-alat-a');

    await saveSession(const AuthSession(
        'tokB', 'b@b.c', 'uid-akun-b', 9999999999999, 'refB'));
    final b = await loadSession();
    expect(b!.uid, 'uid-akun-b');
    expect(b.deviceUid, isEmpty);
    expect(await loadDeviceUid(), isEmpty);
  });

  test('keluar menghapus UID alat juga', () async {
    await saveSession(const AuthSession(
        'tok', 'a@b.c', 'uid-akun', 9999999999999, 'ref', 'uid-alat'));
    await saveSession(null);
    expect(await loadSession(), isNull);
    expect(await loadDeviceUid(), isEmpty);
  });

  test('tanpa UID alat, coasterUrl jatuh ke node akun', () async {
    const s = AuthSession('tok', 'a@b.c', 'uid-akun', 9999999999999);
    expect(s.hasDevice, isFalse);
    expect(s.coasterUrl(_url), '$_url/users/uid-akun/smart_coaster');
  });

  test('dengan UID alat, node alat yang dipakai', () async {
    const s = AuthSession('tok', 'a@b.c', 'uid-akun', 9999999999999, '',
        'uid-alat');
    expect(s.hasDevice, isTrue);
    expect(s.coasterUrl(_url), '$_url/users/uid-alat/smart_coaster');
  });

  test('discoverDevice membaca /links uid akun', () async {
    final paths = <String>[];
    final client = MockClient((req) async {
      paths.add('${req.method} ${req.url.path}');
      return Response('{"uid-alat":{"code":"A1B2C3D4","at":5}}', 200);
    });
    final uid = await discoverDevice(
        base: _url,
        session: const AuthSession('tok', 'a@b.c', 'uid-akun', 9999999999999),
        client: client);
    expect(uid, 'uid-alat');
    expect(paths, ['GET /links/uid-akun.json']);
  });

  // Aturan RTDB tidak menaikkan izin ke node induk: kalau `.read` hanya ada di
  // links/$ownerUid/$deviceUid, permintaan daftar tautan selalu 401. Tes ini
  // mengunci bahwa aplikasi tidak bergantung pada izin tingkat $deviceUid.
  test('discoverDevice memakai jalur daftar, bukan per alat', () async {
    final paths = <String>[];
    final client = MockClient((req) async {
      paths.add(req.url.path);
      return Response('{"alat-a":{"at":9}}', 200);
    });
    await discoverDevice(
        base: _url,
        session: const AuthSession('tok', 'a@b.c', 'uid-akun', 9999999999999),
        client: client);
    expect(paths, ['/links/uid-akun.json']);
    expect(paths.single.endsWith('/xxx.json'), isFalse);
  });

  test('discoverDevice memilih tautan terakhir bila ada beberapa', () async {
    final client = MockClient((req) async => Response(
        '{"alat-lama":{"at":1},"alat-baru":{"at":99}}', 200));
    final uid = await discoverDevice(
        base: _url,
        session: const AuthSession('tok', 'a@b.c', 'uid-akun', 9999999999999),
        client: client);
    expect(uid, 'alat-baru');
  });

  // Rules belum memuat blok links -> 401. Bukan gagal boot: fallback dipakai.
  test('discoverDevice mengembalikan kosong saat ditolak server', () async {
    final client = MockClient((req) async => Response('Unauthorized', 401));
    final uid = await discoverDevice(
        base: _url,
        session: const AuthSession('tok', 'a@b.c', 'uid-akun', 9999999999999),
        client: client);
    expect(uid, isEmpty);
  });

  test('discoverDevice mengabaikan respons kosong', () async {
    final client = MockClient((req) async => Response('null', 200));
    final uid = await discoverDevice(
        base: _url,
        session: const AuthSession('tok', 'a@b.c', 'uid-akun', 9999999999999),
        client: client);
    expect(uid, isEmpty);
  });
}
