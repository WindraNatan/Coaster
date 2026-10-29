# Panduan Pengujian & Operasional Sistem: Smart Hydration Coaster

Dokumen ini memuat panduan merakit, mengkalibrasi, serta mengoperasikan *Smart Hydration Coaster* secara utuh, baik melalui *Serial Monitor* maupun aplikasi *Progressive Web App* (PWA) [`web/index.html`](file:///d:/Kuliah/Sistem%20Kendali/web/index.html).

## 1. Pengabelan Perangkat Keras (Pastikan ESP32 Mati Saat Merakit)

| Modul | Pin Modul | Pin ESP32 | Catatan Teknis |
| :--- | :--- | :--- | :--- |
| **HX711** | `VCC` / `GND` | `VIN (5V)` atau `3V3` / `GND` | Eksitasi *load cell* 5 kg |
| **HX711** | `DOUT` / `SCK` | `GPIO16` / `GPIO4` | Pembacaan ADC 24-bit pada laju 10 Hz |
| **DHT11** | `VCC` / `GND` / `DATA` | `3V3` / `GND` / `GPIO19` | Pembacaan suhu & kelembaban tiap 2 detik |
| **Buzzer (PNP S8550)** | `VCC` / `GND` / `I-O` | **`3V3`** / `GND` / `GPIO18` | **Active-LOW** (`LOW` = bunyi). `VCC` **wajib** ke `3V3` agar transistor PNP *cut-off* saat `GPIO18` `HIGH` |
| **Motor Getar (NPN S8050)** | `VCC` / `GND` / `IN` | `VIN (5V)` / `GND` / `GPIO17` | **Active-HIGH** (`HIGH` = getar) |
| **LED Onboard** | Internal | `GPIO2` | Tidak dipakai di kit ini. Hanya ada di sebagian board; firmware tetap menulis ke pin ini, jadi abaikan kalau LED tidak menyala |

Kabel *load cell* 5 kg ke modul HX711: Merah ke `E+`, Hitam ke `E-`, Hijau ke `A+`, Putih ke `A-`.

## 2. Persiapan Arduino IDE

1. *Board*: **ESP32 Dev Module** (melalui paket *esp32 by Espressif Systems* di *Boards Manager*).
2. *Library* (*Library Manager*):
   - **HX711** oleh Bogdan Necula
   - **DHT sensor library** oleh Adafruit (beserta *Adafruit Unified Sensor*)
   - `<Preferences.h>`, `<WiFi.h>`, `<HTTPClient.h>`, dan `<WiFiClientSecure.h>` sudah termasuk otomatis di *core* ESP32.

## 3. Faktor Kalibrasi *Load Cell* 5 kg (`450.7f`)

Faktor kalibrasi untuk *load cell* 5 kg pada perangkat ini telah diverifikasi menggunakan beban acuan 500 g dan dikunci di [`SmartHydrationCoaster/config.h`](file:///d:/Kuliah/Sistem%20Kendali/SmartHydrationCoaster/config.h):

```cpp
#define DEFAULT_CALIBRATION_FACTOR 450.7f
```

Hasil uji derau statis 20 sampel (`run_noise_test` pada [`tools/test_loadcell/test_loadcell.ino`](file:///d:/Kuliah/Sistem%20Kendali/tools/test_loadcell/test_loadcell.ino)):
- Rata-rata: `500.10 g` (rentang `499.98 g` sampai `500.19 g`, *peak-to-peak jitter* `0.21 g`).
- Jika kelak mengganti batang *load cell* fisik, jalankan [`tools/kalibrasi/kalibrasi.ino`](file:///d:/Kuliah/Sistem%20Kendali/tools/kalibrasi/kalibrasi.ino) untuk mencari faktor baru.

## 4. *Upload Firmware* Utama & Daftar Perintah *Serial*

Buka [`SmartHydrationCoaster/SmartHydrationCoaster.ino`](file:///d:/Kuliah/Sistem%20Kendali/SmartHydrationCoaster/SmartHydrationCoaster.ino) di Arduino IDE, lalu *upload* ke ESP32. Seluruh pengaturan dan progres harian otomatis disimpan secara permanen di memori *non-volatile* (`<Preferences.h>` NVS *Flash*) sehingga **tidak hilang meskipun ESP32 dicabut dari listrik atau di-*restart***.

| Perintah | Contoh | Fungsi |
| :--- | :--- | :--- |
| `t` | `t` | *Tare* titik nol *load cell* (pastikan tatakan kosong tanpa gelas) |
| `c` | `c` | Simpan berat gelas kosong langsung dari beban yang sedang berada di atas tatakan (`35` s.d. `300 g`) |
| `e<gram>` | `e130` | Tetapkan berat gelas kosong secara spesifik dalam gram (tersimpan di NVS) |
| `i<menit>` | `i25` | Tetapkan interval dasar pengingat minum (`1` s.d. `180` menit) dan aktifkan Mode Normal |
| `d` | `d` | *Toggle* Mode Demo (`15 detik`) vs Mode Normal (interval dasar *user*) |
| `m` | `m` | *Toggle* Mode Pewaktuan: **Adaptif Kontinu DHT11 (`AUTO`)** vs **Manual Tetap (`MANUAL`)** |
| `q` | `q` | *Toggle* **Mode Hening (*Silent Mode*)**: mematikan suara *buzzer* (`MUTE`), mempertahankan getaran motor |
| `r` | `r` | *Reset* statistik minum harian ke nol |
| `w<ssid>\|<pass>` | `wKosPutra\|rahasia123` | Simpan kredensial Wi-Fi 2,4 GHz ke NVS dan sambungkan ulang otomatis tanpa *re-flash* |
| `f<url>` | `fhttps://...` | Simpan URL Firebase Realtime Database ke NVS dan aktifkan sinkronisasi *cloud* Core 0 |

## 5. Cara Menggunakan Aplikasi PWA ([`web/index.html`](file:///d:/Kuliah/Sistem%20Kendali/web/index.html))

Buka [`web/index.html`](file:///d:/Kuliah/Sistem%20Kendali/web/index.html) menggunakan Google Chrome atau Microsoft Edge (untuk fitur instalasi PWA penuh dan *Service Worker*, jalankan melalui *local server* seperti `python -m http.server 8000` di folder proyek lalu buka `http://localhost:8000/web/`).

1. **Mode Simulator:** Menguji seluruh 8 skenario PRD secara interaktif di *browser* dengan percepatan waktu `x1` hingga `x600`.
2. **Mode USB *Live* (*Web Serial API*):**
   - Klik *tab* **USB Live**, lalu tekan **Hubungkan Port ESP32** dan pilih *port* COM ESP32 Anda (**pastikan *Serial Monitor* Arduino IDE sudah ditutup** agar *port* COM tidak terkunci).
   - Data berat, volume air, suhu/kelembaban DHT11, sisa waktu, dan status FSM langsung tampil secara *real-time*.
   - Anda dapat menekan tombol **Tare Load Cell**, **Simpan Gelas**, **Atur Interval**, **Buzzer: Hening**, maupun mengisi **SSID Wi-Fi & URL Firebase** lalu klik **Kirim Wi-Fi & Cloud ke ESP32** untuk memprogram kredensial jaringan ke NVS ESP32 tanpa menyentuh kode.
3. **Mode Cloud Firebase:**
   - Masukkan URL Firebase Realtime Database (`https://...firebaseio.com` atau `https://...firebasedatabase.app`) dan klik **Hubungkan Cloud**.
   - Aplikasi di ponsel Android maupun laptop akan menyinkronkan telemetri, konfigurasi interval, dan riwayat harian (`/smart_coaster/daily/{YYYY-MM-DD}`) secara *real-time*.
4. **Ekspor Data Laporan (CSV):**
   - Klik tombol **Unduh CSV** di atas panel log untuk mengunduh rekaman lengkap pengujian (`timestamp`, `state`, `weight_g`, `water_ml`, `temp_c`, `humidity_pct`, `target_interval_sec`, `total_drank_ml`, `drink_count`, `refill_count`, `cheat_count`) sebagai bahan grafik laporan RSK-352 dan RSK-354.
