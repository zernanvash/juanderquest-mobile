#version 460 core

// Background "gradient" the pixel way: vertical bands between two colours,
// blended with 4x4 ordered dithering on a coarse grid. No image assets.

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;    // index 0-1: widget size in logical px
uniform float uCell;   // index 2: art pixel size in logical px
uniform vec4 uTop;     // index 3-6: top colour (rgba, 0..1)
uniform vec4 uBottom;  // index 7-10: bottom colour
uniform float uBands;  // index 11: number of colour steps

out vec4 fragColor;

float bayer2(vec2 a) {
  a = floor(a);
  return fract(a.x / 2.0 + a.y * a.y * 0.75);
}

float bayer4(vec2 a) {
  return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

void main() {
  vec2 cell = floor(FlutterFragCoord().xy / uCell);
  float rows = max(uSize.y / uCell, 1.0);
  float t = clamp(cell.y / rows, 0.0, 1.0);
  // Quantise t into bands, dither between neighbouring bands.
  float scaled = t * uBands;
  float base = floor(scaled);
  float frac = scaled - base;
  float step = base + (frac > bayer4(cell) ? 1.0 : 0.0);
  float k = clamp(step / uBands, 0.0, 1.0);
  fragColor = mix(uTop, uBottom, k);
}
