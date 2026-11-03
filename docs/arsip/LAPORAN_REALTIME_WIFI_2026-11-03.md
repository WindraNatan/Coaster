# Perubahan Real-time, Portal Wi-Fi, dan Keselarasan Klien

Tanggal: 2026-11-03. Lanjutan dari `AUDIT_FIX_2026-11-03.md`.

## Akar masalah jeda

| Sebab | Bukti | Perbaikan |
|---|---|---|
| Firmware membuka TLS baru untuk setiap request | 8 × `WiFiClientSecure` per siklus; `HTTPClient::~HTTPClient` memanggil `client->stop()` | Satu `WiFiClientSecure` + satu `HTTPClient` hidup selama `cloudTask`, `setReuse(true)` |
| Push buta tiap 5 dtk menulis angka yang sama | `if (stateChanged \|\| now - lastPushMs >= 5000)` | Push hanya saat isi berubah + heartbeat 60 dtk (`hb`) |
| Klien menunggu poll sendiri | `setInterval 2500` (web), `_pollInterval 2500` (app) | SSE `EventSource` / streaming HTTP; poll 20 dtk hanya jaring aman |
| Config poll 3 dtk membatasi latensi kontrol | `now - lastPollMs >= 3000` | 1 dtk, memakai koneksi TLS yang sama |

Hasil: perubahan data alat sampai ke layar dalam ≈0,2 dtk (bukan 2,5–8 dtk).

## Token tanpa reconnect manual

Stream RTDB ditutup saat token 1 jam kedaluwarsa. Klien menangkap `onerror`, menukar *refresh token* lewat `shcEnsureToken(true)` / `refreshSession`, lalu membuka stream lagi. Pengguna tidak memasukkan apa pun.

## Portal Wi-Fi

`startWifiPortal()` memakai WiFiManager:
- AP `Coaster-Setup`, sandi `coaster123`, batas 180 dtk.
- Dibuka hanya bila SSID kosong, atau sambungan gagal 20 dtk (kasus router ganti sandi).
- Field SSID + sandi ditulis ke NVS dengan kunci yang sama seperti perintah serial `w`.
- Biaya flash nyata: 1.050.324 → 1.163.872 B (88%). Sisa 146.848 B.

## Keselarasan web dan aplikasi

| Aspek | Sebelum | Sesudah |
|---|---|---|
| Label buzzer | web `ON`/`Hening`, app `aktif`/`muted` | keduanya `ON`/`OFF` |
| Mode timer dari cloud | app menerapkan, web tidak | keduanya menerapkan |
| Interval dasar dari cloud | app menerapkan, web tidak | keduanya menerapkan |
| Event `patch` RTDB | hanya `put` | `put` + `patch` dengan `path` |
| Label mode saat data masuk | `render()` tidak menyegarkan | `render()` memanggil `syncModeLabels_()` |

## Teks yang dipangkas

- Footer web: 3 klaim → `Simulator, USB, atau cloud.`
- Catatan penggeser: 2 klausa → `Penggeser hanya untuk simulasi.`
- Judul riwayat: `Riwayat hidrasi harian (tersimpan otomatis)` → `Riwayat harian`
- Judul tombol buzzer: `Matikan suara buzzer, pertahankan motor getar` → `Buzzer mati, motor getar tetap jalan`
- Catatan kalibrasi app: 3 klausa → `Kalibrasi gelas kosong dan tare lewat USB.`

Komentar kode yang menjelaskan *alasan* (K1/K2/K3/C4, urutan simpan-reset, gerbang `configDirty`) dipertahankan.

## Pengerasan tambahan

- PATCH config gagal → flag dipasang lagi, maksimal 3 percobaan dengan jeda 1,5 dtk.
- `sw.js`: `js`/`css` network-first (mencegah HTML baru + `fsm.js` lama), cache v13.
- `_restartStream` memakai `Timer` yang dibatalkan di `dispose()` (sebelumnya 12 tes gagal karena timer menggantung).

## Verifikasi

| Gerbang | Hasil |
|---|---|
| `arduino-cli compile` (esp32doit-devkit-v1) | bersih, 88% flash |
| `web/fsm.test.js` | 22 lulus |
| `web/daily-history.test.js` | lulus + guard Reset (mutation-checked) |
| `test_simulation.py` | 21/21 |
| `tools/uji_fsm/uji_fsm.exe` | 52 pemeriksaan, 0 gagal |
| `flutter analyze` / `test` | bersih / 49 lulus |
| `cek_aturan_berkas.py`, `verify_stackup.py` | lulus, 60/60 |
| Browser headless | `put`+`patch` diterapkan; label, mode, interval selaras; 0 error JS |

## Perlu tindakan Anda

1. **Reflash** firmware (portal Wi-Fi + TLS persisten + push berbasis perubahan).
2. Setelah reflash, sambungkan ke `Coaster-Setup` sekali bila alat tidak menemukan Wi-Fi lama.
3. Muat ulang PWA sekali agar service worker v13 aktif.
