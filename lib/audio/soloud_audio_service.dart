import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'fft_analyzer.dart';
import 'ogg_opus_slicer.dart';
import 'platform_audio_probe.dart';
import 'progressive_track_cache.dart';

abstract class SoloudBackend {
  bool get isInitialized;

  Future<void> init({
    required int sampleRate,
    required int bufferSize,
    required Channels channels,
  });

  void configureGlobalBiquad({
    required double resonance,
    required double wet,
  });

  void updateGlobalBiquad({required double cutoffHz});

  bool getIsValidVoiceHandle(SoundHandle handle);

  void setProtectVoice(SoundHandle handle, bool protect);

  void setVolume(SoundHandle handle, double volume);

  void setPan(SoundHandle handle, double pan);

  void seek(SoundHandle handle, Duration position);

  Future<AudioSource> loadMem(String name, Uint8List bytes);

  Future<AudioSource> loadAsset(String path, {required LoadMode mode});

  Future<AudioSource> loadUrl(String url, {required LoadMode mode});

  Future<AudioSource> loadFile(String path, {required LoadMode mode});

  AudioSource setBufferStream({
    required int maxBufferSizeBytes,
    required BufferingType bufferingType,
    required double bufferingTimeNeeds,
    required int sampleRate,
    required Channels channels,
    required BufferType format,
  });

  void addAudioDataStream(AudioSource source, Uint8List chunk);

  void setDataIsEnded(AudioSource source);

  int getBufferSize(AudioSource source);

  Future<SoundHandle> play(
    AudioSource source, {
    double volume = 1.0,
    double pan = 0.0,
    bool looping = false,
  });

  Future<void> stop(SoundHandle handle);

  Future<void> disposeSource(AudioSource source);
}

class _DefaultSoloudBackend implements SoloudBackend {
  const _DefaultSoloudBackend();

  @override
  bool get isInitialized => SoLoud.instance.isInitialized;

  @override
  Future<void> init({
    required int sampleRate,
    required int bufferSize,
    required Channels channels,
  }) {
    return SoLoud.instance.init(
      sampleRate: sampleRate,
      bufferSize: bufferSize,
      channels: channels,
    );
  }

  @override
  void configureGlobalBiquad({
    required double resonance,
    required double wet,
  }) {
    final f = SoLoud.instance.filters.biquadResonantFilter;
    if (!f.isActive) {
      f.activate();
    }
    f.resonance.value = resonance;
    f.wet.value = wet;
  }

  @override
  void updateGlobalBiquad({required double cutoffHz}) {
    final f = SoLoud.instance.filters.biquadResonantFilter;
    // SoLoud C++ BiquadResonantFilter::getParamMax(FREQUENCY) is 8000 Hz (Fs/4 stability bound)
    if (cutoffHz < 8000.0) {
      f.frequency.value = cutoffHz.clamp(350.0, 8000.0);
      f.wet.value = ((8000.0 - cutoffHz) / 7650.0).clamp(0.0, 0.85);
    } else {
      f.wet.value = 0.0;
    }
  }

  @override
  bool getIsValidVoiceHandle(SoundHandle handle) =>
      SoLoud.instance.getIsValidVoiceHandle(handle);

  @override
  void setProtectVoice(SoundHandle handle, bool protect) =>
      SoLoud.instance.setProtectVoice(handle, protect);

  @override
  void setVolume(SoundHandle handle, double volume) =>
      SoLoud.instance.setVolume(handle, volume);

  @override
  void setPan(SoundHandle handle, double pan) =>
      SoLoud.instance.setPan(handle, pan);

  @override
  void seek(SoundHandle handle, Duration position) =>
      SoLoud.instance.seek(handle, position);

  @override
  Future<AudioSource> loadMem(String name, Uint8List bytes) =>
      SoLoud.instance.loadMem(name, bytes);

  @override
  Future<AudioSource> loadAsset(String path, {required LoadMode mode}) =>
      SoLoud.instance.loadAsset(path, mode: mode);

  @override
  Future<AudioSource> loadUrl(String url, {required LoadMode mode}) =>
      SoLoud.instance.loadUrl(url, mode: mode);

  @override
  Future<AudioSource> loadFile(String path, {required LoadMode mode}) =>
      SoLoud.instance.loadFile(path, mode: mode);

  @override
  AudioSource setBufferStream({
    required int maxBufferSizeBytes,
    required BufferingType bufferingType,
    required double bufferingTimeNeeds,
    required int sampleRate,
    required Channels channels,
    required BufferType format,
  }) {
    return SoLoud.instance.setBufferStream(
      maxBufferSizeBytes: maxBufferSizeBytes,
      bufferingType: bufferingType,
      bufferingTimeNeeds: bufferingTimeNeeds,
      sampleRate: sampleRate,
      channels: channels,
      format: format,
    );
  }

  @override
  void addAudioDataStream(AudioSource source, Uint8List chunk) =>
      SoLoud.instance.addAudioDataStream(source, chunk);

  @override
  void setDataIsEnded(AudioSource source) =>
      SoLoud.instance.setDataIsEnded(source);

  @override
  int getBufferSize(AudioSource source) =>
      SoLoud.instance.getBufferSize(source);

  @override
  Future<SoundHandle> play(
    AudioSource source, {
    double volume = 1.0,
    double pan = 0.0,
    bool looping = false,
  }) {
    return SoLoud.instance.play(
      source,
      volume: volume,
      pan: pan,
      looping: looping,
    );
  }

  @override
  Future<void> stop(SoundHandle handle) => SoLoud.instance.stop(handle);

  @override
  Future<void> disposeSource(AudioSource source) =>
      SoLoud.instance.disposeSource(source);
}

class ActiveStreamSlot {
  ActiveStreamSlot({
    required this.trackId,
    required this.source,
    required this.handle,
    this.isReleasedStream = false,
    this.streamStartSeekSeconds = 0.0,
    this.lastTargetSeekSeconds = 0.0,
    double? initialAnchorSeekSeconds,
    this.chunkTimer,
  })  : anchorSeekSeconds = initialAnchorSeekSeconds ??
            (isReleasedStream ? streamStartSeekSeconds : lastTargetSeekSeconds),
        playbackClock = Stopwatch()..start();

  final String trackId;
  final AudioSource source;
  final SoundHandle handle;
  final bool isReleasedStream;
  final double streamStartSeekSeconds;
  double lastTargetSeekSeconds;
  double anchorSeekSeconds;
  final Stopwatch playbackClock;
  final Timer? chunkTimer;

  double get estimatedPlaybackSeconds =>
      anchorSeekSeconds + playbackClock.elapsedMicroseconds / 1000000.0;
}

class SoloudAudioService {
  SoloudAudioService({
    ProgressiveTrackCache? cache,
    @visibleForTesting SoloudBackend? backend,
    @visibleForTesting bool forceWebStreamingForTest = false,
    @visibleForTesting
    Future<Uint8List?> Function(ResolvedAudioTarget target)? webByteLoader,
    @visibleForTesting
    Duration feederTickInterval = const Duration(milliseconds: 250),
  })  : cache = cache ?? ProgressiveTrackCache(),
        _backend = backend ?? const _DefaultSoloudBackend(),
        _useWebStreaming = kIsWeb || forceWebStreamingForTest,
        _webByteLoader = webByteLoader,
        _feederTickInterval = feederTickInterval;

  /// High-water mark (~6.8s of 48 kHz stereo float32 PCM) keeping steady WASM
  /// stream memory <3.6 MB and avoiding large real-time `std::vector` `memmove`s.
  static const int maxSteadyBufferedPcmBytes = 2621440; // 2.5 MiB

  final ProgressiveTrackCache cache;
  final FftAnalyzer fft = FftAnalyzer();
  final SoloudBackend _backend;
  final bool _useWebStreaming;
  final Future<Uint8List?> Function(ResolvedAudioTarget target)? _webByteLoader;
  final Duration _feederTickInterval;

  bool _initialized = false;
  bool _initializing = false;
  AudioSource? _keepAliveSource;
  SoundHandle? _keepAliveHandle;
  final Map<String, ActiveStreamSlot> _activeStreams = {};
  final Map<String, int> _slotGeneration = {};
  final Map<String, String> _inFlightSlotTrack = {};
  final Map<String, ({double volume, double pan, double seekSeconds})>
      _pendingSlotParams = {};
  final Map<String, ({String trackId, double completedAtSeekSeconds})>
      _completedNonLoopingSlots = {};
  final Map<String, AudioSource> _sfxCache = {};

  bool get isReady => _initialized;

  @visibleForTesting
  Map<String, ActiveStreamSlot> get debugActiveStreams =>
      Map.unmodifiable(_activeStreams);

  /// Returns exact real-time playback seconds of a currently playing stream voice, if active.
  double? activePlaybackSecondsForTrack(String trackId) {
    if (!_initialized) return null;
    for (final slot in _activeStreams.values) {
      if (slot.trackId == trackId) {
        try {
          if (_backend.getIsValidVoiceHandle(slot.handle)) {
            return slot.estimatedPlaybackSeconds;
          }
        } catch (_) {}
      }
    }
    return null;
  }

  bool _isSlotGenCurrent(String slotKey, int expectedGen) =>
      _initialized && _slotGeneration[slotKey] == expectedGen;

  static Uint8List _buildSilentKeepAliveWav() {
    const dataBytes = 8000; // 0.5s @ 8 kHz mono 16-bit PCM = 8 KB zero-PCM
    final out = Uint8List(44 + dataBytes);
    final bd = ByteData.sublistView(out);
    // "RIFF"
    out[0] = 0x52;
    out[1] = 0x49;
    out[2] = 0x46;
    out[3] = 0x46;
    bd.setUint32(4, 36 + dataBytes, Endian.little);
    // "WAVEfmt "
    out[8] = 0x57;
    out[9] = 0x41;
    out[10] = 0x56;
    out[11] = 0x45;
    out[12] = 0x66;
    out[13] = 0x6D;
    out[14] = 0x74;
    out[15] = 0x20;
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little); // PCM
    bd.setUint16(22, 1, Endian.little); // Mono
    bd.setUint32(24, 8000, Endian.little); // Sample rate
    bd.setUint32(28, 16000, Endian.little); // Byte rate
    bd.setUint16(32, 2, Endian.little); // Block align
    bd.setUint16(34, 16, Endian.little); // Bits per sample
    // "data"
    out[36] = 0x64;
    out[37] = 0x61;
    out[38] = 0x74;
    out[39] = 0x61;
    bd.setUint32(40, dataBytes, Endian.little);
    return out;
  }

  Future<void> _ensureKeepAliveVoice() async {
    try {
      final existingHandle = _keepAliveHandle;
      if (existingHandle != null &&
          _backend.getIsValidVoiceHandle(existingHandle)) {
        return;
      }
      _keepAliveSource ??= await _backend.loadMem(
        'walnutstock_keepalive.wav',
        _buildSilentKeepAliveWav(),
      );
      // Volume 0.05 >= SoLoud's 0.01f INAUDIBLE threshold while multiplying 0-PCM samples (= 0.0 output),
      // keeping getActiveVoiceCount() >= 1 so flutter_soloud never auto-suspends the WebAudio context!
      final handle = await _backend.play(
        _keepAliveSource!,
        volume: 0.05,
        looping: true,
      );
      _backend.setProtectVoice(handle, true);
      _keepAliveHandle = handle;
    } catch (_) {}
  }

  /// Must be called from a user gesture on Web ("Tear Ticket Stub" / HUD / Canvas tap) to unlock WebAudio cleanly.
  Future<void> unlockAndInitialize() async {
    if (_initialized) {
      if (kIsWeb) {
        unawaited(ensureWebAudioUnlockedAndReady());
        unawaited(_ensureKeepAliveVoice());
      }
      return;
    }
    if (_initializing) {
      if (kIsWeb) {
        unawaited(ensureWebAudioUnlockedAndReady());
      }
      return;
    }
    _initializing = true;
    try {
      await cache.initialize();
      if (kIsWeb) {
        await ensureWebAudioUnlockedAndReady();
      }
      if (!_backend.isInitialized) {
        await _backend.init(
          sampleRate: 44100,
          bufferSize: 2048,
          channels: Channels.stereo,
        );
      }
      if (kIsWeb) {
        await ensureWebAudioUnlockedAndReady();
      }
      await _ensureKeepAliveVoice();
      // Enable global biquad low-pass filter slot for real-time canopy/tent occlusion
      try {
        _backend.configureGlobalBiquad(
          resonance: 0.707, // Butterworth flat Q (no resonant ringing)
          wet: 0.0,
        );
      } catch (_) {}
      fft.initializeIfSupported();
      _initialized = true;
    } catch (_) {
      // Headless test environments or browsers blocking audio fail gracefully without crashing gameplay
      _initialized = false;
    } finally {
      _initializing = false;
    }
  }

  Future<void> playSfx(
    String assetPath, {
    double volume = 0.7,
    double pan = 0.0,
  }) async {
    if (!_initialized || volume <= 0.01) return;
    try {
      var src = _sfxCache[assetPath];
      if (src == null) {
        src = await _backend.loadAsset(
          assetPath,
          mode: LoadMode.memory, // Tiny <150 KB WAV UI/footstep SFX stay in RAM
        );
        _sfxCache[assetPath] = src;
      }
      final handle = await _backend.play(
        src,
        volume: volume.clamp(0.0, 1.0),
        pan: pan.clamp(-1.0, 1.0),
      );
      _backend.setPan(handle, pan.clamp(-1.0, 1.0));
    } catch (_) {}
  }

  /// Streams a long festival track incrementally (<3.6 MB steady PCM buffer instead of 146 MB!).
  Future<void> syncStreamSlot({
    required String slotKey,
    required String trackId,
    required ResolvedAudioTarget target,
    required double seekSeconds,
    required double volume,
    required double pan,
    bool looping = false,
  }) async {
    if (!_initialized) return;

    if (looping) {
      _completedNonLoopingSlots.remove(slotKey);
    } else {
      final completed = _completedNonLoopingSlots[slotKey];
      if (completed != null) {
        if (completed.trackId == trackId &&
            (seekSeconds - completed.completedAtSeekSeconds).abs() <= 3.5) {
          _completedNonLoopingSlots[slotKey] = (
            trackId: trackId,
            completedAtSeekSeconds: seekSeconds,
          );
          return;
        }
        _completedNonLoopingSlots.remove(slotKey);
      }
    }

    final existing = _activeStreams[slotKey];
    if (existing != null && existing.trackId == trackId) {
      final targetJump = (seekSeconds - existing.lastTargetSeekSeconds).abs();
      if (_backend.getIsValidVoiceHandle(existing.handle)) {
        _backend.setVolume(existing.handle, volume.clamp(0.0, 1.0));
        _backend.setPan(existing.handle, pan.clamp(-1.0, 1.0));
        if (!looping) {
          existing.lastTargetSeekSeconds = seekSeconds;
          if (!existing.isReleasedStream) {
            if (targetJump > 3.5) {
              _backend.seek(
                existing.handle,
                Duration(milliseconds: (seekSeconds * 1000).round()),
              );
              existing.anchorSeekSeconds = seekSeconds;
              existing.playbackClock
                ..reset()
                ..start();
            }
            return;
          } else {
            // Only re-slice Web released BufferStream on explicit clock jumps / Encore scrubs
            // (never restart in a loop while the festival clock is paused for Dialogue/Journal!)
            if (targetJump <= 3.5) {
              return;
            }
          }
        } else {
          existing.lastTargetSeekSeconds = seekSeconds;
          return;
        }
      } else if (!looping && targetJump <= 3.5) {
        // Non-looping performance finished naturally at EOF: clean up once and rest
        // instead of jackhammer-looping the final tail while clock < endMinute!
        _completedNonLoopingSlots[slotKey] = (
          trackId: trackId,
          completedAtSeekSeconds: seekSeconds,
        );
        await _stopAndDisposeActiveSlot(slotKey);
        return;
      }
    }

    _pendingSlotParams[slotKey] = (
      volume: volume,
      pan: pan,
      seekSeconds: seekSeconds,
    );
    if (_inFlightSlotTrack[slotKey] == trackId) {
      return;
    }

    final myGen = (_slotGeneration[slotKey] ?? 0) + 1;
    _slotGeneration[slotKey] = myGen;
    _inFlightSlotTrack[slotKey] = trackId;

    try {
      await _stopAndDisposeActiveSlot(slotKey);
      if (!_isSlotGenCurrent(slotKey, myGen)) return;

      if (_useWebStreaming && !target.uriOrPath.endsWith('.wav')) {
        final started = await _startWebReleasedBufferStream(
          slotKey: slotKey,
          slotGen: myGen,
          trackId: trackId,
          target: target,
          sliceSeekSeconds: looping ? 0.0 : seekSeconds,
          targetSeekSeconds: seekSeconds,
          looping: looping,
          volume: volume,
          pan: pan,
        );
        if (started || !_isSlotGenCurrent(slotKey, myGen)) return;
      }

      AudioSource source;
      if (target.isBundledFlutterAsset) {
        source = await _backend.loadAsset(
          target.uriOrPath,
          mode: LoadMode.disk,
        );
      } else if (_useWebStreaming ||
          target.uriOrPath.startsWith('http') ||
          target.uriOrPath.startsWith('audio/')) {
        source = await _backend.loadUrl(
          target.uriOrPath,
          mode: LoadMode.disk,
        );
      } else {
        source = await _backend.loadFile(
          target.uriOrPath,
          mode: LoadMode.disk,
        );
      }

      if (!_isSlotGenCurrent(slotKey, myGen)) {
        try {
          await _backend.disposeSource(source);
        } catch (_) {}
        return;
      }

      final latestParams = _pendingSlotParams[slotKey];
      final effVol = (latestParams?.volume ?? volume).clamp(0.0, 1.0);
      final effPan = (latestParams?.pan ?? pan).clamp(-1.0, 1.0);
      final effSeek = latestParams?.seekSeconds ?? seekSeconds;

      final handle = await _backend.play(
        source,
        volume: effVol,
        pan: effPan,
        looping: looping,
      );
      if (!_isSlotGenCurrent(slotKey, myGen)) {
        try {
          await _backend.stop(handle);
          await _backend.disposeSource(source);
        } catch (_) {}
        return;
      }
      if (effSeek > 0.25 && !looping) {
        _backend.seek(
          handle,
          Duration(milliseconds: (effSeek * 1000).round()),
        );
      }
      _activeStreams[slotKey] = ActiveStreamSlot(
        trackId: trackId,
        source: source,
        handle: handle,
        lastTargetSeekSeconds: effSeek,
      );
    } catch (_) {
      if (!_isSlotGenCurrent(slotKey, myGen)) return;
      // Fallback to .mp3 if .ogg not available in dev environment
      if (!target.uriOrPath.endsWith('.mp3') &&
          !target.uriOrPath.endsWith('.wav')) {
        final mp3Fallback = ResolvedAudioTarget(
          uriOrPath: _useWebStreaming
              ? 'assets/assets/audio/tracks/$trackId.mp3'
              : 'assets/audio/tracks/$trackId.mp3',
          isBundledFlutterAsset: false,
        );
        try {
          if (_useWebStreaming) {
            await _startWebReleasedBufferStream(
              slotKey: slotKey,
              slotGen: myGen,
              trackId: trackId,
              target: mp3Fallback,
              sliceSeekSeconds: 0.0,
              targetSeekSeconds: seekSeconds,
              looping: looping,
              volume: volume,
              pan: pan,
            );
          } else {
            final source = await _backend.loadFile(
              mp3Fallback.uriOrPath,
              mode: LoadMode.disk,
            );
            if (!_isSlotGenCurrent(slotKey, myGen)) {
              await _backend.disposeSource(source);
              return;
            }
            final handle = await _backend.play(
              source,
              volume: volume.clamp(0.0, 1.0),
              pan: pan.clamp(-1.0, 1.0),
              looping: looping,
            );
            if (!_isSlotGenCurrent(slotKey, myGen)) {
              await _backend.stop(handle);
              await _backend.disposeSource(source);
              return;
            }
            if (seekSeconds > 0.25 && !looping) {
              _backend.seek(
                handle,
                Duration(milliseconds: (seekSeconds * 1000).round()),
              );
            }
            _activeStreams[slotKey] = ActiveStreamSlot(
              trackId: trackId,
              source: source,
              handle: handle,
              lastTargetSeekSeconds: seekSeconds,
            );
          }
        } catch (_) {}
      }
    } finally {
      if (_slotGeneration[slotKey] == myGen) {
        _inFlightSlotTrack.remove(slotKey);
      }
    }
  }

  Future<Uint8List?> _loadWebCompressedBytes(ResolvedAudioTarget target) async {
    final customLoader = _webByteLoader;
    if (customLoader != null) {
      return customLoader(target);
    }
    if (target.isBundledFlutterAsset) {
      try {
        final bd = await rootBundle.load(target.uriOrPath);
        return bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
      } catch (_) {
        return fetchCachedWebAudioBytes('assets/${target.uriOrPath}');
      }
    }
    return fetchCachedWebAudioBytes(target.uriOrPath);
  }

  Future<bool> _startWebReleasedBufferStream({
    required String slotKey,
    required int slotGen,
    required String trackId,
    required ResolvedAudioTarget target,
    required double sliceSeekSeconds,
    required double targetSeekSeconds,
    required bool looping,
    required double volume,
    required double pan,
  }) async {
    final compressedBytes = await _loadWebCompressedBytes(target);
    if (!_isSlotGenCurrent(slotKey, slotGen)) {
      return false;
    }
    if (compressedBytes == null || compressedBytes.isEmpty) {
      return false;
    }

    var bytes = compressedBytes;
    var actualSeekSeconds = 0.0;
    if (!looping &&
        sliceSeekSeconds > 0.4 &&
        target.uriOrPath.endsWith('.ogg')) {
      final sliced = sliceOggOpusFromSeconds(compressedBytes, sliceSeekSeconds);
      if (sliced.isAtOrPastEof) {
        _completedNonLoopingSlots[slotKey] = (
          trackId: trackId,
          completedAtSeekSeconds: targetSeekSeconds,
        );
        return true;
      }
      bytes = sliced.bytes;
      actualSeekSeconds = sliced.actualSeekSeconds;
    }

    final streamSource = _backend.setBufferStream(
      maxBufferSizeBytes: 16 * 1024 * 1024,
      bufferingType: BufferingType.released,
      bufferingTimeNeeds: 0.35,
      sampleRate: 44100,
      channels: Channels.stereo,
      format: BufferType.auto,
    );

    // Note: flutter_soloud's C++ addData checks `buffer.size() > 1024 * 32` (strict > 32768),
    // so trickleChunk MUST exceed 32768 bytes to trigger Opus packet decode on each feed tick!
    const initialBurst = 131072; // ~9s of 112 kbps Opus for instant playback
    const trickleChunk = 40960; // 40 KB (> 32 KB decode threshold)
    var offset = math.min(initialBurst, bytes.length);
    _backend.addAudioDataStream(
      streamSource,
      Uint8List.sublistView(bytes, 0, offset),
    );

    final latestBeforePlay = _pendingSlotParams[slotKey];
    final initVol = (latestBeforePlay?.volume ?? volume).clamp(0.0, 1.0);
    final initPan = (latestBeforePlay?.pan ?? pan).clamp(-1.0, 1.0);

    final handle = await _backend.play(
      streamSource,
      volume: initVol,
      pan: initPan,
    );
    if (!_isSlotGenCurrent(slotKey, slotGen)) {
      try {
        await _backend.stop(handle);
        await _backend.disposeSource(streamSource);
      } catch (_) {}
      return false;
    }

    final latestAfterPlay = _pendingSlotParams[slotKey];
    final effVol = (latestAfterPlay?.volume ?? initVol).clamp(0.0, 1.0);
    final effPan = (latestAfterPlay?.pan ?? initPan).clamp(-1.0, 1.0);
    final effTargetSeek = latestAfterPlay?.seekSeconds ?? targetSeekSeconds;
    _backend.setVolume(handle, effVol);
    _backend.setPan(handle, effPan);

    if (offset >= bytes.length) {
      _backend.setDataIsEnded(streamSource);
    }

    Timer? feeder;
    if (offset < bytes.length) {
      feeder = Timer.periodic(_feederTickInterval, (timer) {
        final current = _activeStreams[slotKey];
        if (current == null ||
            current.source != streamSource ||
            !_isSlotGenCurrent(slotKey, slotGen)) {
          timer.cancel();
          return;
        }
        if (offset >= bytes.length) {
          try {
            _backend.setDataIsEnded(streamSource);
          } catch (_) {}
          timer.cancel();
          return;
        }
        // Backpressure check: wait until decoded PCM drains below 2.5 MiB (~6.8s cushion)
        // so long tracks never accumulate 100+ MB of float32 PCM in WASM memory!
        try {
          if (_backend.getBufferSize(streamSource) >=
              maxSteadyBufferedPcmBytes) {
            return;
          }
        } catch (_) {}

        final end = math.min(offset + trickleChunk, bytes.length);
        try {
          _backend.addAudioDataStream(
            streamSource,
            Uint8List.sublistView(bytes, offset, end),
          );
          offset = end;
          if (offset >= bytes.length) {
            _backend.setDataIsEnded(streamSource);
            timer.cancel();
          }
        } catch (_) {
          // If internal ring buffer is temporarily full, retry on next tick
        }
      });
    }

    _activeStreams[slotKey] = ActiveStreamSlot(
      trackId: trackId,
      source: streamSource,
      handle: handle,
      isReleasedStream: true,
      streamStartSeekSeconds: actualSeekSeconds,
      lastTargetSeekSeconds: effTargetSeek,
      chunkTimer: feeder,
    );
    return true;
  }

  void updateCanopyLowPass(double cutoffHz) {
    if (!_initialized) return;
    try {
      _backend.updateGlobalBiquad(cutoffHz: cutoffHz);
    } catch (_) {}
  }

  Future<void> _stopAndDisposeActiveSlot(String slotKey) async {
    final slot = _activeStreams.remove(slotKey);
    if (slot == null) return;
    slot.chunkTimer?.cancel();
    if (!_initialized) return;
    try {
      await _backend.stop(slot.handle);
      await _backend.disposeSource(slot.source);
    } catch (_) {}
  }

  Future<void> stopSlot(String slotKey) async {
    _slotGeneration[slotKey] = (_slotGeneration[slotKey] ?? 0) + 1;
    _inFlightSlotTrack.remove(slotKey);
    _pendingSlotParams.remove(slotKey);
    _completedNonLoopingSlots.remove(slotKey);
    await _stopAndDisposeActiveSlot(slotKey);
  }

  Future<void> stopAllStreams() async {
    final allKeys = <String>{
      ..._activeStreams.keys,
      ..._inFlightSlotTrack.keys,
    }.toList();
    for (final key in allKeys) {
      await stopSlot(key);
    }
  }

  Future<void> dispose() async {
    cache.dispose();
    fft.dispose();
    await stopAllStreams();
    final wasInitialized = _initialized;
    _initialized = false;
    final kaHandle = _keepAliveHandle;
    _keepAliveHandle = null;
    if (wasInitialized && kaHandle != null) {
      try {
        await _backend.stop(kaHandle);
      } catch (_) {}
    }
    final kaSource = _keepAliveSource;
    _keepAliveSource = null;
    if (wasInitialized && kaSource != null) {
      try {
        await _backend.disposeSource(kaSource);
      } catch (_) {}
    }
    for (final src in _sfxCache.values) {
      if (wasInitialized) {
        try {
          await _backend.disposeSource(src);
        } catch (_) {}
      }
    }
    _sfxCache.clear();
  }
}
