# Proyek Smart Hydration Coaster (ESP32)

Panduan persistent context untuk Claude Code & Claude Cowork. Proyek tatakan gelas pintar pemantau hidrasi berbasis ESP32 (dual-use untuk mata kuliah RSK-352 Sistem Kendali & RSK-354 Internet of Things, S1 Rekayasa Sistem Komputer, Universitas Tanjungpura).

---

## 1. Arsitektur Hardware & Kelistrikan

* **Mikrokontroler**: ESP32 DevKit V1 (30-pin).
* **Sensor Berat**: Load cell 5 kg + ADC HX711 (DT: `GPIO16`, SCK: `GPIO4`).
  * Faktor Kalibrasi Terkunci: `450.7f` (beban 500 g terukur 500.10 g, peak-to-peak jitter 0.21 g). Jangan diubah ke 290.0f atau 451.2f.
* **Sensor Lingkungan**: DHT11 (`GPIO19`).
* **Buzzer Aktif (Transistor PNP S8550, ACTIVE-LOW)**:
  * Pin Kontrol: `GPIO18` (`BUZZER_ACTIVE_LOW = 1`).
  * **PENTING (Kelistrikan)**: VCC modul buzzer WAJIB terhubung ke pin `3V3` ESP32 (BUKAN 5V/VIN). Jika dihubungkan ke 5V, tegangan emitor-basis $V_{EB} = 5.0\text{V} - 3.3\text{V} = 1.7\text{V} > 0.7\text{V}$ saat pin HIGH sehingga buzzer menyala terus dan tidak bisa cut-off.
* **Motor Getar (Transistor NPN S8050, ACTIVE-HIGH)**:
  * Pin Kontrol: `GPIO17` (`MOTOR_ACTIVE_LOW = 0`). VCC aman di `5V` (VIN) karena emitor bereferensi ke GND.
* **LED Indikator Onboard**: `GPIO2` (`PIN_LED_ALERT`, active-HIGH).
* **Aturan Penulisan Kode Aktuator**: Jangan panggil `digitalWrite()` langsung. Selalu gunakan helper `writeActuator()`.

---

## 2. Aturan Paritas Tiga Port (Wajib 1:1)

Logika Finite State Machine (FSM) dan kontroler adaptif hidup di tiga tempat dan wajib selalu identik secara fungsional:
1. **Firmware C++**: `SmartHydrationCoaster/fsm.h` & `SmartHydrationCoaster/adaptive_controller.h`.
2. **Simulasi Python**: `test_simulation.py` (21/21 skenario wajib lulus).
3. **Simulasi Web**: `web/fsm.js` (kelas JS `CoasterFSM`, diuji `web/fsm.test.js`; 8 tombol skenario di `web/index.html` wajib hijau).

### Perintah Verifikasi Paritas
```bash
# 1. Jalankan pengujian Python (21 skenario regresi)
python test_simulation.py

# 2. Kompilasi dan jalankan harness C++ asli di PC (52 pemeriksaan paritas)
cd tools/uji_fsm
g++ -std=c++17 -Wall -Wextra -I. -I../../SmartHydrationCoaster -o uji_fsm uji_fsm.cpp
./uji_fsm
```
*Catatan kompilasi*: Flag `-I.` wajib ada agar `Arduino.h` shim di `tools/uji_fsm/` terbaca saat mengompilasi header firmware asli.

---

## 3. Logika FSM & Aturan Pengendalian

* **7-State FSM**: `STATE_IDLE`, `STATE_STABLE`, `STATE_TIMING`, `STATE_LIFTED`, `STATE_ALERT_DRINK`, `STATE_ALERT_CHEAT`, `STATE_ALERT_REFILL` + flag `missingCupAlert`. `ALERT_EMPTY_CUP`/`ALERT_MISSING_CUP` hanyalah string turunan flag, bukan state.
* **Anti Tekan-Lepas (K1)**: isi ulang langsung di tatakan dicatat sebagai *pending*; bila berat kembali ke baseline pra-isi-ulang dalam `REFILL_CONFIRM_MS` (5 s), isi ulang dibatalkan dan penurunan tidak dicatat sebagai minum. Pembatalan memulihkan state & timer pra-isi-ulang (kecuali `LIFTED`/`ALERT_REFILL`), sehingga tekan-lepas tidak membunuh alarm minum atau menunda timer.
* **Selaras Kalibrasi (K3)**: `setEmptyCupWeight()` saat state aktif memaksa `ALERT_REFILL` dengan flag `calibrationAlign`; `update()` menyelaraskan baseline ke berat aktual lebih dulu, tidak menghitung isi ulang untuk air yang sudah ada di gelas. Flag dibersihkan juga saat berat kosong teramati di `ALERT_REFILL`, agar tidak basi setelah gelas diangkat lalu kembali (isi ulang sah tetap terhitung).
* **Gerbang Stabilitas (Fix C4)**:
  * Setiap keputusan berbasis selisih berat ($\Delta W$) WAJIB menunggu berat stabil via `isStable()`.
  * Definisi stabil: berat bertahan dalam toleransi $\pm 3\text{ g}$ selama $1.500\text{ ms}$.
  * Mencegah false-drink saat mengangkat gelas (terangkat bertahap ~46 g/sampel @10Hz) yang sebelumnya merusak baseline dan membuat ALERT_CHEAT mustahil tercapai.
* **Baseline & Cheat Behavior**:
  * Baseline TIDAK diperbarui saat terjadi curang (`STATE_ALERT_CHEAT`). Jika user curang lalu kemudian minum sah, selisih minum dihitung akumulatif terhadap baseline awal.
  * Baseline hanya ditimpa saat isi ulang sah (`refill` $\ge 30\text{ g}$).
* **Kendali Adaptif DHT11**:
  * Menggunakan interpolasi linier sepotong-sepotong (*piecewise-linear*) kontinu pada batas suhu (18°C, 26°C, 34°C) dan kelembaban (30%, 50% RH).
  * Floor interval minimal: 5 detik (demo mode) / batas aman.
  * Interval dasar $T_{\text{base}}$ dapat dikustomisasi 1 s.d. 180 menit via perintah serial `i<menit>` atau UI.
  * *Catatan Terminologi*: Ini kendali adaptif berbasis aturan kontinu, BUKAN Fuzzy Logic Sugeno.

---

## 4. Telemetri & Web PWA

* **Protokol ESP32**: HTTPS REST via `HTTPClient` + `WiFiClientSecure` (`setInsecure()`, Port 443, Wi-Fi STA 2.4 GHz).
  * Endpoint: PATCH `/smart_coaster/telemetry.json` (on-change + heartbeat 5 s), GET `/smart_coaster/config.json` (poll 15 s).
  * Tanpa NTP: firmware tidak menyinkronkan waktu; riwayat harian dihitung di web (`localStorage`) per tanggal perangkat.
* **Web App**: PWA (`web/manifest.json`, `web/sw.js`) mendukung mode Simulator, USB Live (`navigator.serial` 115200 baud), dan Firebase Cloud (poll REST 2,5 s).
* **Aplikasi Android (Flutter)**: `app/` (Dart, package `smart_coaster`) — mode Cloud saja: URL RTDB dimasukkan runtime (SharedPreferences `shc_fb_url`, setara `localStorage` PWA), polling `GET <url>/smart_coaster.json` 2,5 s, kontrol `PATCH <url>/smart_coaster/config.json` (`timer_mode`, `manual_interval_min`, `muted`). Identitas visual mengikuti web PWA (palet dark-teal/cyan, Space Grotesk + JetBrains Mono tabular, badge state berwarna); `ALERT_EMPTY_CUP`/`ALERT_MISSING_CUP` tetap dipetakan ke `ALERT_REFILL`. Kalibrasi `c`/tare `t` tetap USB-only. Verifikasi: `flutter pub get && flutter analyze && flutter test` (18 uji kontrak & alur cloud). Toolchain di luar repo: `D:/flutter`, `D:/jdk/jdk-17.0.20.1+1`, `D:/android-sdk`.

---

## 5. Audit Mekanikal & CAD 3D (Status 2026-10-18)

Objek: `cad/coaster_casing.scad` & `web/casing_3d.html` (sasis 28 mm). Dimensi komponen
berasal dari lembar spesifikasi penjual di `Foto spesifikasi sensor dan aktuator/`.

* **Load cell**: 12.7 x 12.7 x 80 mm, cantilever, ujung belakang di spacer.
* **ESP32**: PCB 25.4 mm, baris pin 22.86 mm, di x -17.78..7.62 dan y 77.76..126.02.
* **Buzzer**: modul 32 x 13 x 10 mm memanjang di strip kanan papan, can di (x 16.51, y 69.73). VCC wajib `3V3`.
* **DHT11**: modul 32 x 14 mm diputar (14 mm sejajar x) di wadah depan kiri, x -31..-17, y -10..22, pin menghadap septum.
* **HX711**: PCB 34.5 x 21 mm di wadah depan kanan, header 4-pin menghadap keluar di x 42.25..44.79.
* **Motor getar**: modul 23 x 21 mm menempel di bawah tutup, motor koin turun ke z 21.2. Header male dilepas, kabel disolder ke pad.
* **Pemasangan modul**: pin buzzer, DHT11, dan motor keluar mendatar, jadi tidak ada yang disolder ke papan. Modul ditempel datar (tape 0.5 mm) dan disambung jumper female-female ke header male di papan: buzzer (16.51, 104.43), DHT11 (-3.81, 63.79), HX711 (2.54, 71.41).
* **Bukaan USB**: 15 mm di x -12.58..2.42, mengikuti pusat ESP32 x -5.08 supaya selubung port 7.5 mm (x -8.83..-1.33) tidak tertutup dinding. Potongan menembus sampai y 145.4 karena permukaan luar kapsul ada di y 138.

**Grid perfboard** (dipakai SCAD dan HTML): kolom `x = -21.59 + 2.54k` (18 kolom), baris
`y = 63.79 + 2.54k` (24 baris). Semua pin modul wajib jatuh di grid ini.

Verifikasi: `python tools/cad_check/verify_stackup.py` (59 pemeriksaan). Temuan terbuka dan
status temuan lama ada di `AUDIT_DESIGN_3D.md`.

---

## 6. Preferensi & Panduan Komunikasi

* Komunikasi lugas, objektif, teknis, tanpa basa-basi (*ponytail* dan *anti-slop*).
* Gunakan istilah teknis asli dalam huruf miring saat menulis laporan (*baud*, *payload*, *firmware*, *baseline*, dll.).
* Jika menyarankan perubahan logika, pastikan ketiga port (C++, Python, Web) diselaraskan bersamaan.

<!-- antislop:start -->
## antislop
For UI, copy, people, mobile layout, or code comments work, read `antislop.md` (core) and then the skill for the task:
- UI / visual: `skills/antislop-ui/SKILL.md`
- Copy & text: `skills/antislop-copywriting/SKILL.md`
- People: `skills/antislop-human/SKILL.md`
- Mobile / responsive: `skills/antislop-layoutmobile/SKILL.md`
- Code comments: `skills/antislop-code/SKILL.md`
Before starting, ask the user when antislop applies: during the work, or after it is done.
<!-- antislop:end -->
