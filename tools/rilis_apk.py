#!/usr/bin/env python3
"""Build APK debug, terbitkan sebagai GitHub Release, cetak tautan unduh.

Dipakai supaya pembaruan aplikasi tidak perlu menyambung kabel USB: pengguna
mengunduh APK dari tautan rilis dan memasangnya di atas yang lama. Kunci debug
dipakai apa adanya (build.gradle.kts masih TODO), jadi tanda tangannya cocok
dengan yang terpasang dan tidak memaksa uninstall.

Token diambil dari Git Credential Manager, tidak disimpan ke berkas.

Contoh:
    python tools/rilis_apk.py 1.0.0-beta2
"""
import io
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

REPO = 'WindraNatan/Coaster'
APK = 'app/build/app/outputs/flutter-apk/app-debug.apk'
FLUTTER = r'D:\flutter\bin\flutter.bat'


def sh(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def github_token():
    """Ambil token dari GCM. Gagal -> keluar dengan pesan jelas."""
    out = sh(['git', 'credential', 'fill'],
             input='protocol=https\nhost=github.com\n\n').stdout
    for line in out.splitlines():
        if line.startswith('password='):
            return line.split('=', 1)[1]
    raise SystemExit('Token GitHub tidak ditemukan di credential helper.')


def api(tok, path, method='GET', data=None, raw=None, ctype=None, timeout=1800):
    body = raw if raw is not None else (json.dumps(data).encode() if data else None)
    req = urllib.request.Request(
        'https://api.github.com' + path if path.startswith('/repos') else path,
        data=body, method=method,
        headers={'Authorization': 'Bearer ' + tok,
                 'Accept': 'application/vnd.github+json',
                 'Content-Type': ctype or 'application/json',
                 'User-Agent': 'shc-release'})
    try:
        return json.loads(urllib.request.urlopen(req, timeout=timeout).read() or b'{}')
    except urllib.error.HTTPError as e:
        raise SystemExit(f'GitHub menolak {method} {path}: {e.code} {e.read().decode()[:300]}')


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    tag = sys.argv[1]
    # Tag rilis harus diawali 'v'; GitHub menolak nama lain.
    if not tag.startswith('v'):
        tag = 'v' + tag
    nama = sys.argv[2] if len(sys.argv) > 2 else f'Coaster {tag}'

    print(f'[1/4] membangun APK debug…')
    t0 = time.time()
    r = sh([FLUTTER, 'build', 'apk', '--debug'], cwd='app')
    if r.returncode != 0:
        print(r.stdout[-1500:], r.stderr[-800:])
        raise SystemExit('Build gagal.')
    print(f'      selesai {time.time() - t0:.0f} detik')

    if not os.path.exists(APK):
        raise SystemExit(f'APK tidak ada di {APK}')
    ukuran = os.path.getsize(APK)

    tok = github_token()
    # Sumber rilis harus menunjuk komit yang benar-benar dibangun. Tanpa ini,
    # tag baru berpijak pada cabang remote, yang bisa tertinggal dari HEAD lokal
    # sehingga sumber rilis berbeda dari APK yang diunggah.
    sha = sh(['git', 'rev-parse', 'HEAD']).stdout.strip()
    if not sha:
        raise SystemExit('Tidak bisa membaca HEAD; jalankan dari dalam repo git.')
    kotor = sh(['git', 'status', '--porcelain', '--untracked-files=no']).stdout.strip()
    if kotor:
        print('      PERINGATAN: ada perubahan belum di-commit; APK memuat kode '
              'yang tidak ada di komit mana pun.')
    print(f'      sumber rilis: {sha[:7]}')

    print(f'[2/4] membuat rilis {tag}…')
    rel = api(tok, f'/repos/{REPO}/releases', 'POST', {
        'tag_name': tag,
        'target_commitish': sha,
        'name': nama,
        'body': f'APK debug untuk uji, dibangun dari `{sha[:7]}`. Pasang di atas '
                'versi lama; sesi tidak hilang karena ditandatangani kunci yang sama.',
        'draft': False,
        'prerelease': True,
    })
    print(f'      {rel["html_url"]}')

    print(f'[3/4] mengunggah {ukuran / 1e6:.1f} MB…')
    t0 = time.time()
    nama_asset = f'smart-coaster-{tag}-debug.apk'
    with io.open(APK, 'rb') as f:
        asset = api(tok,
                    f'https://uploads.github.com/repos/{REPO}/releases/{rel["id"]}'
                    f'/assets?name={nama_asset}',
                    'POST', raw=f.read(),
                    ctype='application/vnd.android.package-archive')
    print(f'      selesai {time.time() - t0:.0f} detik')

    print('[4/4] selesai')
    print(f'  unduh: {asset["browser_download_url"]}')


if __name__ == '__main__':
    main()
