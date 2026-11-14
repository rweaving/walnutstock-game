import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walnutstock/audio/audio_schedule_controller.dart';
import 'package:walnutstock/audio/ogg_opus_slicer.dart';
import 'package:walnutstock/audio/progressive_track_cache.dart';
import 'package:walnutstock/audio/soloud_audio_service.dart';
import 'package:walnutstock/audio/spatial_stage_emitter.dart';
import 'package:walnutstock/data/models.dart';
import 'package:walnutstock/state/festival_clock.dart';
import 'package:walnutstock/state/player_profile.dart';
import 'package:walnutstock/state/settings_state.dart';

class _FakeAudioSource implements AudioSource {
  _FakeAudioSource(this.debugId);
  final int debugId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSoloudBackend implements SoloudBackend {
  bool initialized = false;
  int _nextSourceId = 1;
  int _nextHandleId = 100;

  final Set<int> liveSources = {};
  final Set<int> activeHandles = {};
  final Set<int> endedSources = {};
  final Map<int, int> sourceBytesFed = {};
  final Map<int, int> simulatedBufferedPcmBytes = {};
  final Map<int, double> handleVolumes = {};
  final Map<int, double> handlePans = {};
  int playCalls = 0;

  @override
  bool get isInitialized => initialized;

  @override
  Future<void> init({
    required int sampleRate,
    required int bufferSize,
    required Channels channels,
  }) async {
    initialized = true;
  }

  @override
  void configureGlobalBiquad(
      {required double resonance, required double wet}) {}

  @override
  void updateGlobalBiquad({required double cutoffHz}) {}

  @override
  bool getIsValidVoiceHandle(SoundHandle handle) =>
      activeHandles.contains(handle.id);

  @override
  void setProtectVoice(SoundHandle handle, bool protect) {}

  @override
  void setVolume(SoundHandle handle, double volume) {
    handleVolumes[handle.id] = volume;
  }

  @override
  void setPan(SoundHandle handle, double pan) {
    handlePans[handle.id] = pan;
  }

  @override
  void seek(SoundHandle handle, Duration position) {}

  AudioSource _allocSource() {
    final id = _nextSourceId++;
    liveSources.add(id);
    sourceBytesFed[id] = 0;
    return _FakeAudioSource(id);
  }

  @override
  Future<AudioSource> loadMem(String name, Uint8List bytes) async =>
      _allocSource();

  @override
  Future<AudioSource> loadAsset(String path, {required LoadMode mode}) async =>
      _allocSource();

  @override
  Future<AudioSource> loadUrl(String url, {required LoadMode mode}) async =>
      _allocSource();

  @override
  Future<AudioSource> loadFile(String path, {required LoadMode mode}) async =>
      _allocSource();

  @override
  AudioSource setBufferStream({
    required int maxBufferSizeBytes,
    required BufferingType bufferingType,
    required double bufferingTimeNeeds,
    required int sampleRate,
    required Channels channels,
    required BufferType format,
  }) {
    return _allocSource();
  }

  @override
  void addAudioDataStream(AudioSource source, Uint8List chunk) {
    final id = (source as _FakeAudioSource).debugId;
    sourceBytesFed[id] = (sourceBytesFed[id] ?? 0) + chunk.length;
  }

  @override
  void setDataIsEnded(AudioSource source) {
    endedSources.add((source as _FakeAudioSource).debugId);
  }

  @override
  int getBufferSize(AudioSource source) {
    final id = (source as _FakeAudioSource).debugId;
    return simulatedBufferedPcmBytes[id] ?? 0;
  }

  @override
  Future<SoundHandle> play(
    AudioSource source, {
    double volume = 1.0,
    double pan = 0.0,
    bool looping = false,
  }) async {
    playCalls++;
    final h = SoundHandle(_nextHandleId++);
    activeHandles.add(h.id);
    handleVolumes[h.id] = volume;
    handlePans[h.id] = pan;
    return h;
  }

  @override
  Future<void> stop(SoundHandle handle) async {
    activeHandles.remove(handle.id);
  }

  @override
  Future<void> disposeSource(AudioSource source) async {
    liveSources.remove((source as _FakeAudioSource).debugId);
  }
}

class _TrackingAudioService extends SoloudAudioService {
  final Map<String, ({String trackId, double volume, double pan, double seek})>
      activeSlots = {};
  int loadCount = 0;

  @override
  Future<void> syncStreamSlot({
    required String slotKey,
    required String trackId,
    required ResolvedAudioTarget target,
    required double seekSeconds,
    required double volume,
    required double pan,
    bool looping = false,
  }) async {
    final prev = activeSlots[slotKey];
    if (prev == null || prev.trackId != trackId) {
      loadCount++;
    }
    activeSlots[slotKey] = (
      trackId: trackId,
      volume: volume,
      pan: pan,
      seek: seekSeconds,
    );
  }

  @override
  Future<void> stopSlot(String slotKey) async {
    activeSlots.remove(slotKey);
  }
}

void main() {
  late SetlistCatalog catalog;

  setUpAll(() {
    final raw = File('assets/data/setlist_26_tracks.json').readAsStringSync();
    catalog = SetlistCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  group('v1.0 Music Playback & Orchard Spatial Audibility Regressions', () {
    test(
        'Track 1 and Next Set jumps are immediately audible at Front Gate spawn (608, 1344) and locked fence (608, 1184)',
        () {
      const profile = PlayerProfile();
      expect(profile.savedX, 608.0);
      expect(profile.savedY, 1344.0);

      final audio = _TrackingAudioService();
      final ctrl = AudioScheduleController(catalog: catalog, audio: audio);
      final clock = FestivalClockNotifier(catalog);
      const settings = SettingsState();

      // 1. Immediately on entering Free Orchard at default spawn (608, 1344): Track 1 MUST play!
      final spawnSnap = ctrl.update(
        dtSeconds: 0.05,
        clock: clock.state,
        settings: settings,
        listenerX: profile.savedX,
        listenerY: profile.savedY,
        listenerInOcclusionZone: false,
        listenerInUndergrowthFog: false,
        turntableTrackNumber: null,
        encoreAnywhereJukebox: false,
        onFiveMinuteBellAlert: null,
        onTrackHeardStamp: null,
      );
      expect(spawnSnap.primaryTrack?.id, 'track_01');
      expect(spawnSnap.primaryMix?.isAudible, isTrue);
      expect(spawnSnap.primaryMix!.gain, greaterThan(0.20));
      expect(audio.activeSlots['stage_a']?.trackId, 'track_01');
      expect(audio.activeSlots['stage_a']!.volume, greaterThan(0.15));

      // 2. Walking north to locked Front Gate fence (608, 1184) increases Track 1 volume smoothly
      final fenceSnap = ctrl.update(
        dtSeconds: 0.05,
        clock: clock.state,
        settings: settings,
        listenerX: 608.0,
        listenerY: 1184.0,
        listenerInOcclusionZone: false,
        listenerInUndergrowthFog: false,
        turntableTrackNumber: null,
        encoreAnywhereJukebox: false,
        onFiveMinuteBellAlert: null,
        onTrackHeardStamp: null,
      );
      expect(
          fenceSnap.primaryMix!.gain, greaterThan(spawnSnap.primaryMix!.gain));

      // 3. Clicking "Next Set" across all 26 numbered tracks from Front Gate spawn ALWAYS produces audible audio!
      for (var i = 0; i < 25; i++) {
        final jumped = clock.jumpToNextScheduledSet();
        expect(jumped, isNotNull);
        final snap = ctrl.update(
          dtSeconds: 0.05,
          clock: clock.state,
          settings: settings,
          listenerX: profile.savedX,
          listenerY: profile.savedY,
          listenerInOcclusionZone: false,
          listenerInUndergrowthFog: false,
          turntableTrackNumber: null,
          encoreAnywhereJukebox: false,
          onFiveMinuteBellAlert: null,
          onTrackHeardStamp: null,
        );
        expect(
          snap.primaryMix?.isAudible,
          isTrue,
          reason:
              'Track #${jumped!.trackNumber} (${jumped.title} @ ${jumped.stageId}) was silent from spawn!',
        );
        expect(
          audio.activeSlots.values.any((s) => s.volume > 0.04),
          isTrue,
          reason:
              'No active audio stream slot had audible volume on Track #${jumped.trackNumber}!',
        );
      }
    });

    test(
        'Just Listen mode delivers full-clarity concert mix even from far out-of-range corners',
        () {
      final audio = _TrackingAudioService();
      final ctrl = AudioScheduleController(catalog: catalog, audio: audio);
      const settings = SettingsState();
      const day1Morning = FestivalClockState(day: 1, minuteOfDay: 500.0);

      // Far SE corner (1950, 1450) is outside Main Roots Stage maxDist without Just Listen
      final outOfRange = ctrl.update(
        dtSeconds: 0.05,
        clock: day1Morning,
        settings: settings,
        listenerX: 1950.0,
        listenerY: 1450.0,
        listenerInOcclusionZone: true,
        listenerInUndergrowthFog: false,
        turntableTrackNumber: null,
        encoreAnywhereJukebox: false,
        justListenStageMode: false,
        onFiveMinuteBellAlert: null,
        onTrackHeardStamp: null,
      );
      expect(outOfRange.primaryMix?.isAudible, isFalse);
      expect(audio.activeSlots, isEmpty);

      // Toggling Just Listen boosts active stage to crisp centered mix anywhere in the orchard
      final justListen = ctrl.update(
        dtSeconds: 0.05,
        clock: day1Morning,
        settings: settings,
        listenerX: 1950.0,
        listenerY: 1450.0,
        listenerInOcclusionZone: true,
        listenerInUndergrowthFog: false,
        turntableTrackNumber: null,
        encoreAnywhereJukebox: false,
        justListenStageMode: true,
        onFiveMinuteBellAlert: null,
        onTrackHeardStamp: null,
      );
      expect(justListen.primaryMix?.isAudible, isTrue);
      expect(justListen.primaryMix?.gain, closeTo(0.88, 0.001));
      expect(justListen.primaryMix?.pan, 0.0);
      expect(justListen.primaryMix?.lowPassCutoffHz, 18000.0);
      expect(audio.activeSlots['stage_a']?.trackId, 'track_01');
      expect(
        audio.activeSlots['stage_a']?.volume,
        closeTo(0.88 * settings.masterVolume * settings.musicVolume, 0.01),
      );

      // Ensure -9 dB PA ducking still applies cleanly in Just Listen mode if PA Horn is active
      final customCatalog = SetlistCatalog(
        albumTitle: catalog.albumTitle,
        albumArtist: catalog.albumArtist,
        clockMinutesPerRealSecond: catalog.clockMinutesPerRealSecond,
        stages: catalog.stages,
        tracks: [
          catalog.trackByNumber(1)!,
          const ScheduledTrack(
            trackNumber: 99,
            id: 'track_02',
            title: 'PA Overlap Test',
            artist: 'Patchouli Pete',
            day: 1,
            startMinute: 495.0,
            endMinute: 510.0,
            durationSeconds: 27.0,
            stageId: 'pa_global_horn',
            assetPath: 'assets/audio/tracks/track_02.ogg',
            isPaBroadcast: true,
          ),
        ],
      );
      final duckAudio = _TrackingAudioService();
      final duckCtrl =
          AudioScheduleController(catalog: customCatalog, audio: duckAudio);
      duckCtrl.update(
        dtSeconds: 0.05,
        clock: day1Morning,
        settings: settings,
        listenerX: 1950.0,
        listenerY: 1450.0,
        listenerInOcclusionZone: false,
        listenerInUndergrowthFog: false,
        turntableTrackNumber: null,
        encoreAnywhereJukebox: false,
        justListenStageMode: true,
        onFiveMinuteBellAlert: null,
        onTrackHeardStamp: null,
      );
      expect(duckAudio.activeSlots.containsKey('pa_horn'), isTrue);
      expect(
        duckAudio.activeSlots['stage_a']!.volume,
        closeTo(
          0.88 *
              SpatialStageEmitter.paBroadcastDuckLinear *
              settings.masterVolume *
              settings.musicVolume,
          0.01,
        ),
      );
    });

    test(
        'pubspec.yaml declares all 29 Ogg Opus tracks and each file starts with valid OggS header',
        () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final track in catalog.tracks) {
        if (track.assetPath.endsWith('.wav')) continue;
        final expectedEntry = 'assets/audio/tracks/${track.id}.ogg';
        expect(
          pubspec.contains(expectedEntry),
          isTrue,
          reason:
              'Missing $expectedEntry in pubspec.yaml (causes 404 in flutter run / static web builds)!',
        );
        final f = File(expectedEntry);
        expect(f.existsSync(), isTrue, reason: 'Missing file $expectedEntry');
        final header = f.openSync()..setPositionSync(0);
        final magic = header.readSync(4);
        header.closeSync();
        expect(String.fromCharCodes(magic), 'OggS');
      }
    });

    test(
        'dart2js-safe Ogg Opus 64-bit granule helpers & mid-set slicing handle continuation (-1), >32-bit granules, and near-EOF bounds',
        () {
      final buf = ByteData(8);
      writeOggGranulePos(buf, 0, -1);
      expect(readOggGranulePos(buf, 0), -1);

      // Value > 2^32 (e.g. >24 hours @ 48 kHz) where JS `<< 32` would wrap if broken
      const largeGranule = 5000000000;
      writeOggGranulePos(buf, 0, largeGranule);
      expect(readOggGranulePos(buf, 0), largeGranule);

      final track4Bytes =
          File('assets/audio/tracks/track_04.ogg').readAsBytesSync();
      final midSlice = sliceOggOpusFromSeconds(track4Bytes, 141.29);
      expect(midSlice.isAtOrPastEof, isFalse);
      expect(midSlice.actualSeekSeconds, closeTo(141.29, 2.5));
      expect(midSlice.totalDurationSeconds, closeTo(220.16, 1.0));
      expect(midSlice.bytes.length, greaterThan(32768));

      final eofSlice = sliceOggOpusFromSeconds(
        track4Bytes,
        midSlice.totalDurationSeconds! - 0.10,
      );
      expect(eofSlice.isAtOrPastEof, isTrue);
      expect(eofSlice.bytes, isEmpty);
    });

    test(
        'SoloudAudioService cancels superseded in-flight loads and stopSlot mid-fetch without orphaned voices or leaked sources',
        () async {
      final backend = _FakeSoloudBackend();
      final track1Bytes =
          File('assets/audio/tracks/track_01.ogg').readAsBytesSync();
      final completers = <String, Completer<Uint8List?>>{
        'assets/audio/tracks/track_05.ogg': Completer<Uint8List?>(),
        'assets/audio/tracks/track_06.ogg': Completer<Uint8List?>(),
        'assets/audio/tracks/track_08.ogg': Completer<Uint8List?>(),
      };

      final service = SoloudAudioService(
        backend: backend,
        forceWebStreamingForTest: true,
        webByteLoader: (target) =>
            completers[target.uriOrPath]?.future ??
            Future<Uint8List?>.value(track1Bytes),
      );
      await service.unlockAndInitialize();
      expect(backend.activeHandles.length, 1); // Keep-alive voice only

      // Rapidly switch stage_a across track_05 -> track_06 -> track_08 while HTTP fetches are still in flight
      final f5 = service.syncStreamSlot(
        slotKey: 'stage_a',
        trackId: 'track_05',
        target: const ResolvedAudioTarget(
          uriOrPath: 'assets/audio/tracks/track_05.ogg',
          isBundledFlutterAsset: false,
        ),
        seekSeconds: 12.0,
        volume: 0.7,
        pan: -0.2,
      );
      final f6 = service.syncStreamSlot(
        slotKey: 'stage_a',
        trackId: 'track_06',
        target: const ResolvedAudioTarget(
          uriOrPath: 'assets/audio/tracks/track_06.ogg',
          isBundledFlutterAsset: false,
        ),
        seekSeconds: 20.0,
        volume: 0.75,
        pan: 0.0,
      );
      final f8 = service.syncStreamSlot(
        slotKey: 'stage_a',
        trackId: 'track_08',
        target: const ResolvedAudioTarget(
          uriOrPath: 'assets/audio/tracks/track_08.ogg',
          isBundledFlutterAsset: false,
        ),
        seekSeconds: 30.0,
        volume: 0.85,
        pan: 0.25,
      );

      // Complete superseded fetches out-of-order BEFORE and AFTER latest
      completers['assets/audio/tracks/track_05.ogg']!.complete(track1Bytes);
      await f5;
      expect(service.debugActiveStreams['stage_a'], isNull);

      completers['assets/audio/tracks/track_08.ogg']!.complete(track1Bytes);
      await f8;
      expect(service.debugActiveStreams['stage_a']?.trackId, 'track_08');

      completers['assets/audio/tracks/track_06.ogg']!.complete(track1Bytes);
      await f6;

      // Only 1 keep-alive + 1 active stream (track_08) may exist — zero leaked sources or ghost voices!
      expect(service.debugActiveStreams['stage_a']?.trackId, 'track_08');
      expect(backend.activeHandles.length, 2);
      expect(backend.liveSources.length, 2);

      // Now start loading a new track on stage_b and call stopSlot('stage_b') mid-fetch (e.g. opening Pinball)
      final stageBFetch = Completer<Uint8List?>();
      completers['assets/audio/tracks/track_09.ogg'] = stageBFetch;
      final fb = service.syncStreamSlot(
        slotKey: 'stage_b',
        trackId: 'track_09',
        target: const ResolvedAudioTarget(
          uriOrPath: 'assets/audio/tracks/track_09.ogg',
          isBundledFlutterAsset: false,
        ),
        seekSeconds: 5.0,
        volume: 0.8,
        pan: 0.0,
      );
      await service.stopSlot('stage_b');
      stageBFetch.complete(track1Bytes);
      await fb;

      expect(service.debugActiveStreams.containsKey('stage_b'), isFalse);
      expect(backend.activeHandles.length, 2);
      expect(backend.liveSources.length, 2);

      await service.dispose();
    });

    test(
        'SoloudAudioService rests cleanly at natural EOF on non-looping sets (no tail loop), scrubs on >3.5s jumps, and loops when looping=true',
        () async {
      final backend = _FakeSoloudBackend();
      final track3Bytes =
          File('assets/audio/tracks/track_03.ogg').readAsBytesSync();
      final service = SoloudAudioService(
        backend: backend,
        forceWebStreamingForTest: true,
        webByteLoader: (_) async => track3Bytes,
      );
      await service.unlockAndInitialize();

      const target = ResolvedAudioTarget(
        uriOrPath: 'assets/audio/tracks/track_03.ogg',
        isBundledFlutterAsset: true,
      );
      await service.syncStreamSlot(
        slotKey: 'stage_a',
        trackId: 'track_03',
        target: target,
        seekSeconds: 102.0,
        volume: 0.8,
        pan: 0.0,
        looping: false,
      );
      final initialPlays = backend.playCalls;
      final firstHandle = service.debugActiveStreams['stage_a']!.handle;

      // Simulate stream reaching natural EOF while festival clock is paused / near endMinute
      backend.activeHandles.remove(firstHandle.id);

      for (var tick = 0; tick < 10; tick++) {
        await service.syncStreamSlot(
          slotKey: 'stage_a',
          trackId: 'track_03',
          target: target,
          seekSeconds: 102.0 + tick * 0.05,
          volume: 0.8,
          pan: 0.0,
          looping: false,
        );
      }
      expect(
        backend.playCalls,
        initialPlays,
        reason:
            'Non-looping track must NEVER restart in a broken-record loop after natural EOF!',
      );
      expect(service.debugActiveStreams.containsKey('stage_a'), isFalse);

      // Explicit >3.5s scrub backward in Encore Control Deck resumes playback cleanly
      await service.syncStreamSlot(
        slotKey: 'stage_a',
        trackId: 'track_03',
        target: target,
        seekSeconds: 40.0,
        volume: 0.8,
        pan: 0.0,
        looping: false,
      );
      expect(backend.playCalls, initialPlays + 1);
      expect(service.debugActiveStreams['stage_a']?.trackId, 'track_03');

      // Looping stream (e.g. Campground Turntable) DOES cleanly start iteration 2 at natural EOF
      await service.syncStreamSlot(
        slotKey: 'turntable',
        trackId: 'track_03',
        target: target,
        seekSeconds: 0.0,
        volume: 0.9,
        pan: 0.0,
        looping: true,
      );
      final loopHandle1 = service.debugActiveStreams['turntable']!.handle;
      final playsBeforeLoopWrap = backend.playCalls;
      backend.activeHandles.remove(loopHandle1.id);

      await service.syncStreamSlot(
        slotKey: 'turntable',
        trackId: 'track_03',
        target: target,
        seekSeconds: 0.0,
        volume: 0.9,
        pan: 0.0,
        looping: true,
      );
      expect(backend.playCalls, playsBeforeLoopWrap + 1);
      expect(
        service.debugActiveStreams['turntable']!.handle.id,
        isNot(loopHandle1.id),
      );

      await service.dispose();
    });

    test(
        'SoloudAudioService enforces 2.5 MiB PCM backpressure on released BufferStreams until EOF',
        () async {
      final backend = _FakeSoloudBackend();
      final syntheticPayload = Uint8List(220000); // > 131072 initialBurst
      final service = SoloudAudioService(
        backend: backend,
        forceWebStreamingForTest: true,
        feederTickInterval: const Duration(milliseconds: 20),
        webByteLoader: (_) async => syntheticPayload,
      );
      await service.unlockAndInitialize();

      await service.syncStreamSlot(
        slotKey: 'stage_a',
        trackId: 'track_01',
        target: const ResolvedAudioTarget(
          uriOrPath: 'assets/audio/tracks/track_01.ogg',
          isBundledFlutterAsset: true,
        ),
        seekSeconds: 0.0,
        volume: 0.8,
        pan: 0.0,
      );

      final src =
          service.debugActiveStreams['stage_a']!.source as _FakeAudioSource;
      expect(backend.sourceBytesFed[src.debugId], 131072);

      // Simulate full 3.2 MiB decoded PCM buffer -> feeder MUST pause pushing chunks!
      backend.simulatedBufferedPcmBytes[src.debugId] = 3200000;
      await Future<void>.delayed(const Duration(milliseconds: 75));
      expect(backend.sourceBytesFed[src.debugId], 131072);
      expect(backend.endedSources.contains(src.debugId), isFalse);

      // Drain simulated PCM buffer below 2.5 MiB -> feeder resumes and finishes remaining bytes cleanly!
      backend.simulatedBufferedPcmBytes[src.debugId] = 1200000;
      await Future<void>.delayed(const Duration(milliseconds: 110));
      expect(backend.sourceBytesFed[src.debugId], syntheticPayload.length);
      expect(backend.endedSources.contains(src.debugId), isTrue);

      await service.dispose();
    });

    test(
        'Just Listen mode keeps Campground Double-LP Turntable audible anywhere in the orchard',
        () {
      final audio = _TrackingAudioService();
      final ctrl = AudioScheduleController(catalog: catalog, audio: audio);
      const settings = SettingsState();
      const day1Morning = FestivalClockState(day: 1, minuteOfDay: 500.0);

      // Far NW corner (120, 120) is >720 px from Campground Turntable (1072, 960)
      final snap = ctrl.update(
        dtSeconds: 0.05,
        clock: day1Morning,
        settings: settings,
        listenerX: 120.0,
        listenerY: 120.0,
        listenerInOcclusionZone: false,
        listenerInUndergrowthFog: false,
        turntableTrackNumber: 5,
        encoreAnywhereJukebox: false,
        justListenStageMode: true,
        onFiveMinuteBellAlert: null,
        onTrackHeardStamp: null,
      );
      expect(snap.primaryTrack?.trackNumber, 5);
      expect(snap.primaryMix?.isAudible, isTrue);
      expect(snap.primaryMix?.gain, closeTo(0.92, 0.001));
      expect(audio.activeSlots['turntable']?.trackId, 'track_05');
    });
  });
}
