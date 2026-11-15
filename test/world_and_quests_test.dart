import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Canvas, Offset, PictureRecorder, Rect;
import 'package:flame/components.dart' show Vector2;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walnutstock/audio/soloud_audio_service.dart';
import 'package:walnutstock/audio/spatial_stage_emitter.dart';
import 'package:walnutstock/data/models.dart';
import 'package:walnutstock/game/actors/catmull_rom_spline.dart';
import 'package:walnutstock/game/walnutstock_game.dart';
import 'package:walnutstock/game/world/astar_pathfinder.dart';
import 'package:walnutstock/game/world/festival_grounds_scenery_component.dart';
import 'package:walnutstock/game/world/tiled_map_parser.dart';
import 'package:walnutstock/game/world/world_mutators.dart';
import 'package:walnutstock/state/dialogue_and_overlay_state.dart';
import 'package:walnutstock/state/journal_state.dart';
import 'package:walnutstock/state/providers.dart';
import 'package:walnutstock/state/save_repository.dart';
import 'package:walnutstock/state/world_flags.dart';

void main() {
  late OrchardMapData map;
  late FestivalDataBundle bundle;

  setUp(() {
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

  group('9-Zone Tiled World, Mutators, Asphalt-Avoidance A*, and Splines', () {
    test(
        'parses 128x96 map, all 9 festival zones, and .tsx surface properties cleanly',
        () {
      expect(map.width, 128);
      expect(map.height, 96);
      expect(map.zones.length, 9);

      // Andromeda Pavilion crystal dome has low_gravity crystal_floor
      expect(map.surfaceAtWorld(1760, 352), 'crystal_floor');
      expect(map.isLowGravityAtWorld(1760, 352), isTrue);

      // Mellow Meadow service strip has asphalt
      expect(map.surfaceAtWorld(79.5 * 16, 28.5 * 16), 'asphalt');

      // Sorting Machine Arcade Tent has canopy/tent audio occlusion
      expect(map.isOccludedAtWorld(1744, 1024), isTrue);
    });

    test(
        'all 34 NPCs, 11 Cultivars, 20 Wardrobe outfits, 18 Items, 18 Quests, and 8 3D Totems spawn on non-blocked walkable coordinates',
        () {
      expect(bundle.npcs.length, 34);
      expect(bundle.cultivars.length, 11);
      expect(bundle.wardrobe.length, 20);
      expect(bundle.items.length, 18);
      expect(bundle.quests.length, 18);
      expect(bundle.totems.length, 8);

      for (final npc in bundle.npcs) {
        expect(
          map.isPointBlocked(npc.spawnX, npc.spawnY),
          isFalse,
          reason:
              'NPC ${npc.id} spawned on blocked tile (${npc.spawnX}, ${npc.spawnY})',
        );
        if (npc.questId != null) {
          expect(
            bundle.questById(npc.questId!),
            isNotNull,
            reason: 'NPC ${npc.id} questId ${npc.questId} missing in quests',
          );
        }
      }
      for (final q in bundle.quests) {
        expect(
          map.isPointBlocked(q.targetX, q.targetY),
          isFalse,
          reason:
              'Quest ${q.id} target (${q.targetX}, ${q.targetY}) is blocked',
        );
      }
      for (final stallName in const [
        'penny_craft_blanket',
        'colin_curio_crate',
        'street_food_cart',
        'bulletin_lost_found',
        'lost_brass_compass',
      ]) {
        final zone = map.interactables.firstWhere((o) => o.name == stallName);
        expect(
          map.isPointBlocked(zone.rect.center.dx, zone.rect.center.dy),
          isFalse,
          reason: 'Interactable $stallName center is blocked',
        );
      }
      for (final totem in bundle.totems) {
        expect(
          map.isPointBlocked(totem.x, totem.y),
          isFalse,
          reason:
              'Totem ${totem.id} spawned on blocked tile (${totem.x}, ${totem.y})',
        );
      }
    });

    test(
        'WorldMutators: Fence Drop, Janice Moss-Bloom Ledge, and Saturday Slippery Mud',
        () {
      final mutators = WorldMutators(map);

      // 1. Front Gate fence at (37, 74) starts blocked, then opens on Track 2!
      expect(map.isTileBlocked(37, 74), isTrue);
      expect(mutators.applyFenceDrop(), isTrue);
      expect(map.isTileBlocked(37, 74), isFalse);

      // 2. Cliff bark wall behind Velvet Canopy at (13, 15) starts blocked, then blooms into climbable moss!
      expect(map.isTileBlocked(13, 15), isTrue);
      expect(mutators.applyMossBloom(), isTrue);
      expect(map.isTileBlocked(13, 15), isFalse);
      expect(map.surfaceAtWorld(13.5 * 16, 15.5 * 16), 'moss');

      // Verify player can now pathfind from Velvet Canopy Stage right onto Upper Velvet Ledge (Totem #5)!
      final ledgePath = AStarPathfinder(map).findWorldPath(
        startX: 224.0,
        startY: 360.0,
        goalX: 192.0,
        goalY: 144.0,
      );
      expect(ledgePath, isNotEmpty);

      // 3. Dirt lane at (37, 60) turns into slippery mud during Saturday rainstorm, then restores!
      expect(map.surfaceAtWorld(37.5 * 16, 60.5 * 16), 'dirt');
      expect(map.isSlipperyAtWorld(37.5 * 16, 60.5 * 16), isFalse);

      expect(mutators.syncRainstormMud(true), isTrue);
      expect(map.surfaceAtWorld(37.5 * 16, 60.5 * 16), 'mud');
      expect(map.isSlipperyAtWorld(37.5 * 16, 60.5 * 16), isTrue);

      expect(mutators.syncRainstormMud(false), isTrue);
      expect(map.surfaceAtWorld(37.5 * 16, 60.5 * 16), 'dirt');
    });

    test(
        'Barnaby Breeze-Walker A* pathfinder strictly routes around asphalt ("concrete silence")',
        () {
      final path = AStarPathfinder(map).findWorldPath(
        startX: 1216.0,
        startY: 448.0,
        goalX: 1344.0,
        goalY: 448.0,
        avoidAsphalt: true,
      );
      expect(path, isNotEmpty);
      for (final (wx, wy) in path) {
        expect(
          map.surfaceAtWorld(wx, wy),
          isNot('asphalt'),
          reason: 'Barnaby stepped on asphalt at ($wx, $wy)!',
        );
      }
    });

    test(
        'Boundary & degenerate inputs on A* pathfinder and Catmull-Rom spline do not crash',
        () {
      expect(map.isTileBlocked(-5, -10), isTrue);
      expect(map.isTileBlocked(999, 999), isTrue);

      // Out-of-bounds goal clamps cleanly to nearest walkable tile without hanging
      final clampedPath = AStarPathfinder(map).findWorldPath(
        startX: 608.0,
        startY: 1344.0,
        goalX: -9000.0,
        goalY: 9000.0,
      );
      expect(clampedPath, isA<List<(double, double)>>());

      // Empty & single-point splines return graceful defaults without division by zero
      const emptySpline = CatmullRomSpline2D([]);
      expect(emptySpline.evaluate(0.5), Offset.zero);
      expect(emptySpline.tangent(0.5), const Offset(1, 0));

      const singleSpline = CatmullRomSpline2D([Offset(42, 99)]);
      expect(singleSpline.evaluate(0.75), const Offset(42, 99));
    });

    test(
        'Ziggy Shell-shock CatmullRomSpline2D is closed and C1-continuous across control seams',
        () {
      final ziggy = bundle.npcById('ziggy_shellshock')!;
      final spline = CatmullRomSpline2D(
        ziggy.waypoints.map((w) => Offset(w[0], w[1])).toList(),
      );

      final p0 = spline.evaluate(0.0);
      final p1 = spline.evaluate(0.999999);
      expect((p0 - p1).distance, lessThan(0.05));

      for (final seam in [0.0, 0.25, 0.5, 0.75]) {
        final tBefore = spline.tangent(seam - 1e-5);
        final tAfter = spline.tangent(seam + 1e-5);
        expect((tBefore - tAfter).distance, lessThan(0.25));
      }
    });

    test(
        'Undergrowth Psych-Rock Fog stereo C-Major bell beacon pans accurately left/right',
        () {
      final bellStage = bundle.setlist.stages['undergrowth_bells']!;
      // Standing west of sacred Tea-Light Circle -> bells pan into right ear (+)
      final westMix = SpatialStageEmitter.computeMix(
        stage: bellStage,
        listenerX: bellStage.x - 160.0,
        listenerY: bellStage.y + 40.0,
        listenerInOcclusionZone: false,
        isPaBroadcastTrack: false,
        paBroadcastCurrentlyActive: false,
      );
      expect(westMix.isAudible, isTrue);
      expect(westMix.pan, greaterThan(0.4));

      // Standing east of sacred Tea-Light Circle -> bells pan into left ear (-)
      final eastMix = SpatialStageEmitter.computeMix(
        stage: bellStage,
        listenerX: bellStage.x + 160.0,
        listenerY: bellStage.y + 40.0,
        listenerInOcclusionZone: false,
        isPaBroadcastTrack: false,
        paBroadcastCurrentlyActive: false,
      );
      expect(eastMix.isAudible, isTrue);
      expect(eastMix.pan, lessThan(-0.4));
    });

    test(
        'Quest gating & multi-step cast questlines enforce prerequisites and award rewards',
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

      void closeActiveDialogue() {
        while (container.read(uiOverlayProvider).dialogue != null) {
          container.read(uiOverlayProvider.notifier).advanceOrCloseDialogue();
        }
      }

      // 1. Falafel stand is gated BEFORE talking to Burt Baskernut
      final falafelRect =
          map.interactables.firstWhere((o) => o.name == 'falafel_stand').rect;
      game.teleportPlayer(falafelRect.center.dx, falafelRect.center.dy);
      game.handleInteract();
      expect(container.read(worldFlagsProvider).falafelCiderOffered, isFalse);

      // Talk to Burt -> unlock quest -> pour cider -> return to Burt -> unlocks Slow-Wave Sway!
      final burt = bundle.npcById('burt_baskernut')!;
      game.teleportPlayer(burt.spawnX, burt.spawnY + 12);
      game.handleInteract();
      closeActiveDialogue();
      expect(container.read(worldFlagsProvider).burtQuestStarted, isTrue);

      game.teleportPlayer(falafelRect.center.dx, falafelRect.center.dy);
      game.handleInteract();
      expect(container.read(worldFlagsProvider).falafelCiderOffered, isTrue);

      game.teleportPlayer(burt.spawnX, burt.spawnY + 8);
      game.handleInteract();
      closeActiveDialogue();
      expect(container.read(worldFlagsProvider).burtQuestCompleted, isTrue);
      expect(container.read(worldFlagsProvider).slowWaveSwayUnlocked, isTrue);

      // 2. Janice Joeplant Vocal Tea -> physical Moss-Bloom + Vinyl Side B + Amethyst Specs
      final janice = bundle.npcById('janice_joeplant')!;
      final kettle =
          map.interactables.firstWhere((o) => o.name == 'vocal_tea_vine').rect;
      game.teleportPlayer(kettle.center.dx, kettle.center.dy);
      game.handleInteract();
      expect(container.read(worldFlagsProvider).hasVocalTea, isFalse); // Gated!

      game.teleportPlayer(janice.spawnX, janice.spawnY + 10);
      game.handleInteract();
      closeActiveDialogue();
      expect(container.read(worldFlagsProvider).janiceQuestStarted, isTrue);

      game.teleportPlayer(kettle.center.dx, kettle.center.dy);
      game.handleInteract();
      expect(container.read(worldFlagsProvider).hasVocalTea, isTrue);

      game.teleportPlayer(janice.spawnX, janice.spawnY + 10);
      game.handleInteract();
      closeActiveDialogue();
      expect(container.read(worldFlagsProvider).janiceQuestCompleted, isTrue);
      expect(container.read(worldFlagsProvider).mossBridgesBloomed, isTrue);
      expect(container.read(journalStateProvider).collectedVinylIds,
          contains('vinyl_side_b'));
      expect(container.read(playerProfileProvider).unlockedWardrobeIds,
          contains('amethyst_specs'));

      // 3. Cosmo Shell-voy: Tune 3 Meteoric Space-Glass Resonators -> Astral Bootleg + Low-Gravity boost
      final cosmo = bundle.npcById('cosmo_shellvoy')!;
      game.teleportPlayer(cosmo.spawnX, cosmo.spawnY + 10);
      game.handleInteract();
      closeActiveDialogue();
      for (final resName in ['resonator_nw', 'resonator_ne', 'resonator_se']) {
        final r = map.interactables.firstWhere((o) => o.name == resName).rect;
        game.teleportPlayer(r.center.dx, r.center.dy);
        game.handleInteract();
      }
      expect(container.read(worldFlagsProvider).tunedResonators.length, 3);
      game.teleportPlayer(cosmo.spawnX, cosmo.spawnY + 10);
      game.handleInteract();
      closeActiveDialogue();
      expect(container.read(worldFlagsProvider).cosmoQuestCompleted, isTrue);
      expect(container.read(journalStateProvider).collectedVinylIds,
          contains('vinyl_bootleg_drupe'));

      // 4. Jimi Hendshell Great Walnut Ritual now sees >=3 harmony quests completed!
      expect(container.read(worldFlagsProvider).hasHarmonyMilestoneForJimi,
          isTrue);
      final jimi = bundle.npcById('jimi_hendshell')!;
      game.teleportPlayer(jimi.spawnX, jimi.spawnY + 10);
      game.handleInteract();
      closeActiveDialogue();
      game.handleInteract();
      closeActiveDialogue();
      expect(container.read(worldFlagsProvider).jimiQuestCompleted, isTrue);
      expect(container.read(journalStateProvider).collectedVinylIds,
          contains('vinyl_side_d'));
    });

    test(
        'JournalState and WorldFlags persist all Festival Satchel items, Peace Beads, and 8 new side-quest states cleanly',
        () {
      const journal = JournalState(
        inventoryCounts: {
          'gadget_bubble_wand': 1,
          'food_falafel_wrap': 3,
          'vip_all_stage_laminate': 1,
        },
        equippedGadgetId: 'gadget_bubble_wand',
        peaceBeads: 47,
        snappedPolaroidStages: {'main_roots', 'velvet_canopy'},
        recordedBootlegStages: {'urbano_canopy'},
        trackedQuestId: 'quest_sunny_polaroids',
      );
      final roundTripJournal = JournalState.fromJson(journal.toJson());
      expect(roundTripJournal.inventoryCounts, journal.inventoryCounts);
      expect(roundTripJournal.equippedGadgetId, 'gadget_bubble_wand');
      expect(roundTripJournal.peaceBeads, 47);
      expect(
        roundTripJournal.snappedPolaroidStages,
        containsAll(['main_roots', 'velvet_canopy']),
      );
      expect(roundTripJournal.recordedBootlegStages, contains('urbano_canopy'));
      expect(roundTripJournal.trackedQuestId, 'quest_sunny_polaroids');

      const flags = WorldFlags(
        sunnyPhotoQuestStarted: true,
        sunnyPhotoQuestCompleted: true,
        roxieStringQuestStarted: true,
        hasNickelString: true,
        roxieStringQuestCompleted: true,
        pennyTapestryQuestStarted: true,
        fabricSwatches: {'swatch_gate_petal', 'swatch_meadow_clover'},
        fernCompassQuestCompleted: true,
        astraBubbleQuestCompleted: true,
        woodyMunchiesQuestCompleted: true,
        rustyArcadeQuestCompleted: true,
        daisyFreeBubblesGifted: true,
        beachBallMaxRally: 9,
        collectedGroundBeadIds: {'beads_gate', 'beads_roots'},
      );
      final roundTripFlags = WorldFlags.fromJson(flags.toJson());
      expect(roundTripFlags.sunnyPhotoQuestCompleted, isTrue);
      expect(roundTripFlags.roxieStringQuestCompleted, isTrue);
      expect(roundTripFlags.fabricSwatches.length, 2);
      expect(roundTripFlags.fernCompassQuestCompleted, isTrue);
      expect(roundTripFlags.astraBubbleQuestCompleted, isTrue);
      expect(roundTripFlags.woodyMunchiesQuestCompleted, isTrue);
      expect(roundTripFlags.rustyArcadeQuestCompleted, isTrue);
      expect(roundTripFlags.daisyFreeBubblesGifted, isTrue);
      expect(roundTripFlags.beachBallMaxRally, 9);
      expect(roundTripFlags.collectedGroundBeadIds, contains('beads_gate'));
    });

    test(
        '8 new Festival Side Quests, Satchel Gadgets, Street Food Buffs, Nighttime Sparkler Lighter Wave, and 3D Beach Ball Volley work end-to-end',
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
      game.onGameResize(Vector2(1280, 720));
      await game.onLoad();

      void closeActiveDialogue() {
        while (container.read(uiOverlayProvider).dialogue != null) {
          container.read(uiOverlayProvider.notifier).advanceOrCloseDialogue();
        }
      }

      // 1. Daisy Sprout gifts free Soap Bubble Wand -> blow bubbles inside Andromeda Dome -> Astra Hindsii awards Streamers!
      final daisy = bundle.npcById('daisy_dewdrop')!;
      game.teleportPlayer(daisy.spawnX, daisy.spawnY + 10);
      game.handleInteract();
      closeActiveDialogue();
      expect(container.read(worldFlagsProvider).daisyFreeBubblesGifted, isTrue);
      expect(
        container.read(journalStateProvider).hasItem('gadget_bubble_wand'),
        isTrue,
      );
      expect(
        container.read(journalStateProvider).equippedGadgetId,
        'gadget_bubble_wand',
      );

      final astra = bundle.npcById('astra_nebula')!;
      game.teleportPlayer(astra.spawnX, astra.spawnY + 10);
      game.handleInteract();
      closeActiveDialogue();
      expect(
        container.read(worldFlagsProvider).astraBubbleQuestStarted,
        isTrue,
      );

      // Step onto low-gravity crystal dome floor & press [Q] (useEquippedFestivalItem)
      game.teleportPlayer(1760, 352);
      game.useEquippedFestivalItem();
      expect(container.read(worldFlagsProvider).bubbledInDome, isTrue);

      game.teleportPlayer(astra.spawnX, astra.spawnY + 10);
      game.handleInteract();
      closeActiveDialogue();
      expect(
        container.read(worldFlagsProvider).astraBubbleQuestCompleted,
        isTrue,
      );
      expect(
        container.read(journalStateProvider).hasItem('gadget_streamers'),
        isTrue,
      );

      // 2. Roxie Espresso Broken String Emergency -> Colin Shellford -> Encore Sparkler + Nighttime Concert Lighter Wave!
      final roxie = bundle.npcById('roxie_roast')!;
      game.teleportPlayer(roxie.spawnX, roxie.spawnY + 10);
      game.handleInteract();
      closeActiveDialogue();
      expect(
        container.read(worldFlagsProvider).roxieStringQuestStarted,
        isTrue,
      );

      final colin = bundle.npcById('colin_walnut')!;
      game.teleportPlayer(colin.spawnX, colin.spawnY + 10);
      game.handleInteract();
      closeActiveDialogue();
      expect(container.read(worldFlagsProvider).hasNickelString, isTrue);
      expect(
        container.read(journalStateProvider).hasItem('quest_nickel_string'),
        isTrue,
      );

      game.teleportPlayer(roxie.spawnX, roxie.spawnY + 10);
      game.handleInteract();
      closeActiveDialogue();
      expect(
        container.read(worldFlagsProvider).roxieStringQuestCompleted,
        isTrue,
      );
      expect(
        container.read(journalStateProvider).hasItem('gadget_sparkler'),
        isTrue,
      );

      // Jump to a nighttime live set at Main Roots & light the Encore Sparkler!
      final nightTrack = bundle.setlist.tracks.firstWhere(
        (t) => t.stageId == 'main_roots_stage' && t.startMinute >= 1140,
      );
      container.read(festivalClockProvider.notifier).jumpToTrack(nightTrack);
      game.teleportPlayer(600, 464);
      game.useEquippedFestivalItem('gadget_sparkler');
      expect(container.read(worldFlagsProvider).sparklerLit, isTrue);
      game.update(0.1);

      final worldLights =
          game.collectVisibleWorldLights(const Rect.fromLTWH(0, 0, 2048, 1536));
      expect(
        worldLights.any((l) => l.radius == 84.0),
        isTrue,
        reason: 'Lit Encore Sparkler should emit dynamic LightSource3D',
      );
      expect(
        [
          game.npcActorById('sunny_shellflower'),
          game.npcActorById('hazel_groove'),
        ].any((a) => a?.holdingConcertLighter ?? false),
        isTrue,
        reason:
            'Nearby stage dancers should raise concert lighters when player waves Encore Sparkler at night',
      );

      // 3. Sunny Shellflower Front-Row Press Pass -> Snap Polaroids at 3 live stages -> Press Vest + Tambourine!
      final sunny = bundle.npcById('sunny_shellflower')!;
      game.teleportPlayer(sunny.spawnX, sunny.spawnY + 10);
      game.handleInteract();
      closeActiveDialogue();
      expect(container.read(worldFlagsProvider).sunnyPhotoQuestStarted, isTrue);
      expect(
        container.read(journalStateProvider).hasItem('gadget_polaroid'),
        isTrue,
      );

      for (final stageId in [
        'main_roots_stage',
        'mellow_meadow_stage',
        'velvet_canopy_stage',
      ]) {
        final track =
            bundle.setlist.tracks.firstWhere((t) => t.stageId == stageId);
        container.read(festivalClockProvider.notifier).jumpToTrack(track);
        final stage = bundle.setlist.stages[stageId]!;
        game.teleportPlayer(stage.x, stage.y + 60);
        game.update(0.05);
        game.useEquippedFestivalItem('gadget_polaroid');
      }
      expect(
        container.read(journalStateProvider).snappedPolaroidStages.length,
        3,
      );

      final sunnyActor = game.npcActorById('sunny_shellflower')!;
      game.teleportPlayer(sunnyActor.position.x, sunnyActor.position.y + 10);
      game.handleInteract();
      closeActiveDialogue();
      expect(
        container.read(worldFlagsProvider).sunnyPhotoQuestCompleted,
        isTrue,
      );
      expect(
        container.read(playerProfileProvider).unlockedWardrobeIds,
        contains('press_photographer_vest'),
      );
      expect(
        container.read(journalStateProvider).hasItem('gadget_tambourine'),
        isTrue,
      );

      // 4. Penny Patchwork Great Festival Tapestry -> 3 swatches -> Picnic Blanket + Artisan Cape!
      final penny = bundle.npcById('penny_patchwork')!;
      game.teleportPlayer(penny.spawnX, penny.spawnY + 10);
      game.handleInteract();
      closeActiveDialogue();
      expect(
        container.read(worldFlagsProvider).pennyTapestryQuestStarted,
        isTrue,
      );

      for (final helperId in ['daisy_dewdrop', 'clover_husk', 'paloma_hull']) {
        final helper = bundle.npcById(helperId)!;
        game.teleportPlayer(helper.spawnX, helper.spawnY + 10);
        game.handleInteract();
        closeActiveDialogue();
      }
      expect(container.read(worldFlagsProvider).fabricSwatches.length, 3);

      game.teleportPlayer(penny.spawnX, penny.spawnY + 10);
      game.handleInteract();
      closeActiveDialogue();
      expect(
        container.read(worldFlagsProvider).pennyTapestryQuestCompleted,
        isTrue,
      );
      expect(
        container.read(playerProfileProvider).unlockedWardrobeIds,
        contains('artisan_patchwork_cape'),
      );
      expect(
        container.read(journalStateProvider).hasItem('gadget_picnic_blanket'),
        isTrue,
      );

      // Unroll the Woven Picnic Blanket on the grass!
      game.useEquippedFestivalItem('gadget_picnic_blanket');
      expect(container.read(worldFlagsProvider).picnicBlanketDeployed, isTrue);

      // 5. Fern Whisper-Shell Lost Compass -> 5th quest unlocks VIP All-Stage Laminate!
      final compassRect = map.interactables
          .firstWhere((o) => o.name == 'lost_brass_compass')
          .rect;
      game.teleportPlayer(compassRect.center.dx, compassRect.center.dy);
      game.handleInteract();
      expect(container.read(worldFlagsProvider).hasBrassCompass, isTrue);

      final fern = bundle.npcById('fern_whisper')!;
      game.teleportPlayer(fern.spawnX, fern.spawnY + 10);
      game.handleInteract();
      closeActiveDialogue();
      expect(
        container.read(worldFlagsProvider).fernCompassQuestCompleted,
        isTrue,
      );
      expect(container.read(worldFlagsProvider).completedQuestCount, 5);
      expect(
        container.read(journalStateProvider).hasItem('vip_all_stage_laminate'),
        isTrue,
      );

      // 6. Street Food Buffs (Falafel speed + Persimmon Cider mud grip) & 3D Crowd Beach Ball Volley!
      container.read(journalStateProvider.notifier).grantItem(
            'food_falafel_wrap',
            count: 1,
          );
      container.read(journalStateProvider.notifier).grantItem(
            'drink_persimmon_cider',
            count: 1,
          );
      game.useEquippedFestivalItem('food_falafel_wrap');
      expect(
        container.read(worldFlagsProvider).activeSpeedMultiplier,
        greaterThan(1.1),
      );
      game.useEquippedFestivalItem('drink_persimmon_cider');
      expect(container.read(worldFlagsProvider).mudGripActive, isTrue);

      // Walk into the Main Roots Crowd Beach Ball to volley it skyward!
      final ball = game.festivalProps!.beachBalls.first;
      ball.z = 12.0;
      ball.playerHitCooldown = 0.0;
      game.teleportPlayer(ball.x, ball.y);
      game.update(0.05);
      expect(
        container.read(worldFlagsProvider).beachBallMaxRally,
        greaterThanOrEqualTo(1),
      );
    });

    test(
        'Redesigned Festival Grounds: 84-tile 2.5D tileset, Willow Creek & 3 Cedar Footbridges, Crossroads Peace Mosaic, Campfire Hearth, and Catenary Garlands work end-to-end',
        () async {
      // 1. Verify expanded 84-tile .tsx properties (keyed by 0-based tile id)
      expect(map.tileDefs.length, greaterThanOrEqualTo(84));
      expect(map.tileDefs[53]?.surface, 'stone'); // id 53 sandstone cobbles
      expect(map.tileDefs[56]?.surface, 'water'); // id 56 deep creek stream
      expect(map.tileDefs[56]?.collidable, isTrue);
      expect(map.tileDefs[59]?.surface, 'wood_stage'); // id 59 cedar bridge
      expect(map.tileDefs[59]?.collidable, isFalse);
      expect(map.tileDefs[69]?.canopy, isTrue); // id 69 weeping willow fronds
      expect(map.tileDefs[70]?.canopy, isTrue); // id 70 walnut canopy L
      expect(map.tileDefs[79]?.lantern, isTrue); // id 79 campfire hearth
      expect(map.tileDefs[81]?.lantern, isTrue); // id 81 festoon post

      // 2. Eastern Willow Creek blocks direct wading while all 3 Cedar Footbridges carry A* traffic
      expect(map.surfaceAtWorld(1464, 728), 'water');
      expect(map.isPointBlocked(1464, 728), isTrue);

      for (final bridgePt in FestivalGroundsSceneryController.easternCreekBridges) {
        expect(map.surfaceAtWorld(bridgePt.dx, bridgePt.dy), 'wood_stage');
        expect(map.isPointBlocked(bridgePt.dx, bridgePt.dy), isFalse);
      }

      final pathfinder = AStarPathfinder(map);
      final northBridgePath = pathfinder.findWorldPath(
        startX: 1200,
        startY: 624,
        goalX: 1664,
        goalY: 624,
      );
      expect(northBridgePath, isNotEmpty);
      expect(
        northBridgePath.any((pt) => (pt.$1 - 1476).abs() <= 32),
        isTrue,
        reason: 'North Boulevard A* path should cross the North Cedar Footbridge',
      );

      final southBridgePath = pathfinder.findWorldPath(
        startX: 1296,
        startY: 1104,
        goalX: 1664,
        goalY: 1104,
      );
      expect(southBridgePath, isNotEmpty);
      expect(
        southBridgePath.any((pt) => (pt.$1 - 1476).abs() <= 32),
        isTrue,
        reason: 'South Boulevard A* path should cross the South Cedar Footbridge',
      );

      // 3. Central Crossroads Peace Mosaic (608, 864) is stone and stays dry during Rainstorm Mud
      expect(map.surfaceAtWorld(608, 864), 'stone');
      final mutators = WorldMutators(map);
      mutators.syncRainstormMud(true);
      expect(map.surfaceAtWorld(608, 864), 'stone');
      mutators.syncRainstormMud(false);

      // 4. Mount WalnutstockGame and verify FestivalGroundsSceneryController, Crossroads Signpost & Lights
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
      game.onGameResize(Vector2(1280, 720));
      await game.onLoad();
      game.update(0.05);

      expect(game.groundsScenery, isNotNull);
      expect(game.groundsScenery!.surfaceLayer.parent, same(game.world));
      expect(game.groundsScenery!.propsLayer.parent, same(game.world));
      expect(game.groundsScenery!.overheadLayer.parent, same(game.world));
      expect(game.groundsScenery!.surfaceLayer.priority, -4450);
      expect(game.groundsScenery!.propsLayer.priority, 1290);
      expect(game.groundsScenery!.overheadLayer.priority, 6250);

      // Walking up to the Central Crossroads Trail Signpost and interacting opens the Orchard Map tab
      final signPos = FestivalGroundsSceneryController.crossroadsFingerpostPos;
      game.teleportPlayer(signPos.dx, signPos.dy + 16);
      game.update(0.05);
      expect(
        container.read(uiOverlayProvider).nearbyInteractPrompt,
        contains('Crossroads Trail Signpost'),
      );
      game.handleInteract();
      expect(container.read(uiOverlayProvider).pocketProgramOpen, isTrue);
      expect(
        container.read(uiOverlayProvider).pocketProgramTab,
        PocketProgramTab.orchardMap,
      );
      container.read(uiOverlayProvider.notifier).closePocketProgram();

      // Dusk/Night lightmap includes Campfire Hearth, Crossroads Mosaic, and FOH Tower pools
      final nightTrack = bundle.setlist.tracks.firstWhere(
        (t) => t.startMinute >= 1200,
      );
      container.read(festivalClockProvider.notifier).jumpToTrack(nightTrack);
      game.update(0.05);

      // Render across key redesigned landmarks to ensure zero canvas/shader exceptions
      for (final (rx, ry) in const [
        (608.0, 864.0), // Crossroads Peace Mosaic + Fingerpost + X-Garlands
        (1080.0, 1048.0), // Shady Bottoms Campfire Hearth + Vendor Row Pergolas
        (776.0, 568.0), // Main Roots FOH Sound & Liquid-Light Mixing Tower
        (1476.0, 624.0), // Eastern Willow Creek & North Cedar Footbridge
        (1760.0, 352.0), // Andromeda Pavilion Ley-Line Conduits
      ]) {
        game.teleportPlayer(rx, ry);
        game.update(0.05);
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        game.groundsScenery!.surfaceLayer.render(canvas);
        game.groundsScenery!.propsLayer.render(canvas);
        game.groundsScenery!.overheadLayer.render(canvas);
        recorder.endRecording().dispose();
      }

      final allLights = game.collectVisibleWorldLights(
        const Rect.fromLTWH(0, 0, 2048, 1536),
      );
      expect(
        allLights.any(
          (l) =>
              (l.position -
                      FestivalGroundsSceneryController.campgroundFireCenter)
                  .distance <
              2.0,
        ),
        isTrue,
        reason: 'Shady Bottoms Campfire Hearth should emit warm LightSource3D',
      );
      expect(
        allLights.any(
          (l) =>
              (l.position -
                      FestivalGroundsSceneryController.crossroadsPlazaCenter)
                  .distance <
              2.0,
        ),
        isTrue,
        reason: 'Central Crossroads Peace Mosaic should emit dusk LightSource3D',
      );
      expect(
        allLights.any(
          (l) =>
              (l.position -
                      FestivalGroundsSceneryController.mainRootsFohTowerCenter)
                  .distance <
              2.0,
        ),
        isTrue,
        reason: 'Main Roots FOH Mixing Tower should emit liquid-light glow',
      );
    });
  });
}
