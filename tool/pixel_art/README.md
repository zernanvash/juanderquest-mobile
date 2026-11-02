# Pixel art pipeline

Turns designer PNGs (drawn 1 px per art pixel) into brand-palette pixel data that the app draws pixel-perfect.

1. Put the PNG in the workspace `assets/` folder. One sprite per file; animations go in a horizontal strip of equal frames.
2. Add an entry to `assets.json`: `name`, `file`, and for strips `frameWidth` (plus `frameCount`/`trim` if the strip has gaps, and `fps`).
3. From `juanderquest_app/`, run `python tool/pixel_art/png_to_dart.py --root .. --review /tmp/review.png`. This needs Pillow.
4. Check the review sheet: original on top, brand palette underneath. Commit the regenerated `lib/core/pixel/generated/*.g.dart`.

`palette.json` is the single source of the pixel palette. Each colour is either a brand colour (mobile `AppColors` or web `globals.css`) or a documented mix of two brand colours. Keys are permanent, so append new colours and never reorder.

Preview everything in a debug build at Settings → Developer tools → Pixel lab.

## For the artist

Load `juanderquest-pixel.gpl` (GIMP/Aseprite), `juanderquest-pixel.hex` (Lospec/Aseprite) or `juanderquest-pixel-palette.png` (a 1 px swatch strip) into your drawing tool and draw only with these colours. Then the converter changes nothing.

- Draw at **1 px per art pixel** on a **transparent** background, with no anti-aliasing (pencil tool, not brush).
- **Sizes:**
  - nav and action icons 24×24
  - item, stamp and badge icons 36×36
  - characters 32×48
  - map pins 16×24
- **Animations:** one horizontal strip of equal-size frames, no gaps. Tell us the fps (idle loops 8, effects 12, hearts 16).
- **Export:** PNG. Name files in `kebab-case` (`heart-liked.png`, `juan-wave.png`) and put them in the workspace `assets/` folder.
- **Outlines:** use `ink` (0D1B2A), not pure black, so the art matches the UI outlines.
- Don't scale art up before exporting; the app scales it by whole numbers.
