#version 460 core

// Pixel map: snap the real map to a coarse grid, then quantise every cell to
// the JuanderQuest brand palette with 4x4 ordered (Bayer) dithering.
// Used through ImageFilter.shader: the engine sets uSize and uTexture.

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;     // set by the engine: size of the filtered texture
uniform float uCell;    // cell size in device pixels (set from Dart, index 2)
uniform float uSpread;  // dither strength 0..0.3 (index 3, e.g. 0.12)
uniform sampler2D uTexture;

out vec4 fragColor;

float bayer2(vec2 a) {
  a = floor(a);
  return fract(a.x / 2.0 + a.y * a.y * 0.75);
}

float bayer4(vec2 a) {
  return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

void pick(vec3 c, vec3 p, inout vec3 best, inout float bestD) {
  vec3 d = c - p;
  float dist = dot(d, d);
  if (dist < bestD) {
    bestD = dist;
    best = p;
  }
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 cell = floor(frag / uCell);
  // Average a 3x3 grid of samples inside the cell (box filter): thin roads
  // and labels blend into the cell colour instead of becoming random dots.
  vec4 src = vec4(0.0);
  for (int i = 0; i < 3; i++) {
    for (int j = 0; j < 3; j++) {
      vec2 uv = ((cell + vec2(0.17 + 0.33 * float(i), 0.17 + 0.33 * float(j))) * uCell) / uSize;
#ifdef IMPELLER_TARGET_OPENGLES
      uv.y = 1.0 - uv.y;
#endif
      src += texture(uTexture, uv);
    }
  }
  src /= 9.0;
  if (src.a < 0.01) {
    fragColor = vec4(0.0);
    return;
  }
  vec3 c = src.rgb / src.a;
  c += (bayer4(cell) - 0.5) * uSpread;

  vec3 best = vec3(0.0);
  float bestD = 1e9;

  // Brand palette (19 colours from tool/pixel_art/palette.json)
  // Land and urban
  pick(c, vec3(0.980, 0.976, 0.961), best, bestD); // paper
  pick(c, vec3(0.890, 0.886, 0.875), best, bestD); // paperDim
  pick(c, vec3(1.000, 0.973, 0.882), best, bestD); // cream
  pick(c, vec3(0.969, 0.922, 0.882), best, bestD); // parchment
  pick(c, vec3(0.757, 0.784, 0.761), best, bestD); // mist
  pick(c, vec3(0.443, 0.475, 0.451), best, bestD); // stone
  // Roads and labels
  pick(c, vec3(1.000, 1.000, 1.000), best, bestD); // white
  pick(c, vec3(0.255, 0.282, 0.267), best, bestD); // slate
  pick(c, vec3(0.051, 0.106, 0.165), best, bestD); // ink
  // Water
  pick(c, vec3(0.878, 0.949, 0.996), best, bestD); // sky
  pick(c, vec3(0.859, 0.918, 0.996), best, bestD); // blueLight
  pick(c, vec3(0.106, 0.286, 0.396), best, bestD); // blue
  // Parks and fields
  pick(c, vec3(0.757, 0.925, 0.831), best, bestD); // greenLight
  pick(c, vec3(0.247, 0.400, 0.325), best, bestD); // green
  pick(c, vec3(0.153, 0.306, 0.235), best, bestD); // greenDark
  // Sand and beaches
  pick(c, vec3(1.000, 0.871, 0.663), best, bestD); // sunLight
  pick(c, vec3(0.769, 0.612, 0.431), best, bestD); // woodLight
  // Highlights
  pick(c, vec3(1.000, 0.718, 0.012), best, bestD); // sun
  pick(c, vec3(0.902, 0.494, 0.133), best, bestD); // orange

  fragColor = vec4(best * src.a, src.a);
}
