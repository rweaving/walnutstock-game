import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('caches')
external _JsCacheStorage? get _windowCaches;

@JS('fetch')
external JSPromise<_JsResponse> _windowFetch(JSString url);

@JS('walnutResumeAudioContexts')
external JSFunction? get _walnutResumeAudioContextsFn;

@JS('walnutIsSoloudWasmReady')
external JSFunction? get _walnutIsSoloudWasmReadyFn;

@JS('Module_soloud')
external JSAny? get _windowModuleSoloud;

extension type _JsSoloudModule._(JSObject _) implements JSObject {
  @JS('_isInited')
  external JSAny? get isInitedFn;
}

extension type _JsCacheStorage._(JSObject _) implements JSObject {
  external JSPromise<_JsCache> open(JSString cacheName);
}

extension type _JsCache._(JSObject _) implements JSObject {
  external JSPromise<_JsResponse?> match(JSString requestUrl);
  external JSPromise<JSAny?> put(JSString requestUrl, _JsResponse response);
}

extension type _JsResponse._(JSObject _) implements JSObject {
  external bool get ok;
  external _JsResponse clone();
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

const String _audioCacheName = 'walnutstock-audio-v1';

bool _isSoloudWasmLoaded() {
  try {
    final helper = _walnutIsSoloudWasmReadyFn;
    if (helper != null) {
      final res = helper.callAsFunction();
      if (res != null && res.typeofEquals('boolean')) {
        return (res as JSBoolean).toDart;
      }
    }
    final mod = _windowModuleSoloud;
    if (mod != null && mod.typeofEquals('object')) {
      final typed = mod as _JsSoloudModule;
      return typed.isInitedFn != null &&
          typed.isInitedFn!.typeofEquals('function');
    }
  } catch (_) {}
  return false;
}

Future<void> ensureWebAudioUnlockedAndReady() async {
  try {
    _walnutResumeAudioContextsFn?.callAsFunction();
  } catch (_) {}

  // Wait up to ~4s if libflutter_soloud_plugin.wasm is still finishing instantiation
  for (var i = 0; i < 100; i++) {
    if (_isSoloudWasmLoaded()) break;
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }

  try {
    _walnutResumeAudioContextsFn?.callAsFunction();
  } catch (_) {}
}

Future<String> detectPreferredTrackExtension() async {
  // SoLoud's WASM engine embeds libopus/stb_vorbis and decodes Ogg Opus (.ogg)
  // across Chrome, Safari, Firefox, and Edge without relying on <audio> codecs.
  return 'ogg';
}

List<String> _candidateTrackUrls(String primaryUrl) {
  final candidates = <String>[primaryUrl];
  if (primaryUrl.startsWith('assets/assets/audio/tracks/')) {
    final rel = primaryUrl.substring('assets/assets/'.length);
    candidates.add(rel); // 'audio/tracks/...'
  } else if (primaryUrl.startsWith('audio/tracks/')) {
    candidates.add('assets/assets/$primaryUrl');
  } else if (primaryUrl.startsWith('assets/audio/tracks/')) {
    candidates.add('assets/$primaryUrl');
    candidates.add(primaryUrl.substring('assets/'.length));
  }
  return candidates;
}

Future<String?> cacheTrackProgressive(String trackId, String ext) async {
  final url = 'assets/assets/audio/tracks/$trackId.$ext';
  try {
    final caches = _windowCaches;
    if (caches == null) return url;
    final jsUrl = url.toJS;
    final cache = await caches.open(_audioCacheName.toJS).toDart;
    final hit = await cache.match(jsUrl).toDart;
    if (hit == null) {
      final resp = await _windowFetch(jsUrl).toDart;
      if (resp.ok) {
        await cache.put(jsUrl, resp.clone()).toDart;
      }
    }
  } catch (_) {
    // Non-fatal in Private Browsing or non-HTTPS LAN origins where CacheStorage is restricted
  }
  return url;
}

Future<Uint8List?> fetchCachedWebAudioBytes(String url) async {
  for (final candidate in _candidateTrackUrls(url)) {
    final jsUrl = candidate.toJS;
    _JsCache? openedCache;

    // 1. Optional CacheStorage lookup (isolated so SecurityError/QuotaError never blocks fetch!)
    try {
      final caches = _windowCaches;
      if (caches != null) {
        openedCache = await caches.open(_audioCacheName.toJS).toDart;
        final hit = await openedCache.match(jsUrl).toDart;
        if (hit != null) {
          final buf = await hit.arrayBuffer().toDart;
          final bytes = buf.toDart.asUint8List();
          if (bytes.isNotEmpty) return bytes;
        }
      }
    } catch (_) {
      openedCache = null;
    }

    // 2. Direct network fetch (always attempted even when CacheStorage is unavailable)
    try {
      final resp = await _windowFetch(jsUrl).toDart;
      if (!resp.ok) continue;
      if (openedCache != null) {
        try {
          await openedCache.put(jsUrl, resp.clone()).toDart;
        } catch (_) {}
      }
      final buf = await resp.arrayBuffer().toDart;
      final bytes = buf.toDart.asUint8List();
      if (bytes.isNotEmpty) return bytes;
    } catch (_) {}
  }
  return null;
}
