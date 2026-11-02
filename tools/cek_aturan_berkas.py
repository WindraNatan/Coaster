#!/usr/bin/env python3
"""Periksa firebase-rules.json memuat izin yang dibutuhkan klien.

Alasan berkas ini ada: izin RTDB TIDAK naik ke node induk. Kalau `.read` hanya
ada di links/$ownerUid/$deviceUid, maka GET /links/<uid akun>.json (daftar
tautan milik sendiri) selalu 401 — penemuan tautan di aplikasi tidak akan
pernah berhasil, dan tidak ada tes Dart yang bisa menangkapnya karena tes
memakai klien tiruan yang selalu membalas 200.

Berkas aturan adalah kode produksi; ini tesnya. Jalankan bersama tes lain:
    python tools/cek_aturan_berkas.py
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

    # 1. Klien membaca daftar tautan sendiri: butuh .read di level $ownerUid.
    links = aturan.get('links', {}).get('$ownerUid', {})
    perlu('links/$ownerUid punya .read (daftar tautan bisa dibaca pemilik)',
          '.read' in links)
    perlu('links/$ownerUid/$deviceUid punya .read',
          '.read' in links.get('$deviceUid', {}))
    perlu('links/$ownerUid/$deviceUid punya .write',
          '.write' in links.get('$deviceUid', {}))

    # 2. Klaim alat: kode harus bisa dibaca per kode, dan hanya bisa ditulis
    #    oleh penulisnya sendiri (newData.val() === auth.uid).
    claims = aturan.get('claims', {}).get('$code', {})
    perlu('claims/$code punya .read', '.read' in claims)
    perlu('claims/$code punya .write', '.write' in claims)

    # 3. Node data: tidak boleh bisa dibaca tanpa token.
    pengguna = aturan.get('users', {}).get('$uid', {}).get('smart_coaster', {})
    baca = pengguna.get('.read', '')
    perlu('users/$uid/smart_coaster .read memuat auth != null',
          'auth != null' in baca)
    perlu('users/$uid/smart_coaster .read memuat cek links (pemilik lain)',
          'links/' in baca)

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
