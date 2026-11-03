# Panduan Logo

Berkas di folder ini dipakai untuk keperluan branding: laporan, sampul, slide,
kop surat, dan kemasan. Logo web dan ikon aplikasi tetap di
`web/icon.svg` dan `app/android/app/src/main/res/`, karena keduanya harus
memenuhi aturan sistem (maskable, adaptive icon, satu warna).

## Tanda

| Berkas | Latar | Pakai untuk |
|---|---|---|
| `logo-mark.svg` / `.png` | terang | dokumen berlatar putih |
| `logo-mark-dark.svg` / `.png` | gelap | slide, sampul, layar |

Tanda bisa dipakai sendiri tanpa nama produk bila nama sudah muncul di
sekitarnya, misalnya kepala laporan atau favicon cetak.

## Kuncian (tanda + nama)

| Berkas | Bentuk | Pakai untuk |
|---|---|---|
| `logo-horizontal-light.svg` / `.png` | tanda kiri, nama kanan | kop surat, header dokumen |
| `logo-horizontal-dark.svg` / `.png` | tanda kiri, nama kanan | slide gelap |
| `logo-vertical-light.svg` / `.png` | tanda atas, nama bawah | sampul laporan, kaos, stiker |
| `logo-vertical-dark.svg` / `.png` | tanda atas, nama bawah | sampul gelap |

Setiap berkas tersedia sebagai SVG (tajam di ukuran apa pun) dan PNG (siap
tempel di Word atau PowerPoint). PNG diekspor 2x dari ukuran aslinya.

## Warna

| Nama | Nilai | Dipakai untuk |
|---|---|---|
| Tinta | `#0C1F27` | latar gelap, teks di latar terang |
| Panel | `#132B35` | muka tatakan |
| Tatakan (gelap) | `#071219` | tebal tatakan |
| Cyan | `#44C8E6` | tepi tatakan, air |
| Cyan terang | `#7FE3F4` | permukaan air |
| Pucat | `#E2F1F3` | garis gelas, teks di latar gelap |

## Aturan

1. Jangan mengubah proporsi tanda. Kalau perlu ukuran lain, ubah lebar/tinggi
   sekaligus, jangan salah satu.
2. Jangan menambahkan efek. Tidak ada gradien, bayangan jatuh, atau garis luar.
   Logo harus tetap utuh saat dicetak satu warna.
3. Ruang kosong di sekeliling logo minimal setinggi mulut gelas (sekitar 6%
   lebar tanda).
4. Jangan meletakkan logo di atas foto tanpa bidang latar. Kalau terpaksa,
   pakai versi gelap di atas foto gelap, atau beri bidang tinta penuh.
5. Nama produk ditulis "Smart Hydration Coaster", bukan kapital semua, bukan
   "SHC".

## Mengubah logo

Semua berkas SVG dibangun dari satu skrip, jadi bentuk tanda dan huruf nama
tidak bisa berbeda antarberkas.

```
python brand/tools/build-brand.py
```

Skrip itu menulis enam SVG di `brand/` dan `web/icon.svg`. Ikon Android
(`ic_launcher_foreground.xml`) memakai bentuk yang sama dan diperbarui manual.

Untuk memperbarui PNG, jalankan `python brand/tools/export-png.py`. Skrip itu
tidak mengekspor sendiri: ia menghitung ukuran target dan memeriksa berkas yang
sudah ada di disk. Ekspor dijalankan lewat browser dengan viewport 2,4x viewBox
(tangkapan browser menambah 1,25x, jadi hasilnya 3x). Ukuran akhir yang benar:
tanda 1536x1536, kuncian horizontal 4183x960, kuncian vertikal 2649x1380.

Semua ukuran itu 300 DPI: kuncian horizontal 4183 px = 354 mm, cukup untuk
sampul A4 (210 mm) dengan margin.

Font nama produk adalah Space Grotesk Bold dari `app/assets/fonts/`. Nama
diubah menjadi bentuk (path), bukan teks, supaya berkas logo tampil sama di
komputer yang tidak memasang font tersebut.
