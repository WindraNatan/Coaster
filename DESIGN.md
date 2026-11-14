# DESIGN.md: Panduan Sistem Desain dan UX Smart Hydration Coaster
**Versi:** 3.1 (November 2026) - Arsitektur Terpadu *Bento Grid* dan *Ring Gauge Trio*  
**Tema Utama:** *Clean Nordic / Porcelain Light*  
**Arsitektur Tata Letak:** *Bento Grid Layout* (adopsi pola 21st.dev dan Tremor) dipadukan dengan *Ring Gauge Trio* (Vibe Prompts dari *style.ai.id*)  
**Karakter Produk:** *Calm & Ambient Lifestyle Companion* (Tatakan Gelas Pintar Pemantau Hidrasi Gaya Ember Mug dan Apple Health)  
**Platform Target:** *Web PWA* (Desktop, Tablet, Ponsel) dan Aplikasi *Mobile* Android (Flutter)  
**Status Dokumen:** *Single Source of Truth* Desain Antarmuka dan Pengalaman Pengguna (*UI/UX*)

---

## 1. Filosofi dan Prinsip Desain (*Design Principles*)

1. **Teknologi Tenang (*Calm Technology & Ambient Companion*):**
   Tatakan gelas pintar ini hadir di atas meja kerja pengguna mendampingi aktivitas kerja dan belajar sepanjang hari. Antarmuka tidak boleh berteriak, tidak mendramatisasi situasi, dan tidak membanjiri pengguna dengan warna merah pekat yang memicu kepanikan atau stres. Visual didominasi oleh nuansa porselen putih gading yang lapang, bersih, higienis, serta aksen air jernih (*glacial cyan*) yang menyejukkan. Antarmuka dirancang untuk menemani dan menumbuhkan kebiasaan minum secara konsisten, bukan bertindak sebagai mandor yang mengawasi.

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

### C. Geometri, Elevasi, dan Bayangan Lembut (*Geometry, Elevation & Diffused Shadows*)
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

### D. Ergonomi dan Aksesibilitas (*Ergonomics & Touch Targets*)
* **Ukuran Sasaran Sentuh Minimum (*Touch Targets*):**
  Minimal `44 x 44 px` untuk semua tombol aksi, *pill toggle*, kolom input angka, dan *accordion summary* pada layar sentuh ponsel dan tablet (`@media(pointer: coarse)`).
* **Navigasi Tab Terpadu:**
  Tab navigasi utama terbagi atas tiga ranah yang jelas: *Dashboard Live* (tampilan konsumen harian), *Simulasi & Kontrol* (pengaturan perangkat dan skenario uji), serta *Riwayat & Telemetri* (analitik data jangka panjang).

---

## 3. Arsitektur Tata Letak Bento Grid (*Bento Grid Architecture*)

Arsitektur tata letak antarmuka mengadopsi standar modern *Bento Grid* yang dipelopori oleh 21st.dev dan Tremor Dashboard. Pendekatan ini menyusun berbagai modul data ke dalam petak-petak terstruktur (*grid cells*) dengan hierarki asimetris yang proporsional, meminimalkan kekacauan visual (*visual clutter*), serta memberikan kejelasan informasi seketika (*glanceable clarity*).

### A. Prinsip Desain Bento Grid (21st.dev / Tremor)
1. **Hierarki Asimetris Modular (*Asymmetric Hierarchy*):**
   Tidak semua modul berukuran sama. Modul dengan prioritas utama (*hero*) diberikan ruang lebih luas (bentang 2 kolom atau 2 baris), sedangkan metrik pendukung ditempatkan dalam petak berukuran 1x1 yang padat dan informatif.
2. **Keteraturan Jarak (*Consistent Spatial Cadence*):**
   * Celah antar petak (*grid gap*): `16px` pada perangkat bergerak, `20px` pada tablet, dan `24px` pada desktop layar lebar.
   * *Padding* internal petak kartu: seragam `20px` atau `24px` untuk kartu utama, dan `16px` untuk petak metrik mini.
3. **Penyatuan Fisik Porselen (*Unified Porcelain Containers*):**
   Setiap petak dalam *bento grid* dibungkus oleh kartu porselen putih (`#FFFFFF`) dengan garis batas halus (`#E2E8F0`) dan radius sudut `20px`. Hal ini menciptakan kesan fisik sekelompok nampan keramik yang tertata rapi di atas meja.

### B. Matriks Sel Bento Grid (*Grid Cell Matrix*)

Struktur antarmuka pada tampilan desktop mengimplementasikan tata letak kisi 12 kolom:

```
+-----------------------------------------------------------------------------+
|                                HEADER & NAV                                 |
+-----------------------------------------------------------------------------+
| [SEL 1: HERO STAGE] (Col 1-5, Row 1-2)  | [SEL 2: RING GAUGE TRIO] (Col 6-12) |
| - Visualizer Tumbler 500 ml              | - Ring 1: Target Hidrasi Harian     |
| - Coaster Pedestal & Cincin LED Status   | - Ring 2: Hitung Mundur Siklus      |
| - Bobot Aktual (JetBrains Mono)          | - Ring 3: Volume Keterisian Gelas   |
| - Indikator Kestabilan Timbangan        +-------------------------------------+
|                                          | [SEL 3: STATUS & COMPANION FEEDBACK]|
|                                          | - Badge FSM & Pesan Ramah Non-Sirkuler|
+------------------------------------------+-------------------------------------+
| [SEL 4: QUICK CONTROLS] (Col 1-4)        | [SEL 5: ENVIRONMENT] (Col 5-8)     | [SEL 6: METRICS] (Col 9-12) |
| - Mulai / Akhiri Sesi                    | - Suhu Ruang & Kelembaban (DHT11)  | - Frekuensi Tegukan        |
| - Sakelar Buzzer Audio ON/OFF            | - Mode Timer (Otomatis / Tetap)     | - Total Air Terverifikasi  |
+--------------------------------------------------------------------------------+
```

1. **Sel 1: Panggung Visualizer Utama (*Hero Stage Tile*, Bentang 5/12 Kolom, 2 Baris):**
   Menampilkan siluet gelas *tumbler* porselen/frost transparan dengan permukaan cairan air bergradasi *glacial cyan*, cincin halo LED tatakan pintar yang reaktif terhadap status FSM, angka bobot gram aktual timbangan, serta indikator kestabilan sensor.
2. **Sel 2: Panel Cincin Metrik (*Ring Gauge Trio Tile*, Bentang 7/12 Kolom, 1 Baris):**
   Tiga cincin melingkar (*circular gauges*) terpadu yang menyajikan tiga indikator vital hidrasi secara simultan dengan diameter proporsional dan teks metrik terpusat.
3. **Sel 3: Kartu Status dan Penjelas (*Companion Status Tile*, Bentang 7/12 Kolom, 1 Baris):**
   *Badge* status FSM terkini dengan warna lembut ramah pengguna, didampingi teks pesan pendamping kontekstual yang menjelaskan apa yang sedang dilakukan perangkat atau langkah apa yang disarankan ke pengguna.
4. **Sel 4: Kontrol Cepat (*Quick Action Tile*, Bentang 4/12 Kolom):**
   Pengendali sesi minum aktif (`Mulai sesi` / `Akhiri sesi`) dan sakelar audio (`Buzzer ON` / `Buzzer OFF`).
5. **Sel 5: Parameter Lingkungan (*Environment Tile*, Bentang 4/12 Kolom):**
   Pembacaan suhu ruangan (°C) dan kelembaban udara (% RH) dari sensor DHT11, serta status mode adaptif timer minum.
6. **Sel 6: Metrik Sesi Harian (*Session Metrics Tile*, Bentang 4/12 Kolom):**
   Frekuensi tegukan valid, catatan tegukan kecil, serta waktu pengingat terakhir.

### C. Responsivitas dan Penataan Ulang (*Reflow Architecture*)
* **Desktop (Lebar Layar >= 960 px):**
  Tata letak asimetris penuh 12 kolom sesuai matriks di atas. Kolom visualizer gelas di sisi kiri bersanding dengan panel metrik dan cincin hidrasi di sisi kanan.
* **Tablet (Lebar Layar 640 px s.d. 959 px):**
  Kisi bertransformasi menjadi 2 kolom seimbang. Visualizer gelas dan *Ring Gauge Trio* mengambil porsi atas secara penuh (bentang 2 kolom), diikuti petak kontrol dan parameter di bawahnya (masing-masing 1 kolom).
* **Ponsel / Mobile (Lebar Layar < 640 px):**
  Kisi berganti menjadi linier 1 kolom vertikal yang dioptimalkan untuk zona jangkauan satu tangan (*thumb zone*):
  1. *Ring Gauge Trio* dalam orientasi geser horizontal (*carousel*) atau baris kompak 3 lingkaran.
  2. Visualizer *tumbler* ringkas dengan pembacaan bobot gram.
  3. Status FSM *badge* dan pesan pendamping.
  4. Kartu kontrol aksi cepat dan formulir input dengan target sentuh minimal 44x44 px.

---

## 4. Spesifikasi Ring Gauge Trio dan SVG Circular Gauge

### A. Konsep Ring Gauge Trio (Vibe Prompts dari *style.ai.id*)
*Ring Gauge Trio* mengadaptasi prinsip visual modern dari Vibe Prompts *style.ai.id* untuk instrumen pemantauan kesehatan digital. Tiga cincin metrik melingkar bekerja secara harmonis menyajikan tiga pilar hidrasi:

```
       [RING 1]                     [RING 2]                     [RING 3]
  TARGET HIDRASI HARIAN        HITUNG MUNDUR SIKLUS         VOLUME GELAS SAAT INI
      (Daily Target)            (Interval Countdown)            (Current Cup)
      
       .---''''---.                 .---''''---.                 .---''''---.
     .'     62%    '.             .'    14:20   '.             .'    315 ml   '.
    /    1.250 ml    \           /    Target 30m  \           /    Isi 63%     \
   |                  |         |                  |         |                  |
    \                /           \                /           \                /
     '.            .'             '.            .'             '.            .'
       '---....---'                 '---....---'                 '---....---'
     Aksen: Glacial Cyan           Aksen: Amber / Sky           Aksen: Emerald / Sky
```

1. **Ring 1: Target Hidrasi Harian (*Daily Target Gauge*):**
   * **Tujuan:** Menampilkan persentase pencapaian volume air yang diminum hari ini terhadap target harian pengguna (contoh: 2.000 ml).
   * **Warna Lintasan Dasar (*Track*):** `#E0F2FE` (*sky 100*).
   * **Warna Progres Aktif (*Progress Stroke*):** Gradasi `#0284C7` (*sky 600*) ke `#38BDF8` (*sky 400*).
   * **Teks Tengah:** Angka capaian dalam ml (misal `1.250 ml`) dan persentase di atasnya (`62%`).
   * **Label Bawah:** "Target Harian".
2. **Ring 2: Hitung Mundur Siklus Minum (*Interval Countdown Gauge*):**
   * **Tujuan:** Menampilkan sisa waktu sebelum pengingat hidrasi berikutnya berbunyi.
   * **Warna Lintasan Dasar (*Track*):** `#F1F5F9` (*slate 100*).
   * **Warna Progres Aktif (*Progress Stroke*):** `#0284C7` saat waktu masih longgar, berubah menjadi `#F59E0B` (*amber 500*) saat sisa waktu < 20% siklus atau saat status `ALERT_DRINK` aktif.
   * **Teks Tengah:** Waktu format `MM:SS` (misal `14:20`) dalam *font* *JetBrains Mono*.
   * **Label Bawah:** "Jadwal Minum".
3. **Ring 3: Volume Keterisian Gelas (*Current Cup Capacity Gauge*):**
   * **Tujuan:** Menampilkan volume air aktual yang sedang tersedia di atas tatakan terhadap kapasitas nominal gelas (500 ml).
   * **Warna Lintasan Dasar (*Track*):** `#F1F5F9` (*slate 100*).
   * **Warna Progres Aktif (*Progress Stroke*):** `#10B981` (*emerald 500*) jika volume aman, atau `#EF4444` (*rose 500*) jika air menipis (< 50 ml, status `REFILL`).
   * **Teks Tengah:** Angka air di gelas (misal `315 ml`).
   * **Label Bawah:** "Isi Gelas".

### B. Spesifikasi Geometri SVG Circular Gauge (`viewBox="0 0 100 100"`)
Seluruh cincin metrik circular gauge wajib mengacu pada standar geometri SVG 100x100 berikut untuk menjamin skalabilitas sempurna di seluruh resolusi layar (retina display, web desktop, mobile PWA, dan komponen Flutter):

1. **Parameter Ruang Koordinat (*Coordinate Space*):**
   * `viewBox`: `"0 0 100 100"`
   * Lebar & Tinggi Elemen: `width: 100%`, `height: auto`, batas maksimal `max-width: 120px` (desktop) atau `96px` (mobile).
   * Titik Pusat Lingkaran: $cx = 50$, $cy = 50$.
   * Radius Efektif Lingkaran: $r = 40$ unit koordinat SVG.
   * Ketebalan Garis (*Stroke Width*): $8$ unit koordinat (atau $6$ unit untuk varian cincin kompak).
   * Diameter Total Garis: $2 \times r + \text{stroke-width} = 2 \times 40 + 8 = 88$ unit (menyisakan margin aman 6 unit di setiap sisi tepi `viewBox` sehingga ujung garis membulat tidak terpotong).

2. **Perhitungan Matematika Keliling dan Offset (*Circumference & Dashoffset*):**
   * Rumus Keliling Lingkaran:
     $$C = 2 \times \pi \times r = 2 \times 3.14159265 \times 40 \approx 251.327\text{ unit}$$
   * Konfigurasi Pola Garis: `stroke-dasharray="251.327"`
   * Rumus Kalkulasi *Dashoffset* Berdasarkan Persentase ($P$ dalam rentang $0$ s.d. $100$):
     $$\text{stroke-dashoffset} = C \times \left(1 - \frac{P}{100}\right) = 251.327 \times \left(1 - \frac{P}{100}\right)$$
   * Saat nilai $P = 0\%$, $\text{offset} = 251.327$ (lingkaran kosong penuh).
   * Saat nilai $P = 50\%$, $\text{offset} = 125.663$ (lingkaran terisi separuh).
   * Saat nilai $P = 100\%$, $\text{offset} = 0$ (lingkaran tertutup penuh).

3. **Orientasi dan Ujung Garis (*Rotation & Linecap*):**
   * Arah Awal Jam 12: Lingkaran SVG secara alami memulai busur dari arah jam 3 ($0^\circ$). Untuk memulai progres dari puncak atas (jam 12), elemen lingkaran progres wajib dirotasi $-90^\circ$ terhadap titik pusat:
     `transform="rotate(-90 50 50)"`
   * Bentuk Ujung Garis: `stroke-linecap="round"` untuk memberikan nuansa melengkung yang halus dan organik.

4. **Tipografi dan Peletakan Teks Pusat (*Centered Text Coordinates*):**
   * Seluruh teks berada di dalam grup `<g>` tanpa rotasi agar tetap tegak terbaca.
   * Angka Nilai Utama:
     `<text x="50" y="47" text-anchor="middle" dominant-baseline="central" font-family="'JetBrains Mono', monospace" font-size="14" font-weight="600" fill="#0F172A">...</text>`
   * Label Subtitle / Satuan:
     `<text x="50" y="63" text-anchor="middle" dominant-baseline="central" font-family="'Inter', sans-serif" font-size="9" font-weight="500" fill="#64748B">...</text>`

5. **Transisi dan Animasi Halus (*Fluid Transition*):**
   * Transisi CSS pada elemen lingkaran aktif:
     `transition: stroke-dashoffset 0.6s cubic-bezier(0.4, 0, 0.2, 1), stroke 0.3s ease;`
   * Saat mode *prefers-reduced-motion* aktif, durasi transisi disetel ke `0s`.

6. **Referensi Implementasi Kode SVG Circular Gauge (Web PWA):**

```html
<div class="gauge-card">
  <div class="gauge-title">Target Hari Ini</div>
  <div class="gauge-svg-wrap">
    <svg viewBox="0 0 100 100" class="circular-gauge" aria-hidden="true">
      <!-- Lingkar Lintasan Latar Belakang -->
      <circle cx="50" cy="50" r="40" 
              fill="none" 
              stroke="#E0F2FE" 
              stroke-width="8" />
      <!-- Lingkar Progres Dinamis -->
      <circle id="dailyGaugeCircle" cx="50" cy="50" r="40" 
              fill="none" 
              stroke="#0284C7" 
              stroke-width="8" 
              stroke-linecap="round"
              stroke-dasharray="251.327"
              stroke-dashoffset="94.248"
              transform="rotate(-90 50 50)" />
      <!-- Label Angka dan Satuan di Pusat -->
      <text x="50" y="46" text-anchor="middle" dominant-baseline="central" class="gauge-num">1.250</text>
      <text x="50" y="62" text-anchor="middle" dominant-baseline="central" class="gauge-lbl">/ 2.000 ml</text>
    </svg>
  </div>
  <div class="gauge-foot">Tercapai 62.5%</div>
</div>
```

---

## 5. Spesifikasi Komponen Pendukung dan Umpan Balik FSM

### A. Visualizer Gelas Tumbler dan Tatakan Porselen
1. **Siluet Fisik:**
   Menggambarkan gelas *tumbler* transparan berkapasitas 500 ml dengan sudut lengkung halus di atas piringan tatakan porselen bundar berwarna putih dengan cincin halo LED status.
2. **Ketinggian Cairan Dinamis (*Dynamic Water Level*):**
   Ketinggian kolom air bergradasi *sky 600* ke *cyan 400* (`#0284C7` ke `#38BDF8`) bergerak proporsional mengikuti volume air bersih aktual di dalam gelas:
   $$\text{Tinggi Air (\%)} = \text{clamp}\left(\frac{\text{Volume Air (ml)}}{500\text{ ml}} \times 100\%, 0\%, 100\%\right)$$
3. **Animasi Gelombang Cairan (*Wave Motion*):**
   Permukaan air dilengkapi animasi gelombang mikro halus berdurasi 3 detik yang menenangkan. Animasi ini berhenti menjadi bidang datar saat mode *prefers-reduced-motion* aktif.
4. **Cincin Halo LED Tatakan (*Coaster LED Halo Ring*):**
   Piringan tatakan porselen memiliki cincin LED interaktif pada alasnya yang memancarkan warna sesuai status FSM perangkat (hijau zamrud untuk stabil, biru langit untuk hitung mundur, kuning amber untuk pengingat minum dan isi ulang, serta merah lembut untuk peringatan tegukan kecil).

### B. Sistem Status FSM dan Umpan Balik Ramah (*FSM Badges & Companion Feedback*)
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

### C. Sandbox Pengujian dan Simulator Lab (*Test Suite Drawer*)
Untuk memenuhi kebutuhan pengujian praktikum tanpa mengorbankan estetika konsumen:
* Panel kontrol simulator (tombol injeksi bobot, slider suhu/kelembaban manual, dan 8 skenario verifikasi PRD) diletakkan di dalam kontainer terpisah yang dapat dilipat (*accordion* / *collapsible panel*) atau laci geser (*drawer*).
* Label penanda: "Panel Simulasi & Laboratorium" dengan indikator status pengujian yang terpisah jelas dari kartu konsumsi air harian.

---

## 6. Kamus Salinan dan Panduan Bahasa (*Anti-Slop Copywriting*)

Seluruh teks antarmuka wajib menerapkan prinsip penulisan manusiawi (*human voice*), lugas, padat, dan bebas dari istilah klise buatan mesin:

### A. Penghilangan Kamus Tanda Kurung (*No Dictionary Parentheses*)
Dilarang menerjemahkan istilah lalu menempelkan kata aslinya di dalam tanda kurung secara berulang-ulang:
* ❌ `Kelembapan relatif (RH)` → `Kelembapan Ruang` (atau `RH` di baris keterangan)
* ❌ `Interval dasar (mnt):` → `Interval Dasar` (satuan menit ditulis di samping kolom input)
* ❌ `Gelas kosong (g):` → `Berat Gelas Kosong` (satuan gram ditulis di samping kolom input)
* ❌ `Tare Load Cell ('t')` → `Nol-kan Timbangan`
* ❌ `Simpan Gelas di Tatakan ('c')` → `Simpan Berat Gelas`
* ❌ `Mode Tidur (Sleep)` → `Mode Siaga (Standby)`

### B. Penghilangan Kalimat Menghakimi Pengguna (*Non-Adversarial Copy*)
Hindari konotasi negatif yang menuduh pengguna melakukan kecurangan:
* ❌ `Curang: 2x` → `Tegukan kecil: 2x`
* ❌ `percobaan curang ke-1` → `tegukan < 20 ml terdeteksi`
* ❌ `DITOLAK: X g di luar rentang` → `Berat gelas harus antara 35 hingga 300 gram`
* ❌ `Peringatan: Kamu belum minum!` → `Waktunya minum air! Segarkan tubuhmu.`

### C. Penghilangan Kebocoran Arsitektur Pengembang (*No Architecture Leakage*)
Hindari mengekspos detail teknis *database*, sensor, atau jalur komunikasi internal pada layar konsumen:
* ❌ `memakai node akun` / `Lewati, pakai node akun saja` → `Gunakan akun pribadi` / `Lewati untuk sekarang`
* ❌ `buka Serial Monitor 115200 baud` → `masukkan kode alat yang tertera pada panduan atau Wi-Fi setup`
* ❌ `Alat tidur` → `Mode Siaga (Standby)`
* ❌ `Total sejak reset` → `Akumulasi air sesi ini`
* ❌ `basis 30 mnt x faktor kontinu DHT11` → `Otomatis menyesuaikan suhu ruangan`
* ❌ `DHT11` pada pilihan timer → `Otomatis (sesuaikan dengan suhu ruangan)`
* ❌ `stabil (1,5 s terpenuhi)` → `Timbangan stabil`
* ❌ `baseline 380 g` → `Gelas terdeteksi (380 g)`

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

## 7. Matriks Pemetaan Platform dan Aturan Pelestarian 63 Widget Tests

### A. Padanan Variabel Web CSS dan Flutter
| Token Desain | Variabel CSS (`web/index.html`) | Konstanta Flutter (`app/lib/main.dart`) |
| :--- | :--- | :--- |
| Latar Kanvas | `var(--bg)`: `#F8FAFC` | `const _bg = Color(0xFFF8FAFC);` |
| Kartu Porselen | `var(--panel)`: `#FFFFFF` | `const _panel = Color(0xFFFFFFFF);` |
| Panel Sekunder | `var(--panel2)`: `#F1F5F9` | `const _panel2 = Color(0xFFF1F5F9);` |
| Garis Batas | `var(--line)`: `#E2E8F0` | `const _line = Color(0xFFE2E8F0);` |
| Teks Utama | `var(--ink)`: `#0F172A` | `const _ink = Color(0xFF0F172A);` |
| Teks Sekunder | `var(--dim)`: `#64748B` | `const _dim = Color(0xFF64748B);` |
| Aksen Air | `var(--water)`: `#0284C7` | `const _water = Color(0xFF0284C7);` |
| Status Stabil | `var(--ok)`: `#10B981` | `const _ok = Color(0xFF059669);` |
| Status Perhatian| `var(--warn)`: `#F59E0B` | `const _warn = Color(0xFFD97706);` |
| Status Kendala | `var(--alarm)`: `#EF4444` | `const _alarm = Color(0xFFE11D48);` |
| Radius Kartu | `border-radius: 20px;` | `BorderRadius.circular(20)` |
| Radius Tombol | `border-radius: 12px;` | `BorderRadius.circular(12)` |
| Bayangan Kartu| `box-shadow: 0 4px 20px -4px rgba(15,23,42,0.05);` | `BoxShadow(color: Color(0x0A0F172A), blurRadius: 18, offset: Offset(0, 4))` |

### B. Aturan Ketat Pelestarian Pengujian Antarmuka (*63 Widget Tests Preservation*)
Aplikasi mobile Flutter memiliki 63 pengujian otomatis pada direktori `app/test/` yang memverifikasi alur otentikasi, klaim perangkat, kontrol sesi, telemetri awan, dan paritas FSM. Setiap pengembang atau agen pemelihara antarmuka **DILARANG MENGUBAH ATAU MENGHAPUS** teks target, hierarki tata letak, dan kunci widget (*keys*) berikut:

#### 1. Rincian Pengujian Berdasarkan Berkas:
* **`cloud_flow_test.dart` (22 Pengujian):**
  * `find.text('Menghubungkan ke Firebase…')`: Indikator pemuatan koneksi awan awal.
  * Teks metrik numerik persis: `find.text('315.0')` (bobot gram), `find.text('185 ml')` (air terdeteksi), `find.text('07:03')` (sisa waktu hitung mundur), `find.text('750.0 ml')` (total air harian), `find.text('27.0 °C')` (suhu), `find.text('60.0 %')` (kelembaban).
  * Status FSM Badge: `find.text('TIMING')`, `find.text('REFILL')`.
  * Pesan kontekstual tatakan: `find.text('gelas belum kembali ke tatakan')`, `find.text('Gelas tidak di tatakan')`.
  * Sakelar Buzzer dan Hierarki Baris: Wajib mempertahankan struktur `Row` yang memuat teks `'Buzzer'` dan widget `Switch`, serta menampilkan teks `'ON'` atau `'OFF'`:
    `find.descendant(of: find.ancestor(of: find.text('Buzzer'), matching: find.byType(Row)).first, matching: find.byType(Switch))`
  * Tombol Pengendali Sesi: `find.text('Mulai sesi')` dan `find.text('Akhiri sesi')`.
  * Pilihan Demo Cepat: `find.text('Demo 15 detik')`.
  * Input Konfigurasi Interval: Wajib menyertakan label persis `'Interval dasar (menit)'` yang berdampingan dengan `TextField`:
    `find.descendant(of: find.ancestor(of: find.text('Interval dasar (menit)'), matching: find.byType(Row)).first, matching: find.byType(TextField))`
  * Pilihan Mode Otomatis: `find.text('AUTO_DHT')`.
  * Peringatan Siklus Berjalan: `find.textContaining('masih memakai target')` dan `find.textContaining('masih memakai target 30 menit')`.
  * Header dan Tombol Reset Harian: `find.text('Hari ini')`, `find.textContaining('150 / 2000 ml')`, dan `find.textContaining('Hari baru')`.
  * Penanganan Error Jaringan: `find.textContaining('Gagal membaca cloud:')`, `find.textContaining('HTTP 500')`, `find.textContaining('Belum ada data telemetry.')`.
  * Form Masuk Akun: `TextField.at(0)` untuk email, `TextField.at(1)` untuk password, dan tombol aksi `find.text('Masuk')`.

* **`connect_screen_test.dart` (15 Pengujian):**
  * Elemen form layar otentikasi: `find.text('Email')`, `find.text('Password')`, `find.text('Masuk')`.
  * Input konfigurasi lanjutan (tersembunyi dalam mode normal, terbuka saat opsi diklik): `find.text('URL Firebase RTDB')` dan `find.text('Web API Key proyek Firebase')`.
  * Nilai fallback API key: `find.text(kFirebaseApiKey)` dan penolakan nilai salah `find.text('AIzaSalahSekali')`.

* **`claim_device_test.dart` (15 Pengujian):**
  * Verifikasi kontrak logika klaim kode 8 karakter terhadap REST endpoint RTDB:
    `GET /claims/<KODE>.json` -> `PUT /links/<uid-akun>/<uid-alat>.json`.
  * Validasi sanitasi input: kode dengan panjang tidak sama dengan 8 ditolak sebelum menyentuh jaringan.

* **`telemetry_test.dart` (8 Pengujian):**
  * Pemetaan kontrak JSON telemetri: pembacaan tipe data `int` maupun `double` numerik RTDB tanpa menimbulkan `TypeError`.
  * Pemetaan status kanonikal: `ALERT_MISSING_CUP` wajib otomatis dipetakan ke `ALERT_REFILL` dengan flag `missingCup: true` dan keterangan alasan `'gelas belum kembali ke tatakan'`.
  * Nilai default saat tatakan kosong (`STATE_IDLE`): alasan `'taruh gelas untuk mulai'`.

* **`auth_keystore_test.dart` (3 Pengujian):**
  * Penyimpanan sesi otentikasi pengguna secara persisten melalui SharedPreferences.

---

## 8. Verifikasi dan Pemeriksaan Mandiri Desain (*Design Checklist*)

Setiap perubahan antarmuka oleh `web_author` maupun `mobile_author` wajib memverifikasi poin-poin berikut sebelum diserahkan ke `qa_verifier`:
- [x] Latar belakang bersih porselen hangat (`#F8FAFC`) tanpa sisa palet gelap *dark-teal* lama.
- [x] Kartu porselen mengambang putih murni (`#FFFFFF`) dengan sudut membulat `20px` dan bayangan lembut terdifusi.
- [x] Arsitektur *Bento Grid* (pola 21st.dev / Tremor) terdistribusi rapi dalam hierarki sel Hero, Gauges, Status, dan Kontrol.
- [x] *Ring Gauge Trio* menyajikan tiga indikator melingkar (Target Harian, Hitung Mundur Siklus, dan Kapasitas Gelas) dengan spesifikasi SVG `viewBox="0 0 100 100"` ($r=40$, keliling $\approx 251.327$, rotasi $-90^\circ$, `stroke-linecap="round"`).
- [x] Aksen air *glacial cyan* (`#0284C7`) digunakan secara konsisten pada tombol primer, cincin hidrasi, dan kolom air tumbler.
- [x] Angka gram timbangan dan hitung mundur timer menggunakan *font* *JetBrains Mono* dengan format angka tabular (`tabular-nums`).
- [x] Seluruh *badge* status FSM menerapkan warna lembut dan teks kontras, dengan aturan label `REFILL` dan `CHEAT` tanpa kata `ALERT`.
- [x] Tidak ada kamus tanda kurung atau kata-kata menyalahkan pengguna pada seluruh salinan teks antarmuka.
- [x] Seluruh 63 *widget tests* di `app/test/` tetap 100% PASS dengan pelestarian seluruh string pencarian selector.
- [x] Pengujian 4 lapis (Flutter 63 tes, Web JS tests, Python simulator 24 skenario, dan C++ FSM 73 cek) lulus penuh.
