# Audit Geometri 3D — HydroCoaster Sasis 28 mm

## Ringkas

Sasis 22 mm dan seluruh temuan audit sebelumnya sudah tidak berlaku. Sasis sekarang 28 mm dengan interior bersih 23.3 mm, dan tujuh temuan lama sudah tertutup. Yang tersisa adalah lima hal yang tidak bisa diselesaikan oleh geometri saja: diameter can buzzer, cara motor menempel di tutup, header male motor wajib dilepas, jarak HX711 ke batang, dan celah buzzer ke header kanan ESP32.

## Status temuan audit sebelumnya

| No | Temuan lama | Status | Angka sekarang |
|---|---|---|---|
| 1 | Kisi suara tutup tidak sejajar can buzzer | Tertutup | Satu koordinat sumber: can dan kisi sama-sama di (x 16.51, y 69.73) |
| 2 | DHT11 menembus piringan akrilik bawah | Tertutup | DHT duduk di atas piringan (z 6.5), x -31..-17, y -10..22, radius terjauh 42.1 < 50 |
| 3 | Piringan atas mengambang 3.8 mm | Tertutup | Rantai kontak tanpa celah: 3.5 -> 6.5 -> 8.5 -> 21.2 |
| 4 | Kabel DHT/HX711 menembus piringan | Tertutup | Kedua modul duduk di luar batang; kabel lewat terowongan septum y 52..56 |
| 5 | Ventilasi DHT salah tempat | Tertutup | Wadah depan terbuka penuh ke atas; tutup hanya menutupi kompartemen belakang (y 54..132) |
| 6 | PCB buzzer menempel header HX711 | Tertutup | Header HX711 pindah ke x 42.25..44.79, jauh di wadah depan |
| 7 | SCAD dan HTML tidak konsisten | Tertutup | Grid, ESP32, buzzer, DHT11, HX711, motor, dan load cell memakai angka yang sama di kedua file |

## Kondisi geometri sekarang

**Cara pemasangan modul.** Semua modul (buzzer MH-FMD, DHT11, motor V919) punya pin yang keluar mendatar dari tepi PCB, terlihat di foto `WhatsApp Image 2026-10-17 at 14.51.*`. Tidak ada modul yang bisa disolder tegak ke perfboard. Model sekarang memakai tiga hal: modul ditempel datar dengan tape 0.5 mm, titik solder 3 atau 4 pin di baris grid papan, dan kabel yang **disolder ke papan di satu ujung, memakai konektor female di ujung modul**. Dengan cara ini sensor tetap bisa dicabut sementara sambungan ke papan tidak goyang. Motor getar memakai konektor yang sama; header male 1x3-nya dilepas karena rumah dupont 2.5 mm dari bidang pin (y 25.0) akan menembus tutup bawah di 25.8, jadi kabel disolder langsung ke pad modul lalu konektor dipasang di ujung kabel itu.

**Bukaan USB mengikuti ESP32.** Port duduk di x -8.83..-1.33 (selubung 7.5 mm di pusat x -5.08). Bukaan sasis 15 mm di x -12.58..2.42, jadi kedua sisi port punya 3.75 mm sisa. Sebelum revisi ini, model HTML memusatkan celah dinding di x 0 sehingga dinding menutup 1.33 mm port. Potongan SCAD juga diperbaiki: badan kapsul berakhir di y 138 (sudut belakang r 8 di y 130), sedangkan potongan lama berhenti di 137.4 dan menyisakan kulit 0.6 mm. Lubang sekarang dipotong sampai y 145.4 dan menembus dinding luar.

**Sambungan dua part di y=56.** Part depan berhenti di 56 dan membawa kerah 3.5 mm (y 55..61) yang membungkus hidung rear yang di-inset 3.8 mm; clearance radial dan aksial 0.3 mm. Dua baut M3x8 horizontal di x ±47, y 58.5, z 14: clearance Ø3,2 menembus kerah, pilot Ø2,5 di rear berhenti di x 34 (sisa 7 mm ke dinding rongga). Band 5 mm memberi margin 0.9 mm dari lubang ke kedua ujung kerah. Volume front+rear 166.448,9 mm³, −0,18% dari monolit.

**Tumpukan piringan** (satu rantai, tidak ada angka bebas):

    lantai depan 3.5 + akrilik 3.0 + spacer 2.0 + batang 12.7 = piringan atas 21.2
    puncak piringan 24.2, bibir depan 23.2, tonjolan 1.0 mm

Batang 80 mm: ujung depan y -40, ujung belakang y +40. Sudut terjauh radius 40.5 mm di rongga depan r 53. Ujung belakang 40 < septum 56, jadi batang tidak menembus dinding sekat.

**Tumpukan vertikal kompartemen belakang:**

    lantai 2.5 + riser 1.2 + papan 1.6 + header 8.5 + PCB ESP32 1.6 + shield RF 2.6 = 18.0
    tutup mulai 25.8, sisa bersih di atas shield 7.8 mm

**Papan dan modul:**

| Objek | x | y | Ketinggian |
|---|---|---|---|
| Perfboard 50.8 x 70 | -25.4..25.4 | 58..128 | 3.7..5.3 |
| ESP32 (25.4 x 48.26) | -17.78..7.62 | 77.76..126.02 | 13.8..15.4 |
| Buzzer 13 x 32 | 10.01..23.01 | 59.73..91.73 | PCB 5.8..7.4, can sampai 17.4 |
| Motor 23 x 21 (bawah tutup) | -16.58..6.42 | 89.5..110.5 | PCB 24.2..25.8, can turun ke 21.2 |
| HX711 34.5 x 21 | 7.75..42.25 | -4.5..16.5 | 6.5..8.1 |
| DHT11 14 x 32 (diputar) | -31..-17 | -10..22 | 6.5..13.6 |

**Grid perfboard** (dipakai bersama oleh SCAD dan HTML):

    kolom  x = -21.59 + 2.54k, k = 0..17   (margin 3.81 mm ke tepi)
    baris  y = 63.79 + 2.54k,  k = 0..23   (margin 5.79 mm ke tepi depan)

Semua pin modul jatuh di grid: ESP32 di x -16.51 dan 6.35 dengan baris y 84.11..119.67; buzzer di x 16.51 dan baris y 91.73. Empat titik solder juga jatuh di grid: buzzer (16.51, 104.43), DHT11 (-3.81, 63.79), HX711 (2.54, 71.41, 4 pin), motor (21.59, 96.81).

## Temuan terbuka

**1. Diameter can buzzer masih estimasi.** Lembar spesifikasi hanya menyebut modul 32 x 13 x 10 mm. Diameter 12.0 mm di model diturunkan dari foto modul, bukan dari angka penjual. Kisi suara 3x3 (rentang 3.6 mm dari pusat) masih aman untuk can 10..14 mm, tetapi klaim "can Ø12" tidak punya bukti tertulis. Ukur dengan jangka sorong sebelum mencetak tutup.

**2. Motor menempel di tutup tanpa fitur mekanikal.** PCB motor berada di z 24.2..25.8, tepat di bawah tutup, tetapi model tidak menggambar baut, boss, maupun perekat. Jarak bebas vertikal 3.2 mm ke shield RF dan 5.8 mm ke PCB ESP32 sudah benar; cara menempelnya belum. Opsi: dua boss M2 di tutup, atau double tape 3M seperti rencana lama.

**3. Header male motor harus dilepas.** Pin male 1x3 berukuran 11.5 mm. Dari bawah PCB modul (24.2) pin akan mencapai 12.7 mm, menembus shield RF yang puncaknya 18.0 mm. Kabel harus disolder langsung ke pad. Ini keputusan desain, bukan cacat, tetapi wajib ditulis di panduan rakit.

**4. Jarak HX711 ke batang load cell 1.40 mm.** Tepi kiri PCB di x 7.75, batang berakhir di x 6.35. Modul 34.5 mm tidak bisa lebih jauh ke kanan tanpa keluar dari wadah depan. Sudut terjauh modul (termasuk header) berada di radius 49.7 mm, hanya 0.3 mm dari tepi piringan akrilik r 50. Keduanya lolos pemeriksaan, tetapi tidak ada ruang untuk kesalahan potong akrilik.

**5. Celah buzzer ke header kanan ESP32 hanya 1.12 mm.** Tepi buzzer x 10.01, tepi header kanan ESP32 x 8.89. Modul sekarang ditempel datar dengan tape, jadi posisi ditentukan perekat, bukan solder. Pemasangan tape harus lurus; kalau bergeser 1 mm ke kiri, PCB modul mulai menyenggol area header ESP32.

## Verifikasi

    python tools/cad_check/verify_stackup.py        # 59/59 lulus

Tiga part: front 1324 facet, rear 1752, lid 3392, assembly 7708 facet. Export OpenSCAD selesai untuk empat STL (`front.stl`, `rear.stl`, `lid.stl`, `coaster_casing.stl`). OpenSCAD memberi `EXPORT-WARNING: Exported object may not be a valid 2-manifold and may need repair` pada assembly `all`, tetapi tiga part cetak lolos export bersih dan verifier geometri tetap 59/59.

Pemeriksaan yang ditambahkan pada revisi ini: pin ESP32 dan buzzer harus jatuh di grid lubang, motor harus menempel di bawah tutup dan tidak menabrak shield RF, batang 80 mm harus muat di wadah depan, bukaan USB harus mengikuti pusat ESP32, dan geometri seam (baut di dalam kerah, pilot buta, clearance 0.2..0.4 mm, ulir M3x8 cukup, tiap part muat bed 175 mm).
