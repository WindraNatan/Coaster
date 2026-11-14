# DESIGN.md — Panduan Desain Antarmuka & UX: Smart Hydration Coaster
**Versi:** 2.0 (Desember 2026)  
**Karakter Produk:** *Calm & Ambient Desk Companion* (Tatakan Gelas Pintar Pemantau Hidrasi)  
**Platform:** Web PWA (Desktop & Mobile Tablet) dan Aplikasi Mobile Android (Flutter)

---

## 1. Filosofi & Prinsip Desain (*Design Principles*)

1. **Teknologi Tenang (*Calm Technology*):**
   Tatakan gelas ini hidup di atas meja kerja pengguna sepanjang hari. Antarmuka tidak boleh berteriak, tidak mendramatisasi situasi, dan tidak membanjiri pengguna dengan peringatan merah yang memicu stres. Antarmuka hadir untuk menenangkan dan mendisiplinkan, bukan mengawasi.

2. **Pencatatan Tanpa Friksi (*Zero-Friction Logging*):**
   Beban pencatatan ada pada sensor perangkat (*load cell* dan *closed-loop verification*), bukan pada ketikan pengguna. Desain mengutamakan tampilan visual status pasif (berat air aktual, sisa waktu, dan target) daripada tombol input manual.

3. **Pemisahan Tegas: Konsumen Harian vs. Sandbox Pengujian:**
   Antarmuka operasional harian terpisah dari panel uji otomatis PRD / simulator lab. Pengguna riil disuguhi *companion dashboard* yang bersih, sementara penguji/dosen dapat membuka mode *Simulator / Test Suite* secara terisolasi tanpa mengotori layar utama.

4. **Nada Bahasa Manusiawi & Menemani (*Human & Non-Adversarial Copy*):**
   Hapus istilah yang menghakimi seperti "Curang" (*Cheat*) atau "Ditolak". Ganti dengan istilah berorientasi tindakan dan ramah seperti "Tegukan kecil (< 20 ml)" dan batasan yang objektif. Hapus kebocoran istilah backend seperti *node akun*, *Serial Monitor 115200*, *baseline*, dan perintah huruf serial.

---

## 2. Token Desain (*Design Tokens*)

### A. Palet Warna (*The Fluid & Slate Palette*)
Dibatasi pada palet dark-teal yang tenang dengan satu aksen air fluida, bebas dari gradasi ungu-biru AI slop:

| Token | Nilai Hex | Peran & Penggunaan |
| :--- | :--- | :--- |
| `--bg` | `#0C1F27` | Latar belakang kanvas utama (deep obsidian-teal). |
| `--panel` | `#132B35` | Latar kartu komponen, elevasi level 1. |
| `--panel2` | `#0F242D` | Latar panel sekunder, input field, baris header/drawer. |
| `--line` | `#234654` | Garis batas (*border*) halus dan pembatas struktur. |
| `--ink` | `#E2F1F3` | Teks utama, kontras tinggi terhadap panel (WCAG AAA). |
| `--dim` | `#93B8C2` | Teks sekunder, label, unit metrik (kontras > 6:1). |
| `--water` | `#44C8E6` | Aksen cairan utama, progress bar, countdown, tombol aktif. |
| `--ok` | `#5FD195` | Status stabil, target tercapai, indikator koneksi hidup. |
| `--warn` | `#F0C254` | Pengingat waktu minum (`ALERT_DRINK`), peringatan isi ulang. |
| `--alarm` | `#F26B6E` | Peringatan tegukan belum cukup (`ALERT_CHEAT`), error server. |

### B. Tipografi (*Typography Scale*)
* **Display / Header:** `Space Grotesk`, `sans-serif` (geometris, bersih, humanis, berkarakter tegas).
* **Data / Tabular:** `JetBrains Mono`, `monospace` (dengan fitur `font-variant-numeric: tabular-nums` agar angka timbangan gram dan countdown detik tidak melompat-lompat).

| Tingkat | Font Family | Ukuran | Weight | Penggunaan |
| :--- | :--- | :--- | :--- | :--- |
| **Hero Number** | JetBrains Mono | 36–42 px | 600 (Semi-bold) | Bobot gram timbangan & hitung mundur timer. |
| **Title 1** | Space Grotesk | 24–28 px | 600 (Semi-bold) | Status FSM badge & judul seksi utama. |
| **Title 2** | Space Grotesk | 16–18 px | 500 (Medium) | Judul kartu metrik & nama merek. |
| **Body / Label**| Space Grotesk | 13–14 px | 400 (Regular) | Teks keterangan, pesan status, deskripsi. |
| **Micro Data** | JetBrains Mono | 11–12 px | 400–600 | Label metrik, log waktu, indikator status. |

### C. Bentuk & Elevasi (*Radius & Surface Elevation*)
* **Radius Sudut:**
  * Kontrol kecil, pill status, dan tombol aksi: `6px`.
  * Kartu modul & panel metrik: `10px` s.d. `12px`.
  * Hindari *pill-radius* berlebihan (50px) pada semua elemen agar hierarki form vs card tetap jelas.
* **Elevasi & Bayangan:**
  * Pertahankan *flat-matte hierarchy* dengan garis batas kontras `--line: #234654`.
  * Jangan gunakan *blurred radial glow* berlebihan di latar belakang. *Pulse animation* hanya muncul secara terarah saat alarm `ALERT_DRINK` aktif, dan mati otomatis jika pengguna mengaktifkan mode *prefers-reduced-motion*.

### D. Aksesibilitas & Tata Letak Mobile (*Ergonomics*)
* **Target Sentuh Minimum:** Minimal `44 x 44 px` untuk semua tombol sentuh, *pill toggle*, input angka, dan *summary* accordion di perangkat bergerak (`@media(max-width: 760px)` dan `@media(pointer: coarse)`).
* **Tata Letak Reflow:** Pada desktop, stage timbangan berada di sebelah kiri dan status/kontrol di sebelah kanan. Pada layar ponsel (< 920 px), status dan sisa waktu naik ke paling atas (fokus utama jempol), diikuti grafik gelas dan kontrol.

---

## 3. Kamus Copywriting & Panduan Bahasa (*Anti-Slop Voice*)

1. **Hilangkan Kamus Tanda Kurung:**
   * ❌ `Kelembapan relatif (RH)` →  `Kelembapan Ruang`
   * ❌ `Interval dasar (mnt):` →  `Interval Dasar` *(satuan menit di dalam kolom/suffix)*
   * ❌ `Gelas kosong (g):` →  `Berat Gelas Kosong` *(satuan gram di dalam kolom)*
   * ❌ `Tare Load Cell ('t')` →  `Nol-kan Timbangan`
   * ❌ `Simpan Gelas di Tatakan ('c')` →  `Simpan Berat Gelas`

2. **Hilangkan Teks Menghakimi Pengguna:**
   * ❌ `Curang: 2x` →  `Tegukan kecil: 2x`
   * ❌ `percobaan curang ke-1` →  `tegukan < 20 ml terdeteksi`
   * ❌ `DITOLAK: X g di luar rentang` →  `Berat gelas harus antara 35 hingga 300 gram`

3. **Hilangkan Kebocoran Arsitektur Pengembang:**
   * ❌ `memakai node akun` / `Lewati, pakai node akun saja` →  `Gunakan akun pribadi` / `Lewati untuk sekarang`
   * ❌ `buka Serial Monitor 115200 baud` →  `masukkan kode alat yang tertera pada panduan atau Wi-Fi setup`
   * ❌ `Alat tidur` →  `Mode Siaga (Standby)`
   * ❌ `Total sejak reset` →  `Akumulasi air sesi ini`
   * ❌ `basis 30 mnt x faktor kontinu DHT11` →  `Otomatis menyesuaikan suhu ruangan`
   * ❌ `stabil (1,5 s terpenuhi)` →  `Timbangan stabil`
   * ❌ `baseline 380 g` →  `Gelas terdeteksi (380 g)`
