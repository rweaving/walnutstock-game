#!/usr/bin/env node
/**
 * Walnutstock v1.0 Flutter Web + Spatial Audio Preview Server
 * - Serves build/web (automatically falling back to project root before first build)
 * - Streams progressive soundtrack files (.ogg Opus, .m4a AAC, .mp3) from assets/audio/tracks
 * - Sets COOP/COEP headers so SoLoud loads multi-threaded WASM AudioWorklet cleanly
 * - Full HTTP Byte-Range (206 Partial Content) support for instant live-concert seeking
 * - Strict 404 responses for missing static/media files (SPA fallback only for extensionless routes)
 */

import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BUILD_WEB_ROOT = path.join(__dirname, 'build', 'web');
const TRACKS_MEDIA_ROOT = path.join(__dirname, 'assets', 'audio', 'tracks');
const PORT = Number(process.env.PORT || 8080);

function getActiveWebRoot() {
  if (fs.existsSync(path.join(BUILD_WEB_ROOT, 'index.html'))) {
    return BUILD_WEB_ROOT;
  }
  return __dirname;
}

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.wasm': 'application/wasm',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.mp3': 'audio/mpeg',
  '.wav': 'audio/wav',
  '.ogg': 'audio/ogg',
  '.opus': 'audio/ogg; codecs=opus',
  '.m4a': 'audio/mp4',
  '.tmx': 'application/xml; charset=utf-8',
  '.tsx': 'application/xml; charset=utf-8',
  '.frag': 'text/plain; charset=utf-8',
  '.bin': 'application/octet-stream',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff2': 'font/woff2',
};

const COMMON_HEADERS = {
  'Cross-Origin-Opener-Policy': 'same-origin',
  'Cross-Origin-Embedder-Policy': 'require-corp',
  'Cross-Origin-Resource-Policy': 'cross-origin',
  'Access-Control-Allow-Origin': '*',
  'Accept-Ranges': 'bytes',
  'Cache-Control': 'no-cache',
};

function resolveTargetFile(decodedPath, webRoot) {
  // Progressive track streaming route: /audio/tracks/<filename> or /assets/assets/audio/tracks/<filename>
  const audioPrefixes = ['/audio/tracks/', '/assets/assets/audio/tracks/', '/assets/audio/tracks/'];
  for (const prefix of audioPrefixes) {
    if (decodedPath.startsWith(prefix)) {
      const relName = decodedPath.slice(prefix.length);
      // Check webRoot first, then fallback to TRACKS_MEDIA_ROOT
      const inWebRoot = path.resolve(webRoot, '.' + decodedPath);
      if (inWebRoot.startsWith(webRoot) && fs.existsSync(inWebRoot) && fs.statSync(inWebRoot).isFile()) {
        return { status: 'ok', filePath: inWebRoot };
      }
      const inMediaRoot = path.resolve(TRACKS_MEDIA_ROOT, relName);
      if (!inMediaRoot.startsWith(TRACKS_MEDIA_ROOT)) {
        return { status: 'forbidden' };
      }
      if (fs.existsSync(inMediaRoot) && fs.statSync(inMediaRoot).isFile()) {
        return { status: 'ok', filePath: inMediaRoot };
      }
      return { status: 'not_found' };
    }
  }

  const candidate = path.resolve(webRoot, '.' + decodedPath);
  if (!candidate.startsWith(webRoot)) {
    return { status: 'forbidden' };
  }
  if (fs.existsSync(candidate) && fs.statSync(candidate).isFile()) {
    return { status: 'ok', filePath: candidate };
  }

  // Only allow SPA fallback to index.html for extensionless navigation routes
  const ext = path.extname(decodedPath);
  if (ext === '') {
    const indexHtml = path.join(webRoot, 'index.html');
    if (fs.existsSync(indexHtml)) {
      return { status: 'ok', filePath: indexHtml };
    }
  }
  return { status: 'not_found' };
}

const server = http.createServer((req, res) => {
  try {
    if (req.method === 'OPTIONS') {
      res.writeHead(204, COMMON_HEADERS);
      res.end();
      return;
    }

    const webRoot = getActiveWebRoot();
    const reqUrl = new URL(req.url || '/', `http://localhost:${PORT}`);
    let decodedPath = decodeURIComponent(reqUrl.pathname);
    if (decodedPath === '/') decodedPath = '/index.html';

    const resolved = resolveTargetFile(decodedPath, webRoot);
    if (resolved.status === 'forbidden') {
      res.writeHead(403, COMMON_HEADERS);
      res.end('403 Forbidden');
      return;
    }
    if (resolved.status === 'not_found') {
      res.writeHead(404, {
        ...COMMON_HEADERS,
        'Content-Type': 'text/plain; charset=utf-8',
      });
      res.end(`404 Not Found: ${decodedPath}`);
      return;
    }

    const target = resolved.filePath;
    const stat = fs.statSync(target);
    const ext = path.extname(target).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';
    const range = req.headers.range;

    if (range) {
      const match = /bytes=(\d*)-(\d*)/.exec(range);
      if (match) {
        const start = match[1] ? parseInt(match[1], 10) : 0;
        const end = match[2] ? Math.min(parseInt(match[2], 10), stat.size - 1) : stat.size - 1;
        if (start >= 0 && start <= end && start < stat.size) {
          res.writeHead(206, {
            ...COMMON_HEADERS,
            'Content-Type': contentType,
            'Content-Range': `bytes ${start}-${end}/${stat.size}`,
            'Content-Length': String(end - start + 1),
          });
          if (req.method === 'HEAD') {
            res.end();
          } else {
            fs.createReadStream(target, { start, end }).pipe(res);
          }
          return;
        }
        res.writeHead(416, {
          ...COMMON_HEADERS,
          'Content-Range': `bytes */${stat.size}`,
        });
        res.end();
        return;
      }
    }

    res.writeHead(200, {
      ...COMMON_HEADERS,
      'Content-Type': contentType,
      'Content-Length': String(stat.size),
    });
    if (req.method === 'HEAD') {
      res.end();
    } else {
      fs.createReadStream(target).pipe(res);
    }
  } catch (err) {
    res.writeHead(500, COMMON_HEADERS);
    res.end(String(err));
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[Walnutstock Web v1.0] Serving ${getActiveWebRoot()} at http://localhost:${PORT}`);
});
