import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:walnutstock/audio/spatial_stage_emitter.dart';
import 'package:walnutstock/data/models.dart';
import 'package:walnutstock/state/festival_clock.dart';

void main() {
  late SetlistCatalog catalog;

  setUpAll(() {
    final raw = File('assets/data/setlist_26_tracks.json').readAsStringSync();
    catalog = SetlistCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  group('FestivalClock & 26+4 Track Multi-Stage Schedule', () {
    test(
        'contains all 26 numbered album tracks + 5AM prelude + 3 Midnight bonus stems without truncation',
        () {
      final clock = FestivalClockNotifier(catalog);
      for (var n = 1; n <= 26; n++) {
        final track = catalog.trackByNumber(n);
        expect(track, isNotNull, reason: 'Missing album track #$n');
        expect(
          track!.endMinute,
          lessThan(clock.dayEndMinuteFor(track.day)),
          reason:
              'Track #$n (${track.title}) truncated by day ${track.day} end bound!',
        );
      }

      // Prelude + 3 Midnight bonus cuts
      expect(catalog.trackById('track_00'), isNotNull);
      expect(catalog.trackById('track_27_dembow'), isNotNull);
      expect(catalog.trackById('track_28_drupe'), isNotNull);
      expect(catalog.trackById('track_29_omega'), isNotNull);

      for (final bonusId in [
        'track_27_dembow',
        'track_28_drupe',
        'track_29_omega'
      ]) {
        final t = catalog.trackById(bonusId)!;
        expect(t.endMinute, lessThan(clock.dayEndMinuteFor(t.day)));
      }
    });

    test(
        'concurrent Saturday Midnight sets play simultaneously on Urbano & Andromeda stages',
        () {
      final midnightActive = catalog.activeTracksAt(2, 1445.0);
      final stageIds = midnightActive.map((t) => t.stageId).toSet();
      expect(stageIds, contains('urbano_canopy_stage'));
      expect(stageIds, contains('andromeda_pavilion_stage'));
    });

    test(
        'jumpToNextScheduledSet reaches Track 26 (Foxy Nutlady) and advancing Day 3 unlocks Encore Mode',
        () {
      final clock = FestivalClockNotifier(catalog);
      final visitedNumbers = <int>{};
      for (var i = 0; i < 40; i++) {
        final jumped = clock.jumpToNextScheduledSet();
        expect(jumped, isNotNull);
        visitedNumbers.add(jumped!.trackNumber);
        if (jumped.trackNumber == 26) break;
      }
      expect(visitedNumbers, contains(10));
      expect(visitedNumbers, contains(25));
      expect(visitedNumbers, contains(26));

      // Advance past end of Day 3 -> unlocks Endless Encore Mode
      final track26 = catalog.trackByNumber(26)!;
      clock.setClockDirect(day: 3, minuteOfDay: track26.endMinute);
      clock.advanceMinutes(30.0);
      expect(clock.state.encoreModeUnlocked, isTrue);
    });

    test(
        'Saturday rainstorm & 3-hour Bittershell warning align with Track 15 and clear on Track 18',
        () {
      final clock = FestivalClockNotifier(catalog);
      final track15 = catalog.trackByNumber(15)!; // Bad Moon Risin'
      final track18 = catalog.trackByNumber(18)!; // Stage Announcement 4

      // 2.5 hours before Track 15 -> preStormHumid (Bittershell's itching sutures!)
      clock.setClockDirect(day: 2, minuteOfDay: track15.startMinute - 150.0);
      expect(clock.state.weather, WeatherPhase.preStormHumid);
      expect(clock.areDirtPathsMuddy, isFalse);

      // During Track 15 -> blightRainstorm + muddy paths
      clock.setClockDirect(day: 2, minuteOfDay: track15.startMinute + 10.0);
      expect(clock.state.weather, WeatherPhase.blightRainstorm);
      expect(clock.areDirtPathsMuddy, isTrue);

      // Sunday morning before Track 18 ends -> postStormMist + still muddy
      clock.setClockDirect(day: 3, minuteOfDay: track18.startMinute + 5.0);
      expect(clock.state.weather, WeatherPhase.postStormMist);
      expect(clock.areDirtPathsMuddy, isTrue);

      // After Track 18 -> clear dry paths!
      clock.setClockDirect(day: 3, minuteOfDay: track18.endMinute + 5.0);
      expect(clock.state.weather, WeatherPhase.clear);
      expect(clock.areDirtPathsMuddy, isFalse);
    });

    test(
        'SpatialStageEmitter computes attenuation, stereo pan, canopy LPF, and -9dB PA ducking',
        () {
      final mainRoots = catalog.stages['main_roots_stage']!;

      // Front row center -> full gain, centered pan, open 18kHz LPF
      final frontRow = SpatialStageEmitter.computeMix(
        stage: mainRoots,
        listenerX: mainRoots.x,
        listenerY: mainRoots.y + 40.0,
        listenerInOcclusionZone: false,
        isPaBroadcastTrack: false,
        paBroadcastCurrentlyActive: false,
      );
      expect(frontRow.gain, closeTo(1.0, 0.001));
      expect(frontRow.pan, closeTo(0.0, 0.001));
      expect(frontRow.lowPassCutoffHz, 18000.0);

      // Inside occluded tent & PA Horn active -> 420Hz LPF + -9dB ducking
      final occludedDucked = SpatialStageEmitter.computeMix(
        stage: mainRoots,
        listenerX: mainRoots.x - 200.0,
        listenerY: mainRoots.y + 180.0,
        listenerInOcclusionZone: true,
        isPaBroadcastTrack: false,
        paBroadcastCurrentlyActive: true,
      );
      expect(
          occludedDucked.pan, greaterThan(0.3)); // Stage is to the right (+X)
      expect(occludedDucked.lowPassCutoffHz, 420.0);
      expect(occludedDucked.gain, lessThan(0.35));

      // Outside maxDist -> inaudible
      final farAway = SpatialStageEmitter.computeMix(
        stage: mainRoots,
        listenerX: mainRoots.x + 1200.0,
        listenerY: mainRoots.y + 900.0,
        listenerInOcclusionZone: false,
        isPaBroadcastTrack: false,
        paBroadcastCurrentlyActive: false,
      );
      expect(farAway.isAudible, isFalse);
      expect(farAway.gain, 0.0);
    });
  });
}
