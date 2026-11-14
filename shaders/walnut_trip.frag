#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform float uIntensity;
uniform float uBass;
uniform float uMid;

out vec4 fragColor;

vec3 palette(float t) {
  vec3 a = vec3(0.55, 0.45, 0.35);
  vec3 b = vec3(0.45, 0.42, 0.48);
  vec3 c = vec3(1.0, 1.0, 1.0);
  vec3 d = vec3(0.08, 0.38, 0.67);
  return a + b * cos(6.28318 * (c * t + d));
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = (fragCoord * 2.0 - uResolution.xy) / max(uResolution.y, 1.0);
  vec2 uv0 = uv;

  // Kaleidoscopic breathing driven by Track 22 ("The Walnut Trip") bass & mid FFT
  float angle = atan(uv.y, uv.x + 1e-5);
  float radius = length(uv);
  float folds = 6.0;
  angle = mod(angle, 6.28318 / folds) - (3.14159 / folds);
  uv = vec2(cos(angle), sin(angle)) * radius * (1.0 - 0.14 * uBass * sin(uTime * 1.7));

  vec3 col = vec3(0.0);
  for (float i = 0.0; i < 3.0; i += 1.0) {
    uv = fract(uv * 1.45) - 0.5;
    float d = length(uv) * exp(-length(uv0));
    vec3 pCol = palette(length(uv0) + i * 0.35 + uTime * 0.28 + uMid * 0.25);
    d = sin(d * 8.0 + uTime * 1.6) / 8.0;
    d = abs(d);
    d = pow(0.014 / max(d, 0.004), 1.05);
    col += pCol * d;
  }

  col = clamp(col, 0.0, 1.0);
  float vignette = smoothstep(0.15, 1.35, length(uv0));
  float alpha = clamp(uIntensity * (0.20 + 0.22 * vignette + 0.12 * uBass), 0.0, 0.58);
  fragColor = vec4(col * alpha, alpha);
}
