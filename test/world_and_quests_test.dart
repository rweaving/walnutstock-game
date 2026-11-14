import 'dart:convert';
import 'dart:io';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walnutstock/audio/soloud_audio_service.dart';
import 'package:walnutstock/audio/spatial_stage_emitter.dart';
import 'package:walnutstock/data/models.dart';
import 'package:walnutstock/game/actors/catmull_rom_spline.dart';
import 'package:walnutstock/game/walnutstock_game.dart';
import 'package:walnutstock/game/world/astar_pathfinder.dart';
import 'package:walnutstock/game/world/tiled_map_parser.dart';
import 'package:walnutstock/game/world/world_mutators.dart';
import 'package:walnutstock/state/providers.dart';
import 'package:walnutstock/state/save_repository.dart';

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
        'all 34 NPCs, 11 Cultivars, 16 Wardrobe outfits, and all 8 3D Totems spawn on non-blocked walkable coordinates',
        () {
      expect(bundle.npcs.length, 34);
      expect(bundle.cultivars.length, 11);
      expect(bundle.wardrobe.length, 16);
      expect(bundle.totems.length, 8);

      for (final npc in bundle.npcs) {
        expect(
          map.isPointBlocked(npc.spawnX, npc.spawnY),
          isFalse,
          reason:
              'NPC ${npc.id} spawned on blocked tile (${npc.spawnX}, ${npc.spawnY})',
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
  });
}
