#!/usr/bin/env python3
"""Periksa firebase-rules.json memuat izin level-induk dan validasi schema RTDB.

Jalankan: python tools/cek_aturan_berkas.py
"""
import io
import json
import sys

BERKAS = 'firebase-rules.json'


def main():
    try:
        aturan = json.load(io.open(BERKAS, encoding='utf-8'))['rules']
    except FileNotFoundError:
        print(f'GAGAL: {BERKAS} tidak ditemukan')
        return 1
    except json.JSONDecodeError as e:
        print(f'GAGAL: {BERKAS} bukan JSON valid: {e}')
        return 1

    gagal = []

    def perlu(deskripsi, syarat):
        if syarat:
            print(f'[OK   ] {deskripsi}')
        else:
            print(f'[GAGAL] {deskripsi}')
            gagal.append(deskripsi)

    # Izin RTDB tidak naik ke induk; butuh .read di level $ownerUid.
    links = aturan.get('links', {}).get('$ownerUid', {})
    perlu('links/$ownerUid punya .read (daftar tautan bisa dibaca pemilik)',
          '.read' in links)
    perlu('links/$ownerUid/$deviceUid punya .read',
          '.read' in links.get('$deviceUid', {}))
    perlu('links/$ownerUid/$deviceUid punya .write',
          '.write' in links.get('$deviceUid', {}))

    claims = aturan.get('claims', {}).get('$code', {})
    perlu('claims/$code punya .read', '.read' in claims)
    perlu('claims/$code punya .write', '.write' in claims)

    pengguna = aturan.get('users', {}).get('$uid', {}).get('smart_coaster', {})
    baca = pengguna.get('.read', '')
    perlu('users/$uid/smart_coaster .read memuat auth != null',
          'auth != null' in baca)
    perlu('users/$uid/smart_coaster .read memuat cek links (pemilik lain)',
          'links/' in baca)

    perlu('claims/$code memvalidasi format 8 karakter',
          'matches(' in claims.get('.validate', ''))
    tautan_dev = links.get('$deviceUid', {})
    perlu('links/$ownerUid/$deviceUid menolak field liar ($other: false)',
          tautan_dev.get('$other', {}).get('.validate') is False)

    priv_claim = aturan.get('users', {}).get('$uid', {}).get('private', {}).get('claimCode', {})
    perlu('users/$uid/private/claimCode hanya milik $uid & tervalidasi 8 karakter',
          'auth.uid === $uid' in priv_claim.get('.read', '') and
          'matches(' in priv_claim.get('.validate', ''))

    telem = pengguna.get('telemetry', {})
    perlu('telemetry/.write dibatasi ke pemilik alat (auth.uid === $uid)',
          telem.get('.write') == 'auth != null && auth.uid === $uid' and
          telem.get('$other', {}).get('.validate') is False)

    cfg = pengguna.get('config', {})
    perlu('config memvalidasi timer_mode, manual_interval_min, empty_cup_weight_g, muted, dan $other',
          all(k in cfg for k in ('timer_mode', 'manual_interval_min', 'empty_cup_weight_g', 'muted')) and
          cfg.get('$other', {}).get('.validate') is False)

    daily_date = pengguna.get('daily', {}).get('$date', {})
    perlu('daily/$date memvalidasi format tanggal YYYY-MM-DD dan menolak $other',
          'matches(' in daily_date.get('.validate', '') and
          daily_date.get('$other', {}).get('.validate') is False)

    sess = pengguna.get('session', {})
    perlu('session mencegah pengambilalihan sesi aktif oleh tamu lain & menolak $other',
          "data.child('active').val() === false" in sess.get('.write', '') and
          sess.get('$other', {}).get('.validate') is False)

    print()
    if gagal:
        print(f'{len(gagal)} pemeriksaan gagal. Tempel ulang {BERKAS} ke '
              'Realtime Database -> Rules di konsol.')
        return 1
    print(f'Semua pemeriksaan lolos pada {BERKAS}.')
    print('Catatan: ini memeriksa berkas, bukan isi konsol. Untuk konsol, '
          'jalankan tools/cek_aturan_firebase.py.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
