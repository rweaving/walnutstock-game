import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart' show Vector2;
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walnutstock/app/walnutstock_app.dart';
import 'package:walnutstock/audio/soloud_audio_service.dart';
import 'package:walnutstock/data/models.dart';
import 'package:walnutstock/game/actors/stage_performer_director.dart';
import 'package:walnutstock/game/shaders/shader_post_processor.dart';
import 'package:walnutstock/game/walnutstock_game.dart';
import 'package:walnutstock/game/world/concert_light_show.dart';
import 'package:walnutstock/game/world/day_night_atmosphere.dart';
import 'package:walnutstock/game/world/electric_blueberry_experience_component.dart';
import 'package:walnutstock/game/world/stage_3d_rig_component.dart';
import 'package:walnutstock/game/world/tiled_map_parser.dart';
import 'package:walnutstock/state/dialogue_and_overlay_state.dart';
import 'package:walnutstock/state/festival_clock.dart';
import 'package:walnutstock/state/providers.dart';
import 'package:walnutstock/state/save_repository.dart';
import 'package:walnutstock/state/world_flags.dart';

void main() {
  late String tmx;
  late String tsx;
  late FestivalDataBundle bundle;
  late OrchardMapData map;

  setUpAll(() {
    tmx = File('assets/tiles/free_orchard_full.tmx').readAsStringSync();
    tsx = File('assets/tiles/orchard_tileset.tsx').readAsStringSync();

    final setlistJson = jsonDecode(
      File('assets/data/setlist_26_tracks.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final npcsJson = jsonDecode(
      File('assets/data/npcs_and_quests.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final lightshowsJson = jsonDecode(
      File('assets/data/track_lightshows.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    bundle = FestivalDataBundle.fromJsonMaps(
      setlistJson: setlistJson,
      npcsJson: npcsJson,
      lightshowsJson: lightshowsJson,
    );
  });

  setUp(() {
    map = TiledMapParser.parseTmxAndTsx(tmxXmlString: tmx, tsxXmlString: tsx);
  });

  group('On-Stage Live Performers & Band Ensembles Across All 30 Tracks', () {
    test(
        'every single scheduled track (30/30) places live performers on non-blocked stage coordinates',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final container = ProviderContainer(
        overrides: [
          festivalDataProvider.overrideWithValue(bundle),
          saveRepositoryProvider.overrideWithValue(SaveRepository()),
        ],
      );
      addTearDown(container.dispose);

      final game = WalnutstockGame(
        container: container,
        data: bundle,
        mapData: map,
        audioService: SoloudAudioService(),
      );
      game.onGameResize(Vector2(960, 640));
      await game.onLoad();

      expect(bundle.setlist.tracks.length, 30);

      for (final track in bundle.setlist.tracks) {
        final midMinute = (track.startMinute + track.endMinute) * 0.5;
        container
            .read(festivalClockProvider.notifier)
            .setClockDirect(day: track.day, minuteOfDay: midMinute);
        game.update(0.05);

        expect(
          game.liveStageIds,
          contains(track.stageId),
          reason:
              'Track #${track.trackNumber} (${track.title}) should activate ${track.stageId}',
        );

        final stageNpcIds = game.activeStagePerformerNpcIds;
        final stageBand = game.activeEnsemblePerformers
            .where((m) => m.stageId == track.stageId)
            .toList();

        expect(
          stageNpcIds.isNotEmpty || stageBand.isNotEmpty,
          isTrue,
          reason:
              'Track #${track.trackNumber} (${track.artist}) had no performers on ${track.stageId}',
        );

        for (final npcId in stageNpcIds) {
          final actor = game.npcActorById(npcId)!;
          expect(
            map.isPointBlocked(actor.position.x, actor.position.y),
            isFalse,
            reason:
                'Performing NPC $npcId blocked at (${actor.position.x}, ${actor.position.y}) on Track #${track.trackNumber}',
          );
        }
        for (final member in stageBand) {
          expect(
            map.isPointBlocked(member.stagePos.dx, member.stagePos.dy),
            isFalse,
            reason:
                'Ensemble member ${member.id} blocked at ${member.stagePos} on Track #${track.trackNumber}',
          );
        }
      }
    });

    test(
        'headliners & ensembles swap stages accurately, dual-stage midnight works, and performers step off-stage between sets',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final container = ProviderContainer(
        overrides: [
          festivalDataProvider.overrideWithValue(bundle),
          saveRepositoryProvider.overrideWithValue(SaveRepository()),
        ],
      );
      addTearDown(container.dispose);

      final game = WalnutstockGame(
        container: container,
        data: bundle,
        mapData: map,
        audioService: SoloudAudioService(),
      );
      game.onGameResize(Vector2(960, 640));
      await game.onLoad();

      final clockN = container.read(festivalClockProvider.notifier);

      // 1. Track 1 (Day 1, 500.0): Nutcracker Joe & The Hull Band 4-piece on Main Roots; Jimi & Literally Infinite off-stage!
      clockN.setClockDirect(day: 1, minuteOfDay: 500.0);
      game.update(0.05);
      final li = game.npcActorById('literally_infinite')!;
      final jimi = game.npcActorById('jimi_hendshell')!;
      expect(
        game.activeEnsemblePerformers.map((e) => e.id),
        containsAll([
          'nutcracker_joe_lead',
          'hullband_guitar',
          'hullband_bass',
          'hullband_drums',
        ]),
      );
      expect(li.position.y, greaterThan(448.0)); // Off wooden stage deck until Track 10!
      expect(jimi.position.y, greaterThan(448.0)); // Off wooden stage deck!
      expect(game.activeEnsemblePerformers.length, 4);

      // 1b. Track 10 (Day 1, 1500.0): Mountain Grove ("I Think of Walnuts") + Literally Infinite guest organ!
      clockN.setClockDirect(day: 1, minuteOfDay: 1500.0);
      game.update(0.05);
      expect(game.activeStagePerformerNpcIds, contains('literally_infinite'));
      expect(map.surfaceAtWorld(li.position.x, li.position.y), 'wood_stage');
      expect(
        game.activeEnsemblePerformers.map((e) => e.id),
        contains('mountain_leslie_lead'),
      );

      // 2. Track 5 (Day 1, 860.0): Joan Baezelnut & Barnaby Breeze-Walker duet on Mellow Meadow!
      clockN.setClockDirect(day: 1, minuteOfDay: 860.0);
      game.update(0.05);
      expect(
        game.activeStagePerformerNpcIds,
        containsAll(['joan_baezelnut', 'barnaby_breezewalker']),
      );
      expect(li.position.y, greaterThan(448.0)); // Literally Infinite stepped off-stage!

      // 3. Quiet intermission gap (Day 2, 550.0): all stages clear!
      clockN.setClockDirect(day: 2, minuteOfDay: 550.0);
      game.update(0.05);
      expect(game.liveStageIds, isEmpty);
      expect(game.activeStagePerformerNpcIds, isEmpty);
      expect(game.activeEnsemblePerformers, isEmpty);

      // 4. Continuous A* walk-on before & into Janice Joeplant's Track 12 (Day 2, 705.0 -> 710.0)
      final janice = game.npcActorById('janice_joeplant')!;
      clockN.setClockDirect(day: 2, minuteOfDay: 650.0);
      game.update(0.05);
      expect(janice.position.y, closeTo(424.0, 2.0)); // Off-stage before soundcheck

      // Use small step advances from 705.0 -> ~712.0 to verify smooth A* walk onto Velvet Canopy deck
      clockN.setClockDirect(day: 2, minuteOfDay: 705.0);
      game.update(0.05);
      for (var i = 0; i < 60; i++) {
        clockN.advanceMinutes(0.06);
        game.update(0.1);
      }
      expect(janice.isOnStagePerforming, isTrue);
      expect(
        map.surfaceAtWorld(janice.position.x, janice.position.y),
        'wood_stage',
      );

      // Step smoothly past the end of Track 12 (845.7) to verify continuous A* walk back off-stage!
      clockN.setClockDirect(day: 2, minuteOfDay: 845.2);
      game.update(0.05);
      expect(janice.isOnStagePerforming, isTrue);
      for (var i = 0; i < 40; i++) {
        clockN.advanceMinutes(0.05);
        game.update(0.1);
      }
      expect(janice.isOnStagePerforming, isFalse);
      expect(janice.position.y, closeTo(424.0, 4.0));

      // 5. Track 15 (Day 2, 1100.0): Creedence Shellwater 4-piece band rocks Main Roots during Rainstorm!
      clockN.setClockDirect(day: 2, minuteOfDay: 1100.0);
      game.update(0.05);
      expect(container.read(festivalClockProvider).effectiveWeather,
          WeatherPhase.blightRainstorm);
      expect(
        game.activeEnsemblePerformers.map((e) => e.id),
        containsAll(['ccr_fogerty_lead', 'ccr_drums', 'ccr_bass']),
      );

      // 6. Saturday Midnight (Day 2, 1450.0): Simultaneous Urbano (Don Shell-O) & Andromeda (Cosmo)!
      clockN.setClockDirect(day: 2, minuteOfDay: 1450.0);
      game.update(0.05);
      expect(
        game.liveStageIds,
        containsAll(['urbano_canopy_stage', 'andromeda_pavilion_stage']),
      );
      expect(
        game.activeStagePerformerNpcIds,
        containsAll(['don_shello', 'cosmo_shellvoy']),
      );

      // 7. Sunday Night Finale Track 25 (Day 3, 1400.0): Jimi Hendshell headlines Main Roots Stage!
      clockN.setClockDirect(day: 3, minuteOfDay: 1400.0);
      game.update(0.05);
      expect(game.activeStagePerformerNpcIds, contains('jimi_hendshell'));
      expect(map.surfaceAtWorld(jimi.position.x, jimi.position.y), 'wood_stage');
    });

    test(
        'Stage-front festivalgoers dance synced across all 5 live stages, join nearby player dancing, and PlayerWalnut locks bounce & footwork to StageShowFrame beats',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final container = ProviderContainer(
        overrides: [
          festivalDataProvider.overrideWithValue(bundle),
          saveRepositoryProvider.overrideWithValue(SaveRepository()),
        ],
      );
      addTearDown(container.dispose);

      container.read(playerProfileProvider.notifier)
        ..selectCultivar('japonica_heartnut')
        ..unlockWardrobe('velvet_bellbottom_coat', autoEquip: true);

      final game = WalnutstockGame(
        container: container,
        data: bundle,
        mapData: map,
        audioService: SoloudAudioService(),
      );
      game.onGameResize(Vector2(960, 640));
      await game.onLoad();

      final clockN = container.read(festivalClockProvider.notifier);

      // 1. Verify stage-front crowd dancers groove at all 5 festival stages when live!
      const stageFrontDancersByStage = <String, List<String>>{
        'main_roots_stage': [
          'sunny_shellflower',
          'hazel_groove',
          'barnaby_bittershell',
        ],
        'velvet_canopy_stage': [
          'roxie_roast',
          'saffron_suture',
          'raymond_walnut',
        ],
        'urbano_canopy_stage': [
          'mateo_cascara',
          'paloma_hull',
          'wen_wan_elder',
        ],
        'andromeda_pavilion_stage': [
          'astra_nebula',
          'orion_kernel',
          'elsie_walnut',
        ],
        'mellow_meadow_stage': [
          'clover_husk',
          'pippin_pecan',
        ],
      };

      for (final entry in stageFrontDancersByStage.entries) {
        final track = bundle.setlist.tracks.firstWhere(
          (t) => t.stageId == entry.key,
        );
        final midMin = (track.startMinute + track.endMinute) * 0.5;
        clockN.setClockDirect(day: track.day, minuteOfDay: midMin);
        game.update(0.05);

        for (final npcId in entry.value) {
          final actor = game.npcActorById(npcId)!;
          expect(
            actor.isDancingNearStage,
            isTrue,
            reason:
                '$npcId should dance near live ${entry.key} during Track #${track.trackNumber}',
          );
          expect(actor.nearbyStageShow, isNotNull);

          // Render dancing NPC cleanly without throwing
          final rec = ui.PictureRecorder();
          actor.render(Canvas(rec));
          rec.endRecording().dispose();
        }
      }

      // 2. Quiet intermission gap (Day 2, 550.0): stage-front NPCs stop dancing until player dances nearby!
      clockN.setClockDirect(day: 2, minuteOfDay: 550.0);
      game.update(0.05);
      final sunny = game.npcActorById('sunny_shellflower')!;
      expect(sunny.isDancingNearStage, isFalse);

      game.teleportPlayer(sunny.position.x + 28.0, sunny.position.y);
      game.togglePlayerDanceGroove();
      game.update(0.05);
      expect(container.read(worldFlagsProvider).playerDancing, isTrue);
      expect(sunny.isDancingNearStage, isTrue);

      // 3. Player standing in front of live Main Roots Stage (Track 1) syncs bounce & footwork to exact beat grid!
      clockN.setClockDirect(day: 1, minuteOfDay: 500.0);
      game.teleportPlayer(608.0, 480.0);
      game.update(0.1);

      final player = game.player!;
      expect(player.isDancing, isTrue);
      expect(player.activeMusicShow, isNotNull);
      expect(player.crowdAura, greaterThan(0.0));

      final track1 = bundle.setlist.trackByNumber(1)!;
      final probeFrame = bundle.lightshows.sampleTrack(track1, 12.0);
      final beatPeriodSec = 60.0 / probeFrame.bpm;
      final beatStartSec = 12.0 - probeFrame.beatPhase * beatPeriodSec;
      final onBeatTime = beatStartSec + beatPeriodSec * 1.04;
      final offBeatTime = beatStartSec + beatPeriodSec * 1.92;
      final nextBeatTime = beatStartSec + beatPeriodSec * 2.04;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      player.activeMusicShow = bundle.lightshows.sampleTrack(track1, onBeatTime);
      player.render(canvas);
      final downbeatBounce = player.lastDanceBounceY;
      final beatACol = player.lastRenderedFrameCol;

      player.activeMusicShow =
          bundle.lightshows.sampleTrack(track1, offBeatTime);
      player.render(canvas);
      final lateBeatBounce = player.lastDanceBounceY;

      player.activeMusicShow =
          bundle.lightshows.sampleTrack(track1, nextBeatTime);
      player.render(canvas);
      final beatBCol = player.lastRenderedFrameCol;

      // Render all 4 player dance styles + starter outfits cleanly
      for (var style = 0; style < 4; style++) {
        game.cyclePlayerDanceMove();
        game.update(0.02);
        player.render(canvas);
      }
      recorder.endRecording().dispose();

      expect(downbeatBounce, greaterThan(2.0));
      expect(downbeatBounce, greaterThan(lateBeatBounce * 2.0));
      expect(beatACol, isNot(equals(beatBCol)));
    });
  });

  group('Continuous Day/Night Progression, Rainstorm Arc & 3D Rendering', () {
    test(
        'DayNightMetrics transitions smoothly across Dawn, Midday, Golden Hour, Dusk, Night & Rainstorm',
        () {
      final dawn = DayNightMetrics.compute(
        const FestivalClockState(day: 1, minuteOfDay: 355.0),
        timeSeconds: 1.0,
      );
      final midday = DayNightMetrics.compute(
        const FestivalClockState(day: 1, minuteOfDay: 750.0),
        timeSeconds: 1.0,
      );
      final golden = DayNightMetrics.compute(
        const FestivalClockState(day: 1, minuteOfDay: 1080.0),
        timeSeconds: 1.0,
      );
      final dusk = DayNightMetrics.compute(
        const FestivalClockState(day: 1, minuteOfDay: 1165.0),
        timeSeconds: 1.0,
      );
      final night = DayNightMetrics.compute(
        const FestivalClockState(day: 1, minuteOfDay: 1380.0),
        timeSeconds: 1.0,
      );

      // Solar shadow vector sweeps West (dawn) -> compact center (midday) -> East (golden hour)
      expect(dawn.shadowOffset.dx, lessThan(-4.5));
      expect(midday.shadowOffset.dx.abs(), lessThan(2.0));
      expect(golden.shadowOffset.dx, greaterThan(5.0));

      // Darkness ramps monotonically from midday -> golden hour -> dusk -> midnight
      expect(midday.darknessFactor, closeTo(0.0, 0.01));
      expect(golden.darknessFactor, greaterThan(midday.darknessFactor));
      expect(dusk.darknessFactor, greaterThan(golden.darknessFactor));
      expect(night.darknessFactor, greaterThan(dusk.darknessFactor));
      expect(night.starlightAlpha, greaterThan(0.6));
      expect(night.lanternGlowStrength, greaterThan(0.95));

      // Saturday Pre-Storm Humid -> Blight Rainstorm -> Sunday Post-Storm Sunbeams
      final preEarly = DayNightMetrics.compute(
        const FestivalClockState(
          day: 2,
          minuteOfDay: 920.0,
          weather: WeatherPhase.preStormHumid,
        ),
        timeSeconds: 2.0,
        stormStartMinute: 1079.43,
      );
      final preLate = DayNightMetrics.compute(
        const FestivalClockState(
          day: 2,
          minuteOfDay: 1065.0,
          weather: WeatherPhase.preStormHumid,
        ),
        timeSeconds: 2.0,
        stormStartMinute: 1079.43,
      );
      final storm = DayNightMetrics.compute(
        const FestivalClockState(
          day: 2,
          minuteOfDay: 1100.0,
          weather: WeatherPhase.blightRainstorm,
        ),
        timeSeconds: 0.2, // Non-lightning instant
        stormStartMinute: 1079.43,
      );
      final sundaySunMist = DayNightMetrics.compute(
        const FestivalClockState(
          day: 3,
          minuteOfDay: 490.0,
          weather: WeatherPhase.postStormMist,
        ),
        timeSeconds: 2.0,
      );

      expect(preLate.stormBuildUp, greaterThan(preEarly.stormBuildUp));
      expect(preLate.windStrength, greaterThan(preEarly.windStrength));
      expect(storm.rainIntensity, 1.0);
      expect(storm.wetness, 1.0);
      expect(storm.darknessFactor, greaterThan(0.50));
      expect(sundaySunMist.mistIntensity, greaterThan(0.25));
      expect(sundaySunMist.sunbeamIntensity, greaterThan(0.20));
    });

    test(
        '3D world & lightmap render cleanly across all time-of-day & rainstorm phases without exceptions',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final container = ProviderContainer(
        overrides: [
          festivalDataProvider.overrideWithValue(bundle),
          saveRepositoryProvider.overrideWithValue(SaveRepository()),
        ],
      );
      addTearDown(container.dispose);

      final game = WalnutstockGame(
        container: container,
        data: bundle,
        mapData: map,
        audioService: SoloudAudioService(),
      );
      game.onGameResize(Vector2(960, 640));
      await game.onLoad();

      final scenarios = <(int, double, double, double)>[
        (1, 350.0, 608.0, 390.0), // Dawn at Main Roots
        (1, 750.0, 608.0, 390.0), // High Noon at Main Roots
        (1, 1080.0, 1152.0, 448.0), // Golden Hour at Mellow Meadow
        (2, 1020.0, 224.0, 400.0), // Pre-Storm Humid at Velvet Canopy
        (2, 1110.0, 608.0, 390.0), // Pouring Rainstorm w/ Creedence Shellwater!
        (2, 1450.0, 1760.0, 360.0), // Midnight Geodesic Dome w/ Cosmo!
        (2, 1450.0, 228.0, 1030.0), // Midnight Urbano Truck w/ Don Shell-O!
        (3, 490.0, 1744.0, 1020.0), // Post-Storm Morning Sunbeams + Arcade!
      ];

      for (final (day, min, px, py) in scenarios) {
        container
            .read(festivalClockProvider.notifier)
            .setClockDirect(day: day, minuteOfDay: min);
        game.teleportPlayer(px, py);
        game.update(0.1);

        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        game.render(canvas);
        final pic = recorder.endRecording();
        pic.dispose();
      }
    });

    testWidgets(
        'HUD Time Speed button, Sky Progression Bar, and Golden Hour / Starry Night Tent Rest work cleanly',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(960, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          festivalDataProvider.overrideWithValue(bundle),
          saveRepositoryProvider.overrideWithValue(SaveRepository()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: WalnutstockApp(
            data: bundle,
            mapData: map,
            audioService: SoloudAudioService(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Unfold the single Pocket Program pill to verify Sky Progression Bar & Time Speed chip (1x -> 4x -> 10x -> 1x)
      await tester.tap(find.byKey(const ValueKey('pocket_program_pill')));
      await tester.pump();
      expect(find.byKey(const ValueKey('sky_progression_bar')), findsOneWidget);
      final speedBtn = find.byKey(const ValueKey('time_speed_button'));
      expect(speedBtn, findsOneWidget);
      expect(container.read(festivalClockProvider).timeSpeedMultiplier, 1.0);

      await tester.tap(speedBtn);
      await tester.pump();
      expect(container.read(festivalClockProvider).timeSpeedMultiplier, 4.0);

      await tester.tap(speedBtn);
      await tester.pump();
      expect(container.read(festivalClockProvider).timeSpeedMultiplier, 10.0);

      await tester.tap(speedBtn);
      await tester.pump();
      expect(container.read(festivalClockProvider).timeSpeedMultiplier, 1.0);

      await tester.tap(find.byKey(const ValueKey('close_pocket_program_button')));
      await tester.pump();

      // Verify Golden Hour & Starry Night Rest options in TentRestModal
      container
          .read(uiOverlayProvider.notifier)
          .openModal(ActiveModalOverlay.tentRest);
      await tester.pump();
      expect(find.byKey(const ValueKey('rest_golden_hour')), findsOneWidget);
      expect(find.byKey(const ValueKey('rest_starry_night')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('rest_golden_hour')));
      await tester.pump();
      expect(
        container.read(festivalClockProvider).timeOfDayPhase,
        TimeOfDayPhase.goldenHour,
      );

      container
          .read(uiOverlayProvider.notifier)
          .openModal(ActiveModalOverlay.tentRest);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('rest_starry_night')));
      await tester.pump();
      expect(
        container.read(festivalClockProvider).timeOfDayPhase,
        TimeOfDayPhase.night,
      );

      // Jump to Post-Set-8 Woodstock Mud Fest via TentRestModal & verify Mud Slide / Mud Toss HUD chips!
      container
          .read(uiOverlayProvider.notifier)
          .openModal(ActiveModalOverlay.tentRest);
      await tester.pump();
      expect(find.byKey(const ValueKey('rest_mud_fest')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rest_mud_fest')));
      await tester.pump();

      expect(
        container.read(festivalClockProvider).isMudExperienceActive(bundle.setlist),
        isTrue,
      );
      expect(find.byKey(const ValueKey('mud_slide_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('mud_toss_button')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('mud_slide_button')));
      await tester.pump();
      expect(container.read(worldFlagsProvider).mudSlidesCount, 1);

      await tester.tap(find.byKey(const ValueKey('mud_toss_button')));
      await tester.pump();

      // Mobile portrait layout check (390x844) with Mud Slide & Mud Toss HUD chips visible
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    test(
        'Day 1 Set 7 ramps rain continuously into Set 8 storm, then unlocks Post-Set-8 Mud Sliding & Mud Fights',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final container = ProviderContainer(
        overrides: [
          festivalDataProvider.overrideWithValue(bundle),
          saveRepositoryProvider.overrideWithValue(SaveRepository()),
        ],
      );
      addTearDown(container.dispose);

      final game = WalnutstockGame(
        container: container,
        data: bundle,
        mapData: map,
        audioService: SoloudAudioService(),
      );
      game.onGameResize(Vector2(960, 640));
      await game.onLoad();

      final clockN = container.read(festivalClockProvider.notifier);
      final track7 = bundle.setlist.trackByNumber(7)!;
      final track8 = bundle.setlist.trackByNumber(8)!;

      // 1. Before Day 1 Set 7 -> Clear Golden Hour, zero rain, dry grass lawn
      clockN.setClockDirect(day: 1, minuteOfDay: track7.startMinute - 15.0);
      game.update(0.05);
      expect(container.read(festivalClockProvider).weather, WeatherPhase.clear);
      expect(game.currentDayNightMetrics.rainIntensity, 0.0);
      expect(map.surfaceAtWorld(18.5 * 16, 36.5 * 16), 'grass');

      // 2. Day 1 Set 7 -> Rain starts ramping continuously from early Set 7 to late Set 7!
      clockN.setClockDirect(day: 1, minuteOfDay: track7.startMinute + 2.0);
      game.update(0.05);
      final earlySet7Rain = game.currentDayNightMetrics.rainIntensity;
      expect(
        container.read(festivalClockProvider).weather,
        WeatherPhase.preStormHumid,
      );
      expect(earlySet7Rain, greaterThan(0.12));

      clockN.setClockDirect(day: 1, minuteOfDay: track8.startMinute - 2.0);
      game.update(0.05);
      final lateSet7Rain = game.currentDayNightMetrics.rainIntensity;
      expect(lateSet7Rain, greaterThan(earlySet7Rain + 0.35));

      // 3. Day 1 Set 8 (Santana-Shell Collective) -> Full Rainstorm + Mud Pit forms!
      clockN.setClockDirect(day: 1, minuteOfDay: track8.startMinute + 20.0);
      game.update(0.05);
      expect(
        container.read(festivalClockProvider).weather,
        WeatherPhase.blightRainstorm,
      );
      expect(game.currentDayNightMetrics.rainIntensity, 1.0);
      expect(map.surfaceAtWorld(18.5 * 16, 36.5 * 16), 'mud');
      expect(map.isSlipperyAtWorld(18.5 * 16, 36.5 * 16), isTrue);

      // 4. Right after Day 1 Set 8 ends -> Rain clears & Woodstock Mud Experience begins!
      clockN.setClockDirect(day: 1, minuteOfDay: track8.endMinute + 2.0);
      game.update(0.05);
      expect(
        container.read(festivalClockProvider).weather,
        WeatherPhase.postStormMist,
      );
      expect(game.currentDayNightMetrics.rainIntensity, 0.0);
      expect(clockN.isMudExperienceActive, isTrue);
      expect(clockN.areDirtPathsMuddy, isTrue);
      expect(game.mudExperience!.activeRevelerCount, 4);

      // 5. Belly-Slide across the Velvet-to-Main-Roots Mud Pit!
      game.teleportPlayer(296.0, 584.0);
      expect(game.triggerPlayerMudSlide(), isTrue);
      expect(game.player!.isBellySliding, isTrue);
      expect(game.player!.velocity.length, greaterThan(180.0));
      for (var i = 0; i < 6; i++) {
        game.update(0.08);
      }
      expect(game.mudExperience!.groundDecalCount, greaterThan(0));
      expect(container.read(worldFlagsProvider).mudSlidesCount, 1);

      // 6. Have a Mud Fight! Throw 3 mudballs at a Mud Pit reveler -> splats, return throws & Champion Ribbon!
      final targetRev = game.mudExperience!.revelers.first;
      for (var round = 0; round < 3; round++) {
        // Wait out 0.28s throw cooldown between rounds
        for (var k = 0; k < 5; k++) {
          game.update(0.08);
        }
        game.teleportPlayer(targetRev.position.x - 42.0, targetRev.position.y);
        expect(
          game.triggerPlayerMudThrow(
            targetWorldPos:
                ui.Offset(targetRev.position.x, targetRev.position.y),
          ),
          isTrue,
        );
        expect(game.mudExperience!.activeProjectileCount, greaterThanOrEqualTo(1));
        for (var step = 0; step < 8; step++) {
          game.update(0.06);
        }
      }

      expect(
        container.read(worldFlagsProvider).mudFightsSplatted,
        greaterThanOrEqualTo(3),
      );
      expect(
        container.read(journalStateProvider).collectedItems,
        contains('Woodstock Mud-Slide Champion Ribbon'),
      );

      // Render Mud Pit decals, revelers & airborne mudballs cleanly without exceptions
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      game.render(canvas);
      recorder.endRecording().dispose();

      // Restore dry daytime & confirm lawn restores cleanly to grass
      clockN.setClockDirect(day: 1, minuteOfDay: 600.0);
      game.update(0.05);
      expect(map.surfaceAtWorld(18.5 * 16, 36.5 * 16), 'grass');
      expect(game.mudExperience!.activeRevelerCount, 0);
    });
  });

  group('Unique Performer Looks & Pre-Scanned Music-Synced Concert Light Shows',
      () {
    test(
        'all 30 tracks have real DSP-scanned BPM, 4-band envelopes, structural sections, and transient accents',
        () {
      expect(bundle.lightshows.length, 30);

      var totalSections = 0;
      var totalAccents = 0;
      final observedModes = <LightShowSectionMode>{};

      for (final track in bundle.setlist.tracks) {
        final scanned = bundle.lightshows.showForTrackId(track.id);
        expect(
          scanned,
          isNotNull,
          reason: 'Missing pre-scanned light show for ${track.id}',
        );
        expect(scanned!.bpm, inInclusiveRange(70.0, 180.0));
        expect(scanned.bassEnv.length, greaterThan(15));
        expect(scanned.midEnv.length, scanned.bassEnv.length);
        expect(scanned.highMidEnv.length, scanned.bassEnv.length);
        expect(scanned.airEnv.length, scanned.bassEnv.length);
        expect(scanned.sections, isNotEmpty);
        expect(scanned.accents, isNotEmpty);

        totalSections += scanned.sections.length;
        totalAccents += scanned.accents.length;
        for (final sec in scanned.sections) {
          observedModes.add(sec.mode);
        }

        if (track.isPaBroadcast) {
          expect(scanned.sections.first.mode, LightShowSectionMode.paCadence);
        }
      }

      expect(totalSections, greaterThan(250));
      expect(totalAccents, greaterThan(5000));
      expect(
        observedModes,
        containsAll(<LightShowSectionMode>[
          LightShowSectionMode.paCadence,
          LightShowSectionMode.versePocket,
          LightShowSectionMode.chorusAnthemy,
          LightShowSectionMode.soloShred,
          LightShowSectionMode.climaxPrism,
        ]),
      );
    });

    test(
        'every single performer across all 30 tracks has a bespoke unique look with zero cultivar sheet reuse',
        () {
      final cultivarIds = bundle.cultivars.map((c) => c.id).toSet();
      final npcById = {for (final n in bundle.npcs) n.id: n};

      // Verify all 70 bespoke ensemble musician sprite sheets exist on disk
      expect(StagePerformerDirector.ensembleSheetKeys.length, 70);
      expect(
        StagePerformerDirector.ensembleSheetKeys.toSet().length,
        70,
      );
      for (final key in StagePerformerDirector.ensembleSheetKeys) {
        final png = File('assets/images/characters/${key}_sheet.png');
        expect(
          png.existsSync(),
          isTrue,
          reason: 'Missing generated performer sprite sheet ${png.path}',
        );
        expect(png.lengthSync(), greaterThan(500));
      }

      final usedEnsembleKeys = <String>{};
      for (final track in bundle.setlist.tracks) {
        final (npcMarks, bandMembers) = StagePerformerDirector.rosterForTrack(
          track,
          isSoundcheck: false,
        );

        final stageSheets = <String>[];
        for (final m in npcMarks) {
          final npc = npcById[m.npcId];
          expect(npc, isNotNull, reason: 'Unknown NPC ${m.npcId}');
          stageSheets.add(npc!.spriteId);
        }
        for (final b in bandMembers) {
          expect(
            cultivarIds.contains(b.sheetKey),
            isFalse,
            reason:
                'Ensemble member ${b.id} on track #${track.trackNumber} reused generic cultivar sheet ${b.sheetKey}',
          );
          expect(
            StagePerformerDirector.ensembleSheetKeys.contains(b.sheetKey),
            isTrue,
            reason: 'Unregistered ensemble sheetKey ${b.sheetKey}',
          );
          stageSheets.add(b.sheetKey);
          usedEnsembleKeys.add(b.sheetKey);
        }

        // Every performer sharing a stage on any track has a 100% unique sprite sheet!
        expect(
          stageSheets.toSet().length,
          stageSheets.length,
          reason:
              'Duplicate performer look on stage during track #${track.trackNumber}: $stageSheets',
        );
      }

      // 67 bespoke ensemble sheets across tracks 0..29 + 3 fallback ensemble sheets = 70 total!
      expect(usedEnsembleKeys.length, 67);
    });

    test(
        'all 26 canonical lineup tracks match exact artist & title names and each distinct band has a unique lead visual look',
        () {
      const expectedLineup = <int, (String, String)>{
        1: (
          'Nutcracker Joe & The Hull Band',
          'With a Little Help from My Shell (Live)',
        ),
        2: ('The Festival MC', 'Stage Announcement 1'),
        3: ('Richie Shellens', "Crackin' Free (Live)"),
        4: ('The Walnut Blues Band', 'Getting Harder (Live)'),
        5: (
          'Melanie Sapka',
          'Brand New Key (And I Found It Under a Walnut Tree) [Live]',
        ),
        6: ('Arlo Nutthrie', 'Open Shells, Open Hearts (Live)'),
        7: ('The Festival MC', 'Stage Announcement 2'),
        8: ('Nutana', 'Walnut Smooth (Live)'),
        9: ('Canned Walnut', 'Kernel of Truth (Live)'),
        10: ('Mountain Grove', 'I Think of Walnuts (Live)'),
        11: ('The Festival MC', 'Stage Announcement 3'),
        12: ('Janice Joeplant', 'Piece of My Walnut (Live)'),
        13: ('Crosby, Stills, Nash & Walnut', 'Our Shell (Live)'),
        14: (
          'Creedence Clearwater Harvest',
          'Fortunate Son (of a Bareroot Sapling) [Live]',
        ),
        15: (
          'Creedence Clearwater Harvest',
          "Bad Moon Risin' (Watch Out for Blight) [Live]",
        ),
        16: ('The Hull', "Talkin' 'Bout My Dehiscence (Live)"),
        17: ('The Hull', 'Pinball Wizard (at the Sorting Machine) [Live]'),
        18: ('The Festival MC', 'Stage Announcement 4'),
        19: (
          'The Walnuts & The Shells',
          'California Dreamin\' (of Perfect Cracking Weather) [Live]',
        ),
        20: (
          'The Walnuts & The Shells',
          'Monday, Monday (The Sorting Belt Blues) [Live]',
        ),
        21: ('Country Joe & The Nut', 'Walnut Cruncherman (Live)'),
        22: ('Jefferson Orchard', 'The Walnut Trip (Live)'),
        23: ('The Grateful Nut', "Help I'm a Walnut (Live)"),
        24: ('The Festival MC', 'Stage Announcement 5 (Live)'),
        25: ('Jimi Hendshell', 'Purple Haze (of Walnut Dust) [Live]'),
        26: ('Jimi Hendshell', 'Foxy Nutlady (Live)'),
      };

      final leadSpriteByArtist = <String, String>{};
      for (final entry in expectedLineup.entries) {
        final track = bundle.setlist.trackByNumber(entry.key);
        expect(track, isNotNull, reason: 'Missing track #${entry.key}');
        expect(track!.artist, entry.value.$1);
        expect(track.title, entry.value.$2);

        final (npcMarks, bandMembers) = StagePerformerDirector.rosterForTrack(
          track,
          isSoundcheck: false,
        );
        final leadNpc = npcMarks.where((m) => m.isLeadPerformer).firstOrNull;
        final leadBand =
            bandMembers.where((b) => b.isLeadPerformer).firstOrNull;
        final leadIdentity = leadBand != null
            ? 'sheet:${leadBand.sheetKey}'
            : (leadNpc != null
                ? 'npc:${leadNpc.npcId}'
                : 'npc:${npcMarks.first.npcId}');

        final prev = leadSpriteByArtist[track.artist];
        if (prev != null) {
          // Multi-set artists (Creedence Clearwater Harvest, The Hull, The Walnuts & The Shells, Jimi Hendshell, The Festival MC) keep their signature identity!
          expect(
            leadIdentity,
            prev,
            reason:
                'Recurring artist ${track.artist} should keep consistent lead look across sets',
          );
        } else {
          expect(
            leadSpriteByArtist.values.contains(leadIdentity),
            isFalse,
            reason:
                'Artist ${track.artist} collided with another artist lead look ($leadIdentity)',
          );
          leadSpriteByArtist[track.artist] = leadIdentity;
        }
      }

      // 18 unique canonical lineup artists (17 bands/soloists + The Festival MC), all 18 distinct!
      expect(leadSpriteByArtist.length, 18);
    });

    test(
        'computeCenteredWorldPill & StageLiveBannerComponent center artist names vertically and horizontally without pushing text to bottom',
        () {
      const center = Offset(608.0, 312.0);
      for (final sample in const [
        'Nutcracker Joe & The Hull Band  ·  FULL BAND',
        'Crosby, Stills, Nash & Walnut  ·  RHYTHM BREAK',
        'Creedence Clearwater Harvest  ·  CHORUS ANTHEM',
        'Jimi Hendshell  ·  SOLO SHRED',
        '🌈 Enjoy 2 rainbow sets!',
      ]) {
        final layout = computeCenteredWorldPill(
          center: center,
          text: sample,
          fontSize: 7.4,
          textColor: const Color(0xFFFFF8E7),
          horizontalPadding: 9.0,
          pillHeight: 16.0,
          minPillWidth: 84.0,
          maxPillWidth: 316.0,
          borderRadius: 8.0,
          leadingIconSlotWidth: sample.startsWith('🌈') ? 0.0 : 11.0,
        );

        final rect = layout.pillRect.outerRect;
        expect(rect.center.dx, closeTo(center.dx, 0.001));
        expect(rect.center.dy, closeTo(center.dy, 0.001));

        // Horizontal symmetry: left margin before content == right margin after text!
        final leftMargin = layout.leadingIconLeftX - rect.left;
        final rightMargin =
            rect.right - (layout.paragraphTopLeft.dx + layout.glyphWidth);
        expect(leftMargin, closeTo(rightMargin, 0.25));
        expect(leftMargin, greaterThanOrEqualTo(8.5));

        // Vertical symmetry: baseline sits near center + 0.25 * fontSize (~+1.85px),
        // leaving > 5.8px of breathing room above the bottom border (+8.0px)!
        final bottomClearanceFromBaseline = rect.bottom - layout.baselineY;
        final topClearanceToCapTop =
            (layout.baselineY - 7.4 * 0.72) - rect.top;
        expect(bottomClearanceFromBaseline, greaterThan(5.8));
        expect(topClearanceToCapTop, closeTo(4.5, 0.8));
      }

      // Verify StageLiveBannerComponent renders cleanly on Canvas and sits above all stage roofs
      expect(
        StageLiveBannerComponent.bannerWorldAnchors['main_roots_stage']!.dy,
        lessThan(322.0), // Above Main Roots proscenium arch apex (322)
      );
      expect(
        StageLiveBannerComponent
            .bannerWorldAnchors['andromeda_pavilion_stage']!
            .dy,
        lessThan(278.0), // Above Andromeda geodesic dome top rim (278)
      );

      final track13 = bundle.setlist.trackByNumber(13)!;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final banner = StageLiveBannerComponent(
        liveStagesGetter: () => {
          'main_roots_stage': LiveStageVisualState(
            stageId: 'main_roots_stage',
            track: track13,
            primaryColor: const Color(0xFFFFD166),
            secondaryColor: const Color(0xFF95D5B2),
            show: bundle.lightshows.sampleTrack(track13, 12.0),
          ),
        },
        stagesCatalog: bundle.setlist.stages,
        cameraCenterGetter: () => const Offset(608, 380),
        timeGetter: () => 12.0,
      );
      banner.render(canvas);
      final picture = recorder.endRecording();
      addTearDown(picture.dispose);
    });

    test(
        'runtime concert light show, dynamic world lights, and performer choreography sync to scanned audio sections & render cleanly',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final container = ProviderContainer(
        overrides: [
          festivalDataProvider.overrideWithValue(bundle),
          saveRepositoryProvider.overrideWithValue(SaveRepository()),
        ],
      );
      addTearDown(container.dispose);

      final game = WalnutstockGame(
        container: container,
        data: bundle,
        mapData: map,
        audioService: SoloudAudioService(),
      );
      game.onGameResize(Vector2(960, 640));
      await game.onLoad();

      final clockN = container.read(festivalClockProvider.notifier);
      final jimiTrack = bundle.setlist.trackByNumber(25)!;
      final jimiShow = bundle.lightshows.showForTrackId(jimiTrack.id)!;

      // Locate a scanned soloShred section & a chorus/climax section on Jimi Hendshell's set (or fallback cues)
      final soloCue = jimiShow.sections.firstWhere(
        (s) => s.mode == LightShowSectionMode.soloShred,
        orElse: () => jimiShow.sections.first,
      );
      final fullCue = jimiShow.sections.firstWhere(
        (s) =>
            s.mode == LightShowSectionMode.climaxPrism ||
            s.mode == LightShowSectionMode.chorusAnthemy,
        orElse: () => jimiShow.sections.last,
      );

      final cpm = bundle.setlist.clockMinutesPerRealSecond;
      final soloMidSec = (soloCue.startSec + soloCue.endSec) * 0.5;
      final fullMidSec = (fullCue.startSec + fullCue.endSec) * 0.5;

      // 1. Jump to Jimi's solo section on Main Roots Stage
      clockN.setClockDirect(
        day: jimiTrack.day,
        minuteOfDay: jimiTrack.startMinute + soloMidSec * cpm,
      );
      game.teleportPlayer(608.0, 400.0);
      game.update(0.05);

      final soloLive = game.liveStageVisuals['main_roots_stage'];
      expect(soloLive, isNotNull);
      expect(soloLive!.show.trackId, jimiTrack.id);
      expect(soloLive.show.sectionMode, soloCue.mode);

      final jimiActor = game.npcActorById('jimi_hendshell')!;
      expect(jimiActor.isOnStagePerforming, isTrue);
      final soloChoreo = jimiActor.currentChoreoSample;
      expect(soloChoreo, isNotNull);
      if (soloCue.mode == LightShowSectionMode.soloShred) {
        expect(soloChoreo!.poseMove, PerformerPoseMove.soloShred);
        expect(soloChoreo.forwardStepY, greaterThan(1.5));
        expect(soloChoreo.sparkBurst, greaterThan(0.3));
      }

      // 2. Jump to full-stage chorus/climax section -> sweeping multi-pool LightSource3D wash!
      clockN.setClockDirect(
        day: jimiTrack.day,
        minuteOfDay: jimiTrack.startMinute + fullMidSec * cpm,
      );
      game.update(0.05);

      final fullLive = game.liveStageVisuals['main_roots_stage']!;
      expect(fullLive.show.sectionMode, fullCue.mode);
      final stageLights = game.collectVisibleWorldLightsForBounds(
        const ui.Rect.fromLTWH(460, 280, 300, 220),
      );
      // Multiple dynamic concert stage LightSource3D pools illuminate Main Roots Stage!
      expect(stageLights.length, greaterThanOrEqualTo(3));

      // 3. Render all 7 concert stage architectures while LIVE to verify 0 canvas errors!
      final representativeTracks = <int>[
        2, // High-Branch PA Booth (Patchouli Pete)
        5, // Mellow Meadow Stage (Joan + Barnaby + Meadow Bass)
        8, // Velvet Canopy Stage (Santana-Shell Collective)
        20, // Sorting Arcade Stage (Mamas & Husks + Arcade Attendant)
        25, // Main Roots Stage (Jimi Hendshell Experience)
        27, // Urbano Canopy Truck Stage (Don Shell-O + DJ + Perc)
        28, // Andromeda Geodesic Dome (Cosmo Shell-voy + Synth + Perc)
      ];
      for (final tn in representativeTracks) {
        final tr = bundle.setlist.trackByNumber(tn)!;
        final st = bundle.setlist.stages[tr.stageId]!;
        clockN.setClockDirect(
          day: tr.day,
          minuteOfDay: (tr.startMinute + tr.endMinute) * 0.5,
        );
        game.teleportPlayer(st.x, st.y + 24.0);
        game.update(0.05);

        final rec = ui.PictureRecorder();
        final c = ui.Canvas(rec);
        game.render(c);
        rec.endRecording().dispose();
      }
    });
  });

  group('Day 2 Creek Stage Electric Purple Blueberries & 2-Set Wavy Rainbow',
      () {
    test(
        'Electric Purple Blueberries are shared near Willow Creek & Meadow Stage on Day 2 start and make everything wavy & rainbow for exactly 2 sets',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final creekStage = bundle.setlist.stages['mellow_meadow_stage']!;
      expect(creekStage.name, 'Willow Creek & Meadow Stage');

      const basket = ElectricBlueberryExperienceController.basketWorldPos;
      expect(map.isPointBlocked(basket.dx, basket.dy), isFalse);
      expect(
        (ui.Offset(creekStage.x, creekStage.y) - basket).distance,
        lessThan(85.0),
      );

      final container = ProviderContainer(
        overrides: [
          festivalDataProvider.overrideWithValue(bundle),
          saveRepositoryProvider.overrideWithValue(SaveRepository()),
        ],
      );
      addTearDown(container.dispose);

      final game = WalnutstockGame(
        container: container,
        data: bundle,
        mapData: map,
        audioService: SoloudAudioService(),
      );
      game.onGameResize(Vector2(960, 640));
      await game.onLoad();

      final clockN = container.read(festivalClockProvider.notifier);

      // 1. Day 1: Creekside blueberry sharing circle is NOT active yet
      clockN.setClockDirect(day: 1, minuteOfDay: 520.0);
      game.update(0.05);
      expect(
          container.read(festivalClockProvider).isDay2BlueberrySharingActive,
          isFalse);
      expect(game.blueberryExperience!.activeSharerCount, 0);

      // 2. Start of Day 2 (5:05 AM Sunrise, Track 0 live at Creek Stage):
      //    Sharing circle spawns beside Willow Creek & Meadow Stage!
      clockN.restUntilDay2Blueberries();
      game.teleportPlayer(basket.dx + 28.0, basket.dy + 6.0);
      game.update(0.05);

      expect(container.read(festivalClockProvider).day, 2);
      expect(
          container.read(festivalClockProvider).isDay2BlueberrySharingActive,
          isTrue);
      expect(game.blueberryExperience!.activeSharerCount, 2);
      expect(
        container.read(uiOverlayProvider).nearbyInteractPrompt,
        'Share Electric Purple Blueberries [E]',
      );

      // Verify purple aura light is emitted at the sharing basket
      final creekLights = game.collectVisibleWorldLightsForBounds(
        const ui.Rect.fromLTWH(1020, 420, 200, 140),
      );
      expect(
        creekLights.any((l) => l.position == basket),
        isTrue,
      );

      // 3. Share the blueberries via [E] / interact -> Wavy Rainbow activates for 2 sets!
      game.handleInteract();
      game.update(0.12);

      var flags = container.read(worldFlagsProvider);
      expect(flags.blueberryTripActive, isTrue);
      expect(flags.blueberriesSharedCount, 1);
      expect(flags.isBlueberryRainbowActiveAt(2, 306.0), isTrue);
      expect(flags.blueberrySetsRemainingAt(2, 306.0), 2);
      expect(
        container.read(journalStateProvider).collectedItems,
        contains('Electric Purple Blueberries'),
      );
      expect(game.blueberryVisualBlend, greaterThan(0.4));

      // JSON save/load round-trip preserves active 2-set blueberry window
      final roundTrip = WorldFlags.fromJson(flags.toJson());
      expect(roundTrip.isBlueberryRainbowActiveAt(2, 306.0), isTrue);
      expect(roundTrip.blueberrySetsRemainingAt(2, 306.0), 2);

      // Render wavy matrix warp + rainbow hue saveLayer + creek + rainbow footsteps cleanly
      game.teleportPlayer(basket.dx - 18.0, basket.dy + 12.0);
      game.update(0.16);
      expect(game.blueberryExperience!.rainbowTrailCount, greaterThan(0));

      final waveMat = ShaderPostProcessor.buildLiquidWaveMatrix(
        viewportSize: const Size(960, 640),
        timeSeconds: 1.25,
        intensity: 1.0,
        bass: 0.6,
      );
      expect(waveMat[0], greaterThan(1.02)); // overscanned wave scale/shear

      final rec = ui.PictureRecorder();
      final canvas = ui.Canvas(rec);
      game.render(canvas);
      rec.endRecording().dispose();

      // 4. Advance past Set #1 (`track_00`, ends 415.5) and into PA Announcement (`track_11`, 675.0)
      //    & Set #2 (`track_12` Janice Joeplant, 708.95..845.7) -> Still active with 1 set left!
      final track0 = bundle.setlist.trackByNumber(0)!;
      final track12 = bundle.setlist.trackByNumber(12)!;
      final track13 = bundle.setlist.trackByNumber(13)!;

      clockN.setClockDirect(day: 2, minuteOfDay: track0.endMinute + 10.0);
      game.update(0.05);
      flags = container.read(worldFlagsProvider);
      expect(
          flags.isBlueberryRainbowActiveAt(2, track0.endMinute + 10.0), isTrue);
      expect(flags.blueberrySetsRemainingAt(2, track0.endMinute + 10.0), 1);

      // During Patchouli Pete's PA announcement (`track_11` @ 675.0) & Set #2 (`track_12` @ 780.0):
      clockN.setClockDirect(day: 2, minuteOfDay: 675.0);
      game.update(0.05);
      expect(
        container.read(worldFlagsProvider).isBlueberryRainbowActiveAt(2, 675.0),
        isTrue,
      );

      clockN.setClockDirect(
        day: 2,
        minuteOfDay: (track12.startMinute + track12.endMinute) * 0.5,
      );
      game.update(0.05);
      flags = container.read(worldFlagsProvider);
      expect(
        flags.blueberrySetsRemainingAt(
          2,
          (track12.startMinute + track12.endMinute) * 0.5,
        ),
        1,
      );

      // 5. Right after Set #2 (`track_12`, ends 845.7) finishes (before Set #3 `track_13` @ 853.7) ->
      //    2-set wavy rainbow cleanly expires!
      clockN.setClockDirect(day: 2, minuteOfDay: track12.endMinute + 2.0);
      game.update(0.05);
      flags = container.read(worldFlagsProvider);
      expect(flags.blueberryTripActive, isFalse);
      expect(
        flags.isBlueberryRainbowActiveAt(2, track12.endMinute + 2.0),
        isFalse,
      );
      expect(
        flags.blueberrySetsRemainingAt(2, track12.endMinute + 2.0),
        0,
      );
      expect(game.blueberryVisualBlend, 0.0);

      // 6. Also verify walking onto the basket later on Day 2 morning (`480.0`, after `track_00`)
      //    auto-shares berries spanning `track_12` (Set #1) + `track_13` (Set #2) and expiring before `track_14`!
      game.teleportPlayer(basket.dx + 40.0, basket.dy);
      game.update(0.05);
      clockN.setClockDirect(day: 2, minuteOfDay: 480.0);
      game.teleportPlayer(basket.dx, basket.dy); // direct walk-over share!
      game.update(0.05);
      flags = container.read(worldFlagsProvider);
      expect(flags.blueberryTripActive, isTrue);
      expect(flags.blueberrySetsRemainingAt(2, 750.0), 2); // during track_12
      expect(flags.blueberrySetsRemainingAt(2, 890.0), 1); // during track_13
      expect(flags.isBlueberryRainbowActiveAt(2, track13.endMinute + 2.0),
          isFalse);
    });

    testWidgets(
        'TentRestModal jumps to Day 2 Dawn Creek Blueberries and WristbandHud displays 2-set Wavy Rainbow badge cleanly',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(960, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          festivalDataProvider.overrideWithValue(bundle),
          saveRepositoryProvider.overrideWithValue(SaveRepository()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: WalnutstockApp(
            data: bundle,
            mapData: map,
            audioService: SoloudAudioService(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Open TentRestModal and jump directly to Day 2 Dawn Creek Blueberries
      container
          .read(uiOverlayProvider.notifier)
          .openModal(ActiveModalOverlay.tentRest);
      await tester.pump();

      expect(
          find.byKey(const ValueKey('rest_day2_blueberries')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rest_day2_blueberries')));
      await tester.pump();

      expect(container.read(festivalClockProvider).day, 2);
      expect(
        container.read(festivalClockProvider).isDay2BlueberrySharingActive,
        isTrue,
      );

      // Activate Electric Purple Blueberries and verify HUD badge updates from 2 Sets -> 1 Set -> gone!
      container.read(worldFlagsProvider.notifier).activateElectricBlueberries(
            bundle.setlist,
            day: 2,
            minuteOfDay: 305.0,
          );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('electric_blueberry_hud_badge')),
        findsOneWidget,
      );
      expect(find.textContaining('2 Sets Left'), findsOneWidget);

      container
          .read(festivalClockProvider.notifier)
          .setClockDirect(day: 2, minuteOfDay: 750.0);
      await tester.pump();
      expect(find.textContaining('1 Set Left'), findsOneWidget);

      // Mobile portrait check (390x844) with Wavy Rainbow HUD badge visible -> 0 overflows
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
