# Audit Teknis & Code Review — Smart Hydration Coaster

**Tanggal audit:** 5 Oktober 2026
**Cakupan:** `PRD_Smart_Hydration_Coaster.md`, `config.h`, `filter.h`, `fuzzy_controller.h`, `fsm.h`, `main.ino`, `kalibrasi.ino`, `test_hardware.ino`, `test_loadcell.ino`, `test sensor aktuator/SmartCoaster_Test/*`, `test_simulation.py`, `web/index.html`, `docs/pemodelan_sistem_kendali.md`
**Metode:** pembacaan statis seluruh berkas + kompilasi `fsm.h` dengan stub `Arduino.h` di g++ dan *replay* skenario uji untuk membuktikan perilaku aktual (bukan asumsi). Temuan terberat di-*cross-check* ke Atria Dawn.

**Ringkasan eksekutif.** Arsitektur proyek sudah benar secara konsep (FSM 7-state, filter moving average, timer adaptif, dashboard terpisah), tetapi ada **tiga kelas masalah yang serius**: (1) mekanisme stabilisasi/debounce FSM praktis tidak berfungsi karena dihitung per pemanggilan fungsi, bukan per satuan waktu; (2) `fsm.h`, `test_simulation.py`, dan `web/index.html` adalah **tiga implementasi berbeda** yang saling tidak sinkron — sehingga hasil "8/8 PASS" dari unit test **tidak membuktikan apa pun** tentang firmware yang dikirim; (3) polaritas buzzer terbalik — modul buzzer yang dipakai bertipe **active-LOW**, sedangkan firmware mengirim `HIGH` untuk menyalakannya, sehingga alarm justru **diam saat seharusnya berbunyi dan berbunyi terus saat tidak ada alert**. Semua temuan di bawah sudah diverifikasi, bukan dugaan.

---

## Daftar Temuan Berdasarkan Tingkat Keparahan

| Kode | Tingkat | Ringkas | Lokasi |
| :--- | :--- | :--- | :--- |
| C0 | **KRITIS** | 4 berkas `.ino` dalam satu folder → sketch tidak bisa dikompilasi | root project |
| C1 | **KRITIS** | `stabilizeCount` per pemanggilan, bukan per sampel → debounce hilang | `fsm.h`, `main.ino` |
| C2 | **KRITIS** | `stabilizeCount` tidak di-reset antar state → debounce isi-ulang hilang | `fsm.h` |
| C3 | **KRITIS** | FSM C++ / Python / JS tidak sinkron; unit test menguji logika yang berbeda | `fsm.h`, `test_simulation.py`, `web/index.html` |
| H1 | Selesai | Kedua modul aktuator terverifikasi punya driver transistor onboard | — |
| H1b | **Tinggi** | Buzzer active-LOW vs motor active-HIGH, keduanya digerakkan dari satu variabel → buzzer terbalik | `main.ino:26,42,112` |
| H2 | Tinggi | `PIN_MOTOR = GPIO2` — strapping pin + LED onboard | `config.h` |
| H3 | Tinggi | Tidak ada validasi rentang/NaN pada berat → state bisa macet | `main.ino`, `fsm.h` |
| H4 | Tinggi | "Menyala terus" vs "berkedip" — kontradiksi requirement ↔ PRD ↔ kode | `main.ino`, PRD §4.5 |
| M1 | Sedang | `BASE_INTERVAL_MS` 60 menit, PRD/test/web pakai 30 menit | `config.h`, PRD §4.3 |
| M2 | Sedang | `demoMode = true` sebagai default firmware | `main.ino` |
| M3 | Sedang | Ambang refill (30 g) vs minum (20 g) tidak konsisten di jalur berbeda | `fsm.h` |
| M4 | Sedang | Jalur `ALERT_REFILL → LIFTED` mematikan alarm lupa-gelas permanen | `fsm.h` |
| M5 | Sedang | Perintah serial `'c'` bisa menyimpan berat gelas berisi air | `main.ino` |
| M6 | Sedang | Web: `drinkCount` hanya naik saat gelas kosong, bukan per tegukan | `web/index.html` |
| M7 | Sedang | Web: interval adaptif tidak dihitung ulang saat suhu berubah | `web/index.html` |
| M8 | Sedang | Dua nilai `DEFAULT_CALIBRATION_FACTOR` berbeda (−420 vs 290) | `config.h`, `test_loadcell.ino` |
| L1 | Rendah | `emptyCupWeight` tidak dipersist (hilang saat reboot) | `fsm.h` |
| L2 | Rendah | `EMPTY_CUP_TOLERANCE` dan `MIN_DRINK_DELTA` sama-sama 20 g → ambiguitas | `config.h` |
| L3 | Rendah | Kontradiksi internal PRD soal durasi stabilisasi (1,5 s vs ±1 s) | PRD §3.1 |
| O1–O11 | Over-eng | Kode mati & duplikasi (lihat §4) | berbagai |

**Catatan positif (sudah benar, jangan "diperbaiki"):** seluruh perbandingan waktu memakai pola `nowMs - start >= interval` dengan `uint32_t`, sehingga **aman terhadap rollover `millis()`** (~49,7 hari). Ini saya uji secara eksplisit dan hasilnya benar. Pembacaan HX711 sudah *non-blocking* (`is_ready()`), dan tidak ada `delay()` di `loop()`. Itu fondasi yang bagus.

---

## 1. Temuan KRITIS

### C0 — Sketch tidak dapat dikompilasi oleh Arduino IDE

Empat berkas `.ino` berada dalam satu folder sketch yang sama:

```
main.ino          (setup + loop)
kalibrasi.ino     (setup + loop)
test_hardware.ino (setup + loop)
test_loadcell.ino (setup + loop)
```

Arduino IDE menggabungkan **semua** `.ino` dalam satu folder sketch menjadi satu unit kompilasi. Konsekuensinya: muncul **empat definisi `setup()` dan empat definisi `loop()`** → *multiple definition* / redefinition error. Selain itu, Arduino IDE mensyaratkan ada satu berkas `.ino` yang namanya identik dengan nama folder; folder ini bernama `Sistem Kendali` tetapi tidak ada `Sistem Kendali.ino`.

**Dampak:** firmware tidak bisa di-*upload* apa adanya. Ini kemungkinan besar yang memaksa `test_hardware.ino` dan `test_loadcell.ino` "dipindah-pindah" secara manual saat praktikum.

**Perbaikan:** pisahkan tiap utilitas ke folder sketch sendiri yang benar, mis.

```
SmartCoaster/          SmartCoaster.ino  (= main.ino)
  config.h  filter.h  fsm.h  fuzzy_controller.h
KalibrasiLoadCell/     KalibrasiLoadCell.ino  (= kalibrasi.ino)
TestHardware/          TestHardware.ino  (= test_hardware.ino)
TestLoadCell/          TestLoadCell.ino  (= test_loadcell.ino)
```

Cukup *rename* dan *move*, tanpa mengubah isi.

### C1 — Stabilisasi/debounce FSM praktis tidak berfungsi

**Lokasi:** `fsm.h` baris 78, 127, 173 (`stabilizeCount++`) dan `main.ino` baris 149 (`fsm.update(...)` dipanggil setiap iterasi `loop()`).

`stabilizeCount` bertambah **setiap kali `update()` dipanggil**, bukan setiap ada sampel baru. Karena `loop()` tidak memiliki `delay()` dan `update()` dipanggil di setiap iterasi, `loop()` ESP32 berputar sangat cepat (ratusan ribu kali per detik). Artinya ambang `stabilizeCount >= 10` — yang secara desain dimaksudkan sebagai debounce ±1 detik — tercapai dalam **mikrodetik**.

Saya membuktikannya dengan mengompilasi `fsm.h` di g++ dan memanggil `update()` sepuluh kali dengan stempel `millis()` yang **identik**:

```
1x update t=1000ms  -> STABLE
setelah 10x update, nowMs TETAP 1000ms -> TIMING   <== waktu berlalu = 0 ms
```

Perilaku ini juga memunculkan *false positive* anti-cheat. Pada state `LIFTED`, satu sampel transien 1 ms saja sudah langsung dievaluasi:

```
angkat gelas (baseline 380 g) -> LIFTED
1x sentuh 378 g (turun 2 g)   -> ALERT_CHEAT   (cheatCount=1)
```

Padahal tujuan `stabilizeCount` justru mencegah hal ini (dokumentasi PRD §4.1 menyebut peredaman "hentakan saat meletakkan gelas"). Debuonce untuk jalur `LIFTED` karena itu **tidak berfungsi sama sekali** — getaran meja atau noise HX711 bisa memicu peringatan anti-cheat palsu.

**Perbaikan (paling ringkas, sesuai saran Atria):** jangan panggil `fsm.update()` setiap iterasi; panggil hanya saat ada sampel baru.

```cpp
if (nowMs - lastSampleTime >= SAMPLE_INTERVAL_MS) {
    lastSampleTime = nowMs;
    if (scale.is_ready()) {
        weightFilter.add(scale.get_units(1));
        fsm.update(weightFilter.getAverage(), nowMs);   // <-- update di sini
    }
}
```

Alternatif yang lebih tahan banting: ganti konsep "hitung sampel" menjadi "hitung waktu" (`nowMs - stableStartMs >= STABILITY_TIME_MS`), sehingga tidak lagi bergantung pada seberapa sering `update()` dipanggil. Pendekatan waktu inilah yang sudah dipakai `test_simulation.py` (1500 ms) — lihat C3.

**Validasi:** Atria Dawn mengonfirmasi temuan ini benar, dengan catatan pemeriksaan di hardware: ukur jeda "gelas diletakkan → TIMING", seharusnya ±1 detik, bukan seketika.

### C2 — `stabilizeCount` tidak di-reset saat berpindah state

**Lokasi:** `fsm.h` baris 83, 112, 135, 153, 166, 178 (semua transisi **keluar** dari `STATE_STABLE`, `STATE_LIFTED`, `STATE_ALERT_REFILL`).

Nilai `stabilizeCount` hanya di-reset di tiga tempat: konstruktor, transisi `STATE_IDLE → STATE_STABLE`, dan transisi masuk `STATE_LIFTED`. Ia **tidak** di-reset ketika masuk `STATE_ALERT_REFILL`.

Karena `STATE_STABLE` hanya keluar ketika `stabilizeCount >= 10`, maka begitu masuk `STATE_ALERT_REFILL` nilainya sudah ≥ 10. Akibatnya cabang di baris 171–179 langsung terpenuhi pada **sampel pertama**:

```
gelas kosong ditaruh -> ALERT_REFILL (ALERT_EMPTY_CUP)
tuang air 1 sampel (350g) -> TIMING   <== seharusnya masih butuh 10 sampel debounce
```

Praktisnya, debounce untuk "gelas sudah diisi ulang" hilang total: satu percikan noise yang melewati ambang sudah cukup untuk menyatakan gelas terisi dan mematikan alarm.

**Perbaikan:** reset `stabilizeCount` di **setiap** entry state, bukan hanya di beberapa. Cara paling rapi: pusatkan transisi pada satu fungsi `enterState()` yang selalu mengosongkan counter, lalu panggil fungsi itu di semua cabang.

**Validasi:** Atria Dawn mengonfirmasi temuan ini benar, dengan rekomendasi yang sama (reset counter pada entry setiap state).

### C3 — Tiga implementasi FSM yang saling tidak sinkron

Ada tiga "FSM" dalam proyek ini: `fsm.h` (C++, yang benar-benar di-*upload*), `test_simulation.py` (Python), dan `web/index.html` (JavaScript, tapi ini simulator tombol — bukan FSM). Yang bermasalah adalah pasangan C++ ↔ Python, karena PRD §7 mengklaim `test_simulation.py` "memverifikasi seluruh 8 skenario FSM". Ia tidak.

Perbedaan yang saya verifikasi secara konkret:

| Aspek | `fsm.h` (C++) | `test_simulation.py` |
| :--- | :--- | :--- |
| Mekanisme stabilisasi | Hitung sampel (`stabilizeCount >= 10`) | Hitung waktu (`>= 1500 ms`, band 3 g) |
| Ambang "gelas berisi air" | `emptyCupWeight + 15` = **145 g** | `emptyCupWeight + 25` = **155 g** |
| Ambang refill saat gelas ditaruh kembali | `REFILL_DELTA` = **30 g** | `MIN_DRINK_DELTA` = **20 g** |
| Cabang refill di `STATE_TIMING` (isi ulang langsung di tatakan) | **Ada** (baris 100–105) | **Tidak ada** |
| Jalur `ALERT_REFILL → LIFTED` | **Ada** (baris 162–167) | **Tidak ada** |

Konsekuensi konkret dari dua baris terakhir, yang saya buktikan lewat *replay* ke `fsm.h`:

- Ambang 145 g vs 155 g: menaruh gelas seberat **150 g** membuat C++ masuk `STATE_TIMING` (dianggap ada air), sementara Python tetap `ALERT_EMPTY_CUP`. Selisih 10 g ini persis di sekitar ambang, jadi paling rawan.
- Ambang refill 30 g vs 20 g: menaruh gelas kembali dengan kenaikan **+20 g** membuat C++ menandainya `ALERT_CHEAT` (karena 20 < 30), sedangkan Python menganggapnya refill sah dan kembali ke `STATE_TIMING`.
- Python tidak punya jalur `ALERT_REFILL → LIFTED`, sehingga skenario **ALERT_MISSING_CUP tidak akan pernah muncul setelah alert gelas kosong**. Firmware asli bisa.

**Mengapa ini temuan berat, bukan sekadar ketidakrapian:** saya menjalankan `test_simulation.py` dan hasilnya `8/8 PASS`. Artinya unit test itu **lulus karena menguji re-implementasi Python yang berbeda dari firmware**, bukan karena firmware benar. Ini *false confidence* — paling berbahaya justru saat presentasi: penguji bisa menemukan bug di hardware padahal test "semuanya hijau".

**Perbaikan:** jadikan satu sumber kebenaran. Opsi termurah: buat `test_simulation.py` benar-benar memanggil logika C++ (mis. via *shared library* kecil atau transkrip ulang yang identik), atau minimal samakan konstantanya dan hapus divergensi yang tidak disengaja. Jika tidak, hentikan klaim bahwa test tersebut memverifikasi firmware.

---

## 2. Temuan TINGGI

### H1 — Selesai: kedua modul aktuator sudah punya driver

**Status:** **ditutup** setelah konfirmasi pemilik proyek (2026-10-05) untuk kedua aktuator.

- **Modul buzzer:** transistor S8550 (SOT-23, kode bodi `2TY`) + resistor base onboard, tepat di antara pin `I/O` dan lubang baut.
- **Modul vibration motor:** transistor driver NPN S8050 (atau MOSFET) + resistor dan komponen pengaman, tepat di samping pin `IN`.

Keduanya berarti pin GPIO **hanya menggerakkan basis transistor**, bukan menanggung arus motor/buzzer. Tiga kekhawatiran yang saya sebut sebelumnya (tegangan 3,3 V vs 5 V, arus 60–90 mA pada motor / 20–30 mA pada buzzer melewati pin, dan *back-EMF*) **gugur seluruhnya**. Rangkaian pengaman arus di PRD §2.2 terpenuhi untuk kedua aktuator — **tidak perlu menambah transistor, resistor, atau dioda eksternal.**

Yang perlu disesuaikan hanya **dokumentasi**: tabel §2.3 PRD masih menggambarkan buzzer tersambung langsung ("Positif (+) → GPIO18"), padahal kenyataannya modul 3-pin (VCC/GND/I-O). Lihat §5.5.

**Namun konfirmasi ini justru mengungkap bug baru** — kedua modul punya polaritas **berlawanan**. Lanjut ke H1b.

### H1b — Polarisasi berlawanan: buzzer active-LOW, motor active-HIGH

**Lokasi:** `main.ino` baris 26, 42, dan 112.

Hasil verifikasi pemilik proyek:

| Aktuator | Polaritas | Nyala saat | Status di firmware |
| :--- | :--- | :--- | :--- |
| Modul buzzer (`低电平触发`) | **Active-LOW** | Pin `I/O` = LOW | **Terbalik** |
| Modul vibration motor | **Active-HIGH** | Pin `IN` = HIGH | Benar |

Inilah yang membuat masalahnya halus: firmware menggerakkan **kedua** aktuator dari satu variabel yang sama (`actuatorOutputState`) dengan level logika yang identik:

```cpp
digitalWrite(PIN_BUZZER, actuatorOutputState ? HIGH : LOW);
digitalWrite(PIN_MOTOR,  actuatorOutputState ? HIGH : LOW);   // baris 42-43
```

Karena polaritas keduanya berlawanan, **tidak ada satu nilai pun yang membuat keduanya benar secara bersamaan**. Kalau `HIGH`, motor menyala benar tapi buzzer ikut "menyala" padahal active-LOW berarti diam — dan sebaliknya.

Firmware memperlakukan `HIGH` sebagai "nyala" di ketiga tempat:

```cpp
// baris 26 — cabang "tidak ada alert"
digitalWrite(PIN_BUZZER, LOW);          // dimaksudkan OFF, tapi active-LOW = ON

// baris 42 — saat alert aktif
digitalWrite(PIN_BUZZER, actuatorOutputState ? HIGH : LOW);   // HIGH = ON (salah)

// baris 112 — setup
digitalWrite(PIN_BUZZER, LOW);          // dimaksudkan OFF, tapi active-LOW = ON
```

Akibatnya, perilakunya **persis terbalik dari yang dirancang**:

| Kondisi | Yang seharusnya | Yang benar-benar terjadi |
| :--- | :--- | :--- |
| Tidak ada alert (idle, timing, stable) | Buzzer **diam** | Buzzer **berbunyi terus** sejak boot |
| `ALERT_DRINK` / `ALERT_CHEAT` / `ALERT_REFILL` | Buzzer **berbunyi berdenyut** | Buzzer **diam**, hanya berkedip sekejap saat toggle |

Ini melumpuhkan inti alatnya: kelima skenario peringatan (2, 3, 4, 5, dan varian anti-cheat) kehilangan aktuator suaranya, sementara buzzer mengganggu terus selama operasi normal. Vibration motor tidak terpengaruh kalau modulnya bertipe active-HIGH — tapi itu **belum terverifikasi**, lihat catatan di bawah.

**Cara memastikan sendiri:** nyalakan alat dan jangan sentuh apa pun. Kalau buzzer langsung berbunyi dan berhenti hanya saat alert muncul, itu konfirmasi bug ini.

**Perbaikan (satu tempat, bukan tiga):** tambahkan konstanta polaritas di `config.h`, lalu bungkus penulisan pin dalam satu fungsi kecil sehingga polaritas hanya ditentukan sekali.

```cpp
// config.h
#define BUZZER_ACTIVE_LOW 1   // modul 低电平触发 (S8550): LOW = nyala
#define MOTOR_ACTIVE_LOW  0   // modul S8050: HIGH = nyala (terverifikasi 2026-10-05)
```

```cpp
// main.ino — helper, taruh di atas handleActuators()
inline void writeActuator(uint8_t pin, bool on, bool activeLow) {
    digitalWrite(pin, (on != activeLow) ? HIGH : LOW);
}
```

Lalu ketiga pemanggilan diganti:

```cpp
// baris 26
writeActuator(PIN_BUZZER, false, BUZZER_ACTIVE_LOW);
writeActuator(PIN_MOTOR,  false, MOTOR_ACTIVE_LOW);

// baris 42-43
writeActuator(PIN_BUZZER, actuatorOutputState, BUZZER_ACTIVE_LOW);
writeActuator(PIN_MOTOR,  actuatorOutputState, MOTOR_ACTIVE_LOW);

// baris 112-113 (setup)
writeActuator(PIN_BUZZER, false, BUZZER_ACTIVE_LOW);
writeActuator(PIN_MOTOR,  false, MOTOR_ACTIVE_LOW);
```

Keuntungan pendekatan ini: karena polaritas kedua aktuator berlawanan, helper inilah yang membuat keduanya bisa digerakkan dari satu variabel `actuatorOutputState` tanpa saling mengganggu. Kalau nanti salah satu modul diganti, cukup ubah **satu angka** di `config.h`, bukan menelusuri ulang seluruh berkas.

**Catatan boot:** pada modul active-LOW, saat ESP32 baru di-reset (pin masih mengambang), pull-up bawaan modul membuat buzzer tetap diam — jadi tidak ada masalah saat boot. Untuk motor, transistor S8050 tanpa sinyal juga dalam kondisi mati. Kombinasi ini kebetulan menguntungkan.

**Catatan PWM:** modul motor mendukung sinyal PWM, jadi kekuatan getar bisa diatur dengan `analogWrite()`. Firmware saat ini belum memanfaatkannya (hanya on/off). Ini bukan bug — lihat §5.6 untuk penilaian apakah perlu diterapkan.

### H2 — `PIN_MOTOR = GPIO2` adalah strapping pin

**Lokasi:** `config.h` baris 10.

Pada ESP32 DevKit V1, **GPIO2 adalah strapping pin** yang ikut menentukan mode boot (harus LOW saat reset untuk boot SPI normal), sekaligus terhubung ke **LED onboard**. GPIO ini dipakai sebagai jalur sinyal `IN` modul driver motor getar.

Penting dipahami: **memakai modul tidak menghilangkan masalah ini.** Modul menggantikan rangkaian penggeraknya, tetapi jalur sinyalnya tetap berakhir di GPIO2 yang sama. Modul dengan pull-down di sisi input memang membuat risiko boot gagal lebih kecil — jadi ini **risiko bersyarat, bukan kepastian gagal** — tetapi GPIO2 tetap tidak terkontrol selama proses boot/flashing, dan karena ada pull-up pada strapping-nya, kondisi tertentu masih bisa membuat modul masuk *download mode* sehingga firmware tidak berjalan. Selain itu LED onboard akan ikut berkedip setiap motor dinyalakan, yang membingungkan saat debugging.

**Perbaikan:** pindahkan `PIN_MOTOR` ke pin non-strapping yang aman, mis. GPIO13, 14, 25, 26, 27, 32, atau 33. Cukup ubah satu baris di `config.h`.

**Validasi:** Atria Dawn menyatakan ini risiko nyata (bersyarat) dan merekomendasikan pin non-strapping.

### H3 — Tidak ada validasi rentang/NaN pada berat

**Lokasi:** `main.ino` baris 134–136 dan `fsm.h` `update()`.

Berat mentah dari HX711 langsung dimasukkan ke filter dan FSM tanpa pemeriksaan kewajaran. Jika sensor terlepas, kabel longgar, atau terjadi *saturasi* ADC (nilai 8388607 / −8388608 — yang justru sudah dideteksi di `test_loadcell.ino`, tapi **tidak** di firmware utama), maka:

- Nilai `NaN` membuat **semua** perbandingan di `update()` bernilai `false` → FSM tidak akan pernah bertransisi dan bisa macet permanen di state saat itu.
- Nilai negatif besar atau lonjakan ekstrem bisa memicu transisi palsu (mis. melompat ke `ALERT_REFILL`).

**Perbaikan:** tolak sampel di luar rentang wajar sebelum masuk filter, dan tangani `NaN`:

```cpp
float w = scale.get_units(1);
if (!isnan(w) && w > -50.0f && w < 6000.0f) weightFilter.add(w);
```

**Validasi:** Atria Dawn menambahkan saran *sanity check* pembacaan (tolak `< 0`, `> max`, `NaN`) plus *timeout* per state sebagai pengaman tambahan.

### H4 — "Menyala terus" vs "berkedip": requirement, PRD, dan kode tidak sepakat

Requirement yang kamu berikan menyebut: *"Timer habis & gelas belum diangkat → Buzzer, Vibration DC, dan Web Notification **menyala terus** sampai gelas diangkat."*

Implementasinya (`handleActuators`, `main.ino` 24–45) adalah **berkedip** dengan periode berbeda per status: 500 ms untuk `ALERT_DRINK`, 150 ms untuk `ALERT_CHEAT`, 750 ms untuk `ALERT_REFILL`.

Yang perlu diputuskan (bukan bug, tapi harus diselaraskan sebelum presentasi):

1. PRD §4.5 **juga** menyebut "menyala 500 ms, mati 500 ms" untuk `ALERT_DRINK` — jadi PRD sendiri kontradiktif dengan kalimat "menyala terus" di ringkasan skenario.
2. Yang benar-benar tidak sesuai adalah *Web Notification*: notifikasi browser hanya dikirim **sekali** saat transisi (baris 323–326, `state.alertReason !== lastAlertReason`), tidak berulang. Banner visual memang tetap tampil, tetapi klaim "notifikasi menyala terus" tidak terpenuhi.
3. Ada bug kecil: `lastActuatorToggle` tidak di-reset saat keluar dari mode alert. Saat alarm baru muncul, fase toggle bisa "nyangkut" mewarisi sisa waktu dari alarm sebelumnya, sehingga ketukan pertama bisa terasa tidak konsisten.

**Perbaikan:** tentukan satu perilaku yang benar (berkedip vs kontinu), lalu samakan di PRD, kode, dan web. Reset `lastActuatorToggle` saat masuk/keluar alert.

---

## 3. Temuan SEDANG & RENDAH

### M1 — `BASE_INTERVAL_MS` 60 menit vs 30 menit
`config.h` baris 26 menetapkan `BASE_INTERVAL_MS = 3600000UL` (**60 menit**). Namun PRD §4.3 menghitung contoh dengan `T_base = 30 menit`, `test_simulation.py` memakai `30 * 60 * 1000`, dan `web/index.html` memakai nilai default `30` menit. Kode dan dokumen tidak sepakat soal nilai dasar. Karena `demoMode` aktif secara default (lihat M2), perbedaan ini tidak terlihat saat demo.

### M2 — `demoMode = true` sebagai default
`main.ino` baris 21. Artinya saat pertama menyala, interval adalah 15 detik dan batas angkat gelas 10 detik — bukan operasi normal. Untuk demo kelas ini praktis, tetapi berisiko: lupa menekan `'d'` saat pengujian nyata membuat sistem berperilaku tidak sesuai spesifikasi. PRD tidak menyebut default ini. Pertimbangkan default `false` dengan opsi `'d'` untuk demo.

### M3 — Ambang refill vs minum tidak konsisten
`REFILL_DELTA = 30 g` dan `MIN_DRINK_DELTA = 20 g`. Di `STATE_TIMING` (baris 100–117), jalur naik dan turun diperlakukan berbeda (30 vs 20). Tetapi di `evaluateReturnedCup` (baris 254–268), keduanya benar-benar dibedakan juga — namun di `STATE_ALERT_DRINK/CHEAT` (baris 148) hanya jalur turun yang ada. Ada baiknya dibuat satu tabel transisi eksplisit agar tidak ada jalur yang "lupa" salah satu arah.

### M4 — `ALERT_REFILL → LIFTED` mematikan alarm lupa-gelas permanen
`fsm.h` baris 162–167: saat `missingCupAlert == true`, gelas yang diangkat **tidak** akan memindahkan state ke `LIFTED` — alarm tetap `ALERT_MISSING_CUP`. Ini sebenarnya disengaja (agar alarm tidak hilang sebelum gelas benar-benar ditaruh kembali), tetapi konsekuensinya: jika user mengangkat gelas kosong untuk diisi lalu meletakkannya di tempat lain, sistem **tidak akan pernah** kembali ke `LIFTED` dan alarm lupa-gelas tidak akan pernah bisa diselesaikan melalui jalur normal. Perlu jalur pemulihan eksplisit.

### M5 — Perintah serial `'c'` bisa menyimpan berat gelas berisi air
`main.ino` baris 85–89: `fsm.setEmptyCupWeight(currentFilteredWeight)`. Jika ditekan saat gelas berisi air, `emptyCupWeight` menjadi mis. 380 g, dan seluruh ambang (`emptyLimit = 380 + 15`) menjadi kacau — sistem akan menganggap air habis hanya ketika berat turun ke 395 g. `setEmptyCupWeight` hanya memvalidasi `weightG >= CUP_ON_THRESHOLD`, yang tidak cukup. Tambahkan peringatan/pengaman.

### M6 — Web: `drinkCount` hanya naik saat gelas kosong
`web/index.html` baris 371–377: `drinkCount++` hanya terjadi di cabang `ALERT_EMPTY_CUP`. Pada firmware, setiap tegukan sah (`totalDrankGrams`) menambah akumulasi. Jadi di dashboard, "Minum: Nx" tidak mewakili frekuensi minum, melainkan frekuensi "gelas habis" — berbeda dari maksud PRD §6.2 ("jumlah frekuensi minum").

### M7 — Web: interval adaptif tidak dihitung ulang
`computeAdaptiveMinutes()` (baris 271–282) hanya dipanggil di handler `btnSaveConfig` (baris 391). Firmware menghitung ulang setiap 2 detik. Di dashboard, nilai interval akan basi begitu suhu berubah sampai user menekan "Simpan Konfigurasi" lagi.

### M8 — Dua nilai faktor kalibrasi yang berbeda
`config.h` baris 31: `DEFAULT_CALIBRATION_FACTOR -420.0f`. `test_loadcell.ino` baris 18: `calibration_factor = 290.0f`. `kalibrasi.ino` baris 10 dan `loadcell_test.h` baris 8 memakai −420,0. Perbedaan tanda bisa jadi hanya konvensi polaritas (ada perintah `'i'` untuk membalik), tetapi perbedaan **magnitudo** (290 vs 420) menunjukkan salah satu nilai sudah basi. Ini harus dikalibrasi ulang secara fisik dan disamakan di semua berkas.

### L1 — `emptyCupWeight` tidak dipersist
Disimpan hanya di RAM. Hilang setiap reboot, kembali ke `DEFAULT_EMPTY_CUP_WEIGHT` 130 g. Untuk demo kelas dapat diterima; untuk pemakaian nyata perlu `Preferences`/NVS. *(Catatan: ini bukan cacat, hanya keterbatasan yang layak disebut di laporan.)*

### L2 — `EMPTY_CUP_TOLERANCE` dan `MIN_DRINK_DELTA` sama-sama 20 g
Secara numerik identik tetapi bermakna berbeda (toleransi deteksi kosong vs ambang tegukan sah). Kebetulan ini menimbulkan ambiguitas saat membaca kode — khususnya karena `MIN_WATER_WEIGHT = 25` di Python adalah konsep yang sama dengan `EMPTY_CUP_TOLERANCE = 15` di C++, dengan nilai berbeda. Beri nama yang menegaskan perbedaannya.

### L3 — Kontradiksi internal PRD soal durasi stabilisasi
PRD §3.1: "menstabilkan pembacaan selama 1,5 detik". PRD §4.4 (diagram): "Stabil". Kode C++: ±1 detik (dan itupun tidak berfungsi, lihat C1). Python: 1500 ms. Tiga angka berbeda untuk hal yang sama. Samakan.

### Catatan yang saya periksa dan ternyata **bukan** masalah

- **Over-voltage HX711 → GPIO16.** Awalnya saya duga DOUT HX711 akan mengikuti VCC 5 V sehingga melebihi batas 3,3 V ESP32. Atria mengoreksi: pada modul HX711 umum, DOUT high mengikuti **DVDD regulator internal (~2,6 V)**, bukan 5 V, sehingga aman untuk GPIO 3,3 V. Yang masih di luar jaminan datasheet adalah arah sebaliknya (SCK 3,3 V ke input yang butuh ~2,6 V) — masih ditoleransi, tambahkan resistor seri 1 kΩ bila ingin aman. **Jangan ubah apa pun di sini tanpa mengukur dulu.**
- **`millis()` overflow.** Semua perbandingan memakai `uint32_t` dengan pola `nowMs - start`. Saya uji dengan `timerStart = 0xFFFFF000` dan melewati rollover — hasilnya benar (`ALERT_DRINK` tetap terpicu). **Aman, tidak perlu diubah.**
- **`loop()` blocking.** `loop()` tidak memiliki `delay()`, dan HX711 dibaca dengan `is_ready()`. Arsitektur sudah non-blocking dengan baik. (DHT11 sendiri memang sensor yang lambat, tetapi karena dibaca tiap 2 detik dan tidak memblokir, ini dapat diterima.)

---

## 4. Audit Over-Engineering (`/ponytail-audit`)

Diurutkan dari potongan terbesar.

| Tag | Temuan | Lokasi |
| :--- | :--- | :--- |
| `delete:` | `test_loadcell.ino` diduplikasi **byte-per-byte identik** di `test_loadcell/test_loadcell.ino` (220 baris). Hapus salah satu. | root + `test_loadcell/` |
| `delete:` | `test_hardware.ino` diduplikasi **hampir identik** di `test sensor aktuator/SmartCoaster_Test/SmartCoaster_Test.ino` (82 baris). Hapus salah satu. | root + `test sensor aktuator/` |
| `delete:` | Empat berkas `buzzer_test.h`, `dht_test.h`, `loadcell_test.h`, `motor_test.h` (~50 baris) **tidak pernah di-`#include`** oleh berkas mana pun. Kode mati total. | `test sensor aktuator/SmartCoaster_Test/` |
| `delete:` | `MovingAverageFilter::isFilled()` — tidak ada pemanggil di seluruh repo. | `filter.h:37` |
| `delete:` | `CoasterFSM::getInterval()` dan `CoasterFSM::getBaselineWeight()` — tidak ada pemanggil. | `fsm.h:37,188` |
| `delete:` | `CoasterFSM::getAlertMessage()` — tidak dipakai; `main.ino` memakai `getStateString()`. | `fsm.h:225` |
| `yagni:` | Guard `windowSize > MAX_CAPACITY ? MAX_CAPACITY : windowSize` — satu-satunya pemanggil selalu memakai 10 < 20. | `filter.h:9` |
| `yagni:` | Cabang `#if defined(ESP8266)` dan `#else` di `test_loadcell.ino` — proyek hanya ESP32. | `test_loadcell.ino:4–13` |
| `shrink:` | `MovingAverageFilter::add()` — cabang `if/else` dapat disatukan: `if (count == maxWindow) runningSum -= buffer[head]; else count++;` lalu tiga baris sisanya sama. | `filter.h:18–30` |
| `shrink:` | `test_simulation.py`: `state_entry_ms` diset tapi tak pernah dibaca; `last_drink_ml` ditulis tapi tak pernah dibaca. | `test_simulation.py` |
| `shrink:` | `fuzzy_controller.h` dinamai "fuzzy" tetapi isinya murni *step function* `if/else` — lihat §5. Ganti nama atau perbaiki isinya. | `fuzzy_controller.h` |

**net: ≈ −350 hingga −600 baris, tanpa dependensi tambahan.**

Yang **bukan** over-engineering dan sebaiknya dipertahankan: pemisahan `config.h` (konstanta terpusat), kelas `MovingAverageFilter` (dipakai, ringkas, benar), dan struktur FSM sebagai kelas (memberi tempat yang jelas untuk reset counter — lihat C2).

---

## 5. Konsistensi PRD vs Kodebase — Klaim Akademis

Bagian ini terpisah karena dampaknya bukan pada fungsionalitas, melainkan pada **pertanggungjawaban ilmiah** di depan penguji.

### 5.1 Klaim "Fuzzy Logic Controller" tidak didukung kode

PRD §4 dan `docs/pemodelan_sistem_kendali.md` §5 mendeskripsikan secara rinci *Fuzzy Logic Controller* tipe **Sugeno orde-0**, lengkap dengan dua variabel masukan (Rasio Waktu $T_r$, Rasio Sisa Air $W_r$), fungsi keanggotaan trapesium/segitiga, **lima aturan inferensi** (R1–R5), dan defuzzifikasi *weighted average* dengan keluaran urgensi 20/50/90.

`fuzzy_controller.h` yang sebenarnya di-*upload* **hanya berisi `if/else` empat cabang** pada suhu, ditambah satu kondisi biner pada kelembaban. Tidak ada fuzzyfikasi, tidak ada inferensi, tidak ada defuzzifikasi. Fungsi tersebut juga hanya mengembalikan **interval timer**, bukan "tingkat urgensi" yang menggerakkan pola aktuator seperti yang diklaim.

Yang lebih penting: `docs/pemodelan_sistem_kendali.md` mendefinisikan **SP sebagai target konsumsi air** ($\Delta m \ge 150$ gram per 2 jam) dengan *error* $e(t) = SP - PV$, sedangkan PRD mendefinisikan **SP sebagai pengurangan massa minimal dalam batas waktu** ($\Delta W_{min} = 20$ g). Kedua dokumen mendefinisikan setpoint secara berbeda, dan tidak ada satupun yang cocok dengan kode (yang hanya membandingkan berat dengan ambang tetap).

**Rekomendasi:** ini celah paling mudah ditembus penguji. Dua pilihan jujur: (a) turunkan klaim di dokumen menjadi "kontroler *threshold* deterministik dengan adaptasi interval berbasis tabel" dan hapus bagian Sugeno — ini akurat dan tetap bisa dipertahankan; atau (b) benar-benar implementasikan FLC Sugeno orde-0 (untuk 2 masukan × 3 himpunan × 5 aturan, ini sekitar 60–80 baris C++). Jangan biarkan dokumen menjanjikan sesuatu yang tidak ada di kode.

### 5.2 Dokumentasi menyebut ESP8266

`docs/pemodelan_sistem_kendali.md` §3 (diagram blok) menyebut kontroler di **"ESP8266"**, padahal seluruh perangkat keras dan kode adalah **ESP32**. Kesalahan salin yang mudah diperbaiki, tapi mencolok.

### 5.3 Klaim filter derau yang belum diverifikasi

`docs/pemodelan_sistem_kendali.md` §6.1 mengklaim fluktuasi derau "berhasil ditekan dari ±4,5 gram menjadi < ±0,5 gram". Tidak ada berkas data pengukuran di repositori yang mendukung angka ini. `test_loadcell.ino` memang punya fungsi `run_noise_test()` yang *bisa* menghasilkan angka tersebut — sebaiknya jalankan dan lampirkan keluaran nyatanya sebagai bukti, bukan menuliskan angka di dokumen lebih dulu.

### 5.4 Skenario: 6 vs 8

Requirement yang kamu berikan mencantumkan **6 skenario wajib**; PRD §3 mencantumkan **8 skenario** (menambahkan "minum via sedotan / isi ulang langsung di atas tatakan" dan memisahkan beberapa kasus). Bukan masalah teknis, tetapi pastikan penomoran di laporan akhir konsisten dengan yang diminta dosen.

### 5.5 Tabel pinout PRD tidak mencerminkan pemasangan modul

Tabel §2.3 menggambarkan buzzer dan motor seolah-olah tersambung langsung: buzzer "Positif (+) → GPIO18, Negatif (−) → GND", motor "IN/Sinyal → GPIO2, VCC & GND → VIN (5V) & GND". Kenyataannya keduanya adalah **modul 3-pin** dengan kaki bertanda VCC/GND/S (atau IN). Untuk motor, PRD §2.2 memang sudah menyebut opsi "modul driver", jadi isinya konsisten meski tabelnya tidak. Untuk buzzer, tidak ada satu pun bagian PRD yang menyebut driver atau modul.

**Dampak:** ini jenis ketidakcocokan yang mudah terlihat saat penguji membandingkan tabel di laporan dengan benda fisik di meja. Perbarui tabel §2.3 agar mencantumkan tiga kaki per modul (VCC → 5 V, GND → GND, I-O/IN → GPIO), dan tambahkan satu kalimat di §2.2 bahwa **kedua** aktuator memakai modul yang sudah ber-driver — sertakan alasannya (motor 60–90 mA dan buzzer 20–30 mA melebihi batas aman pin GPIO). Cantumkan juga polaritasnya: buzzer active-LOW, motor active-HIGH.

### 5.6 Kata "PWM" di dokumen vs pemakaian sebenarnya (bukan cacat)

PRD §2.3 mencantumkan tipe sinyal motor sebagai "Output Digital / PWM" dan §4.1 menyebut "Sinyal digital/PWM penggerak buzzer dan vibration motor DC dengan pola modulasi spesifik". Modul motor memang **mendukung** PWM (bisa diatur kekuatan getarnya via `analogWrite()`), dan firmware menggerakkannya secara digital on/off dengan pola pulsing (500/150/750 ms).

**Penilaian saya: ini bukan bug.** Pola pulsing yang ada sudah merupakan "modulasi spesifik per status pelanggaran" seperti yang dijelaskan §4.5, dan §4.5 sendiri konsisten dengan kode. Yang perlu kamu sadari hanya bahwa frasa "PWM" di §2.3/§4.1 bisa dibaca penguji sebagai klaim bahwa kekuatan getar diatur secara proporsional — padahal tidak. Jika ditanya, jawab bahwa modulnya PWM-capable tetapi firmware memakai pola pulsing digital; itu jawaban yang akurat.

**Apakah perlu diimplementasikan? Tidak, untuk sekarang.** Membedakan pola lewat *durasi* sudah cukup untuk membedakan jenis peringatan, dan menambah PWM berarti menambah variabel baru (intensitas) yang harus didefinisikan per state. Ini memperbaiki sesuatu yang tidak rusak. Kalau nanti ingin menambah dimensi "tingkat urgensi" — yang justru akan menyambungkan kembali klaim *fuzzy* di §5.1 — barulah PWM punya alasan kuat.

---

## 6. Urutan Perbaikan yang Disarankan

1. **C0** — rapikan struktur folder sketch agar firmware bisa dikompilasi. (Prasyarat untuk semua pengujian.)
2. **C1 + C2** — perbaiki debounce: panggil `fsm.update()` hanya saat sampel baru, dan reset counter di setiap entry state.
3. **C3** — satukan logika C++ dan Python, atau hentikan klaim bahwa unit test memverifikasi firmware.
4. **H3** — tambahkan validasi rentang/`NaN` pada berat.
5. **H1b** — balik polaritas buzzer (modul active-LOW). Ini perbaikan satu baris yang memulihkan seluruh fungsi alarm; kerjakan sebelum demo.
6. **H2** — pindahkan sinyal motor dari GPIO2 ke pin non-strapping.
6. **M1, M8** — samakan `BASE_INTERVAL_MS` dan faktor kalibrasi dengan dokumen.
7. **§5** — selaraskan klaim akademis (fuzzy, ESP8266, angka derau) dan tabel pinout dengan kenyataan.
8. **§4** — bersihkan kode mati dan duplikasi.

---

## Lampiran — Cara Reproduksi Bukti

Harness C++ yang dipakai untuk membuktikan C1, C2, dan C3 dapat dibangun ulang dengan menyalin `fsm.h` dan `config.h` ke sebuah folder, menambahkan stub `Arduino.h` minimal (`stdint.h`, `stddef.h`, `math.h`, makro `isnan`), lalu mengompilasi:

```bash
g++ -std=c++17 -Wall -I<stub> -I<project> main.cpp -o harness && ./harness
```

Probe yang dijalankan: (A) *replay* urutan `test_simulation.py` ke FSM C++, (B) hitung sampel nyata hingga stabil, (C) `stabilizeCount` bocor antar state, (D) ambang 145 g vs 155 g, (E) jalur `ALERT_REFILL → LIFTED`, (F) ambang refill 30 g vs 20 g, (G) rollover `millis()`, (H) sepuluh `update()` pada milidetik identik, (I) *false positive* anti-cheat pada sentuhan 1 ms, (J) perbandingan konstanta antar berkas.

`test_simulation.py` dijalankan langsung dengan Python 3.10 dan melaporkan 8/8 PASS — yang justru menjadi bukti temuan C3, karena lulusnya test tersebut tidak berkorelasi dengan kebenaran `fsm.h`.
