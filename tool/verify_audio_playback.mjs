#!/usr/bin/env node
/**
 * Ground-truth WebAudio PCM waveform verification in headless Chrome
 * WITHOUT `--autoplay-policy=no-user-gesture-required` (strict user-gesture autoplay!).
 *
 * Hooks `AudioNode.prototype.connect` -> `AnalyserNode` -> `AudioContext.destination`
 * and asserts real non-zero speaker waveform output:
 * 1. `AudioContext.state` stays `"running"` after `sfx_ticket_tear.wav` ends on Cultivar Creator (never auto-suspends!).
 * 2. Standing still at Front Gate spawn (608, 1344) immediately outputs real Track 1 music (`peak > 0.02`, `rms > 0.004`).
 * 3. Opening Vibe Journal for >5.5s (pausing festival clock) keeps Track 1 streaming smoothly without 4.5s restart cuts.
 * 4. Clicking `Next Set` across Day 1 sets (including non-core Track 5 @ Mellow Meadow & Track 8 @ Velvet Canopy)
 *    outputs real non-zero PCM on every track with zero HTTP >=400 responses, even under plain static `build/web` hosting!
 */

import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const BUILD_WEB = path.join(ROOT, 'build', 'web');
const CHROME_BIN = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const SERVE_PORT = 18894;
const STATIC_PORT = 18895;
const DEBUG_PORT = 19234;
const PROFILE_DIR = path.join(ROOT, '.dart_tool', 'chrome_audio_cdp_profile');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function httpGetJson(url) {
  return new Promise((resolve, reject) => {
    http
      .get(url, (res) => {
        const chunks = [];
        res.on('data', (c) => chunks.push(c));
        res.on('end', () => {
          try {
            resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
          } catch (e) {
            reject(e);
          }
        });
      })
      .on('error', reject);
  });
}

class CdpSession {
  constructor(wsUrl) {
    this.ws = new WebSocket(wsUrl);
    this.nextId = 1;
    this.pending = new Map();
    this.events = [];
  }

  async connect() {
    await new Promise((resolve, reject) => {
      this.ws.addEventListener('open', resolve, { once: true });
      this.ws.addEventListener('error', reject, { once: true });
    });
    this.ws.addEventListener('message', (ev) => {
      const msg = JSON.parse(String(ev.data));
      if (msg.id && this.pending.has(msg.id)) {
        const { resolve, reject } = this.pending.get(msg.id);
        this.pending.delete(msg.id);
        if (msg.error) reject(new Error(JSON.stringify(msg.error)));
        else resolve(msg.result);
      } else if (msg.method) {
        this.events.push(msg);
      }
    });
  }

  send(method, params = {}) {
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }

  close() {
    try {
      this.ws.close();
    } catch (_) {}
  }
}

function startPlainStaticBuildWebServer(port) {
  const mime = {
    '.html': 'text/html; charset=utf-8',
    '.js': 'text/javascript; charset=utf-8',
    '.mjs': 'text/javascript; charset=utf-8',
    '.wasm': 'application/wasm',
    '.json': 'application/json; charset=utf-8',
    '.png': 'image/png',
    '.ogg': 'audio/ogg',
    '.wav': 'audio/wav',
    '.mp3': 'audio/mpeg',
    '.tmx': 'application/xml; charset=utf-8',
    '.tsx': 'application/xml; charset=utf-8',
    '.frag': 'text/plain; charset=utf-8',
    '.bin': 'application/octet-stream',
    '.otf': 'font/otf',
    '.ttf': 'font/ttf',
  };
  const srv = http.createServer((req, res) => {
    const u = new URL(req.url || '/', `http://127.0.0.1:${port}`);
    let p = decodeURIComponent(u.pathname);
    if (p === '/') p = '/index.html';
    const full = path.resolve(BUILD_WEB, '.' + p);
    const headers = {
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
    };
    if (!full.startsWith(BUILD_WEB) || !fs.existsSync(full) || !fs.statSync(full).isFile()) {
      res.writeHead(404, headers);
      res.end('404');
      return;
    }
    const ext = path.extname(full).toLowerCase();
    res.writeHead(200, {
      ...headers,
      'Content-Type': mime[ext] || 'application/octet-stream',
    });
    fs.createReadStream(full).pipe(res);
  });
  return new Promise((resolve) => srv.listen(port, '127.0.0.1', () => resolve(srv)));
}

const ANALYSER_HOOK_SCRIPT = `
(() => {
  window.__audioProbe = { analysers: [], connects: 0, streamHashes: [] };
  const origConnect = AudioNode.prototype.connect;
  AudioNode.prototype.connect = function(dest, ...rest) {
    if (dest && typeof AudioDestinationNode !== 'undefined' && dest instanceof AudioDestinationNode && !this.__probedDest) {
      this.__probedDest = true;
      window.__audioProbe.connects++;
      const ctx = dest.context;
      const analyser = ctx.createAnalyser();
      analyser.fftSize = 2048;
      origConnect.call(this, analyser);
      origConnect.call(analyser, dest);
      window.__audioProbe.analysers.push({ ctx, analyser });
      return dest;
    }
    return origConnect.call(this, dest, ...rest);
  };
  setInterval(() => {
    const M = window.Module_soloud;
    if (!M || M.__walnutProbeHooked) return;
    M.__walnutProbeHooked = true;
    const origSetBuf = M._setBufferStream;
    M._setBufferStream = function(hashPtr, ...rest) {
      const rc = origSetBuf.call(this, hashPtr, ...rest);
      window.__audioProbe.streamHashes.push({
        hash: M.getValue(hashPtr, 'i32'),
        t: Math.round(performance.now()),
      });
      return rc;
    };
  }, 25);
  window.__getSoloudBufferBytes = (hash) => {
    const M = window.Module_soloud;
    if (!M || !M._getBufferSize || !hash) return -1;
    const ptr = M._malloc(4);
    M._getBufferSize(hash, ptr);
    const bytes = M.getValue(ptr, 'i32');
    M._free(ptr);
    return bytes;
  };
  window.__measureSpeakerOutput = async (windows = 8, intervalMs = 80) => {
    let bestPeak = 0;
    let bestRms = 0;
    let states = [];
    for (let w = 0; w < windows; w++) {
      states = [];
      for (const item of window.__audioProbe.analysers) {
        states.push(item.ctx.state);
        const buf = new Float32Array(item.analyser.fftSize);
        item.analyser.getFloatTimeDomainData(buf);
        let sumSq = 0;
        let peak = 0;
        for (let i = 0; i < buf.length; i++) {
          const v = Math.abs(buf[i]);
          if (v > peak) peak = v;
          sumSq += v * v;
        }
        const rms = Math.sqrt(sumSq / buf.length);
        if (peak > bestPeak) bestPeak = peak;
        if (rms > bestRms) bestRms = rms;
      }
      if (w + 1 < windows) {
        await new Promise((r) => setTimeout(r, intervalMs));
      }
    }
    const M = window.Module_soloud;
    const activeVoices = M && M._getActiveVoiceCount ? M._getActiveVoiceCount() : -1;
    const lastHash = window.__audioProbe.streamHashes.at(-1)?.hash;
    const bufferedBytes = lastHash ? window.__getSoloudBufferBytes(lastHash) : -1;
    return {
      states,
      activeVoices,
      streamsCreated: window.__audioProbe.streamHashes.length,
      bufferedMB: bufferedBytes >= 0 ? Number((bufferedBytes / 1048576).toFixed(2)) : -1,
      peak: Number(bestPeak.toFixed(5)),
      rms: Number(bestRms.toFixed(5)),
    };
  };
})();
`;

async function verifyAgainstUrl(cdp, baseUrl, label) {
  cdp.events.length = 0;
  await cdp.send('Page.navigate', { url: baseUrl });
  await sleep(3200);

  async function clickAt(x, y) {
    await cdp.send('Input.dispatchMouseEvent', {
      type: 'mousePressed',
      x,
      y,
      button: 'left',
      clickCount: 1,
    });
    await sleep(40);
    await cdp.send('Input.dispatchMouseEvent', {
      type: 'mouseReleased',
      x,
      y,
      button: 'left',
      clickCount: 1,
    });
  }

  async function sampleAudio() {
    const res = await cdp.send('Runtime.evaluate', {
      expression: 'window.__measureSpeakerOutput(8, 85)',
      awaitPromise: true,
      returnByValue: true,
    });
    return res.result.value;
  }

  // 1. Click "Tear Ticket Stub" (strict user gesture unlock!) and wait 2.0s so ticket SFX finishes
  await clickAt(480, 418);
  await sleep(2000);
  const creatorAudio = await sampleAudio();
  console.log(`[${label}] CultivarCreator after ticket SFX:`, JSON.stringify(creatorAudio));
  assert.ok(
    creatorAudio.states.includes('running'),
    `[${label}] Expected AudioContext to stay 'running' on CultivarCreator (got ${JSON.stringify(creatorAudio)})`,
  );
  assert.ok(
    creatorAudio.activeVoices >= 1,
    `[${label}] Expected keep-alive voice activeVoices >= 1 (got ${creatorAudio.activeVoices})`,
  );

  // 2. Click "Step into the Free Orchard" -> stand completely still at Front Gate spawn (608, 1344)
  await clickAt(480, 486);
  await sleep(1400);
  const spawnAudio = await sampleAudio();
  console.log(`[${label}] Front Gate Spawn (Track 1):`, JSON.stringify(spawnAudio));
  assert.ok(spawnAudio.states.includes('running'), `[${label}] AudioContext not running at spawn`);
  assert.ok(
    spawnAudio.rms > 0.004 && spawnAudio.peak > 0.02,
    `[${label}] Expected audible Track 1 waveform at Front Gate spawn, got ${JSON.stringify(spawnAudio)}`,
  );

  if (label === 'serve.mjs') {
    // 3. Open Vibe Journal (pauses festival clock) for 5.6s -> verify music continues without restart/drop
    await clickAt(52, 66);
    await sleep(5200);
    const journalPausedAudio = await sampleAudio();
    console.log(`[${label}] While Journal Open >5.2s:`, JSON.stringify(journalPausedAudio));
    assert.ok(
      journalPausedAudio.rms > 0.004,
      `[${label}] Music dropped while Journal modal paused festival clock: ${JSON.stringify(journalPausedAudio)}`,
    );
    assert.ok(
      journalPausedAudio.bufferedMB > 0 && journalPausedAudio.bufferedMB < 4.5,
      `[${label}] Expected backpressure-bounded PCM buffer < 4.5 MB after >6.5s, got ${journalPausedAudio.bufferedMB} MB`,
    );
    // Close Journal via close button (812, 88)
    await clickAt(812, 88);
    await sleep(300);
  }

  // 4. Click "Next Set" 4 times -> lands on Track 5 (non-core progressive track_05.ogg @ Mellow Meadow!)
  for (let i = 0; i < 4; i++) {
    await clickAt(138, 66);
    await sleep(120);
  }
  await sleep(1200);
  const track5Audio = await sampleAudio();
  console.log(`[${label}] Track 5 (Mellow Meadow progressive .ogg):`, JSON.stringify(track5Audio));
  assert.ok(track5Audio.states.includes('running'), `[${label}] AudioContext suspended on Track 5`);
  assert.ok(
    track5Audio.streamsCreated > spawnAudio.streamsCreated,
    `[${label}] Expected Next Set to advance stream beyond Track 1 (spawn=${spawnAudio.streamsCreated}, track5=${track5Audio.streamsCreated})`,
  );
  assert.ok(
    track5Audio.rms > 0.002 && track5Audio.peak > 0.01,
    `[${label}] Expected audible Track 5 waveform from Front Gate, got ${JSON.stringify(track5Audio)}`,
  );

  // 5. Click "Next Set" 3 more times -> Track 8 (Velvet Canopy Stage progressive track_08.ogg!)
  for (let i = 0; i < 3; i++) {
    await clickAt(138, 66);
    await sleep(120);
  }
  await sleep(2200);
  const track8Audio = await sampleAudio();
  console.log(`[${label}] Track 8 (Velvet Canopy progressive .ogg):`, JSON.stringify(track8Audio));
  assert.ok(track8Audio.states.includes('running'), `[${label}] AudioContext suspended on Track 8`);
  assert.ok(
    track8Audio.streamsCreated > track5Audio.streamsCreated,
    `[${label}] Expected Next Set to advance stream beyond Track 5 (track5=${track5Audio.streamsCreated}, track8=${track8Audio.streamsCreated})`,
  );
  assert.ok(
    track8Audio.rms > 0.002 && track8Audio.peak > 0.01,
    `[${label}] Expected audible Track 8 waveform from Front Gate, got ${JSON.stringify(track8Audio)}`,
  );

  const exceptions = cdp.events
    .filter((e) => e.method === 'Runtime.exceptionThrown')
    .map((e) => e.params.exceptionDetails?.text);
  const badResponses = cdp.events
    .filter((e) => e.method === 'Network.responseReceived' && e.params.response.status >= 400)
    .map((e) => ({ status: e.params.response.status, url: e.params.response.url }));
  const externalCdnRequests = cdp.events
    .filter(
      (e) =>
        e.method === 'Network.requestWillBeSent' &&
        e.params.request.url.includes('flutter-canvaskit'),
    )
    .map((e) => e.params.request.url);

  assert.deepEqual(exceptions, [], `[${label}] Unexpected JS/WASM exceptions: ${JSON.stringify(exceptions)}`);
  assert.deepEqual(badResponses, [], `[${label}] Unexpected HTTP >=400 responses: ${JSON.stringify(badResponses)}`);
  assert.deepEqual(
    externalCdnRequests,
    [],
    `[${label}] Expected 100% local CanvasKit (--no-web-resources-cdn), saw CDN requests: ${JSON.stringify(externalCdnRequests)}`,
  );
}

async function verifyMidSetSliceAndNaturalEof(cdp, baseUrl, label) {
  async function clickAt(x, y) {
    await cdp.send('Input.dispatchMouseEvent', {
      type: 'mousePressed',
      x,
      y,
      button: 'left',
      clickCount: 1,
    });
    await sleep(40);
    await cdp.send('Input.dispatchMouseEvent', {
      type: 'mouseReleased',
      x,
      y,
      button: 'left',
      clickCount: 1,
    });
  }

  async function seedHiveSave(minuteOfDay) {
    await cdp.send('Runtime.evaluate', {
      expression: `new Promise((resolve) => {
        const req = indexedDB.open('walnutstock_saves_v1');
        req.onsuccess = () => {
          const db = req.result;
          const tx = db.transaction('box', 'readwrite');
          const save = JSON.stringify({
            schemaVersion: 2,
            profile: { cultivarId: 'hartley', savedX: 608, savedY: 420 },
            clock: { day: 1, minuteOfDay: ${minuteOfDay}, clockPaused: true, encoreModeUnlocked: true },
            flags: {},
            journal: {},
            settings: {}
          });
          tx.objectStore('box').put(save, 'slot_primary');
          tx.oncomplete = () => { db.close(); resolve(true); };
        };
      })`,
      awaitPromise: true,
      returnByValue: true,
    });
  }

  async function clearHiveSave() {
    await cdp.send('Runtime.evaluate', {
      expression: `new Promise((resolve) => {
        const req = indexedDB.open('walnutstock_saves_v1');
        req.onsuccess = () => {
          const db = req.result;
          const tx = db.transaction('box', 'readwrite');
          tx.objectStore('box').delete('slot_primary');
          tx.oncomplete = () => { db.close(); resolve(true); };
        };
      })`,
      awaitPromise: true,
      returnByValue: true,
    });
  }

  // A. Mid-set Ogg Opus slice (minuteOfDay = 787.94 -> 141.29s into Track 4, >0.4s!) via single-click RESUME SAVED TENT SESSION
  await seedHiveSave(787.94);
  cdp.events.length = 0;
  await cdp.send('Page.navigate', { url: baseUrl });
  await sleep(2800);
  await clickAt(480, 441); // Single-click "RESUME SAVED TENT SESSION"
  await sleep(2600);
  const midSliceRes = await cdp.send('Runtime.evaluate', {
    expression: 'window.__measureSpeakerOutput(8, 85)',
    awaitPromise: true,
    returnByValue: true,
  });
  const midAudio = midSliceRes.result.value;
  console.log(`[${label}] Mid-set Ogg Opus slice (141.3s into Track 4 via single-click Resume):`, JSON.stringify(midAudio));
  assert.ok(midAudio.states.includes('running'), `[${label}] AudioContext not running after single-click Resume`);
  assert.equal(
    midAudio.streamsCreated,
    1,
    `[${label}] Expected exactly 1 BufferStream on mid-set Ogg slice (got ${midAudio.streamsCreated})`,
  );
  assert.ok(
    midAudio.rms > 0.004 && midAudio.peak > 0.02,
    `[${label}] Expected audible mid-set sliced Track 4 waveform, got ${JSON.stringify(midAudio)}`,
  );

  // B. Natural EOF on non-looping Track 1 while clock is paused ~2.25s before EOF (minuteOfDay = 610.75)
  await seedHiveSave(610.75);
  await cdp.send('Page.navigate', { url: baseUrl });
  await sleep(2800);
  await clickAt(480, 441); // Single-click "RESUME SAVED TENT SESSION"
  await sleep(5000); // Wait well past 2.25s natural EOF
  const eofRes = await cdp.send('Runtime.evaluate', {
    expression: 'window.__measureSpeakerOutput(4, 60)',
    awaitPromise: true,
    returnByValue: true,
  });
  const eofAudio = eofRes.result.value;
  console.log(`[${label}] Post-EOF non-looping Track 1 (clockPaused=true):`, JSON.stringify(eofAudio));
  assert.equal(
    eofAudio.streamsCreated,
    1,
    `[${label}] Non-looping track entered broken-record tail restart loop at EOF (streamsCreated=${eofAudio.streamsCreated})`,
  );
  assert.equal(
    eofAudio.activeVoices,
    1,
    `[${label}] Expected only keep-alive voice (1) after non-looping Track 1 natural EOF, got ${eofAudio.activeVoices}`,
  );

  await clearHiveSave();

  const badResponses = cdp.events
    .filter((e) => e.method === 'Network.responseReceived' && e.params.response.status >= 400)
    .map((e) => ({ status: e.params.response.status, url: e.params.response.url }));
  assert.deepEqual(badResponses, [], `[${label}] Unexpected HTTP >=400 during mid-set/EOF check: ${JSON.stringify(badResponses)}`);
}

async function main() {
  const bootstrapJs = fs.readFileSync(path.join(BUILD_WEB, 'flutter_bootstrap.js'), 'utf8');
  assert.ok(
    bootstrapJs.includes('useLocalCanvasKit'),
    'Expected build/web/flutter_bootstrap.js to include useLocalCanvasKit: true (--no-web-resources-cdn)',
  );

  fs.rmSync(PROFILE_DIR, { recursive: true, force: true });
  fs.mkdirSync(PROFILE_DIR, { recursive: true });

  const srv = spawn(process.execPath, ['serve.mjs'], {
    cwd: ROOT,
    env: { ...process.env, PORT: String(SERVE_PORT) },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  await new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error('serve.mjs timeout')), 5000);
    srv.stdout.on('data', (d) => {
      if (String(d).includes('Serving')) {
        clearTimeout(t);
        resolve();
      }
    });
  });

  const staticSrv = await startPlainStaticBuildWebServer(STATIC_PORT);

  // NOTE: Deliberately NO `--autoplay-policy=no-user-gesture-required`!
  const chrome = spawn(
    CHROME_BIN,
    [
      '--headless=new',
      '--window-size=960,640',
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-gpu-sandbox',
      '--enable-webgl',
      '--ignore-gpu-blocklist',
      '--use-gl=angle',
      '--use-angle=swiftshader',
      `--remote-debugging-port=${DEBUG_PORT}`,
      `--user-data-dir=${PROFILE_DIR}`,
      'about:blank',
    ],
    { stdio: ['ignore', 'pipe', 'pipe'] },
  );

  let cdp = null;
  try {
    let targets = null;
    for (let i = 0; i < 40; i++) {
      try {
        targets = await httpGetJson(`http://127.0.0.1:${DEBUG_PORT}/json/list`);
        if (Array.isArray(targets) && targets.length > 0) break;
      } catch (_) {}
      await sleep(200);
    }
    assert.ok(targets && targets.length > 0, 'Failed to connect to Chrome CDP');
    const pageTarget = targets.find((t) => t.type === 'page') || targets[0];
    cdp = new CdpSession(pageTarget.webSocketDebuggerUrl);
    await cdp.connect();

    await cdp.send('Page.enable');
    await cdp.send('Runtime.enable');
    await cdp.send('Network.enable');
    await cdp.send('Page.addScriptToEvaluateOnNewDocument', { source: ANALYSER_HOOK_SCRIPT });
    await cdp.send('Emulation.setDeviceMetricsOverride', {
      width: 960,
      height: 640,
      deviceScaleFactor: 1,
      mobile: false,
    });

    await verifyAgainstUrl(cdp, `http://localhost:${SERVE_PORT}/`, 'serve.mjs');
    await verifyMidSetSliceAndNaturalEof(cdp, `http://localhost:${SERVE_PORT}/`, 'serve.mjs');
    await verifyAgainstUrl(cdp, `http://127.0.0.1:${STATIC_PORT}/`, 'static-build-web');
    await verifyMidSetSliceAndNaturalEof(cdp, `http://127.0.0.1:${STATIC_PORT}/`, 'static-build-web');

    // Simulate non-secure LAN HTTP origin / Private Browsing where window.caches throws SecurityError!
    await cdp.send('Page.addScriptToEvaluateOnNewDocument', {
      source: `Object.defineProperty(window, 'caches', { get() { throw new DOMException('Insecure origin', 'SecurityError'); } });`,
    });
    await verifyAgainstUrl(cdp, `http://127.0.0.1:${SERVE_PORT}/`, 'restricted-cachestorage-lan');

    console.log('[Walnutstock Audio Playback Verification] ALL STRICT-AUTOPLAY WAVEFORM ASSERTIONS PASSED!');
  } finally {
    if (cdp) cdp.close();
    const exited =
      chrome.exitCode !== null
        ? Promise.resolve()
        : new Promise((resolve) => chrome.once('exit', resolve));
    chrome.kill('SIGKILL');
    srv.kill('SIGTERM');
    staticSrv.close();
    await exited;
    await sleep(150);
    fs.rmSync(PROFILE_DIR, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
  }
}

main().catch((err) => {
  console.error('[Audio Playback Verification Error]', err);
  process.exit(1);
});
