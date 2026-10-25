# Audit UI Web — Smart Hydration Coaster (PWA)

Tanggal: 2026-10-25 · Objek: `web/index.html` · Mode awal: read-only, lalu perbaikan atas persetujuan pengguna.

## Audit scope
- Surface: satu layar dashboard `web/index.html`, mode Simulator / USB Live / Cloud Firebase.
- Governing evidence: `CLAUDE.md` §2–§4 (paritas tiga port, kosakata state kanonik),
  `AUDIT_SISTEM_DAN_WEB.md`, WCAG 2.2 AA, `hallmark` Floor, `antislop` (mode *during*).
- Runtime owners: `web/index.html` (CSS+JS inline), `web/fsm.js`, `web/auth.js`.
- Explicit exceptions: bahasa UI Indonesia; palet dark-teal/cyan + Space Grotesk/JetBrains Mono
  adalah identitas proyek; angka metrik memang mono.

## Findings

| # | Masalah | Koreksi | Status |
|---|---|---|---|
| 1 | Status & timer di bawah lipatan HP: `#badge` y=1075 (375x667), y=852 (390x844); header 190–213 px | `.status` jadi blok DOM pertama; grid `areas:"stage status"/"stage tele"` di desktop, `"status"/"stage"/"tele"` di <920 px. Header dipadatkan: judul dipotong `ellipsis` (subjudul disembunyikan <920 px), jam + warp pindah ke baris slider | Selesai |
| 2 | `@media(pointer:coarse)` mati oleh urutan cascade | Blok dipindah ke akhir `<style>` | Selesai |
| 3 | Label state `ALERT EMPTY_CUP`/`ALERT MISSING_CUP` menyimpang dari kosakata kanonik; `#badge` tanpa live region | Dipetakan ke `ALERT REFILL`; `role="status" aria-live="polite" aria-atomic="true"` | Selesai |
| 4 | Mode Cloud: slider mati tampak hidup, tanpa teks penjelas | `input:disabled{opacity:.45;cursor:not-allowed}` + catatan "dibaca dari DHT11" | Selesai |

## Verifikasi

| Ukuran | Sebelum | Sesudah |
|---|---|---|
| Tinggi header 390 px | 190 px | 136 px |
| Tinggi header 1280 px | 71 px | 59 px |
| `#badge` top 390x844 | 852 px | 154 px |
| `#badge` top 375x667 | 1075 px | 154 px (bottom 285 < 667) |
| Target sentuh (coarse), 6 kontrol diuji | 28–38 px | 44 px semua, 0 undersized |
| Label state turunan | `ALERT EMPTY_CUP` | `ALERT REFILL` |
| Enter di field akun | tidak ada request | submit → `Gagal masuk: API key not valid` |
| `input:disabled` | `opacity:1`, `cursor:pointer` | `opacity:.45`, `cursor:not-allowed` |
| axe-core | 0 violation / 37 pass | 0 violation / 37 pass |
| `web/fsm.test.js` | — | SEMUA LULUS |
| Overflow horizontal 360/375/390/412 | tidak ada | tidak ada |

Skenario PRD 5 (gelas kosong) dijalankan ulang di browser: badge `ALERT REFILL`,
keterangan "gelas kosong, silakan isi ulang", log tetap memakai string mentah
`LIFTED -> ALERT_EMPTY_CUP` (sengaja, itu jejak telemetri).

Form akun (`#authForm`, satu `<form>`, `type="submit"`/`type="button"`) sudah ada sebelum audit;
klaim "tanpa `<form>`" di versi pertama laporan ini keliru dan sudah dikoreksi.

## Catatan
- `web/sw.js` network-first untuk navigasi (`:21`), jadi pengguna online menerima `index.html`
  baru pada muatan berikutnya; `CACHE_NAME` dinaikkan ke `v7` hanya untuk memaksa aset non-navigasi
  (auth.js/fsm.js) ikut diperbarui. Saat memverifikasi dengan tab yang sudah pernah membuka PWA,
  cache lama bisa menang sampai service worker aktif — pakai cache-buster (`?v=...`) atau hapus
  registrasi SW sebelum mengukur.
- Perbaikan tambahan di luar empat temuan UI: `startSession()` (`:913-918`) memanggil
  `fsm.resetStats()` sebelum `saveTodayStatsToHistory()`, sehingga riwayat hari ini ditimpa nol
  saat mulai sesi. Urutan dibalik (pola yang sama dengan `bReset`, K2 di
  `AUDIT_SISTEM_DAN_WEB.md:43`) dan diuji: riwayat 420 ml tetap utuh setelah sesi dimulai.
- Batasan yang belum tertutup: `pollCloudOnce()` (`:1042`) memanggil `saveTodayStatsToHistory()`
  tanpa syarat setelah menimpa penghitung FSM dari telemetri cloud. Pada pergantian pemilik,
  firmware mereset dalam ~15-20 s (poll config 15 s + heartbeat 5 s), cloud melaporkan nol, lalu
  `:1042` menulis nol ke entri hari ini. Jadi perbaikan urutan di `startSession()` hanya menutup
  pembalikan langsung, bukan perjalanan pulang-pergi lewat cloud. Perbaikan penuh menuntut riwayat
  harian disimpan di cloud (node `daily/<tanggal>` sudah ada dan sudah ditulis web), bukan di
  `localStorage` saja.

## Audit lanjutan (repo-wide)

Temuan lain di luar permukaan UI, dari audit menyeluruh. Nomor mengikuti laporan audit repo.

| # | Masalah | Status |
|---|---|---|
| R1 (selesai) | Simulator menulis ke perangkat nyata: `pushCloudConfig()`/`pushCloudTelemetry()` tanpa cek mode. Terbukti di browser — klik `Buzzer` saat `connMode === 'sim'` mengirim `PATCH .../config.json`, `Reset Harian` mengirim `PATCH .../telemetry.json` berisi nol. `sendSerialCmd()` sudah dijaga (`if (!serialWriter) return;`), hanya jalur cloud yang tidak. | **Selesai** — `if (connMode === 'sim') return;` di awal kedua fungsi; diuji di browser: mode sim 0 request, mode cloud dan USB tetap PATCH |
| R2 (selesai) | `sessionOwner` tidak pernah disimpan ke NVS (`cloud_sync.h:48`, `:313-318`). Setiap boot nilainya kosong, RTDB masih menyimpan pemilik lama, jadi `resetDailyStats()` jalan tiap reboot — bukan hanya saat serah-terima. | **Selesai** — ditulis ke NVS saat serah-terima (`cloud_sync.h:316-319`), dibaca di `initCloudSync` (`:354-357`); C++ harness 52/52 tetap lulus |
| R3 (selesai) | Kode klaim ditulis ulang terus setelah reboot: rules menolak (`!data.exists()`), `claimPublished` kembali false, retry tiap 250 ms ≈ 345 rb request ditolak/hari. `claimDone` ditulis (`:204`) tapi tidak pernah dibaca. | **Selesai** — `claimPublished` dibaca dari `claimDone` saat init, plus backoff 1 jam untuk kegagalan (`:234-239`) |
| R4 (selesai) | Label "TOTAL HARI INI" di app tidak pernah berganti hari: firmware tanpa NTP/RTC dan tanpa reset tengah malam. | **Selesai** — label diganti `TOTAL SEJAK RESET` (angka memang kumulatif; `CLAUDE.md` §4 mengunci "tanpa NTP", jadi menambah NTP akan melanggar keputusan itu). Reset harian sejati butuh NTP dan perubahan tiga dokumen: dicatat sebagai keputusan produk, bukan bug |
| R5 (selesai) | `_poll()` memanggil `refreshSession()` sebelum menampilkan error asli, dan tanpa `catch` sendiri; kegagalan refresh (jaringan putus) menelan penyebab sebenarnya. Di test, `loadApiKey()` melempar `MissingPluginException` sehingga `_error` tidak pernah diset. | **Selesai** — error diset dulu, refresh di dalam `try/catch` terpisah; `flutter test` 18/18, `flutter analyze` bersih |
| R6 (selesai) | Login firmware menyusun JSON dengan penyambungan string (`cloud_sync.h:64-65`); email/password berisi `"` atau `\` menghasilkan JSON rusak → HTTP 400. | **Selesai** — `jsonEscape()` menutup `"`, `\`, `\n`, `\r`, `\t`; 7 kasus diuji dengan `JSON.parse` dan round-trip nilai identik. Batasnya ditandai `ponytail:` di `cloud_sync.h:59` (input operator lewat serial, bukan data pihak lain) |
| R7 (selesai) | Riwayat harian (`localStorage`) tanpa test otomatis; dua bug sudah lolos di jalur ini. | **Selesai** — `web/daily-history.test.js` (3 asersi: simpan-sebelum-reset, bukti urutan terbalik merusak, pemangkasan 30 hari). Diverifikasi bisa gagal: pemangkasan dihapus sementara → `AssertionError: harus 30 entri, dapat 41` |
| R8 (selesai) | `CFG.BASE_INTERVAL`, `idTokenExp`, riwayat tanpa batas. | **Selesai** — `BASE_INTERVAL` dihapus dari `fsm.js`, dua tulis `idTokenExp` dihapus, riwayat dipangkas ke 30 hari. `claimDone` sekarang dibaca (R3) |

Temuan tambahan yang muncul saat mengompilasi firmware (bukan bagian R1-R8):
`cloud_sync.h` memanggil `saveStatsToNvs()` tanpa deklarasi `extern`, jadi
`arduino-cli compile --fqbn esp32:esp32:esp32` gagal dengan
`'saveStatsToNvs' was not declared in this scope`. Ini ada juga di HEAD, artinya firmware
tidak pernah berhasil dikompilasi dari repo ini. Setelah deklarasi ditambahkan:
**Sketch uses 1048116 bytes (79%) flash, 48952 bytes (14%) RAM**.

Catatan koreksi untuk pembaca laporan ini: `input[type=range]` muncul tiga kali di CSS dan
keempat aturan terkait (`:80`, `:144`, `:173`, `:51`) semuanya menopang sesuatu — `:173` adalah
blok coarse yang menang cascade karena berada paling akhir; menggabungkannya akan mengembalikan
target sentuh 28 px.
