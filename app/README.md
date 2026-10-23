# Smart Hydration Coaster — Aplikasi Flutter
Aplikasi monitoring & kendali untuk Smart Hydration Coaster melalui **Firebase
Realtime Database** (mode Cloud). Menggantikan web PWA (`web/`) untuk perangkat
Android: membaca `GET <url>/smart_coaster.json`, menulis kontrol ke
`PATCH <url>/smart_coaster/config.json`.
Identitas visual (palet dark-teal/cyan, Space Grotesk + JetBrains Mono tabular,
badge state berwarna) mengikuti `web/index.html`; kontrak field telemetry &
config mengikuti firmware `cloud_sync.h` dan CLAUDE.md §3.

## Isi
- `lib/main.dart` — UI: layar koneksi URL, dashboard (gelas, state badge,
  countdown, suhu/kelembaban, total harian, kontrol buzzer/mode/interval).
- `lib/telemetry.dart` — parsing kontrak cloud + pemetaan state turunan
  (ALERT_EMPTY_CUP / ALERT_MISSING_CUP → ALERT_REFILL). Pure Dart, teruji.
- `test/telemetry_test.dart` — parsing kontrak telemetry.
- `test/cloud_flow_test.dart` — alur cloud: poll GET node induk, PATCH config,
  state loading/error/empty.
- `assets/fonts/` — font bundel offline (subset latin).

## Kontrol yang tersedia di app
- Buzzer: mute/unmute (`muted`).
- Mode timer: `AUTO_DHT` / `MANUAL`, dan interval dasar 1 sampai 180 menit saat MANUAL
  (`manual_interval_min`, batas dari `config.h`).
Kalibrasi berat gelas kosong (`c`) dan tare (`t`) hanya lewat USB/serial (web
PWA), tidak tersedia di app.

## Menjalankan
Toolchain workstation ini dipasang di luar repo: `D:/flutter`,
`D:/jdk/jdk-17.0.20.1+1`, `D:/android-sdk`. Env var `JAVA_HOME`,
`ANDROID_SDK_ROOT`, `GRADLE_USER_HOME`, `PUB_CACHE` sudah diset persisten lewat
`setx`; kalau pindah mesin, ulangi:
```powershell
setx JAVA_HOME D:\jdk\jdk-17.0.20.1+1
setx ANDROID_SDK_ROOT D:\android-sdk
setx GRADLE_USER_HOME D:\gradle-home
setx PUB_CACHE D:\pub-cache
```

### SOP install & run ke HP
1. **Siapkan HP**: aktifkan *Developer options* + *USB debugging*, colok USB,
   terima dialog RSA fingerprint di HP.
2. **Cek device**:
   ```bash
   flutter devices
   ```
   Kalau HP + emulator/desktop muncul barengan, pakai `-d <id>` (HP repo ini
   `RRCY507KBJY`, Galaxy A56).
3. **Install APK** — wajib `--debug`; tanpa flag Flutter pilih mode *release*
   dan gagal karena APK release belum pernah di-build:
   ```bash
   cd D:/Kuliah/Sistem\ Kendali/app
   flutter install --debug            # tambah -d <id> bila perlu
   ```
4. **Buka app** — tekan ikon *Smart Coaster* di HP, atau dari PC:
   ```bash
   adb shell monkey -p com.shc.smart_coaster -c android.intent.category.LAUNCHER 1
   ```
5. **Masukkan URL RTDB** sekali di layar pertama app; tersimpan di
   SharedPreferences (`shc_fb_url`), tidak perlu diisi ulang. URL proyek ini:
   `https://smart-coaster-64880-default-rtdb.asia-southeast1.firebasedatabase.app`
6. **Verifikasi**: dashboard menampilkan status `CLOUD sinkron <hh:mm>`,
   state badge, suhu/kelembaban, dan total harian yang sama dengan data di
   Firebase console.

### Run langsung dari PC (opsional, hot reload)
```bash
flutter run            # tambah -d <id> bila perlu
```
Sesi ini membuat proses Gradle panjang; `Ctrl+C` untuk berhenti (app tetap
jalan sendiri di HP). Env var wajib sudah ada sebelum `flutter` dijalankan —
tanda gagal: error `JAVA_HOME` / `ANDROID_SDK_ROOT` tidak dikenal.

### Test
```bash
flutter test           # kontrak telemetry + alur cloud (18 skenario)
```
