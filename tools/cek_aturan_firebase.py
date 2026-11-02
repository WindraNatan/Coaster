#!/usr/bin/env python3
"""Periksa apakah aturan Firebase di konsol sudah lengkap untuk alur tautan alat.

Alat ini memakai REST langsung (tanpa HP, tanpa SDK): login dengan email dan
kata sandi, lalu menguji tiga hal yang tidak bisa diuji oleh MockClient —
apakah izin tingkat node benar-benar diberikan konsol.

Yang diperiksa:
  1. /claims/<kode>            -> harus 200 (blok claims ada)
  2. /links/<uid>              -> harus 200 (`.read` di level $ownerUid ada)
  3. /users/<uid orang lain>   -> harus 401 (tidak bisa baca node asing)

Poin 2 adalah yang paling mudah terlewat: izin RTDB tidak naik ke node induk,
jadi `.read` yang hanya ada di links/$ownerUid/$deviceUid membuat permintaan
daftar tautan selalu 401 dan penemuan tautan tidak pernah jalan.

Pakai:
    python tools/cek_aturan_firebase.py <email> <password>
"""
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

API_KEY = 'AIzaSyAsJOK540P20E2KeOyB2BdXQj3dOARfyLA'
BASE = 'https://smart-coaster-64880-default-rtdb.asia-southeast1.firebasedatabase.app'


def login(email, password):
    req = urllib.request.Request(
        f'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={API_KEY}',
        data=json.dumps({'email': email, 'password': password,
                         'returnSecureToken': True}).encode(),
        headers={'Content-Type': 'application/json'}, method='POST')
    try:
        r = json.loads(urllib.request.urlopen(req, timeout=30).read())
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        pesan = json.loads(body).get('error', {}).get('message', body)
        raise SystemExit(f'Login gagal: {pesan}')
    return r['idToken'], r['localId']


def get(path, tok):
    try:
        r = urllib.request.urlopen(f'{BASE}{path}.json?auth={tok}', timeout=25)
        return r.status, r.read().decode()[:60]
    except urllib.error.HTTPError as e:
        return e.code, e.reason


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    tok, uid = login(sys.argv[1], sys.argv[2])
    print(f'uid akun: {uid}\n')

    hasil = []
    for label, path, harus in [
        ('/claims/<kode acak>', '/claims/ZZZZZZZZ', 200),
        ('/links/<uid akun>', f'/links/{uid}', 200),
        ('/users/<uid asing>', '/users/uid_orang_lain', 401),
    ]:
        kode, isi = get(path, tok)
        ok = (kode == harus)
        hasil.append(ok)
        tanda = 'OK  ' if ok else 'GAGAL'
        print(f'[{tanda}] {label:22s} -> {kode} (harus {harus})  {isi}')

    print()
    if all(hasil):
        print('Aturan lengkap. Penemuan tautan dan klaim alat bisa jalan.')
    else:
        print('Aturan belum lengkap. Tempel seluruh isi firebase-rules.json dari '
              'repo ke Realtime Database -> Rules, lalu jalankan ulang.')


if __name__ == '__main__':
    main()
