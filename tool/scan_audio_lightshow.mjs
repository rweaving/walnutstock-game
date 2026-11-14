#!/usr/bin/env node
/**
 * Walnutstock Offline Multi-Band Audio DSP Scanner & Light-Show / Choreography Compiler
 *
 * Scans all 30 scheduled festival tracks via ffmpeg (16 kHz mono float32 PCM) and runs
 * a 512-point Hann-windowed Radix-2 FFT at 40 Hz (25 ms resolution) to generate:
 *   1. Continuous 10 Hz (100 ms) 4-band spectral envelopes (Bass, Mid, Lead/Vocal, Air/Cymbal)
 *   2. Autocorrelation-detected BPM & phase-locked beat grid offset
 *   3. 25 ms-accurate transient accent cues (kick drops, snare snaps, cymbal blinders, lead riffs)
 *   4. Beat-snapped structural musical sections (intro, verse, chorus, solo, percussion break, hush, climax, outro)
 *
 * Outputs: assets/data/track_lightshows.json
 */

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');

const SAMPLE_RATE = 16000;
const FFT_SIZE = 512;
const HOP_SAMPLES = 400; // 25 ms = 40 Hz analysis rate
const ENV_STRIDE = 4; // 4 * 25 ms = 100 ms (10 Hz) continuous envelope rate
const B64_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

// Precompute Hann window & bit-reversal table for 512-pt Radix-2 FFT
const HANN = new Float32Array(FFT_SIZE);
const BIT_REV = new Uint16Array(FFT_SIZE);
for (let i = 0; i < FFT_SIZE; i++) {
  HANN[i] = 0.5 * (1 - Math.cos((2 * Math.PI * i) / (FFT_SIZE - 1)));
  let rev = 0;
  let x = i;
  for (let b = 0; b < 9; b++) {
    rev = (rev << 1) | (x & 1);
    x >>= 1;
  }
  BIT_REV[i] = rev;
}

const COS_TABLE = new Float32Array(FFT_SIZE / 2);
const SIN_TABLE = new Float32Array(FFT_SIZE / 2);
for (let i = 0; i < FFT_SIZE / 2; i++) {
  const ang = (-2 * Math.PI * i) / FFT_SIZE;
  COS_TABLE[i] = Math.cos(ang);
  SIN_TABLE[i] = Math.sin(ang);
}

function fft512(re, im) {
  for (let i = 0; i < FFT_SIZE; i++) {
    const j = BIT_REV[i];
    if (j > i) {
      const tr = re[i];
      re[i] = re[j];
      re[j] = tr;
      const ti = im[i];
      im[i] = im[j];
      im[j] = ti;
    }
  }
  for (let len = 2; len <= FFT_SIZE; len <<= 1) {
    const half = len >> 1;
    const step = FFT_SIZE / len;
    for (let i = 0; i < FFT_SIZE; i += len) {
      for (let j = 0; j < half; j++) {
        const idx = j * step;
        const wr = COS_TABLE[idx];
        const wi = SIN_TABLE[idx];
        const ur = re[i + j];
        const ui = im[i + j];
        const vr = re[i + j + half] * wr - im[i + j + half] * wi;
        const vi = re[i + j + half] * wi + im[i + j + half] * wr;
        re[i + j] = ur + vr;
        im[i + j] = ui + vi;
        re[i + j + half] = ur - vr;
        im[i + j + half] = ui - vi;
      }
    }
  }
}

function decodeMonoPcm(filePath) {
  const proc = spawnSync(
    'ffmpeg',
    ['-v', 'error', '-i', filePath, '-ac', '1', '-ar', String(SAMPLE_RATE), '-f', 'f32le', '-'],
    { maxBuffer: 160 * 1024 * 1024 },
  );
  if (proc.status !== 0 || !proc.stdout || proc.stdout.length < FFT_SIZE * 4) {
    throw new Error(`ffmpeg failed for ${filePath}: ${proc.stderr?.toString() ?? 'unknown'}`);
  }
  const sampleCount = Math.floor(proc.stdout.byteLength / 4);
  const out = new Float32Array(sampleCount);
  Buffer.from(proc.stdout.buffer, proc.stdout.byteOffset, sampleCount * 4).copy(
    Buffer.from(out.buffer),
  );
  return out;
}

function percentile(arr, q) {
  if (arr.length === 0) return 1e-5;
  const copy = Float32Array.from(arr);
  copy.sort();
  // Ignore dead-silent frames if mostly non-silent
  let start = 0;
  while (start < copy.length - 10 && copy[start] <= 1e-6) start++;
  const activeLen = copy.length - start;
  const idx = start + Math.min(activeLen - 1, Math.max(0, Math.floor(activeLen * q)));
  return Math.max(1e-5, copy[idx]);
}

function encodeEnvelopeB64(values10Hz) {
  let out = '';
  for (let i = 0; i < values10Hz.length; i++) {
    const v = Math.max(0, Math.min(1, values10Hz[i]));
    const q = Math.round(v * 63);
    out += B64_CHARS[q];
  }
  return out;
}

function estimateBpmAndOffset(flux, bassFlux, hopSec) {
  const n = flux.length;
  if (n < 80) return { bpm: 112.0, beatOffsetSec: 0.0 };

  const combined = new Float32Array(n);
  let mean = 0;
  for (let i = 0; i < n; i++) {
    combined[i] = flux[i] + bassFlux[i] * 1.35;
    mean += combined[i];
  }
  mean /= n;
  for (let i = 0; i < n; i++) {
    combined[i] = Math.max(0, combined[i] - mean * 0.85);
  }

  // Lag search 68 BPM .. 176 BPM at 40 Hz (lag 13 .. 35 frames)
  const minLag = 13;
  const maxLag = 36;
  const ac = new Float32Array(maxLag + 1);
  for (let lag = minLag; lag <= maxLag; lag++) {
    let sum = 0;
    const limit = n - lag;
    for (let i = 0; i < limit; i++) {
      sum += combined[i] * combined[i + lag];
    }
    const bpmCand = 60.0 / (lag * hopSec);
    // Gentle prior favoring natural live band tempos around 92-138 BPM
    const prior = 1.0 - 0.14 * Math.pow((bpmCand - 116.0) / 52.0, 2);
    ac[lag] = (sum / Math.max(1, limit)) * prior;
  }

  let bestLag = 20;
  let bestVal = -1;
  for (let lag = minLag; lag <= maxLag; lag++) {
    let score = ac[lag];
    if (lag * 2 <= maxLag) score += 0.35 * ac[lag * 2];
    if (lag % 2 === 0 && lag / 2 >= minLag) score += 0.25 * ac[lag / 2];
    if (score > bestVal) {
      bestVal = score;
      bestLag = lag;
    }
  }

  // Parabolic interpolation around bestLag for sub-frame BPM accuracy
  let refinedLag = bestLag;
  if (bestLag > minLag && bestLag < maxLag) {
    const y0 = ac[bestLag - 1];
    const y1 = ac[bestLag];
    const y2 = ac[bestLag + 1];
    const denom = 2 * (2 * y1 - y0 - y2);
    if (Math.abs(denom) > 1e-7) {
      const delta = (y0 - y2) / denom;
      if (Math.abs(delta) < 0.6) refinedLag = bestLag + delta;
    }
  }

  const bpm = Math.round((60.0 / (refinedLag * hopSec)) * 10) / 10;
  const periodFrames = 60.0 / (bpm * hopSec);

  // Find phase offset maximizing alignment with combined onset energy
  const phaseSteps = 32;
  let bestPhase = 0;
  let bestPhaseScore = -1;
  for (let p = 0; p < phaseSteps; p++) {
    const startFrame = (p / phaseSteps) * periodFrames;
    let score = 0;
    let count = 0;
    for (let pos = startFrame; pos < n - 1; pos += periodFrames) {
      const idx = Math.round(pos);
      score += combined[idx] + 0.5 * (combined[Math.max(0, idx - 1)] + combined[Math.min(n - 1, idx + 1)]);
      count++;
    }
    if (count > 0 && score / count > bestPhaseScore) {
      bestPhaseScore = score / count;
      bestPhase = startFrame * hopSec;
    }
  }

  return {
    bpm,
    beatOffsetSec: Math.round(bestPhase * 1000) / 1000,
  };
}

function detectAccents(flux, bassN, midN, highMidN, airN, hopSec, isPaBroadcast) {
  const n = flux.length;
  const accents = [];
  const winRadius = 24; // +-0.6s adaptive local window
  const minGapFrames = isPaBroadcast ? 14 : 9; // 0.35s PA, 0.225s music
  let lastAccepted = -999;

  const p92Flux = percentile(flux, 0.92);

  for (let i = 2; i < n - 2; i++) {
    const cur = flux[i];
    if (cur <= flux[i - 1] || cur < flux[i + 1] || cur <= flux[i - 2] || cur < flux[i + 2]) {
      continue;
    }
    if (i - lastAccepted < minGapFrames) continue;

    const w0 = Math.max(0, i - winRadius);
    const w1 = Math.min(n - 1, i + winRadius);
    let sum = 0;
    let sumSq = 0;
    const count = w1 - w0 + 1;
    for (let k = w0; k <= w1; k++) {
      sum += flux[k];
      sumSq += flux[k] * flux[k];
    }
    const mean = sum / count;
    const std = Math.sqrt(Math.max(0, sumSq / count - mean * mean));
    const threshold = mean + (isPaBroadcast ? 1.15 : 1.38) * std + p92Flux * 0.14;
    if (cur < threshold) continue;

    const b = bassN[i];
    const m = midN[i];
    const hm = highMidN[i];
    const a = airN[i];

    // Classify accent:
    // 0 = kick_drop, 1 = snare_snap, 2 = cymbal_blinder, 3 = lead_riff
    let kind = 1;
    if (a > 0.68 && (b + m) > 0.95) {
      kind = 2; // Crash / Blinder burst!
    } else if (b >= hm * 1.08 && b >= m * 0.95 && b > 0.48) {
      kind = 0; // Heavy kick / bass drop!
    } else if (hm > b * 1.08 && hm > 0.52) {
      kind = 3; // Guitar riff / Vocal scream / PA emphasis!
    } else {
      kind = 1; // Snare / Rhythm chord stab
    }

    const strength = Math.max(0.25, Math.min(1.0, cur / (p92Flux * 1.18)));
    accents.push([
      Math.round(i * hopSec * 100) / 100,
      kind,
      Math.round(strength * 100) / 100,
    ]);
    lastAccepted = i;
  }

  // Cap density cleanly if extraordinarily busy while preserving strongest peaks across song
  const maxAccents = Math.max(18, Math.ceil(n * hopSec * (isPaBroadcast ? 1.1 : 1.45)));
  if (accents.length > maxAccents) {
    // Divide into 8s buckets so every part of the track keeps its best accents
    const bucketSec = 8.0;
    const totalSec = n * hopSec;
    const buckets = Math.max(1, Math.ceil(totalSec / bucketSec));
    const perBucket = Math.max(2, Math.ceil(maxAccents / buckets));
    const filtered = [];
    for (let bIdx = 0; bIdx < buckets; bIdx++) {
      const t0 = bIdx * bucketSec;
      const t1 = t0 + bucketSec;
      const slice = accents.filter((a) => a[0] >= t0 && a[0] < t1);
      slice.sort((x, y) => y[2] - x[2]);
      const top = slice.slice(0, perBucket).sort((x, y) => x[0] - y[0]);
      filtered.push(...top);
    }
    return filtered;
  }

  return accents;
}

function segmentSections(bass10, mid10, hm10, air10, flux40, bpm, beatOffsetSec, track) {
  const totalSec = bass10.length * 0.1;
  if (track.isPaBroadcast) {
    return [[0, Math.round(totalSec * 10) / 10, 'pa_cadence', 0.78]];
  }
  if (totalSec <= 16.0) {
    return [[0, Math.round(totalSec * 10) / 10, 'verse_pocket', 0.65]];
  }

  // Segment aligned to 8-bar / 16-beat musical phrase boundaries (~7-12s per phrase)
  const beatSec = 60.0 / Math.max(60.0, bpm);
  const barsPerBlock = bpm >= 126 ? 8 : 4; // 32 or 16 beats
  const blockSec = Math.max(6.5, Math.min(14.5, beatSec * 4 * barsPerBlock));

  const rawBlocks = [];
  let cursor = 0.0;
  // First block aligns to beatOffsetSec + N*blockSec
  let nextEdge = beatOffsetSec + blockSec;
  while (cursor < totalSec - 0.5) {
    let end = nextEdge;
    if (totalSec - end < blockSec * 0.45) {
      end = totalSec;
    }
    const i0 = Math.max(0, Math.floor(cursor * 10));
    const i1 = Math.min(bass10.length, Math.ceil(end * 10));
    let sumB = 0;
    let sumM = 0;
    let sumHM = 0;
    let sumA = 0;
    const len = Math.max(1, i1 - i0);
    for (let i = i0; i < i1; i++) {
      sumB += bass10[i];
      sumM += mid10[i];
      sumHM += hm10[i];
      sumA += air10[i];
    }
    const f0 = Math.max(0, Math.floor(cursor * 40));
    const f1 = Math.min(flux40.length, Math.ceil(end * 40));
    let sumF = 0;
    for (let f = f0; f < f1; f++) sumF += flux40[f];

    const avgB = sumB / len;
    const avgM = sumM / len;
    const avgHM = sumHM / len;
    const avgA = sumA / len;
    const energy = avgB * 0.32 + avgM * 0.28 + avgHM * 0.28 + avgA * 0.12;
    const fluxAvg = sumF / Math.max(1, f1 - f0);

    rawBlocks.push({
      start: cursor,
      end,
      avgB,
      avgM,
      avgHM,
      avgA,
      energy,
      fluxAvg,
    });
    cursor = end;
    nextEdge += blockSec;
  }

  const energies = Float32Array.from(rawBlocks.map((b) => b.energy));
  const fluxes = Float32Array.from(rawBlocks.map((b) => b.fluxAvg));
  const p80E = percentile(energies, 0.80);
  const p55E = percentile(energies, 0.55);
  const p25E = percentile(energies, 0.25);
  const p78F = percentile(fluxes, 0.78);

  const labeled = rawBlocks.map((b, idx) => {
    const relPos = ((b.start + b.end) * 0.5) / totalSec;
    const leadDom = b.avgHM / Math.max(0.08, b.avgB * 0.65 + b.avgM * 0.35);
    const percDom = (b.avgB + b.avgA * 0.8) / Math.max(0.08, b.avgM + b.avgHM * 0.5);

    let mode = 'verse_pocket';
    if (idx === 0 && b.energy < p80E) {
      mode = 'intro_dawn';
    } else if (idx === rawBlocks.length - 1 && b.energy <= p55E) {
      mode = 'outro_fade';
    } else if (b.energy >= p80E && relPos > 0.22) {
      // Distinguish blazing guitar/organ solo vs full-band climax prism
      if (leadDom > 1.24 && relPos < 0.88) {
        mode = 'solo_shred';
      } else {
        mode = 'climax_prism';
      }
    } else if (leadDom > 1.28 && b.energy >= p25E && relPos > 0.18) {
      mode = 'solo_shred';
    } else if (b.fluxAvg >= p78F && percDom > 1.15) {
      mode = 'rhythm_break';
    } else if (b.energy <= p25E) {
      mode = 'hush_glow';
    } else if (b.energy >= p55E) {
      mode = 'chorus_anthemy';
    } else {
      mode = 'verse_pocket';
    }

    const normIntensity = Math.max(0.18, Math.min(1.0, b.energy / Math.max(0.15, p80E * 1.08)));
    return [
      Math.round(b.start * 100) / 100,
      Math.round(b.end * 100) / 100,
      mode,
      Math.round(normIntensity * 100) / 100,
    ];
  });

  // Merge adjacent blocks that share the exact same mode for crisp structural transitions
  const merged = [];
  for (const seg of labeled) {
    const prev = merged[merged.length - 1];
    if (prev && prev[2] === seg[2]) {
      prev[1] = seg[1];
      prev[3] = Math.round(((prev[3] + seg[3]) * 0.5) * 100) / 100;
    } else {
      merged.push([...seg]);
    }
  }
  return merged;
}

function scanTrack(track) {
  const fullPath = path.join(ROOT, track.assetPath);
  const pcm = decodeMonoPcm(fullPath);
  const actualDecodedSec = pcm.length / SAMPLE_RATE;
  const isLoopedShortSample = track.assetPath.endsWith('.wav') && actualDecodedSec < track.durationSeconds * 0.5;

  const hopSec = HOP_SAMPLES / SAMPLE_RATE; // 0.025s
  const frameCount = Math.max(1, Math.floor((pcm.length - FFT_SIZE) / HOP_SAMPLES) + 1);

  const rawBass = new Float32Array(frameCount);
  const rawMid = new Float32Array(frameCount);
  const rawHM = new Float32Array(frameCount);
  const rawAir = new Float32Array(frameCount);
  const flux = new Float32Array(frameCount);
  const bassFlux = new Float32Array(frameCount);

  const re = new Float32Array(FFT_SIZE);
  const im = new Float32Array(FFT_SIZE);
  const prevLogMag = new Float32Array(FFT_SIZE / 2);

  for (let f = 0; f < frameCount; f++) {
    const offset = f * HOP_SAMPLES;
    for (let i = 0; i < FFT_SIZE; i++) {
      re[i] = (pcm[offset + i] ?? 0) * HANN[i];
      im[i] = 0;
    }
    fft512(re, im);

    let sumBass = 0;
    let sumMid = 0;
    let sumHM = 0;
    let sumAir = 0;
    let frameFlux = 0;

    for (let k = 1; k < 250; k++) {
      const mag = Math.hypot(re[k], im[k]) / (FFT_SIZE * 0.5);
      const logMag = Math.log1p(mag * 45.0);
      if (f > 0 && k <= 180) {
        const diff = logMag - prevLogMag[k];
        if (diff > 0) {
          // Extra weight on kick/snare/guitar attack bins (31 Hz .. 2500 Hz)
          frameFlux += diff * (k <= 80 ? 1.35 : 0.75);
        }
      }
      prevLogMag[k] = logMag;

      if (k <= 5) sumBass += mag;
      else if (k <= 32) sumMid += mag;
      else if (k <= 128) sumHM += mag;
      else sumAir += mag;
    }

    rawBass[f] = sumBass / 5;
    rawMid[f] = sumMid / 27;
    rawHM[f] = sumHM / 96;
    rawAir[f] = sumAir / 121;
    flux[f] = frameFlux;
    bassFlux[f] = f > 0 ? Math.max(0, rawBass[f] - rawBass[f - 1]) : 0;
  }

  const p96B = percentile(rawBass, 0.96);
  const p96M = percentile(rawMid, 0.96);
  const p96HM = percentile(rawHM, 0.96);
  const p96A = percentile(rawAir, 0.96);

  const bassN = new Float32Array(frameCount);
  const midN = new Float32Array(frameCount);
  const hmN = new Float32Array(frameCount);
  const airN = new Float32Array(frameCount);

  for (let f = 0; f < frameCount; f++) {
    bassN[f] = Math.min(1.0, Math.pow(rawBass[f] / p96B, 0.82));
    midN[f] = Math.min(1.0, Math.pow(rawMid[f] / p96M, 0.85));
    hmN[f] = Math.min(1.0, Math.pow(rawHM[f] / p96HM, 0.85));
    airN[f] = Math.min(1.0, Math.pow(rawAir[f] / p96A, 0.88));
  }

  // Downsample to 10 Hz (100 ms steps) using peak-preserving blend (65% peak + 35% mean)
  const envLen = Math.max(1, Math.ceil(frameCount / ENV_STRIDE));
  const bass10 = new Float32Array(envLen);
  const mid10 = new Float32Array(envLen);
  const hm10 = new Float32Array(envLen);
  const air10 = new Float32Array(envLen);

  for (let e = 0; e < envLen; e++) {
    const start = e * ENV_STRIDE;
    const end = Math.min(frameCount, start + ENV_STRIDE);
    const cnt = Math.max(1, end - start);
    let maxB = 0, sumB = 0;
    let maxM = 0, sumM = 0;
    let maxHM = 0, sumHM = 0;
    let maxA = 0, sumA = 0;
    for (let f = start; f < end; f++) {
      if (bassN[f] > maxB) maxB = bassN[f];
      sumB += bassN[f];
      if (midN[f] > maxM) maxM = midN[f];
      sumM += midN[f];
      if (hmN[f] > maxHM) maxHM = hmN[f];
      sumHM += hmN[f];
      if (airN[f] > maxA) maxA = airN[f];
      sumA += airN[f];
    }
    bass10[e] = 0.65 * maxB + 0.35 * (sumB / cnt);
    mid10[e] = 0.65 * maxM + 0.35 * (sumM / cnt);
    hm10[e] = 0.65 * maxHM + 0.35 * (sumHM / cnt);
    air10[e] = 0.65 * maxA + 0.35 * (sumA / cnt);
  }

  const { bpm, beatOffsetSec } = estimateBpmAndOffset(flux, bassFlux, hopSec);
  const accents = detectAccents(flux, bassN, midN, hmN, airN, hopSec, track.isPaBroadcast);
  const sections = segmentSections(bass10, mid10, hm10, air10, flux, bpm, beatOffsetSec, track);

  return {
    id: track.id,
    trackNumber: track.trackNumber,
    scannedDurationSec: Math.round(actualDecodedSec * 100) / 100,
    looped: isLoopedShortSample,
    bpm,
    beatOffsetSec,
    envHz: 10,
    bassB64: encodeEnvelopeB64(bass10),
    midB64: encodeEnvelopeB64(mid10),
    highMidB64: encodeEnvelopeB64(hm10),
    airB64: encodeEnvelopeB64(air10),
    sections,
    accents,
  };
}

function main() {
  const setlist = JSON.parse(
    fs.readFileSync(path.join(ROOT, 'assets/data/setlist_26_tracks.json'), 'utf8'),
  );
  const t0 = Date.now();
  const tracksOut = {};
  let totalAccents = 0;
  let totalSections = 0;

  for (const track of setlist.tracks) {
    const scanned = scanTrack(track);
    tracksOut[track.id] = scanned;
    totalAccents += scanned.accents.length;
    totalSections += scanned.sections.length;
    console.log(
      `[DSP] #${String(track.trackNumber).padStart(2, '0')} ${track.id.padEnd(16)} | ` +
      `${String(scanned.scannedDurationSec).padStart(6)}s | ${String(scanned.bpm).padStart(5)} BPM | ` +
      `${String(scanned.sections.length).padStart(2)} sections | ${String(scanned.accents.length).padStart(3)} accents`,
    );
  }

  const payload = {
    version: 1,
    sampleRateHz: SAMPLE_RATE,
    fftSize: FFT_SIZE,
    analysisHz: 40,
    envelopeHz: 10,
    tracks: tracksOut,
  };

  const outPath = path.join(ROOT, 'assets/data/track_lightshows.json');
  const jsonStr = JSON.stringify(payload);
  fs.writeFileSync(outPath, jsonStr, 'utf8');
  const elapsedSec = ((Date.now() - t0) / 1000).toFixed(2);
  const sizeKb = (Buffer.byteLength(jsonStr, 'utf8') / 1024).toFixed(1);
  console.log(
    `\n✓ Scanned all ${setlist.tracks.length} audio tracks in ${elapsedSec}s -> ${outPath} (${sizeKb} KB, ${totalSections} sections, ${totalAccents} millisecond-synced accents).`,
  );
}

main();
