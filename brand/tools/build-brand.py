"""Membangun seluruh berkas logo dari satu definisi tanda + wordmark.

Menulis enam SVG di brand/ (tanda dan kuncian, versi terang dan gelap) serta
web/icon.svg. Semua berasal dari bentuk yang sama, jadi tidak bisa menyimpang.

Dijalankan: python brand/tools/build-brand.py
"""
import io
import os

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.ttLib import TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONT = os.path.join(ROOT, 'app', 'assets', 'fonts', 'SpaceGrotesk-Bold.ttf')
OUT = os.path.join(ROOT, 'brand')

INK = '#0C1F27'
CYAN = '#44C8E6'
PALE = '#E2F1F3'
TRACK = 0.02


def glyphs(text, size):
    font = TTFont(FONT)
    gs = font.getGlyphSet()
    cmap = font.getBestCmap()
    upem = font['head'].unitsPerEm
    scale = size / upem
    x = 0.0
    out = []
    for ch in text:
        name = cmap.get(ord(ch))
        if name is None:
            x += size * 0.34
            continue
        pen = SVGPathPen(gs)
        gs[name].draw(pen)
        d = pen.getCommands()
        if d:
            out.append(
                f'<path transform="translate({x:.2f} 0) scale({scale:.5f} {-scale:.5f})" d="{d}"/>'
            )
        x += gs[name].width * scale + size * TRACK
    return '\n      '.join(out), x


def mark_defs():
    """Potongan air. Dideklarasikan sekali di akar SVG: di dalam grup yang
    diskalakan, koordinat clipPath ikut terskala dan air terpotong salah."""
    return '''  <defs>
    <clipPath id="body">
      <path d="M168,158 L182,372 A74,25 0 0 0 330,372 L344,158 Z"/>
    </clipPath>
  </defs>
'''


def mark(color_mode='dark'):
    """Tanda: gelas di atas tatakan, tampak sedikit dari atas."""
    if color_mode == 'dark':
        base, face, edge, water, surf, rim = '#071219', '#173743', CYAN, CYAN, '#7FE3F4', '#9FC4CE'
    elif color_mode == 'yellow':
        # Sticker di casing mustard #EDB651. Cyan di atas kuning nyaris tidak
        # terbaca (kontras 1,3:1), jadi air dikurung di dalam badan gelas yang
        # bertinta, dan tatakan diberi muka putih tulang supaya gelas punya
        # bidang untuk berdiri.
        base, face, edge, water, surf, rim = '#C9922F', '#FAF5E9', INK, CYAN, '#DDF1F6', INK
    else:
        base, face, edge, water, surf, rim = '#0A1920', '#132B35', '#2FA8C4', CYAN, '#8FE9F7', '#8FB3BD'
    return f'''  <ellipse cx="256" cy="404" rx="176" ry="54" fill="{base}"/>
  <ellipse cx="256" cy="386" rx="176" ry="54" fill="{face}" stroke="{edge}" stroke-width="13"/>
  <path d="M168,158 L182,372 A74,25 0 0 0 330,372 L344,158 Z" fill="{INK if color_mode != 'dark' else '#143440'}"/>
  <g clip-path="url(#body)">
    <rect x="160" y="286" width="192" height="120" fill="{water}"/>
  </g>
  <ellipse cx="256" cy="286" rx="79" ry="26" fill="{surf}"/>
  <ellipse cx="256" cy="158" rx="88" ry="30" fill="{INK if color_mode != 'dark' else '#143440'}" stroke="{rim}" stroke-width="9"/>'''


def sticker_yellow(with_name=True):
    """Sticker untuk ditempel di casing kuning mustard.

    Latar sengaja kosong: kalau dicetak di vinil bening, kuning casing yang
    menjadi latarnya. Preview-nya ada di sticker_yellow_preview().

    Nama produk memakai tinta gelap, bukan pucat: pucat di atas kuning hilang.
    """
    if with_name:
        name, w = glyphs('Smart Hydration Coaster', 56)
    else:
        name, w = '', 0.0
    margin, gap, mark_size = 64, 42, 232
    height = int(margin * 2 + mark_size)
    mark_y = (height - mark_size) // 2
    if with_name:
        tx = margin + mark_size + gap
        total_w = int(tx + w + margin)
    else:
        tx = 0
        total_w = int(mark_size + margin * 2)
    baseline = height // 2 + 20
    inner = mark('yellow')
    body = f'''  <g transform="translate({margin} {mark_y}) scale({mark_size/512:.4f})">
{inner}
  </g>'''
    if with_name:
        body += f'''
  <g fill="{INK}" transform="translate({tx:.2f} {baseline})">
      {name}
  </g>'''
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {total_w} {height}" width="{total_w}" height="{height}" role="img" aria-label="Smart Hydration Coaster">
  <title>Smart Hydration Coaster</title>
{mark_defs()}{body}
</svg>
'''


def sticker_yellow_preview():
    """Sticker yang sama di atas bidang kuning casing, untuk menilai kontras."""
    satu = sticker_yellow()
    vb = satu.split('viewBox="')[1].split('"')[0].split()
    w, h = int(vb[2]), int(vb[3])
    # Seluruh isi dipakai apa adanya, termasuk <defs>: clipPath gelas harus
    # ikut, kalau tidak air menonjol keluar dinding yang meruncing.
    isi = satu[satu.index('>') + 1:satu.rindex('</svg>')]
    isi = isi[isi.index('</title>') + len('</title>'):]
    pad = 96
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w + pad*2} {h + pad*2}" width="{w + pad*2}" height="{h + pad*2}" role="img" aria-label="Pratinjau sticker di casing kuning">
  <title>Pratinjau sticker di casing kuning</title>
  <rect width="100%" height="100%" fill="#EDB651"/>
  <g transform="translate({pad} {pad})">{isi}</g>
</svg>
'''


def lockup_horizontal(bg):
    """Tanda di kiri, nama produk di kanan."""
    name, w = glyphs('Smart Hydration Coaster', 68)
    margin, gap, mark_size = 96, 54, 300
    tx = margin + mark_size + gap
    total_w = int(tx + w + margin)
    height = 320
    mark_y = (height - mark_size) // 2
    baseline = height // 2 + 24
    fill = PALE if bg == 'dark' else INK
    background = '#0C1F27' if bg == 'dark' else '#FFFFFF'
    inner = mark('dark' if bg == 'dark' else 'light')
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {total_w} {height}" width="{total_w}" height="{height}" role="img" aria-label="Smart Hydration Coaster">
  <title>Smart Hydration Coaster</title>
{mark_defs()}  <rect width="{total_w}" height="{height}" fill="{background}"/>
  <g transform="translate({margin} {mark_y}) scale({mark_size/512:.4f})">
{inner}
  </g>
  <g fill="{fill}" transform="translate({tx} {baseline})">
      {name}
  </g>
</svg>
'''


def lockup_vertical(bg):
    """Tanda di atas, nama produk di bawah — untuk kop surat dan sampul."""
    name, w = glyphs('Smart Hydration Coaster', 58)
    mark_size = 300
    width = int(w + 160)
    tx = (width - w) / 2
    fill = PALE if bg == 'dark' else INK
    background = '#0C1F27' if bg == 'dark' else '#FFFFFF'
    inner = mark('dark' if bg == 'dark' else 'light')
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} 460" width="{width}" height="460" role="img" aria-label="Smart Hydration Coaster">
  <title>Smart Hydration Coaster</title>
{mark_defs()}  <rect width="{width}" height="460" fill="{background}"/>
  <g transform="translate({(width - mark_size) / 2} 36) scale({mark_size/512:.4f})">
{inner}
  </g>
  <g fill="{fill}" transform="translate({tx:.2f} 412)">
      {name}
  </g>
</svg>
'''



def icon(scale=0.72, pad=70):
    """Ikon PWA: tanda yang sama dengan logo, di atas bidang tinta.

    Isi diperkecil ke area aman maskable (72%) supaya tidak terpotong saat
    launcher memakai bentuk bulat atau squircle. Geometrinya tidak disalin:
    mark() dipakai apa adanya, jadi ikon tidak bisa menyimpang dari logo.
    """
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512" role="img" aria-label="Smart Hydration Coaster">
  <title>Smart Hydration Coaster</title>
  <rect width="512" height="512" rx="112" fill="#071219"/>
  <defs>
    <clipPath id="body">
      <path d="M168,158 L182,372 A74,25 0 0 0 330,372 L344,158 Z"/>
    </clipPath>
  </defs>
  <g transform="translate({pad} {pad}) scale({scale})">
{mark('dark')}
  </g>
</svg>
'''


def android_foreground(scale=0.72, pad=70):
    """Lapisan depan adaptive icon Android, dari bentuk yang sama.

    Android memakai viewport 512 dengan isi diperkecil, jadi koordinatnya
    identik dengan SVG tanda. Air diklip ke bentuk gelas; tanpa klip, persegi
    panjang air menonjol keluar dinding yang meruncing.
    """
    body = 'M168,158 L182,372 A74,25 0 0 0 330,372 L344,158 Z'
    return f'''<?xml version="1.0" encoding="utf-8"?>
<!-- Dihasilkan android_foreground() di brand/tools/build-brand.py.
     Jangan disunting manual: ubah generator agar tanda, ikon web, dan ikon
     Android tetap satu bentuk. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="512"
    android:viewportHeight="512">

    <group android:translateX="{pad}" android:translateY="{pad}"
           android:scaleX="{scale}" android:scaleY="{scale}">
        <path
            android:fillColor="#071219"
            android:pathData="M80,404 a176,54 0 1 0 352,0 a176,54 0 1 0 -352,0 z" />
        <path
            android:fillColor="#173743"
            android:strokeColor="#44C8E6"
            android:strokeWidth="13"
            android:pathData="M80,386 a176,54 0 1 0 352,0 a176,54 0 1 0 -352,0 z" />
        <path
            android:fillColor="#143440"
            android:pathData="{body}" />
        <group>
            <clip-path android:pathData="{body}" />
            <path
                android:fillColor="#44C8E6"
                android:pathData="M160,286 h192 v120 h-192 z" />
        </group>
        <path
            android:fillColor="#7FE3F4"
            android:pathData="M177,286 a79,26 0 1 0 158,0 a79,26 0 1 0 -158,0 z" />
        <path
            android:fillColor="#143440"
            android:strokeColor="#9FC4CE"
            android:strokeWidth="9"
            android:pathData="M168,158 a88,30 0 1 0 176,0 a88,30 0 1 0 -176,0 z" />
    </group>
</vector>
'''

def main():
    files = {
        'logo-mark.svg': f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512" role="img" aria-label="Smart Hydration Coaster">
  <title>Smart Hydration Coaster</title>
{mark_defs()}{mark('light')}
</svg>
''',
        'logo-mark-dark.svg': f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512" role="img" aria-label="Smart Hydration Coaster">
  <title>Smart Hydration Coaster</title>
{mark_defs()}{mark('dark')}
</svg>
''',
        'logo-horizontal-light.svg': lockup_horizontal('light'),
        'logo-horizontal-dark.svg': lockup_horizontal('dark'),
        'logo-vertical-light.svg': lockup_vertical('light'),
        'logo-vertical-dark.svg': lockup_vertical('dark'),
        'logo-sticker-yellow.svg': sticker_yellow(),
        'logo-sticker-yellow-mark.svg': sticker_yellow(with_name=False),
        'logo-sticker-yellow-preview.svg': sticker_yellow_preview(),
    }
    files['../web/icon.svg'] = icon()
    files['../app/android/app/src/main/res/drawable/ic_launcher_foreground.xml'] = android_foreground()
    for name, content in files.items():
        io.open(os.path.join(OUT, name), 'w', encoding='utf-8', newline='\n').write(content)
        print('tulis', name, len(content), 'byte')


if __name__ == '__main__':
    main()
