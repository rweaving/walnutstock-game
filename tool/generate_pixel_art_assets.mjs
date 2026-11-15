#!/usr/bin/env node
/**
 * Walnutstock Refined 2.5D / 3D-Shaded Asset, Tileset, 9-Zone TMX & Totem Generator
 * Pure Node.js (uses built-in node:zlib + CRC32 PNG writer — zero external deps).
 *
 * Upgrades all 50 tiles, 28 character sprite sheets & portraits, and 8 totems with
 * per-pixel 3D surface normal lighting, Blinn-Phong specular highlights, ambient occlusion,
 * walnut convolution bump-mapping, 2.5D oblique bevels, and complete headwear/instruments.
 */

import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');

// --- Minimal Pure-JS PNG Encoder ---
const CRC_TABLE = new Uint32Array(256);
for (let n = 0; n < 256; n++) {
  let c = n;
  for (let k = 0; k < 8; k++) {
    c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
  }
  CRC_TABLE[n] = c >>> 0;
}

function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) {
    c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  }
  return (c ^ 0xffffffff) >>> 0;
}

function pngChunk(type, data) {
  const typeBuf = Buffer.from(type, 'ascii');
  const lenBuf = Buffer.alloc(4);
  lenBuf.writeUInt32BE(data.length, 0);
  const crcInput = Buffer.concat([typeBuf, data]);
  const crcBuf = Buffer.alloc(4);
  crcBuf.writeUInt32BE(crc32(crcInput), 0);
  return Buffer.concat([lenBuf, typeBuf, data, crcBuf]);
}

function clampByte(v) {
  return v < 0 ? 0 : v > 255 ? 255 : Math.round(v);
}

class PixelCanvas {
  constructor(w, h) {
    this.w = w;
    this.h = h;
    this.data = new Uint8Array(w * h * 4);
  }

  setPixel(x, y, rgba) {
    const ix = Math.floor(x);
    const iy = Math.floor(y);
    if (ix < 0 || iy < 0 || ix >= this.w || iy >= this.h) return;
    const idx = (iy * this.w + ix) * 4;
    const sa = (rgba[3] ?? 255) / 255;
    if (sa >= 0.999 || this.data[idx + 3] === 0) {
      this.data[idx] = clampByte(rgba[0]);
      this.data[idx + 1] = clampByte(rgba[1]);
      this.data[idx + 2] = clampByte(rgba[2]);
      this.data[idx + 3] = clampByte(rgba[3] ?? 255);
      return;
    }
    const da = this.data[idx + 3] / 255;
    const outA = sa + da * (1 - sa);
    if (outA <= 0.001) return;
    this.data[idx] = clampByte((rgba[0] * sa + this.data[idx] * da * (1 - sa)) / outA);
    this.data[idx + 1] = clampByte((rgba[1] * sa + this.data[idx + 1] * da * (1 - sa)) / outA);
    this.data[idx + 2] = clampByte((rgba[2] * sa + this.data[idx + 2] * da * (1 - sa)) / outA);
    this.data[idx + 3] = clampByte(outA * 255);
  }

  putRaw(x, y, rgba) {
    const ix = Math.floor(x);
    const iy = Math.floor(y);
    if (ix < 0 || iy < 0 || ix >= this.w || iy >= this.h) return;
    const idx = (iy * this.w + ix) * 4;
    this.data[idx] = clampByte(rgba[0]);
    this.data[idx + 1] = clampByte(rgba[1]);
    this.data[idx + 2] = clampByte(rgba[2]);
    this.data[idx + 3] = clampByte(rgba[3] ?? 255);
  }

  fillRect(x, y, w, h, rgba) {
    for (let dy = 0; dy < h; dy++) {
      for (let dx = 0; dx < w; dx++) {
        this.setPixel(x + dx, y + dy, rgba);
      }
    }
  }

  fillEllipse(cx, cy, rx, ry, rgba) {
    for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++) {
      for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
        const nx = (x - cx) / rx;
        const ny = (y - cy) / ry;
        if (nx * nx + ny * ny <= 1.0) {
          this.setPixel(x, y, rgba);
        }
      }
    }
  }

  strokeEllipse(cx, cy, rx, ry, rgba) {
    for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++) {
      for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
        const nx = (x - cx) / rx;
        const ny = (y - cy) / ry;
        const d = nx * nx + ny * ny;
        if (d <= 1.0 && d >= 0.72) {
          this.setPixel(x, y, rgba);
        }
      }
    }
  }

  /**
   * Renders a 3D normal-shaded ellipsoid with Blinn-Phong specular, rim light & optional bump fn.
   */
  fillLitEllipsoid(cx, cy, rx, ry, baseRgba, opts = {}) {
    const specStrength = opts.specStrength ?? 0.28;
    const specPower = opts.specPower ?? 18.0;
    const rimStrength = opts.rimStrength ?? 0.22;
    const outline = opts.outline ?? null;
    const bumpFn = opts.bumpFn ?? null;
    const alpha = baseRgba[3] ?? 255;

    if (outline) {
      this.fillEllipse(cx, cy, rx + 0.9, ry + 0.9, outline);
    }

    // Key sun light from upper-left-front (-0.42, -0.52, 0.74)
    const lx = -0.42;
    const ly = -0.52;
    const lz = 0.74;
    // Halfway vector with viewer (0, 0, 1)
    const hx = -0.24;
    const hy = -0.30;
    const hz = 0.92;

    for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++) {
      for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
        let nx = (x - cx) / rx;
        let ny = (y - cy) / ry;
        const r2 = nx * nx + ny * ny;
        if (r2 > 1.0) continue;
        let nz = Math.sqrt(Math.max(0.02, 1.0 - r2));

        let colorBase = baseRgba;
        if (bumpFn) {
          const mod = bumpFn(nx, ny, nz, x - cx, y - cy);
          if (mod) {
            nx += mod.dnx ?? 0;
            ny += mod.dny ?? 0;
            if (mod.color) colorBase = mod.color;
            const len = Math.hypot(nx, ny, nz) || 1;
            nx /= len;
            ny /= len;
            nz /= len;
          }
        }

        const ndotl = Math.max(0, nx * lx + ny * ly + nz * lz);
        const hemi = 0.5 - 0.5 * ny; // sky top vs ground bounce
        const diffuse = 0.42 + 0.68 * ndotl + 0.08 * hemi;
        const spec = Math.pow(Math.max(0, nx * hx + ny * hy + nz * hz), specPower) * specStrength;
        const rim = Math.pow(1.0 - nz, 2.4) * rimStrength * (nx > 0 || ny < 0 ? 1.0 : 0.45);
        // Subtle underside ambient occlusion
        const ao = ny > 0.55 ? 1.0 - (ny - 0.55) * 0.42 : 1.0;

        const r = (colorBase[0] * diffuse * ao) + 255 * spec + 235 * rim;
        const g = (colorBase[1] * diffuse * ao) + 244 * spec + 215 * rim;
        const b = (colorBase[2] * diffuse * ao) + 220 * spec + 185 * rim;
        this.setPixel(x, y, [r, g, b, alpha]);
      }
    }
  }

  /**
   * Renders a 3D horizontally-curved cylinder (great for tree trunks, barrels, vests, pedestals).
   */
  fillLitCylinder(x0, y0, w, h, baseRgba, opts = {}) {
    const specStrength = opts.specStrength ?? 0.18;
    const verticalShade = opts.verticalShade ?? 0.12;
    const alpha = baseRgba[3] ?? 255;
    for (let dy = 0; dy < h; dy++) {
      const vFactor = 1.0 - (dy / Math.max(1, h - 1)) * verticalShade;
      for (let dx = 0; dx < w; dx++) {
        const nx = ((dx + 0.5) / w) * 2.0 - 1.0;
        const nz = Math.sqrt(Math.max(0.05, 1.0 - nx * nx));
        const ndotl = Math.max(0, nx * -0.48 + nz * 0.86);
        const spec = Math.pow(Math.max(0, nx * -0.25 + nz * 0.96), 16) * specStrength;
        const f = (0.48 + 0.64 * ndotl) * vFactor;
        this.setPixel(x0 + dx, y0 + dy, [
          baseRgba[0] * f + 255 * spec,
          baseRgba[1] * f + 245 * spec,
          baseRgba[2] * f + 225 * spec,
          alpha,
        ]);
      }
    }
  }

  toPngBuffer() {
    const raw = Buffer.alloc(this.h * (1 + this.w * 4));
    for (let y = 0; y < this.h; y++) {
      const rowOffset = y * (1 + this.w * 4);
      raw[rowOffset] = 0;
      Buffer.from(this.data.buffer, y * this.w * 4, this.w * 4).copy(raw, rowOffset + 1);
    }
    const ihdr = Buffer.alloc(13);
    ihdr.writeUInt32BE(this.w, 0);
    ihdr.writeUInt32BE(this.h, 4);
    ihdr[8] = 8;
    ihdr[9] = 6;
    ihdr[10] = 0;
    ihdr[11] = 0;
    ihdr[12] = 0;

    const compressed = zlib.deflateSync(raw, { level: 9 });
    return Buffer.concat([
      Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
      pngChunk('IHDR', ihdr),
      pngChunk('IDAT', compressed),
      pngChunk('IEND', Buffer.alloc(0)),
    ]);
  }

  save(filePath) {
    fs.mkdirSync(path.dirname(filePath), { recursive: true });
    fs.writeFileSync(filePath, this.toPngBuffer());
  }
}

function hex(str, a = 255) {
  const s = str.replace('#', '');
  return [
    parseInt(s.slice(0, 2), 16),
    parseInt(s.slice(2, 4), 16),
    parseInt(s.slice(4, 6), 16),
    a,
  ];
}

function shade(rgba, factor) {
  return [
    clampByte(rgba[0] * factor),
    clampByte(rgba[1] * factor),
    clampByte(rgba[2] * factor),
    rgba[3] ?? 255,
  ];
}

function mixCol(a, b, t) {
  return [
    clampByte(a[0] + (b[0] - a[0]) * t),
    clampByte(a[1] + (b[1] - a[1]) * t),
    clampByte(a[2] + (b[2] - a[2]) * t),
    clampByte((a[3] ?? 255) + ((b[3] ?? 255) - (a[3] ?? 255)) * t),
  ];
}

// ============================================================================
// 1. EXPANDED 2.5D / 3D-SHADED 256x256 TILESET (16x16 tiles) + .TSX PROPERTIES
// ============================================================================
function buildTilesetAndTsx() {
  const ts = new PixelCanvas(256, 256);

  function drawTile(id, fn) {
    const tx = (id % 16) * 16;
    const ty = Math.floor(id / 16) * 16;
    fn(tx, ty);
  }

  function hash2(x, y, seed) {
    const n = Math.sin(x * 127.1 + y * 311.7 + seed * 74.7) * 43758.5453;
    return n - Math.floor(n);
  }

  function paintGrassBase(ox, oy, baseHex, seed) {
    const base = hex(baseHex);
    for (let y = 0; y < 16; y++) {
      for (let x = 0; x < 16; x++) {
        const r = hash2(x, y, seed);
        const microWave = Math.sin(x * 0.55 + y * 0.35 + seed) * 0.05;
        let f = 0.96 + microWave + (r - 0.5) * 0.18;
        ts.setPixel(ox + x, oy + y, shade(base, f));
      }
    }
    // 2.5D upright grass blade tufts with shadow + sunlit tip
    const tufts = [
      [2, 4], [7, 2], [13, 5], [4, 11], [10, 9], [14, 13], [1, 14],
    ];
    for (let i = 0; i < tufts.length; i++) {
      const [gx, gy] = tufts[(i + seed) % tufts.length];
      if ((i + seed) % 2 === 0) {
        ts.setPixel(ox + gx, oy + gy + 1, shade(base, 0.74));
        ts.setPixel(ox + gx, oy + gy, shade(base, 1.20));
        ts.setPixel(ox + ((gx + 1) % 16), oy + gy, shade(base, 1.12));
      }
    }
  }

  // 0, 1, 2: Lush 2.5D Grass & Wildflower Clover variants
  drawTile(0, (ox, oy) => paintGrassBase(ox, oy, '#477c36', 1));
  drawTile(1, (ox, oy) => {
    paintGrassBase(ox, oy, '#407331', 2);
    // Subtle 3-leaf clover cluster
    ts.setPixel(ox + 6, oy + 7, hex('#65b04e'));
    ts.setPixel(ox + 5, oy + 8, hex('#569e41'));
    ts.setPixel(ox + 7, oy + 8, hex('#569e41'));
  });
  drawTile(2, (ox, oy) => {
    paintGrassBase(ox, oy, '#4e873c', 3);
    // 3D wildflowers with cast shadow + bright corolla
    const flowers = [
      [4, 5, '#ffd166', '#fff8d6'],
      [11, 10, '#fff3b0', '#ffffff'],
      [9, 3, '#e899dc', '#ffd6ff'],
      [3, 12, '#90e0ef', '#e0fbfc'],
    ];
    for (const [fx, fy, petal, core] of flowers) {
      ts.setPixel(ox + fx, oy + fy + 1, hex('#264a1c', 180));
      ts.setPixel(ox + fx - 1, oy + fy, hex(petal));
      ts.setPixel(ox + fx + 1, oy + fy, hex(petal));
      ts.setPixel(ox + fx, oy + fy - 1, hex(petal));
      ts.setPixel(ox + fx, oy + fy, hex(core));
    }
  });

  // 3: Warm 3D sculpted dusty orchard dirt lane with pebbles & bevel grain
  drawTile(3, (ox, oy) => {
    const base = hex('#9e7548');
    for (let y = 0; y < 16; y++) {
      for (let x = 0; x < 16; x++) {
        const r = hash2(x, y, 30);
        const rut = Math.sin((x + y * 0.25) * 0.8) * 0.05;
        ts.setPixel(ox + x, oy + y, shade(base, 0.96 + rut + (r - 0.5) * 0.22));
      }
    }
    // 3D tiny sunlit pebbles with dark underside
    for (const [px, py] of [[3, 4], [11, 6], [7, 12], [13, 13]]) {
      ts.setPixel(ox + px, oy + py + 1, hex('#664627'));
      ts.setPixel(ox + px, oy + py, hex('#c79d6d'));
    }
  });

  // 4: Slippery 3D wet mud with recessed reflective rain puddle
  drawTile(4, (ox, oy) => {
    const base = hex('#573820');
    for (let y = 0; y < 16; y++) {
      for (let x = 0; x < 16; x++) {
        const r = hash2(x, y, 44);
        ts.setPixel(ox + x, oy + y, shade(base, 0.86 + r * 0.26));
      }
    }
    // Recessed mud rim + glossy sky-reflecting puddle
    ts.fillEllipse(ox + 8, oy + 8.5, 6, 4, hex('#3b2413'));
    ts.fillEllipse(ox + 8, oy + 8, 5.2, 3.2, hex('#4f6d82'));
    ts.fillEllipse(ox + 7.5, oy + 7.5, 3.6, 2.0, hex('#7ea3bd'));
    ts.fillRect(ox + 5, oy + 6, 4, 1, hex('#d4ecfc'));
  });

  // 5: Plush 3D emerald cushion moss
  drawTile(5, (ox, oy) => {
    const base = hex('#2b8a63');
    for (let y = 0; y < 16; y++) {
      for (let x = 0; x < 16; x++) {
        const cx = ((x % 8) - 3.5) / 4.0;
        const cy = ((y % 8) - 3.5) / 4.0;
        const cushion = Math.max(0, 1.0 - (cx * cx + cy * cy) * 0.45);
        const r = hash2(x, y, 55) * 0.14;
        ts.setPixel(ox + x, oy + y, shade(base, 0.78 + cushion * 0.36 + r));
      }
    }
  });

  // 6: 2.5D Beveled Hardwood Stage Planks with warm varnish specular & nail heads
  drawTile(6, (ox, oy) => {
    for (let y = 0; y < 16; y++) {
      const plankRow = y % 4;
      for (let x = 0; x < 16; x++) {
        const grain = Math.sin(x * 0.7 + Math.floor(y / 4) * 2.1) * 0.06;
        let col = shade(hex('#87532f'), 1.0 + grain);
        if (plankRow === 0) col = hex('#4a2a14'); // recessed seam
        else if (plankRow === 1) col = shade(hex('#a86b3e'), 1.02 + grain); // top bevel highlight
        else if (plankRow === 3) col = shade(hex('#6e4123'), 0.96 + grain); // bottom plank shadow
        ts.setPixel(ox + x, oy + y, col);
      }
    }
    for (let y = 0; y < 16; y += 4) {
      const jointX = (y * 3 + 5) % 14 + 1;
      ts.fillRect(ox + jointX, oy + y + 1, 1, 3, hex('#4a2a14'));
      ts.setPixel(ox + jointX - 1, oy + y + 2, hex('#d49b62'));
    }
  });

  // 7: Weathered 3D macadam asphalt ("the concrete silence")
  drawTile(7, (ox, oy) => {
    const base = hex('#4b5059');
    for (let y = 0; y < 16; y++) {
      for (let x = 0; x < 16; x++) {
        const r = hash2(x, y, 77);
        const bevel = x === 0 ? 1.15 : x === 15 ? 0.84 : 1.0;
        ts.setPixel(ox + x, oy + y, shade(base, (0.88 + r * 0.24) * bevel));
      }
    }
    ts.setPixel(ox + 4, oy + 5, hex('#848c99'));
    ts.setPixel(ox + 11, oy + 12, hex('#848c99'));
  });

  // 8: 2.5D Standing Wooden Front Gate Fence with post caps & ground shadow
  drawTile(8, (ox, oy) => {
    ts.fillEllipse(ox + 8, oy + 14, 7.5, 2, hex('#000000', 95));
    // Horizontal 3D beveled rails
    for (const ry of [4, 10]) {
      ts.fillRect(ox, oy + ry, 16, 1, hex('#cfa06b'));
      ts.fillRect(ox, oy + ry + 1, 16, 2, hex('#9e6637'));
      ts.fillRect(ox, oy + ry + 3, 16, 1, hex('#59351a'));
    }
    // Vertical 3D cylindrical posts + end-grain caps
    for (const px of [2, 11]) {
      ts.fillLitCylinder(ox + px, oy + 2, 4, 13, hex('#8c5832'), { specStrength: 0.15 });
      ts.fillRect(ox + px, oy + 1, 4, 2, hex('#deb383'));
      ts.setPixel(ox + px + 1, oy + 5, hex('#2b1a0e'));
      ts.setPixel(ox + px + 1, oy + 11, hex('#2b1a0e'));
    }
  });

  // 9: Toppled wooden fence planks on ground (walkable)
  drawTile(9, (ox, oy) => {
    ts.fillRect(ox + 1, oy + 10, 14, 4, hex('#3b2312', 120));
    ts.fillRect(ox + 1, oy + 8, 14, 1, hex('#b87f4c'));
    ts.fillRect(ox + 1, oy + 9, 14, 2, hex('#82522b'));
    ts.fillRect(ox + 3, oy + 12, 11, 1, hex('#9c6639'));
    ts.fillRect(ox + 3, oy + 13, 11, 2, hex('#633d20'));
  });

  // 10: Volumetric 3D Walnut Border Tree / Hedge
  drawTile(10, (ox, oy) => {
    ts.fillRect(ox, oy, 16, 16, hex('#1d3b18'));
    ts.fillLitCylinder(ox + 6, oy + 11, 4, 5, hex('#664024'));
    ts.fillLitEllipsoid(ox + 8, oy + 7.5, 7.2, 6.2, hex('#356e2b'), {
      specStrength: 0.14,
      rimStrength: 0.18,
      outline: hex('#163012'),
    });
    ts.fillLitEllipsoid(ox + 6, oy + 5.5, 4.5, 3.8, hex('#4f9440'), {
      specStrength: 0.20,
      rimStrength: 0.12,
    });
  });

  // 11: Volumetric 3D Overhead Walnut Canopy with golden drupes
  drawTile(11, (ox, oy) => {
    ts.fillLitEllipsoid(ox + 8, oy + 8.5, 7.6, 7.2, hex('#2d6125', 228), {
      specStrength: 0.16,
      rimStrength: 0.20,
      outline: hex('#173612', 200),
    });
    ts.fillLitEllipsoid(ox + 6, oy + 6, 4.8, 4.4, hex('#488c3b', 232), {
      specStrength: 0.22,
    });
    // 3D golden walnut drupes hanging in foliage
    ts.fillLitEllipsoid(ox + 11, oy + 10, 1.8, 2.0, hex('#d4a056', 245), { specStrength: 0.35 });
    ts.fillLitEllipsoid(ox + 5, oy + 11, 1.5, 1.6, hex('#c48e47', 240), { specStrength: 0.30 });
  });

  // 12: 2.5D Vintage Concert Speaker Stack (top face + front baffle + concave cones)
  drawTile(12, (ox, oy) => {
    ts.fillEllipse(ox + 8, oy + 15, 6.5, 1.5, hex('#000000', 120));
    // Top cabinet bevel (2.5D oblique)
    ts.fillRect(ox + 2, oy + 1, 12, 3, hex('#4a4552'));
    ts.fillRect(ox + 2, oy + 1, 12, 1, hex('#6c6578'));
    // Front cabinet body
    ts.fillRect(ox + 2, oy + 3, 12, 12, hex('#1f1c24'));
    ts.fillRect(ox + 3, oy + 4, 10, 10, hex('#2d2936'));
    // Brass corner hardware
    for (const [cx, cy] of [[2, 3], [13, 3], [2, 14], [13, 14]]) {
      ts.setPixel(ox + cx, oy + cy, hex('#e0a94f'));
    }
    // Twin 3D recessed speaker cones with gold dust caps
    for (const cy of [6.5, 11.5]) {
      ts.fillEllipse(ox + 8, oy + cy, 3.2, 2.6, hex('#121017'));
      ts.strokeEllipse(ox + 8, oy + cy, 3.2, 2.6, hex('#524b61'));
      ts.fillLitEllipsoid(ox + 8, oy + cy, 1.4, 1.4, hex('#e6b35a'), { specStrength: 0.45 });
    }
  });

  // 13: 2.5D Pitched Canvas Tent Wall with roof ridge & guy-line stakes
  drawTile(13, (ox, oy) => {
    ts.fillRect(ox + 1, oy + 14, 14, 2, hex('#000000', 95));
    // Sloped terracotta-striped canvas roof
    for (let y = 1; y < 7; y++) {
      const shadeF = 1.18 - (y - 1) * 0.06;
      ts.fillRect(ox + 1, oy + y, 14, 1, shade(hex('#c46d3e'), shadeF));
    }
    ts.fillRect(ox + 1, oy + 1, 14, 1, hex('#f0a878')); // roof ridge highlight
    // Shaded cream canvas front wall
    ts.fillLitCylinder(ox + 1, oy + 7, 14, 7, hex('#dfd0ab'), { specStrength: 0.08 });
    ts.fillRect(ox + 1, oy + 13, 14, 1, hex('#8c7754'));
  });

  // 14: 2.5D Tent Flap Warm Entrance
  drawTile(14, (ox, oy) => {
    for (let y = 1; y < 6; y++) {
      ts.fillRect(ox + 1, oy + y, 14, 1, shade(hex('#c46d3e'), 1.15 - y * 0.05));
    }
    ts.fillLitCylinder(ox + 1, oy + 6, 14, 9, hex('#dfd0ab'), { specStrength: 0.08 });
    // Warm interior lantern glow inside tent flap
    ts.fillRect(ox + 5, oy + 6, 6, 9, hex('#2b1a10'));
    ts.fillEllipse(ox + 8, oy + 11, 2.5, 3, hex('#ff9f1c', 120));
    // Tied-back canvas drapes
    ts.fillRect(ox + 4, oy + 6, 2, 8, hex('#b5653b'));
    ts.fillRect(ox + 10, oy + 6, 2, 8, hex('#9c522b'));
  });

  // 15: Woven 3D Patchwork Meadow Blanket with fringe & quilting seams
  drawTile(15, (ox, oy) => {
    ts.fillRect(ox, oy + 15, 16, 1, hex('#1f3b18', 130));
    const patches = [
      [1, 1, '#c94c4c'], [8, 1, '#e0a938'],
      [1, 8, '#3f7cac'], [8, 8, '#8b5fbf'],
    ];
    for (const [px, py, col] of patches) {
      const base = hex(col);
      for (let dy = 0; dy < 7; dy++) {
        for (let dx = 0; dx < 7; dx++) {
          const weave = ((dx + dy) % 2 === 0 ? 1.06 : 0.94);
          const pillow = 1.04 - Math.hypot(dx - 3, dy - 3) * 0.03;
          ts.setPixel(ox + px + dx, oy + py + dy, shade(base, weave * pillow));
        }
      }
    }
    // Golden fringe along edges
    for (let x = 1; x < 15; x += 2) {
      ts.setPixel(ox + x, oy, hex('#f4e3c1'));
      ts.setPixel(ox + x, oy + 15, hex('#d9c398'));
    }
  });

  // 16: Sculpted 3D Walnut Grove Tree Trunk & Crown
  drawTile(16, (ox, oy) => {
    ts.fillEllipse(ox + 8, oy + 14.5, 6.5, 2, hex('#000000', 110));
    // Flared roots & 3D bark cylinder
    ts.fillLitCylinder(ox + 5, oy + 9, 6, 6, hex('#734626'), { specStrength: 0.12 });
    ts.fillRect(ox + 4, oy + 14, 2, 2, hex('#59351c'));
    ts.fillRect(ox + 10, oy + 14, 2, 2, hex('#472915'));
    // Multi-lobed 3D leaf crown
    ts.fillLitEllipsoid(ox + 8, oy + 6, 7.2, 5.8, hex('#2f6926'), {
      specStrength: 0.18,
      rimStrength: 0.22,
      outline: hex('#183814'),
    });
    ts.fillLitEllipsoid(ox + 6, oy + 4.5, 4.5, 3.6, hex('#4da13f'), { specStrength: 0.24 });
  });

  // 17: 3D Wrought-Wood & Brass Pathway Festival Lantern
  drawTile(17, (ox, oy) => {
    ts.fillEllipse(ox + 8, oy + 14.5, 4.5, 1.5, hex('#000000', 110));
    ts.fillLitCylinder(ox + 7, oy + 7, 2, 8, hex('#593a22'));
    // Brass lantern cap + glowing 3D glass globe
    ts.fillLitEllipsoid(ox + 8, oy + 5.5, 3.6, 3.4, hex('#ffcf56'), {
      specStrength: 0.55,
      outline: hex('#8c5e1a'),
    });
    ts.fillRect(ox + 6, oy + 2, 4, 1, hex('#4a321f'));
    ts.setPixel(ox + 8, oy + 5, hex('#ffffff'));
  });

  // 18: 2.5D Falafel Stand & Striped Awning Counter
  drawTile(18, (ox, oy) => {
    // 3D Wooden counter front with recessed panel
    ts.fillLitCylinder(ox + 1, oy + 7, 14, 8, hex('#8f5b34'), { specStrength: 0.1 });
    ts.fillRect(ox + 1, oy + 6, 14, 2, hex('#cfa06b')); // marble/wood countertop
    // Striped 3D sloped awning casting shadow onto counter
    ts.fillRect(ox + 1, oy + 6, 14, 1, hex('#3d2210', 140));
    for (let x = 0; x < 16; x++) {
      const isCream = Math.floor(x / 3) % 2 === 0;
      const base = isCream ? hex('#f7edd9') : hex('#cf3838');
      for (let y = 0; y < 6; y++) {
        ts.setPixel(ox + x, oy + y, shade(base, 1.15 - y * 0.06));
      }
    }
    // 3D platter of golden falafel balls & tahini
    ts.fillEllipse(ox + 8, oy + 8, 4, 2, hex('#e9ecef'));
    ts.fillLitEllipsoid(ox + 7, oy + 7.5, 1.5, 1.4, hex('#7ab846'));
    ts.fillLitEllipsoid(ox + 9.5, oy + 7.5, 1.5, 1.4, hex('#8ac926'));
  });

  // 19: 3D Sculpted Giant Walnut Root Stage Proscenium Arch
  drawTile(19, (ox, oy) => {
    ts.fillLitCylinder(ox, oy + 2, 16, 14, hex('#5e391d'), { specStrength: 0.16 });
    // Intertwined 3D root tendons & golden sap inlay
    ts.fillLitEllipsoid(ox + 8, oy + 6, 7, 3.2, hex('#82512c'), { specStrength: 0.25 });
    ts.fillLitEllipsoid(ox + 8, oy + 10, 5.5, 2.2, hex('#ebb146'), { specStrength: 0.45 });
  });

  // 20: 2.5D Campground Double-LP Turntable Console
  drawTile(20, (ox, oy) => {
    ts.fillLitCylinder(ox + 1, oy + 7, 14, 8, hex('#6e4423'));
    ts.fillRect(ox + 1, oy + 3, 14, 5, hex('#996236'));
    ts.fillRect(ox + 2, oy + 4, 12, 6, hex('#221f26'));
    // 3D Vinyl platter with specular groove sheen
    ts.fillLitEllipsoid(ox + 7, oy + 7, 3.6, 3.2, hex('#18181f'), { specStrength: 0.50 });
    ts.fillEllipse(ox + 7, oy + 7, 1.4, 1.4, hex('#e85d3f'));
    ts.fillRect(ox + 11, oy + 4, 1, 5, hex('#e2e8f0')); // silver tonearm
  });

  // 21: 2.5D High-Branch Booth Timber Platform & Beveled Ladder
  drawTile(21, (ox, oy) => {
    ts.fillLitCylinder(ox + 1, oy, 14, 16, hex('#6e4626'), { specStrength: 0.10 });
    ts.fillLitCylinder(ox + 4, oy, 2, 16, hex('#c48f52'), { specStrength: 0.22 });
    ts.fillLitCylinder(ox + 10, oy, 2, 16, hex('#c48f52'), { specStrength: 0.22 });
    for (let y = 2; y < 16; y += 4) {
      ts.fillRect(ox + 4, oy + y, 8, 1, hex('#f0c68c'));
      ts.fillRect(ox + 4, oy + y + 1, 8, 1, hex('#7d522b'));
    }
  });

  // 22: Plush 3D Velvet Canopy Crushed Burgundy Carpet with gold border
  drawTile(22, (ox, oy) => {
    const base = hex('#731d3b');
    for (let y = 0; y < 16; y++) {
      for (let x = 0; x < 16; x++) {
        const velvetSheen = Math.sin(x * 0.6 + y * 0.4) * 0.10 + (hash2(x, y, 22) - 0.5) * 0.12;
        ts.setPixel(ox + x, oy + y, shade(base, 1.0 + velvetSheen));
      }
    }
    ts.fillRect(ox, oy, 16, 1, hex('#ebb854'));
    ts.fillRect(ox, oy + 1, 16, 1, hex('#9e7425'));
  });

  // 23: 2.5D Olive Velvet Stage Deck with inlaid amethyst stud
  drawTile(23, (ox, oy) => {
    for (let y = 0; y < 16; y++) {
      const row = y % 4;
      for (let x = 0; x < 16; x++) {
        const g = Math.sin(x * 0.5 + y) * 0.04;
        const c = row === 0 ? hex('#2e3819') : row === 1 ? shade(hex('#63753b'), 1 + g) : shade(hex('#4e5d2e'), 1 + g);
        ts.setPixel(ox + x, oy + y, c);
      }
    }
    ts.fillLitEllipsoid(ox + 8, oy + 8, 1.5, 1.5, hex('#c77dff'), { specStrength: 0.5 });
  });

  // 24: 3D Pleated Amethyst & Citrine Velvet Stage Drapery
  drawTile(24, (ox, oy) => {
    for (let x = 0; x < 16; x++) {
      const fold = 0.65 + 0.52 * (0.5 + 0.5 * Math.sin((x / 16) * Math.PI * 4));
      for (let y = 0; y < 15; y++) {
        ts.setPixel(ox + x, oy + y, shade(hex('#6e1d4c'), fold * (1.08 - y * 0.02)));
      }
    }
    ts.fillRect(ox, oy + 14, 16, 2, hex('#d4a345')); // gold tassel hem
    ts.fillLitEllipsoid(ox + 4, oy + 5, 1.8, 1.8, hex('#c77dff'), { specStrength: 0.6 });
    ts.fillLitEllipsoid(ox + 12, oy + 6, 1.8, 1.8, hex('#ffd166'), { specStrength: 0.6 });
  });

  // 25: 3D Steep Cliff Bark/Rock Wall (dormant moss spores)
  drawTile(25, (ox, oy) => {
    for (let x = 0; x < 16; x++) {
      const ridge = 0.78 + 0.34 * Math.sin(x * 1.4);
      for (let y = 0; y < 16; y++) {
        const strata = (y % 5 === 0) ? 0.82 : 1.0;
        ts.setPixel(ox + x, oy + y, shade(hex('#4f3521'), ridge * strata));
      }
    }
    ts.fillLitEllipsoid(ox + 7, oy + 8, 2.0, 1.5, hex('#2f8555'));
  });

  // 26: 3D Bloomed Climbable Emerald Bark-Moss Terrace Steps
  drawTile(26, (ox, oy) => {
    ts.fillRect(ox, oy, 16, 16, hex('#205e40'));
    for (let y = 1; y < 16; y += 4) {
      ts.fillLitEllipsoid(ox + 8, oy + y + 1, 6.8, 2.0, hex('#48e59a'), {
        specStrength: 0.30,
        outline: hex('#164730'),
      });
    }
    ts.setPixel(ox + 5, oy + 4, hex('#e3fff1'));
    ts.setPixel(ox + 11, oy + 12, hex('#e3fff1'));
  });

  // 27: 3D Gnarled Ancient Old Oak Roots (with McGregor's golden pick glint)
  drawTile(27, (ox, oy) => {
    ts.fillEllipse(ox + 8, oy + 13, 7.5, 2.5, hex('#000000', 110));
    ts.fillLitEllipsoid(ox + 8, oy + 8, 7.4, 6.2, hex('#5e3b20'), {
      specStrength: 0.18,
      outline: hex('#2e1b0d'),
    });
    ts.fillLitEllipsoid(ox + 7, oy + 6, 5.2, 3.6, hex('#7d512e'), { specStrength: 0.24 });
    ts.fillLitEllipsoid(ox + 10, oy + 11, 1.6, 1.6, hex('#ffd166'), { specStrength: 0.65 });
  });

  // 28: Shimmering 3D Dew Clover Glade
  drawTile(28, (ox, oy) => {
    paintGrassBase(ox, oy, '#3d7836', 28);
    ts.fillLitEllipsoid(ox + 5, oy + 6, 2.2, 2.0, hex('#7bf1a8'), { specStrength: 0.55 });
    ts.fillLitEllipsoid(ox + 11, oy + 10, 2.2, 2.0, hex('#90e0ef'), { specStrength: 0.65 });
  });

  // 29: 3D Faceted Andromeda Crystal Starlight Floor
  drawTile(29, (ox, oy) => {
    for (let y = 0; y < 16; y++) {
      for (let x = 0; x < 16; x++) {
        const dx = Math.abs(x - 7.5);
        const dy = Math.abs(y - 7.5);
        const facet = Math.max(0, 1.0 - (dx + dy) / 14.0);
        ts.setPixel(ox + x, oy + y, mixCol(hex('#15112e'), hex('#2f2766'), facet));
      }
    }
    ts.strokeEllipse(ox + 8, oy + 8, 6, 6, hex('#4e449c'));
    ts.setPixel(ox + 4, oy + 4, hex('#72efdd'));
    ts.setPixel(ox + 12, oy + 10, hex('#e0aaff'));
  });

  // 30: 3D Geodesic Dome Crystal Strut Node
  drawTile(30, (ox, oy) => {
    ts.fillRect(ox, oy, 16, 16, hex('#1f1845'));
    for (let i = 0; i < 16; i++) {
      ts.setPixel(ox + i, oy + i, hex('#80ffdb'));
      ts.setPixel(ox + Math.min(15, i + 1), oy + i, hex('#48bfe3'));
      ts.setPixel(ox + 15 - i, oy + i, hex('#e0aaff'));
    }
    ts.fillLitEllipsoid(ox + 8, oy + 8, 3.0, 3.0, hex('#caf0f8'), { specStrength: 0.65 });
  });

  // 31: 3D Faceted Meteoric Space-Glass Resonator Spire
  drawTile(31, (ox, oy) => {
    ts.fillEllipse(ox + 8, oy + 14, 5.5, 2.2, hex('#1a142e', 160));
    ts.fillLitEllipsoid(ox + 8, oy + 13, 5.0, 2.0, hex('#463a66'));
    for (let y = 1; y <= 12; y++) {
      const halfW = Math.max(1, Math.round(((y + 1) / 13) * 3.5));
      ts.fillLitCylinder(ox + 8 - halfW, oy + y, halfW * 2, 1, hex('#48bfe3'), { specStrength: 0.55 });
    }
    ts.fillRect(ox + 7, oy + 2, 1, 9, hex('#ffffff', 210));
  });

  // 32: 2.5D Urbano Red-and-Gold 1969 Produce Truck Stage
  drawTile(32, (ox, oy) => {
    ts.fillRect(ox, oy + 14, 16, 2, hex('#000000', 130));
    // Truck roof & upper cab (bright sunlit scarlet)
    ts.fillRect(ox, oy + 1, 16, 3, hex('#e63946'));
    ts.fillRect(ox, oy + 1, 16, 1, hex('#ff758f'));
    // Truck body + Santurce gold racing stripe
    ts.fillLitCylinder(ox, oy + 4, 16, 9, hex('#b82028'), { specStrength: 0.20 });
    ts.fillRect(ox, oy + 6, 16, 3, hex('#f7c348'));
    ts.fillRect(ox, oy + 6, 16, 1, hex('#fff3b0'));
    // Chrome bumper & 3D tires
    ts.fillRect(ox, oy + 12, 16, 1, hex('#dee2e6'));
    ts.fillLitEllipsoid(ox + 4.5, oy + 13.5, 2.2, 2.2, hex('#212529'), { specStrength: 0.3 });
    ts.fillLitEllipsoid(ox + 11.5, oy + 13.5, 2.2, 2.2, hex('#212529'), { specStrength: 0.3 });
  });

  // 33: 2.5D Santurce Towering Sub-Woofer Stack
  drawTile(33, (ox, oy) => {
    ts.fillRect(ox + 1, oy, 14, 3, hex('#3d3642'));
    ts.fillRect(ox + 1, oy + 2, 14, 14, hex('#18151c'));
    ts.fillLitEllipsoid(ox + 8, oy + 5.5, 4.2, 3.6, hex('#2b2630'), { outline: hex('#f4b942') });
    ts.fillLitEllipsoid(ox + 8, oy + 5.5, 1.6, 1.6, hex('#ffd166'), { specStrength: 0.5 });
    ts.fillLitEllipsoid(ox + 8, oy + 12, 4.2, 3.2, hex('#2b2630'), { outline: hex('#e63946') });
    ts.fillLitEllipsoid(ox + 8, oy + 12, 1.6, 1.6, hex('#ff4d6d'), { specStrength: 0.5 });
  });

  // 34: Urbano Dancefloor Packed Warm Terracotta Earth
  drawTile(34, (ox, oy) => {
    const base = hex('#8c5e3b');
    for (let y = 0; y < 16; y++) {
      for (let x = 0; x < 16; x++) {
        const r = hash2(x, y, 34);
        ts.setPixel(ox + x, oy + y, shade(base, 0.90 + r * 0.20));
      }
    }
    ts.fillRect(ox + 2, oy + 2, 12, 1, hex('#f4b942', 140));
  });

  // 35: Bioluminescent 3D Undergrowth Mycelium Moss Floor
  drawTile(35, (ox, oy) => {
    const base = hex('#183833');
    for (let y = 0; y < 16; y++) {
      for (let x = 0; x < 16; x++) {
        const r = hash2(x, y, 35);
        ts.setPixel(ox + x, oy + y, shade(base, 0.85 + r * 0.30));
      }
    }
    ts.fillLitEllipsoid(ox + 3.5, oy + 5, 1.5, 1.5, hex('#38f2d4'), { specStrength: 0.6 });
    ts.fillLitEllipsoid(ox + 11.5, oy + 12, 1.6, 1.5, hex('#b565f7'), { specStrength: 0.6 });
    ts.setPixel(ox + 13, oy + 4, hex('#80ffdb'));
  });

  // 36: 3D Sacred Tea-Light Altar Stone & Glowing Flame
  drawTile(36, (ox, oy) => {
    ts.fillRect(ox, oy, 16, 16, hex('#183833'));
    ts.fillLitEllipsoid(ox + 8, oy + 10.5, 5.2, 3.6, hex('#6c757d'), {
      specStrength: 0.25,
      outline: hex('#2b303a'),
    });
    // Warm candle wax + glowing flame halo
    ts.fillEllipse(ox + 8, oy + 8, 4.0, 3.5, hex('#ffb703', 95));
    ts.fillRect(ox + 7, oy + 8, 2, 2, hex('#fff3b0'));
    ts.fillLitEllipsoid(ox + 8, oy + 6.5, 1.6, 2.2, hex('#ff9f1c'), { specStrength: 0.7 });
    ts.setPixel(ox + 8, oy + 6, hex('#ffffff'));
  });

  // 37: 3D Twisted Undergrowth Bramble Wall
  drawTile(37, (ox, oy) => {
    ts.fillRect(ox, oy, 16, 16, hex('#111f1e'));
    ts.fillLitEllipsoid(ox + 8, oy + 8, 7.2, 7.0, hex('#2e1a47'), {
      specStrength: 0.20,
      outline: hex('#0b1414'),
    });
    ts.fillLitEllipsoid(ox + 6, oy + 6, 2.0, 2.0, hex('#9d4edd'), { specStrength: 0.5 });
  });

  // 38: 3D Fermented Persimmon Cider Oak Barrel
  drawTile(38, (ox, oy) => {
    ts.fillEllipse(ox + 8, oy + 14.5, 5.5, 1.8, hex('#000000', 115));
    ts.fillLitCylinder(ox + 3, oy + 3, 10, 11, hex('#a65729'), { specStrength: 0.22 });
    ts.fillLitEllipsoid(ox + 8, oy + 3, 5.0, 2.0, hex('#cfa06b'), { outline: hex('#5e3116') });
    ts.fillRect(ox + 3, oy + 5, 10, 1, hex('#4a4e69'));
    ts.fillRect(ox + 3, oy + 11, 10, 1, hex('#4a4e69'));
  });

  // 39: 2.5D Vintage Vinyl Crate with Colored LP Sleeves
  drawTile(39, (ox, oy) => {
    ts.fillEllipse(ox + 8, oy + 14.5, 6.5, 1.5, hex('#000000', 110));
    // Record sleeves sticking up in 3D
    ts.fillRect(ox + 3, oy + 1, 9, 5, hex('#e76f51'));
    ts.fillRect(ox + 4, oy + 2, 9, 5, hex('#2a9d8f'));
    ts.fillLitEllipsoid(ox + 8, oy + 4, 3.8, 3.2, hex('#1b1b24'), { specStrength: 0.45 });
    // Slatted wooden crate front
    ts.fillLitCylinder(ox + 2, oy + 5, 12, 9, hex('#9c6639'), { specStrength: 0.14 });
    ts.fillRect(ox + 2, oy + 8, 12, 1, hex('#5c3a1e'));
    ts.fillRect(ox + 2, oy + 11, 12, 1, hex('#5c3a1e'));
  });

  // 40: 3D Fluted Marble Artifact Booth Pedestal
  drawTile(40, (ox, oy) => {
    ts.fillEllipse(ox + 8, oy + 15, 6, 1.5, hex('#000000', 110));
    ts.fillLitCylinder(ox + 3, oy + 6, 10, 9, hex('#e6dfd1'), { specStrength: 0.25 });
    ts.fillLitEllipsoid(ox + 8, oy + 5.5, 5.5, 2.4, hex('#f4a261'), {
      specStrength: 0.40,
      outline: hex('#8c5828'),
    });
  });

  // 41: 3D Woven Hemp-Rope Hammock
  drawTile(41, (ox, oy) => {
    paintGrassBase(ox, oy, '#477c36', 41);
    ts.fillEllipse(ox + 8, oy + 12, 6.5, 2.0, hex('#1c3614', 130));
    ts.fillLitCylinder(ox + 1, oy + 5, 2, 7, hex('#6b4226'));
    ts.fillLitCylinder(ox + 13, oy + 5, 2, 7, hex('#6b4226'));
    ts.fillLitEllipsoid(ox + 8, oy + 8, 6.2, 2.8, hex('#dec08f'), {
      specStrength: 0.20,
      outline: hex('#8c6d46'),
    });
  });

  // 42: Glossy 3D Checkered Sorting Arcade Floor
  drawTile(42, (ox, oy) => {
    for (let y = 0; y < 16; y++) {
      for (let x = 0; x < 16; x++) {
        const checker = ((x >> 3) + (y >> 3)) % 2 === 0;
        const base = checker ? hex('#3d2652') : hex('#281936');
        const gloss = 1.0 + Math.max(0, 0.16 - Math.hypot(x - 5, y - 5) * 0.02);
        ts.setPixel(ox + x, oy + y, shade(base, gloss));
      }
    }
  });

  // 43: 2.5D Optical Pinball Sorter Arcade Cabinet (glowing backglass + inclined playfield)
  drawTile(43, (ox, oy) => {
    ts.fillEllipse(ox + 8, oy + 15, 6.5, 1.5, hex('#000000', 130));
    // Raised arcade backbox
    ts.fillRect(ox + 2, oy + 1, 12, 5, hex('#560bad'));
    ts.fillRect(ox + 3, oy + 2, 10, 3, hex('#ffbe0b'));
    ts.setPixel(ox + 6, oy + 3, hex('#f72585'));
    ts.setPixel(ox + 10, oy + 3, hex('#4cc9f0'));
    // Inclined glass playfield + chrome side rails
    ts.fillRect(ox + 2, oy + 6, 12, 9, hex('#3a0ca3'));
    ts.fillRect(ox + 2, oy + 6, 1, 8, hex('#e2e8f0'));
    ts.fillRect(ox + 13, oy + 6, 1, 8, hex('#adb5bd'));
    ts.fillRect(ox + 3, oy + 6, 10, 6, hex('#4cc9f0'));
    ts.fillRect(ox + 4, oy + 7, 3, 2, hex('#ffffff', 160)); // glass reflection
    ts.fillLitEllipsoid(ox + 8, oy + 9, 1.6, 1.6, hex('#ffbe0b'), { specStrength: 0.6 });
  });

  // 44: 2.5D Industrial Optical Sorting Belt Conveyor with Golden Kernels
  drawTile(44, (ox, oy) => {
    ts.fillRect(ox, oy + 13, 16, 3, hex('#1b1e22'));
    ts.fillRect(ox, oy + 2, 16, 2, hex('#adb5bd')); // steel side rail
    ts.fillRect(ox, oy + 12, 16, 2, hex('#6c757d'));
    ts.fillRect(ox, oy + 4, 16, 8, hex('#2b3035'));
    for (let x = 1; x < 16; x += 4) {
      ts.fillRect(ox + x, oy + 4, 2, 8, hex('#495057'));
    }
    ts.fillLitEllipsoid(ox + 8, oy + 8, 2.4, 2.2, hex('#e9a952'), { specStrength: 0.45 });
  });

  // 45: 3D Pleated Carnival Striped Tent Wall
  drawTile(45, (ox, oy) => {
    for (let x = 0; x < 16; x++) {
      const isGold = Math.floor(x / 3) % 2 === 0;
      const base = isGold ? hex('#ffbe0b') : hex('#7209b7');
      const cyl = 0.78 + 0.34 * Math.sin((x % 3) / 3 * Math.PI);
      for (let y = 0; y < 16; y++) {
        ts.setPixel(ox + x, oy + y, shade(base, cyl * (1.08 - y * 0.015)));
      }
    }
  });

  // 46: 2.5D Literally Infinite CRT / Oscilloscope Sound Terminal
  drawTile(46, (ox, oy) => {
    ts.fillEllipse(ox + 8, oy + 15, 5.5, 1.5, hex('#000000', 120));
    ts.fillLitCylinder(ox + 3, oy + 2, 10, 13, hex('#2b303a'), { specStrength: 0.25 });
    ts.fillRect(ox + 3, oy + 1, 10, 2, hex('#6c757d'));
    // Glowing cyan phosphor CRT screen with sinewave
    ts.fillRect(ox + 4, oy + 4, 8, 5, hex('#0b3b36'));
    for (let sx = 0; sx < 8; sx++) {
      const sy = 6 + Math.round(Math.sin(sx * 1.1) * 1.2);
      ts.setPixel(ox + 4 + sx, oy + sy, hex('#80ffdb'));
    }
    ts.fillLitEllipsoid(ox + 8, oy + 12, 2.0, 2.0, hex('#ffbe0b'), { specStrength: 0.6 });
  });

  // 47: 2.5D Carved Wooden Zone Signpost
  drawTile(47, (ox, oy) => {
    ts.fillEllipse(ox + 8, oy + 15, 4.5, 1.5, hex('#000000', 110));
    ts.fillLitCylinder(ox + 7, oy + 7, 2, 8, hex('#5c3a21'));
    ts.fillRect(ox + 2, oy + 2, 12, 1, hex('#deb383'));
    ts.fillRect(ox + 2, oy + 3, 12, 5, hex('#a87446'));
    ts.fillRect(ox + 2, oy + 8, 12, 1, hex('#4f3119'));
    ts.fillRect(ox + 4, oy + 5, 8, 1, hex('#fff8eb'));
  });

  // 48: Sunlit 3D Upper Grove Ledge Clover Grass
  drawTile(48, (ox, oy) => {
    paintGrassBase(ox, oy, '#559444', 48);
    ts.fillLitEllipsoid(ox + 5, oy + 4, 1.5, 1.5, hex('#ffe66d'));
    ts.fillLitEllipsoid(ox + 12, oy + 11, 1.5, 1.5, hex('#c77dff'));
  });

  // 49: 3D Layered Cliff Rock Rim with Top Bevel & Crevices
  drawTile(49, (ox, oy) => {
    ts.fillRect(ox, oy, 16, 3, hex('#9e8a7e'));
    ts.fillRect(ox, oy, 16, 1, hex('#c2afa3'));
    for (let y = 3; y < 16; y++) {
      for (let x = 0; x < 16; x++) {
        const crag = 0.78 + 0.30 * Math.sin(x * 0.9 + (y >> 2) * 1.7);
        const drop = 1.0 - (y - 3) * 0.025;
        ts.setPixel(ox + x, oy + y, shade(hex('#5e4e45'), crag * drop));
      }
    }
  });

  // 50: Sunlit Golden Clover & Dandelion Meadow Grass
  drawTile(50, (ox, oy) => {
    paintGrassBase(ox, oy, '#478e4d', 50);
    for (const [cx, cy] of [[3, 4], [11, 3], [7, 10], [13, 12], [2, 13]]) {
      ts.setPixel(ox + cx, oy + cy + 1, hex('#234f29'));
      ts.setPixel(ox + cx, oy + cy, hex('#fff3b0'));
      ts.setPixel(ox + cx + 1, oy + cy, hex('#ffd166'));
    }
    ts.setPixel(ox + 6, oy + 5, hex('#ffffff'));
    ts.setPixel(ox + 10, oy + 8, hex('#ffffff'));
  });

  // 51: Fallen Golden Walnut Leaf & Dropped Nut Scatter on Orchard Grass
  drawTile(51, (ox, oy) => {
    paintGrassBase(ox, oy, '#3e7c44', 51);
    const leaves = [
      [2, 3, '#d48c3b'], [5, 4, '#e9c46a'], [11, 5, '#bc6c25'],
      [8, 10, '#e09f3e'], [3, 12, '#c97b50'], [12, 13, '#f4a261'],
    ];
    for (const [lx, ly, col] of leaves) {
      ts.fillRect(ox + lx, oy + ly, 2, 1, hex(col));
      ts.setPixel(ox + lx + 1, oy + ly + 1, shade(hex(col), 0.72));
    }
    // Tiny fallen walnut shell
    ts.fillLitEllipsoid(ox + 9, oy + 7, 1.8, 1.5, hex('#9c6644'), { specStrength: 0.35 });
  });

  // 52: Organic Grassy Dirt Road Verge (soft transition shoulder, mud-compatible!)
  drawTile(52, (ox, oy) => {
    paintGrassBase(ox, oy, '#417f47', 52);
    const dirt = hex('#9e724d');
    for (let y = 0; y < 16; y++) {
      for (let x = 0; x < 16; x++) {
        const d = Math.hypot(x - 7.5, y - 7.5) + (hash2(x, y, 52) - 0.5) * 3.8;
        if (d < 6.4) {
          const grain = 0.90 + hash2(x, y, 152) * 0.22;
          ts.setPixel(ox + x, oy + y, shade(dirt, grain));
        }
      }
    }
    ts.setPixel(ox + 5, oy + 6, hex('#cbb294'));
    ts.setPixel(ox + 10, oy + 9, hex('#704e32'));
  });

  // 53: Warm Sandstone & Cobble Plaza Flagstones
  drawTile(53, (ox, oy) => {
    ts.fillRect(ox, oy, 16, 16, hex('#594a3e'));
    const stones = [
      [0, 0, 7, 7, '#b89f84'],
      [8, 0, 8, 6, '#c4ab8e'],
      [0, 8, 6, 8, '#ad9378'],
      [7, 7, 9, 9, '#bfa588'],
    ];
    for (const [sx, sy, sw, sh, col] of stones) {
      const base = hex(col);
      ts.fillRect(ox + sx, oy + sy, sw, sh, base);
      ts.fillRect(ox + sx, oy + sy, sw, 1, shade(base, 1.18));
      ts.fillRect(ox + sx, oy + sy + sh - 1, sw, 1, shade(base, 0.76));
    }
  });

  // 54: Mossy Slate Stepping Stones inLush Grass
  drawTile(54, (ox, oy) => {
    paintGrassBase(ox, oy, '#3b7842', 54);
    ts.fillLitEllipsoid(ox + 5, oy + 5, 4.0, 2.8, hex('#8d99ae'), {
      specStrength: 0.22,
      outline: hex('#2b2d42'),
    });
    ts.fillLitEllipsoid(ox + 11, oy + 11, 3.8, 2.7, hex('#98a4b8'), {
      specStrength: 0.24,
      outline: hex('#2b2d42'),
    });
  });

  // 55: Rustic Split-Cedar Corduroy Boardwalk Planks
  drawTile(55, (ox, oy) => {
    paintGrassBase(ox, oy, '#35683b', 55);
    for (let py = 1; py < 15; py += 4) {
      const plank = py % 8 === 1 ? hex('#9c6644') : hex('#8d5b3c');
      ts.fillRect(ox + 1, oy + py, 14, 3, plank);
      ts.fillRect(ox + 1, oy + py, 14, 1, shade(plank, 1.18));
      ts.fillRect(ox + 1, oy + py + 2, 14, 1, shade(plank, 0.72));
      ts.setPixel(ox + 3, oy + py + 1, hex('#3b2314'));
      ts.setPixel(ox + 12, oy + py + 1, hex('#3b2314'));
    }
  });

  // 56: Willow Creek Deep Stream Water (3D riverbed + turquoise shimmer)
  drawTile(56, (ox, oy) => {
    for (let y = 0; y < 16; y++) {
      for (let x = 0; x < 16; x++) {
        const wave = Math.sin(x * 0.65 + y * 0.45) * 0.5 + 0.5;
        const base = mixCol(hex('#134e6f'), hex('#1f8a9c'), wave * 0.72);
        ts.setPixel(ox + x, oy + y, base);
      }
    }
    ts.fillRect(ox + 2, oy + 4, 4, 1, hex('#90e0ef', 190));
    ts.fillRect(ox + 9, oy + 11, 5, 1, hex('#caf0f8', 180));
  });

  // 57: Willow Creek Sparkling Riffles & River Pebbles
  drawTile(57, (ox, oy) => {
    for (let y = 0; y < 16; y++) {
      for (let x = 0; x < 16; x++) {
        const wave = Math.cos(x * 0.7 - y * 0.5) * 0.5 + 0.5;
        const base = mixCol(hex('#166080'), hex('#2ec4b6'), wave * 0.78);
        ts.setPixel(ox + x, oy + y, base);
      }
    }
    ts.fillEllipse(ox + 5, oy + 9, 2.2, 1.3, hex('#48cae4'));
    ts.fillRect(ox + 3, oy + 3, 5, 1, hex('#ffffff', 210));
    ts.fillRect(ox + 8, oy + 7, 4, 1, hex('#caf0f8', 210));
    ts.fillRect(ox + 4, oy + 13, 6, 1, hex('#ffffff', 185));
  });

  // 58: Mossy Creek Bank & Smooth River Cobbles
  drawTile(58, (ox, oy) => {
    paintGrassBase(ox, oy, '#2d6a4f', 58);
    for (const [cx, cy, rx, col] of [
      [4, 5, 2.6, '#778da9'],
      [11, 6, 2.3, '#8d99ae'],
      [7, 12, 2.8, '#6c757d'],
      [13, 13, 2.1, '#98c1d9'],
    ]) {
      ts.fillLitEllipsoid(ox + cx, oy + cy, rx, 1.7, hex(col), {
        specStrength: 0.30,
        outline: hex('#1d2d35'),
      });
    }
    // Emerald reed tufts
    ts.fillRect(ox + 2, oy + 9, 1, 4, hex('#52b788'));
    ts.fillRect(ox + 3, oy + 10, 1, 3, hex('#74c69d'));
  });

  // 59: Arched Cedar Footbridge Deck with Side Timber Stringers
  drawTile(59, (ox, oy) => {
    ts.fillRect(ox, oy, 16, 16, hex('#134e6f'));
    ts.fillRect(ox, oy + 1, 16, 14, hex('#4a2e1b'));
    for (let px = 0; px < 16; px += 4) {
      const plank = (px / 4) % 2 === 0 ? hex('#a46c42') : hex('#8f5934');
      ts.fillRect(ox + px, oy + 2, 3, 12, plank);
      ts.fillRect(ox + px, oy + 2, 3, 1, shade(plank, 1.2));
      ts.fillRect(ox + px, oy + 13, 3, 1, shade(plank, 0.72));
    }
    ts.fillRect(ox, oy + 1, 16, 2, hex('#c68b59'));
    ts.fillRect(ox, oy + 13, 16, 2, hex('#6f4518'));
  });

  // 60: Tall Golden 1969 Sunflowers (decor)
  drawTile(60, (ox, oy) => {
    for (const [sx, sy] of [[4, 6], [11, 5], [8, 10]]) {
      ts.fillRect(ox + sx, oy + sy + 2, 1, 5, hex('#2d6a4f'));
      ts.setPixel(ox + sx - 1, oy + sy + 4, hex('#52b788'));
      ts.fillLitEllipsoid(ox + sx + 0.5, oy + sy, 2.8, 2.8, hex('#ffbe0b'), {
        specStrength: 0.35,
      });
      ts.fillEllipse(ox + sx + 0.5, oy + sy, 1.3, 1.3, hex('#4a250b'));
    }
  });

  // 61: California Poppy & Marigold Wildflower Patch (decor)
  drawTile(61, (ox, oy) => {
    const blooms = [
      [3, 4, '#fb5607'], [9, 3, '#ffbe0b'], [13, 7, '#ff595e'],
      [5, 10, '#ff9f1c'], [11, 12, '#ffca3a'], [2, 13, '#fb5607'],
    ];
    for (const [bx, by, col] of blooms) {
      ts.setPixel(ox + bx, oy + by + 2, hex('#2d6a4f'));
      ts.fillLitEllipsoid(ox + bx, oy + by, 1.9, 1.7, hex(col), { specStrength: 0.35 });
      ts.setPixel(ox + bx, oy + by, hex('#fff3b0'));
    }
  });

  // 62: Fragrant Wild Lavender & Chamomile Bed (decor)
  drawTile(62, (ox, oy) => {
    for (const lx of [3, 6, 10, 13]) {
      ts.fillRect(ox + lx, oy + 8, 1, 5, hex('#40916c'));
      ts.fillRect(ox + lx, oy + 4, 1, 4, hex('#9d4edd'));
      ts.setPixel(ox + lx, oy + 3, hex('#e0aaff'));
      ts.setPixel(ox + lx + (lx % 2 === 0 ? 1 : -1), oy + 5, hex('#c77dff'));
    }
    ts.fillEllipse(ox + 8, oy + 12, 1.6, 1.6, hex('#ffffff'));
    ts.setPixel(ox + 8, oy + 12, hex('#ffd166'));
  });

  // 63: Woodland Ferns & Red Amanita Fairy-Ring Toadstools (decor)
  drawTile(63, (ox, oy) => {
    // Lush radiating fern fronds
    for (const [fx, fy] of [[2, 7], [6, 5], [10, 6], [4, 11]]) {
      ts.fillRect(ox + fx, oy + fy, 4, 2, hex('#2d6a4f'));
      ts.fillRect(ox + fx + 1, oy + fy - 1, 2, 1, hex('#52b788'));
    }
    // 2 spotted red toadstools
    for (const [mx, my, r] of [[11, 11, 2.6], [5, 12, 2.0]]) {
      ts.fillRect(ox + mx, oy + my, 2, 3, hex('#f8edeb'));
      ts.fillLitEllipsoid(ox + mx + 0.5, oy + my - 0.6, r, 1.7, hex('#e63946'), {
        specStrength: 0.4,
      });
      ts.setPixel(ox + mx, oy + my - 1, hex('#ffffff'));
      ts.setPixel(ox + mx + 1, oy + my - 1, hex('#ffffff'));
    }
  });

  // 64: Floating Creek Waterlily Pad & Pink Lotus Blossom (decor)
  drawTile(64, (ox, oy) => {
    ts.fillLitEllipsoid(ox + 8, oy + 9, 5.2, 3.6, hex('#40916c'), {
      specStrength: 0.25,
      outline: hex('#1b4332'),
    });
    ts.fillRect(ox + 8, oy + 9, 5, 1, hex('#166080'));
    ts.fillLitEllipsoid(ox + 7, oy + 7.2, 2.4, 1.9, hex('#ff8fab'), {
      specStrength: 0.45,
    });
    ts.setPixel(ox + 7, oy + 7, hex('#ffd166'));
  });

  // 65: 3D Twine-Bound Golden Hay Bale Lounge Seat (decor, walkable edge)
  drawTile(65, (ox, oy) => {
    ts.fillEllipse(ox + 8, oy + 14, 7, 2, hex('#000000', 85));
    ts.fillRect(ox + 2, oy + 5, 12, 9, hex('#d4a347'));
    ts.fillRect(ox + 2, oy + 4, 12, 3, hex('#f4d35e'));
    for (let x = 2; x < 14; x += 2) {
      ts.setPixel(ox + x, oy + 8, hex('#b58328'));
      ts.setPixel(ox + x + 1, oy + 11, hex('#9c6b19'));
    }
    // Twine bindings
    ts.fillRect(ox + 5, oy + 4, 1, 10, hex('#7f4f24'));
    ts.fillRect(ox + 10, oy + 4, 1, 10, hex('#7f4f24'));
  });

  // 66: Stacked Oak Cider & Persimmon Barrels (collidable decor)
  drawTile(66, (ox, oy) => {
    ts.fillEllipse(ox + 8, oy + 14.5, 6.8, 2.0, hex('#000000', 95));
    ts.fillLitCylinder(ox + 3, oy + 3, 10, 11, hex('#8c5a32'), { specStrength: 0.28 });
    ts.fillLitEllipsoid(ox + 8, oy + 3.2, 5.0, 2.0, hex('#b07d48'), { specStrength: 0.3 });
    ts.fillRect(ox + 3, oy + 5, 10, 1, hex('#3d405b'));
    ts.fillRect(ox + 3, oy + 11, 10, 1, hex('#3d405b'));
    ts.setPixel(ox + 8, oy + 8, hex('#ffd166'));
  });

  // 67: Overflowing Wicker Harvest Walnut Basket (decor)
  drawTile(67, (ox, oy) => {
    ts.fillEllipse(ox + 8, oy + 14, 5.5, 1.8, hex('#000000', 85));
    ts.fillLitCylinder(ox + 4, oy + 8, 8, 6, hex('#b07d48'), { specStrength: 0.22 });
    for (const [wx, wy] of [[5.5, 7.2], [8.0, 6.6], [10.3, 7.3], [7.0, 5.5], [9.2, 5.7]]) {
      ts.fillLitEllipsoid(ox + wx, oy + wy, 1.7, 1.5, hex('#d49a5a'), {
        specStrength: 0.35,
        outline: hex('#4a2c11'),
      });
    }
  });

  // 68: Gnarled Creekside Weeping Willow Trunk (collidable decor)
  drawTile(68, (ox, oy) => {
    ts.fillEllipse(ox + 8, oy + 14.5, 6.5, 2.0, hex('#000000', 100));
    ts.fillLitCylinder(ox + 5, oy + 3, 6, 11, hex('#6b5844'), { specStrength: 0.2 });
    ts.fillRect(ox + 4, oy + 12, 2, 2, hex('#524334'));
    ts.fillRect(ox + 10, oy + 12, 2, 2, hex('#524334'));
    ts.fillLitEllipsoid(ox + 8, oy + 3, 6.2, 3.0, hex('#74c69d'), { specStrength: 0.3 });
  });

  // 69: Cascading Chartreuse Weeping Willow Canopy Fronds (canopy)
  drawTile(69, (ox, oy) => {
    ts.fillLitEllipsoid(ox + 8, oy + 6, 7.5, 5.5, hex('#52b788'), {
      specStrength: 0.28,
      outline: hex('#1b4332'),
    });
    for (let x = 2; x <= 14; x += 2) {
      const len = 5 + (x % 3) * 2;
      ts.fillRect(ox + x, oy + 7, 1, len, hex(x % 4 === 0 ? '#95d5b2' : '#74c69d'));
      ts.setPixel(ox + x, oy + 7 + len, hex('#d8f3dc'));
    }
  });

  // 70: Heritage Walnut Orchard Canopy Bough Left (canopy with green walnut drupes!)
  drawTile(70, (ox, oy) => {
    ts.fillLitEllipsoid(ox + 9, oy + 8, 7.2, 6.8, hex('#2d6a4f'), {
      specStrength: 0.26,
      outline: hex('#143022'),
    });
    ts.fillLitEllipsoid(ox + 7, oy + 6, 4.8, 4.2, hex('#40916c'), { specStrength: 0.3 });
    // Ripening orchard walnut hulls
    ts.fillLitEllipsoid(ox + 6, oy + 10, 1.8, 1.8, hex('#95d5b2'), { specStrength: 0.45 });
    ts.fillLitEllipsoid(ox + 12, oy + 9, 1.7, 1.7, hex('#b7e4c7'), { specStrength: 0.45 });
  });

  // 71: Heritage Walnut Orchard Canopy Bough Right (canopy with golden-dappled foliage!)
  drawTile(71, (ox, oy) => {
    ts.fillLitEllipsoid(ox + 7, oy + 8, 7.2, 6.8, hex('#2d6a4f'), {
      specStrength: 0.26,
      outline: hex('#143022'),
    });
    ts.fillLitEllipsoid(ox + 9, oy + 6, 4.8, 4.2, hex('#52b788'), { specStrength: 0.32 });
    ts.fillLitEllipsoid(ox + 5, oy + 9, 1.7, 1.7, hex('#95d5b2'), { specStrength: 0.45 });
    ts.fillLitEllipsoid(ox + 10, oy + 11, 1.8, 1.8, hex('#d9ed92'), { specStrength: 0.45 });
  });

  // 72 & 73: 1969 Teal Canvas A-Frame Pup Tent (Left & Right halves)
  drawTile(72, (ox, oy) => {
    ts.fillRect(ox + 1, oy + 13, 15, 2, hex('#000000', 90));
    for (let y = 3; y <= 13; y++) {
      const xStart = Math.max(2, 13 - (y - 3));
      ts.fillRect(ox + xStart, oy + y, 16 - xStart, 1, y < 6 ? hex('#48cae4') : hex('#0096c7'));
    }
    ts.fillRect(ox + 2, oy + 13, 14, 1, hex('#ffd166'));
    ts.setPixel(ox + 1, oy + 13, hex('#e63946'));
  });
  drawTile(73, (ox, oy) => {
    ts.fillRect(ox, oy + 13, 15, 2, hex('#000000', 90));
    for (let y = 3; y <= 13; y++) {
      const w = Math.min(14, 4 + (y - 3));
      ts.fillRect(ox, oy + y, w, 1, y < 6 ? hex('#0077b6') : hex('#023e8a'));
    }
    // Warm tent opening triangle
    ts.fillRect(ox, oy + 8, 4, 6, hex('#2b180b'));
    ts.fillRect(ox, oy + 10, 3, 4, hex('#ffb703', 190));
    ts.fillRect(ox, oy + 13, 14, 1, hex('#ffd166'));
  });

  // 74 & 75: 1969 Saffron & Violet Tie-Dye Dome Tent (Left & Right halves)
  drawTile(74, (ox, oy) => {
    ts.fillRect(ox + 2, oy + 13, 14, 2, hex('#000000', 90));
    ts.fillLitEllipsoid(ox + 14, oy + 10, 11, 7.5, hex('#ff9f1c'), {
      specStrength: 0.3,
      outline: hex('#3c096c'),
    });
    ts.fillRect(ox + 6, oy + 8, 10, 2, hex('#9d4edd'));
    ts.fillRect(ox + 4, oy + 13, 12, 1, hex('#ffd166'));
  });
  drawTile(75, (ox, oy) => {
    ts.fillRect(ox, oy + 13, 14, 2, hex('#000000', 90));
    ts.fillLitEllipsoid(ox + 2, oy + 10, 11, 7.5, hex('#f77f00'), {
      specStrength: 0.3,
      outline: hex('#3c096c'),
    });
    ts.fillRect(ox, oy + 8, 10, 2, hex('#7209b7'));
    ts.fillRect(ox, oy + 9, 3, 5, hex('#ffd166', 210));
  });

  // 76, 77, 78: 1969 Painted Flower-Power VW Microbus (Front, Mid, Rear)
  drawTile(76, (ox, oy) => {
    ts.fillRect(ox + 2, oy + 14, 14, 2, hex('#000000', 110));
    ts.fillRect(ox + 3, oy + 2, 13, 6, hex('#fff3d6'));
    ts.fillRect(ox + 2, oy + 8, 14, 5, hex('#2ec4b6'));
    // Split safari windshield + chrome VW nose + headlight
    ts.fillRect(ox + 4, oy + 3, 5, 4, hex('#90e0ef'));
    ts.fillRect(ox + 11, oy + 3, 4, 4, hex('#48cae4'));
    ts.fillEllipse(ox + 4, oy + 10, 1.5, 1.5, hex('#ffe66d'));
    ts.fillLitEllipsoid(ox + 11, oy + 13.5, 3.0, 2.5, hex('#212529'), { specStrength: 0.3 });
    ts.setPixel(ox + 11, oy + 13, hex('#dee2e6'));
  });
  drawTile(77, (ox, oy) => {
    ts.fillRect(ox, oy + 14, 16, 2, hex('#000000', 110));
    ts.fillRect(ox, oy + 1, 16, 1, hex('#d4a373')); // roof rack
    ts.fillRect(ox + 3, oy + 0, 10, 2, hex('#e76f51')); // strapped camp bedroll
    ts.fillRect(ox, oy + 2, 16, 6, hex('#fff3d6'));
    ts.fillRect(ox, oy + 8, 16, 5, hex('#2ec4b6'));
    ts.fillRect(ox + 2, oy + 3, 5, 4, hex('#48cae4'));
    ts.fillRect(ox + 9, oy + 3, 5, 4, hex('#48cae4'));
    // Hand-painted flower-power peace decals!
    ts.fillEllipse(ox + 5, oy + 10, 2.0, 2.0, hex('#ff595e'));
    ts.setPixel(ox + 5, oy + 10, hex('#ffd166'));
    ts.fillEllipse(ox + 12, oy + 10, 1.8, 1.8, hex('#ffbe0b'));
    ts.setPixel(ox + 12, oy + 10, hex('#9d4edd'));
  });
  drawTile(78, (ox, oy) => {
    ts.fillRect(ox, oy + 14, 14, 2, hex('#000000', 110));
    ts.fillRect(ox, oy + 2, 13, 6, hex('#fff3d6'));
    ts.fillRect(ox, oy + 8, 14, 5, hex('#2ec4b6'));
    ts.fillRect(ox + 2, oy + 3, 6, 4, hex('#48cae4'));
    ts.fillRect(ox + 12, oy + 9, 2, 2, hex('#e63946')); // tail light
    ts.fillLitEllipsoid(ox + 6, oy + 13.5, 3.0, 2.5, hex('#212529'), { specStrength: 0.3 });
    ts.setPixel(ox + 6, oy + 13, hex('#dee2e6'));
  });

  // 79: Communal Campfire Stone Hearth with Glowing Coals (lantern=true!)
  drawTile(79, (ox, oy) => {
    ts.fillEllipse(ox + 8, oy + 9, 6.8, 5.2, hex('#2b2d42'));
    for (let i = 0; i < 8; i++) {
      const a = (i / 8) * Math.PI * 2;
      ts.fillLitEllipsoid(
        ox + 8 + Math.cos(a) * 5.2,
        oy + 9 + Math.sin(a) * 3.8,
        2.0,
        1.6,
        hex('#8d99ae'),
        { specStrength: 0.25 },
      );
    }
    // Crossed cedar logs & glowing embers
    ts.fillRect(ox + 5, oy + 8, 6, 2, hex('#5c3a21'));
    ts.fillLitEllipsoid(ox + 8, oy + 7.2, 3.0, 3.4, hex('#ff9f1c'), { specStrength: 0.5 });
    ts.fillLitEllipsoid(ox + 8, oy + 6.5, 1.7, 2.2, hex('#fff3b0'), { specStrength: 0.7 });
  });

  // 80: Carved Wooden 1969 Festival Directional Fingerpost Sign
  drawTile(80, (ox, oy) => {
    ts.fillEllipse(ox + 8, oy + 14.5, 4.5, 1.5, hex('#000000', 90));
    ts.fillLitCylinder(ox + 7, oy + 2, 2, 13, hex('#6f4518'), { specStrength: 0.25 });
    ts.fillRect(ox + 2, oy + 3, 11, 3, hex('#e9c46a'));
    ts.fillRect(ox + 3, oy + 7, 11, 3, hex('#52b788'));
    ts.fillRect(ox + 2, oy + 11, 9, 2, hex('#f4a261'));
    ts.setPixel(ox + 8, oy + 1, hex('#ffd166'));
  });

  // 81: Artisan Market Timber Post with Festoon Bulb & Pennants (lantern=true!)
  drawTile(81, (ox, oy) => {
    ts.fillEllipse(ox + 8, oy + 14.5, 4.0, 1.5, hex('#000000', 90));
    ts.fillLitCylinder(ox + 7, oy + 2, 2, 13, hex('#7f4f24'), { specStrength: 0.25 });
    ts.fillRect(ox + 2, oy + 2, 12, 1, hex('#3b2314'));
    ts.fillRect(ox + 3, oy + 3, 3, 2, hex('#ff595e'));
    ts.fillRect(ox + 10, oy + 3, 3, 2, hex('#4cc9f0'));
    ts.fillLitEllipsoid(ox + 8, oy + 4.2, 2.0, 2.0, hex('#fff3b0'), { specStrength: 0.7 });
  });

  // 82: Leaning Acoustic Folk Guitar & Vintage Vinyl Milk Crate (decor)
  drawTile(82, (ox, oy) => {
    ts.fillEllipse(ox + 8, oy + 14.5, 6.0, 1.8, hex('#000000', 85));
    ts.fillRect(ox + 2, oy + 8, 6, 6, hex('#e76f51'));
    ts.fillRect(ox + 3, oy + 6, 4, 2, hex('#212529')); // LP sleeves sticking up
    ts.fillLitEllipsoid(ox + 11, oy + 10.5, 3.2, 3.8, hex('#d48c3b'), {
      specStrength: 0.4,
      outline: hex('#3b2314'),
    });
    ts.setPixel(ox + 11, oy + 10, hex('#2b180b'));
    ts.fillRect(ox + 11, oy + 3, 2, 5, hex('#6f4518'));
  });

  // 83: Rustic Vertical Split-Rail Orchard Fence
  drawTile(83, (ox, oy) => {
    ts.fillLitCylinder(ox + 6, oy, 4, 16, hex('#7f5539'), { specStrength: 0.22 });
    ts.fillRect(ox + 5, oy + 3, 6, 2, hex('#9c6644'));
    ts.fillRect(ox + 5, oy + 11, 6, 2, hex('#9c6644'));
  });

  ts.save(path.join(ROOT, 'assets/images/tiles/orchard_tileset.png'));

  const tileMetadata = [
    { id: 0, surface: 'grass' },
    { id: 1, surface: 'grass' },
    { id: 2, surface: 'grass' },
    { id: 3, surface: 'dirt' },
    { id: 4, surface: 'mud', slippery: true },
    { id: 5, surface: 'moss' },
    { id: 6, surface: 'wood_stage' },
    { id: 7, surface: 'asphalt' },
    { id: 8, collidable: true, fence_gate: true },
    { id: 9, surface: 'dirt' },
    { id: 10, collidable: true },
    { id: 11, canopy: true, occlusion: true },
    { id: 12, collidable: true },
    { id: 13, collidable: true, occlusion: true },
    { id: 14, surface: 'wood_stage', occlusion: true },
    { id: 15, surface: 'grass' },
    { id: 16, collidable: true },
    { id: 17, lantern: true },
    { id: 18, collidable: true },
    { id: 19, collidable: true },
    { id: 20, collidable: true },
    { id: 21, surface: 'wood_stage', climbable: true },
    { id: 22, surface: 'velvet_carpet' },
    { id: 23, surface: 'wood_stage' },
    { id: 24, collidable: true },
    { id: 25, collidable: true, moss_target: true },
    { id: 26, surface: 'moss', climbable_moss: true },
    { id: 27, collidable: true },
    { id: 28, surface: 'grass' },
    { id: 29, surface: 'crystal_floor', low_gravity: true },
    { id: 30, collidable: true },
    { id: 31, collidable: true },
    { id: 32, collidable: true },
    { id: 33, collidable: true },
    { id: 34, surface: 'dirt' },
    { id: 35, surface: 'moss', occlusion: true },
    { id: 36, surface: 'moss' },
    { id: 37, collidable: true },
    { id: 38, collidable: true },
    { id: 39, collidable: true },
    { id: 40, collidable: true },
    { id: 41, surface: 'grass' },
    { id: 42, surface: 'wood_stage', occlusion: true },
    { id: 43, collidable: true },
    { id: 44, surface: 'wood_stage', occlusion: true },
    { id: 45, collidable: true, occlusion: true },
    { id: 46, collidable: true },
    { id: 47, collidable: true },
    { id: 48, surface: 'grass' },
    { id: 49, collidable: true },
    { id: 50, surface: 'grass' },
    { id: 51, surface: 'grass' },
    { id: 52, surface: 'dirt' },
    { id: 53, surface: 'stone' },
    { id: 54, surface: 'stone' },
    { id: 55, surface: 'wood_stage' },
    { id: 56, surface: 'water', collidable: true },
    { id: 57, surface: 'water', collidable: true },
    { id: 58, surface: 'grass' },
    { id: 59, surface: 'wood_stage' },
    { id: 60, surface: 'grass' },
    { id: 61, surface: 'grass' },
    { id: 62, surface: 'grass' },
    { id: 63, surface: 'grass' },
    { id: 64, surface: 'water' },
    { id: 65, surface: 'grass' },
    { id: 66, collidable: true },
    { id: 67, surface: 'grass' },
    { id: 68, collidable: true },
    { id: 69, canopy: true, occlusion: true },
    { id: 70, canopy: true, occlusion: true },
    { id: 71, canopy: true, occlusion: true },
    { id: 72, collidable: true, occlusion: true },
    { id: 73, collidable: true, occlusion: true },
    { id: 74, collidable: true, occlusion: true },
    { id: 75, collidable: true, occlusion: true },
    { id: 76, collidable: true },
    { id: 77, collidable: true },
    { id: 78, collidable: true },
    { id: 79, lantern: true },
    { id: 80, surface: 'grass' },
    { id: 81, lantern: true },
    { id: 82, surface: 'grass' },
    { id: 83, collidable: true },
  ];

  const tileXml = tileMetadata
    .map((t) => {
      const props = Object.entries(t)
        .filter(([k]) => k !== 'id')
        .map(([k, v]) => {
          const typeAttr = typeof v === 'boolean' ? ' type="bool"' : '';
          return `<property name="${k}"${typeAttr} value="${v}"/>`;
        })
        .join('');
      return ` <tile id="${t.id}"><properties>${props}</properties></tile>`;
    })
    .join('\n');

  const tsxContent = `<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.10.2" name="orchard_tileset" tilewidth="16" tileheight="16" tilecount="256" columns="16">
 <image source="../images/tiles/orchard_tileset.png" width="256" height="256"/>
${tileXml}
</tileset>
`;
  fs.writeFileSync(path.join(ROOT, 'assets/tiles/orchard_tileset.tsx'), tsxContent, 'utf8');
  return tileMetadata;
}

// ============================================================================
// 2. FULL 128x96 9-ZONE TILED MAP (free_orchard_full.tmx) — REDESIGNED & POLISHED
// ============================================================================
function buildFullOrchardTmx(tileMetadata = []) {
  const W = 128;
  const H = 96;
  const ground = new Int32Array(W * H);
  const decor = new Int32Array(W * H);
  const canopy = new Int32Array(W * H);

  const GID = (id) => id + 1;
  const setG = (x, y, id) => {
    if (x >= 0 && y >= 0 && x < W && y < H) ground[y * W + x] = GID(id);
  };
  const setD = (x, y, id) => {
    if (x >= 0 && y >= 0 && x < W && y < H) decor[y * W + x] = id < 0 ? 0 : GID(id);
  };
  const setC = (x, y, id) => {
    if (x >= 0 && y >= 0 && x < W && y < H) canopy[y * W + x] = id < 0 ? 0 : GID(id);
  };
  const fillRect = (fn, x0, y0, w, h, id) => {
    for (let y = y0; y < y0 + h; y++) {
      for (let x = x0; x < x0 + w; x++) fn(x, y, id);
    }
  };
  const fillDisc = (fn, cx, cy, rx, ry, id) => {
    for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++) {
      for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
        if (((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0) {
          fn(x, y, id);
        }
      }
    }
  };

  // 1. Varied Organic Orchard Meadow Base (lush grass + golden clover drifts + fallen walnut leaves)
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const n = Math.sin(x * 0.16 + y * 0.11) + Math.cos(x * 0.09 - y * 0.19);
      const v = (x * 7 + y * 13) % 11;
      if (n > 1.15 && v % 3 === 0) {
        setG(x, y, 50); // sunlit clover & dandelion drift
      } else if (n < -1.18 && v % 2 === 0) {
        setG(x, y, 51); // fallen golden walnut leaves
      } else {
        setG(x, y, v === 0 ? 2 : v % 3 === 0 ? 1 : 0);
      }
    }
  }

  // Outer perimeter woodland wall
  for (let x = 0; x < W; x++) {
    setD(x, 0, 10);
    setD(x, H - 1, 10);
    setC(x, H - 2, 11);
  }
  for (let y = 0; y < H; y++) {
    setD(0, y, 10);
    setD(W - 1, y, 10);
    if (y > 1 && y < H - 2 && y % 3 !== 0) {
      setC(1, y, 70);
      setC(W - 2, y, 71);
    }
  }

  // 2. Organic Winding Orchard Lanes & Soft Grassy-Dirt Verges
  // Soft road shoulders first (id 52 = surface 'dirt'), then rich trodden dirt core (id 3)
  const paintDirtCorridor = (x0, y0, w, h) => {
    fillRect(setG, x0 - 1, y0 - 1, w + 2, h + 2, 52);
    fillRect(setG, x0, y0, w, h, 3);
  };
  paintDirtCorridor(36, 40, 4, 52); // Grand North-South Gate Promenade
  paintDirtCorridor(14, 38, 92, 3); // North Stage Boulevard
  paintDirtCorridor(14, 68, 92, 3); // South Campground & Urbano Boulevard
  paintDirtCorridor(74, 16, 3, 55); // Undergrowth -> Meadow -> Vendor Row Trail
  paintDirtCorridor(15, 38, 3, 32); // West Grove Velvet-to-Urbano Lane
  paintDirtCorridor(104, 31, 3, 40); // East Andromeda-to-Arcade Ridge Lane

  // Keep Mud-Slide Meadow bowls (tx:12..44, ty:33..42) clean grass/dirt so Set 8 Mud Party shines!
  for (let ty = 34; ty <= 37; ty++) {
    for (let tx = 13; tx <= 43; tx++) {
      if (ground[ty * W + tx] === GID(52)) setG(tx, ty, (tx + ty) % 2 === 0 ? 0 : 1);
    }
  }

  // Central Orchard Crossroads Peace Plaza (around 608, 864 => tx:38, ty:54)
  // Note: (37, 60) MUST remain surface='dirt' for WorldMutators rainstorm test!
  fillDisc(setG, 38, 54, 4.6, 3.6, 53);
  fillDisc(setG, 38, 39, 3.8, 2.6, 53); // Main Roots South Bowl Plaza
  fillDisc(setG, 38, 69, 3.8, 2.6, 53); // South Gate North Crossroads
  // Scenic diagonal stepping-stone shortcuts connecting Crossroads to Meadow & Campground!
  for (let i = 0; i < 14; i++) {
    setG(42 + i, 53 - Math.floor(i * 0.8), 54);
    setG(42 + i, 55 + Math.floor(i * 0.85), 54);
    setG(34 - i, 55 + Math.floor(i * 0.85), 54);
  }
  // Directional festival fingerpost at Crossroads edge (walkable!)
  setD(35, 53, 80);
  setD(41, 53, 17);
  setD(35, 56, 17);

  // 3. Full Winding WILLOW CREEK + Mossy Cobble Banks + 3 Wide Cedar Footbridges!
  // Winds cleanly through the eastern orchard valley (tx ~ 91..93) from northern ridge (ty:18)
  // down to the southern boundary (ty:94), plus a northern spring pool feeding Mellow Meadow!
  for (let y = 18; y <= 94; y++) {
    const cx = 91 + Math.round(Math.sin(y * 0.14) * 1.2);
    setG(cx - 1, y, 58);
    setG(cx + 2, y, 58);
    setG(cx, y, y % 4 === 0 ? 57 : 56);
    setG(cx + 1, y, (y + 2) % 4 === 0 ? 57 : 56);
    if (y % 7 === 0 && (y < 37 || y > 42) && (y < 52 || y > 56) && (y < 67 || y > 72)) {
      setD(cx + (y % 2), y, 64); // floating waterlily & lotus!
    }
  }
  // Wide Walkable Cedar Footbridges carrying every East-West lane & mid-orchard trail across Willow Creek!
  for (const [by0, by1] of [[37, 41], [53, 55], [67, 71]]) {
    for (let y = by0; y <= by1; y++) {
      for (let x = 89; x <= 95; x++) {
        setD(x, y, -1);
        if (x >= 90 && x <= 94) {
          setG(x, y, 59); // Cedar Footbridge Deck (walkable wood_stage!)
        } else {
          setG(x, y, 55); // Corduroy timber bridge approach
        }
      }
    }
    setD(89, by0, 17); // Bridge-head warm lanterns!
    setD(95, by1, 17);
  }
  // Creekside Weeping Willows along Willow Creek banks
  for (const [wx, wy] of [[89, 25], [95, 31], [89, 46], [95, 61], [89, 78], [95, 85]]) {
    setD(wx, wy, 68);
    setC(wx, wy - 1, 69);
    setC(wx - 1, wy - 1, 69);
    setC(wx + 1, wy - 1, 69);
  }

  // 4. ZONE 1: Front Gate, Arrival Microbuses & Broken Fences
  fillRect(setG, 34, 88, 8, 7, 7);
  // Warm cobblestone apron around Orchard Gate kiosks (536,1320 & 680,1320)
  fillRect(setG, 32, 81, 12, 4, 53);
  fillRect(setG, 36, 75, 4, 13, 3);
  setD(36, 95, -1);
  setD(37, 95, -1);
  setD(38, 95, -1);
  setD(39, 95, -1);
  for (let x = 24; x <= 52; x++) {
    setD(x, 74, 8); // Perimeter wooden gate fence (including required (37,74)!)
  }
  setD(33, 76, 47);
  setD(43, 76, 47);
  setD(42, 76, 17);
  setD(33, 82, 17);
  setD(35, 86, 17);
  setD(40, 86, 17);
  // Parked 1969 Painted Peace VW Microbuses in the South Arrival Meadow!
  setD(25, 86, 76); setD(26, 86, 77); setD(27, 86, 78);
  setD(48, 86, 76); setD(49, 86, 77); setD(50, 86, 78);
  setD(23, 90, 72); setD(24, 90, 73); // Early-arrival gate camp tent
  setD(28, 87, 82); // Acoustic guitar & vinyl crate beside VW bus
  setD(47, 87, 65); // Hay bale lounge by east VW bus
  // Welcome wildflower borders flanking the gate lane
  for (let y = 77; y <= 85; y += 2) {
    setD(31, y, y % 4 === 1 ? 60 : 61);
    setD(44, y, y % 4 === 1 ? 61 : 62);
  }

  // 5. ZONE 2: Main Roots Stage, Amphitheater Bowl & High-Branch Booth
  fillRect(setG, 30, 21, 16, 7, 6);
  fillRect(setD, 29, 20, 18, 1, 19);
  setD(30, 22, 12);
  setD(30, 24, 12);
  setD(45, 22, 12);
  setD(45, 24, 12);
  for (let y = 29; y <= 36; y++) {
    for (let x = 31; x <= 45; x++) {
      if ((x + y) % 2 === 0) setG(x, y, 5);
    }
  }
  fillRect(setG, 47, 20, 4, 5, 21);
  fillRect(setC, 46, 18, 6, 3, 11);
  setD(29, 30, 17);
  setD(46, 30, 17);
  setD(28, 34, 17);
  setD(48, 34, 17);
  // Sunflower & hay-bale amphitheater rim framing Main Roots Stage
  for (const [sx, sy] of [[27, 23], [27, 26], [52, 23], [52, 26]]) {
    setD(sx, sy, 60);
  }
  setD(28, 32, 65);
  setD(48, 32, 65);

  // 6. ZONE 3: Velvet Canopy Stage & Upper Moss-Bloom Cliff Sanctuary
  fillRect(setG, 5, 4, 18, 10, 48);
  // Mossy stepping-stone path atop Upper Velvet Ledge
  for (let x = 8; x <= 22; x += 2) setG(x, 8, 54);
  for (let x = 4; x <= 23; x++) {
    setD(x, 14, 49);
  }
  for (let y = 14; y <= 16; y++) {
    for (let x = 12; x <= 14; x++) {
      setD(x, y, 25); // Required moss_target (12..14, 14..16)!
    }
  }
  setD(9, 7, 46);
  fillRect(setG, 8, 20, 11, 5, 23);
  fillRect(setG, 7, 25, 13, 8, 22);
  // Extended bohemian carpet runner & woodland fern/lavender border
  fillRect(setG, 11, 33, 5, 4, 22);
  fillRect(setD, 8, 19, 11, 1, 24);
  setD(8, 21, 12);
  setD(18, 21, 12);
  setD(7, 27, 17);
  setD(19, 27, 17);
  setD(6, 31, 17);
  setD(20, 31, 17);
  for (let y = 21; y <= 31; y += 2) {
    setD(5, y, y % 4 === 1 ? 62 : 63);
    setD(21, y, y % 4 === 1 ? 63 : 62);
  }

  // 7. ZONE 4: The Mellow Meadow, Clover Rings & The Old Oak
  fillRect(setG, 62, 22, 26, 16, 2);
  fillDisc(setG, 72, 28, 6.5, 4.5, 50); // Golden clover circle around Blessing Stone (1152,448 => 72,28)
  fillRect(setG, 66, 28, 3, 3, 15);
  fillRect(setG, 70, 27, 4, 3, 15);
  fillRect(setG, 73, 32, 3, 3, 15);
  fillRect(setG, 68, 24, 4, 3, 28);
  // Preserved Mellow Meadow service asphalt strip at tx:79..80, ty:23..35 (including (79,28)!)
  fillRect(setG, 79, 23, 2, 13, 7);
  // Old Oak ancient roots, golden leaf carpet & sprawling canopy (84,24)
  fillDisc(setG, 84, 25, 3.6, 2.8, 51);
  fillRect(setD, 84, 24, 2, 2, 27);
  fillRect(setC, 81, 19, 8, 6, 11);
  setC(82, 25, 69);
  setC(87, 25, 69);
  setD(82, 23, 17);
  setD(87, 23, 17);
  // Wildflowers framing Mellow Meadow north & east edges (clear of Ziggy's spline!)
  for (const [fx, fy, fid] of [
    [62, 22, 60], [64, 21, 61], [76, 21, 62], [86, 28, 61], [87, 30, 60],
  ]) {
    setD(fx, fy, fid);
  }

  // 8. ZONE 5: The Andromeda Pavilion & Crystal Approach Paths
  fillRect(setG, 100, 16, 20, 16, 29);
  for (let x = 100; x < 120; x++) {
    setD(x, 16, 30);
    if (x < 108 || x > 111) setD(x, 31, 30);
  }
  for (let y = 16; y <= 31; y++) {
    if (y < 23 || y > 25) setD(100, y, 30);
    setD(119, y, 30);
  }
  // Stepping-stone starlight paths out to all 3 Meteoric Space-Glass Resonators!
  for (let y = 32; y <= 38; y++) setG(109, y, 54);
  for (let x = 96; x <= 99; x++) setG(x, 24, 54);
  for (let y = 13; y <= 16; y++) setG(98, y, 54);
  for (let x = 120; x <= 122; x++) setG(x, 14, 54);
  for (let y = 32; y <= 35; y++) setG(121, y, 54);
  setD(98, 12, 31);
  setD(122, 14, 31);
  setD(121, 35, 31);
  setD(98, 22, 17);
  setD(107, 33, 17);
  setD(112, 33, 17);

  // 9. ZONE 6: The Urbano Canopy & Santurce Courtyard
  fillRect(setG, 7, 62, 16, 18, 34);
  // Cobblestone Santurce dance apron in front of Don Shell-O's stage truck
  fillRect(setG, 9, 66, 12, 8, 53);
  fillRect(setD, 10, 61, 8, 2, 32);
  setD(8, 62, 33);
  setD(9, 62, 33);
  setD(19, 62, 33);
  setD(20, 62, 33);
  setD(7, 68, 81);
  setD(22, 68, 81);
  setD(7, 74, 17);
  setD(22, 74, 17);
  // Parked Santurce Tour Microbus & cider barrels on east/north courtyard edge
  setD(24, 63, 76); setD(25, 63, 77); setD(26, 63, 78);
  setD(6, 64, 66);
  setD(6, 77, 60);
  setD(23, 77, 61);

  // 10. ZONE 7: The Undergrowth & Bioluminescent Tea-Light Circle
  fillRect(setG, 58, 3, 34, 14, 35);
  fillRect(setG, 23, 7, 35, 3, 5);
  // Stepping stones along Janice's secret moss trail & southern Undergrowth entrance
  for (let x = 25; x <= 56; x += 3) setG(x, 8, 54);
  for (let y = 14; y <= 17; y++) setG(75, y, 54);
  for (let x = 57; x <= 92; x++) {
    setD(x, 2, 37);
    if (x < 73 || x > 77) setD(x, 16, 37);
  }
  setG(73, 7, 36);
  setG(77, 7, 36);
  setG(73, 11, 36);
  setG(77, 11, 36);
  setG(75, 9, 36);
  // Fairy-ring ferns & toadstools framing West Moss Arch (66,13) & East Fern Clearing (83,12)
  for (const [fx, fy] of [[63, 12], [69, 12], [81, 11], [86, 11], [72, 6], [78, 6]]) {
    setD(fx, fy, 63);
  }
  setD(72, 17, 17);
  setD(78, 17, 17);
  fillRect(setC, 60, 4, 30, 10, 11);

  // 11. ZONE 8: Shady Bottoms Campground Village, Campfire & Vendor Row Market
  // Corduroy timber & cobblestone Vendor Row promenade
  fillRect(setG, 70, 61, 17, 3, 53);
  fillRect(setG, 77, 72, 10, 4, 53);
  // Existing core Campground & Vendor Row props
  fillRect(setD, 60, 59, 4, 2, 13);
  setD(61, 61, 14);
  setG(65, 61, 41);
  setD(67, 60, 20);
  setD(69, 60, 39);
  setD(71, 60, 18);
  setD(72, 60, 38);
  fillRect(setG, 55, 70, 2, 2, 15);
  fillRect(setD, 60, 74, 3, 2, 13);
  setD(61, 76, 14);
  fillRect(setD, 68, 74, 3, 2, 13);
  setD(69, 76, 14);
  fillRect(setD, 79, 60, 4, 1, 18);
  setD(84, 60, 38);
  setD(85, 60, 38);
  fillRect(setD, 79, 74, 4, 1, 40);
  setD(84, 74, 39);
  setD(77, 66, 17);
  // Expanded 1969 Tent Village, Communal Campfire Hearth & Market Festoon Posts!
  setD(67, 65, 79); // Crackling Communal Campfire Hearth at (1080, 1048) in Campground Commons!
  setD(65, 65, 65); // Hay bale seat west of campfire
  setD(69, 65, 82); // Acoustic folk guitar & vinyl crate east of campfire
  setD(57, 60, 72); setD(58, 60, 73); // Teal A-Frame tent NW
  setD(57, 74, 74); setD(58, 74, 75); // Saffron Tie-Dye dome tent SW
  setD(64, 75, 72); setD(65, 75, 73); // Teal A-Frame tent South
  setD(73, 75, 74); setD(74, 75, 75); // Saffron Tie-Dye dome tent SE
  setD(70, 59, 81);
  setD(78, 59, 81);
  setD(86, 59, 81);
  setD(78, 73, 81);
  setD(86, 73, 81);
  setD(86, 61, 66); // Oak cider barrel stack at east end of Vendor Row

  // 12. ZONE 9: The Sorting Machine Arcade Tent & Carnival Boardwalk
  fillRect(setG, 99, 59, 20, 18, 42);
  // Cedar boardwalk entrance plazas at West (x:96..98, y:67..70) & South (x:106..110, y:77..79) doors
  fillRect(setG, 96, 67, 3, 4, 55);
  fillRect(setG, 106, 77, 5, 3, 55);
  for (let x = 99; x < 119; x++) {
    setD(x, 59, 45);
    if (x < 106 || x > 110) setD(x, 76, 45);
  }
  for (let y = 59; y <= 76; y++) {
    if (y < 67 || y > 70) setD(99, y, 45);
    setD(118, y, 45);
  }
  setD(103, 62, 43);
  setD(106, 62, 43);
  fillRect(setG, 111, 63, 5, 2, 44);
  setD(113, 61, 46);
  setD(98, 66, 81);
  setD(98, 71, 81);
  setD(105, 77, 81);
  setD(111, 77, 81);

  // 13. Structured Heritage Walnut Orchard Groves across previously bare interstitial fields!
  // Each orchard tree has a 3D walnut trunk (16), lush paired walnut canopy boughs (70, 71, 11),
  // golden fallen leaves (51), and occasional wicker harvest baskets (67) & wildflowers!
  const orchardGroves = [
    // West Orchard Grove (between Velvet Canopy & Urbano Canopy, x:6..28, y:44..57)
    [8, 46], [13, 46], [21, 46], [26, 46],
    [10, 51], [23, 51], [28, 52],
    [8, 56], [13, 56], [21, 56], [26, 56],
    // Central Heart-of-the-Farm Walnut Orchard (east of Main Promenade, x:44..58, y:44..64)
    [45, 45], [50, 45], [55, 45],
    [47, 50], [52, 50], [57, 50],
    [45, 56], [50, 56], [55, 56],
    [47, 62], [52, 62],
    // West Promenade Orchard Row (west of Main Promenade, x:22..33, y:45..64)
    [25, 48], [31, 46], [31, 52], [30, 62],
    // North-East Ridge Grove (between Mellow Meadow, Willow Creek & Andromeda, x:95..102, y:43..55)
    [96, 45], [100, 45], [97, 51], [101, 51], [114, 44], [118, 48], [114, 53],
    // South Entrance & Outer Pastures (flanking Front Gate & Campground south)
    [12, 84], [18, 86], [29, 82], [46, 82], [54, 84], [62, 85], [72, 85], [82, 84], [102, 84], [112, 84],
  ];
  for (let i = 0; i < orchardGroves.length; i++) {
    const [tx, ty] = orchardGroves[i];
    if (decor[ty * W + tx] !== 0) continue;
    setG(tx, ty, 51);
    setG(tx - 1, ty, 51);
    setD(tx, ty, 16);
    setC(tx - 1, ty - 1, 70);
    setC(tx, ty - 1, 11);
    setC(tx + 1, ty - 1, 71);
    if (i % 4 === 0 && decor[ty * W + (tx + 1)] === 0) {
      setD(tx + 1, ty, 67); // harvest walnut basket beside every 4th tree!
    } else if (i % 3 === 1 && decor[(ty + 1) * W + tx] === 0) {
      setD(tx, ty + 1, i % 2 === 0 ? 61 : 62);
    }
  }

  function layerToCsv(arr) {
    const rows = [];
    for (let y = 0; y < H; y++) {
      const slice = [];
      for (let x = 0; x < W; x++) slice.push(arr[y * W + x]);
      rows.push(slice.join(','));
    }
    return rows.join(',\n');
  }

  const objectsXml = [
    `<object id="1" name="player_spawn" type="spawn" x="608" y="1344" width="16" height="16"/>`,
    `<object id="10" name="Front Gate &amp; Broken Fences" type="zone" x="384" y="1120" width="448" height="400"/>`,
    `<object id="11" name="Main Roots Stage &amp; High-Branch Booth" type="zone" x="416" y="288" width="448" height="480"/>`,
    `<object id="12" name="The Velvet Canopy Stage" type="zone" x="64" y="64" width="352" height="576"/>`,
    `<object id="13" name="The Mellow Meadow &amp; The Old Oak" type="zone" x="928" y="288" width="544" height="448"/>`,
    `<object id="14" name="The Andromeda Pavilion" type="zone" x="1536" y="128" width="448" height="480"/>`,
    `<object id="15" name="The Urbano Canopy" type="zone" x="64" y="896" width="384" height="480"/>`,
    `<object id="16" name="The Undergrowth &amp; Tea-Light Circle" type="zone" x="896" y="32" width="608" height="256"/>`,
    `<object id="17" name="Shady Bottoms Campground &amp; Vendor Row" type="zone" x="896" y="864" width="592" height="528"/>`,
    `<object id="18" name="The Sorting Machine Arcade Tent" type="zone" x="1536" y="864" width="464" height="496"/>`,
    `<object id="20" name="campground_tent_occlusion" type="occlusion" x="952" y="936" width="80" height="72"/>`,
    `<object id="21" name="sorting_arcade_occlusion" type="occlusion" x="1584" y="944" width="320" height="288"/>`,
    `<object id="22" name="undergrowth_canopy_occlusion" type="occlusion" x="928" y="48" width="544" height="224"/>`,
    `<object id="23" name="old_oak_canopy_occlusion" type="occlusion" x="1312" y="320" width="96" height="80"/>`,
    `<object id="30" name="tent_rest_spot" type="interactable" x="976" y="976" width="32" height="32"/>`,
    `<object id="31" name="turntable_spot" type="interactable" x="1072" y="960" width="32" height="32"/>`,
    `<object id="32" name="falafel_stand" type="interactable" x="1264" y="960" width="64" height="32"/>`,
    `<object id="33" name="old_oak_roots" type="interactable" x="1344" y="384" width="32" height="32"/>`,
    `<object id="34" name="high_branch_ladder" type="interactable" x="768" y="352" width="48" height="48"/>`,
    `<object id="35" name="vocal_tea_vine" type="interactable" x="1344" y="960" width="32" height="32"/>`,
    `<object id="36" name="resonator_nw" type="interactable" x="1568" y="192" width="32" height="32"/>`,
    `<object id="37" name="resonator_ne" type="interactable" x="1952" y="224" width="32" height="32"/>`,
    `<object id="38" name="resonator_se" type="interactable" x="1936" y="560" width="32" height="32"/>`,
    `<object id="39" name="meadow_blessing_stone" type="interactable" x="1152" y="448" width="32" height="32"/>`,
    `<object id="40" name="don_shello_buried_stash" type="interactable" x="192" y="1216" width="32" height="32"/>`,
    `<object id="41" name="tea_light_altar" type="interactable" x="1200" y="144" width="32" height="32"/>`,
    `<object id="42" name="pinball_cabinet" type="interactable" x="1648" y="992" width="64" height="32"/>`,
    `<object id="43" name="sorting_belt_console" type="interactable" x="1776" y="1008" width="80" height="32"/>`,
    `<object id="44" name="artifact_booth" type="interactable" x="1264" y="1184" width="64" height="32"/>`,
    `<object id="45" name="terminal_velvet_ledge" type="interactable" x="144" y="112" width="32" height="32"/>`,
    `<object id="46" name="terminal_arcade" type="interactable" x="1808" y="976" width="32" height="32"/>`,
    `<object id="47" name="penny_craft_blanket" type="interactable" x="880" y="1120" width="32" height="32"/>`,
    `<object id="48" name="colin_curio_crate" type="interactable" x="1344" y="1192" width="32" height="32"/>`,
    `<object id="49" name="street_food_cart" type="interactable" x="1136" y="968" width="32" height="32"/>`,
    `<object id="50" name="bulletin_lost_found" type="interactable" x="680" y="1224" width="32" height="32"/>`,
    `<object id="51" name="lost_brass_compass" type="interactable" x="484" y="612" width="24" height="24"/>`,
  ].join('\n  ');

  const tmx = `<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.10.2" orientation="orthogonal" renderorder="right-down" width="${W}" height="${H}" tilewidth="16" tileheight="16" infinite="0" nextlayerid="6" nextobjectid="60">
 <tileset firstgid="1" source="orchard_tileset.tsx"/>
 <layer id="1" name="ground" width="${W}" height="${H}">
  <data encoding="csv">
${layerToCsv(ground)}
  </data>
 </layer>
 <layer id="2" name="decor" width="${W}" height="${H}">
  <data encoding="csv">
${layerToCsv(decor)}
  </data>
 </layer>
 <layer id="3" name="canopy" width="${W}" height="${H}">
  <data encoding="csv">
${layerToCsv(canopy)}
  </data>
 </layer>
 <objectgroup id="4" name="zones_and_triggers">
  ${objectsXml}
 </objectgroup>
</map>
`;
  fs.writeFileSync(path.join(ROOT, 'assets/tiles/free_orchard_full.tmx'), tmx, 'utf8');

  // Automated Generation-Time Walkability & Test Invariant Verification!
  if (tileMetadata.length > 0) {
    const collidableIds = new Set(tileMetadata.filter((m) => m.collidable).map((m) => m.id));
    const isBlockedTile = (tx, ty) => {
      if (tx < 0 || ty < 0 || tx >= W || ty >= H) return true;
      const gId = ground[ty * W + tx] - 1;
      const dId = decor[ty * W + tx] - 1;
      return collidableIds.has(gId) || collidableIds.has(dId);
    };
    const assertPointOpen = (label, wx, wy) => {
      const tx = Math.floor(wx / 16);
      const ty = Math.floor(wy / 16);
      if (isBlockedTile(tx, ty)) {
        throw new Error(`[Map Verifier] Blocked gameplay coordinate ${label} at (${wx}, ${wy}) -> tile (${tx}, ${ty})!`);
      }
    };

    const npcsPath = path.join(ROOT, 'assets/data/npcs_and_quests.json');
    if (fs.existsSync(npcsPath)) {
      const data = JSON.parse(fs.readFileSync(npcsPath, 'utf8'));
      for (const npc of data.npcs ?? []) {
        assertPointOpen(`NPC ${npc.id}`, npc.spawnX, npc.spawnY);
        for (const [wx, wy] of npc.waypoints ?? []) {
          assertPointOpen(`NPC ${npc.id} waypoint`, wx, wy);
        }
      }
      for (const q of data.quests ?? []) {
        assertPointOpen(`Quest ${q.id}`, q.targetX, q.targetY);
      }
      for (const t of data.totems ?? []) {
        assertPointOpen(`Totem ${t.id}`, t.x, t.y);
      }
    }

    const criticalWorldSpots = [
      ['player_spawn', 608, 1344],
      ['lineup_kiosk', 536, 1320],
      ['cultivar_booth', 680, 1320],
      ['cultivar_chandler', 520, 1248],
      ['cultivar_hartley', 744, 520],
      ['cultivar_howard', 472, 488],
      ['cultivar_tulare', 312, 472],
      ['cultivar_franquette', 1032, 520],
      ['cultivar_hindsii', 1272, 512],
      ['cultivar_wen_wan', 336, 1088],
      ['cultivar_red_livermore', 928, 1032],
      ['cultivar_serr', 1648, 544],
      ['cultivar_heartnut', 1424, 920],
      ['cultivar_butternut', 1520, 1120],
      ['blueberry_basket', 1096, 496],
      ['fog_entrance', 1200, 248],
      ['fog_wp_west', 1064, 212],
      ['fog_wp_east', 1336, 196],
      ['fog_sanctum', 1200, 144],
    ];
    for (const [label, wx, wy] of criticalWorldSpots) {
      assertPointOpen(label, wx, wy);
    }
  }
}

// ============================================================================
// 3. 3D-SCULPTED WALNUT CHARACTER SHEETS (96x128) & PORTRAITS (64x64)
// ============================================================================
const CHARACTER_SPECS = [
  // 11 Visually Distinct Player Walnut Cultivars (unique shell silhouettes, bump textures, crowns & palettes!)
  { id: 'cultivar_chandler', shell: '#e3a857', ridge: '#8f5319', accent: '#5c4738', portraitBg: '#52b788', glasses: null, hat: null, shellShape: 'classic_sprout', bumpStyle: 'classic', sproutLeaf: true },
  { id: 'cultivar_hartley', shell: '#d48c3b', ridge: '#6e3910', accent: '#5c4738', portraitBg: '#e9c46a', glasses: null, hat: null, shellShape: 'hartley_cone', bumpStyle: 'shoulder_band', broad: true },
  { id: 'cultivar_howard', shell: '#bf6535', ridge: '#61260b', accent: '#5c4738', portraitBg: '#f4a261', glasses: null, hat: null, shellShape: 'plump_round', bumpStyle: 'freckled', broad: true },
  { id: 'cultivar_tulare', shell: '#6e3b1e', ridge: '#2e1406', accent: '#5c4738', portraitBg: '#e76f51', glasses: null, hat: null, shellShape: 'ribbed_barrel', bumpStyle: 'vertical_ribs' },
  { id: 'cultivar_franquette', shell: '#e6be8a', ridge: '#8f6538', accent: '#5c4738', portraitBg: '#a8dadc', glasses: null, hat: null, shellShape: 'teardrop', bumpStyle: 'delicate', tall: true },
  { id: 'cultivar_juglans_hindsii', shell: '#2e2930', ridge: '#110e14', accent: '#5c4738', portraitBg: '#9d4edd', glasses: null, hat: null, shellShape: 'sleek_black', bumpStyle: 'smooth_stone', coolRim: true },
  { id: 'cultivar_wen_wan', shell: '#b84a27', ridge: '#4f1606', accent: '#5c4738', portraitBg: '#ffd166', glasses: null, hat: null, shellShape: 'lion_lattice', bumpStyle: 'lion_lattice', sculpted: true, goldEquator: true },
  { id: 'cultivar_red_livermore', shell: '#9e2a3b', ridge: '#4a0e17', accent: '#5c4738', portraitBg: '#ff4d6d', glasses: null, hat: null, shellShape: 'crimson_oval', bumpStyle: 'ruby_veins', rubySeam: true },
  { id: 'cultivar_serr', shell: '#f2dfc4', ridge: '#a68a64', accent: '#5c4738', portraitBg: '#90e0ef', glasses: null, hat: null, shellShape: 'smooth_porcelain', bumpStyle: 'porcelain' },
  { id: 'cultivar_japonica_heartnut', shell: '#c97b50', ridge: '#6e351a', accent: '#5c4738', portraitBg: '#ff8fab', glasses: null, hat: null, shellShape: 'heart', bumpStyle: 'smooth_heart' },
  { id: 'cultivar_cinerea_butternut', shell: '#847e5c', ridge: '#3d3a26', accent: '#5c4738', portraitBg: '#80ed99', glasses: null, hat: null, shellShape: 'butternut_spindle', bumpStyle: 'jagged_bark', tall: true },

  // 34 Festival Cast, Performers & Stage-Front Dancers!
  { id: 'npc_patchouli_pete', shell: '#cc8c4b', ridge: '#78491b', accent: '#c97a3d', glasses: '#ffb703', hat: 'bandana_red', outfit: 'suede_fringe', facial: 'goatee' },
  { id: 'npc_jimi_hendshell', shell: '#73492e', ridge: '#381e0e', accent: '#f1ede4', glasses: null, hat: 'bandana_purple', outfit: 'fringed_buckskin', hair: 'afro_crown', facial: 'santana_mustache', guitar: '#f8f9fa' },
  { id: 'npc_janice_joeplant', shell: '#bf7a43', ridge: '#6e3c16', accent: '#b5179e', glasses: '#ff70a6', hat: 'feathers', outfit: 'velvet_boa', hair: 'long_parted' },
  { id: 'npc_cosmo_shellvoy', shell: '#743ad5', ridge: '#ffd166', accent: '#1b263b', glasses: '#caf0f8', hat: 'star_crest', outfit: 'nebula_robe', guitar: '#72efdd' },
  { id: 'npc_don_shello', shell: '#945926', ridge: '#242423', accent: '#b81d24', glasses: '#1c1c24', hat: 'crown_cap', outfit: 'varsity_gold', facial: 'goatee' },
  { id: 'npc_barnaby_breezewalker', shell: '#d4a66e', ridge: '#82592c', accent: '#2d6a4f', glasses: null, hat: 'felt_twig', outfit: 'bard_cloak', guitar: '#bc6c25' },
  { id: 'npc_joan_baezelnut', shell: '#c78e54', ridge: '#73481f', accent: '#3a86ff', glasses: null, hat: 'flower_braid', outfit: 'peasant_embroidery', hair: 'long_parted', guitar: '#dda15e' },
  { id: 'npc_ziggy_shellshock', shell: '#cc8c4b', ridge: '#7a4719', accent: '#9b2226', glasses: '#fb8500', hat: null },
  { id: 'npc_burt_baskernut', shell: '#dea35b', ridge: '#87551c', accent: '#e9c46a', glasses: null, hat: 'scarf_seafoam' },
  { id: 'npc_tula_twigwalker', shell: '#2d7870', ridge: '#48cae4', accent: '#f77f00', glasses: null, hat: 'shawl_sunset' },
  { id: 'npc_barnaby_bittershell', shell: '#a16844', ridge: '#522a0a', accent: '#e63946', glasses: null, hat: 'bedroll' },
  { id: 'npc_literally_infinite', shell: '#ffd166', ridge: '#e08e3c', accent: '#80ffdb', glasses: '#ffffff', hat: 'halo', outfit: 'tie_dye', guitar: '#ffe66d' },
  { id: 'npc_boddhi_barkhand', shell: '#ab754a', ridge: '#633c12', accent: '#d4a373', glasses: null, hat: null },
  { id: 'npc_colin_walnut', shell: '#c28e60', ridge: '#80532a', accent: '#e76f51', glasses: '#a8dadc', hat: null },
  { id: 'npc_nora_walnut', shell: '#d9a673', ridge: '#915b38', accent: '#ffafcc', glasses: null, hat: 'flower_braid' },
  { id: 'npc_raymond_walnut', shell: '#a15c2b', ridge: '#522a0a', accent: '#8ac926', glasses: '#ffca3a', hat: 'bandana_red' },
  { id: 'npc_elsie_walnut', shell: '#e0ba92', ridge: '#915b38', accent: '#ffca3a', glasses: null, hat: 'felt_twig' },
  { id: 'npc_wen_wan_elder', shell: '#875426', ridge: '#3d220d', accent: '#52b788', glasses: null, hat: 'halo', sculpted: true },
  { id: 'npc_arcade_attendant', shell: '#b58063', ridge: '#633e2a', accent: '#7209b7', glasses: '#ffbe0b', hat: 'crown_cap', outfit: 'tracksuit_neon' },
  { id: 'npc_festivalgoer_a', shell: '#c28e60', ridge: '#80532a', accent: '#e76f51', glasses: null, hat: null },
  { id: 'npc_festivalgoer_b', shell: '#d9a673', ridge: '#915b38', accent: '#ffafcc', glasses: null, hat: 'flower_braid' },

  // 15 New Festivalgoers, Stage Dancers & Orchard Folk Across All 9 Zones!
  { id: 'npc_sunny_shellflower', shell: '#e6b57e', ridge: '#8f582a', accent: '#ff595e', glasses: '#ffd166', hat: 'daisy_clip', outfit: 'tie_dye', hair: 'blonde_fringe' },
  { id: 'npc_hazel_groove', shell: '#9e2a3b', ridge: '#4a0e17', accent: '#ffbe0b', glasses: null, hat: 'beaded_headband', outfit: 'sunshine_poncho', shellShape: 'crimson_oval', bumpStyle: 'ruby_veins' },
  { id: 'npc_clover_husk', shell: '#d4a36c', ridge: '#855b2e', accent: '#52b788', glasses: null, hat: 'woven_garland', outfit: 'boho_ivory_lace', shellShape: 'teardrop', tall: true },
  { id: 'npc_pippin_pecan', shell: '#c97b50', ridge: '#6e351a', accent: '#48cae4', glasses: '#ff70a6', hat: 'straw_sunhat', outfit: 'paisley_psych', shellShape: 'heart', bumpStyle: 'smooth_heart' },
  { id: 'npc_roxie_roast', shell: '#6e3b1e', ridge: '#2e1406', accent: '#f72585', glasses: '#4cc9f0', hat: 'velvet_beret', outfit: 'velvet_boa', shellShape: 'ribbed_barrel', bumpStyle: 'vertical_ribs' },
  { id: 'npc_saffron_suture', shell: '#d48c3b', ridge: '#6e3910', accent: '#ff9f1c', glasses: null, hat: 'bandana_purple', outfit: 'floral_caftan', shellShape: 'hartley_cone', broad: true },
  { id: 'npc_mateo_cascara', shell: '#a66332', ridge: '#52290d', accent: '#06d6a0', glasses: '#ffbe0b', hat: 'panama_fedora', outfit: 'guayabera_white', facial: 'santana_mustache' },
  { id: 'npc_paloma_hull', shell: '#bf6535', ridge: '#61260b', accent: '#e63946', glasses: null, hat: 'daisy_clip', outfit: 'dashiki_gold', hair: 'afro_crown', shellShape: 'plump_round', bumpStyle: 'freckled' },
  { id: 'npc_astra_nebula', shell: '#2e2930', ridge: '#110e14', accent: '#7209b7', glasses: '#80ffdb', hat: 'crystal_antennae', outfit: 'nebula_robe', shellShape: 'sleek_black', coolRim: true },
  { id: 'npc_orion_kernel', shell: '#f2dfc4', ridge: '#a68a64', accent: '#3a86ff', glasses: '#f72585', hat: 'solar_crown', outfit: 'mod_turtleneck', shellShape: 'smooth_porcelain', bumpStyle: 'porcelain' },
  { id: 'npc_daisy_dewdrop', shell: '#e3a857', ridge: '#8f5319', accent: '#80ed99', glasses: null, hat: 'flower_braid', outfit: 'peasant_embroidery', sproutLeaf: true },
  { id: 'npc_woody_granola', shell: '#847e5c', ridge: '#3d3a26', accent: '#bc6c25', glasses: '#e9c46a', hat: 'arlo_floppy_hat', outfit: 'suede_fringe', facial: 'full_beard', shellShape: 'butternut_spindle', bumpStyle: 'jagged_bark', tall: true },
  { id: 'npc_penny_patchwork', shell: '#d99e5b', ridge: '#855220', accent: '#9b5de5', glasses: '#00bbf9', hat: 'knit_beanie', outfit: 'tie_dye', hair: 'mop_curls' },
  { id: 'npc_rusty_pinball', shell: '#b84a27', ridge: '#4f1606', accent: '#00f5d4', glasses: '#fee440', hat: 'kangol_white', outfit: 'mod_target_tee', shellShape: 'lion_lattice', bumpStyle: 'lion_lattice', sculpted: true },
  { id: 'npc_fern_whisper', shell: '#95a578', ridge: '#465432', accent: '#38b000', glasses: null, hat: 'felt_twig', outfit: 'bard_cloak', shellShape: 'teardrop', tall: true },

  // Bespoke On-Stage Band Musicians & Canonical Lineup Artists (100% unique look for every performer across all 30 sets!)
  { id: 'perf_meadow_bass', sheetOnly: true, shell: '#c88d55', ridge: '#73451c', accent: '#8d5b34', glasses: null, hat: 'straw_sunhat', outfit: 'suede_fringe', facial: 'sideburns' },
  { id: 'perf_carlos_santana', sheetOnly: true, shell: '#7c4d2b', ridge: '#381d0c', accent: '#221f26', glasses: null, hat: 'pan_african_band', outfit: 'latin_vest', hair: 'mop_curls', facial: 'santana_mustache' },
  { id: 'perf_santana_congas', sheetOnly: true, shell: '#a66332', ridge: '#52290d', accent: '#f8f9fa', glasses: '#ffbe0b', hat: null, outfit: 'guayabera_white', hair: 'afro_crown' },
  { id: 'perf_santana_drums', sheetOnly: true, shell: '#d99f5c', ridge: '#875421', accent: '#80ed99', glasses: null, hat: null, hair: 'mop_curls' },
  { id: 'perf_santana_organ', sheetOnly: true, shell: '#b87b44', ridge: '#633a16', accent: '#720026', glasses: '#4ea8de', hat: null, outfit: 'velvet_boa', facial: 'sideburns' },
  { id: 'perf_kozmic_guitar', sheetOnly: true, shell: '#c98850', ridge: '#70411a', accent: '#9d4edd', glasses: '#48cae4', hat: null, outfit: 'paisley_psych', hair: 'mop_curls', facial: 'sideburns' },
  { id: 'perf_kozmic_drums', sheetOnly: true, shell: '#9c5d30', ridge: '#4a250b', accent: '#3d405b', glasses: null, hat: 'derby_crimson', outfit: 'sgt_tunic' },
  { id: 'perf_kozmic_organ', sheetOnly: true, tall: true, shell: '#d4a36c', ridge: '#7d5327', accent: '#00b4d8', glasses: '#ffd166', hat: 'beaded_headband' },
  { id: 'perf_john_fogerty', sheetOnly: true, shell: '#c28448', ridge: '#6e3f16', accent: '#d62828', glasses: null, hat: null, outfit: 'flannel_plaid', hair: 'mop_curls', facial: 'sideburns' },
  { id: 'perf_tom_fogerty', sheetOnly: true, shell: '#cc9054', ridge: '#75461b', accent: '#2b59c3', glasses: null, hat: 'rancher_hat', outfit: 'denim_snap' },
  { id: 'perf_stu_cook', sheetOnly: true, broad: true, shell: '#b57840', ridge: '#613713', accent: '#588157', glasses: '#ffb703', hat: null, facial: 'sideburns' },
  { id: 'perf_doug_clifford', sheetOnly: true, shell: '#a86934', ridge: '#542c0d', accent: '#457b9d', glasses: null, hat: 'navy_bandana', facial: 'goatee' },
  { id: 'perf_mama_cass', sheetOnly: true, broad: true, shell: '#de9e62', ridge: '#875223', accent: '#f72585', glasses: null, hat: 'daisy_clip', outfit: 'floral_caftan', hair: 'long_parted' },
  { id: 'perf_michelle_husk', sheetOnly: true, shell: '#e6b57e', ridge: '#946334', accent: '#ffbe0b', glasses: null, hat: null, outfit: 'sunshine_poncho', hair: 'blonde_fringe' },
  { id: 'perf_denny_husk', sheetOnly: true, shell: '#b87d4b', ridge: '#693d18', accent: '#2d6a4f', glasses: null, hat: 'velvet_beret', outfit: 'bard_cloak' },
  { id: 'perf_john_husk', sheetOnly: true, tall: true, shell: '#CFA06B', ridge: '#7A4E24', accent: '#5e548e', glasses: '#e0fbfc', hat: 'stovepipe_hat', facial: 'goatee' },
  { id: 'perf_billy_cox', sheetOnly: true, shell: '#5c3c28', ridge: '#29170c', accent: '#1d3557', glasses: null, hat: 'black_beret', outfit: 'dashiki_gold', facial: 'santana_mustache' },
  { id: 'perf_mitch_mitchell', sheetOnly: true, shell: '#cc8f56', ridge: '#78471c', accent: '#d90429', glasses: null, hat: null, outfit: 'hussar_jacket', hair: 'mop_curls' },
  { id: 'perf_urbano_dj', sheetOnly: true, shell: '#9e6231', ridge: '#47250a', accent: '#00f5d4', glasses: '#f72585', hat: 'kangol_white', outfit: 'tracksuit_neon' },
  { id: 'perf_urbano_perc', sheetOnly: true, shell: '#b06d35', ridge: '#592e0d', accent: '#e63946', glasses: null, hat: 'panama_fedora', outfit: 'floral_caftan', facial: 'santana_mustache' },
  { id: 'perf_cosmo_synth', sheetOnly: true, sculpted: true, shell: '#8f5228', ridge: '#3d1e08', accent: '#0077b6', glasses: '#ffd166', hat: 'solar_crown', outfit: 'nebula_robe' },
  { id: 'perf_cosmo_perc', sheetOnly: true, shell: '#9d7cd8', ridge: '#48cae4', accent: '#560bad', glasses: null, hat: 'crystal_antennae', outfit: 'nebula_robe' },
  { id: 'perf_li_drums', sheetOnly: true, shell: '#c48347', ridge: '#6e3e15', accent: '#00bbf9', glasses: null, hat: null, outfit: 'sgt_tunic', hair: 'mop_curls', facial: 'ringo_stache' },
  { id: 'perf_li_bass', sheetOnly: true, tall: true, shell: '#d99e5b', ridge: '#855220', accent: '#ff595e', glasses: '#4cc9f0', hat: 'beaded_headband', outfit: 'tie_dye' },
  { id: 'perf_li_organ', sheetOnly: true, shell: '#d6a672', ridge: '#805529', accent: '#1b1b24', glasses: '#ced4da', hat: null, outfit: 'mod_turtleneck', hair: 'blonde_fringe' },

  // Track 1: Nutcracker Joe & The Hull Band
  { id: 'perf_nutcracker_joe', sheetOnly: true, shell: '#c5874d', ridge: '#6e3d14', accent: '#f8f9fa', glasses: null, hat: null, outfit: 'cocker_star_shirt', hair: 'mop_curls', facial: 'sideburns', whiteBoots: true },
  { id: 'perf_hullband_guitar', sheetOnly: true, shell: '#b87a44', ridge: '#633712', accent: '#3a5a40', glasses: null, hat: null, outfit: 'denim_snap', facial: 'full_beard' },
  { id: 'perf_hullband_bass', sheetOnly: true, shell: '#c98e54', ridge: '#704218', accent: '#8d5b34', glasses: null, hat: 'beaded_headband', outfit: 'suede_fringe' },
  { id: 'perf_hullband_drums', sheetOnly: true, shell: '#a86b38', ridge: '#542c0d', accent: '#9b2226', glasses: null, hat: null, outfit: 'circus_stripes', hair: 'mop_curls' },

  // Track 3: Richie Shellens (Morning Acoustic Trio)
  { id: 'perf_richie_shellens', sheetOnly: true, tall: true, sculpted: true, shell: '#6b3e23', ridge: '#33190a', accent: '#f77f00', glasses: null, hat: null, outfit: 'dashiki_gold', facial: 'goatee' },
  { id: 'perf_richie_guitar2', sheetOnly: true, shell: '#7c4a29', ridge: '#3b1e0b', accent: '#9b2226', glasses: null, hat: null, outfit: 'dashiki_gold', hair: 'afro_crown' },
  { id: 'perf_richie_congas', sheetOnly: true, shell: '#87512d', ridge: '#42220d', accent: '#2a9d8f', glasses: null, hat: 'kufi_emerald', outfit: 'guayabera_white', facial: 'goatee' },

  // Track 4: The Walnut Blues Band
  { id: 'perf_blues_frontman', sheetOnly: true, shell: '#b57840', ridge: '#5e3410', accent: '#1d3557', glasses: '#00b4d8', hat: 'porkpie_navy', outfit: 'blues_pinstripe', facial: 'goatee' },
  { id: 'perf_blues_organ', sheetOnly: true, shell: '#cc8f56', ridge: '#75461b', accent: '#720026', glasses: '#ffb703', hat: null, outfit: 'mod_collar', facial: 'sideburns' },
  { id: 'perf_blues_bass', sheetOnly: true, shell: '#a36836', ridge: '#4f290b', accent: '#495057', glasses: null, hat: 'black_beret', outfit: 'denim_snap' },
  { id: 'perf_blues_drums', sheetOnly: true, shell: '#c4864c', ridge: '#6b3d15', accent: '#ca6702', glasses: null, hat: 'bandana_red', outfit: 'suede_fringe' },

  // Track 5: Melanie Sapka
  { id: 'perf_melanie_sapka', sheetOnly: true, shell: '#d9a066', ridge: '#855324', accent: '#f8edeb', glasses: null, hat: 'woven_garland', outfit: 'boho_ivory_lace', hair: 'long_parted' },

  // Track 6: Arlo Nutthrie
  { id: 'perf_arlo_nutthrie', sheetOnly: true, tall: true, shell: '#c88d55', ridge: '#73451c', accent: '#457b9d', glasses: null, hat: 'arlo_floppy_hat', outfit: 'denim_snap', hair: 'mop_curls' },
  { id: 'perf_arlo_dobro', sheetOnly: true, shell: '#b07d48', ridge: '#5e3814', accent: '#9c6644', glasses: null, hat: 'rancher_hat', outfit: 'suede_fringe', facial: 'walrus_stache' },
  { id: 'perf_arlo_bass', sheetOnly: true, shell: '#8d5b34', ridge: '#47280e', accent: '#bc4749', glasses: '#e9c46a', hat: null, outfit: 'flannel_plaid' },
  { id: 'perf_arlo_drums', sheetOnly: true, shell: '#bf854d', ridge: '#6b3e17', accent: '#588157', glasses: null, hat: 'straw_sunhat', outfit: 'bard_cloak' },

  // Track 9: Canned Walnut
  { id: 'perf_canned_bear', sheetOnly: true, broad: true, shell: '#9c6030', ridge: '#4a250b', accent: '#f1faee', glasses: null, hat: 'knit_beanie', outfit: 'bear_suspenders', facial: 'full_beard' },
  { id: 'perf_canned_blindowl', sheetOnly: true, shell: '#d4a373', ridge: '#7d5327', accent: '#a3b18a', glasses: '#f8f9fa', hat: null, outfit: 'denim_snap', hair: 'mop_curls' },
  { id: 'perf_canned_bass', sheetOnly: true, shell: '#7f4f24', ridge: '#3b1f09', accent: '#3d2512', glasses: null, hat: null, outfit: 'dark_buckskin', facial: 'sideburns' },
  { id: 'perf_canned_drums', sheetOnly: true, shell: '#b57840', ridge: '#613713', accent: '#00afb9', glasses: null, hat: 'bandana_red', outfit: 'latin_vest', facial: 'santana_mustache' },

  // Track 10: Mountain Grove
  { id: 'perf_mountain_leslie', sheetOnly: true, broad: true, tall: true, shell: '#b5763c', ridge: '#5e3410', accent: '#7f4f24', glasses: null, hat: null, outfit: 'fur_buckskin', hair: 'afro_crown' },
  { id: 'perf_mountain_felix', sheetOnly: true, shell: '#c9935b', ridge: '#75461b', accent: '#5a189a', glasses: null, hat: null, outfit: 'paisley_psych', hair: 'mop_curls', facial: 'santana_mustache' },
  { id: 'perf_mountain_drums', sheetOnly: true, shell: '#a66a38', ridge: '#522c0e', accent: '#e9c46a', glasses: null, hat: 'navy_bandana', outfit: 'suede_fringe' },

  // Track 13: Crosby, Stills, Nash & Walnut
  { id: 'perf_csny_stills', sheetOnly: true, shell: '#d19a62', ridge: '#7d4f22', accent: '#9b2226', glasses: null, hat: null, outfit: 'jersey_72', hair: 'blonde_fringe' },
  { id: 'perf_csny_crosby', sheetOnly: true, broad: true, shell: '#bd824a', ridge: '#693c14', accent: '#bc6c25', glasses: null, hat: null, outfit: 'suede_fringe', hair: 'long_parted', facial: 'walrus_stache' },
  { id: 'perf_csny_nash', sheetOnly: true, shell: '#cfa06b', ridge: '#7a4e24', accent: '#48cae4', glasses: null, hat: null, outfit: 'mod_collar', facial: 'sideburns' },
  { id: 'perf_csny_walnut', sheetOnly: true, tall: true, shell: '#8f582a', ridge: '#422209', accent: '#2b2623', glasses: null, hat: null, outfit: 'dark_buckskin', hair: 'long_parted', facial: 'sideburns' },

  // Tracks 16 & 17: The Hull
  { id: 'perf_hull_daltrey', sheetOnly: true, shell: '#d9a46c', ridge: '#855324', accent: '#f8f9fa', glasses: null, hat: null, outfit: 'white_fringe_cape', hair: 'blonde_fringe' },
  { id: 'perf_hull_townshend', sheetOnly: true, tall: true, shell: '#c48a52', ridge: '#6e4017', accent: '#f1faee', glasses: null, hat: null, outfit: 'boiler_mod_suit', whiteBoots: true },
  { id: 'perf_hull_entwistle', sheetOnly: true, shell: '#b87e48', ridge: '#633a14', accent: '#1b1b22', glasses: null, hat: null, outfit: 'skeleton_suit', hair: 'mop_curls', facial: 'sideburns' },
  { id: 'perf_hull_moon', sheetOnly: true, shell: '#cc8f56', ridge: '#78471c', accent: '#1d3557', glasses: null, hat: null, outfit: 'mod_target_tee', hair: 'mop_curls' },

  // Track 21: Country Joe & The Nut
  { id: 'perf_country_joe', sheetOnly: true, shell: '#be844c', ridge: '#693d16', accent: '#4f6d3a', glasses: null, hat: 'bandana_red', outfit: 'army_surplus', hair: 'mop_curls', facial: 'walrus_stache' },
  { id: 'perf_fish_barry', sheetOnly: true, shell: '#cf965e', ridge: '#7a4b20', accent: '#7209b7', glasses: '#ffbe0b', hat: null, outfit: 'tie_dye', hair: 'afro_crown' },
  { id: 'perf_fish_organ', sheetOnly: true, shell: '#d6a26c', ridge: '#805226', accent: '#e63946', glasses: null, hat: 'derby_crimson', outfit: 'circus_stripes' },
  { id: 'perf_fish_drums', sheetOnly: true, shell: '#a86e3a', ridge: '#542e0e', accent: '#3a86ff', glasses: null, hat: 'stovepipe_hat', outfit: 'sgt_tunic' },

  // Track 22: Jefferson Orchard
  { id: 'perf_jefferson_grace', sheetOnly: true, shell: '#dfab76', ridge: '#8a5829', accent: '#ffffff', glasses: null, hat: 'grace_headband', outfit: 'white_fringe_cape', hair: 'long_parted' },
  { id: 'perf_jefferson_marty', sheetOnly: true, shell: '#c4874e', ridge: '#6e3f16', accent: '#9b2226', glasses: null, hat: 'beaded_headband', outfit: 'paisley_psych', hair: 'mop_curls' },
  { id: 'perf_jefferson_jorma', sheetOnly: true, shell: '#b87b44', ridge: '#633a16', accent: '#3a5a40', glasses: '#ffd166', hat: null, outfit: 'suede_fringe', facial: 'sideburns' },
  { id: 'perf_jefferson_jack', sheetOnly: true, tall: true, shell: '#d29b64', ridge: '#7d4f22', accent: '#560bad', glasses: '#80ffdb', hat: null, outfit: 'varsity_gold', hair: 'blonde_fringe' },
  { id: 'perf_jefferson_drums', sheetOnly: true, shell: '#9e6231', ridge: '#47250a', accent: '#212529', glasses: null, hat: 'black_beret', outfit: 'mod_turtleneck' },

  // Track 23: The Grateful Nut
  { id: 'perf_grateful_jerry', sheetOnly: true, broad: true, shell: '#ab6f3a', ridge: '#542e0e', accent: '#3a0ca3', glasses: '#4cc9f0', hat: null, outfit: 'tie_dye', hair: 'afro_crown', facial: 'full_beard' },
  { id: 'perf_grateful_bob', sheetOnly: true, shell: '#d49e68', ridge: '#805226', accent: '#2b59c3', glasses: null, hat: null, outfit: 'denim_snap', hair: 'mop_curls' },
  { id: 'perf_grateful_phil', sheetOnly: true, tall: true, shell: '#dfb07c', ridge: '#8a5d2e', accent: '#8d5b34', glasses: '#ff70a6', hat: null, outfit: 'suede_fringe', hair: 'blonde_fringe' },
  { id: 'perf_grateful_pigpen', sheetOnly: true, shell: '#995d2d', ridge: '#452208', accent: '#3d2512', glasses: null, hat: 'rancher_hat', outfit: 'dark_buckskin', facial: 'walrus_stache' },
  { id: 'perf_grateful_drums', sheetOnly: true, shell: '#c2864e', ridge: '#6e3f16', accent: '#ff9f1c', glasses: null, hat: 'bandana_purple', outfit: 'paisley_psych' },
];

function walnutShapeR2(u, v, shape = 'classic', seamShift = 0) {
  const us = u - seamShift * 0.35;
  if (shape === 'hartley_cone') {
    if (v > 0.88) return 2.0;
    const widthScale = Math.max(0.38, 0.86 + 0.38 * v);
    const vEff = v > 0.52 ? 0.52 + (v - 0.52) * 1.45 : v * 0.98;
    return (u / widthScale) ** 2 + vEff ** 2;
  }
  if (shape === 'plump_round') {
    const widthScale = 1.14;
    const vEff = v * 1.05;
    return (u / widthScale) ** 2 + vEff ** 2;
  }
  if (shape === 'ribbed_barrel') {
    return Math.pow(Math.abs(u / 0.98), 2.9) + Math.pow(Math.abs(v / 1.02), 2.9);
  }
  if (shape === 'teardrop') {
    const widthScale = v < 0
      ? Math.max(0.30, 0.86 + 0.62 * v)
      : 0.86 + 0.24 * Math.sin(Math.min(1, v) * Math.PI * 0.85);
    return (u / widthScale) ** 2 + (v / 1.07) ** 2;
  }
  if (shape === 'sleek_black') {
    return (u / 0.95) ** 2 + (v / 0.95) ** 2;
  }
  if (shape === 'lion_lattice') {
    const lobe = 1.05 + 0.06 * Math.cos(v * 4.6);
    return (u / lobe) ** 2 + (v / 1.01) ** 2;
  }
  if (shape === 'crimson_oval') {
    const widthScale = v < -0.25 ? Math.max(0.44, 0.96 + 0.44 * (v + 0.25)) : 0.96;
    return (u / widthScale) ** 2 + (v / 1.04) ** 2;
  }
  if (shape === 'smooth_porcelain') {
    return (u / 0.98) ** 2 + (v / 0.98) ** 2;
  }
  if (shape === 'heart') {
    // True 3D heart silhouette: twin rounded upper lobes, deep top cleft notch, pointed bottom tip
    let vShifted = v;
    if (v < 0.12) {
      const wTop = Math.min(1.0, Math.max(0.0, (0.12 - v) / 0.45));
      const centerDip = 0.36 * Math.exp(-Math.pow(us / 0.24, 2));
      const lobeLift = 0.15 * Math.exp(-Math.pow((Math.abs(us) - 0.52) / 0.30, 2));
      vShifted = v - (centerDip - lobeLift) * wTop;
    }
    const t = Math.max(0, (v + 0.10) / 1.12);
    const widthScale = v > -0.10
      ? 1.16 * Math.pow(Math.max(0.06, 1.0 - t * 0.94), 0.78)
      : 1.16;
    return (u / widthScale) ** 2 + (vShifted / 1.02) ** 2;
  }
  if (shape === 'butternut_spindle') {
    const widthScale = Math.max(0.26, 0.78 * Math.cos(Math.min(1.22, Math.abs(v) * 1.04)));
    return (u / widthScale) ** 2 + (v / 1.10) ** 2;
  }
  // Classic walnut with subtle crown pinch at apex
  const widthScale = v < -0.52 ? Math.max(0.62, 1.0 - (-v - 0.52) * 0.28) : 1.0;
  return (u / widthScale) ** 2 + v ** 2;
}

function walnutBumpMod(shellCol, ridgeCol, spec, seamShift = 0) {
  const sculpted = Boolean(spec?.sculpted);
  const bumpStyle = spec?.bumpStyle ?? (sculpted ? 'lion_lattice' : 'classic');
  const goldCol = hex('#ffd166');
  const rubyVeinCol = hex('#ff4d6d');
  const mossFleckCol = hex('#6a994e');

  return (nx, ny) => {
    const sx = nx - seamShift;

    // Wen-Wan signature golden equator meridian ring
    if (spec?.goldEquator && Math.abs(ny - 0.04) < 0.085) {
      return { dnx: 0, dny: (ny - 0.04) * 3.0, color: goldCol };
    }

    // Central vertical walnut suture seam (styled per cultivar)
    const seamHalfW = bumpStyle === 'porcelain' || bumpStyle === 'smooth_heart' ? 0.065 : 0.095;
    if (Math.abs(sx) < seamHalfW && Math.abs(ny) < 0.90) {
      const seamColor = spec?.rubySeam ? mixCol(ridgeCol, rubyVeinCol, 0.55) : ridgeCol;
      return { dnx: sx * -2.2, dny: 0.15, color: seamColor };
    }

    if (bumpStyle === 'shoulder_band') {
      // Hartley bold horizontal shoulder ridge + flat-base chevrons
      if (Math.abs(ny - 0.26) < 0.095) {
        return { dnx: 0.08, dny: -0.32, color: mixCol(shellCol, ridgeCol, 0.72) };
      }
      const wave = Math.sin(Math.abs(sx) * 9.0 + ny * 4.0);
      if (wave > 0.62) {
        return { dnx: Math.sign(sx) * 0.22, dny: 0.16, color: mixCol(shellCol, ridgeCol, 0.5) };
      }
      return { dnx: wave * 0.12, dny: wave * 0.10, color: shellCol };
    }

    if (bumpStyle === 'freckled') {
      // Howard plump globe with toasted cinnamon freckles
      const dot = Math.sin(sx * 17.5 + 0.8) * Math.sin(ny * 16.5 - 0.4);
      if (dot > 0.58) {
        return { dnx: -0.15, dny: -0.15, color: mixCol(shellCol, ridgeCol, 0.78) };
      }
      return { dnx: dot * 0.08, dny: dot * 0.08, color: shellCol };
    }

    if (bumpStyle === 'vertical_ribs') {
      // Tulare deep vertical bass-string ribs
      const rib = Math.cos(sx * 18.5);
      if (rib > 0.52) {
        return { dnx: Math.sin(sx * 18.5) * 0.36, dny: 0.06, color: mixCol(shellCol, ridgeCol, 0.75) };
      }
      return { dnx: Math.sin(sx * 18.5) * 0.18, dny: 0.04, color: shellCol };
    }

    if (bumpStyle === 'delicate') {
      // Franquette fine French filigree ridges
      const fil = Math.sin(Math.abs(sx) * 14.0 - ny * 7.0) * Math.cos(ny * 8.0);
      if (fil > 0.68) {
        return { dnx: Math.sign(sx) * 0.16, dny: 0.12, color: mixCol(shellCol, ridgeCol, 0.42) };
      }
      return { dnx: fil * 0.08, dny: fil * 0.06, color: shellCol };
    }

    if (bumpStyle === 'smooth_stone') {
      // Juglans hindsii sleek dark walnut with subtle longitudinal stone grooves
      const groove = Math.cos(sx * 14.0 + ny * 2.5);
      if (groove > 0.76) {
        return { dnx: Math.sign(sx) * 0.24, dny: 0.10, color: ridgeCol };
      }
      return { dnx: groove * 0.08, dny: 0.04, color: shellCol };
    }

    if (bumpStyle === 'lion_lattice') {
      // Wen-Wan carved diamond cross-hatch convolutions
      const d1 = Math.sin((Math.abs(sx) + ny) * 13.0);
      const d2 = Math.sin((Math.abs(sx) - ny) * 13.0);
      if (d1 * d2 > 0.32) {
        return { dnx: Math.sign(sx) * 0.32, dny: 0.24, color: mixCol(shellCol, ridgeCol, 0.78) };
      }
      return { dnx: d1 * 0.16, dny: d2 * 0.16, color: shellCol };
    }

    if (bumpStyle === 'ruby_veins') {
      // Red Livermore branching crimson veins
      const vein = Math.sin(Math.abs(sx) * 12.0 - ny * 6.5) * Math.cos(ny * 7.5 + Math.abs(sx) * 3.5);
      if (vein > 0.46) {
        return { dnx: Math.sign(sx) * 0.24, dny: 0.18, color: mixCol(ridgeCol, rubyVeinCol, 0.38) };
      }
      return { dnx: vein * 0.14, dny: vein * 0.10, color: shellCol };
    }

    if (bumpStyle === 'porcelain') {
      // Serr ultra-smooth ivory shell
      const soft = Math.sin(sx * 6.0) * Math.cos(ny * 6.0);
      return { dnx: soft * 0.04, dny: soft * 0.04, color: shellCol };
    }

    if (bumpStyle === 'smooth_heart') {
      // Japonica Heartnut warm polished heart lobes
      const lobeShade = ny < 0 && Math.abs(sx) < 0.25 ? -0.22 * Math.sign(sx || 1) : 0;
      const pulse = Math.sin(Math.abs(sx) * 8.0 + ny * 5.0);
      if (pulse > 0.72) {
        return { dnx: lobeShade + Math.sign(sx) * 0.14, dny: 0.10, color: mixCol(shellCol, ridgeCol, 0.38) };
      }
      return { dnx: lobeShade, dny: pulse * 0.06, color: shellCol };
    }

    if (bumpStyle === 'jagged_bark') {
      // Cinerea Butternut rugged craggy olive-bark ridges + moss flecks
      const crag = Math.sin(sx * 21.0 + Math.sin(ny * 11.0) * 1.8) * Math.cos(ny * 9.5);
      if (crag > 0.68 && (Math.abs(sx * 10 + ny * 7) % 1 > 0.65)) {
        return { dnx: 0.22, dny: -0.18, color: mixCol(shellCol, mossFleckCol, 0.62) };
      }
      if (Math.abs(crag) > 0.44) {
        return { dnx: Math.sign(crag) * 0.32, dny: 0.20, color: mixCol(shellCol, ridgeCol, 0.80) };
      }
      return { dnx: crag * 0.18, dny: 0.12, color: shellCol };
    }

    // Classic convoluted walnut shell ridges (gyri)
    const wave = Math.sin(Math.abs(sx) * 10.5 + ny * 5.2) * Math.cos(ny * 6.5 - Math.abs(sx) * 4.0);
    const threshold = sculpted ? 0.36 : 0.56;
    if (wave > threshold) {
      return { dnx: Math.sign(sx) * 0.24, dny: 0.18, color: mixCol(shellCol, ridgeCol, sculpted ? 0.72 : 0.52) };
    }
    return { dnx: wave * 0.16, dny: wave * 0.12, color: shellCol };
  };
}

function drawSculptedWalnutShell(canvas, cx, cy, rx, ry, shellCol, ridgeCol, darkCol, spec, seamShift = 0) {
  const shape = spec?.shellShape ?? 'classic';
  const bumpFn = walnutBumpMod(shellCol, ridgeCol, spec, seamShift);
  const specStrength = spec?.bumpStyle === 'porcelain'
    ? 0.50
    : spec?.sculpted || spec?.coolRim
      ? 0.44
      : 0.31;
  const specPower = spec?.bumpStyle === 'porcelain' ? 26.0 : spec?.sculpted ? 24.0 : 17.0;
  const rimStrength = spec?.coolRim ? 0.42 : 0.26;
  const rimCol = spec?.coolRim
    ? [195, 175, 255]
    : spec?.rubySeam
      ? [255, 190, 205]
      : [235, 215, 185];

  const padX = rx * 1.24 + 2;
  const padY = ry * 1.24 + 2;
  const outRx = rx + 1.05;
  const outRy = ry + 1.05;

  // Pass 1: Crisp 1px dark silhouette outline matching exact sculpted shell contour
  for (let y = Math.floor(cy - padY); y <= Math.ceil(cy + padY); y++) {
    for (let x = Math.floor(cx - padX); x <= Math.ceil(cx + padX); x++) {
      const uOut = (x - cx) / outRx;
      const vOut = (y - cy) / outRy;
      if (walnutShapeR2(uOut, vOut, shape, seamShift) <= 1.0) {
        canvas.setPixel(x, y, darkCol);
      }
    }
  }

  // Pass 2: Per-pixel 3D Blinn-Phong + Rim + Bump-mapped sculpted walnut interior
  const lx = -0.42, ly = -0.52, lz = 0.74;
  const hx = -0.24, hy = -0.30, hz = 0.92;

  for (let y = Math.floor(cy - padY); y <= Math.ceil(cy + padY); y++) {
    for (let x = Math.floor(cx - padX); x <= Math.ceil(cx + padX); x++) {
      const u = (x - cx) / rx;
      const v = (y - cy) / ry;
      const r2 = walnutShapeR2(u, v, shape, seamShift);
      if (r2 > 1.0) continue;

      let nx = Math.max(-0.98, Math.min(0.98, u));
      let ny = Math.max(-0.98, Math.min(0.98, v));
      let nz = Math.sqrt(Math.max(0.03, 1.0 - Math.min(0.97, r2)));

      let colorBase = shellCol;
      const mod = bumpFn(nx, ny, nz, x - cx, y - cy);
      if (mod) {
        nx += mod.dnx ?? 0;
        ny += mod.dny ?? 0;
        if (mod.color) colorBase = mod.color;
        const len = Math.hypot(nx, ny, nz) || 1;
        nx /= len;
        ny /= len;
        nz /= len;
      }

      const ndotl = Math.max(0, nx * lx + ny * ly + nz * lz);
      const hemi = 0.5 - 0.5 * ny;
      const diffuse = 0.42 + 0.68 * ndotl + 0.08 * hemi;
      const specVal = Math.pow(Math.max(0, nx * hx + ny * hy + nz * hz), specPower) * specStrength;
      const rim = Math.pow(1.0 - nz, 2.3) * rimStrength * (nx > 0 || ny < 0 ? 1.0 : 0.48);
      const ao = v > 0.55 ? Math.max(0.68, 1.0 - (v - 0.55) * 0.42) : 1.0;

      const r = colorBase[0] * diffuse * ao + 255 * specVal + rimCol[0] * rim;
      const g = colorBase[1] * diffuse * ao + 244 * specVal + rimCol[1] * rim;
      const b = colorBase[2] * diffuse * ao + 224 * specVal + rimCol[2] * rim;
      canvas.setPixel(x, y, [r, g, b, 255]);
    }
  }

  // Optional Chandler twin orchard sprout leaves at shell apex!
  if (spec?.sproutLeaf) {
    const scale = rx / 9.2;
    const stemTopY = cy - ry - 2.2 * scale;
    const stemW = Math.max(1, Math.round(scale));
    canvas.fillRect(Math.round(cx - stemW * 0.5), Math.round(stemTopY), stemW, Math.max(2, Math.round(2.8 * scale)), hex('#5c3a21'));
    canvas.fillLitEllipsoid(cx - 2.6 * scale, stemTopY + 0.3 * scale, 2.5 * scale, 1.4 * scale, hex('#52b788'), {
      specStrength: 0.4,
      outline: darkCol,
    });
    canvas.fillLitEllipsoid(cx + 2.6 * scale, stemTopY + 0.1 * scale, 2.6 * scale, 1.5 * scale, hex('#74c69d'), {
      specStrength: 0.45,
      outline: darkCol,
    });
  }
}

function drawWalnutFrame(canvas, ox, oy, spec, dir, frame) {
  const shell = hex(spec.shell);
  const ridge = hex(spec.ridge);
  const accent = hex(spec.accent);
  const dark = hex('#1c110a');

  const bob = frame === 1 || frame === 2 ? -1 : 0;
  const stepL = frame === 1 ? -2 : frame === 2 ? 1 : 0;
  const stepR = frame === 2 ? -2 : frame === 1 ? 1 : 0;
  const faceShift = dir === 1 ? -2 : dir === 2 ? 2 : 0;
  const seamShift = dir === 1 ? -0.22 : dir === 2 ? 0.22 : 0.0;

  // Soft 2-ring contact ground shadow
  canvas.fillEllipse(ox + 16, oy + 28.5, 8.2, 3.0, hex('#000000', 55));
  canvas.fillEllipse(ox + 16, oy + 28.2, 5.8, 2.0, hex('#000000', 85));

  // 3D Rounded Boots / Sneakers with toe highlight
  const shoeCol = spec.id === 'npc_don_shello'
    ? hex('#e63946')
    : spec.whiteBoots
      ? hex('#f1faee')
      : hex('#3b2416');
  canvas.fillLitEllipsoid(ox + 12.5, oy + 26.5 + stepL, 2.4, 2.0, shoeCol, {
    specStrength: 0.35,
    outline: dark,
  });
  canvas.fillLitEllipsoid(ox + 19.5, oy + 26.5 + stepR, 2.4, 2.0, shoeCol, {
    specStrength: 0.35,
    outline: dark,
  });
  if (spec.id === 'npc_don_shello') {
    // Crisp white soles on Air McGregors
    canvas.fillRect(ox + 11, oy + 28 + stepL, 4, 1, hex('#ffffff'));
    canvas.fillRect(ox + 18, oy + 28 + stepR, 4, 1, hex('#ffffff'));
  }

  // 3D Cylindrical Festival Tunic / Bespoke Performer Stage Attire
  canvas.fillRect(ox + 9, oy + 18 + bob, 14, 8, dark);
  canvas.fillLitCylinder(ox + 10, oy + 19 + bob, 12, 6, accent, { specStrength: 0.22 });
  // Vest lapel / center seam & gold peace button
  canvas.fillRect(ox + 15 + Math.round(faceShift * 0.5), oy + 19 + bob, 2, 6, shade(accent, 0.72));
  canvas.setPixel(ox + 14 + Math.round(faceShift * 0.5), oy + 21 + bob, hex('#ffd166'));

  // Bespoke 1969 Woodstock Performer Stage Outfits
  if (spec.outfit === 'fringed_buckskin') {
    // Jimi's iconic white Woodstock jacket with turquoise bead yoke & swaying fringe
    canvas.fillRect(ox + 10, oy + 19 + bob, 12, 2, hex('#48cae4'));
    for (let fx = 10; fx <= 21; fx += 2) {
      canvas.setPixel(ox + fx, oy + 25 + bob, hex('#e0d6c3'));
      canvas.setPixel(ox + fx, oy + 21 + bob, hex('#0096c7'));
    }
  } else if (spec.outfit === 'tie_dye') {
    // Psychedelic rainbow spiral tie-dye
    const tdCols = [hex('#ff595e'), hex('#ffca3a'), hex('#8ac926'), hex('#1982c4'), hex('#6a4c93')];
    for (let dy = 0; dy < 6; dy++) {
      for (let dx = 0; dx < 12; dx++) {
        const ang = Math.atan2(dy - 2.5, dx - 5.5) + Math.hypot(dx - 5.5, dy - 2.5) * 0.7;
        const ci = ((Math.floor(ang * 1.8) % 5) + 5) % 5;
        if ((dx + dy) % 2 === 0) canvas.setPixel(ox + 10 + dx, oy + 19 + bob + dy, tdCols[ci]);
      }
    }
  } else if (spec.outfit === 'flannel_plaid') {
    // John Shell-gerty's red & black lumberjack buffalo plaid
    for (let dy = 0; dy < 6; dy++) {
      for (let dx = 0; dx < 12; dx++) {
        if (dx % 3 === 0 || dy % 2 === 0) {
          canvas.setPixel(ox + 10 + dx, oy + 19 + bob + dy, (dx % 3 === 0 && dy % 2 === 0) ? hex('#141418') : hex('#9b111e'));
        }
      }
    }
  } else if (spec.outfit === 'denim_snap') {
    canvas.fillRect(ox + 11, oy + 20 + bob, 3, 1, hex('#ffd166'));
    canvas.fillRect(ox + 18, oy + 20 + bob, 3, 1, hex('#ffd166'));
    canvas.setPixel(ox + 15, oy + 22 + bob, hex('#f8f9fa'));
    canvas.setPixel(ox + 15, oy + 24 + bob, hex('#f8f9fa'));
  } else if (spec.outfit === 'hussar_jacket') {
    // Mitch Mitchell British scarlet hussar horizontal gold frogging braids
    for (const by of [20, 22, 24]) {
      canvas.fillRect(ox + 11, oy + by + bob, 10, 1, hex('#ffd166'));
    }
  } else if (spec.outfit === 'sgt_tunic') {
    // Ringo / Kozmic satin parade tunic with gold shoulder epaulets
    canvas.fillRect(ox + 9, oy + 18 + bob, 3, 2, hex('#ffd166'));
    canvas.fillRect(ox + 20, oy + 18 + bob, 3, 2, hex('#ffd166'));
    canvas.fillRect(ox + 13, oy + 20 + bob, 6, 1, hex('#ffd166'));
    canvas.fillRect(ox + 13, oy + 23 + bob, 6, 1, hex('#ffd166'));
  } else if (spec.outfit === 'guayabera_white') {
    canvas.fillRect(ox + 12, oy + 19 + bob, 1, 6, hex('#e9c46a'));
    canvas.fillRect(ox + 19, oy + 19 + bob, 1, 6, hex('#e9c46a'));
  } else if (spec.outfit === 'latin_vest') {
    // Open black Santana vest revealing warm walnut chest + gold medallion
    canvas.fillRect(ox + 14, oy + 19 + bob, 4, 6, shell);
    canvas.setPixel(ox + 15, oy + 21 + bob, hex('#ffd166'));
    canvas.setPixel(ox + 16, oy + 21 + bob, hex('#ffd166'));
  } else if (spec.outfit === 'velvet_boa') {
    // Layered bohemian pearls & feather boa collar
    canvas.fillLitEllipsoid(ox + 16, oy + 19.5 + bob, 7.2, 2.0, hex('#ff70a6'), { outline: dark });
    for (const px of [13, 15, 17, 19]) canvas.setPixel(ox + px, oy + 21 + bob, hex('#fff8e7'));
  } else if (spec.outfit === 'paisley_psych') {
    for (const [px, py, pc] of [[11, 20, '#ff9f1c'], [14, 23, '#80ffdb'], [18, 21, '#ff9f1c'], [20, 23, '#ff70a6']]) {
      canvas.setPixel(ox + px, oy + py + bob, hex(pc));
    }
  } else if (spec.outfit === 'floral_caftan') {
    canvas.fillRect(ox + 9, oy + 20 + bob, 14, 6, accent);
    for (const [px, py, pc] of [[11, 21, '#ffd166'], [15, 23, '#ffffff'], [19, 21, '#80ffdb'], [13, 24, '#ffbe0b']]) {
      canvas.setPixel(ox + px, oy + py + bob, hex(pc));
    }
  } else if (spec.outfit === 'sunshine_poncho') {
    canvas.fillLitEllipsoid(ox + 16, oy + 21 + bob, 7.4, 3.2, hex('#ffbe0b'), { outline: dark });
    for (let fx = 10; fx <= 21; fx += 2) canvas.setPixel(ox + fx, oy + 24 + bob, hex('#ffffff'));
  } else if (spec.outfit === 'dashiki_gold') {
    // Gold geometric V-collar dashiki embroidery
    canvas.setPixel(ox + 13, oy + 19 + bob, hex('#ffd166'));
    canvas.setPixel(ox + 18, oy + 19 + bob, hex('#ffd166'));
    canvas.setPixel(ox + 14, oy + 20 + bob, hex('#ffd166'));
    canvas.setPixel(ox + 17, oy + 20 + bob, hex('#ffd166'));
    canvas.fillRect(ox + 15, oy + 21 + bob, 2, 2, hex('#ffd166'));
  } else if (spec.outfit === 'varsity_gold') {
    canvas.fillRect(ox + 10, oy + 19 + bob, 2, 6, hex('#ffd166'));
    canvas.fillRect(ox + 20, oy + 19 + bob, 2, 6, hex('#ffd166'));
    canvas.fillRect(ox + 14, oy + 20 + bob, 4, 2, hex('#ffd166')); // Gold chain
  } else if (spec.outfit === 'tracksuit_neon') {
    canvas.fillRect(ox + 10, oy + 21 + bob, 12, 2, hex('#f72585'));
    canvas.fillRect(ox + 11, oy + 23 + bob, 10, 1, hex('#fee440'));
  } else if (spec.outfit === 'nebula_robe') {
    canvas.fillLitEllipsoid(ox + 16, oy + 19.5 + bob, 7.4, 2.0, hex('#ffd166'), { specStrength: 0.5, outline: dark });
    canvas.setPixel(ox + 13, oy + 22 + bob, hex('#80ffdb'));
    canvas.setPixel(ox + 18, oy + 23 + bob, hex('#c77dff'));
  } else if (spec.outfit === 'suede_fringe') {
    for (let fx = 10; fx <= 21; fx += 2) canvas.setPixel(ox + fx, oy + 24 + bob, hex('#e6ccb2'));
  } else if (spec.outfit === 'peasant_embroidery') {
    canvas.fillRect(ox + 12, oy + 19 + bob, 8, 1, hex('#ffffff'));
    canvas.setPixel(ox + 14, oy + 21 + bob, hex('#ffafcc'));
    canvas.setPixel(ox + 17, oy + 21 + bob, hex('#ffd166'));
  } else if (spec.outfit === 'mod_turtleneck') {
    canvas.fillRect(ox + 13, oy + 18 + bob, 6, 2, hex('#111118'));
    canvas.setPixel(ox + 16, oy + 21 + bob, hex('#e0fbfc'));
  } else if (spec.outfit === 'bard_cloak') {
    canvas.fillLitEllipsoid(ox + 16, oy + 19.5 + bob, 7.0, 2.0, hex('#52b788'), { outline: dark });
  } else if (spec.outfit === 'cocker_star_shirt') {
    // Joe Cocker Woodstock red/white/blue starburst tie-dye tee
    canvas.fillRect(ox + 10, oy + 19 + bob, 12, 6, hex('#f8f9fa'));
    for (const dx of [11, 13, 18, 20]) canvas.setPixel(ox + dx, oy + 20 + bob, hex('#e63946'));
    for (const dx of [12, 19]) canvas.setPixel(ox + dx, oy + 23 + bob, hex('#1d3557'));
    canvas.fillRect(ox + 15, oy + 20 + bob, 2, 3, hex('#e63946'));
    canvas.setPixel(ox + 14, oy + 21 + bob, hex('#1d3557'));
    canvas.setPixel(ox + 17, oy + 21 + bob, hex('#1d3557'));
  } else if (spec.outfit === 'blues_pinstripe') {
    // Midnight Chicago-Woodstock blues waistcoat with silver pinstripes
    for (let sx = 11; sx <= 20; sx += 2) {
      canvas.fillRect(ox + sx, oy + 19 + bob, 1, 6, hex('#a8dadc'));
    }
    canvas.fillRect(ox + 15, oy + 19 + bob, 2, 4, hex('#f8f9fa'));
  } else if (spec.outfit === 'boho_ivory_lace') {
    // Melanie flowing ivory folk gown with warm candlelit lace trim
    canvas.fillRect(ox + 9, oy + 20 + bob, 14, 6, hex('#f8edeb'));
    for (let lx = 10; lx <= 21; lx += 2) {
      canvas.setPixel(ox + lx, oy + 20 + bob, hex('#ffd166'));
      canvas.setPixel(ox + lx, oy + 25 + bob, hex('#e8d1b5'));
    }
  } else if (spec.outfit === 'bear_suspenders') {
    // Canned Walnut red heavy-duty boogie suspenders over cream henley
    canvas.fillRect(ox + 12, oy + 19 + bob, 2, 6, hex('#d62828'));
    canvas.fillRect(ox + 18, oy + 19 + bob, 2, 6, hex('#d62828'));
    canvas.setPixel(ox + 12, oy + 23 + bob, hex('#ffd166'));
    canvas.setPixel(ox + 19, oy + 23 + bob, hex('#ffd166'));
  } else if (spec.outfit === 'fur_buckskin') {
    // Mountain Grove frontier buckskin vest with cream shearling fur collar
    canvas.fillLitEllipsoid(ox + 16, oy + 19.2 + bob, 7.2, 1.9, hex('#fdf0d5'), { outline: dark });
    for (let fx = 10; fx <= 21; fx += 2) canvas.setPixel(ox + fx, oy + 25 + bob, hex('#d4a373'));
  } else if (spec.outfit === 'jersey_72') {
    // Stephen Stills classic burgundy & gold football jersey
    canvas.fillRect(ox + 10, oy + 19 + bob, 12, 1, hex('#ffd166'));
    canvas.fillRect(ox + 13, oy + 21 + bob, 2, 3, hex('#ffd166'));
    canvas.fillRect(ox + 17, oy + 21 + bob, 2, 3, hex('#ffd166'));
  } else if (spec.outfit === 'mod_collar') {
    // Crisp British open V-collar shirt
    canvas.setPixel(ox + 14, oy + 19 + bob, hex('#ffffff'));
    canvas.setPixel(ox + 17, oy + 19 + bob, hex('#ffffff'));
    canvas.fillRect(ox + 15, oy + 20 + bob, 2, 2, shell);
  } else if (spec.outfit === 'dark_buckskin') {
    // Charcoal-espresso fringed buckskin jacket
    for (let fx = 10; fx <= 21; fx += 2) {
      canvas.setPixel(ox + fx, oy + 25 + bob, hex('#b08968'));
      canvas.setPixel(ox + fx, oy + 20 + bob, hex('#ddb892'));
    }
  } else if (spec.outfit === 'white_fringe_cape') {
    // Billowing white Woodstock fringe cape / gown (The Hull & Jefferson Orchard)
    canvas.fillRect(ox + 8, oy + 19 + bob, 2, 5, hex('#f8f9fa'));
    canvas.fillRect(ox + 22, oy + 19 + bob, 2, 5, hex('#f8f9fa'));
    for (let fx = 9; fx <= 22; fx += 2) {
      canvas.setPixel(ox + fx, oy + 25 + bob, hex('#e9ecef'));
    }
  } else if (spec.outfit === 'boiler_mod_suit') {
    // Pete Townshend white Woodstock boiler jumpsuit + Union-Jack mod badge
    canvas.fillRect(ox + 15, oy + 19 + bob, 1, 6, hex('#adb5bd'));
    canvas.fillRect(ox + 18, oy + 20 + bob, 3, 2, hex('#1d3557'));
    canvas.setPixel(ox + 19, oy + 20 + bob, hex('#e63946'));
  } else if (spec.outfit === 'skeleton_suit') {
    // John Entwistle black skeleton-rib stage suit
    canvas.fillRect(ox + 15, oy + 19 + bob, 2, 6, hex('#f8f9fa'));
    for (const ry of [20, 22, 24]) {
      canvas.fillRect(ox + 12, oy + ry + bob, 8, 1, hex('#f8f9fa'));
    }
  } else if (spec.outfit === 'mod_target_tee') {
    // Keith Moon British Mod concentric red/white/blue target bullseye tee
    canvas.fillEllipse(ox + 16, oy + 22 + bob, 3.2, 2.6, hex('#ffffff'));
    canvas.fillEllipse(ox + 16, oy + 22 + bob, 2.1, 1.8, hex('#1d3557'));
    canvas.setPixel(ox + 16, oy + 22 + bob, hex('#e63946'));
  } else if (spec.outfit === 'army_surplus') {
    // Country Joe olive-drab field jacket with gold peace badge & pockets
    canvas.fillRect(ox + 11, oy + 20 + bob, 3, 2, hex('#344e41'));
    canvas.fillRect(ox + 18, oy + 20 + bob, 3, 2, hex('#344e41'));
    canvas.setPixel(ox + 12, oy + 20 + bob, hex('#ffd166'));
  } else if (spec.outfit === 'circus_stripes') {
    // Psychedelic carnival vertical stripes
    for (let sx = 10; sx <= 21; sx++) {
      const sCol = sx % 2 === 0 ? hex('#e63946') : hex('#ffd166');
      canvas.fillRect(ox + sx, oy + 19 + bob, 1, 6, sCol);
    }
  }

  // Shawls / Scarves worn over shoulders
  if (spec.hat === 'scarf_seafoam') {
    canvas.fillLitEllipsoid(ox + 16, oy + 19.5 + bob, 7.2, 2.2, hex('#52b788'), { outline: dark });
    canvas.fillLitCylinder(ox + 18, oy + 20 + bob, 3, 5, hex('#74c69d'));
  } else if (spec.hat === 'shawl_sunset') {
    canvas.fillLitEllipsoid(ox + 16, oy + 20 + bob, 7.6, 2.6, hex('#f77f00'), { outline: dark });
    canvas.fillRect(ox + 10, oy + 21 + bob, 12, 1, hex('#48cae4'));
  }

  // Back-layer hair halos (afro crown / flowing locks behind walnut shell)
  if (spec.hair === 'afro_crown') {
    canvas.fillLitEllipsoid(ox + 16, oy + 10.5 + bob, 11.2, 9.5, hex('#1e1410'), { specStrength: 0.15, outline: dark });
  } else if (spec.hair === 'long_parted') {
    canvas.fillLitCylinder(ox + 6, oy + 10 + bob, 3, 10, hex('#3b2214'), { specStrength: 0.2 });
    canvas.fillLitCylinder(ox + 23, oy + 10 + bob, 3, 10, hex('#3b2214'), { specStrength: 0.2 });
  }

  // 3D Normal-Lit Anthropomorphic Walnut Head/Shell (with variety-specific silhouette & crown!)
  const rx = spec.broad ? 10.2 : 9.2;
  const ry = spec.tall ? 10.2 : 9.2;
  drawSculptedWalnutShell(canvas, ox + 16, oy + 12.5 + bob, rx, ry, shell, ridge, dark, spec, seamShift);

  // Front hair fringes / mop curls
  if (spec.hair === 'mop_curls') {
    canvas.fillLitEllipsoid(ox + 16, oy + 5.6 + bob, 8.6, 3.0, hex('#3b2314'), { specStrength: 0.22, outline: dark });
    if (dir !== 3) {
      canvas.fillRect(ox + 8, oy + 7 + bob, 2, 4, hex('#3b2314'));
      canvas.fillRect(ox + 22, oy + 7 + bob, 2, 4, hex('#3b2314'));
    }
  } else if (spec.hair === 'blonde_fringe') {
    canvas.fillLitEllipsoid(ox + 16, oy + 5.5 + bob, 8.4, 2.8, hex('#f3c65f'), { specStrength: 0.35, outline: dark });
    canvas.fillRect(ox + 7, oy + 8 + bob, 2, 8, hex('#e9b44c'));
    canvas.fillRect(ox + 23, oy + 8 + bob, 2, 8, hex('#e9b44c'));
  }

  // Little 3D walnut arms on sides
  const armSwing = frame === 1 ? 1 : frame === 2 ? -1 : 0;
  canvas.fillLitEllipsoid(ox + 8.5, oy + 20.5 + bob + armSwing, 2.0, 2.4, shell, { outline: dark });
  canvas.fillLitEllipsoid(ox + 23.5, oy + 20.5 + bob - armSwing, 2.0, 2.4, shell, { outline: dark });

  // Bedroll on back for Barnaby Bittershell
  if (spec.hat === 'bedroll') {
    canvas.fillLitCylinder(ox + 8, oy + 4 + bob, 16, 4, hex('#e63946'), { specStrength: 0.25 });
    canvas.fillRect(ox + 11, oy + 4 + bob, 1, 4, hex('#ffd166'));
    canvas.fillRect(ox + 20, oy + 4 + bob, 1, 4, hex('#ffd166'));
  }

  // Expressive Face & Iconic Facial Hair (unless facing up: dir === 3)
  if (dir !== 3) {
    const eyeLX = ox + 13 + faceShift;
    const eyeRX = ox + 18 + faceShift;
    const eyeY = oy + 12 + bob;

    if (spec.facial === 'sideburns') {
      canvas.fillRect(ox + 9 + Math.max(-1, faceShift), oy + 11 + bob, 2, 5, hex('#3b2314'));
      canvas.fillRect(ox + 21 + Math.min(1, faceShift), oy + 11 + bob, 2, 5, hex('#3b2314'));
    }

    if (spec.glasses) {
      const gCol = hex(spec.glasses);
      canvas.fillRect(eyeLX - 1, eyeY - 1, 4, 3, dark);
      canvas.fillRect(eyeRX - 1, eyeY - 1, 4, 3, dark);
      canvas.fillRect(eyeLX, eyeY - 1, 3, 2, gCol);
      canvas.fillRect(eyeRX, eyeY - 1, 3, 2, gCol);
      canvas.setPixel(eyeLX, eyeY - 1, hex('#ffffff', 210));
      canvas.setPixel(eyeRX, eyeY - 1, hex('#ffffff', 210));
      canvas.fillRect(eyeLX + 3, eyeY, 2, 1, gCol);
    } else {
      canvas.fillRect(eyeLX, eyeY, 2, 3, dark);
      canvas.fillRect(eyeRX, eyeY, 2, 3, dark);
      canvas.setPixel(eyeLX, eyeY, hex('#ffffff'));
      canvas.setPixel(eyeRX, eyeY, hex('#ffffff'));
      // Warm rosy cheeks
      canvas.setPixel(eyeLX - 1, eyeY + 3, hex('#ff758f', 110));
      canvas.setPixel(eyeRX + 2, eyeY + 3, hex('#ff758f', 110));
    }

    // Facial hair & smile variations
    if (spec.facial === 'santana_mustache') {
      canvas.fillRect(ox + 13 + faceShift, oy + 15 + bob, 6, 1, hex('#1a110b'));
      canvas.setPixel(ox + 13 + faceShift, oy + 16 + bob, hex('#1a110b'));
      canvas.setPixel(ox + 18 + faceShift, oy + 16 + bob, hex('#1a110b'));
      canvas.setPixel(ox + 16 + faceShift, oy + 17 + bob, hex('#1a110b'));
    } else if (spec.facial === 'ringo_stache') {
      canvas.fillRect(ox + 13 + faceShift, oy + 15 + bob, 6, 1, hex('#2e1a0f'));
      canvas.fillRect(ox + 13 + faceShift, oy + 16 + bob, 1, 2, hex('#2e1a0f'));
      canvas.fillRect(ox + 18 + faceShift, oy + 16 + bob, 1, 2, hex('#2e1a0f'));
    } else if (spec.facial === 'goatee') {
      canvas.fillRect(ox + 15 + faceShift, oy + 16 + bob, 3, 1, dark);
      canvas.fillRect(ox + 15 + faceShift, oy + 17 + bob, 2, 2, hex('#2b190e'));
    } else if (spec.facial === 'full_beard') {
      // Bushy 1969 Bear / Jerry Garcia beard framing smile
      canvas.fillLitEllipsoid(ox + 16 + faceShift, oy + 17.4 + bob, 5.2, 2.6, hex('#2e1a0f'), { specStrength: 0.15 });
      canvas.fillRect(ox + 15 + faceShift, oy + 16 + bob, 3, 1, hex('#ffd166'));
    } else if (spec.facial === 'walrus_stache') {
      // Drooping 1969 cavalry / Crosby / Country Joe walrus mustache
      canvas.fillRect(ox + 12 + faceShift, oy + 15 + bob, 8, 2, hex('#3b2314'));
      canvas.setPixel(ox + 12 + faceShift, oy + 17 + bob, hex('#3b2314'));
      canvas.setPixel(ox + 19 + faceShift, oy + 17 + bob, hex('#3b2314'));
    } else {
      canvas.fillRect(ox + 15 + faceShift, oy + 16 + bob, 3, 1, dark);
    }
  }

  // Complete 3D Hats & Performer Headpieces
  if (spec.hat === 'bandana_red' || spec.hat === 'bandana_purple' || spec.hat === 'navy_bandana') {
    const hCol = spec.hat === 'bandana_purple'
      ? hex('#9d4edd')
      : spec.hat === 'navy_bandana'
        ? hex('#1d3557')
        : hex('#e63946');
    canvas.fillLitCylinder(ox + 7, oy + 5 + bob, 18, 3, hCol, { specStrength: 0.28 });
    canvas.fillRect(ox + 6, oy + 7 + bob, 2, 3, shade(hCol, 0.85));
  } else if (spec.hat === 'pan_african_band') {
    canvas.fillRect(ox + 7, oy + 5 + bob, 18, 1, hex('#e63946'));
    canvas.fillRect(ox + 7, oy + 6 + bob, 18, 1, hex('#ffd166'));
    canvas.fillRect(ox + 7, oy + 7 + bob, 18, 1, hex('#2a9d8f'));
  } else if (spec.hat === 'beaded_headband') {
    canvas.fillRect(ox + 7, oy + 6 + bob, 18, 2, hex('#6f4518'));
    for (let bx = 8; bx <= 23; bx += 3) {
      canvas.setPixel(ox + bx, oy + 6 + bob, hex('#48cae4'));
      canvas.setPixel(ox + bx + 1, oy + 7 + bob, hex('#ffd166'));
    }
  } else if (spec.hat === 'feathers') {
    canvas.fillLitCylinder(ox + 8, oy + 5 + bob, 16, 2, hex('#b5179e'));
    canvas.fillLitEllipsoid(ox + 19, oy + 3 + bob, 1.6, 3.4, hex('#2ec4b6'), { specStrength: 0.4 });
    canvas.fillLitEllipsoid(ox + 21.5, oy + 4 + bob, 1.6, 3.0, hex('#ff9f1c'), { specStrength: 0.4 });
  } else if (spec.hat === 'felt_twig') {
    canvas.fillEllipse(ox + 16, oy + 6 + bob, 9.5, 2.2, hex('#1b4332'));
    canvas.fillLitEllipsoid(ox + 16, oy + 4.5 + bob, 6.5, 2.8, hex('#2d6a4f'), { specStrength: 0.25 });
    canvas.fillRect(ox + 19, oy + 1 + bob, 1, 4, hex('#74c69d'));
    canvas.fillLitEllipsoid(ox + 21, oy + 1.5 + bob, 2.0, 1.4, hex('#95d5b2'));
  } else if (spec.hat === 'rancher_hat') {
    canvas.fillEllipse(ox + 16, oy + 6 + bob, 10.8, 2.4, hex('#8c5a2b'));
    canvas.fillLitEllipsoid(ox + 16, oy + 4.0 + bob, 6.8, 2.8, hex('#b07d48'), { specStrength: 0.28, outline: dark });
    canvas.fillRect(ox + 10, oy + 5 + bob, 12, 1, hex('#3d2512'));
  } else if (spec.hat === 'straw_sunhat') {
    canvas.fillEllipse(ox + 16, oy + 6 + bob, 11.2, 2.5, hex('#e9c46a'));
    canvas.fillLitEllipsoid(ox + 16, oy + 4.0 + bob, 6.8, 2.8, hex('#f4d35e'), { specStrength: 0.3, outline: dark });
    canvas.fillRect(ox + 10, oy + 5 + bob, 12, 1, hex('#e76f51'));
  } else if (spec.hat === 'panama_fedora') {
    canvas.fillEllipse(ox + 16, oy + 6 + bob, 9.8, 2.2, hex('#f8f9fa'));
    canvas.fillLitEllipsoid(ox + 16, oy + 4.0 + bob, 6.4, 2.6, hex('#ffffff'), { specStrength: 0.35, outline: dark });
    canvas.fillRect(ox + 10, oy + 5 + bob, 12, 1, hex('#1b1b22'));
  } else if (spec.hat === 'derby_crimson') {
    canvas.fillEllipse(ox + 16, oy + 6 + bob, 8.8, 2.0, hex('#590d22'));
    canvas.fillLitEllipsoid(ox + 16, oy + 3.8 + bob, 6.2, 3.2, hex('#a4133c'), { specStrength: 0.38, outline: dark });
  } else if (spec.hat === 'stovepipe_hat') {
    canvas.fillEllipse(ox + 16, oy + 6 + bob, 8.8, 2.0, hex('#24192e'));
    canvas.fillLitCylinder(ox + 11, oy + 0 + bob, 10, 6, hex('#4a3b5c'), { specStrength: 0.3 });
    canvas.fillRect(ox + 11, oy + 4 + bob, 10, 1, hex('#ffd166'));
  } else if (spec.hat === 'velvet_beret' || spec.hat === 'black_beret') {
    const bCol = spec.hat === 'black_beret' ? hex('#212529') : hex('#7b2cbf');
    canvas.fillLitEllipsoid(ox + 15, oy + 4.2 + bob, 7.6, 2.6, bCol, { specStrength: 0.32, outline: dark });
  } else if (spec.hat === 'daisy_clip') {
    canvas.fillLitEllipsoid(ox + 21, oy + 6 + bob, 2.4, 2.4, hex('#ffffff'), { specStrength: 0.4 });
    canvas.setPixel(ox + 21, oy + 6 + bob, hex('#ffb703'));
  } else if (spec.hat === 'kangol_white') {
    canvas.fillLitEllipsoid(ox + 16, oy + 4.5 + bob, 7.4, 2.8, hex('#f8f9fa'), { specStrength: 0.4, outline: dark });
    // Glowing cyan DJ headphones over ears!
    canvas.fillLitEllipsoid(ox + 7.2, oy + 12 + bob, 1.8, 2.6, hex('#00f5d4'), { outline: dark });
    canvas.fillLitEllipsoid(ox + 24.8, oy + 12 + bob, 1.8, 2.6, hex('#00f5d4'), { outline: dark });
  } else if (spec.hat === 'solar_crown') {
    canvas.strokeEllipse(ox + 16, oy + 3.5 + bob, 7.5, 2.5, hex('#ffd166'));
    for (const rxOff of [10, 13, 16, 19, 22]) {
      canvas.fillRect(ox + rxOff, oy + 0 + bob, 1, 3, hex('#ffbe0b'));
    }
  } else if (spec.hat === 'crystal_antennae') {
    canvas.fillRect(ox + 12, oy + 1 + bob, 1, 4, hex('#72efdd'));
    canvas.fillRect(ox + 19, oy + 1 + bob, 1, 4, hex('#72efdd'));
    canvas.fillLitEllipsoid(ox + 12.5, oy + 1.2 + bob, 1.5, 1.5, hex('#80ffdb'), { specStrength: 0.7 });
    canvas.fillLitEllipsoid(ox + 19.5, oy + 1.2 + bob, 1.5, 1.5, hex('#c77dff'), { specStrength: 0.7 });
  } else if (spec.hat === 'star_crest') {
    canvas.fillLitEllipsoid(ox + 16, oy + 3 + bob, 3.2, 2.5, hex('#ffd166'), { specStrength: 0.65 });
    canvas.setPixel(ox + 16, oy + 1 + bob, hex('#ffffff'));
  } else if (spec.hat === 'halo') {
    canvas.strokeEllipse(ox + 16, oy + 2.5 + bob, 6.5, 2.0, hex('#ffd166'));
    canvas.setPixel(ox + 12, oy + 2 + bob, hex('#ffffff'));
  } else if (spec.hat === 'crown_cap') {
    const capCol = spec.id === 'npc_don_shello' ? hex('#f5cb5c') : hex('#4cc9f0');
    canvas.fillLitEllipsoid(ox + 16, oy + 4.8 + bob, 7.5, 3.0, capCol, { specStrength: 0.4, outline: dark });
    canvas.fillRect(ox + 10 + faceShift, oy + 6 + bob, 12, 2, shade(capCol, 0.78));
  } else if (spec.hat === 'flower_braid') {
    const blossoms = [
      [10, 6, '#ffafcc'], [13, 5, '#ffd166'], [16, 5, '#ffffff'], [19, 5, '#bdb2ff'], [22, 6, '#ffafcc'],
    ];
    for (const [bx, by, bcol] of blossoms) {
      canvas.fillLitEllipsoid(ox + bx, oy + by + bob, 1.6, 1.5, hex(bcol), { specStrength: 0.35 });
    }
  } else if (spec.hat === 'porkpie_navy') {
    canvas.fillEllipse(ox + 16, oy + 6 + bob, 9.2, 2.0, hex('#0d1b2a'));
    canvas.fillLitEllipsoid(ox + 16, oy + 4.2 + bob, 6.4, 2.4, hex('#1d3557'), { specStrength: 0.36, outline: dark });
    canvas.fillRect(ox + 10, oy + 5 + bob, 12, 1, hex('#00b4d8'));
  } else if (spec.hat === 'woven_garland') {
    canvas.fillRect(ox + 8, oy + 6 + bob, 16, 1, hex('#74c69d'));
    for (const [gx, gc] of [[9, '#fff3b0'], [13, '#ffccd5'], [16, '#ffd166'], [19, '#ffccd5'], [23, '#fff3b0']]) {
      canvas.setPixel(ox + gx, oy + 5 + bob, hex(gc));
      canvas.setPixel(ox + gx, oy + 6 + bob, hex('#ffffff'));
    }
  } else if (spec.hat === 'arlo_floppy_hat') {
    canvas.fillEllipse(ox + 16, oy + 6.4 + bob, 11.8, 2.6, hex('#b08968'));
    canvas.fillLitEllipsoid(ox + 16, oy + 3.6 + bob, 6.8, 3.2, hex('#ddb892'), { specStrength: 0.32, outline: dark });
    canvas.fillRect(ox + 10, oy + 5 + bob, 12, 1, hex('#457b9d'));
    canvas.setPixel(ox + 16, oy + 5 + bob, hex('#ffd166'));
  } else if (spec.hat === 'knit_beanie') {
    canvas.fillLitEllipsoid(ox + 16, oy + 4.4 + bob, 7.6, 3.0, hex('#9b2226'), { specStrength: 0.25, outline: dark });
    canvas.fillRect(ox + 9, oy + 6 + bob, 14, 2, hex('#ae2012'));
  } else if (spec.hat === 'kufi_emerald') {
    canvas.fillLitCylinder(ox + 10, oy + 3 + bob, 12, 4, hex('#2a9d8f'), { specStrength: 0.32 });
    for (let kx = 10; kx <= 21; kx += 2) canvas.setPixel(ox + kx, oy + 5 + bob, hex('#ffd166'));
  } else if (spec.hat === 'grace_headband') {
    canvas.fillRect(ox + 8, oy + 6 + bob, 16, 1, hex('#e0aaff'));
    canvas.fillLitEllipsoid(ox + 16, oy + 5.6 + bob, 1.8, 1.8, hex('#80ffdb'), { specStrength: 0.7 });
  }

  // 3D Shaded Guitar / Lute / Crystal-Bass Instrument
  if (spec.guitar && dir !== 3) {
    const gCol = hex(spec.guitar);
    // Guitar body with dark outline + specular highlight
    canvas.fillLitEllipsoid(ox + 14.5, oy + 20 + bob, 4.4, 3.0, gCol, {
      specStrength: 0.48,
      outline: dark,
    });
    canvas.setPixel(ox + 15, oy + 20 + bob, dark); // soundhole / pickup
    // Angled neck & headstock
    for (let s = 0; s < 7; s++) {
      canvas.setPixel(ox + 18 + s, oy + 18 - Math.floor(s * 0.6) + bob, hex('#5c3a21'));
      canvas.setPixel(ox + 18 + s, oy + 17 - Math.floor(s * 0.6) + bob, gCol);
    }
  }
}

function drawPortrait(spec) {
  const p = new PixelCanvas(64, 64);
  const accent = hex(spec.accent);
  const bgTheme = hex(spec.portraitBg ?? spec.accent);
  const bgOuter = shade(bgTheme, 0.24);
  const bgInner = shade(bgTheme, 0.56);

  // Radial studio-lit portrait backdrop
  for (let y = 0; y < 64; y++) {
    for (let x = 0; x < 64; x++) {
      const d = Math.min(1, Math.hypot(x - 32, y - 28) / 36);
      p.putRaw(x, y, mixCol(bgInner, bgOuter, d));
    }
  }
  // Bokeh stage lights in background
  p.fillEllipse(14, 16, 4, 4, hex('#ffd166', 48));
  p.fillEllipse(50, 20, 5, 5, hex('#ffffff', 40));
  p.strokeEllipse(32, 32, 30, 30, bgTheme);
  p.strokeEllipse(32, 32, 28.5, 28.5, hex('#ffd166', 145));

  const shell = hex(spec.shell);
  const ridge = hex(spec.ridge);
  const dark = hex('#1c110a');

  // Back hair halo in portrait
  if (spec.hair === 'afro_crown') {
    p.fillLitEllipsoid(32, 27, 23, 20, hex('#1e1410'), { specStrength: 0.16, outline: dark });
  } else if (spec.hair === 'long_parted') {
    p.fillLitCylinder(11, 24, 7, 26, hex('#3b2214'), { specStrength: 0.2 });
    p.fillLitCylinder(46, 24, 7, 26, hex('#3b2214'), { specStrength: 0.2 });
  }

  // 3D Shoulders / Festival Jacket
  p.fillLitEllipsoid(32, 56, 19, 12, accent, { specStrength: 0.25, outline: dark });
  if (spec.outfit === 'tie_dye') {
    const tdCols = [hex('#ff595e'), hex('#ffca3a'), hex('#8ac926'), hex('#1982c4'), hex('#6a4c93')];
    for (let dy = 48; dy < 63; dy++) {
      for (let dx = 16; dx < 48; dx++) {
        if ((dx - 32) ** 2 / 260 + (dy - 56) ** 2 / 90 <= 1 && (dx + dy) % 2 === 0) {
          const ang = Math.atan2(dy - 56, dx - 32) + Math.hypot(dx - 32, dy - 56) * 0.35;
          const ci = ((Math.floor(ang * 1.8) % 5) + 5) % 5;
          p.setPixel(dx, dy, tdCols[ci]);
        }
      }
    }
  } else if (spec.outfit === 'sunshine_poncho') {
    p.fillLitEllipsoid(32, 55, 18, 9, hex('#ffbe0b'), { specStrength: 0.28, outline: dark });
  }

  // 3D Sculpted Walnut Head (with variety-specific shape, suture, freckles, ribs, heart or sprout!)
  const prx = spec.broad ? 20.2 : 18.2;
  const pry = spec.tall ? 21.4 : 19.6;
  drawSculptedWalnutShell(p, 32, 33, prx, pry, shell, ridge, dark, spec, 0);

  // Front hair fringes in portrait
  if (spec.hair === 'mop_curls') {
    p.fillLitEllipsoid(32, 14, 17, 5.5, hex('#3b2314'), { specStrength: 0.22, outline: dark });
  } else if (spec.hair === 'blonde_fringe') {
    p.fillLitEllipsoid(32, 14, 16.5, 5.2, hex('#f3c65f'), { specStrength: 0.35, outline: dark });
    p.fillRect(14, 18, 4, 16, hex('#e9b44c'));
    p.fillRect(46, 18, 4, 16, hex('#e9b44c'));
  }

  // Expressive 3D Eyes or Specular Glasses
  if (spec.glasses) {
    const gc = hex(spec.glasses);
    p.fillLitEllipsoid(24, 31, 6.2, 5.0, gc, { specStrength: 0.65, outline: dark });
    p.fillLitEllipsoid(40, 31, 6.2, 5.0, gc, { specStrength: 0.65, outline: dark });
    p.fillRect(29, 30, 6, 2, dark);
    p.fillRect(21, 28, 3, 2, hex('#ffffff', 200));
    p.fillRect(37, 28, 3, 2, hex('#ffffff', 200));
  } else {
    p.fillEllipse(25, 31, 3.5, 4.5, dark);
    p.fillEllipse(39, 31, 3.5, 4.5, dark);
    p.fillRect(23, 28, 2, 2, hex('#ffffff'));
    p.fillRect(37, 28, 2, 2, hex('#ffffff'));
    p.setPixel(26, 33, hex('#a8dadc', 180));
    p.setPixel(40, 33, hex('#a8dadc', 180));
  }

  // Facial hair or warm curved smile
  if (spec.facial === 'full_beard') {
    p.fillLitEllipsoid(32, 43, 11.5, 6.2, hex('#2e1a0f'), { specStrength: 0.16 });
    p.fillRect(29, 40, 6, 2, hex('#ffd166'));
  } else if (spec.facial === 'santana_mustache') {
    p.fillRect(26, 38, 12, 2, hex('#1a110b'));
    p.fillRect(28, 41, 8, 2, dark);
  } else if (spec.facial === 'goatee') {
    p.fillRect(28, 40, 8, 2, dark);
    p.fillRect(30, 43, 4, 4, hex('#2b190e'));
  } else {
    p.fillRect(28, 41, 8, 2, dark);
    p.setPixel(27, 40, dark);
    p.setPixel(36, 40, dark);
  }

  // Portrait Headwear
  if (spec.hat === 'felt_twig') {
    p.fillEllipse(32, 13, 21, 4, hex('#1b4332'));
    p.fillLitEllipsoid(32, 10, 14, 5, hex('#2d6a4f'), { specStrength: 0.3 });
    p.fillRect(42, 3, 2, 8, hex('#74c69d'));
    p.fillLitEllipsoid(46, 4, 4.5, 2.5, hex('#b7e4c7'));
  } else if (spec.hat === 'bandana_purple' || spec.hat === 'bandana_red') {
    const hc = hex(spec.hat === 'bandana_purple' ? '#9d4edd' : '#e63946');
    p.fillLitCylinder(14, 13, 36, 6, hc, { specStrength: 0.32 });
  } else if (spec.hat === 'beaded_headband') {
    p.fillRect(14, 15, 36, 3, hex('#6f4518'));
    for (let bx = 16; bx <= 46; bx += 5) {
      p.fillRect(bx, 15, 2, 2, hex('#48cae4'));
      p.fillRect(bx + 2, 16, 2, 2, hex('#ffd166'));
    }
  } else if (spec.hat === 'feathers') {
    p.fillLitEllipsoid(44, 10, 3.5, 7.5, hex('#2ec4b6'), { specStrength: 0.45 });
    p.fillLitEllipsoid(49, 12, 3.2, 6.5, hex('#ff9f1c'), { specStrength: 0.45 });
  } else if (spec.hat === 'crown_cap') {
    const cc = spec.id === 'npc_don_shello' ? hex('#f5cb5c' ) : hex('#4cc9f0');
    p.fillLitEllipsoid(32, 12, 16, 6, cc, { specStrength: 0.45, outline: dark });
  } else if (spec.hat === 'flower_braid' || spec.hat === 'woven_garland') {
    for (const [fx, col] of [[18, '#ffafcc'], [25, '#ffd166'], [32, '#ffffff'], [39, '#bdb2ff'], [46, '#ffafcc']]) {
      p.fillLitEllipsoid(fx, 13, 3.5, 3.2, hex(col), { specStrength: 0.4 });
    }
  } else if (spec.hat === 'daisy_clip') {
    p.fillLitEllipsoid(44, 14, 5.2, 5.2, hex('#ffffff'), { specStrength: 0.45 });
    p.fillEllipse(44, 14, 2.2, 2.2, hex('#ffb703'));
  } else if (spec.hat === 'straw_sunhat' || spec.hat === 'arlo_floppy_hat') {
    p.fillEllipse(32, 14, 24, 4.5, hex('#e9c46a'));
    p.fillLitEllipsoid(32, 10, 14, 5.5, hex('#f4d35e'), { specStrength: 0.32, outline: dark });
    p.fillRect(19, 12, 26, 2, hex('#e76f51'));
  } else if (spec.hat === 'panama_fedora') {
    p.fillEllipse(32, 14, 21, 4.0, hex('#f8f9fa'));
    p.fillLitEllipsoid(32, 10, 13, 5.0, hex('#ffffff'), { specStrength: 0.38, outline: dark });
    p.fillRect(19, 12, 26, 2, hex('#1b1b22'));
  } else if (spec.hat === 'velvet_beret') {
    p.fillLitEllipsoid(30, 11, 16, 5.5, hex('#7b2cbf'), { specStrength: 0.35, outline: dark });
  } else if (spec.hat === 'knit_beanie') {
    p.fillLitEllipsoid(32, 11, 15.5, 6.0, hex('#9b2226'), { specStrength: 0.28, outline: dark });
  } else if (spec.hat === 'kangol_white') {
    p.fillLitEllipsoid(32, 11, 15.5, 5.8, hex('#f8f9fa'), { specStrength: 0.4, outline: dark });
    p.fillLitEllipsoid(12, 30, 3.5, 5.5, hex('#00f5d4'), { outline: dark });
    p.fillLitEllipsoid(52, 30, 3.5, 5.5, hex('#00f5d4'), { outline: dark });
  } else if (spec.hat === 'crystal_antennae') {
    p.fillRect(24, 4, 2, 9, hex('#72efdd'));
    p.fillRect(38, 4, 2, 9, hex('#72efdd'));
    p.fillLitEllipsoid(25, 4, 3.2, 3.2, hex('#80ffdb'), { specStrength: 0.7 });
    p.fillLitEllipsoid(39, 4, 3.2, 3.2, hex('#c77dff'), { specStrength: 0.7 });
  } else if (spec.hat === 'solar_crown' || spec.hat === 'halo' || spec.hat === 'star_crest') {
    p.strokeEllipse(32, 8, 14, 4.0, hex('#ffd166'));
  }

  return p;
}

function buildCharacters() {
  for (const spec of CHARACTER_SPECS) {
    const sheet = new PixelCanvas(96, 128);
    for (let dir = 0; dir < 4; dir++) {
      for (let frame = 0; frame < 3; frame++) {
        drawWalnutFrame(sheet, frame * 32, dir * 32, spec, dir, frame);
      }
    }
    sheet.save(path.join(ROOT, `assets/images/characters/${spec.id}_sheet.png`));
    if (!spec.sheetOnly) {
      drawPortrait(spec).save(path.join(ROOT, `assets/images/characters/${spec.id}_portrait.png`));
    }
  }
}

// ============================================================================
// 4. 8 DISTINCT 3D-PRINTED TOTEM SCULPTURES & PROPS
// ============================================================================
function buildTotemsAndProps() {
  const totems = [
    { id: 'totem_01', color: '#ffd166', base: '#9c6644', shape: 'kernel' },
    { id: 'totem_02', color: '#b565f7', base: '#3c096c', shape: 'guitar' },
    { id: 'totem_03', color: '#52b788', base: '#1b4332', shape: 'lute' },
    { id: 'totem_04', color: '#4cc9f0', base: '#1d3557', shape: 'spire' },
    { id: 'totem_05', color: '#f72585', base: '#560bad', shape: 'chalice' },
    { id: 'totem_06', color: '#f4a261', base: '#7f4f24', shape: 'substack' },
    { id: 'totem_07', color: '#80ffdb', base: '#006d77', shape: 'bell' },
    { id: 'totem_08', color: '#ffbe0b', base: '#fb5607', shape: 'monolith' },
  ];

  for (const t of totems) {
    const c = new PixelCanvas(48, 48);
    const col = hex(t.color);
    const base = hex(t.base);

    // Ground contact shadow + 3D beveled plinth base
    c.fillEllipse(24, 43, 16, 4, hex('#000000', 110));
    c.fillLitCylinder(11, 37, 26, 5, base, { specStrength: 0.28 });
    c.fillLitEllipsoid(24, 37, 13, 3.2, shade(base, 1.28), { specStrength: 0.35 });

    // 3D-printed PLA/resin sculpture with horizontal 0.2mm layer normal modulation
    for (let y = 8; y < 37; y++) {
      const u = (y - 8) / 29; // 0 top -> 1 bottom
      let halfW = 9;
      if (t.shape === 'kernel') halfW = Math.round(3 + 9 * Math.sin(u * Math.PI));
      else if (t.shape === 'guitar') halfW = u < 0.42 ? 3 : Math.round(6 + 5 * Math.sin((u - 0.4) * Math.PI * 1.6));
      else if (t.shape === 'lute') halfW = u < 0.38 ? 2 : Math.round(4 + 8 * Math.sin((u - 0.35) * Math.PI * 1.4));
      else if (t.shape === 'spire') halfW = Math.max(2, Math.round(2 + u * 10 * (1 - 0.15 * Math.sin(u * 18))));
      else if (t.shape === 'chalice') halfW = u < 0.48 ? Math.round(10 - u * 12) : u < 0.72 ? 3 : Math.round(3 + (u - 0.7) * 22);
      else if (t.shape === 'substack') halfW = y % 9 === 0 ? 7 : 9;
      else if (t.shape === 'bell') halfW = Math.round(3 + Math.pow(u, 1.4) * 9);
      else halfW = 7;

      const layerFactor = y % 2 === 0 ? 1.04 : 0.90;
      c.fillLitCylinder(24 - halfW, y, halfW * 2, 1, shade(col, layerFactor), { specStrength: 0.48 });
    }
    // Glowing core highlight on main sculpture body
    c.fillLitEllipsoid(22.5, 27, 2.6, 2.6, hex('#ffffff', 155), { specStrength: 0.7 });
    c.save(path.join(ROOT, `assets/images/totems/${t.id}.png`));
  }

  // 3D Refractive Morning Dew Drop
  const dew = new PixelCanvas(16, 16);
  dew.fillEllipse(8, 13, 4.5, 1.8, hex('#000000', 80));
  dew.fillLitEllipsoid(8, 9, 4.4, 5.2, hex('#48cae4'), {
    specStrength: 0.75,
    specPower: 26,
    rimStrength: 0.35,
    outline: hex('#0077b6'),
  });
  dew.setPixel(6, 7, hex('#ffffff'));
  dew.save(path.join(ROOT, 'assets/images/props/dew_drop.png'));

  // 3D Specular Vinyl Record Disc
  const vinyl = new PixelCanvas(32, 32);
  vinyl.fillLitEllipsoid(16, 16, 14, 14, hex('#181820'), { specStrength: 0.55, outline: hex('#09090d') });
  vinyl.strokeEllipse(16, 16, 10.5, 10.5, hex('#353545'));
  vinyl.strokeEllipse(16, 16, 8, 8, hex('#2b2b38'));
  vinyl.fillLitEllipsoid(16, 16, 5, 5, hex('#e76f51'), { specStrength: 0.35 });
  vinyl.setPixel(16, 16, hex('#ffffff'));
  vinyl.save(path.join(ROOT, 'assets/images/props/vinyl_disc.png'));

  // 3D 6-Panel Specular Festival Beach Ball
  const ball = new PixelCanvas(24, 24);
  const panelColors = [
    hex('#ff595e'),
    hex('#ffca3a'),
    hex('#f8f9fa'),
    hex('#1982c4'),
    hex('#8ac926'),
    hex('#9d4edd'),
  ];
  for (let y = 2; y < 22; y++) {
    for (let x = 2; x < 22; x++) {
      const dx = (x - 11.5) / 9.5;
      const dy = (y - 11.5) / 9.5;
      const r2 = dx * dx + dy * dy;
      if (r2 > 1.0) continue;
      const nz = Math.sqrt(Math.max(0.05, 1.0 - r2));
      const ang = Math.atan2(dy, dx);
      const panelIdx = ((Math.floor(((ang + Math.PI) / (Math.PI * 2)) * 6) % 6) + 6) % 6;
      const base = panelColors[panelIdx];
      const ndotl = Math.max(0, -0.45 * dx - 0.55 * dy + 0.70 * nz);
      const spec = Math.pow(Math.max(0, -0.35 * dx - 0.45 * dy + 0.82 * nz), 18) * 0.55;
      const lit = shade(base, 0.52 + 0.62 * ndotl);
      ball.setPixel(x, y, mixCol(lit, hex('#ffffff'), Math.min(1, spec)));
      if (r2 > 0.82) {
        ball.setPixel(x, y, hex('#1c1424'));
      }
    }
  }
  ball.fillLitEllipsoid(11.5, 6.5, 2.5, 1.6, hex('#ffffff'), { outline: hex('#1c1424') });
  ball.save(path.join(ROOT, 'assets/images/props/beach_ball.png'));

  // 3D Brass Pocket Festival Compass with Specular Glint
  const compass = new PixelCanvas(16, 16);
  compass.fillEllipse(8, 13, 5.5, 2.0, hex('#000000', 95));
  compass.fillLitEllipsoid(8, 8.5, 5.6, 5.2, hex('#e9b44c'), {
    specStrength: 0.65,
    outline: hex('#5c3a12'),
  });
  compass.fillEllipse(8, 8.5, 3.6, 3.2, hex('#fff8e8'));
  compass.fillRect(8, 6, 1, 3, hex('#e63946'));
  compass.fillRect(7, 9, 1, 2, hex('#1d3557'));
  compass.setPixel(6, 5, hex('#ffffff'));
  compass.setPixel(12, 3, hex('#fff3b0'));
  compass.save(path.join(ROOT, 'assets/images/props/compass_glint.png'));

  // 3D Woven Patchwork Picnic Blanket (48x36)
  const blanket = new PixelCanvas(48, 36);
  blanket.fillRect(2, 33, 44, 2, hex('#000000', 95));
  const quiltPalette = [
    '#e63946', '#f4a261', '#e9c46a', '#2a9d8f', '#457b9d', '#9d4edd',
  ];
  for (let qy = 0; qy < 3; qy++) {
    for (let qx = 0; qx < 4; qx++) {
      const col = hex(quiltPalette[(qx + qy * 2) % quiltPalette.length]);
      for (let dy = 0; dy < 10; dy++) {
        for (let dx = 0; dx < 10; dx++) {
          const weave = (dx + dy) % 2 === 0 ? 1.06 : 0.94;
          const seam = dx === 0 || dy === 0 ? 0.78 : 1.0;
          blanket.setPixel(4 + qx * 10 + dx, 3 + qy * 10 + dy, shade(col, weave * seam));
        }
      }
    }
  }
  for (let fx = 4; fx < 44; fx += 2) {
    blanket.fillRect(fx, 1, 1, 2, hex('#fff3d6'));
    blanket.fillRect(fx, 33, 1, 2, hex('#e6d3a7'));
  }
  for (let fy = 4; fy < 32; fy += 2) {
    blanket.fillRect(2, fy, 2, 1, hex('#fff3d6'));
    blanket.fillRect(44, fy, 2, 1, hex('#e6d3a7'));
  }
  blanket.save(path.join(ROOT, 'assets/images/props/picnic_blanket.png'));
}

const worldOnly = process.argv.includes('--world-only');
const tileMeta = buildTilesetAndTsx();
buildFullOrchardTmx(tileMeta);
if (!worldOnly) {
  buildCharacters();
  buildTotemsAndProps();
}
console.log(
  worldOnly
    ? '[Walnutstock 3D Art Pipeline] Generated expanded 84-tile 2.5D tileset & verified 128x96 redesigned TMX.'
    : '[Walnutstock 3D Art Pipeline] Generated expanded 84-tile 2.5D tileset, 128x96 TMX, character sheets/portraits, and 8 sculpted 3D totems.',
);
