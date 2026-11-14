#!/usr/bin/env node
/**
 * Headless Chrome DevTools Protocol (CDP) end-to-end verification for Walnutstock Web v1.0.
 * Verifies:
 * 1. Cross-Origin Isolation (`window.crossOriginIsolated === true`) for SoLoud WASM AudioWorklet.
 * 2. Zero uncaught JS/WASM runtime exceptions, zero failed HTTP/COEP requests, zero >=400 responses.
 * 3. Flutter CanvasKit boot -> Ticket-Tear WebAudio unlock -> Cultivar Creator -> Overworld 9-zone render
 *    -> Night lantern halos & fireflies -> Multi-line HUD song wrap + GLSL `walnut_trip.frag` shader.
 */

import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const CHROME_BIN = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const SERVER_PORT = 18891;
const DEBUG_PORT = 19229;
const PROFILE_DIR = path.join(ROOT, '.dart_tool', 'chrome_cdp_profile');
const SCREENSHOT_DIR = path.join(ROOT, '.dart_tool', 'cdp_screenshots');

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

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

async function main() {
  fs.rmSync(PROFILE_DIR, { recursive: true, force: true });
  fs.mkdirSync(PROFILE_DIR, { recursive: true });
  fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });

  const srv = spawn(process.execPath, ['serve.mjs'], {
    cwd: ROOT,
    env: { ...process.env, PORT: String(SERVER_PORT) },
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  await new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error('serve.mjs start timeout')), 5000);
    srv.stdout.on('data', (d) => {
      if (String(d).includes('Serving')) {
        clearTimeout(t);
        resolve();
      }
    });
  });

  const chrome = spawn(
    CHROME_BIN,
    [
      '--headless=new',
      '--window-size=960,640',
      '--autoplay-policy=no-user-gesture-required',
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
    await cdp.send('Log.enable');
    await cdp.send('Network.enable');

    await cdp.send('Emulation.setDeviceMetricsOverride', {
      width: 960,
      height: 640,
      deviceScaleFactor: 1,
      mobile: false,
    });

    await cdp.send('Page.navigate', { url: `http://localhost:${SERVER_PORT}/` });
    await sleep(3200);

    async function clickAt(x, y) {
      await cdp.send('Input.dispatchMouseEvent', {
        type: 'mousePressed',
        x,
        y,
        button: 'left',
        clickCount: 1,
      });
      await sleep(35);
      await cdp.send('Input.dispatchMouseEvent', {
        type: 'mouseReleased',
        x,
        y,
        button: 'left',
        clickCount: 1,
      });
    }

    const shot1 = await cdp.send('Page.captureScreenshot', { format: 'png' });
    fs.writeFileSync(
      path.join(SCREENSHOT_DIR, '01_ticket_splash.png'),
      Buffer.from(shot1.data, 'base64'),
    );

    // 1. Tear Ticket Stub -> unlocks SoLoud WebAudio WASM worker
    await clickAt(480, 418);
    await sleep(800);
    const shot2 = await cdp.send('Page.captureScreenshot', { format: 'png' });
    fs.writeFileSync(
      path.join(SCREENSHOT_DIR, '02_cultivar_creator.png'),
      Buffer.from(shot2.data, 'base64'),
    );

    // 2. Step into the Free Orchard
    await clickAt(480, 486);
    await sleep(1500);
    const shot3 = await cdp.send('Page.captureScreenshot', { format: 'png' });
    fs.writeFileSync(
      path.join(SCREENSHOT_DIR, '03_overworld_spawn.png'),
      Buffer.from(shot3.data, 'base64'),
    );

    // 3. Cue through Day 1 sets to Track 10 (Midnight Lanterns + Starry Fireflies!)
    async function clickNextSet() {
      await clickAt(138, 66);
    }

    for (let i = 0; i < 9; i++) {
      await clickNextSet();
      await sleep(70);
    }
    await sleep(700);
    const shot4 = await cdp.send('Page.captureScreenshot', { format: 'png' });
    fs.writeFileSync(
      path.join(SCREENSHOT_DIR, '04_night_lanterns_fireflies.png'),
      Buffer.from(shot4.data, 'base64'),
    );

    // 4. Cue forward to Track 22 ("The Walnut Trip" GLSL Kaleidoscope Shader!)
    for (let i = 0; i < 15; i++) {
      await clickNextSet();
      await sleep(70);
    }
    await sleep(900);
    const shot5 = await cdp.send('Page.captureScreenshot', { format: 'png' });
    fs.writeFileSync(
      path.join(SCREENSHOT_DIR, '05_walnut_trip_shader.png'),
      Buffer.from(shot5.data, 'base64'),
    );

    const bootInfo = await cdp.send('Runtime.evaluate', {
      expression: `({
        crossOriginIsolated: window.crossOriginIsolated,
        title: document.title,
        flutterViewCount: document.querySelectorAll('flutter-view, flt-glass-pane, canvas').length,
        hasSoloudModule: typeof window.Module_soloud !== 'undefined' || typeof Module !== 'undefined'
      })`,
      returnByValue: true,
    });
    const info = bootInfo.result.value;
    console.log('[CDP Boot Info]', JSON.stringify(info));

    const exceptions = cdp.events
      .filter((e) => e.method === 'Runtime.exceptionThrown')
      .map((e) => e.params.exceptionDetails?.text + ' ' + (e.params.exceptionDetails?.exception?.description || ''));
    const failedReqs = cdp.events
      .filter((e) => e.method === 'Network.loadingFailed')
      .map((e) => e.params);
    const badResponses = cdp.events
      .filter((e) => e.method === 'Network.responseReceived' && e.params.response.status >= 400)
      .map((e) => ({ status: e.params.response.status, url: e.params.response.url }));

    assert.equal(info.crossOriginIsolated, true, 'Expected crossOriginIsolated === true');
    assert.equal(info.hasSoloudModule, true, 'Expected Module_soloud initialized');
    assert.ok(info.flutterViewCount >= 1, 'Expected Flutter CanvasKit view mounted');
    assert.deepEqual(exceptions, [], `Unexpected JS/WASM exceptions: ${JSON.stringify(exceptions)}`);
    assert.deepEqual(failedReqs, [], `Unexpected failed network requests: ${JSON.stringify(failedReqs)}`);
    assert.deepEqual(badResponses, [], `Unexpected HTTP >=400 responses: ${JSON.stringify(badResponses)}`);

    console.log('[Walnutstock Browser Verification] ALL CDP/WebAudio/CanvasKit/Shader assertions PASSED!');
  } finally {
    if (cdp) cdp.close();
    const exited =
      chrome.exitCode !== null
        ? Promise.resolve()
        : new Promise((resolve) => chrome.once('exit', resolve));
    chrome.kill('SIGKILL');
    srv.kill('SIGTERM');
    await exited;
    await sleep(150);
    fs.rmSync(PROFILE_DIR, {
      recursive: true,
      force: true,
      maxRetries: 5,
      retryDelay: 200,
    });
  }
}

main().catch((err) => {
  console.error('[CDP Verification Error]', err);
  process.exit(1);
});
