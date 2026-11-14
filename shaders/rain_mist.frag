#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform float uIntensity;
uniform float uBass;
uniform float uMid;

out vec4 fragColor;

float hash21(vec2 p) {
  p = fract(p * vec2(234.34, 435.345));
  p += dot(p, p + 34.23);
  return fract(p.x * p.y);
}

float rainLayer(vec2 uv, vec2 scale, float speed, float slant, float density, float thickness) {
  vec2 p = uv;
  p.x += p.y * slant + sin(uTime * 0.6) * 0.02;
  vec2 st = p * scale + vec2(-uTime * speed * 0.08, -uTime * speed);
  vec2 id = floor(st);
  vec2 f = fract(st);
  float rnd = hash21(id);
  float jitter = (rnd - 0.5) * 0.42;
  float xDist = abs(f.x - 0.5 + jitter);
  float drop = smoothstep(thickness, thickness * 0.15, xDist) *
               smoothstep(0.96, 0.08, f.y) *
               smoothstep(0.0, 0.08, f.y) *
               step(density, rnd);
  return drop;
}

float cloudNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = hash21(i);
  float b = hash21(i + vec2(1.0, 0.0));
  float c = hash21(i + vec2(0.0, 1.0));
  float d = hash21(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / max(uResolution.xy, vec2(1.0));

  // Mode weights from uMid:
  //   0.15 -> Post-storm sunlit morning mist + sunbeams
  //   0.52 -> Pre-storm humid rolling overcast
  //   0.90 -> Full Saturday Blight Rainstorm (3D multi-depth rain curtains + lightning)
  float wMist = 1.0 - smoothstep(0.25, 0.45, uMid);
  float wRain = smoothstep(0.65, 0.82, uMid);
  float wPreStorm = clamp(1.0 - wMist - wRain, 0.0, 1.0);

  // Rolling atmospheric cloud turbulence
  float c1 = cloudNoise(uv * vec2(4.5, 2.8) + vec2(uTime * 0.16, uTime * 0.05));
  float c2 = cloudNoise(uv * vec2(9.0, 5.5) - vec2(uTime * 0.28, -uTime * 0.09));
  float clouds = c1 * 0.62 + c2 * 0.38;

  // 3 depth-parallax rain layers (far fine sheet, mid rain, foreground close drops)
  float rFar = rainLayer(uv, vec2(68.0, 18.0), 6.2, 0.24, 0.66, 0.10) * 0.45;
  float rMid = rainLayer(uv + vec2(0.17, 0.31), vec2(42.0, 11.0), 8.8, 0.30, 0.72, 0.09) * 0.78;
  float rNear = rainLayer(uv + vec2(0.43, 0.11), vec2(22.0, 6.5), 12.4, 0.36, 0.80, 0.075) * 1.15;
  float streak = clamp(rFar + rMid + rNear, 0.0, 1.25);

  // Periodic distant sheet-lightning pulse during rainstorm
  float boltWave = pow(max(0.0, sin(uTime * 0.67) * sin(uTime * 2.93)), 14.0);
  float lightning = boltWave * wRain;

  vec3 stormBase = mix(vec3(0.09, 0.15, 0.25), vec3(0.18, 0.27, 0.40), clouds);
  vec3 rainCol = mix(stormBase, vec3(0.76, 0.89, 1.0), clamp(streak * 0.85, 0.0, 1.0));
  rainCol += vec3(0.75, 0.84, 1.0) * lightning * 0.55;
  float rainAlpha = 0.16 + 0.10 * clouds + 0.36 * clamp(streak, 0.0, 1.0) + 0.07 * uBass + 0.22 * lightning;

  // Pre-storm humid brooding clouds + subtle wind wisps
  float wisp = rainLayer(uv, vec2(28.0, 4.0), 2.8, 0.55, 0.88, 0.08) * 0.25;
  vec3 preCol = mix(vec3(0.20, 0.28, 0.34), vec3(0.42, 0.46, 0.44), clouds) + vec3(0.55) * wisp;
  float preAlpha = 0.10 + 0.14 * clouds * (1.0 - uv.y * 0.35) + wisp * 0.15;

  // Post-storm sunlit mist + diagonal golden crepuscular sunbeams
  float mistWave = 0.5 + 0.5 * sin(uv.x * 6.0 + uTime * 0.42 + sin(uv.y * 5.0 - uTime * 0.28));
  float rayCoord = (uv.x * 1.15 - uv.y * 0.55) * 9.0 - uTime * 0.18;
  float sunRay = pow(0.5 + 0.5 * sin(rayCoord), 5.0) * (1.0 - uv.y * 0.65);
  vec3 mistCol = mix(vec3(0.84, 0.92, 0.89), vec3(1.0, 0.92, 0.66), clamp(sunRay * 1.2 + (1.0 - uv.y) * 0.45, 0.0, 1.0));
  float mistAlpha = 0.10 + 0.13 * mistWave * (1.0 - uv.y * 0.4) + 0.14 * sunRay;

  vec3 col = mistCol * wMist + preCol * wPreStorm + rainCol * wRain;
  float rawAlpha = mistAlpha * wMist + preAlpha * wPreStorm + rainAlpha * wRain;
  float alpha = clamp(uIntensity * rawAlpha, 0.0, 0.66);
  fragColor = vec4(col * alpha, alpha);
}
