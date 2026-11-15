import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color, Offset;

import 'package:flame/components.dart' show Vector2;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walnutstock/audio/progressive_track_cache.dart';
import 'package:walnutstock/audio/soloud_audio_service.dart';
import 'package:walnutstock/data/models.dart';
import 'package:walnutstock/game/actors/npc_actor.dart';
import 'package:walnutstock/game/walnutstock_game.dart';
import 'package:walnutstock/game/world/concert_light_show.dart';
import 'package:walnutstock/game/world/festival_crowd_director.dart';
import 'package:walnutstock/game/world/stage_3d_rig_component.dart';
import 'package:walnutstock/game/world/tiled_map_parser.dart';
import 'package:walnutstock/state/dialogue_and_overlay_state.dart';
import 'package:walnutstock/state/providers.dart';
import 'package:walnutstock/state/save_repository.dart';

class _SilentTestAudioService extends SoloudAudioService {
  @override
  Future<void> syncStreamSlot({
    required String slotKey,
    required String trackId,
    required ResolvedAudioTarget target,
    required double seekSeconds,
    required double volume,
    required double pan,
    bool looping = false,
  }) async {}

  @override
  Future<void> stopSlot(String slotKey) async {}

  @override
  void updateCanopyLowPass(double cutoffHz) {}

  @override
  Future<void> playSfx(
    String assetPath, {
    double volume = 0.7,
    double pan = 0.0,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FestivalDataBundle bundle;
  late OrchardMapData map;

  setUpAll(() {
    final tmx = File('assets/tiles/free_orchard_full.tmx').readAsStringSync();
    final tsx = File('assets/tiles/orchard_tileset.tsx').readAsStringSync();
    map = TiledMapParser.parseTmxAndTsx(tmxXmlString: tmx, tsxXmlString: tsx);

    final setlistJson = jsonDecode(
      File('assets/data/setlist_26_tracks.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final npcsJson = jsonDecode(
      File('assets/data/npcs_and_quests.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    bundle = FestivalDataBundle.fromJsonMaps(
      setlistJson: setlistJson,
      npcsJson: npcsJson,
    );
  });

  Future<(WalnutstockGame, ProviderContainer)> createLoadedGame() async {
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
      audioService: _SilentTestAudioService(),
    );
    game.onGameResize(Vector2(960, 640));
    await game.onLoad();
    return (game, container);
  }

  test(
      'All curated blanket spots, blanket seats, food queue slots, and festivalgoer homes are walkable',
      () async {
    final (game, container) = await createLoadedGame();
    final director = game.crowdDirector!;

    // Jump to Day 3 so all 9 blankets and all 24 festivalgoers are active
    container
        .read(festivalClockProvider.notifier)
        .setClockDirect(day: 3, minuteOfDay: 720.0);
    game.update(0.05);

    expect(director.activeBlanketSpots.length, 9);
    for (final blanket in director.activeBlanketSpots) {
      expect(
        map.isPointBlocked(blanket.center.dx, blanket.center.dy),
        isFalse,
        reason: 'Blanket center ${blanket.id} must be walkable',
      );
      for (final seat in blanket.seats) {
        expect(
          map.isPointBlocked(seat.dx, seat.dy),
          isFalse,
          reason: 'Blanket seat on ${blanket.id} must be walkable',
        );
      }
    }

    expect(director.foodQueues.keys,
        containsAll(['falafel_stand', 'street_food_cart', 'cider_tea_kettle']));
    for (final q in director.foodQueues.values) {
      for (final slot in q.spec.queueSlots) {
        expect(
          map.isPointBlocked(slot.dx, slot.dy),
          isFalse,
          reason: 'Food queue slot at ${q.spec.id} must be walkable',
        );
      }
    }

    expect(director.allGoers.length, 24);
    for (final goer in director.allGoers) {
      expect(
        map.isPointBlocked(goer.spec.homePos.dx, goer.spec.homePos.dy),
        isFalse,
        reason: 'FestivalGoer homePos for ${goer.spec.id} must be walkable',
      );
    }
  });

  test(
      'Crowds, woven blankets, outfits, and post-rain mud patina progress across Days 1, 2, and 3',
      () async {
    final (game, container) = await createLoadedGame();
    final director = game.crowdDirector!;
    final clockN = container.read(festivalClockProvider.notifier);
    final sampleGoer = director.allGoers.first;

    // Day 1 (Friday morning): 12 festivalgoers, 4 blankets, Day 1 wardrobe
    clockN.setClockDirect(day: 1, minuteOfDay: 510.0);
    game.update(0.05);
    expect(director.activeCrowdActors.length, 12);
    expect(director.activeBlanketSpots.length, 4);
    expect(sampleGoer.activeWardrobeId, sampleGoer.spec.day1WardrobeId);

    // Day 2 (Saturday post-storm mud celebration, Track 16): 19 festivalgoers, 7 blankets, Day 2 wardrobe + mud patina
    final track16 = bundle.setlist.trackByNumber(16)!;
    clockN.setClockDirect(day: 2, minuteOfDay: track16.startMinute + 12.0);
    for (var i = 0; i < 8; i++) {
      game.update(0.25);
    }
    expect(director.activeCrowdActors.length, 19);
    expect(director.activeBlanketSpots.length, 7);
    expect(sampleGoer.activeWardrobeId, sampleGoer.spec.day2WardrobeId);
    expect(sampleGoer.mudPatina, greaterThan(0.15));

    // Day 3 (Sunday afternoon): 24 festivalgoers, 9 blankets, Day 3 wardrobe
    clockN.setClockDirect(day: 3, minuteOfDay: 900.0);
    game.update(0.05);
    expect(director.activeCrowdActors.length, 24);
    expect(director.activeBlanketSpots.length, 9);
    expect(sampleGoer.activeWardrobeId, sampleGoer.spec.day3WardrobeId);
  });

  test(
      'NPCs & festivalgoers wander between stages via A* and dance when live sets shift stages',
      () async {
    final (game, container) = await createLoadedGame();
    final director = game.crowdDirector!;
    final clockN = container.read(festivalClockProvider.notifier);

    // 1. Start at Track 5 on Mellow Meadow Stage
    final track5 = bundle.setlist.trackByNumber(5)!;
    expect(track5.stageId, 'mellow_meadow_stage');
    clockN.setClockDirect(day: 1, minuteOfDay: track5.startMinute + 15.0);
    game.update(0.05);

    final meadowDancers = director.activeCrowdActors
        .where((g) => g.targetStageId == 'mellow_meadow_stage')
        .toList();
    expect(meadowDancers, isNotEmpty);
    expect(director.countDancingActors([
      for (final id in ['nora_walnut', 'pippin_pecan', 'raymond_walnut'])
        game.npcActorById(id)!,
    ]), greaterThan(0));

    // 2. Now live music shifts to Track 8 on Velvet Canopy Stage WITHOUT snapping positions:
    //    verify meadow dancers switch targetStageId to velvet_canopy_stage and A*-walk west!
    final track8 = bundle.setlist.trackByNumber(8)!;
    expect(track8.stageId, 'velvet_canopy_stage');
    // Step clock smoothly in <2.5 min increments or jump & observe live stage migration:
    // Let's place a dancer at Mellow Meadow lawn, then let Velvet Canopy go live without clockJumped!
    clockN.setClockDirect(day: 1, minuteOfDay: track8.startMinute - 0.5);
    game.update(0.05);

    final migrant = director.activeCrowdActors.firstWhere(
      (g) =>
          g.activity != FestivalCrowdActivity.queuingInFoodLine &&
          g.activity != FestivalCrowdActivity.walkingToFoodLine,
    );
    migrant.position.setValues(1148.0, 506.0); // Mellow Meadow bowl
    final startX = migrant.position.x;

    // Advance naturally across Track 8 start (no clockJumped!) so crowd walks via A*
    clockN.setClockDirect(day: 1, minuteOfDay: track8.startMinute + 1.0);
    for (var i = 0; i < 20; i++) {
      game.update(0.25);
    }

    final velvetBound = director.activeCrowdActors
        .where((g) => g.targetStageId == 'velvet_canopy_stage')
        .toList();
    expect(velvetBound, isNotEmpty);
    // Migrant at x=1148 heading toward Velvet Canopy (x~224) moves west or joins active goal
    if (migrant.targetStageId == 'velvet_canopy_stage') {
      expect(migrant.position.x, lessThan(startX));
    }

    // Roaming Named NPC (Raymond Walnut prefers velvet_canopy_stage) also joins!
    final raymond = game.npcActorById('raymond_walnut')!;
    expect(
      raymond.autonomousTargetStageId == 'velvet_canopy_stage' ||
          raymond.isQueuingForFood ||
          raymond.isSittingOnBlanket,
      isTrue,
    );
  });

  test(
      'Festivalgoers sit on lawn blankets (including player custom blanket) and stand up during heavy rainstorms',
      () async {
    final (game, container) = await createLoadedGame();
    final director = game.crowdDirector!;
    final clockN = container.read(festivalClockProvider.notifier);

    // Clear afternoon on Day 2: festivalgoers lounge on woven blankets
    clockN.setClockDirect(day: 2, minuteOfDay: 640.0);
    game.update(0.05);
    expect(director.countSeatedActors([]), greaterThanOrEqualTo(4));

    // Player unrolls their Woven Picnic Blanket on Main Roots lawn:
    // custom blanket registers and gets prioritized for guest seating!
    container.read(worldFlagsProvider.notifier).update(
          (s) => s.copyWith(
            picnicBlanketDeployed: true,
            picnicBlanketX: 608.0,
            picnicBlanketY: 560.0,
          ),
        );
    // Force an intermission rebalance where a goer picks up a seat on player's blanket
    for (final g in director.activeCrowdActors) {
      if (g.activity == FestivalCrowdActivity.sittingOnBlanket) {
        g.stateHoldTimerSec = 0.0;
        g.activity = FestivalCrowdActivity.strollingOrchard;
        break;
      }
    }
    game.update(0.1);
    expect(
      director.activeBlanketSpots.any((b) => b.isPlayerBlanket),
      isTrue,
    );
    expect(
      director.activeCrowdActors
          .any((g) => g.targetBlanketId == 'blanket_player_custom'),
      isTrue,
    );

    // Heavy Saturday Rainstorm (Track 15 -> WeatherPhase.blightRainstorm, rainIntensity > 0.50):
    // all blanket loungers immediately vacate!
    final track15 = bundle.setlist.trackByNumber(15)!;
    clockN.setClockDirect(day: 2, minuteOfDay: track15.startMinute + 15.0);
    game.update(0.1);
    expect(game.currentDayNightMetrics.rainIntensity, greaterThan(0.50));
    expect(director.countSeatedActors([]), 0);
  });

  test(
      'Vendor Row food lines serve customers at counter, advance remaining slots, and never block player stall interaction',
      () async {
    final (game, container) = await createLoadedGame();
    final director = game.crowdDirector!;
    final clockN = container.read(festivalClockProvider.notifier);

    // Day 2 midday lunch rush (12:05 PM): queues form across Vendor Row stalls
    clockN.setClockDirect(day: 2, minuteOfDay: 725.0);
    game.update(0.05);
    expect(director.totalQueuedForFoodCount, greaterThanOrEqualTo(4));

    final activeQueue = director.foodQueues.values
        .firstWhere((q) => q.memberKeys.isNotEmpty);
    final initialFrontKey = activeQueue.memberKeys.first;
    final secondKey =
        activeQueue.memberKeys.length > 1 ? activeQueue.memberKeys[1] : null;

    // Ensure player standing right at falafel_stand & street_food_cart still interacts
    // with the stall counters (not hijacked by queued festivalgoers' dialogue)!
    final falafelRect = map.interactables
        .firstWhere((o) => o.name == 'falafel_stand')
        .rect;
    game.teleportPlayer(falafelRect.center.dx, falafelRect.center.dy);
    game.handleInteract();
    expect(container.read(uiOverlayProvider).dialogue, isNull);
    expect(container.read(uiOverlayProvider).toastBanner, contains('pita counter'));

    final foodCartRect = map.interactables
        .firstWhere((o) => o.name == 'street_food_cart')
        .rect;
    game.teleportPlayer(foodCartRect.center.dx, foodCartRect.center.dy);
    game.handleInteract();
    expect(container.read(uiOverlayProvider).modal, ActiveModalOverlay.vendorStall);
    container.read(uiOverlayProvider.notifier).closeModal();

    // Move player away from Vendor Row and step 6.5s so slot 0 gets served!
    game.teleportPlayer(608.0, 864.0);
    for (var i = 0; i < 28; i++) {
      game.update(0.25);
    }

    expect(activeQueue.servedCount, greaterThanOrEqualTo(1));
    if (initialFrontKey.startsWith('crowd:')) {
      final servedGoer = director.allGoers
          .firstWhere((g) => g.spec.id == initialFrontKey.substring(6));
      expect(servedGoer.heldTreatEmoji, isNotNull);
      expect(
        servedGoer.activity,
        isNot(equals(FestivalCrowdActivity.queuingInFoodLine)),
      );
    }
    if (secondKey != null && activeQueue.memberKeys.contains(secondKey)) {
      expect(activeQueue.indexOf(secondKey), 0);
    }
  });

  test(
      'Audiences react to solos, hush sways & set-end ovations, and conversations evolve across Days 1, 2, and 3',
      () async {
    final (game, container) = await createLoadedGame();
    final director = game.crowdDirector!;
    final clockN = container.read(festivalClockProvider.notifier);

    // 1. Test live performance reactions (kickoff -> soloOrDrop -> hushSway -> set-end encoreOvation)
    final track1 = bundle.setlist.trackByNumber(1)!;
    StageShowFrame frameWith({
      required double trackTimeSec,
      required LightShowSectionMode mode,
      bool kickDrop = false,
    }) {
      return StageShowFrame(
        trackId: track1.id,
        trackNumber: track1.trackNumber,
        trackTimeSec: trackTimeSec,
        bpm: 120.0,
        sectionMode: mode,
        sectionIntensity: 0.85,
        sectionProgress: 0.4,
        bass: 0.72,
        mid: 0.55,
        highMid: 0.48,
        air: 0.35,
        beatIndex: 8,
        barBeat: 0,
        beatPhase: 0.15,
        beatPulse: 0.82,
        accentKind:
            kickDrop ? LightShowAccentKind.kickDrop : LightShowAccentKind.none,
        accentFlash: kickDrop ? 0.92 : 0.0,
        accentAgeSec: 0.05,
      );
    }

    final flags = container.read(worldFlagsProvider);
    final clock1 = container.read(festivalClockProvider);

    // Kickoff reaction on track start
    director.update(
      dt: 0.1,
      clock: clock1,
      flags: flags,
      liveStages: {
        'main_roots_stage': LiveStageVisualState(
          stageId: 'main_roots_stage',
          track: track1,
          primaryColor: const Color(0xFFFFB703),
          secondaryColor: const Color(0xFFFB5607),
          show: frameWith(
            trackTimeSec: 2.0,
            mode: LightShowSectionMode.versePocket,
          ),
        ),
      },
      namedNpcs: const [],
      playerPos: Vector2(608, 520),
      bassLevel: 0.6,
      nightSparklerWave: false,
      clockJumped: false,
    );
    expect(
      director.stageReactionFor('main_roots_stage'),
      CrowdReactionKind.setKickoff,
    );

    // Advance past kickoff into Guitar Solo Shred -> soloOrDrop!
    director.update(
      dt: 8.5,
      clock: clock1,
      flags: flags,
      liveStages: {
        'main_roots_stage': LiveStageVisualState(
          stageId: 'main_roots_stage',
          track: track1,
          primaryColor: const Color(0xFFFFB703),
          secondaryColor: const Color(0xFFFB5607),
          show: frameWith(
            trackTimeSec: 64.0,
            mode: LightShowSectionMode.soloShred,
            kickDrop: true,
          ),
        ),
      },
      namedNpcs: const [],
      playerPos: Vector2(608, 520),
      bassLevel: 0.85,
      nightSparklerWave: false,
      clockJumped: false,
    );
    expect(
      director.stageReactionFor('main_roots_stage'),
      CrowdReactionKind.soloOrDrop,
    );

    // Acoustic Hush Breakdown -> hushSway!
    director.update(
      dt: 0.5,
      clock: clock1,
      flags: flags,
      liveStages: {
        'main_roots_stage': LiveStageVisualState(
          stageId: 'main_roots_stage',
          track: track1,
          primaryColor: const Color(0xFFFFB703),
          secondaryColor: const Color(0xFFFB5607),
          show: frameWith(
            trackTimeSec: 112.0,
            mode: LightShowSectionMode.hushGlow,
          ),
        ),
      },
      namedNpcs: const [],
      playerPos: Vector2(608, 520),
      bassLevel: 0.25,
      nightSparklerWave: false,
      clockJumped: false,
    );
    expect(
      director.stageReactionFor('main_roots_stage'),
      CrowdReactionKind.hushSway,
    );

    // Set concludes (liveStages becomes empty without clockJumped) -> standing ovation!
    director.update(
      dt: 0.5,
      clock: clock1,
      flags: flags,
      liveStages: const {},
      namedNpcs: const [],
      playerPos: Vector2(608, 520),
      bassLevel: 0.0,
      nightSparklerWave: false,
      clockJumped: false,
    );
    expect(
      director.stageReactionFor('main_roots_stage'),
      CrowdReactionKind.encoreOvation,
    );

    // 2. Verify 3-Day Evolving Conversations for both FestivalGoers AND Named NPCs!
    final goer = director.activeCrowdActors.first;
    final noraActor = game.npcActorById('nora_walnut')!;

    List<String> captureNamedNpcLines(NpcActor actor) {
      game.teleportPlayer(actor.position.x, actor.position.y + 12.0);
      game.handleInteract();
      final lines =
          List<String>.from(container.read(uiOverlayProvider).dialogue!.lines);
      while (container.read(uiOverlayProvider).dialogue != null) {
        container.read(uiOverlayProvider.notifier).advanceOrCloseDialogue();
      }
      return lines;
    }

    // Day 1 Conversation
    clockN.setClockDirect(day: 1, minuteOfDay: 520.0);
    game.update(0.05);
    final goerDay1 = director
        .buildFestivalGoerDialogue(
          goer: goer,
          clock: container.read(festivalClockProvider),
          flags: container.read(worldFlagsProvider),
          liveStages: game.liveStageVisuals,
        )
        .join(' ');
    final noraDay1 = captureNamedNpcLines(noraActor).join(' ');

    // Day 2 Conversation
    clockN.setClockDirect(day: 2, minuteOfDay: 760.0);
    game.update(0.05);
    final goerDay2 = director
        .buildFestivalGoerDialogue(
          goer: goer,
          clock: container.read(festivalClockProvider),
          flags: container.read(worldFlagsProvider),
          liveStages: game.liveStageVisuals,
        )
        .join(' ');
    final noraDay2 = captureNamedNpcLines(noraActor).join(' ');

    // Day 3 Conversation
    clockN.setClockDirect(day: 3, minuteOfDay: 1210.0);
    game.update(0.05);
    final goerDay3 = director
        .buildFestivalGoerDialogue(
          goer: goer,
          clock: container.read(festivalClockProvider),
          flags: container.read(worldFlagsProvider),
          liveStages: game.liveStageVisuals,
        )
        .join(' ');
    final noraDay3 = captureNamedNpcLines(noraActor).join(' ');

    expect(goerDay1, isNot(equals(goerDay2)));
    expect(goerDay2, isNot(equals(goerDay3)));
    expect(goerDay1, isNot(equals(goerDay3)));

    expect(noraDay1, contains('Day 1'));
    expect(noraDay2, contains('Day 2'));
    expect(noraDay3, contains('Day 3'));

    // Also verify interactive handleInteract() directly on an open-ground FestivalGoer opens their dialogue!
    final openGoer = director.activeCrowdActors.firstWhere(
      (g) =>
          map.interactables.every(
            (o) =>
                (o.rect.center - Offset(g.position.x, g.position.y)).distance >
                60.0,
          ) &&
          bundle.npcs.every(
            (n) =>
                game.npcActorById(n.id)!.position.distanceTo(g.position) > 60.0,
          ),
    );
    game.teleportPlayer(openGoer.position.x, openGoer.position.y + 10.0);
    game.handleInteract();
    final goerSession = container.read(uiOverlayProvider).dialogue;
    expect(goerSession, isNotNull);
    expect(goerSession!.speakerName, openGoer.spec.name);
  });
}
