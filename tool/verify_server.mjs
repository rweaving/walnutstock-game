#!/usr/bin/env node
/**
 * Integration test for serve.mjs:
 * Verifies COOP/COEP headers, 206 Partial Content byte-range seeking,
 * 404 on missing static/media files, 416 on out-of-range, and 200 SPA fallback on extensionless routes.
 */

import http from 'node:http';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const TEST_PORT = 18942;

function httpGet(urlPath, headers = {}) {
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        hostname: '127.0.0.1',
        port: TEST_PORT,
        path: urlPath,
        method: 'GET',
        headers,
      },
      (res) => {
        const chunks = [];
        res.on('data', (c) => chunks.push(c));
        res.on('end', () => {
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            body: Buffer.concat(chunks),
          });
        });
      },
    );
    req.on('error', reject);
    req.end();
  });
}

async function main() {
  const proc = spawn(process.execPath, [path.join(ROOT, 'serve.mjs')], {
    env: { ...process.env, PORT: String(TEST_PORT) },
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('serve.mjs startup timeout')), 5000);
    proc.stdout.on('data', (d) => {
      if (d.toString().includes('Serving')) {
        clearTimeout(timer);
        resolve();
      }
    });
  });

  try {
    // 1. Root index.html + COOP/COEP multi-threaded WASM headers
    const rootResp = await httpGet('/');
    assert.equal(rootResp.statusCode, 200);
    assert.equal(rootResp.headers['cross-origin-opener-policy'], 'same-origin');
    assert.equal(rootResp.headers['cross-origin-embedder-policy'], 'require-corp');
    assert.ok(rootResp.body.toString('utf8').includes('Walnutstock'));

    // 2. Compiled Flutter Web bundle + SoLoud WASM loader + Opus track 26 & Midnight bonus stems
    const mainJs = await httpGet('/main.dart.js');
    assert.equal(mainJs.statusCode, 200);
    assert.ok(mainJs.body.length > 500000);

    const soloudPluginJs = await httpGet('/assets/packages/flutter_soloud/web/libflutter_soloud_plugin.js');
    assert.equal(soloudPluginJs.statusCode, 200);
    const soloudInitModuleJs = await httpGet('/assets/packages/flutter_soloud/web/init_module.dart.js');
    assert.equal(soloudInitModuleJs.statusCode, 200);
    const soloudWasm = await httpGet('/assets/packages/flutter_soloud/web/libflutter_soloud_plugin.wasm');
    assert.equal(soloudWasm.statusCode, 200);

    const opus26 = await httpGet('/audio/tracks/track_26.ogg', {
      Range: 'bytes=0-1023',
    });
    assert.equal(opus26.statusCode, 206);
    assert.equal(opus26.body.length, 1024);

    const midnightStem = await httpGet('/audio/tracks/track_27_dembow.ogg', {
      Range: 'bytes=0-511',
    });
    assert.equal(midnightStem.statusCode, 206);

    // 3. HTTP 206 Partial Content byte-range seeking on .m4a & .mp3
    const rangeResp = await httpGet('/audio/tracks/track_01.m4a', {
      Range: 'bytes=100-611',
    });
    assert.equal(rangeResp.statusCode, 206);
    assert.equal(rangeResp.body.length, 512);
    assert.match(rangeResp.headers['content-range'] || '', /^bytes 100-611\/\d+$/);

    // 3. Out-of-bounds Range -> 416 Range Not Satisfiable
    const badRange = await httpGet('/audio/tracks/track_01.m4a', {
      Range: 'bytes=999999999-9999999999',
    });
    assert.equal(badRange.statusCode, 416);

    // 4. Missing static/audio files MUST return 404 (fixes v0.1.0 index.html 200 bug!)
    const missingAudio = await httpGet('/audio/tracks/nonexistent_999.ogg');
    assert.equal(missingAudio.statusCode, 404);
    const missingPng = await httpGet('/assets/images/does_not_exist.png');
    assert.equal(missingPng.statusCode, 404);

    // 5. Extensionless client navigation route -> 200 SPA index.html fallback
    const spaRoute = await httpGet('/free-orchard/encore');
    assert.equal(spaRoute.statusCode, 200);
    assert.ok(spaRoute.body.toString('utf8').includes('<!DOCTYPE html>'));

    console.log('[Walnutstock Server Verification] ALL 5 HTTP/COOP/COEP/206/404 assertions PASSED!');
  } finally {
    proc.kill('SIGTERM');
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
