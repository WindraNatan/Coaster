# Daftar Tangkapan Layar untuk Laporan

## Sudah selesai (folder `bukti-screenshot/`)

| No | Berkas | Isi |
|---|---|---|
| 01 | `01-web-simulator-desktop.png` | Web, mode Simulator, layar lebar penuh |
| 02 | `02-web-simulator-hp.png` | Web, mode Simulator, ukuran ponsel |
| 03 | `03-web-halaman-akun.png` | Halaman Akun: masuk dan klaim alat |
| 04 | `04-web-alert-minum.png` | Web, keadaan ALERT DRINK |
| 05 | `05-web-mode-cloud.png` | Web, mode Cloud Firebase |

## Perlu Anda ambil dari ponsel

Simpan di `bukti-screenshot/app-anda-sendiri/`.

| No | Nama berkas | Apa yang harus terlihat |
|---|---|---|
| 08 | `08-app-pengingat.png` | Kartu Pengingat Minum saat aktif: saklar, nama audio, tombol |
| 09 | `09-app-akun-klaim.png` | Layar masuk atau layar klaim kode alat |
| 10 | `10-app-notifikasi.png` | Permintaan izin notifikasi, atau notifikasi "Waktunya minum" di layar kunci |

Nomor 06 dan 07 sudah ada: dibuat dari widget test dengan MockClient, karena
dashboard butuh sesi Firebase dan tidak ada kredensial uji di repo. Isinya
tampilan asli aplikasi dengan data tiruan, bukan foto perangkat.

Langkah untuk nomor 08:

1. Buka aplikasi.
2. Gulir ke kartu Pengingat Minum.
3. Nyalakan saklar.
4. Jawab izinkan saat Android bertanya soal notifikasi.
5. Tekan Pilih audio bila nama audio ingin terlihat.
6. Tangkap layar.

Langkah untuk nomor 10:

1. Kunci ponsel.
2. Tunggu alarm.
3. Tangkap layar kunci saat notifikasi tampil.

## Membuat zip

Jalankan dari akar proyek:

```
powershell Compress-Archive -Path bukti-screenshot -DestinationPath bukti-screenshot.zip -Force
```

Atau klik kanan folder `bukti-screenshot`, lalu **Send to › Compressed (zipped) folder**.

## Batas ukuran

Formulir pengumpulan membatasi ZIP hingga **10 MB**. Setelah empat gambar
aplikasi dimasukkan, periksa ukurannya:

```
powershell "(Get-Item bukti-screenshot.zip).Length / 1MB"
```

Bila lebih dari 10 MB, kecilkan gambar terlebih dahulu:

```
powershell Compress-Archive -Path bukti-screenshot -DestinationPath bukti-screenshot.zip -Force
```

Gambar PNG dari ponsel biasanya 2-4 MB per berkas, jadi empat gambar bisa
mendekati batas. Cara mengecilkan: buka gambar di Photos, pilih **Resize**,
simpan dengan lebar 1080 px.
