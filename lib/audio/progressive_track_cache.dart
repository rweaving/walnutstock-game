import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/models.dart';
import 'platform_audio_probe.dart';

class ResolvedAudioTarget {
  const ResolvedAudioTarget({
    required this.uriOrPath,
    required this.isBundledFlutterAsset,
  });

  final String uriOrPath;
  final bool isBundledFlutterAsset;
}

class ProgressiveTrackCache {
  ProgressiveTrackCache();

  String _preferredExt = 'ogg';
  bool _initialized = false;
  bool _disposed = false;
  bool _prefetchRunning = false;
  final Map<String, String> _cachedPaths = {};

  String get preferredExtension => _preferredExt;

  Future<void> initialize() async {
    if (_initialized) return;
    _preferredExt = await detectPreferredTrackExtension();
    _initialized = true;
  }

  ResolvedAudioTarget resolveTrack(ScheduledTrack track) {
    if (track.assetPath.endsWith('.wav')) {
      return ResolvedAudioTarget(
        uriOrPath: track.assetPath,
        isBundledFlutterAsset: true,
      );
    }

    // Core Day 1 startup tracks 1..4 in Opus (.ogg) are bundled inside the <15MB core package
    if (track.bundledInCore && _preferredExt == 'ogg') {
      return ResolvedAudioTarget(
        uriOrPath: 'assets/audio/tracks/${track.id}.ogg',
        isBundledFlutterAsset: true,
      );
    }

    final cached = _cachedPaths[track.id];
    if (cached != null) {
      return ResolvedAudioTarget(
        uriOrPath: cached,
        isBundledFlutterAsset: false,
      );
    }

    if (kIsWeb) {
      return ResolvedAudioTarget(
        uriOrPath: 'assets/assets/audio/tracks/${track.id}.$_preferredExt',
        isBundledFlutterAsset: false,
      );
    }

    return ResolvedAudioTarget(
      uriOrPath: 'assets/audio/tracks/${track.id}.$_preferredExt',
      isBundledFlutterAsset: false,
    );
  }

  /// Background rolling-window pre-fetcher ordered chronologically from the
  /// guest's current festival position. Limits background downloads to the
  /// immediate active + upcoming sets (`maxTracksToPrefetch`) so mobile cellular
  /// visitors don't download ~74 MB of audio upfront.
  void startBackgroundPrefetch(
    SetlistCatalog catalog, {
    required int currentDay,
    double currentMinute = 0.0,
    int maxTracksToPrefetch = 2,
  }) {
    if (_prefetchRunning || _disposed) return;
    unawaited(
      _runSequentialPrefetch(
        catalog,
        currentDay,
        currentMinute,
        maxTracksToPrefetch,
      ),
    );
  }

  Future<void> _runSequentialPrefetch(
    SetlistCatalog catalog,
    int startDay,
    double startMinute,
    int maxTracksToPrefetch,
  ) async {
    _prefetchRunning = true;
    try {
      await initialize();
      double offsetMinutes(ScheduledTrack t) {
        var dayDiff = t.day - startDay;
        if (dayDiff < 0 || (dayDiff == 0 && t.endMinute < startMinute)) {
          dayDiff += 3;
        }
        return dayDiff * 1440.0 + (t.startMinute - startMinute);
      }

      final ordered = [...catalog.tracks]
        ..sort((a, b) => offsetMinutes(a).compareTo(offsetMinutes(b)));

      var prefetchedCount = 0;
      for (final track in ordered) {
        if (_disposed || prefetchedCount >= maxTracksToPrefetch) return;
        if (track.assetPath.endsWith('.wav')) continue;
        if (track.bundledInCore && _preferredExt == 'ogg') continue;
        if (_cachedPaths.containsKey(track.id)) continue;

        final result = await cacheTrackProgressive(track.id, _preferredExt);
        if (result != null) {
          _cachedPaths[track.id] = result;
        }
        prefetchedCount++;
        // Yield gently between tracks so gameplay & active streaming stay silky smooth
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    } finally {
      _prefetchRunning = false;
    }
  }

  void dispose() {
    _disposed = true;
  }
}
