"""Mengekspor setiap SVG brand ke PNG memakai Chromium tanpa latar tambahan.

Dijalankan: python brand/tools/export-png.py
Butuh: node dengan modul puppeteer dari browser tool, atau jalankan dari TUI
lewat browser.open. Skrip ini hanya mencatat ukuran yang harus dipakai.
"""
import io
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'brand')

# Skala ekspor: 2x dari viewBox, cukup untuk cetak dan slide.
SCALE = 2

print('Berkas dan ukuran ekspor yang benar:')
for name in sorted(os.listdir(OUT)):
    if not name.endswith('.svg'):
        continue
    text = io.open(os.path.join(OUT, name), encoding='utf-8').read()
    m = re.search(r'viewBox="0 0 (\d+) (\d+)"', text)
    if not m:
        print('  (tanpa viewBox)', name)
        continue
    w, h = int(m.group(1)), int(m.group(2))
    print(f'  {name:32} {w * SCALE}x{h * SCALE}')
