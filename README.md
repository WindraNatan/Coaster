# Smart Hydration Coaster

Tatakan gelas yang menimbang air yang Anda minum, menjalankan timer minum
adaptif dari suhu dan kelembapan ruangan, dan mengirim datanya ke Firebase
sehingga bisa dipantau dari browser dan ponsel.

ESP32 DevKit V1 · load cell 5 kg lewat HX711 · DHT11 · buzzer · motor getar.

## Isi repo

| Folder | Isi |
|---|---|
| `SmartHydrationCoaster/` | firmware Arduino (C++), FSM dan kendali adaptif |
| `web/` | PWA: simulator, USB Live lewat Web Serial, dan mode Cloud |
| `app/` | aplikasi Android (Flutter), mode Cloud + pengingat minum |
| `brand/` | logo dan panduan merek (SVG + PNG) |
| `tools/` | harness uji, pemeriksaan CAD, skrip rilis APK |
| `cad/` | model sasis OpenSCAD |

## Menjalankan

**Web.** Buka `web/index.html` di browser, atau layani dengan server statis
apa pun. Simulator langsung jalan tanpa perangkat.

**Aplikasi Android.**

```
cd app
flutter pub get
flutter run
```

Build rilis: `python tools/rilis_apk.py v1.0.0-betaN` — membangun APK release,
mengunggahnya sebagai GitHub Release, dan mencetak tautan unduh.

**Firmware.** Butuh Arduino IDE dengan core ESP32 3.x dan library WiFiManager,
HX711, DHT. Isi `SmartHydrationCoaster/secrets.h` (tidak di-commit) dari
`secrets.h.example`. Compile lewat CLI:

```
arduino-cli compile --fqbn esp32:esp32:esp32doit-devkit-v1 SmartHydrationCoaster
```

## Verifikasi

```
python test_simulation.py                 # 21 skenario FSM (Python)
node web/fsm.test.js                      # paritas FSM di JS
node web/daily-history.test.js            # riwayat + hitungan harian
tools/uji_fsm/uji_fsm.exe                 # 52 pemeriksaan FSM (C++)
python tools/cad_check/verify_stackup.py  # 60 pemeriksaan tata letak sasis
python tools/cek_aturan_berkas.py         # berkas aturan Firebase
cd app && flutter analyze && flutter test # 55 tes
```

Logika FSM hidup di tiga tempat dan wajib identik: `fsm.h`, `test_simulation.py`,
dan `web/fsm.js`. Setiap perubahan disalin ke ketiganya.

## Catatan rancangan

- Alat tidak punya jam (tanpa NTP). Angka dari alat kumulatif sejak reset
  manual; "hari ini" dihitung di klien dari selisih terhadap baseline tanggal.
- Firmware mengirim `hb` yang naik setiap push. Klien memakainya untuk
  membedakan alat diam dari alat mati, karena berat dan suhu bisa identik.
- Pengingat minum di Android memakai foreground service untuk audio: kanal
  notifikasi Android 8+ mengunci suara saat dibuat, sehingga audio pilihan
  pengguna tidak bisa dipasang lewat konfigurasi kanal.

## Lisensi dan atribusi

Panduan konteks pengembangan ada di `CLAUDE.md`. Dokumen kebutuhan produk:
`PRD_Smart_Hydration_Coaster.md`.
