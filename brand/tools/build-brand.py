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
    launcher memakai bentuk bulat atau squircle.
    """
    body = 'M168,158 L182,372 A74,25 0 0 0 330,372 L344,158 Z'
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512" role="img" aria-label="Smart Hydration Coaster">
  <title>Smart Hydration Coaster</title>
  <rect width="512" height="512" rx="112" fill="#0C1F27"/>
  <defs>
    <clipPath id="cup">
      <path d="{body}"/>
    </clipPath>
  </defs>
  <g transform="translate({pad} {pad}) scale({scale})">
    <ellipse cx="256" cy="404" rx="176" ry="54" fill="#0A1920"/>
    <ellipse cx="256" cy="386" rx="176" ry="54" fill="#132B35" stroke="#2FA8C4" stroke-width="13"/>
    <path d="{body}" fill="#0C1F27"/>
    <rect x="160" y="286" width="192" height="120" fill="#44C8E6" clip-path="url(#cup)"/>
    <ellipse cx="256" cy="286" rx="79" ry="26" fill="#8FE9F7"/>
    <ellipse cx="256" cy="158" rx="88" ry="30" fill="#0C1F27" stroke="#8FB3BD" stroke-width="9"/>
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
<!-- Dihasilkan brand/tools/build-brand.py. Jangan disunting manual: ubah
     generator agar tanda, ikon web, dan ikon Android tetap satu bentuk. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="512"
    android:viewportHeight="512">

    <group android:translateX="{pad}" android:translateY="{pad}"
           android:scaleX="{scale}" android:scaleY="{scale}">
        <path
            android:fillColor="#0A1920"
            android:pathData="M80,404 a176,54 0 1 0 352,0 a176,54 0 1 0 -352,0 z" />
        <path
            android:fillColor="#132B35"
            android:strokeColor="#2FA8C4"
            android:strokeWidth="13"
            android:pathData="M80,386 a176,54 0 1 0 352,0 a176,54 0 1 0 -352,0 z" />
        <path
            android:fillColor="#0C1F27"
            android:pathData="{body}" />
        <group>
            <clip-path android:pathData="{body}" />
            <path
                android:fillColor="#44C8E6"
                android:pathData="M160,286 h192 v120 h-192 z" />
        </group>
        <path
            android:fillColor="#8FE9F7"
            android:pathData="M177,286 a79,26 0 1 0 158,0 a79,26 0 1 0 -158,0 z" />
        <path
            android:fillColor="#0C1F27"
            android:strokeColor="#8FB3BD"
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
    }
    files['../web/icon.svg'] = icon()
    files['../app/android/app/src/main/res/drawable/ic_launcher_foreground.xml'] = android_foreground()
    for name, content in files.items():
        io.open(os.path.join(OUT, name), 'w', encoding='utf-8', newline='\n').write(content)
        print('tulis', name, len(content), 'byte')


if __name__ == '__main__':
    main()
