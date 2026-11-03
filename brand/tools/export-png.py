"""Menghitung ukuran ekspor PNG dan memeriksa hasilnya di disk.

Ekspornya sendiri dijalankan lewat browser (lihat PANDUAN-LOGO.md) memakai
deviceScaleFactor 3. Skrip ini menghitung target dan membandingkannya dengan
berkas yang benar-benar ada, supaya tidak ada klaim ukuran tanpa bukti.

Dijalankan: python brand/tools/export-png.py
"""
import io
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'brand')

# 3x viewBox. Lockup selebar 1378 px menjadi 4134 px: 350 mm pada 300 DPI,
# cukup untuk sampul A4 (210 mm) dengan margin.
SCALE = 3


def png_size(path):
    with open(path, 'rb') as f:
        head = f.read(24)
    if head[:8] != b'\x89PNG\r\n\x1a\n':
        return None
    return int.from_bytes(head[16:20], 'big'), int.from_bytes(head[20:24], 'big')


def main():
    print(f'{"berkas":32} {"target":>12} {"di disk":>12}  status')
    problems = 0
    for name in sorted(os.listdir(OUT)):
        if not name.endswith('.svg'):
            continue
        text = io.open(os.path.join(OUT, name), encoding='utf-8').read()
        m = re.search(r'viewBox="0 0 (\d+) (\d+)"', text)
        if not m:
            print(f'  {name:30} (tanpa viewBox)')
            continue
        w, h = int(m.group(1)) * SCALE, int(m.group(2)) * SCALE
        png = os.path.join(OUT, name[:-4] + '.png')
        actual = png_size(png) if os.path.exists(png) else None
        if actual is None:
            status, problems = 'BELUM ADA', problems + 1
            shown = '-'
        else:
            shown = f'{actual[0]}x{actual[1]}'
            # Toleransi 5% untuk pembulatan viewBox.
            ok = actual[0] >= w * 0.95 and actual[1] >= h * 0.95
            status = 'ok' if ok else 'TERLALU KECIL'
            problems += 0 if ok else 1
        print(f'  {name:30} {w}x{h:<8} {shown:>12}  {status}')
    print()
    print('Semua siap.' if problems == 0 else f'{problems} berkas perlu diekspor ulang.')


if __name__ == '__main__':
    main()
