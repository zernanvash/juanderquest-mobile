"""Assemble a frame from its pieces the same way the app does, for review.

    python -I tool/pixel_art/frames/preview_frame.py bamboo out.png

Draws the frame around a 180 x 72 player card and a 180 x 40 Passport
header, at 4x, on paper.
"""
import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))


def assemble(d, w, h):
    meta = json.load(open(os.path.join(d, 'frame.json'), encoding='utf-8'))
    e, c = meta['edge'], meta['corner']
    load = lambda n: Image.open(os.path.join(d, n)).convert('RGBA')
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    fill = load('fill.png')
    t = fill.width
    for y in range(e, h - e, t):
        for x in range(e, w - e, t):
            tile = fill.crop((0, 0, min(t, w - e - x), min(t, h - e - y)))
            im.alpha_composite(tile, (x, y))
    for name, horiz, pos in (('edge-top.png', True, 0),
                             ('edge-bottom.png', True, h - e),
                             ('edge-left.png', False, 0),
                             ('edge-right.png', False, w - e)):
        piece = load(name)
        t = piece.width if horiz else piece.height
        span = w - 2 * e if horiz else h - 2 * e
        for k in range(0, span, t):
            n = min(t, span - k)
            if horiz:
                im.alpha_composite(piece.crop((0, 0, n, e)), (e + k, pos))
            else:
                im.alpha_composite(piece.crop((0, 0, e, n)), (pos, e + k))
    im.alpha_composite(load('corner-tl.png'), (0, 0))
    im.alpha_composite(load('corner-tr.png'), (w - c, 0))
    im.alpha_composite(load('corner-bl.png'), (0, h - c))
    im.alpha_composite(load('corner-br.png'), (w - c, h - c))
    return im


def main(name, out):
    d = os.path.join(ROOT, 'assets', 'frames', name)
    paper = (0xFA, 0xF9, 0xF5, 255)
    sheet = Image.new('RGBA', (200, 140), paper)
    sheet.alpha_composite(assemble(d, 180, 72), (10, 6))
    sheet.alpha_composite(assemble(d, 180, 40), (10, 90))
    sheet.resize((800, 560), Image.NEAREST).save(out)
    print('wrote', out)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
