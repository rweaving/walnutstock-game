#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform float uIntensity;
uniform float uBass;
uniform float uMid;

out vec4 fragColor;

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = (fragCoord - 0.5 * uResolution.xy) / max(uResolution.y, 1.0);

  // Retro-70s Andromeda Pavilion cosmic nebula & crystal starfield
  float r = length(uv);
  float a = atan(uv.y, uv.x + 1e-5);
  float ribbon = sin(a * 3.0 + r * 7.0 - uTime * 1.2) * 0.5 + 0.5;
  float aurora = sin(uv.x * 5.5 + sin(uv.y * 4.0 + uTime * 0.8)) * 0.5 + 0.5;

  vec3 teal = vec3(0.18, 0.88, 0.84);
  vec3 cosmicViolet = vec3(0.45, 0.16, 0.82);
  vec3 starlightGold = vec3(1.0, 0.84, 0.45);

  vec3 col = mix(cosmicViolet, teal, ribbon * 0.7 + 0.3 * aurora);
  col += starlightGold * (0.18 * uBass * smoothstep(0.7, 0.0, r));

  // Twinkling stars
  vec2 starUv = floor((uv + vec2(uTime * 0.02, 0.0)) * 38.0);
  float starSeed = hash(starUv);
  float twinkle = 0.5 + 0.5 * sin(uTime * 4.0 + starSeed * 30.0);
  if (starSeed > 0.965) {
    col += vec3(0.9, 0.96, 1.0) * twinkle * (0.6 + 0.4 * uMid);
  }

  float alpha = clamp(uIntensity * (0.22 + 0.18 * ribbon + 0.12 * uBass), 0.0, 0.55);
  fragColor = vec4(col * alpha, alpha);
}
