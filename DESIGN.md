# DESIGN.md: Panduan Sistem Desain dan UX Smart Hydration Coaster
**Versi:** 4.0 (November 2026) - *Mineral Stoneware & Deep Spring Teal*  
**Rujukan Ekosistem `style.ai.id`:** *Heritage* (`design.dev/ai/design-md-generator` untuk palet hangat keramik dan elevasi tonal tanpa bayangan berlebih), *Apple* (`designmd.co/d/apple` untuk bayangan kontak fisik khusus perangkat keras dan respons tekan taktil), *Anthropic* (`designmd.co/d/anthropic` untuk kurva gerak halus `cubic-bezier(0.16, 1, 0.3, 1)`), serta *Antislop* (`antislop.ai.id`, 40 aturan anti-slop).  
**Platform Target:** *Web PWA* (Desktop, Tablet, Ponsel) dan Aplikasi *Mobile* Android (Flutter)  
**Status Dokumen:** *Single Source of Truth* Desain Antarmuka dan Pengalaman Pengguna (*UI/UX*)

---

## 1. Arah Desain (*Design Read & Unslop Direction*)

* **Design Read (`antislop`):** Reading this as: daily hydration companion web app for everyday users & live presentation demo, in a calm mineral stoneware physical-product style, dial `ENERGY 1 / RHYTHM 2 / MOTION 1`.
* **Unslop 5-Line Direction:**
  * **Product:** Aplikasi pendamping tatakan gelas pintar yang memantau isi air, mengatur pengingat minum sesuai suhu ruangan, dan mencatat hidrasi harian.
  * **Character:** tenang, presisi, membumi.
  * **World:** meja kerja pagi hari dengan gelas kaca air mineral dingin di atas tatakan keramik matte (*matte stoneware ceramic & deep spring water*).
  * **Moments:** visual gelas kaca berisi air di atas tatakan keramik dengan bayangan kontak fisik (`--shadow-coaster`) dan permukaan air hidup.
  * **Signature:** satu warna air mineral dalam (`#0B5D6B`) yang muncul hanya di air gelas, progres aktif, dan satu aksi utama (`Mulai sesi`).

### Prinsip Inti
1. **Teknologi Tenang (*Calm Companion*):** Permukaan kanvas keramik matte `#F4F6F5` dan kartu porselen halus `#FBFCFB` (tanpa `#FFFFFF` murni yang menyilaukan dan tanpa bayangan kartu generik). Kedalaman antarmuka dibentuk melalui lapisan tonal dan garis tepi `1px`.
2. **Satu Fokus Utama di Layar Pembuka:** Di desktop `1280x800`, panggung gelas + tiga cincin hidrasi + kondisi ruang dan kendali sesi tampil utuh tanpa perlu gulir.
3. **Pemisahan Konsumen Harian vs Mode Presentasi:** Tombol simulasi sentuhan gelas dan panel `Simulasi presentasi` (beserta penggeser berat, suhu, percepatan waktu, dan 8 skenario uji) hanya muncul saat mode `Simulasi` aktif dan disembunyikan total di mode `Kabel USB` serta `Online`. Panel simulasi juga dapat dilipat agar presentasi tetap bersih.
4. **Bebas Jargon Pengembang di Layar Pengguna Web:** Seluruh istilah teknis *backend* maupun perangkat keras seperti `FSM`, `HX711`, `DHT11`, `ESP32`, `UID`, `RH`, `Tare`, `Buzzer`, `Standby`, `Log Sensor`, `Diagnostik`, `C++/Python/JS`, `115200 baud`, serta kode status internal (`IDLE`, `STABLE`, `TIMING`, `LIFTED`, `ALERT_*`, `CHEAT`, `REFILL`) dihapus dari salinan layar pengguna Web PWA dan diganti ke bahasa Indonesia yang lugas dan ramah. Protokol JSON/serial internal tetap dipertahankan di kode komunikasi dan tes paritas.
5. **Disiplin Anti-Slop & Aksesibilitas:** Tanpa tanda hubung panjang (*em dash*/*en dash*), tanpa `animate-pulse`, tanpa `transition-all`, tanpa kartu di dalam kartu, tanpa *pill* dekoratif, tanpa `uppercase tracking` pada label kecil, serta wajib lolos rasio kontras WCAG AA (`>= 4.5:1` teks normal) dan sasaran sentuh `>= 44 px` pada layar sentuh.

---

## 2. Sistem Token Desain (*Mineral Stoneware & Deep Spring Teal*)

### A. Palet Warna `:root` Terverifikasi WCAG AA/AAA
| Token CSS | Nilai Hex / CSS | Peran dan Penggunaan | Rasio Kontras WCAG |
| :--- | :--- | :--- | :--- |
| `--bg-canvas` | `#F4F6F5` | Kanvas utama *warm matte stoneware* | 15.36:1 dgn `--ink-primary` |
| `--bg-surface` | `#FBFCFB` | Permukaan kartu utama | 16.21:1 dgn `--ink-primary` |
| `--bg-subtle` | `#EAEEEC` | Permukaan kontrol tersegmentasi & blok aktivitas | 4.80:1 dgn `--ink-muted` |
| `--border-hairline` | `#D7DFDC` | Garis tepi `1px` kartu dan pemisah seksi | Pemisah halus |
| `--border-control` | `#768782` | Garis tepi tombol sekunder, input, dan batang hari lampau | 3.67:1 non-teks |
| `--ink-primary` | `#16201E` | Judul utama, angka metrik, dan teks aktif | 16.21:1 dgn `--bg-surface` |
| `--ink-secondary` | `#475652` | Teks pendukung, label formulir, subjudul | 7.50:1 dgn `--bg-surface` |
| `--ink-muted` | `#5B6B66` | Keterangan tambahan dan label waktu | 5.46:1 dgn `--bg-surface` |
| `--accent` | `#0B5D6B` | Aksen tunggal *Deep Spring Teal* (`Mulai sesi`, cincin progres, hari ini) | 7.31:1 dgn `--accent-ink` |
| `--accent-hover` | `#084853` | Kondisi *hover* aksi primer | 9.90:1 dgn `--accent-ink` |
| `--accent-soft` | `#E3F0F2` | Latar sorotan lembut aksen & seleksi teks | 6.45:1 dgn `--accent` |
| `--accent-ink` | `#FBFCFB` | Teks di atas tombol aksen `--accent` | 7.31:1 |
| `--water-top` | `#3B93A1` | Gradasi atas permukaan cairan air dalam gelas | Visual cairan |
| `--water-bottom` | `#0B5D6B` | Gradasi dasar cairan air dalam gelas | Visual cairan |
| `--ok` / `--ok-bg` / `--ok-border` | `#16654B` / `#E6F3EE` / `#B7DDD0` | Status stabil, gelas terdeteksi, koneksi aktif | 6.15:1 |
| `--warn` / `--warn-bg` / `--warn-border` | `#8C4B0C` / `#FDF3E3` / `#EED0A0` | Pengingat waktunya minum, perhatian ringan | 6.11:1 |
| `--danger` / `--danger-bg` / `--danger-border` | `#9B2C2C` / `#FBECEC` / `#EBC1C1` | Air hampir habis, tegukan belum cukup, atau kendala koneksi | 6.56:1 |
| `--backdrop` | `rgba(22, 32, 30, 0.42)` | Latar belakang `<dialog>` modal | Lapisan modal |
| `--shadow-coaster` | `0 18px 34px -14px rgba(22, 32, 30, 0.16), 0 4px 10px -4px rgba(22, 32, 30, 0.08)` | Bayangan kontak fisik khusus panggung gelas & tatakan | Elevasi objek fisik |
| `--ease-calm` | `cubic-bezier(0.16, 1, 0.3, 1)` | Kurva gerak tunggal transisi UI | Gerak tenang |

### B. Tipografi & Aturan Numerik
* **Antarmuka & Judul (`--font-sans`):** *Instrument Sans* dengan bobot `400` (Reguler), `500` (Medium), dan `600` (Semi-bold) saja (tanpa bobot `700`/`800`/`900`).
* **Angka Murni (`--font-mono`):** *IBM Plex Mono* bobot `500` dengan `font-variant-numeric: tabular-nums`. Aturan ketat anti-slop (`Hallmark REFLEX 64`): `font-mono` hanya diterapkan pada elemen yang berisi angka murni (misalnya hitung mundur `00:15` atau bobot `350.0`), sedangkan kata, label, dan satuan (`ml`, `g`, `°C`, `%`) selalu menggunakan *Instrument Sans*.

### C. Radius, Elevasi, dan Gerak
* **Radius:** Kartu utama `16px` (`rounded-2xl`), petak internal `12px` (`rounded-xl`), kontrol/tombol/input `8px` (`rounded-lg`) hingga `12px` (`rounded-xl`).
* **Elevasi:** Kartu UI datar menggunakan batas `1px` `--border-hairline` dan perbedaan tonal `--bg-canvas` ke `--bg-surface`. Satu-satunya bayangan ada pada objek fisik tatakan gelas (`--shadow-coaster`).
* **Keadaan Interaktif & Aksesibilitas:**
  * Seluruh tombol tidak memakai `transition-all`, menggunakan `transition-colors duration-150` atau `transition-transform duration-300 ease-calm`.
  * Kondisi tekan aktif global: `button:not(:disabled):active { transform: scale(0.98); }`.
  * Indikator fokus instan: `:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }`.
  * Modal menggunakan `<dialog closedby="any">` dengan `.showModal()` dan *fallback* klik latar luar untuk Safari.

---

## 3. Arsitektur Tata Letak Web PWA

```
+-----------------------------------------------------------------------------+
| HEADER: Ikon Tetes Datar + Smart Hydration Coaster + Status | Simulasi/USB/Online | Masuk |
+-----------------------------------------------------------------------------+
| [KOLOM 1-5: GELAS DI TATAKAN]           | [KOLOM 6-12 ATAS: 3 CINCIN HIDRASI] |
| - Badge status bahasa sehari-hari       | - Target harian (%)                 |
| - Visual gelas + bayangan fisik tatakan | - Isi gelas (ml & kondisi)          |
| - Angka isi air & berat total           | - Jadwal minum (MM:SS)              |
| - Pesan pendamping 1 kalimat            +-----------------------------------+
| - Tombol simulasi fisik (hanya Simulasi)| [KOLOM 6-12 BAWAH: SUHU & SESI]     |
|                                         | - Suhu ruangan & kelembapan         |
|                                         | - Ringkasan sesi saat ini           |
|                                         | - Mulai sesi (primer) & Istirahatkan|
+-----------------------------------------+-----------------------------------+
| [KOLOM 1-4: PENGATURAN]                 | [KOLOM 5-12: RIWAYAT MINUM]         |
| - Jadwal (Sesuai suhu / Manual / Demo)  | - Tab 1: Grafik 7 hari terakhir     |
| - Jeda minum, suara pengingat           | - Tab 2: Catatan aktivitas + CSV    |
| - Target harian, berat gelas kosong     |                                     |
| - Nolkan timbangan & mulai hitungan baru|                                     |
+-----------------------------------------+-----------------------------------+
| [OPSIONAL, HANYA MODE SIMULASI: SIMULASI PRESENTASI (BISA DILIPAT)]          |
| - Penggeser Berat, Suhu, Kelembapan + Kecepatan waktu + 8 Skenario Uji      |
+-----------------------------------------------------------------------------+
```

---

## 4. Kamus Bahasa Pengguna Web PWA (Bebas Jargon Teknis)

Daftar pemetaan status protokol internal ke salinan ramah pengguna di Web PWA:

| Status / Istilah Internal | Label & Pesan di Web PWA | Catatan |
| :--- | :--- | :--- |
| `IDLE` | `Siap dipakai` / Letakkan gelas di tatakan untuk mulai memantau. | Tanpa kode `IDLE`. |
| `STABLE` | `Gelas terdeteksi` / Gelas sudah tenang di tatakan dan siap dipantau. | Tanpa istilah toleransi `±3 g`. |
| `TIMING` | `Pemantauan aktif` / Jadwal minum sedang berjalan. | Tanpa kata `FSM` atau `TIMING`. |
| `LIFTED` | `Gelas diangkat` / Silakan minum air dari gelasmu. | Bahasa alami. |
| `ALERT_DRINK` | `Waktunya minum` / Ambil gelas dan minum minimal satu tegukan. | Tanpa kata `ALERT_DRINK` & tanpa tanda seru berlebih. |
| `ALERT_CHEAT` | `Belum cukup minum` / Air berkurang sedikit. Silakan minum satu tegukan lagi. | Menggantikan istilah menghakimi `CHEAT`/`curang`. |
| `ALERT_EMPTY_CUP` | `Air hampir habis` / Isi ulang air ke dalam gelas sebelum meletakkannya kembali. | Menggantikan `ALERT_EMPTY_CUP`/`REFILL`. |
| `ALERT_MISSING_CUP` | `Gelas belum kembali` / Letakkan kembali gelasmu di atas tatakan. | Menggantikan `ALERT_MISSING_CUP`. |
| `Standby` (`active:false`) | `Mode istirahat` / Sesi sedang beristirahat. Tekan Mulai sesi untuk mengaktifkan pengingat. | Menggantikan `Standby`/`Tidur`. |
| `Otomatis (AUTO_DHT)` | `Sesuai suhu` (`Otomatis sesuai suhu ruangan`) | Tanpa `DHT11`. |
| `Tare` | `Nolkan timbangan` | Tanpa `Load Cell` / `HX711`. |
| `Buzzer` | `Suara pengingat` (`Aktif` / `Hening`) | Tanpa `Buzzer MUTE/ON`. |
| `Log Sensor` | `Catatan aktivitas` | Tanpa log teknis `FSM` / `Serial`. |

---

## 5. Spesifikasi SVG Circular Gauge (`viewBox="0 0 100 100"`)
* Pusat `(50, 50)`, radius `40`, ketebalan garis `8`, keliling `C = 251.327`.
* Rotasi awal `-90°` (`-rotate-90`) dengan ujung membulat `strokeLinecap="round"`.
* Progres aktif dihitung via `strokeDashoffset = C * (1 - pct / 100)` dan bertransisi menggunakan `transition-[stroke-dashoffset,stroke] duration-300 ease-calm`.

---

## 6. Matriks Kompatibilitas & Pelestarian 69 Widget Tests Flutter (`app/`)

Aplikasi Android/multiplatform Flutter (`app/`) kini menerapkan token *Mineral Stoneware & Deep Spring Teal* (`app/lib/theme.dart` dan `app/lib/painters.dart`), tata letak adaptif 1 kolom ponsel (`< 880 px`) vs 2 kolom tablet/laptop (`>= 880 px`), grafik riwayat 7 hari (`HistoryBarsList`), penyesuaian target harian berbasis modal sheet, dan pencari tatakan pribadi `findOwnClaimCode()`, sambil mempertahankan perilaku native mobile (pengingat alarm lokal Android, `RefreshIndicator`, `HapticFeedback`, menu AppBar). Seluruh 69 pengujian otomatis di `app/test/` memverifikasi alur otentikasi, klaim perangkat, kontrol sesi, telemetri awan, tata letak adaptif, dan paritas FSM. Setiap pengembang atau agen pemelihara antarmuka **DILARANG MENGUBAH ATAU MENGHAPUS** teks target, hierarki tata letak, dan kunci widget (*keys*) berikut di `app/`:

### Rincian Pengujian Berdasarkan Berkas (`app/test/`)
* **`cloud_flow_test.dart` (25 Pengujian):**
  * `find.text('Menghubungkan ke Firebase…')`
  * Teks metrik numerik persis: `find.text('315.0')`, `find.text('185 ml')`, `find.text('07:03')`, `find.text('750.0 ml')`, `find.text('27.0 °C')`, `find.text('60.0 %')`.
  * Status FSM Badge: `find.text('TIMING')`, `find.text('REFILL')`.
  * Pesan kontekstual tatakan: `find.text('gelas belum kembali ke tatakan')`, `find.text('Gelas tidak di tatakan')`.
  * Sakelar Buzzer dan Hierarki Baris: `Row` memuat `'Buzzer'` dan `Switch`, serta teks `'ON'` atau `'OFF'`.
  * Tombol Pengendali Sesi: `find.text('Mulai sesi')` dan `find.text('Akhiri sesi')`.
  * Pilihan Demo Cepat: `find.text('Demo 15 detik')`.
  * Input Konfigurasi Interval: label persis `'Interval dasar (menit)'` berdampingan dengan `TextField`.
  * Pilihan Mode Otomatis: `find.text('AUTO_DHT')`.
  * Peringatan Siklus Berjalan: `find.textContaining('masih memakai target')` dan `find.textContaining('masih memakai target 30 menit')`.
  * Header dan Tombol Reset Harian: `find.text('Hari ini')`, `find.textContaining('150 / 2000 ml')`, dan `find.textContaining('Hari baru')`.
  * Penanganan Error Jaringan: `find.textContaining('Gagal membaca cloud:')`, `find.textContaining('HTTP 500')`, `find.textContaining('Belum ada data telemetry.')`.
  * Form Masuk Akun: `TextField.at(0)` untuk email, `TextField.at(1)` untuk password, dan tombol aksi `find.text('Masuk')`.
* **`connect_screen_test.dart` (15 Pengujian):**
  * `find.text('Email')`, `find.text('Password')`, `find.text('Masuk')`, `find.text('URL Firebase RTDB')`, `find.text('Web API Key proyek Firebase')`, `find.text(kFirebaseApiKey)`, `find.text('AIzaSalahSekali')`.
* **`claim_device_test.dart` (18 Pengujian):**
  * `GET /claims/<KODE>.json` -> `PUT /links/<uid-akun>/<uid-alat>.json`; `findOwnClaimCode()` membaca `/users/<uid>/private/claimCode.json` lalu jalur fallback; validasi panjang 8 karakter.
* **`telemetry_test.dart` (8 Pengujian):**
  * Pemetaan JSON telemetri, `ALERT_MISSING_CUP` -> `ALERT_REFILL` (`missingCup: true`, `'gelas belum kembali ke tatakan'`), `STATE_IDLE` (`'taruh gelas untuk mulai'`).
* **`auth_keystore_test.dart` (3 Pengujian):**
  * Penyimpanan sesi otentikasi SharedPreferences.

---

## 7. Daftar Periksa Pengiriman (*Delivery Checklist*)
- [x] Rujukan sistem visual & anti-slop `style.ai.id` (`Heritage`, `Apple`, `Anthropic`, `Antislop`) terdokumentasi di `DESIGN.md` v4.0.
- [x] Seluruh warna dan tipografi melalui token `:root` tanpa warna default Tailwind (`slate-*`, `sky-*`, dsb.).
- [x] Kontras WCAG AA terverifikasi lewat `contrast-check.py`.
- [x] Bebas *em dash* (`—`), bebas *card inside card*, bebas `transition-all`, bebas `animate-pulse`, dan bebas istilah pengembang di layar konsumen Web PWA.
- [x] Seluruh uji paritas 4 lapis (Node JS tests, Python 24 skenario, C++ 78 cek, Flutter 69 unit/widget tests) serta `Hallmark sloplint` (`0 FAIL`, `0 REFLEX`) terpenuhi.
