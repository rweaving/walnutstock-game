#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform float uIntensity;
uniform float uBass;
uniform float uMid;

out vec4 fragColor;

vec3 rainbowSpectrum(float t) {
  // Vivid ROYGBIV + Electric Purple Blueberry cosine spectrum
  vec3 a = vec3(0.54, 0.50, 0.56);
  vec3 b = vec3(0.46, 0.48, 0.44);
  vec3 c = vec3(1.0, 1.0, 1.0);
  vec3 d = vec3(0.00, 0.33, 0.67);
  return clamp(a + b * cos(6.28318 * (c * t + d)), 0.0, 1.0);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 res = max(uResolution.xy, vec2(1.0));
  vec2 uv = (fragCoord * 2.0 - res) / res.y;

  // Multi-layered liquid creek-wave domain warp
  float waveA = sin(uv.x * 4.8 + uTime * 2.3 + uBass * 1.8) * 0.16;
  float waveB = cos(uv.y * 5.4 - uTime * 1.9 + uMid * 1.5) * 0.14;
  float waveC = sin((uv.x + uv.y) * 3.6 - uTime * 1.4) * 0.11;
  vec2 wuv = uv + vec2(waveB + waveC, waveA - waveC);

  // Flowing sinusoidal rainbow ribbons + concentric electric-berry ripples
  float ribbonPhase = wuv.y * 2.1 + sin(wuv.x * 3.4 + uTime * 1.7) * 0.42 - uTime * 0.38;
  float ripple = sin(length(wuv) * 9.5 - uTime * 3.1 + uBass * 2.4) * 0.5 + 0.5;

  vec3 rainbow = rainbowSpectrum(ribbonPhase + ripple * 0.22);
  vec3 electricBerry = vec3(0.62, 0.18, 1.00);
  vec3 col = mix(rainbow, electricBerry, 0.20 + 0.14 * sin(uTime * 2.0 + length(uv) * 4.0));

  // Crisp luminous wave crests
  float crest = pow(0.5 + 0.5 * sin(wuv.y * 12.0 + sin(wuv.x * 5.0 + uTime * 2.4) * 2.2), 3.0);
  col = clamp(col + crest * 0.24, 0.0, 1.0);

  float edge = smoothstep(0.10, 1.28, length(uv));
  float waveBand = 0.5 + 0.5 * sin(ribbonPhase * 6.28318);
  float alpha = clamp(
    uIntensity * (0.19 + 0.12 * waveBand + 0.10 * edge + 0.10 * uBass),
    0.0,
    0.52
  );
  fragColor = vec4(col * alpha, alpha);
}
