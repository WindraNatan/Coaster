#!/usr/bin/env python3
"""Build APK release dan unggah ke GitHub Release memakai token GCM.

Contoh: python tools/rilis_apk.py v1.0.0-beta21 [--skip-build] [nama]
"""
import io
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request

REPO = 'WindraNatan/Coaster'
APK = 'app/build/app/outputs/flutter-apk/app-release.apk'
FLUTTER = shutil.which('flutter') or r'D:\flutter\bin\flutter.bat'


def sh(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def github_token():
    out = sh(['git', 'credential', 'fill'],
             input='protocol=https\nhost=github.com\n\n').stdout
    for line in out.splitlines():
        if line.startswith('password='):
            return line.split('=', 1)[1]
    raise SystemExit('Token GitHub tidak ditemukan di credential helper.')


def api_request(tok, path, method='GET', data=None, raw=None, ctype=None, timeout=1800):
    body = raw if raw is not None else (json.dumps(data).encode() if data else None)
    url = 'https://api.github.com' + path if path.startswith('/repos') else path
    for attempt in range(2):
        req = urllib.request.Request(
            url, data=body, method=method,
            headers={'Authorization': 'Bearer ' + tok,
                     'Accept': 'application/vnd.github+json',
                     'Content-Type': ctype or 'application/json',
                     'User-Agent': 'shc-release'})
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return resp.status, json.loads(resp.read() or b'{}')
        except urllib.error.HTTPError as e:
            err_body = e.read().decode(errors='replace')[:300]
            if e.code in (500, 502, 503) and attempt == 0:
                time.sleep(3)
                continue
            return e.code, err_body
    return 500, 'Retry gagal'


def api(tok, path, method='GET', data=None, raw=None, ctype=None, timeout=1800):
    status, payload = api_request(tok, path, method, data, raw, ctype, timeout)
    if status >= 400:
        raise SystemExit(f'GitHub menolak {method} {path}: {status} {payload}')
    return payload


def parse_args(argv):
    skip_build = False
    pos = []
    for a in argv:
        if a in ('-h', '--help'):
            print(__doc__.strip())
            raise SystemExit(0)
        if a == '--skip-build':
            skip_build = True
        elif a.startswith('-'):
            raise SystemExit(f'Opsi tidak dikenal: {a}')
        else:
            pos.append(a)
    if not pos:
        raise SystemExit(__doc__)
    return pos[0], (pos[1] if len(pos) > 1 else None), skip_build


def main():
    raw_tag, nama_arg, skip_build = parse_args(sys.argv[1:])
    tag = raw_tag if raw_tag.startswith('v') else 'v' + raw_tag
    nama = nama_arg or f'Coaster {tag}'

    tok = github_token()
    sha = sh(['git', 'rev-parse', 'HEAD']).stdout.strip()
    if not sha:
        raise SystemExit('Tidak bisa membaca HEAD; jalankan dari dalam repo git.')
    kotor = sh(['git', 'status', '--porcelain', '--untracked-files=no']).stdout.strip()
    if kotor:
        print('PERINGATAN: ada perubahan belum di-commit; APK memuat kode '
              'yang tidak ada di komit mana pun.')
    belum = sh(['git', 'rev-list', '--count', 'origin/master..HEAD']).stdout.strip()
    if belum.isdigit() and int(belum) > 0:
        raise SystemExit(
            f'{belum} komit belum di-push. GitHub tidak mengenal SHA ini, jadi '
            'rilis akan ditolak 422.\nJalankan dulu: git push origin master')

    status, _ = api_request(tok, f'/repos/{REPO}/releases/tags/{tag}')
    if status == 200:
        rels = api(tok, f'/repos/{REPO}/releases?per_page=5')
        recent = ', '.join(r['tag_name'] for r in rels)
        raise SystemExit(f'Tag {tag} sudah ada di GitHub (rilis terakhir: {recent}). Gunakan tag baru.')
    if status != 404:
        raise SystemExit(f'Gagal memeriksa tag {tag} di GitHub: HTTP {status}')

    if skip_build:
        print('[1/4] melewati build APK (--skip-build)...')
    else:
        print('[1/4] membangun APK release...')
        t0 = time.time()
        r = sh([FLUTTER, 'build', 'apk', '--release'], cwd='app')
        if r.returncode != 0:
            print(r.stdout[-1500:], r.stderr[-800:])
            raise SystemExit('Build gagal.')
        print(f'      selesai {time.time() - t0:.0f} detik')

    if not os.path.exists(APK):
        raise SystemExit(f'APK tidak ada di {APK}')
    ukuran = os.path.getsize(APK)
    print(f'      sumber rilis: {sha[:7]}')

    print(f'[2/4] membuat rilis {tag}...')
    rel = api(tok, f'/repos/{REPO}/releases', 'POST', {
        'tag_name': tag,
        'target_commitish': sha,
        'name': nama,
        'body': f'APK release, dibangun dari `{sha[:7]}`. Ditandatangani '
                'kunci debug, jadi memasang di atas versi lama tidak perlu mencopot '
                'dan sesi tidak hilang.',
        'draft': False,
        'prerelease': True,
    })
    print(f'      {rel["html_url"]}')

    print(f'[3/4] mengunggah {ukuran / 1e6:.1f} MB...')
    t0 = time.time()
    nama_asset = f'smart-coaster-{tag}.apk'
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
