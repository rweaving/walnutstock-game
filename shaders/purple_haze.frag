#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform float uIntensity;
uniform float uBass;
uniform float uMid;

out vec4 fragColor;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = hash21(i);
  float b = hash21(i + vec2(1.0, 0.0));
  float c = hash21(i + vec2(0.0, 1.0));
  float d = hash21(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / max(uResolution.xy, vec2(1.0));

  // Volumetric violet walnut-dust waves & stage bloom (Track 25: Purple Haze)
  vec2 flow = uv * vec2(4.2, 3.0) + vec2(uTime * 0.14, -uTime * 0.22);
  float haze1 = noise(flow);
  float haze2 = noise(flow * 2.1 - vec2(uTime * 0.31, uTime * 0.18));
  float haze = 0.62 * haze1 + 0.38 * haze2;

  // Glowing walnut-dust motes
  vec2 dustGrid = uv * vec2(26.0, 16.0) + vec2(sin(uTime * 0.5), -uTime * 0.9);
  vec2 cell = floor(dustGrid);
  vec2 local = fract(dustGrid) - 0.5;
  float seed = hash21(cell);
  float mote = smoothstep(0.22, 0.02, length(local - 0.24 * vec2(sin(uTime + seed * 6.28), cos(uTime * 1.3 + seed * 6.28))));
  mote *= step(0.68, seed);

  vec3 deepViolet = vec3(0.38, 0.09, 0.62);
  vec3 electricMagenta = vec3(0.78, 0.28, 0.96);
  vec3 goldenDust = vec3(1.0, 0.82, 0.46);

  vec3 col = mix(deepViolet, electricMagenta, haze + 0.25 * uBass);
  col = mix(col, goldenDust, clamp(mote * (0.65 + 0.35 * uMid), 0.0, 1.0));

  float stageGlow = smoothstep(0.85, 0.0, length(uv - vec2(0.5, 0.25))) * (0.25 + 0.35 * uBass);
  float alpha = clamp(uIntensity * (0.18 + 0.26 * haze + 0.22 * mote + stageGlow), 0.0, 0.62);
  fragColor = vec4(col * alpha, alpha);
}
