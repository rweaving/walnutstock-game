import 'dart:async';
import '../data/models.dart';
import '../game/world/concert_light_show.dart';
import '../state/festival_clock.dart';
import '../state/settings_state.dart';
import 'fft_analyzer.dart';
import 'progressive_track_cache.dart';
import 'soloud_audio_service.dart';
import 'spatial_stage_emitter.dart';

class AudioScheduleSnapshot {
  const AudioScheduleSnapshot({
    this.primaryTrack,
    this.secondaryTrack,
    this.primaryMix,
    this.fft = const FftFrame(),
  });

  final ScheduledTrack? primaryTrack;
  final ScheduledTrack? secondaryTrack;
  final SpatialMixResult? primaryMix;
  final FftFrame fft;
}

class AudioScheduleController {
  AudioScheduleController({
    required this.catalog,
    required this.audio,
    this.lightshows = ConcertLightShowLibrary.empty,
  });

  static const List<String> _stageSlotPool = ['stage_a', 'stage_b'];

  final SetlistCatalog catalog;
  final SoloudAudioService audio;
  final ConcertLightShowLibrary lightshows;

  double _elapsedSeconds = 0.0;
  double _bellChimeCooldown = 0.0;
  final Set<String> _alertedFiveMinTrackIds = {};
  final Map<String, String> _slotToTrackId = {};
  AudioScheduleSnapshot _latest = const AudioScheduleSnapshot();

  AudioScheduleSnapshot get latest => _latest;

  /// Resolves the exact playback position in seconds for a scheduled track, preferring
  /// the live SoLoud stream voice clock when actively playing so animations & lights stay
  /// sample-synced to the speaker output, and falling back to schedule clock offset otherwise.
  double trackPositionSecondsFor(
    ScheduledTrack track,
    FestivalClockState clock,
  ) {
    final liveSec = audio.activePlaybackSecondsForTrack(track.id);
    if (liveSec != null) {
      if (track.durationSeconds > 1.0 && liveSec > track.durationSeconds) {
        return liveSec % track.durationSeconds;
      }
      return liveSec.clamp(0.0, track.durationSeconds);
    }
    return track.seekOffsetSeconds(
      clock.minuteOfDay,
      catalog.clockMinutesPerRealSecond,
    );
  }

  /// Exposed for unit tests verifying sticky multi-stage & PA slot assignments.
  Map<String, String> get debugActiveStageSlotAssignments =>
      Map.unmodifiable(_slotToTrackId);

  /// Updates concurrent multi-stage emitters, dedicated PA horn channel, arcade cabinet override,
  /// turntable jukebox override, and Undergrowth Lost-Woods stereo C-major bells.
  AudioScheduleSnapshot update({
    required double dtSeconds,
    required FestivalClockState clock,
    required SettingsState settings,
    required double listenerX,
    required double listenerY,
    required bool listenerInOcclusionZone,
    required bool listenerInUndergrowthFog,
    (double, double)? fogBeaconWorldPos,
    String? activeArcadeTrackId,
    required int? turntableTrackNumber,
    required bool encoreAnywhereJukebox,
    bool justListenStageMode = false,
    double outerGateMuffle = 0.0,
    required void Function(ScheduledTrack upcoming)? onFiveMinuteBellAlert,
    required void Function(ScheduledTrack liveTrack)? onTrackHeardStamp,
  }) {
    _elapsedSeconds += dtSeconds;
    final masterMusicGain = settings.masterVolume * settings.musicVolume;

    // Check 5-minute Stage Bell Alert (GDD §4.3)
    if (clock.wristbandAlertsEnabled && onFiveMinuteBellAlert != null) {
      for (final t in catalog.tracks) {
        if (t.day == clock.day && !_alertedFiveMinTrackIds.contains(t.id)) {
          final minsUntil = t.startMinute - clock.minuteOfDay;
          if (minsUntil > 0.0 && minsUntil <= 5.0) {
            _alertedFiveMinTrackIds.add(t.id);
            unawaited(
              audio.playSfx(
                'assets/audio/sfx/sfx_bell_alert.wav',
                volume: 0.55 * settings.masterVolume * settings.sfxVolume,
              ),
            );
            onFiveMinuteBellAlert(t);
          }
        }
      }
    }

    // 0. Optional Arcade Mini-Game Cabinet Soundtrack (Track 17 Pinball / Track 20 Sorting Belt)
    if (activeArcadeTrackId != null) {
      final arcadeTrack = catalog.trackById(activeArcadeTrackId);
      if (arcadeTrack != null) {
        onTrackHeardStamp?.call(arcadeTrack);
        audio.updateCanopyLowPass(18000.0);
        unawaited(
          audio.syncStreamSlot(
            slotKey: 'arcade_cabinet',
            trackId: arcadeTrack.id,
            target: audio.cache.resolveTrack(arcadeTrack),
            seekSeconds: 0.0,
            volume: 0.85 * masterMusicGain,
            pan: 0.0,
            looping: true,
          ),
        );
        for (final s in _stageSlotPool) {
          _slotToTrackId.remove(s);
          unawaited(audio.stopSlot(s));
        }
        unawaited(audio.stopSlot('pa_horn'));
        unawaited(audio.stopSlot('turntable'));
        unawaited(audio.stopSlot('vinyl_crackle'));

        const arcadeMix = SpatialMixResult(
          gain: 0.88,
          pan: 0.0,
          lowPassCutoffHz: 18000.0,
          distance: 0.0,
          isAudible: true,
        );
        final arcadePos = trackPositionSecondsFor(arcadeTrack, clock);
        final fftFrame = audio.fft.sample(
          timeSeconds: _elapsedSeconds,
          activeTracks: [arcadeTrack],
          audibleStageGain: arcadeMix.gain,
          scannedShowFrame: lightshows.isEmpty
              ? null
              : lightshows.sampleTrack(arcadeTrack, arcadePos),
        );
        _latest = AudioScheduleSnapshot(
          primaryTrack: arcadeTrack,
          primaryMix: arcadeMix,
          fft: fftFrame,
        );
        return _latest;
      }
    }
    unawaited(audio.stopSlot('arcade_cabinet'));

    // 1. Optional Campground Double-LP Turntable Override
    if (turntableTrackNumber != null) {
      final recordTrack = catalog.trackByNumber(turntableTrackNumber);
      final turntableStage = catalog.stages['campground_turntable'];
      if (recordTrack != null && turntableStage != null) {
        final mix = (encoreAnywhereJukebox || justListenStageMode)
            ? const SpatialMixResult(
                gain: 0.92,
                pan: 0.0,
                lowPassCutoffHz: 18000.0,
                distance: 0.0,
                isAudible: true,
              )
            : SpatialStageEmitter.computeMix(
                stage: turntableStage,
                listenerX: listenerX,
                listenerY: listenerY,
                listenerInOcclusionZone: false,
                isPaBroadcastTrack: false,
                paBroadcastCurrentlyActive: false,
              );

        if (mix.isAudible) {
          onTrackHeardStamp?.call(recordTrack);
          // Ensure global canopy low-pass never muffles the Campground Turntable!
          audio.updateCanopyLowPass(18000.0);
          unawaited(
            audio.syncStreamSlot(
              slotKey: 'turntable',
              trackId: recordTrack.id,
              target: audio.cache.resolveTrack(recordTrack),
              seekSeconds: 0.0,
              volume: mix.gain * masterMusicGain,
              pan: mix.pan,
              looping: true,
            ),
          );
          if (settings.vinylCrackleEnabled) {
            unawaited(
              audio.syncStreamSlot(
                slotKey: 'vinyl_crackle',
                trackId: 'vinyl_crackle',
                target: const ResolvedAudioTarget(
                  uriOrPath: 'assets/audio/sfx/sfx_vinyl_crackle.wav',
                  isBundledFlutterAsset: true,
                ),
                seekSeconds: 0.0,
                volume: 0.18 * mix.gain * masterMusicGain,
                pan: mix.pan,
                looping: true,
              ),
            );
          } else {
            unawaited(audio.stopSlot('vinyl_crackle'));
          }
          for (final s in _stageSlotPool) {
            _slotToTrackId.remove(s);
            unawaited(audio.stopSlot(s));
          }
          unawaited(audio.stopSlot('pa_horn'));

          final recordPos = trackPositionSecondsFor(recordTrack, clock);
          final fftFrame = audio.fft.sample(
            timeSeconds: _elapsedSeconds,
            activeTracks: [recordTrack],
            audibleStageGain: mix.gain,
            scannedShowFrame: lightshows.isEmpty
                ? null
                : lightshows.sampleTrack(recordTrack, recordPos),
          );
          _latest = AudioScheduleSnapshot(
            primaryTrack: recordTrack,
            primaryMix: mix,
            fft: fftFrame,
          );
          return _latest;
        }
      }
    }
    unawaited(audio.stopSlot('turntable'));
    unawaited(audio.stopSlot('vinyl_crackle'));

    // 2. Concurrent Scheduled Multi-Stage Playback + Dedicated PA Horn Channel
    final activeTracks = catalog.activeTracksAt(clock.day, clock.minuteOfDay);
    final paTrack = activeTracks.where((t) => t.isPaBroadcast).firstOrNull;
    final paActive = paTrack != null;

    // 2a. Dedicated PA Horn Broadcast Slot (never evicts or thrashes live stages!)
    SpatialMixResult? paMix;
    if (paTrack != null) {
      final paStage =
          catalog.stages[paTrack.stageId] ?? catalog.stages.values.first;
      paMix = SpatialStageEmitter.computeMix(
        stage: paStage,
        listenerX: listenerX,
        listenerY: listenerY,
        listenerInOcclusionZone: false,
        isPaBroadcastTrack: true,
        paBroadcastCurrentlyActive: true,
      );
      final paSeek = paTrack.seekOffsetSeconds(
        clock.minuteOfDay,
        catalog.clockMinutesPerRealSecond,
      );
      if (paTrack.trackNumber >= 1) {
        onTrackHeardStamp?.call(paTrack);
      }
      unawaited(
        audio.syncStreamSlot(
          slotKey: 'pa_horn',
          trackId: paTrack.id,
          target: audio.cache.resolveTrack(paTrack),
          seekSeconds: paSeek,
          volume: paMix.gain * masterMusicGain,
          pan: paMix.pan,
          looping: paTrack.assetPath.endsWith('.wav'),
        ),
      );
    } else {
      unawaited(audio.stopSlot('pa_horn'));
    }

    // 2b. Sticky 2-Slot Concurrent Stage Emitter Pool (zero reload when crossing midpoint!)
    final stageScored = <({ScheduledTrack track, SpatialMixResult mix})>[];
    for (final t in activeTracks) {
      if (t.isPaBroadcast) continue;
      final stage = catalog.stages[t.stageId] ?? catalog.stages.values.first;
      var mix = SpatialStageEmitter.computeMix(
        stage: stage,
        listenerX: listenerX,
        listenerY: listenerY,
        listenerInOcclusionZone: listenerInOcclusionZone,
        isPaBroadcastTrack: false,
        paBroadcastCurrentlyActive: paActive,
      );
      if (justListenStageMode && mix.gain < 0.88) {
        final boostGain =
            paActive ? 0.88 * SpatialStageEmitter.paBroadcastDuckLinear : 0.88;
        mix = SpatialMixResult(
          gain: boostGain,
          pan: 0.0,
          lowPassCutoffHz: 18000.0,
          distance: mix.distance,
          isAudible: true,
        );
      } else if (outerGateMuffle > 0.01 && mix.isAudible) {
        final m = outerGateMuffle.clamp(0.0, 1.0);
        final attenuatedGain = mix.gain * (1.0 - 0.46 * m);
        final muffledCutoff =
            mix.lowPassCutoffHz + (680.0 - mix.lowPassCutoffHz) * m;
        mix = SpatialMixResult(
          gain: attenuatedGain,
          pan: mix.pan * (1.0 - 0.35 * m),
          lowPassCutoffHz: muffledCutoff.clamp(520.0, 18000.0),
          distance: mix.distance,
          isAudible: attenuatedGain >= 0.015,
        );
      }
      stageScored.add((track: t, mix: mix));
    }
    stageScored.sort((a, b) => b.mix.gain.compareTo(a.mix.gain));

    final topAudible = stageScored
        .where((e) => e.mix.isAudible)
        .take(_stageSlotPool.length)
        .toList(growable: false);
    final desiredIds = topAudible.map((e) => e.track.id).toSet();

    // Release any slot whose track is no longer in topAudible
    for (final slotKey in _stageSlotPool) {
      final assignedId = _slotToTrackId[slotKey];
      if (assignedId != null && !desiredIds.contains(assignedId)) {
        _slotToTrackId.remove(slotKey);
        unawaited(audio.stopSlot(slotKey));
      }
    }

    // Sync each audible stage track onto its existing sticky slot (or an open slot)
    for (final entry in topAudible) {
      var slotKey = _slotToTrackId.entries
          .where((kv) => kv.value == entry.track.id)
          .map((kv) => kv.key)
          .firstOrNull;
      if (slotKey == null) {
        slotKey = _stageSlotPool.firstWhere(
          (s) => !_slotToTrackId.containsKey(s),
          orElse: () => _stageSlotPool.first,
        );
        _slotToTrackId[slotKey] = entry.track.id;
      }

      final seekSec = entry.track.seekOffsetSeconds(
        clock.minuteOfDay,
        catalog.clockMinutesPerRealSecond,
      );
      if (entry.mix.gain > 0.18 && entry.track.trackNumber >= 1) {
        onTrackHeardStamp?.call(entry.track);
      }
      unawaited(
        audio.syncStreamSlot(
          slotKey: slotKey,
          trackId: entry.track.id,
          target: audio.cache.resolveTrack(entry.track),
          seekSeconds: seekSec,
          volume: entry.mix.gain * masterMusicGain,
          pan: entry.mix.pan,
          looping: entry.track.assetPath.endsWith('.wav'),
        ),
      );
    }

    // Ensure unused slots are stopped
    for (final slotKey in _stageSlotPool) {
      if (!_slotToTrackId.containsKey(slotKey)) {
        unawaited(audio.stopSlot(slotKey));
      }
    }

    // Only engage canopy low-pass filter when an audible non-PA stage is playing
    if (!paActive && topAudible.isNotEmpty) {
      audio.updateCanopyLowPass(topAudible.first.mix.lowPassCutoffHz);
    } else {
      audio.updateCanopyLowPass(18000.0);
    }

    // 3. Tula Twigwalker's Stereo C-Major Bell Beacon inside Zone 7 Psych-Rock Fog
    if (listenerInUndergrowthFog) {
      _bellChimeCooldown -= dtSeconds;
      if (_bellChimeCooldown <= 0.0) {
        _bellChimeCooldown = 2.6;
        final baseBell = catalog.stages['undergrowth_bells'];
        if (baseBell != null) {
          final beaconStage = fogBeaconWorldPos != null
              ? StageInfo(
                  id: baseBell.id,
                  name: baseBell.name,
                  zone: baseBell.zone,
                  x: fogBeaconWorldPos.$1,
                  y: fogBeaconWorldPos.$2,
                  minDist: baseBell.minDist,
                  maxDist: baseBell.maxDist,
                )
              : baseBell;
          final bellMix = SpatialStageEmitter.computeMix(
            stage: beaconStage,
            listenerX: listenerX,
            listenerY: listenerY,
            listenerInOcclusionZone: false,
            isPaBroadcastTrack: false,
            paBroadcastCurrentlyActive: paActive,
          );
          if (bellMix.isAudible) {
            unawaited(
              audio.playSfx(
                'assets/audio/sfx/sfx_bell_cmajor.wav',
                volume: (0.24 + 0.68 * bellMix.gain) *
                    settings.masterVolume *
                    settings.sfxVolume,
                pan: bellMix.pan,
              ),
            );
          }
        }
      }
    }

    final ScheduledTrack? primary = paTrack ??
        (topAudible.isNotEmpty
            ? topAudible.first.track
            : (stageScored.isNotEmpty ? stageScored.first.track : null));
    final ScheduledTrack? secondary = paTrack != null
        ? (topAudible.isNotEmpty ? topAudible.first.track : null)
        : (topAudible.length > 1 ? topAudible[1].track : null);
    final SpatialMixResult? primaryMix = paMix ??
        (topAudible.isNotEmpty
            ? topAudible.first.mix
            : (stageScored.isNotEmpty ? stageScored.first.mix : null));

    final fftTrack = topAudible.isNotEmpty ? topAudible.first.track : primary;
    final fftShow = (fftTrack != null && !lightshows.isEmpty)
        ? lightshows.sampleTrack(
            fftTrack,
            trackPositionSecondsFor(fftTrack, clock),
          )
        : null;
    final fftFrame = audio.fft.sample(
      timeSeconds: _elapsedSeconds,
      activeTracks: activeTracks,
      audibleStageGain: topAudible.isNotEmpty
          ? topAudible.first.mix.gain
          : (paMix?.gain ?? 0.0),
      scannedShowFrame: fftShow,
    );

    _latest = AudioScheduleSnapshot(
      primaryTrack: primary,
      secondaryTrack: secondary,
      primaryMix: primaryMix,
      fft: fftFrame,
    );
    return _latest;
  }
}
