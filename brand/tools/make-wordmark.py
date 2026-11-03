"""Ubah teks menjadi path SVG memakai Space Grotesk dari aset aplikasi.

Wordmark disimpan sebagai bentuk, bukan <text>, supaya berkas logo tampil sama
di komputer yang tidak memasang font tersebut.
"""
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen

FONT = 'app/assets/fonts/SpaceGrotesk-Bold.ttf'
TRACKING = 0.055


def glyph_paths(text, size):
    f = TTFont(FONT)
    gs = f.getGlyphSet()
    cmap = f.getBestCmap()
    upem = f['head'].unitsPerEm
    out, x = [], 0.0
    for ch in text:
        name = cmap.get(ord(ch))
        if name is None:
            x += size * 0.34
            continue
        pen = SVGPathPen(gs)
        gs[name].draw(pen)
        d = pen.getCommands()
        if d:
            out.append((x, d))
        x += gs[name].width * size / upem + size * TRACKING
    return out, x, upem


def path_group(text, size, dx=0.0, dy=0.0):
    paths, width, upem = glyph_paths(text, size)
    scale = size / upem
    parts = []
    for x, d in paths:
        parts.append(
            f'<path transform="translate({dx + x:.2f} {dy:.2f}) scale({scale:.5f} {-scale:.5f})" d="{d}"/>'
        )
    return '\n    '.join(parts), width


if __name__ == '__main__':
    _, w, _ = glyph_paths('SMART HYDRATION COASTER', 100)
    print(f'lebar "SMART HYDRATION COASTER" pada 100 px: {w:.1f}')
