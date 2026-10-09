# Cara Uji Sistem Secara Nyata (Tanpa Buzzer & Motor)

Buzzer dan motor bisa ditunda: GPIO18/17 hanya diberi OUTPUT kosong, firmware tetap jalan penuh. Sebagai gantinya, LED onboard (GPIO2) berkedip mengikuti pola alert yang sama dengan buzzer. Sisanya: tatakan gelas, HX711 + load cell, DHT11, kabel USB, ESP32 DevKit.

## 1. Wiring (ESP32 mati dulu)

| Modul | Pin modul | Ke ESP32 |
|---|---|---|
| HX711 | VCC | 3V3 |
| HX711 | GND | GND |
| HX711 | DOUT | GPIO16 |
| HX711 | SCK | GPIO4 |
| DHT11 | VCC / GND / DATA | 3V3 / GND / GPIO19 |
| Buzzer (S8550 PNP) | VCC / GND / I-O | **3V3** / GND / GPIO18 |
| Motor getar (S8050 NPN) | VCC / GND / IN | 5V (VIN) / GND / GPIO17 |

Load cell ke HX711 (kabel standar): merah → E+, hitam → E-, hijau → A+, putih → A-.

Catatan DHT11: kalau modul 3 pin, colok langsung. Kalau sensor mentok 4 pin, butuh resistor 10k antara VCC dan DATA.

## 2. Siapkan Arduino IDE

Board: esp32 by Espressif (Boards Manager). Library (Library Manager): **HX711** oleh Bogdan Necula, **DHT sensor library** oleh Adafruit (ikut menarik Adafruit Unified Sensor).

## 3. Kalibrasi load cell (sekali, wajib)

1. Buka `tools/kalibrasi/kalibrasi.ino`, upload ke ESP32, buka Serial Monitor **115200**.
2. Tatakan kosong saat boot (skrip tare otomatis).
3. Taruh benda beratnya diketahui (misal botol 600 ml = ±600 g, atau takaran dapur).
4. Tekan `+` / `-` di Serial sampai bacaan = berat asli. Faktor berubah per 10.
5. Tekan `f`, salin nilai yang muncul ke `SmartHydrationCoaster/config.h`:

```cpp
#define DEFAULT_CALIBRATION_FACTOR -137.0f  // <- ganti dengan nilaimu
```

## 4. Upload firmware utama

Buka folder `SmartHydrationCoaster/` di Arduino IDE (yang `.ino`-nya sudah diganti nama, jangan main.ino). Upload, buka Serial Monitor 115200. Muncul: `Smart Hydration Coaster - ESP32 Siap.` beserta daftar perintah.

## 5. Perintah Serial

| Ketik | Fungsi |
|---|---|
| `t` | Tare titik nol (tatakan tanpa gelas) |
| `c` | Simpan berat gelas kosong (dari bacaan saat ini; maks 300 g) |
| `d` | Toggle mode Demo: 15 detik ↔ 30 menit (default: demo AKTIF) |
| `m` | Toggle timer adaptif DHT11 ↔ manual |
| `r` | Reset statistik harian |

## 6. Alur uji (mode demo, timer 15 s)

1. Tanpa gelas: tekan `t` (tare), lalu taruh gelas kosong dan tekan `c`. Telemetri tiap 0,5 s menampilkan berat, air, state.
2. Tuang air ke gelas (≥ 200 g lebih berat) → tunggu ~1,5 detik → state masuk `TIMING`, timer jalan.
3. Tunggu 15 detik → `ALERT_DRINK`, LED kedip 500 ms. Ini pengingat minum.
4. Angkat gelas, minum beberapa teguk (turun ≥ 20 g), taruh kembali, diamkan 1,5 detik → alarm mati, timer reset, "Diminum" naik. Minum terverifikasi.
5. Uji anti-cheat: **angkat gelas sampai benar-benar lepas dari tatakan** (berat jatuh di bawah 25 g, state `LIFTED`), lalu taruh kembali tanpa minum sehingga selisih berat terhadap baseline kurang dari 20 g → `ALERT_CHEAT`, LED kedip cepat 150 ms. Yang penting gelas harus terangkat dulu; menyentuh atau menekan gelas tanpa mengangkatnya tidak membawa ke cabang ini.
6. Kosongkan gelas, taruh → `ALERT_EMPTY_CUP`, LED kedip 750 ms.
7. Angkat gelas > 10 detik → `ALERT_MISSING_CUP`, alarm bertahan sampai gelas kembali.
8. Isi ulang → alarm mati, state kembali `TIMING`.
9. Tekan `r` untuk mengosongkan statistik harian, `d` untuk mencoba interval normal 30 menit (kembalikan ke `d` lagi setelahnya).

Kalau LED kedip tapi ingin memastikan urutan persisnya, bandingkan dengan simulator web: `web/index.html` menjalankan FSM yang sama, tombol skenarionya meniru langkah di atas.

### Membaca baris `[DBG]`

Setiap perpindahan state mencetak satu baris diagnostik:

```
[DBG] -> LIFTED | w=12.4 | baseline=380.0 | delta=-367.6g | vonis=-
```

Kolom `vonis` menyatakan apa yang diputuskan FSM saat transisi itu: `MINUM`, `REFILL`, `CHEAT`, atau `-` bila tidak ada yang dicatat. Yang perlu diperiksa saat mengangkat gelas penuh: vonisnya harus `-` sepanjang proses mengangkat, dan `[DBG] -> LIFTED` hanya muncul sekali. Sebelum gerbang stabilitas dipasang, satu pengangkatan mencetak empat sampai enam baris `vonis=MINUM` berurutan dengan baseline ikut merosot, dan cabang `ALERT_CHEAT` tidak pernah tercapai. Baris `[DBG]` ini sengaja ditinggal selama pengujian; hapus blok `[DBG]` di `SmartHydrationCoaster.ino` sebelum dikumpulkan.

## Catatan Polaritas & Catu Daya Aktuator

Polaritas buzzer (`LOW` = bunyi, modul PNP S8550) dan motor (`HIGH` = getar, modul NPN S8050) sudah dikunci di `config.h`. Pastikan `VCC` modul buzzer dihubungkan ke **`3V3`** (bukan `5V`, karena pada `5V` transistor PNP tidak bisa *cut-off* dari sinyal `HIGH` `3,3V` ESP32), sedangkan `VCC` motor getar dihubungkan ke `5V` (`VIN`).
