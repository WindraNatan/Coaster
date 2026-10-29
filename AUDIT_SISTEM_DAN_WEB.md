# Audit Logika Sistem & Web: Smart Hydration Coaster

Tanggal audit: 2026-10-21
Objek: `SmartHydrationCoaster/` (firmware), `test_simulation.py`, `tools/uji_fsm/`, `web/index.html`, `web/casing_3d.html`, dokumen proyek.
Metode: baca seluruh sumber, jalankan empat suite verifikasi, replay paritas JS di Node, render kedua halaman di Chromium headless pada 390 px dan 1400 px, lalu uji kebocoran logika dengan skenario serangan baru.

## Verdict

Paritas tiga port lulus penuh dan itu bagian terkuat proyek ini: 21/21 skenario Python, 52/52 pemeriksaan C++, 30 asersi JS di `web/fsm.test.js` (4 skenario regresi K1/K3, bernomor 18-21). Geometri CAD 59/59 lulus. FSM tidak punya cacat regresi.

> Angka di dokumen ini adalah rekaman saat audit ditulis. Per 2026-10-25: CAD **60/60** (satu pemeriksaan arah pin motor ditambahkan), dan `web/fsm.test.js` tetap 30 asersi.

Yang tersisa adalah satu lubang logika serius yang belum diuji suite mana pun: alarm dan statistik bisa dikelabui dengan menekan gelas, tanpa minum dan tanpa mengangkatnya. Selain itu ada satu bug kehilangan data di tombol Reset Harian, satu label CSS yang membuat seluruh log alarm kehilangan warna, satu jalur putus USB yang tidak menutup port, dan drift dokumentasi yang cukup banyak (pin DHT, nama state, jumlah tes, klaim library dan NTP).

Dari sisi AI slop: `web/index.html` tergolong bersih. `web/casing_3d.html` masih membawa pola slop yang jelas dan rusak total di layar ponsel.

## 1. Temuan kritis

Tiga temuan ini berdampak langsung pada data pengukuran dan klaim yang tertulis di dokumen.

### K1. Tekan-lepas gelas memalsukan minum dan mematikan alarm

Severity: tinggi, mematahkan klaim anti-cheat.

FSM menerima kenaikan berat stabil 30 g atau lebih sebagai isi ulang tanpa menanyakan apakah gelas pernah diangkat. Baseline naik ke berat baru, lalu jari dilepas dan berat turun 35 g. Penurunan itu melewati ambang minum dan tercatat sebagai minum sah. Load cell memang tidak bisa membedakan air yang dituang dari jari yang menekan, tetapi FSM sekarang ikut tertipu tanpa perlawanan.

```
f = CoasterFSM(empty_cup_weight=130, target_interval_ms=15000)
settle(f, 380, 1000)      # TIMING, baseline 380
f.update(380, 30000)      # ALERT_DRINK aktif
settle(f, 415, 30000)     # tekan gelas +35 g selama 1,5 detik
settle(f, 380, 33000)     # lepas tekanan
```

Hasil: alarm mati, **refill=1, drink=1, total=35 ml, cheat=0**. Lima siklus menghasilkan 175 ml palsu, 5 minum, 5 isi ulang, 0 curang.

Mekanismenya di `fsm.h:107-135` dan `fsm.h:161-184`. Suite 21 skenario tidak menangkapnya karena semua kasus curang di suite berhenti di selisih di bawah 20 g. Penguji bisa mematahkan klaim anti-cheat dengan satu jari.

Ada tiga jalan keluar. Yang paling aman mengunci isi ulang agar hanya sah setelah state LIFTED, dengan konsekuensi skenario 8 PRD hilang. Alternatifnya heuristik pembalik: bila berat turun kembali ke baseline lama dalam beberapa detik, refill dibatalkan dan penurunan tidak dicatat. Pilihan terakhir mengakui ini batas fisik dan mencabut klaim anti-cheat yang berlaku umum.

### K2. Reset Harian menghapus riwayat hari itu

Severity: sedang-tinggi, kehilangan data.

Tombol menjalankan `resetStats()` lebih dulu, baru `saveTodayStatsToHistory()` (`web/index.html:768-775`). Fungsi kedua menulis angka nol ke entri hari ini dan menimpa catatan asli. Riwayat dari pagi sampai siang hilang tanpa jejak.

Urutannya bisa dibalik, atau entri hari ini dihapus dari riwayat bila maksud tombol ini memang mengosongkan catatan.

### K3. Kalibrasi gelas kosong memicu isi ulang palsu

Severity: sedang.

`setEmptyCupWeight()` menyetel baseline ke angka kalibrasi lalu memaksa state ke ALERT_REFILL (`fsm.h:44-55`). Bila gelas berisi masih di tatakan, transisi berikutnya melihat berat jauh di atas batas kosong dan mencatat refill yang tidak pernah terjadi.

```
settle(f, 380, 1000)          # TIMING
f.set_empty_cup_weight(130)   # user menekan Simpan Gelas
settle(f, 380, 3000)          # refill=1, tanpa isi ulang
```

Ini efek samping Fix Celah 2 yang belum ditutup. Perintah serial `c` tidak terkena karena memakai berat aktual, tetapi perintah `e` dan tombol Simpan Gelas di web sama-sama memicunya.

## 2. Temuan sedang

Empat temuan ini merusak umpan balik atau membuat halaman gagal dipakai di perangkat tertentu.

### M1. Seluruh log alarm kehilangan warna

Kelas warna dihitung dengan memotong nama state setelah garis bawah (`web/index.html:593`). `ALERT_DRINK` menjadi `ev-DRINK`, sementara CSS hanya mendefinisikan `.ev-ALERT_DRINK`, `.ev-ALERT_CHEAT`, dan `.ev-ALERT_REFILL` (`web/index.html:135-140`). Semua baris transisi alarm tampil abu-abu, dan baris isi ulang memakai kelas alarm minum yang tidak cocok dengan maksudnya.

Fungsi `evCls` cukup mengembalikan `'ev-' + st` untuk state berawalan ALERT.

### M2. Tombol Putuskan USB tidak menutup port

Tombol putus memanggil `close()` saat loop baca masih memegang lock reader (`web/index.html:790-799`). Spesifikasi Web Serial hanya menutup port setelah `reader.releaseLock()`, dan lock baru lepas setelah `reader.cancel()`. Error yang muncul ditelan `catch` kosong, port tetap terbuka, lalu percobaan koneksi berikutnya gagal tanpa pesan.

Urutan yang benar: beri tanda berhenti, `await reader.cancel()`, tunggu loop keluar, baru `close()`.

### M3. casing_3d.html rusak di layar ponsel

Halaman ini tidak punya satu pun `@media`. Pada lebar 390 px dokumen meluber sampai 562 px, tombol header terdorong keluar, dan tag anotasi 3D berakhir di koordinat negatif. `overflow:hidden` menyembunyikan scrollbar, jadi kontrol terpotong tanpa bisa dijangkau. Font 9 sampai 10.5 px dan target sentuh di bawah 44 px menambah masalah yang sama di layar sentuh.

Halaman peraga ini lebih aman dipakai dari laptop, atau ditandai desktop-only supaya tidak dibuka dari ponsel saat presentasi.

### M4. Dokumentasi menyimpang dari kode

Beberapa dokumen sudah tidak cocok dengan kode. Dua baris teratas paling berbahaya karena `CLAUDE.md` dibaca agent di setiap sesi.

| Lokasi | Klaim | Kenyataan |
|---|---|---|
| `CLAUDE.md:12` | DHT11 di GPIO15 | `config.h:12` GPIO19, `CARA_UJI_HARDWARE.md:11` GPIO19 |
| `CLAUDE.md:46` | FSM berisi `STATE_INIT` dan `STATE_ALERT_EMPTY_CUP` | `fsm.h:7-15` berisi `STATE_IDLE`, `STATE_STABLE`; `ALERT_EMPTY_CUP` hanya string turunan flag |
| `CLAUDE.md:35`, `HANDOFF_AGENT.md:127` | 34 pemeriksaan C++ | `uji_fsm.cpp` punya 52 `CHECK` |
| `HANDOFF_AGENT.md:20` | 15 skenario Python | `test_simulation.py` punya 21 |
| `CLAUDE.md:64`, `PRD:162` | Library Mobizt Firebase ESP Client | `cloud_sync.h` memakai `HTTPClient` dan `WiFiClientSecure` langsung |
| `CLAUDE.md:66` | NTP disinkronkan tiap 6 jam | tidak ada `configTime` atau kode NTP di firmware |
| `CLAUDE.md:65`, `PRD:167-172` | Heartbeat 10 s, poll 30 s, ESP32 menulis `/daily/` | heartbeat 5 s, poll 15 s, firmware tidak menulis `/daily/` |
| `PRD:170` | Browser realtime via SDK `onValue` WSS | web memakai REST polling 2.5 s |
| `PRD §8` | Casing PVC foam board 5 mm tiga lapis | sudah diganti sasis kapsul 28 mm |

Sisanya kosmetik, kecuali klaim cloud: firmware tidak menulis `/daily/`, tidak memakai Mobizt, dan tidak menyinkronkan NTP.

## 3. Kebersihan dan temuan ringan

Sisa kode mati: `CFG.BASE_INTERVAL` di `web/index.html:309` tidak pernah dipakai. Manifest juga mengunci orientasi potret padahal dashboard dua kolom lebih nyaman mendatar.

Perilaku yang perlu diketahui. `scale.tare(20)` berjalan saat boot (`SmartHydrationCoaster.ino:285`); bila gelas sudah di tatakan saat board dinyalakan, titik nol bergeser dan gelas tidak terdeteksi. Mode demo aktif secara default sehingga board baru memberi alarm tiap 15 detik sampai diubah lewat serial. `setInsecure()` mematikan validasi sertifikat TLS dan rules Firebase terbuka, wajar untuk praktikum tetapi bertentangan dengan klaim HTTPS tanpa catatan.

Kebersihan repo. `.gitignore` menutup `.pyc`, `*.exe`, dan `test_*.png`, tetapi 14 foto WhatsApp dan `Materi/` masih ter-track; 47 file berstatus kotor saat audit. Belum ada README untuk orang baru, dan `HANDOFF_AGENT.md` ditujukan untuk agent.

## 4. Penilaian AI slop

`web/index.html` lolos. Tidak ada em dash, statistik karangan, testimoni palsu, link mati, gradient dekoratif, atau glow. Palet lima warna seluruhnya membawa status FSM, bukan hiasan. Kontras teks terendah 5.72:1 dan lebar 390 px bebas overflow (`scrollWidth 390`). Empty state, error state, dan pesan status untuk USB maupun cloud sudah ada. Label huruf besar ber-tracking lebar sebenarnya pola yang sering jadi tell, tetapi di sini melayani identitas alat ukur dan konsisten dengan halaman 3D.

`web/casing_3d.html` belum lolos. Halaman ini tidak punya satu pun media query. Blur latar dipakai lima elemen, bayangan lima elemen, dan palet aktif memuat sepuluh warna. Badge kapsul dekoratif, emoji kaca pembesar, dan label 9 px melengkapi daftarnya. Dua puluh enam komentar banner `=====` yang mengulang isi blok yang ditandainya sudah dibersihkan pada 21 Oktober 2026. Tidak ada fokus keyboard maupun `aria`; seluruh interaksi menempel pada `onclick` di `div`. Sisi kuatnya, model 3D itu sendiri adalah konten nyata yang spesifik ke produk, bukan ilustrasi generik.

Komentar firmware di `fsm.h` dan `adaptive_controller.h` menjelaskan alasan dan riwayat bug, bukan mengulang kode. Itu standar yang benar dan sebaiknya dipertahankan.

## 5. Sisi pengguna

Saat demo, alur yang paling mungkin dicoba adalah menekan gelas untuk menguji tipuan. Itu justru eksploit K1, jadi tutup dulu atau jelaskan sebelum sidang. Tombol Reset Harian juga menghapus riwayat hari itu, bukan memulai hitungan baru.

Simpan Gelas mengambil berat apa pun yang ada di tatakan. Bila gelas berisi, volume harian meleset sebesar isi gelas; label sebaiknya menyebut gelas kosong dan menampilkan berat terukur sebelum menyimpan. Board juga harus dinyalakan saat tatakan kosong, karena tare boot menggeser titik nol bila sudah ada beban.

Web Serial memerlukan konteks aman. Membuka `index.html` lewat `file://` memblokir manifest dan notifikasi (terverifikasi di konsol), jadi jalankan lewat server lokal sesuai `CARA_UJI_HARDWARE.md:57`. Halaman 3D jangan dibuka dari ponsel dalam kondisi sekarang.

Belum ada satu halaman yang memandu perakitan dan penyalaan dari nol untuk orang baru. `CARA_UJI_HARDWARE.md` paling dekat, tetapi berasumsi pembaca sudah mengenal repo.

## 6. Sisi developer

Tiga port identik, tetapi sinkronisasinya manual; tidak ada skrip atau CI yang menjalankan ketiga suite sekaligus. Saat audit, port web tidak punya uji mandiri: kelas FSM tertanam di dalam HTML sehingga tidak bisa diimpor Node, dan delapan tombol skenario hanya mencakup skenario PRD. Saya mengekstrak kelas itu secara ad hoc dan 32 asersi lulus, tetapi hasilnya tidak tersimpan. Kelas itu kini sudah diekstrak ke `web/fsm.js`, diimpor `web/index.html` lewat `<script src="fsm.js">`, dengan `web/fsm.test.js` (30 asersi, 4 skenario regresi K1/K3 bernomor 18-21). Sisa pekerjaan: mirror penuh 21 skenario Python/C++ di JS, dan delapan tombol skenario di `web/index.html` masih hanya mencakup skenario PRD.

Tambahkan regresi K1 dan K3 ke ketiga port. Tanpa itu perbaikan bisa hilang diam-diam seperti kasus gerbang stabilitas sebelumnya.

Firmware dan PRD berbeda soal cloud: tidak ada penulisan `/daily/`, tidak ada NTP, tidak ada Mobizt, heartbeat 5 detik. Pilih satu kebenaran; memperbarui dokumen lebih murah daripada menambah fitur. Kegagalan tulis Firebase juga ditelan tanpa pesan, jadi saat rules menolak, dashboard tetap terlihat sehat.

Biner `uji_fsm.exe` ikut ter-commit dan sudah basi dibanding sumber. ZeroGPT API kini membalas 403 berbayar dan SciSpace membalas 500; T-Checker masih berfungsi. Uji cloud end-to-end belum punya bukti di panduan, hanya langkah manual.

## 7. Yang sudah benar

Empat suite lulus: 21/21 Python, 52/52 C++, 30 asersi JS di `web/fsm.test.js` (4 skenario regresi K1/K3), dan 59/59 pemeriksaan geometri CAD. Kompilasi C++ bersih dengan `-Wall -Wextra`. Kedua halaman punya tag seimbang, JavaScript lolos pemeriksaan sintaks, dan tidak ada error konsol selain CORS manifest saat `file://`. `index.html` pada 390 px bebas overflow dan bebas teks terpotong. Di firmware tidak ada cabang mati maupun state tak terpakai; desain gerbang stabilitas dan urutan evaluasi sudah benar untuk seluruh kasus yang diuji.

## 8. Prioritas perbaikan

1. K1 tekan-lepas. Pilih satu jalan keluar, lalu tambahkan skenario regresi di tiga port.
2. K2 urutan Reset Harian. Tukar dua baris di `web/index.html:769-770`.
3. M1 dan M2. Perbaiki kelas log dan tutup port serial dengan urutan yang benar.
4. K3 kalibrasi. Tolak kalibrasi saat berat aktual jauh di atas angka yang disimpan, atau selaraskan baseline tanpa memaksa refill.
5. M4 drift dokumentasi. Minimal dua baris `CLAUDE.md` yang dibaca setiap sesi.
6. M3 responsive halaman 3D, atau tandai desktop-only.
7. Kebersihan repo: `.gitignore`, hapus artefak, logo tak terpakai, dan biner basi.

Catatan metode: seluruh temuan berasal dari eksekusi kode atau pengukuran render. Perilaku aktuator dan cloud pada perangkat fisik tidak bisa diverifikasi dari sini; audit ini tidak menyentuh hardware.
