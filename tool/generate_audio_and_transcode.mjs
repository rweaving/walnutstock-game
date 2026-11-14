#!/usr/bin/env node
/**
 * Walnutstock v1.0 Procedural Audio Stem Synthesizer & Multi-Codec Transcoder
 * 1. Synthesizes stereo 16-bit PCM WAV SFX (C-major bells, pinball, vinyl crackle, resonators, moss bloom)
 * 2. Synthesizes procedural instrumental stems for the 3 Midnight/bootleg sets:
 *    - track_27_dembow ("Shaking of the Branches" — Don Shell-O Urbano Canopy dem-bow)
 *    - track_28_drupe ("The Drupe Dimension Drift" — Cosmo Shell-voy cosmic crystal-bass funk)
 *    - track_29_omega ("Omega Grove — Shelltrip Caravan" — Astral space-dub groove)
 * 3. Batch-transcodes tracks 01..29 into .ogg (Opus 112k) via ffmpeg and .m4a (AAC 128k) via afconvert/ffmpeg.
 */

import fs from 'node:fs';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const SFX_DIR = path.join(ROOT, 'assets/audio/sfx');
const TRACKS_DIR = path.join(ROOT, 'assets/audio/tracks');

function writeStereoWav(filePath, sampleRate, leftFloats, rightFloats) {
  const numSamples = leftFloats.length;
  const dataBytes = numSamples * 4; // 2 channels * 16-bit
  const buf = Buffer.alloc(44 + dataBytes);

  buf.write('RIFF', 0);
  buf.writeUInt32LE(36 + dataBytes, 4);
  buf.write('WAVE', 8);
  buf.write('fmt ', 12);
  buf.writeUInt32LE(16, 16);
  buf.writeUInt16LE(1, 20); // PCM
  buf.writeUInt16LE(2, 22); // Stereo
  buf.writeUInt32LE(sampleRate, 24);
  buf.writeUInt32LE(sampleRate * 4, 28);
  buf.writeUInt16LE(4, 32);
  buf.writeUInt16LE(16, 34);
  buf.write('data', 36);
  buf.writeUInt32LE(dataBytes, 40);

  let offset = 44;
  for (let i = 0; i < numSamples; i++) {
    const l = Math.max(-1, Math.min(1, leftFloats[i]));
    const r = Math.max(-1, Math.min(1, rightFloats[i]));
    buf.writeInt16LE(Math.round(l * 32767), offset);
    buf.writeInt16LE(Math.round(r * 32767), offset + 2);
    offset += 4;
  }
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, buf);
}

// ============================================================================
// 1. SYNTHESIZE PHASE 3-4 SFX
// ============================================================================
function synthesizeSfx() {
  const sr = 44100;

  // sfx_bell_cmajor.wav: Tula Twigwalker's shimmering C-major brass bells (C5, E5, G5, C6)
  {
    const dur = 2.4;
    const n = Math.floor(sr * dur);
    const L = new Float32Array(n);
    const R = new Float32Array(n);
    const freqs = [523.25, 659.25, 783.99, 1046.5];
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      let sL = 0;
      let sR = 0;
      freqs.forEach((f, idx) => {
        const onset = idx * 0.14;
        if (t >= onset) {
          const dt = t - onset;
          const env = Math.exp(-dt * 2.4) * (1 - Math.exp(-dt * 120));
          const tone =
            0.65 * Math.sin(2 * Math.PI * f * dt) +
            0.25 * Math.sin(2 * Math.PI * f * 2.003 * dt) +
            0.1 * Math.sin(2 * Math.PI * f * 3.01 * dt);
          sL += tone * env * (idx % 2 === 0 ? 0.32 : 0.22);
          sR += tone * env * (idx % 2 === 1 ? 0.32 : 0.22);
        }
      });
      L[i] = sL;
      R[i] = sR;
    }
    writeStereoWav(path.join(SFX_DIR, 'sfx_bell_cmajor.wav'), sr, L, R);
  }

  // sfx_pinball_bumper.wav: Bright optical sorter bumper pop + harmonic ring
  {
    const n = Math.floor(sr * 0.35);
    const L = new Float32Array(n);
    const R = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      const sweep = 880 + 660 * Math.exp(-t * 28);
      const s = Math.sin(2 * Math.PI * sweep * t) * Math.exp(-t * 11) * 0.65;
      L[i] = s;
      R[i] = s;
    }
    writeStereoWav(path.join(SFX_DIR, 'sfx_pinball_bumper.wav'), sr, L, R);
  }

  // sfx_pinball_flipper.wav: Optical air-jet flipper snap
  {
    const n = Math.floor(sr * 0.18);
    const L = new Float32Array(n);
    const R = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      const noise = (Math.sin(i * 12.9898) * 43758.5453) % 1;
      const click = Math.sin(2 * Math.PI * (240 + 900 * Math.exp(-t * 45)) * t);
      const s = (0.55 * click + 0.35 * noise) * Math.exp(-t * 22) * 0.6;
      L[i] = s;
      R[i] = s;
    }
    writeStereoWav(path.join(SFX_DIR, 'sfx_pinball_flipper.wav'), sr, L, R);
  }

  // sfx_vinyl_crackle.wav: Warm 4-second seamless analog vinyl groove dust loop
  {
    const n = Math.floor(sr * 4.0);
    const L = new Float32Array(n);
    const R = new Float32Array(n);
    let lpL = 0;
    let lpR = 0;
    for (let i = 0; i < n; i++) {
      const r1 = ((Math.sin(i * 78.233 + 1.3) * 43758.5453) % 1) * 2 - 1;
      const r2 = ((Math.sin(i * 19.191 + 7.7) * 19341.1234) % 1) * 2 - 1;
      lpL = lpL * 0.92 + r1 * 0.015;
      lpR = lpR * 0.92 + r2 * 0.015;
      const popL = Math.abs(r1) > 0.9985 ? r1 * 0.24 : 0;
      const popR = Math.abs(r2) > 0.9985 ? r2 * 0.24 : 0;
      L[i] = lpL + popL;
      R[i] = lpR + popR;
    }
    writeStereoWav(path.join(SFX_DIR, 'sfx_vinyl_crackle.wav'), sr, L, R);
  }

  // sfx_resonator_hum.wav: Cosmo's space-glass harmonic crystal chord
  {
    const n = Math.floor(sr * 1.8);
    const L = new Float32Array(n);
    const R = new Float32Array(n);
    const chord = [293.66, 440.0, 554.37, 659.25, 880.0]; // Dmaj9 astral voicing
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      const env = Math.sin(Math.min(1, t / 0.25) * (Math.PI / 2)) * Math.exp(-t * 1.4);
      let sL = 0;
      let sR = 0;
      chord.forEach((f, idx) => {
        const lfo = 1 + 0.004 * Math.sin(2 * Math.PI * (4.5 + idx) * t);
        const v = Math.sin(2 * Math.PI * f * lfo * t) * 0.18;
        sL += v * (idx % 2 === 0 ? 1.0 : 0.6);
        sR += v * (idx % 2 === 1 ? 1.0 : 0.6);
      });
      L[i] = sL * env;
      R[i] = sR * env;
    }
    writeStereoWav(path.join(SFX_DIR, 'sfx_resonator_hum.wav'), sr, L, R);
  }

  // sfx_moss_bloom.wav: Lush organic ascending harp/moss glissando
  {
    const n = Math.floor(sr * 1.9);
    const L = new Float32Array(n);
    const R = new Float32Array(n);
    const notes = [392.0, 493.88, 587.33, 739.99, 783.99, 987.77, 1174.66];
    for (let i = 0; i < n; i++) {
      const t = i / sr;
      let sL = 0;
      let sR = 0;
      notes.forEach((f, idx) => {
        const onset = idx * 0.11;
        if (t >= onset) {
          const dt = t - onset;
          const v = Math.sin(2 * Math.PI * f * dt) * Math.exp(-dt * 3.2) * 0.25;
          const pan = idx / (notes.length - 1);
          sL += v * (1 - pan * 0.5);
          sR += v * (0.5 + pan * 0.5);
        }
      });
      L[i] = sL;
      R[i] = sR;
    }
    writeStereoWav(path.join(SFX_DIR, 'sfx_moss_bloom.wav'), sr, L, R);
  }
}

// ============================================================================
// 2. SYNTHESIZE 3 MIDNIGHT / BOOTLEG INSTRUMENTAL STEMS (WAV -> OGG/M4A/MP3)
// ============================================================================
function synthesizeBonusTracks() {
  const sr = 24000; // Crisp synthesis rate, fast transcode to 48kHz Opus & 44.1kHz AAC

  // Track 27: "Shaking of the Branches" — Don Shell-O Urbano Canopy Dem-Bow (96s, 100 BPM)
  {
    const dur = 96;
    const n = sr * dur;
    const L = new Float32Array(n);
    const R = new Float32Array(n);
    const bpm = 100;
    const beatSec = 60 / bpm;
    const stepSec = beatSec / 4; // 16th note
    const bassRoots = [55.0, 55.0, 65.41, 49.0]; // A1, A1, C2, G1

    for (let i = 0; i < n; i++) {
      const t = i / sr;
      const bar = Math.floor(t / (beatSec * 4));
      const stepInBar = Math.floor(t / stepSec) % 16;
      const dtStep = t % stepSec;

      // Dem-bow kick on 0, 4, 8, 12; syncopated snare on 3, 6, 11, 14
      let drum = 0;
      if (stepInBar % 4 === 0) {
        const kFreq = 54 + 95 * Math.exp(-dtStep * 36);
        drum += Math.sin(2 * Math.PI * kFreq * dtStep) * Math.exp(-dtStep * 9.5) * 0.62;
      }
      if (stepInBar === 3 || stepInBar === 6 || stepInBar === 11 || stepInBar === 14) {
        const nz = ((Math.sin(i * 91.7) * 43758.54) % 1) * 2 - 1;
        const rim = Math.sin(2 * Math.PI * 310 * dtStep);
        drum += (0.45 * nz + 0.45 * rim) * Math.exp(-dtStep * 22) * 0.42;
      }

      // Santurce Sub-woofer 808 + warm brass stabs
      const root = bassRoots[bar % 4];
      const sub = Math.sin(2 * Math.PI * root * t) * (0.35 + 0.15 * Math.sin(2 * Math.PI * 2 * t));
      let stabL = 0;
      let stabR = 0;
      if (stepInBar === 0 || stepInBar === 6 || stepInBar === 10) {
        const env = Math.exp(-dtStep * 7.5) * 0.22;
        stabL = (Math.sin(2 * Math.PI * root * 4 * t) + 0.6 * Math.sin(2 * Math.PI * root * 6 * t)) * env;
        stabR = (Math.sin(2 * Math.PI * root * 4.01 * t) + 0.6 * Math.sin(2 * Math.PI * root * 5.99 * t)) * env;
      }

      const fade = Math.min(1, t / 1.5, (dur - t) / 2.0);
      L[i] = Math.tanh((drum + sub + stabL) * 1.1) * 0.8 * fade;
      R[i] = Math.tanh((drum + sub + stabR) * 1.1) * 0.8 * fade;
    }
    writeStereoWav(path.join(TRACKS_DIR, 'track_27_dembow.wav'), sr, L, R);
  }

  // Track 28: "The Drupe Dimension Drift" — Cosmo Shell-voy Cosmic Crystal-Bass Funk (104s, 92 BPM)
  {
    const dur = 104;
    const n = sr * dur;
    const L = new Float32Array(n);
    const R = new Float32Array(n);
    const bpm = 92;
    const stepSec = 60 / bpm / 4;
    const grooveNotes = [73.42, 73.42, 87.31, 98.0, 110.0, 98.0, 130.81, 110.0]; // D minor pentatonic funk

    for (let i = 0; i < n; i++) {
      const t = i / sr;
      const step = Math.floor(t / stepSec);
      const dt = t % stepSec;
      const fBass = grooveNotes[step % grooveNotes.length];

      // Envelope-filtered Crystal-Bridge Bass
      const env = Math.exp(-dt * 8.0);
      const wow = 1 + 0.5 * env;
      const bass =
        (0.55 * Math.sin(2 * Math.PI * fBass * t) +
          0.3 * Math.sin(2 * Math.PI * fBass * 2 * wow * t) +
          0.15 * Math.sin(2 * Math.PI * fBass * 3 * wow * t)) *
        (0.35 + 0.45 * env);

      // Swirling stereo nebula pad (D9sus4)
      const phL = 0.5 + 0.5 * Math.sin(2 * Math.PI * 0.23 * t);
      const phR = 0.5 + 0.5 * Math.cos(2 * Math.PI * 0.23 * t);
      const pad =
        0.11 * Math.sin(2 * Math.PI * 293.66 * t) +
        0.09 * Math.sin(2 * Math.PI * 440.0 * t) +
        0.09 * Math.sin(2 * Math.PI * 523.25 * t) +
        0.08 * Math.sin(2 * Math.PI * 659.25 * t);

      // Cosmic hi-hat pulse
      const hat = step % 2 === 1 ? (((Math.sin(i * 45.13) * 19381.7) % 1) * Math.exp(-dt * 35) * 0.12) : 0;

      const fade = Math.min(1, t / 2.0, (dur - t) / 2.5);
      L[i] = Math.tanh(bass * 0.75 + pad * (0.6 + 0.6 * phL) + hat) * 0.8 * fade;
      R[i] = Math.tanh(bass * 0.75 + pad * (0.6 + 0.6 * phR) + hat) * 0.8 * fade;
    }
    writeStereoWav(path.join(TRACKS_DIR, 'track_28_drupe.wav'), sr, L, R);
  }

  // Track 29: "Omega Grove — Shelltrip Caravan" — Astral Space-Dub Groove (104s, 78 BPM)
  {
    const dur = 104;
    const n = sr * dur;
    const L = new Float32Array(n);
    const R = new Float32Array(n);
    const bpm = 78;
    const beatSec = 60 / bpm;
    const arp = [261.63, 329.63, 392.0, 493.88, 587.33, 493.88, 392.0, 329.63]; // Cmaj9 caravan

    for (let i = 0; i < n; i++) {
      const t = i / sr;
      const beat = Math.floor(t / beatSec);
      const dtBeat = t % beatSec;

      const bassRoot = (Math.floor(beat / 4) % 2 === 0) ? 65.41 : 55.0; // C2 -> A1
      const dubBass = Math.sin(2 * Math.PI * bassRoot * t) * (0.42 * Math.exp(-dtBeat * 2.2) + 0.18);

      const arpStep = Math.floor(t / (beatSec / 2));
      const dtArp = t % (beatSec / 2);
      const fArp = arp[arpStep % arp.length];
      const pluckL = Math.sin(2 * Math.PI * fArp * dtArp) * Math.exp(-dtArp * 6.5) * 0.24;
      // Stereo ping-pong tape delay!
      const delayArp = arp[(arpStep + arp.length - 1) % arp.length];
      const pluckR = Math.sin(2 * Math.PI * delayArp * 1.002 * dtArp) * Math.exp(-dtArp * 5.0) * 0.22;

      const fade = Math.min(1, t / 2.0, (dur - t) / 2.5);
      L[i] = Math.tanh(dubBass + pluckL + 0.35 * pluckR) * 0.82 * fade;
      R[i] = Math.tanh(dubBass + pluckR + 0.35 * pluckL) * 0.82 * fade;
    }
    writeStereoWav(path.join(TRACKS_DIR, 'track_29_omega.wav'), sr, L, R);
  }
}

// ============================================================================
// 3. TRANSCODE ALL TRACKS TO .OGG (OPUS) & .M4A (AAC)
// ============================================================================
function findBinary(name) {
  const candidates = [
    `/opt/homebrew/bin/${name}`,
    `/usr/local/bin/${name}`,
    `/usr/bin/${name}`,
  ];
  for (const c of candidates) {
    if (fs.existsSync(c)) return c;
  }
  const which = spawnSync('which', [name], { encoding: 'utf8' });
  if (which.status === 0 && which.stdout.trim()) return which.stdout.trim();
  return null;
}

function transcodeAllTracks() {
  const ffmpeg = findBinary('ffmpeg');
  const afconvert = findBinary('afconvert');

  const files = fs.readdirSync(TRACKS_DIR).sort();
  const baseIds = [...new Set(
    files
      .filter((f) => /\.(mp3|wav)$/.test(f))
      .map((f) => f.replace(/\.(mp3|wav)$/, '')),
  )];

  let oggDone = 0;
  let m4aDone = 0;

  for (const id of baseIds) {
    const srcMp3 = path.join(TRACKS_DIR, `${id}.mp3`);
    const srcWav = path.join(TRACKS_DIR, `${id}.wav`);
    const src = fs.existsSync(srcMp3) ? srcMp3 : srcWav;
    const outOgg = path.join(TRACKS_DIR, `${id}.ogg`);
    const outM4a = path.join(TRACKS_DIR, `${id}.m4a`);

    // Ensure MP3 also exists for procedural WAV tracks if ffmpeg is available
    if (!fs.existsSync(srcMp3) && fs.existsSync(srcWav) && ffmpeg) {
      execFileSync(ffmpeg, ['-y', '-loglevel', 'error', '-i', srcWav, '-c:a', 'libmp3lame', '-b:a', '128k', srcMp3]);
    }

    if (!fs.existsSync(outOgg) && ffmpeg) {
      execFileSync(ffmpeg, [
        '-y', '-loglevel', 'error',
        '-i', src,
        '-vn',
        '-c:a', 'libopus',
        '-b:a', '112k',
        '-vbr', 'on',
        outOgg,
      ]);
      oggDone++;
    }

    if (!fs.existsSync(outM4a)) {
      if (afconvert) {
        execFileSync(afconvert, ['-f', 'm4af', '-d', 'aac', '-b', '128000', src, outM4a]);
        m4aDone++;
      } else if (ffmpeg) {
        execFileSync(ffmpeg, [
          '-y', '-loglevel', 'error',
          '-i', src,
          '-vn',
          '-c:a', 'aac',
          '-b:a', '128k',
          '-movflags', '+faststart',
          outM4a,
        ]);
        m4aDone++;
      }
    }

    // Remove temporary large .wav stems for track_27..29 once encoded to compressed formats
    if (fs.existsSync(srcWav) && fs.existsSync(outOgg) && fs.existsSync(outM4a) && fs.existsSync(srcMp3)) {
      fs.unlinkSync(srcWav);
    }
  }

  console.log(`[Walnutstock Audio Pipeline] Transcoded ${oggDone} .ogg (Opus) and ${m4aDone} .m4a (AAC) tracks. (ffmpeg=${Boolean(ffmpeg)}, afconvert=${Boolean(afconvert)})`);
}

const mode = process.argv[2] || 'all';
if (mode === 'all' || mode === 'synth') {
  synthesizeSfx();
  synthesizeBonusTracks();
  console.log('[Walnutstock Audio Pipeline] Synthesized 6 stereo SFX and 3 Midnight bonus stems.');
}
if (mode === 'all' || mode === 'transcode') {
  transcodeAllTracks();
}
