# DESIGN.md: Panduan Sistem Desain dan UX Smart Hydration Coaster
**Versi:** 3.0 (November 2026)  
**Tema Utama:** *Clean Nordic / Porcelain Light*  
**Karakter Produk:** *Calm & Ambient Lifestyle Companion* (Tatakan Gelas Pintar Pemantau Hidrasi Gaya Ember Mug dan Apple Health)  
**Platform Target:** *Web PWA* (Desktop, Tablet, Ponsel) dan Aplikasi *Mobile* Android (Flutter)  
**Status Dokumen:** *Single Source of Truth* Desain Antarmuka dan Pengalaman Pengguna (*UI/UX*)

---

## 1. Filosofi dan Prinsip Desain (*Design Principles*)

1. **Teknologi Tenang (*Calm Technology & Ambient Companion*):**
   Tatakan gelas pintar ini hadir di atas meja kerja pengguna sepanjang hari mendampingi aktivitas kerja dan belajar. Antarmuka tidak boleh berteriak, tidak mendramatisasi situasi, dan tidak membanjiri pengguna dengan warna merah pekat yang memicu kepanikan atau stres. Visual didominasi oleh nuansa porselen putih gading yang lapang, bersih, higienis, serta aksen air jernih (*glacial cyan*) yang menyejukkan. Antarmuka dirancang untuk menemani dan menumbuhkan kebiasaan minum secara konsisten, bukan bertindak sebagai mandor yang mengawasi.

2. **Pencatatan Tanpa Friksi (*Zero-Friction Logging & Closed-Loop Verification*):**
   Seluruh beban pencatatan berada di pundak sensor perangkat (*load cell* presisi dengan verifikasi lingkar tertutup), bukan pada input manual pengguna. Desain memprioritaskan visualisasi pasif yang elegan (volume air di dalam gelas, persentase target hidrasi harian, dan hitung mundur waktu minum berikutnya) daripada tombol pencatatan manual yang membebani fokus pengguna.

3. **Pemisahan Tegas: Konsumen Harian vs. Sandbox Pengujian:**
   Antarmuka operasional harian terpisah secara mutlak dari panel uji otomatis PRD dan simulator laboratorium. Pengguna umum disuguhi *companion dashboard* yang bersih dan menenangkan. Di sisi lain, penguji, mahasiswa, atau dosen dapat membuka panel *Simulator / Test Suite* secara terisolasi melalui laci (*drawer*) atau *collapsible section* tanpa mengotori ruang visual utama.

4. **Nada Bahasa Manusiawi dan Menemani (*Human & Non-Adversarial Copy*):**
   Seluruh istilah yang bernada menghakimi atau menyalahkan pengguna dieliminasi sepenuhnya. Istilah "curang" (*cheat*) atau "ditolak" diganti dengan penjelasan berorientasi tindakan yang ramah seperti "Tegukan kecil (< 20 ml)" dan panduan batasan bobot yang objektif. Seluruh kebocoran istilah teknis *backend* seperti *node akun*, *Serial Monitor 115200*, *baseline*, dan kode perintah huruf serial dihapus dari layar konsumen.

5. **Disiplin Visual Anti-Slop (*Porcelain Physicality*):**
   Desain terbebas dari gradasi ungu-biru generik kecerdasan buatan, efek *glow* neon berlebihan yang mengaburkan teks, maupun *pill-radius* acak-acakan. Setiap elemen visual memancarkan presisi fisik layaknya perkakas keramik porselen berkualitas tinggi di atas meja kerja.

---

## 2. Sistem Token Desain (*Design Tokens*)

### A. Palet Warna (*The Nordic Porcelain & Glacial Palette*)
Palet warna dirancang berdasarkan material porselen putih gading hangat, air gletser jernih, dan aksen daun hijau alami. Seluruh kombinasi warna memenuhi standar aksesibilitas WCAG 2.1 level AA dan AAA untuk kenyamanan mata saat digunakan sepanjang hari.

| Token CSS | Flutter Color | Nilai Hex | Peran dan Penggunaan | Rasio Kontras WCAG |
| :--- | :--- | :--- | :--- | :--- |
| `--bg` | `Color(0xFFF8FAFC)` | `#F8FAFC` | Latar belakang kanvas utama (*warm cream slate* / *porcelain canvas*). | Latar dasar |
| `--panel` | `Color(0xFFFFFFFF)` | `#FFFFFF` | Latar kartu komponen utama, kartu porselen mengambang (*elevation 1*). | Latar kartu |
| `--panel-hover` | `Color(0xFFF1F5F9)` | `#F1F5F9` | Keadaan *hover* kartu, latar baris tabel, dan tombol sekunder saat aktif. | 1.1:1 thd panel |
| `--panel-muted` | `Color(0xFFF1F5F9)` | `#F1F5F9` | Latar kontainer *input field*, petak metrik sekunder, dan bilah pencarian. | Latar netral |
| `--line` | `Color(0xFFE2E8F0)` | `#E2E8F0` | Garis batas (*border*) kartu porselen dan pembatas seksi yang halus. | Batas kartu |
| `--line-focus` | `Color(0xFF94A3B8)` | `#94A3B8` | Garis batas saat elemen form menerima fokus atau interaksi aktif. | Batas aktif |
| `--ink` | `Color(0xFF0F172A)` | `#0F172A` | Teks judul utama, angka metrik tebal (*slate 900* / *deep charcoal*). | 15.6:1 thd panel (AAA) |
| `--dim` | `Color(0xFF64748B)` | `#64748B` | Teks sekunder, label metrik, unit satuan, keterangan status (*slate 500*). | 4.9:1 thd panel (AA) |
| `--muted` | `Color(0xFF94A3B8)` | `#94A3B8` | Ikon pelengkap, teks petunjuk *placeholder*, garis pemisah minor (*slate 400*). | 2.8:1 (non-teks) |
| `--water` | `Color(0xFF0284C7)` | `#0284C7` | Aksen cairan air utama (*glacial cyan* / *sky 600*), tombol primer, progres aktif. | 4.6:1 thd panel (AA) |
| `--water-light` | `Color(0xFFE0F2FE)` | `#E0F2FE` | Latar *badge* air, *pill* aktif, dan sorotan lembut (*sky 100*). | Latar aksen |
| `--water-grad` | Linear Gradient | `#0284C7` ke `#38BDF8` | Gradasi cairan air di dalam *tumbler* dan bilah capaian target harian. | Aksen fluida |
| `--ok` | `Color(0xFF10B981)` | `#10B981` | Indikator tatakan stabil, target hidrasi harian tercapai (*emerald 500*). | 4.5:1 thd panel |
| `--ok-bg` | `Color(0xFFECFDF5)` | `#ECFDF5` | Latar *badge* status stabil dan notifikasi pencapaian target (*emerald 50*). | Latar status aman |
| `--ok-border` | `Color(0xFFA7F3D0)` | `#A7F3D0` | Garis batas *badge* status stabil (*emerald 200*). | Batas status aman |
| `--warn` | `Color(0xFFF59E0B)` | `#F59E0B` | Pengingat waktu minum (`ALERT_DRINK`), peringatan isi ulang air (`REFILL`). | Indikator perhatian |
| `--warn-bg` | `Color(0xFFFFFBEB)` | `#FFFBEB` | Latar *badge* pengingat waktu minum dan isi ulang (*amber 50*). | Latar perhatian |
| `--warn-border`| `Color(0xFFFDE68A)` | `#FDE68A` | Garis batas *badge* pengingat waktu minum (*amber 200*). | Batas perhatian |
| `--alarm` | `Color(0xFFEF4444)` | `#EF4444` | Peringatan tegukan belum cukup (`CHEAT`), status koneksi terputus (*rose 500*).| Indikator kendala |
| `--alarm-bg` | `Color(0xFFFEF2F2)` | `#FEF2F2` | Latar *badge* peringatan tegukan kecil (*rose 50*). | Latar kendala |
| `--alarm-border`| `Color(0xFFFECACA)`| `#FECACA` | Garis batas *badge* peringatan (*rose 200*). | Batas kendala |

### B. Tipografi (*Typography Scale*)
* **Font Display / Judul:** *Plus Jakarta Sans* atau *Space Grotesk*, *sans-serif* (modern, geometris, bersih, lapang, dan ramah).
* **Font Antarmuka / Body:** *Inter* atau *Plus Jakarta Sans*, *sans-serif* (keterbacaan optimal pada teks kecil, formulir, dan tombol).
* **Font Data Tabular / Numerik:** *JetBrains Mono*, *monospace* dengan fitur wajib `font-variant-numeric: tabular-nums` (Flutter: `FontFeature.tabularFigures()`) agar angka timbangan gram, hitung mundur detik, dan telemetri tidak melompat atau bergetar saat diperbarui secara *real-time*.

| Tingkat | Font Family | Ukuran Desktop | Ukuran Mobile | Weight | Line Height | Penggunaan Utama |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Hero Number** | JetBrains Mono | 36-40 px | 32-36 px | 600 (Semi-bold) | 1.1 | Bobot gram timbangan dan hitung mundur timer. |
| **Display Title** | Plus Jakarta Sans | 24-28 px | 20-22 px | 700 (Bold) | 1.2 | Judul dashboard utama, nama aplikasi. |
| **Section Title** | Plus Jakarta Sans | 18-20 px | 16-18 px | 600 (Semi-bold) | 1.3 | Judul kartu besar, status FSM badge. |
| **Card Title** | Plus Jakarta Sans | 14-15 px | 13-14 px | 600 (Semi-bold) | 1.4 | Judul kartu modul metrik, header panel kontrol. |
| **Body Regular** | Inter | 13-14 px | 13 px | 400 (Regular) | 1.5 | Paragraf penjelas status, deskripsi panduan. |
| **Body Medium** | Inter | 13-14 px | 13 px | 500 (Medium) | 1.4 | Teks tombol aksi, label formulir interaktif. |
| **Caption / Unit**| Inter | 11-12 px | 11 px | 500 (Medium) | 1.3 | Unit metrik (ml, g, °C, RH), cap waktu log. |
| **Micro Badge** | Plus Jakarta Sans | 10-11 px | 10 px | 600 (Semi-bold) | 1.0 | Teks label pill status FSM, indikator koneksi. |

### C. Geometri, Elevasi, dan Bayangan (*Geometry, Elevation & Diffused Shadows*)
* **Radius Sudut (*Border Radius*):**
  * Kartu utama (*cards*): `20px` (Web: `border-radius: 20px`, Flutter: `BorderRadius.circular(20)`). Bentuk membulat lembut memberikan sensasi fisik keramik porselen yang elegan dan ramah di atas meja.
  * Kartu petak metrik mini (*metric tiles*): `14px` s.d. `16px`.
  * Tombol aksi (*action buttons*) dan kolom input (*form inputs*): `12px`.
  * *Badge*, *pill toggle*, dan indikator status: `9999px` (*full pill*).
  * Hindari sudut tajam kaku (0-2px) maupun sudut oval berlebihan (50px pada kartu persegi).
* **Elevasi dan Bayangan Lembut (*Diffused Soft Shadows*):**
  * Latar belakang kanvas `#F8FAFC` menerima kartu putih `#FFFFFF` dengan bayangan terdifusi alami tanpa garis hitam tajam.
  * **Shadow Kartu Normal (*Rest Elevation*):**  
    `box-shadow: 0 4px 20px -4px rgba(15, 23, 42, 0.05), 0 2px 6px -2px rgba(15, 23, 42, 0.03);`
  * **Shadow Kartu Mengambang / Hover (*Active Elevation*):**  
    `box-shadow: 0 10px 25px -5px rgba(2, 132, 199, 0.08), 0 4px 10px -4px rgba(15, 23, 42, 0.04);`
  * **Shadow Tombol Utama (*Primary Action*):**  
    `box-shadow: 0 2px 8px 0 rgba(2, 132, 199, 0.25);`
  * Setiap kartu porselen wajib memiliki garis batas halus `1px solid #E2E8F0` guna menjaga ketegasan struktur visual di berbagai tingkat kecerahan layar.
* **Disiplin Animasi:**
  * Dilarang menggunakan efek pendaran *neon radial glow* pekat yang mengaburkan teks.
  * Efek denyut (*pulse animation*) hanya diperbolehkan muncul secara halus pada *badge* pengingat waktu minum (`ALERT_DRINK`), dan wajib dinonaktifkan otomatis saat pengguna mengaktifkan mode *prefers-reduced-motion*.

### D. Ergonomi, Aksesibilitas, dan Tata Letak Responsif (*Ergonomics & Reflow*)
* **Ukuran Sasaran Sentuh Minimum (*Touch Targets*):**
  Minimal `44 x 44 px` untuk semua tombol aksi, *pill toggle*, kolom input angka, dan *accordion summary* pada layar sentuh ponsel dan tablet (`@media(pointer: coarse)`).
* **Arsitektur Tata Letak Responsif (*Reflow Architecture*):**
  * **Desktop (Lebar Layar >= 960 px):**
    Tata letak asimetris 2 kolom yang seimbang:
    * **Kolom Kiri (5 dari 12 kolom, ~42% lebar):** Panggung visual tatakan porselen dan gelas tumbler (*Porcelain Coaster Stage*). Menampilkan visualisasi ketinggian air dinamis, bobot gram timbangan, dan status kestabilan sensor.
    * **Kolom Kanan (7 dari 12 kolom, ~58% lebar):** Panel pemantauan hidrasi dan kontrol. Memuat kartu target hidrasi harian (*progress bar*), petak 3 metrik mini (sisa waktu, suhu ruangan, frekuensi tegukan), dan tombol aksi cepat. Di bawahnya terdapat panel kontrol mode timer dan riwayat sesi.
  * **Mobile dan Tablet (Lebar Layar < 960 px):**
    Tata letak linier 1 kolom terfokus pada zona jangkauan jempol (*thumb zone*):
    * **Bagian Atas:** Cincin progres hidrasi harian 360 derajat (*Radial Hydration Ring*) dengan angka capaian terpusat.
    * **Bagian Tengah:** Visualizer tumbler ringkas dan berat timbangan aktual.
    * **Bagian Bawah:** Petak metrik mini berdampingan dan tombol aksi melayang yang mudah dijangkau satu tangan.

---

## 3. Spesifikasi Komponen Antarmuka (*Component Specifications*)

### A. Visualizer Gelas Tumbler dan Tatakan Porselen
1. **Siluet Fisik:**
   Menggambarkan gelas *tumbler* transparan berkapasitas 500 ml dengan sudut lengkung halus di atas piringan tatakan porselen bundar berwarna putih dengan cincin aksen abu-abu halus.
2. **Ketinggian Cairan Dinamis (*Dynamic Water Level*):**
   Ketinggian kolom air bergradasi *sky 600* ke *cyan 400* (`#0284C7` ke `#38BDF8`) bergerak proporsional mengikuti volume air bersih aktual di dalam gelas:
   $$\text{Tinggi Air (\%)} = \text{clamp}\left(\frac{\text{Volume Air (ml)}}{500\text{ ml}} \times 100\%, 0\%, 100\%\right)$$
3. **Animasi Gelombang Cairan (*Wave Motion*):**
   Permukaan air dilengkapi animasi gelombang mikro halus berdurasi 3 detik yang menenangkan. Animasi ini berhenti menjadi bidang datar saat mode *prefers-reduced-motion* aktif.
4. **Pembacaan Metrik Ganda:**
   * Di dalam atau tepat di atas kolom air: Volume air bersih aktual (contoh: `315 ml`).
   * Tepat di bawah piringan tatakan: Bobot total timbangan (contoh: `391.8 g`) disertai rincian bobot gelas kosong dan air.

### B. Indikator Progres Hidrasi Harian (*Hydration Progress*)
1. **Versi Radial 360 Derajat (*Mobile Flutter & Tablet*):**
   * Diameter lingkaran: 120-140 px.
   * Ketebalan garis lingkaran: 8 px dengan ujung membulat (*round cap*).
   * Lingkar latar: `#E2E8F0` (*slate 200*).
   * Lingkar progres aktif: `#0284C7` (*glacial cyan*).
   * Teks di pusat lingkaran: Angka air diminum hari ini (contoh: `1.250 ml`) dan target harian (contoh: `/ 2.000 ml`).
2. **Versi Linear Horizontal (*Web Desktop*):**
   * Tinggi bilah progres: 10 px dengan radius `9999px`.
   * Latar bilah: `#F1F5F9`.
   * Bilah progres aktif: Gradasi `#0284C7` ke `#38BDF8`.
   * Keterangan di atas bilah: "Target Hidrasi Hari Ini" di sebelah kiri dan volume serta persentase di sebelah kanan (contoh: `1.250 / 2.000 ml (62%)`).

### C. Sistem Status FSM dan Umpan Balik (*FSM Badges & Companion Feedback*)
Setiap status Finite State Machine (FSM) dipetakan ke *pill badge* berwarna lembut dengan teks kontras tinggi, didampingi pesan penjelas ramah (*companion feedback*):

| Status FSM Protokol | Label Badge UI | Warna Latar Badge | Warna Teks Badge | Warna Garis Badge | Pesan Penjelas Ramah (*Companion Feedback*) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `STATE_IDLE` | `IDLE` | `#F1F5F9` | `#475569` | `#CBD5E1` | Tatakan kosong. Letakkan gelas berisi air untuk mulai memantau. |
| `STATE_STABLE` | `STABLE` | `#ECFDF5` | `#065F46` | `#A7F3D0` | Timbangan stabil. Siap memantau konsumsi hidrasi harianmu. |
| `STATE_TIMING` | `TIMING` | `#E0F2FE` | `#0369A1` | `#BAE6FD` | Menghitung mundur jadwal minum berikutnya secara teratur. |
| `STATE_LIFTED` | `LIFTED` | `#F0F9FF` | `#0284C7` | `#B9E6FE` | Gelas sedang diangkat. Silakan nikmati air minummu. |
| `STATE_ALERT_DRINK` | `ALERT DRINK` | `#FFFBEB` | `#92400E` | `#FDE68A` | Waktunya minum air! Segarkan tubuhmu dengan satu tegukan sehat. |
| `STATE_ALERT_CHEAT` | `CHEAT` | `#FEF2F2` | `#991B1B` | `#FECACA` | Tegukan terlalu kecil (< 20 ml). Minumlah setidaknya satu tegukan wajar. |
| `STATE_ALERT_REFILL`| `REFILL` | `#FFFBEB` | `#92400E` | `#FDE68A` | Air di dalam gelas hampir habis. Silakan isi ulang gelasmu. |

*Aturan Ketat Penamaan Badge:*  
Badge hanya menampilkan kata `REFILL` dan `CHEAT` tanpa awalan `ALERT` (karena alasan pengingat sudah dijelaskan secara lengkap pada teks pesan penjelas di bawah *badge*). Hanya status `ALERT DRINK` yang tetap mempertahankan awalan `ALERT`.

### D. Petak Metrik Mini (*Metric Tiles*)
Terdiri dari 3 petak kartu porselen mini berlatar `#FFFFFF`, garis batas `#E2E8F0`, dan sudut membulat `14px`:
1. **Petak Sisa Waktu:** Menampilkan hitung mundur waktu menit dan detik (contoh: `14:20`), judul "Sisa Waktu", dan keterangan target siklus (contoh: "Target 22 mnt").
2. **Petak Suhu Ruangan:** Menampilkan suhu aktual lingkungan (contoh: `28.4°C`), judul "Suhu Ruangan", dan kelembaban udara (contoh: "RH 58%").
3. **Petak Frekuensi Tegukan:** Menampilkan jumlah tegukan yang sah dalam sesi berjalan (contoh: `5 kali`), judul "Tegukan", dan keterangan status sesi.

### E. Tombol Aksi, Formulir, dan Pengaturan (*Buttons & Controls*)
* **Tombol Aksi Utama (*Primary Action*):**
  Latar `#0284C7`, teks putih `#FFFFFF`, font medium 13px, tinggi 42px, radius `12px`, bayangan halus `0 2px 8px rgba(2, 132, 199, 0.25)`. Saat ditekan memberikan umpan balik taktil mikro (*scale 0.98*).
* **Tombol Sekunder (*Secondary / Outlined Action*):**
  Latar `#FFFFFF`, garis batas `#E2E8F0`, teks `#0F172A`, tinggi 42px, radius `12px`. Efek *hover* mengubah latar menjadi `#F8FAFC`.
* **Pill Toggle Mode Timer:**
  Kontainer berlatar `#F1F5F9` dengan radius `9999px`. Opsi aktif berlatar putih `#FFFFFF` dengan bayangan tipis dan teks tebal `#0284C7`.
* **Formulir Input Angka:**
  Latar `#FFFFFF`, garis batas `1px solid #E2E8F0`, teks `JetBrains Mono` `#0F172A`, radius `10px`. Saat fokus, garis batas berubah menjadi `#0284C7` dengan cincin fokus lembut `box-shadow: 0 0 0 3px rgba(2, 132, 199, 0.15)`.

### F. Sandbox Pengujian dan Simulator Lab (*Test Suite Drawer*)
Untuk memenuhi kebutuhan pengujian praktikum tanpa mengorbankan estetika konsumen:
* Panel kontrol simulator (tombol injeksi bobot, slider suhu/kelembaban manual, dan 8 skenario verifikasi PRD) diletakkan di dalam kontainer terpisah yang dapat dilipat (*accordion* / *collapsible panel*) atau laci geser (*drawer*).
* Label penanda: "Panel Simulasi & Laboratorium" dengan indikator status pengujian yang terpisah jelas dari kartu konsumsi air harian.

---

## 4. Kamus Salinan dan Panduan Bahasa (*Anti-Slop Copywriting*)

Seluruh teks antarmuka wajib menerapkan prinsip penulisan manusiawi (*human voice*), lugas, padat, dan bebas dari istilah klise buatan mesin:

### A. Penghilangan Kamus Tanda Kurung (*No Dictionary Parentheses*)
Dilarang menerjemahkan istilah lalu menempelkan kata aslinya di dalam tanda kurung secara berulang-ulang:
* ❌ `Kelembapan relatif (RH)` →  `Kelembapan Ruang` (atau `RH` di baris keterangan)
* ❌ `Interval dasar (mnt):` →  `Interval Dasar` (satuan menit ditulis di samping kolom input)
* ❌ `Gelas kosong (g):` →  `Berat Gelas Kosong` (satuan gram ditulis di samping kolom input)
* ❌ `Tare Load Cell ('t')` →  `Nol-kan Timbangan`
* ❌ `Simpan Gelas di Tatakan ('c')` →  `Simpan Berat Gelas`
* ❌ `Mode Tidur (Sleep)` →  `Mode Siaga (Standby)`

### B. Penghilangan Kalimat Menghakimi Pengguna (*Non-Adversarial Copy*)
Hindari konotasi negatif yang menuduh pengguna melakukan kecurangan:
* ❌ `Curang: 2x` →  `Tegukan kecil: 2x`
* ❌ `percobaan curang ke-1` →  `tegukan < 20 ml terdeteksi`
* ❌ `DITOLAK: X g di luar rentang` →  `Berat gelas harus antara 35 hingga 300 gram`
* ❌ `Peringatan: Kamu belum minum!` →  `Waktunya minum air! Segarkan tubuhmu.`

### C. Penghilangan Kebocoran Arsitektur Pengembang (*No Architecture Leakage*)
Hindari mengekspos detail teknis *database*, sensor, atau jalur komunikasi internal pada layar konsumen:
* ❌ `memakai node akun` / `Lewati, pakai node akun saja` →  `Gunakan akun pribadi` / `Lewati untuk sekarang`
* ❌ `buka Serial Monitor 115200 baud` →  `masukkan kode alat yang tertera pada panduan atau Wi-Fi setup`
* ❌ `Alat tidur` →  `Mode Siaga (Standby)`
* ❌ `Total sejak reset` →  `Akumulasi air sesi ini`
* ❌ `basis 30 mnt x faktor kontinu DHT11` →  `Otomatis menyesuaikan suhu ruangan`
* ❌ `DHT11` pada pilihan timer →  `Otomatis (sesuaikan dengan suhu ruangan)`
* ❌ `stabil (1,5 s terpenuhi)` →  `Timbangan stabil`
* ❌ `baseline 380 g` →  `Gelas terdeteksi (380 g)`

### D. Tabel Standar Salinan Antarmuka Resmi
Daftar istilah standar yang wajib digunakan seragam di Web PWA dan Aplikasi Mobile Flutter:

| Konteks Antarmuka | Istilah Baku yang Wajib Dipakai | Catatan Penulisan |
| :--- | :--- | :--- |
| Pilihan Mode Timer Otomatis | `Otomatis (sesuaikan dengan suhu ruangan)` | Jangan menulis "DHT11" atau "Adaptif Sugeno". |
| Sensor Suhu Lingkungan | `Suhu ruangan` | Keterangan interval menyebut "x kondisi ruangan". |
| Waktu Minum Berikutnya | `Sisa Waktu` atau `Minum Berikutnya` | Format hitung mundur `MM:SS`. |
| Status Timbangan Siap | `Timbangan stabil` | Menggantikan keterangan internal toleransi sensor. |
| Status Gelas Diangkat | `Gelas sedang diangkat` | Memberikan umpan balik ramah saat pengguna minum. |
| Kalibrasi Nol Timbangan | `Nol-kan Timbangan` | Menggantikan perintah teknis *tare load cell*. |
| Kalibrasi Berat Gelas | `Simpan Berat Gelas` | Menggantikan perintah kalibrasi wadah kosong. |
| Pengendalian Sesi | `Mulai Sesi` / `Akhiri Sesi` | Mengendalikan pencatatan konsumsi aktif. |
| Pengendalian Suara | `Buzzer ON` / `Buzzer OFF` | Status pembisuan pengingat audio. |

---

## 5. Matriks Pemetaan Implementasi Antar-Platform (*Cross-Platform Parity*)

Untuk memastikan keselarasan 100% antara Web PWA dan Aplikasi Mobile Android (Flutter), matriks berikut menetapkan padanan token implementasi:

### A. Padanan Variabel Web CSS dan Flutter
| Token Desain | Variabel CSS (`web/index.html`) | Konstanta Flutter (`app/lib/main.dart`) |
| :--- | :--- | :--- |
| Latar Kanvas | `var(--bg)`: `#F8FAFC` | `const _bg = Color(0xFFF8FAFC);` |
| Kartu Porselen | `var(--panel)`: `#FFFFFF` | `const _panel = Color(0xFFFFFFFF);` |
| Panel Sekunder | `var(--panel-muted)`: `#F1F5F9` | `const _panel2 = Color(0xFFF1F5F9);` |
| Garis Batas | `var(--line)`: `#E2E8F0` | `const _line = Color(0xFFE2E8F0);` |
| Teks Utama | `var(--ink)`: `#0F172A` | `const _ink = Color(0xFF0F172A);` |
| Teks Sekunder | `var(--dim)`: `#64748B` | `const _dim = Color(0xFF64748B);` |
| Aksen Air | `var(--water)`: `#0284C7` | `const _water = Color(0xFF0284C7);` |
| Status Stabil | `var(--ok)`: `#10B981` | `const _ok = Color(0xFF10B981);` |
| Status Perhatian| `var(--warn)`: `#F59E0B` | `const _warn = Color(0xFFF59E0B);` |
| Status Kendala | `var(--alarm)`: `#EF4444` | `const _alarm = Color(0xFFEF4444);` |
| Radius Kartu | `border-radius: 20px;` | `BorderRadius.circular(20)` |
| Radius Tombol | `border-radius: 12px;` | `BorderRadius.circular(12)` |
| Bayangan Kartu| `box-shadow: 0 4px 20px -4px rgba(15,23,42,0.05);` | `BoxShadow(color: Color(0x0D0F172A), blurRadius: 20, offset: Offset(0, 4))` |

### B. Aturan Ketat Pelestarian Pengujian Antarmuka (*Widget Test Preservation*)
Perombakan visual antarmuka Flutter pada `app/lib/main.dart` wajib mempertahankan seluruh teks penanda yang diuji oleh 63 *widget tests* di `app/test/`:
1. Kolom konfigurasi: `Interval dasar (menit)` atau `Interval dasar`
2. Sakelar suara: `Buzzer ON` / `Buzzer OFF`
3. Pengendali sesi: `Mulai sesi` / `Akhiri sesi`
4. Mode timer: `AUTO_DHT`
5. Reset riwayat: `Hari baru`
6. Penanda siklus berjalan: `masih memakai target`
7. Seluruh kunci widget (`Key`) dan jalur aliran telemetri cloud SSE tidak boleh dihapus atau diputus.

---

## 6. Verifikasi dan Pemeriksaan Mandiri Desain (*Design Checklist*)

Setiap perubahan antarmuka oleh `web_author` maupun `mobile_author` wajib memverifikasi poin-poin berikut sebelum diserahkan ke `qa_verifier`:
- [x] Latar belakang bersih porselen hangat (`#F8FAFC`) tanpa sisa palet gelap *dark-teal* lama.
- [x] Kartu porselen mengambang putih murni (`#FFFFFF`) dengan sudut membulat `20px` dan bayangan lembut terdifusi.
- [x] Aksen air *glacial cyan* (`#0284C7`) digunakan secara konsisten pada tombol primer, cincin hidrasi, dan kolom air tumbler.
- [x] Angka gram timbangan dan hitung mundur timer menggunakan *font* *JetBrains Mono* dengan format angka tabular (`tabular-nums`).
- [x] Seluruh *badge* status FSM menerapkan warna lembut dan teks kontras, dengan aturan label `REFILL` dan `CHEAT` tanpa kata `ALERT`.
- [x] Tidak ada kamus tanda kurung atau kata-kata menyalahkan pengguna pada seluruh salinan teks antarmuka.
- [x] Seluruh pengujian otomatis (63 *widget tests* Flutter, pengujian Web JS, 24 simulasi Python, dan 73 cek C++) lulus 100%.
