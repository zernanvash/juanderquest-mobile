"""Bamboo cosmetic frame (Plan 104b step 1, drawn by the orchestrator).

Every pixel is placed by this script in the JuanderQuest palette; nothing is
traced or copied from a reference sheet. Run from anywhere:

    python -I tool/pixel_art/frames/make_bamboo.py

Writes assets/frames/bamboo/{corner-*,edge-*,fill}.png and frame.json.

How the pieces fit (sizes in art pixels; the app draws 1 art px per grid
unit, nearest-neighbour):
  * E = 10: edge thickness on every side. Top and bottom edges carry a 4 px
    transparent outset (pole caps and leaf tips poke into it) and a 6 px
    bamboo bar; left and right edges carry a 2 px outset and an 8 px pole.
  * C = 32: corner size. Corners are drawn last, over the edges, so they
    hold only the joint (the E x E square) plus the ornaments; everything
    else in them is transparent and the edges show through.
  * Edges repeat along their length (top/bottom every TH, sides every TV);
    fill.png tiles inside the E inset.
"""
import json
import math
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, 'assets', 'frames', 'bamboo')

E = 10    # edge thickness
C = 32    # corner size
T = 16    # fill tile size
TH = 48   # top/bottom edge repeat (one node per repeat)
TV = 24   # left/right edge repeat (one node per repeat)
W = 2 * C + TH    # the working canvas
H = 2 * C + TV


def palette():
    data = json.load(open(os.path.join(ROOT, 'tool', 'pixel_art',
                                       'palette.json'), encoding='utf-8'))
    named = {}
    pending = list(data['colors'])
    while pending:
        rest = []
        for c in pending:
            if 'hex' in c:
                h = c['hex']
                named[c['name']] = tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
            elif c['mix'][0] in named and c['mix'][1] in named:
                a, b, t = named[c['mix'][0]], named[c['mix'][1]], c['mix'][2]
                named[c['name']] = tuple(round(a[i] + (b[i] - a[i]) * t)
                                         for i in range(3))
            else:
                rest.append(c)
        pending = rest
    return named


P = palette()

# Letters used in the drawing below.
K = {
    'O': 'greenDeep',    # outline
    'D': 'greenDark',
    'B': 'greenBright',
    'G': 'green',
    'M': 'greenMid',
    'L': 'greenLight',
    'w': 'woodDeep',     # lashing cord, dark
    'm': 'woodMid',
    'l': 'woodLight',    # lashing cord, light
    'c': 'cream',        # warm highlight on the cut cap
    's': 'sunLight',
}


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = {}

    def put(self, x, y, key):
        if 0 <= x < self.w and 0 <= y < self.h and key not in '. ':
            self.px[(x, y)] = key

    def stamp(self, x0, y0, rows):
        for dy, row in enumerate(rows):
            for dx, ch in enumerate(row):
                self.put(x0 + dx, y0 + dy, ch)

    def image(self, box=None, keep=None):
        x0, y0, x1, y1 = box or (0, 0, self.w, self.h)
        im = Image.new('RGBA', (x1 - x0, y1 - y0), (0, 0, 0, 0))
        for (x, y), k in self.px.items():
            if x0 <= x < x1 and y0 <= y < y1 and (keep is None or keep(x, y)):
                im.putpixel((x - x0, y - y0), P[K[k]] + (255,))
        return im


# ---- bamboo pieces ------------------------------------------------------
# Light comes from the top left: poles are lit on their left side and bars
# on their top side, on every edge (so the pieces are not plain mirrors).
POLE = 'OMLMGBDO'          # left to right, 8 px
BAR = 'OLMGDO'             # top to bottom, 6 px


def pole(cv, x, y0, y1, node_phase=0):
    """Vertical pole, columns x..x+7, rows y0..y1-1, a node every TV rows.
    A node is a groove with a lit ridge under it."""
    for y in range(y0, y1):
        n = (y - node_phase) % TV
        for i, k in enumerate(POLE):
            if n == 0 and 0 < i < 7:
                k = 'O'                      # the node's groove
            elif n == 1 and 0 < i < 7:
                k = 'L' if i < 4 else 'M'    # ridge lit from above
            elif n == TV - 1 and 0 < i < 7:
                k = 'D' if i > 3 else 'G'    # shadow above the groove
            cv.put(x + i, y, k)


def bar(cv, y, x0, x1, node_phase=0):
    """Horizontal bar, rows y..y+5, columns x0..x1-1, a node every TH cols."""
    for x in range(x0, x1):
        n = (x - node_phase) % TH
        for i, k in enumerate(BAR):
            if n == 0 and 0 < i < 5:
                k = 'O'
            elif n == 1 and 0 < i < 5:
                k = 'L' if i < 3 else 'M'
            elif n == TH - 1 and 0 < i < 5:
                k = 'D' if i > 2 else 'G'
            cv.put(x, y + i, k)


def leaf(cv, ox, oy, angle_deg, length, width):
    """A bamboo leaf from (ox, oy) along angle_deg (0 = right, negative =
    up), pointed at both ends and widest a third of the way out. The half
    that faces the light (top left) is lit (greenLight rim, greenMid), the
    other half is in shade (green, greenBright); a light midrib; a 1 px
    outline. Drawn over whatever is already there, outline included, so a
    later leaf sits cleanly in front of an earlier one."""
    a = math.radians(angle_deg)
    ux, uy = math.cos(a), math.sin(a)
    # Normal of the d < 0 half is (uy, -ux); it is lit if it faces the light.
    lit_neg = (uy * -0.45 + -ux * -0.9) > 0
    body = {}
    r = int(length + width) + 2
    for y in range(oy - r, oy + r + 1):
        for x in range(ox - r, ox + r + 1):
            dx, dy = x + 0.5 - ox, y + 0.5 - oy
            t = dx * ux + dy * uy               # along the leaf
            d = -dx * uy + dy * ux              # across it (+ = lower side)
            if not 0 <= t <= length:
                continue
            f = t / length
            hw = width / 2 * (math.sin(math.pi * f ** 0.7) ** 0.9)
            if abs(d) > hw:
                continue
            if abs(d) < 0.5 and 0.2 < f < 0.8:
                k = 'L'                          # midrib
            elif (d < 0) == lit_neg:
                k = 'L' if abs(d) > hw - 1.0 and f < 0.55 else 'M'
            else:
                k = 'G' if abs(d) < hw * 0.6 else 'B'
            body[(x, y)] = k
    for (x, y) in list(body):
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if (nx, ny) not in body:
                cv.put(nx, ny, 'O')
    for (x, y), k in body.items():
        cv.put(x, y, k)


CAP = [            # the cut top of a pole, 8 wide; rises above the bar
    '.OOOOOO.',
    'OcsLLMDO',
    'OsLMMGDO',
    'ODDDDDDO',
]
BASE = [           # the cut bottom, below the bottom bar
    'OMLMGBDO',
    '.OOOOOO.',
]
LASH = [           # cord wrapped round the pole where a bar meets it
    'Olllmmw.',
    'Ommmwwww',
    'Olllmmw.',
]


def frame():
    """The whole frame on a W x H canvas: base layer and ornaments."""
    base = Canvas(W, H)
    orn = Canvas(W, H)
    # Bars run behind the poles.
    bar(base, 4, 2, W - 2, node_phase=C + 30)
    bar(base, H - E, 2, W - 2, node_phase=C + 12)
    for x in (2, W - E):
        pole(base, x, 0, H, node_phase=C + 14)

    for x in (2, W - E):
        orn.stamp(x, 1, CAP)
        orn.stamp(x, 5, LASH)
        orn.stamp(x, H - E + 1, LASH)
        orn.stamp(x, H - E + 6, BASE)
    # Leaves: two from the top-left joint spreading right along the top bar
    # (one rises into the outset, one droops over the inner corner), and the
    # same pair from the bottom-right joint spreading left. Drawn, not
    # rotated, so both clusters take the light from the top left.
    for (ox, oy, ang, ln, wd) in ((9, 8, 20, 14, 5.0),
                                  (9, 6, -9, 22, 6.0)):
        leaf(orn, ox, oy, ang, ln, wd)
        leaf(orn, W - 1 - ox, H - 1 - oy, ang + 180, ln, wd)
    full = Canvas(W, H)
    full.px = dict(base.px)
    full.px.update(orn.px)
    return base, orn, full


def fill_tile():
    """16 x 16 woven paper: parchment with paperDim diagonal ticks that
    switch direction every 4 rows (a light weave). Tones stay close so ink
    text reads on it."""
    im = Image.new('RGBA', (T, T))
    for y in range(T):
        for x in range(T):
            band = (y // 4) % 2
            tick = ((x + y) % 8 == 0) if band == 0 else ((x - y) % 8 == 0)
            im.putpixel((x, y), P['paperDim' if tick else 'parchment'] + (255,))
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    base, orn, full = frame()

    def corner_keep(right, bottom):
        # Keep the E x E joint square from the base; the rest of the corner
        # comes from the ornament layer only, so the edges show through.
        def keep(x, y):
            jx = (W - 1 - x) if right else x
            jy = (H - 1 - y) if bottom else y
            return (jx < E and jy < E) or (x, y) in orn.px
        return keep

    pieces = {
        'corner-tl.png': full.image((0, 0, C, C), corner_keep(0, 0)),
        'corner-tr.png': full.image((W - C, 0, W, C), corner_keep(1, 0)),
        'corner-bl.png': full.image((0, H - C, C, H), corner_keep(0, 1)),
        'corner-br.png': full.image((W - C, H - C, W, H), corner_keep(1, 1)),
        'edge-top.png': base.image((C, 0, C + TH, E)),
        'edge-bottom.png': base.image((C, H - E, C + TH, H)),
        'edge-left.png': base.image((0, C, E, C + TV)),
        'edge-right.png': base.image((W - E, C, W, C + TV)),
        'fill.png': fill_tile(),
    }
    for name, im in pieces.items():
        im.save(os.path.join(OUT, name))
    meta = {
        'name': 'bamboo',
        'edge': E,
        'corner': C,
        'text': 'ink',
        'files': sorted(pieces),
    }
    with open(os.path.join(OUT, 'frame.json'), 'w', encoding='utf-8',
              newline='\n') as f:
        json.dump(meta, f, indent=2)
        f.write('\n')
    print('wrote', OUT)


if __name__ == '__main__':
    sys.exit(main())
