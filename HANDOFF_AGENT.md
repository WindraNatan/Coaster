# LANJUTAN PROYEK: Smart Hydration Coaster

Berkas panduan untuk agent (atau orang) yang melanjutkan proyek ini. Ditulis 2026-10-09 setelah sesi kerja terakhir. Baca ini dulu sebelum menyentuh kode.

## 1. Apa proyeknya

Tatakan gelas pintar berbasis ESP32 yang memantau hidrasi: load cell HX711 mengukur berat gelas, DHT11 membaca suhu dan kelembaban ruangan, dan sebuah FSM tujuh state memutuskan kapan memberi alarm minum. Dipakai untuk dua mata kuliah sekaligus, RSK-352 (Sistem Kendali, bagian FSM dan kontroler adaptif) dan RSK-354 (IoT, bagian dashboard web dan telemetri).

Pemilik proyek mahasiswa S1 Rekayasa Sistem Komputer, Universitas Tanjungpura. Preferensi kerja yang perlu diketahui: meminta bahasa yang deskriptif, mau analisis yang jujur dan kritis, dan minta skill relevan dimuat tiap kali tanpa harus diminta ulang.

Perangkat keras: ESP32 DevKit V1, HX711 + load cell, DHT11. Buzzer aktif dan motor getar sudah tersedia lagi untuk pengujian; keduanya sempat tertunda karena komponen hilang. Karena itu LED onboard di GPIO2 dipakai sebagai indikator alert pengganti, dan ia harus tetap ada sebagai jejak visual saat menelusuri masalah aktuator.

## 2. Peta berkas

```
D:\Kuliah\Sistem Kendali\
  PRD_Smart_Hydration_Coaster.md     dokumen requirement + spesifikasi teknis, versi final
  CARA_UJI_HARDWARE.md               panduan uji perangkat nyata langkah demi langkah
  AUDIT_Smart_Hydration_Coaster.md   hasil audit lama, sebagian sudah usang (lihat §6)
  test_simulation.py                 port 1 Python FSM + kontroler adaptif, 15 skenario
  docs/pemodelan_sistem_kendali.md   pemodelan sistem kendali, masa draft
  SmartHydrationCoaster\
    SmartHydrationCoaster.ino        firmware utama
    config.h                         pin, ambang, konstanta waktu, faktor kalibrasi
    fsm.h                            mesin state 7 state, inti logika
    adaptive_controller.h            interval jadwal adaptif dari suhu dan kelembaban
    filter.h                         moving average, jendela 10 sampel
  tools\
    kalibrasi\kalibrasi.ino          kalibrasi faktor load cell, perintah serial '+', '-', 't', 'r', 'i'
    test_hardware\test_hardware.ino  uji buzzer, motor, DHT satu per satu
    test_loadcell\test_loadcell.ino  uji dan karakterisasi load cell, deteksi noise
    uji_fsm\Arduino.h                shim agar header firmware bisa dikompilasi di PC
    uji_fsm\uji_fsm.cpp              26 pemeriksaan paritas fsm.h + adaptive_controller.h
  web\index.html                     dashboard simulator FSM, 8 tombol skenario
  _arsip\                            draft lama, jangan dijadikan rujukan
```

## 3. Aturan terpenting: tiga port harus 1:1

Logika FSM hidup di tiga tempat sekaligus dan wajib tetap identik: `SmartHydrationCoaster/fsm.h` (C++), `test_simulation.py` (Python), dan `web/index.html` (kelas JS `CoasterFSM`). Nama propertinya beda antar port, dan itu disengaja: web memakai `baseline`, `totalDrank`, `isStable`, `setState`, `setInterval_`; Python memakai `baseline_weight`, `total_consumed_ml`, `is_stable`, `enter_state`, `target_interval_ms`; C++ memakai `baselineWeight`, `totalDrankGrams`, `enterState`, `monitorIntervalMs`.

Setiap ubahan logika di satu port wajib disalin ke dua port lain, lalu ketiganya dijalankan. Inilah cara menemukan beberapa bug laten terakhir. Kalau hanya satu port diubah, bedanya jadi bug dan sangat sulit dilacak kemudian.

Perintah verifikasi ketiga port:

```bash
# 1. Python
python3 test_simulation.py

# 2. C++, mengompilasi header firmware ASLI di PC
cd tools/uji_fsm
g++ -std=c++17 -Wall -Wextra -I. -I../../SmartHydrationCoaster -o uji_fsm uji_fsm.cpp
./uji_fsm

# 3. Web
# buka web/index.html di browser, tekan kedelapan tombol skenario
```

Catatan teknis yang mudah menjebak: `fsm.h` menyertakan `<Arduino.h>` dengan tanda kurung sudut, sedangkan shim `Arduino.h` ada di folder `tools/uji_fsm`. Itu sebabnya flag `-I.` wajib ada; tanpa itu kompilasi gagal dengan pesan `Arduino.h: No such file or directory`. Shim itu hanya menyediakan `<stdint.h>` dan `isnan()`, tidak ada API Arduino lain.

Port C++ ini penjaga paritas yang paling dekat dengan kode yang benar-benar di-flash ke ESP32, jadi jangan dibuang walaupun Python sudah hijau.

## 4. Yang baru selesai: Fix C4, gerbang stabilitas pada keputusan selisih berat

Ini pekerjaan terakhir dan penyebab utama masalah yang muncul di perangkat nyata. Pada uji hardware, `ALERT_CHEAT` tidak pernah tercapai. Log serial menunjukkan baris `[DBG] -> ALERT_EMPTY_CUP` berulang dengan `delta=-46.x g | vonis=MINUM` dan penghitung minum melonjak dari 288,1 ml ke 482,7 ml. Penyebabnya bukan kesalahan pemakai, tapi bug di FSM.

Mengangkat gelas bukan satu langkah, melainkan turun bertahap sekitar 46 g per sampel pada laju 10 Hz. Setiap sampel turun itu lewat ambang minum 20 g, jadi tiap sampel dicatat sebagai satu kali minum. Akibatnya berlapis: 4 sampai 6 minum palsu per pengangkatan, timer minum terus ter-reset sehingga `ALERT_DRINK` tidak pernah muncul, baseline rusak mengikuti berat terangkat, dan yang paling fatal, ketika gelas ditaruh kembali selisihnya selalu terbaca sebagai minum sah sehingga cabang `ALERT_CHEAT` jadi mustahil dicapai.

Perbaikannya: setiap keputusan berbasis selisih berat menunggu berat baru stabil lebih dulu. Berlaku untuk cabang minum dan isi ulang di `STATE_TIMING`, `STATE_ALERT_DRINK`, `STATE_ALERT_CHEAT`, dan pemulihan dari `STATE_ALERT_REFILL`. Gerbangnya memakai `isStable()`, yaitu berat bertahan dalam ±3 g selama 1.500 ms.

Yang perlu dicatat dari proses ini: sembilan skenario uji lama semuanya mengangkat gelas dalam satu langkah, sehingga cacat ini lolos dari seluruh rangkaian uji tanpa terdeteksi. Dua skenario regresi baru ditambahkan, yang ke-14 mengangkat gelas bertahap dan menuntut 0 minum palsu dengan baseline utuh, yang ke-15 melanjutkan ke `ALERT_CHEAT`. Keduanya sengaja ditambahkan karena membuktikan bahwa rangkaian uji yang "semuanya lulus" bisa buta terhadap bug tertentu. Kalau dikerjakan di masa depan, cek dulu apakah rangkaian ujimu benar-benar menggigit dengan sengaja merusak kodenya (misalnya dengan menghapus gerbangan) lalu memastikan tes gagal.

Status verifikasi 2026-10-08: Python 15/15, C++ 26/26 dengan kompilasi bersih tanpa warning, dan kedelapan tombol skenario web sesuai harapan.

Cacat lama lain yang ikut ditemukan dan diperbaiki sesi itu, semuanya sudah ada sebelum Fix C4 dan bukan disebabkan olehnya:

Interval adaptif di web membaca `CFG.K_HUM_DRY` yang tidak pernah didefinisikan, sedangkan yang ada bernama `CFG.K_DRY`. Hasilnya `Math.round(base * 1.0 * undefined)` menjadi NaN, dan timer minum tidak pernah habis ketika kelembaban di bawah 40 persen.

Sembilan variabel simulator di web (`fsm`, `weight`, `simMs`, `demo`, `warp`, `sc`, `lastFull`, `roomT`, `roomHum`) dirujuk lebih 100 kali tapi tidak pernah dideklarasikan. Karena halaman memakai `'use strict'`, penugasan ke nama yang belum dideklarasikan langsung melempar `ReferenceError` dan seluruh halaman mati saat dimuat. Perbaikan berupa blok `let` yang dimasukkan sebelum bagian UI. `fsm` harus `let`, bukan `const`, karena `runScenario` menugaskannya ulang.

Jeda antar langkah skenario web semula 200 ms, lebih kecil dari satu tick pada warp ×10 yang 1000 ms, sehingga dua langkah jatuh di tick yang sama dan FSM tidak pernah melihat keadaan antara seperti gelas terangkat. Semua jeda langkah skenario sekarang 1.500 ms atau lebih, dan tiap skenario mengisi gelasnya sendiri karena FSM di-reset setiap tombol ditekan.

`DEFAULT_CALIBRATION_FACTOR` sebelumnya didefinisikan dua kali di `config.h` (451,2 dan 290,0f) dan sempat disamakan ke 290,0f, tetapi hasil kalibrasi fisik beban 500 g pada load cell 5 kg membuktikan faktor yang benar adalah `450.7f` (nilai 290,0f membuat beban 500 g terbaca > 700 g). Sekarang `450.7f` dikunci seragam di `config.h`, `kalibrasi.ino`, dan `test_loadcell.ino`.

`adaptive_controller.h` menulis ulang angka faktor suhu dan kelembaban secara hardcode sementara `config.h` mendefinisikan nilai yang sama dengan komentar "harus identik". Definenya jadi mati, dan guard include-nya masih bernama `FUZZY_CONTROLLER_H` sisa dari rename yang tidak pernah tuntas. Sekarang fungsinya membaca konstanta dari `config.h`, dan guard include diperbaiki jadi `ADAPTIVE_CONTROLLER_H`.

## 5. SELESAI: masalah buzzer menyala terus (akar masalah fisik)

Buzzer tadinya berbunyi terus menerus baik saat `GPIO18` diberi `HIGH` maupun `LOW`. Penyebabnya bukan di kode dan bukan polaritas terbalik, melainkan **kabel `VCC` modul buzzer (transistor PNP S8550, active-LOW) terhubung ke `5V` (`VIN`)** mengikuti tabel lama di `PRD_Smart_Hydration_Coaster.md` dan `CARA_UJI_HARDWARE.md`.

Karena logika `HIGH` ESP32 hanya `3,3 V`, mencatu emitor transistor PNP dengan `5,0 V` membuat tegangan emitor-basis tetap $V_{EB} = 5{,}0\text{ V} - 3{,}3\text{ V} = 1{,}7\text{ V} > 0{,}7\text{ V}$ saat pin `HIGH`. Akibatnya transistor PNP tidak pernah bisa *cut-off* baik pada saat `HIGH` (`3,3 V`) maupun `LOW` (`0 V`).

Solusi yang sudah terverifikasi:
1. **`VCC` modul buzzer wajib dihubungkan ke `3V3` ESP32** (bukan `5V`), sehingga saat `GPIO18` bernilai `HIGH` (`3,3 V`), $V_{EB} = 0\text{ V}$ dan buzzer mati total saat *idle*. Modul motor getar (transistor NPN S8050, active-HIGH) tetap aman di `5V` (`VIN`) karena emitornya bereferensi ke `GND`.
2. `BUZZER_ACTIVE_LOW = 1` dan `MOTOR_ACTIVE_LOW = 0` di `config.h` sudah benar.
3. `tools/test_hardware/test_hardware.ino` sudah diselaraskan: `PIN_MOTOR` diperbaiki dari `2` ke `17`, memakai `writeActuator()`, dan memiliki perintah `'5'` untuk uji polaritas `HIGH`/`LOW` 2 detik.

Jangan menulis `digitalWrite` langsung untuk aktuator di kode baru; selalu gunakan `writeActuator()` termasuk untuk `PIN_LED_ALERT` (`GPIO2`, active-HIGH).

## 6. BERKAS YANG HARUS DIBACA DULU, DAN YANG SUDAH BASI

`PRD_Smart_Hydration_Coaster.md` sudah diperbarui dan bisa dipercaya. Bagian penting: §4.3 berjudul "Kendali Adaptif Berbasis Aturan (bukan Fuzzy)" dan sudah memperbarui nama `fuzzy_controller.h` menjadi `adaptive_controller.h` serta menghapus klaim FLC Sugeno, jadi klaim di dokumen utama sudah jujur; §4.4 menjelaskan FSM tujuh state beserta aturan bahwa setiap keputusan selisih berat wajib menunggu berat stabil, termasuk penjelasan fisiknya; §9 memuat tabel kriteria penerimaan beserta skenario regresi 10 dan catatan bahwa tiga port harus lulus skenario yang sama; §11 mencatat perubahan penting termasuk entri 2026-10-08 untuk Fix C4.

`CARA_UJI_HARDWARE.md` juga sudah diperbarui. Langkah anti-cheat diperbaiki karena versi lama menggambarkan jalur yang mustahil: uji cheat yang benar angkat gelas sampai benar-benar lepas dari tatakan (berat jatuh di bawah 25 g menuju `LIFTED`), lalu taruh kembali tanpa minum. Ada juga bagian baru yang menjelaskan cara membaca baris `[DBG]` dan kolom `vonis`-nya yang bernilai `MINUM`, `REFILL`, `CHEAT`, atau `-`.

`AUDIT_Smart_Hydration_Coaster.md` sudah usang, dan ini penting agar tidak salah paham. Temuan yang sudah beres dan sebaiknya dianggap tutup: M1 interval dasar 30 menit (sudah 1.800.000 ms), M4 jalur alarm lupa gelas (sudah ada jalur pemulihan satu pintu di `STATE_ALERT_REFILL`), M8 konflik faktor kalibrasi (sudah 450,7f di semua berkas). M2 `demoMode = true` sebagai default firmware sengaja dibiarkan karena mode demo 15 detik memang yang dipakai saat presentasi kelas, tapi kalau pakai sehari-hari lebih enak nilai itu diubah lewat perintah serial `d`.

`docs/pemodelan_sistem_kendali.md` masih berisi konten masa draft: menyebut ESP8266 padahal perangkatnya ESP32, mendeskripsikan kontroler Fuzzy Sugeno padahal aplikasinya sudah jadi berbasis aturan bernama `adaptive_controller.h`, dan mengklaim reduksi derau dari ±4,5 g menjadi kurang dari ±0,5 g tanpa data pengukuran yang mendukung. Klaim angka itu jangan dipakai sebelum `run_noise_test()` benar-benar dijalankan dan hasilnya dicatat.

`web/index_v1_backup.html` dan isi `_arsip/` tinggalkan saja, jangan dijadikan acuan.

## 7. Catatan perilaku yang perlu diketahui sebelum menyimpulkan apa pun

Baseline tidak diperbarui ketika terjadi cheat (`STATE_ALERT_CHEAT`). Itu disengaja dan melindungi pengukuran berikutnya agar curang kecil tidak menggerus angka acuan. Karena selisih minum selalu dihitung terhadap `baselineWeight` terakhir yang tercatat, jika user mencoba cheat (misal minum 8 g dari baseline 380 g sehingga berat menjadi 372 g) lalu setelah itu lanjut minum sah (misal minum 180 g lagi sehingga berat menjadi 192 g), maka saat minum sah itu dievaluasi, selisih yang dicatat adalah `380 - 192 = 188` ml (8 g saat cheat ikut terakumulasi penuh).

Penurunan kurang dari 20 g baru benar-benar hilang dari `totalDrankGrams` jika setelah berkurang < 20 g user langsung melakukan **isi ulang (`refill` >= 30 g)**, karena cabang refill langsung menimpa `baselineWeight` dengan berat baru tanpa mencatat penurunan kecil sebelumnya. Efek samping lain dari ditahannya `baselineWeight` saat cheat: mengangkat dan menaruh kembali gelas pada berat yang sama (misal 372 g) berulang kali tanpa minum tambahan akan terhitung sebagai cheat baru setiap kali.

## 8. Hal-hal yang perlu dikerjakan berikutnya

Hapus blok `[DBG]` di `SmartHydrationCoaster.ino` sekitar baris 195 sampai 213 sebelum proyek dikumpulkan. Blok itu berguna saat pengujian tapi tidak layak ada di kode hasil akhir.

Tulis ulang atau perbarui `docs/pemodelan_sistem_kendali.md` agar menyebut ESP32, menjelaskan kontroler berbasis aturan alih-alih Fuzzy, dan membuang atau menyediakan data nyata untuk klaim reduksi derau. Sebaiknya tunggu sampai uji perangkat nyata selesai supaya angkanya bisa diisi dengan hasil terukur.

Sisa pekerjaan sesi uji perangkat nyata: verifikasi telemetri dashboard web dan bagian IoT untuk RSK-354 masih jauh di belakang bagian Sistem Kendali. Sketch sudah belum pernah dikompilasi maupun di-flash dari sisi ini karena tidak ada toolchain Arduino di lingkungan kerja agent. Semua berkas `.ino` wajib dikompilasi dan diunggah dari sisi pemilik proyek; jangan anggap firmware terverifikasi hanya karena harness C++ hijau, karena harness itu hanya menguji `fsm.h`, `config.h`, dan `adaptive_controller.h`, bukan berkas `.ino` beserta library HX711 dan DHT.

Pertahankan tiga port tetap sinkron setiap kali logika FSM disentuh, dan pertahankan cara kerja ini: setiap fix diberi uji yang benar-benar bisa gagal, bukan hanya tes yang sudah pasti lulus.
