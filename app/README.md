# Smart Hydration Coaster (Aplikasi Flutter)

Aplikasi monitoring dan kendali untuk Smart Hydration Coaster lewat **Firebase Realtime Database** (mode Cloud). Jalur telemetri memakai SSE dan polling 20 detik pada `/users/<uid>/smart_coaster/telemetry.json`, `/config.json`, `/session.json`, dan `/daily/<tanggal>.json`, serta deteksi alat terputus jika heartbeat `hb` tidak bertambah selama 25 detik.

Identitas visual mengikuti sistem desain Mineral Stoneware (`#F4F6F5`/`#FBFCFB`) dan Deep Spring Teal (`#0B5D6B`) dengan font offline *Space Grotesk* dan *JetBrains Mono* tabular di `assets/fonts/`.

## Isi

- `lib/main.dart`: UI koneksi akun/URL, dashboard adaptif 1-2 kolom, kendali timer/sesi/target harian, riwayat 7 hari, dan klaim alat.
- `lib/telemetry.dart`: parsing kontrak telemetri/config/session, pemetaan state (`ALERT_EMPTY_CUP` / `ALERT_MISSING_CUP` ke `ALERT_REFILL`), dan status koneksi alat.
- `lib/auth.dart`: autentikasi Firebase Auth, penyimpanan sesi aman, dan penemuan tautan tatakan milik akun.
- `lib/project_config.dart`: konfigurasi build `--dart-define` (`FB_URL`, `FB_API_KEY`) beserta nilai bawaan proyek.
- `lib/reminder.dart`: penjadwalan pengingat minum lokal Android dengan foreground service audio.
- `lib/theme.dart` & `lib/painters.dart`: token warna, tipografi, cincin hidrasi, dan visual gelas.
- `test/`: 74 pengujian otomatis (`cloud_flow_test.dart`, `connect_screen_test.dart`, `claim_device_test.dart`, `telemetry_test.dart`, `auth_keystore_test.dart`).

## Kontrol yang tersedia di app

- Mulai/akhiri sesi (`session.json`), klaim kode tatakan 8 karakter, dan atur target harian.
- Mode jadwal: `AUTO_DHT` (sesuai suhu ruangan), `MANUAL` (1-180 menit via `manual_interval_min`), dan `DEMO` (15 detik).
- Suara pengingat (`muted`) serta bobot gelas kosong (`empty_cup_weight_g`).
- Kalibrasi faktor timbangan (`c`), nolkan timbangan (`t`), dan reset statistik alat (`r`) hanya tersedia lewat koneksi USB Serial di Web PWA.

## Menjalankan & Menguji

Pastikan Flutter SDK, Android SDK, dan JDK sudah terpasang di `PATH` atau env var masing-masing (`JAVA_HOME`, `ANDROID_SDK_ROOT`).

```bash
cd app
flutter pub get
flutter run          # jalankan di perangkat atau emulator aktif
flutter analyze      # cek statis
flutter test         # 74 pengujian unit dan widget
```

Untuk membangun dan mengunggah APK rilis ke GitHub Releases, jalankan dari root repo:

```bash
python tools/rilis_apk.py v1.0.0-betaN
```
