import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart' show Vector2;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walnutstock/audio/audio_schedule_controller.dart';
import 'package:walnutstock/audio/ogg_opus_slicer.dart';
import 'package:walnutstock/audio/progressive_track_cache.dart';
import 'package:walnutstock/audio/soloud_audio_service.dart';
import 'package:walnutstock/data/models.dart';
import 'package:walnutstock/game/actors/npc_actor.dart';
import 'package:walnutstock/game/minigames/sorting_belt_blues_game.dart';
import 'package:walnutstock/game/walnutstock_game.dart';
import 'package:walnutstock/game/world/tiled_map_parser.dart';
import 'package:walnutstock/game/world/world_mutators.dart';
import 'package:walnutstock/game/zones/psych_rock_fog_zone.dart';
import 'package:walnutstock/state/festival_clock.dart';
import 'package:walnutstock/state/providers.dart';
import 'package:walnutstock/state/save_repository.dart';
import 'package:walnutstock/state/settings_state.dart';

class RecordingAudioService extends SoloudAudioService {
  final Map<String, ({String trackId, double volume, double pan, bool looping})>
      activeSlots = {};
  final List<(String slotKey, String trackId)> streamLoads = [];
  final List<String> stoppedSlots = [];
  final List<(String asset, double pan)> sfxPlayed = [];
  double lastLowPassCutoffHz = -1.0;

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
      streamLoads.add((slotKey, trackId));
    }
    activeSlots[slotKey] = (
      trackId: trackId,
      volume: volume,
      pan: pan,
      looping: looping,
    );
  }

  @override
  Future<void> stopSlot(String slotKey) async {
    if (activeSlots.remove(slotKey) != null) {
      stoppedSlots.add(slotKey);
    }
  }

  @override
  void updateCanopyLowPass(double cutoffHz) {
    lastLowPassCutoffHz = cutoffHz;
  }

  @override
  Future<void> playSfx(
    String assetPath, {
    double volume = 0.7,
    double pan = 0.0,
  }) async {
    sfxPlayed.add((assetPath, pan));
  }
}

void main() {
  late FestivalDataBundle bundle;
  late OrchardMapData map;

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

  group('Audio Engine Regressions (Ogg Opus Slicer, Sticky Slots, PA, LPF)',
      () {
    test(
        'computeOggPageCrc32 matches real track_01.ogg CRCs & sliceOggOpusFromSeconds produces valid seekable stream',
        () {
      final raw = File('assets/audio/tracks/track_01.ogg').readAsBytesSync();
      expect(raw.length, greaterThan(200000));

      // Verify our RFC 3533 CRC-32 matches unmodified Ogg pages bit-for-bit!
      final bd = ByteData.sublistView(raw);
      final firstSegCount = raw[26];
      var firstBody = 0;
      for (var i = 0; i < firstSegCount; i++) {
        firstBody += raw[27 + i];
      }
      final firstPage =
          Uint8List.sublistView(raw, 0, 27 + firstSegCount + firstBody);
      final expectedCrc = bd.getUint32(22, Endian.little);
      expect(computeOggPageCrc32(firstPage), expectedCrc);

      // Slice 45 seconds into track_01.ogg
      final sliced = sliceOggOpusFromSeconds(raw, 45.0);
      expect(sliced.actualSeekSeconds, closeTo(45.0, 2.5));
      expect(sliced.bytes.length, lessThan(raw.length));

      // Walk every single Ogg page in sliced.bytes and verify:
      // 1) OpusHead & OpusTags headers intact
      // 2) Sequential page_sequence_number = 0, 1, 2, ...
      // 3) Every page's stored CRC-32 matches computeOggPageCrc32!
      final sbd = ByteData.sublistView(sliced.bytes);
      var cursor = 0;
      var expectedSeq = 0;
      var sawEos = false;
      while (cursor < sliced.bytes.length) {
        expect(sliced.bytes[cursor], 0x4F); // 'O'
        expect(sliced.bytes[cursor + 1], 0x67); // 'g'
        final headerType = sliced.bytes[cursor + 5];
        final seq = sbd.getUint32(cursor + 18, Endian.little);
        final storedCrc = sbd.getUint32(cursor + 22, Endian.little);
        final segs = sliced.bytes[cursor + 26];
        var body = 0;
        for (var s = 0; s < segs; s++) {
          body += sliced.bytes[cursor + 27 + s];
        }
        final pageLen = 27 + segs + body;
        final pageBytes =
            Uint8List.sublistView(sliced.bytes, cursor, cursor + pageLen);

        expect(seq, expectedSeq,
            reason: 'Broken Ogg page sequence at page $expectedSeq');
        expect(computeOggPageCrc32(pageBytes), storedCrc,
            reason: 'Invalid Ogg CRC at page $expectedSeq');
        if ((headerType & 0x04) != 0) sawEos = true;

        cursor += pageLen;
        expectedSeq++;
      }
      expect(cursor, sliced.bytes.length);
      expect(expectedSeq, greaterThan(10));
      expect(sawEos, isTrue);
    });

    test(
        'Sticky multi-stage slots do NOT reload streams when crossing Urbano/Andromeda midpoint',
        () {
      final rec = RecordingAudioService();
      final ctrl = AudioScheduleController(catalog: bundle.setlist, audio: rec);
      const settings = SettingsState();

      // Saturday Midnight (Day 2, minute 1445): Urbano (240, 1024) & Andromeda (1760, 320) both live!
      // Pick midpoint where both stages are within their maxDist (~980, 680) or expand test stages:
      final urbano = bundle.setlist.stages['urbano_canopy_stage']!;
      final andromeda = bundle.setlist.stages['andromeda_pavilion_stage']!;
      final customCatalog = SetlistCatalog(
        albumTitle: bundle.setlist.albumTitle,
        albumArtist: bundle.setlist.albumArtist,
        clockMinutesPerRealSecond: bundle.setlist.clockMinutesPerRealSecond,
        stages: {
          ...bundle.setlist.stages,
          'urbano_canopy_stage': StageInfo(
            id: urbano.id,
            name: urbano.name,
            zone: urbano.zone,
            x: 700,
            y: 700,
            minDist: 80,
            maxDist: 700,
          ),
          'andromeda_pavilion_stage': StageInfo(
            id: andromeda.id,
            name: andromeda.name,
            zone: andromeda.zone,
            x: 1000,
            y: 700,
            minDist: 80,
            maxDist: 700,
          ),
        },
        tracks: bundle.setlist.tracks,
      );
      final midCtrl =
          AudioScheduleController(catalog: customCatalog, audio: rec);
      const midnightClock = FestivalClockState(day: 2, minuteOfDay: 1445.0);

      // Closer to Urbano (x=780): Urbano > Andromeda
      midCtrl.update(
        dtSeconds: 0.1,
        clock: midnightClock,
        settings: settings,
        listenerX: 780,
        listenerY: 700,
        listenerInOcclusionZone: false,
        listenerInUndergrowthFog: false,
        turntableTrackNumber: null,
        encoreAnywhereJukebox: false,
        onFiveMinuteBellAlert: null,
        onTrackHeardStamp: null,
      );
      expect(rec.streamLoads.length, 2);
      final initialSlots = Map.of(midCtrl.debugActiveStageSlotAssignments);

      // Walk past midpoint closer to Andromeda (x=940): Andromeda > Urbano!
      midCtrl.update(
        dtSeconds: 0.1,
        clock: midnightClock,
        settings: settings,
        listenerX: 940,
        listenerY: 700,
        listenerInOcclusionZone: false,
        listenerInUndergrowthFog: false,
        turntableTrackNumber: null,
        encoreAnywhereJukebox: false,
        onFiveMinuteBellAlert: null,
        onTrackHeardStamp: null,
      );

      // ZERO stream reloads or slot swaps when gain rank flips!
      expect(rec.streamLoads.length, 2);
      expect(midCtrl.debugActiveStageSlotAssignments, equals(initialSlots));

      // Out of range of all stages -> global LPF MUST reset to 18000 Hz (never muffle footsteps/UI!)
      ctrl.update(
        dtSeconds: 0.1,
        clock: const FestivalClockState(day: 1, minuteOfDay: 500.0),
        settings: settings,
        listenerX: 1950,
        listenerY: 1450,
        listenerInOcclusionZone: true,
        listenerInUndergrowthFog: false,
        turntableTrackNumber: null,
        encoreAnywhereJukebox: false,
        onFiveMinuteBellAlert: null,
        onTrackHeardStamp: null,
      );
      expect(rec.lastLowPassCutoffHz, 18000.0);

      // PA Horn uses dedicated 'pa_horn' slot and resets LPF to 18000 Hz
      final track2 = bundle.setlist.trackByNumber(2)!;
      ctrl.update(
        dtSeconds: 0.1,
        clock: FestivalClockState(
            day: track2.day, minuteOfDay: track2.startMinute + 1.0),
        settings: settings,
        listenerX: 608,
        listenerY: 1200,
        listenerInOcclusionZone: true,
        listenerInUndergrowthFog: false,
        turntableTrackNumber: null,
        encoreAnywhereJukebox: false,
        onFiveMinuteBellAlert: null,
        onTrackHeardStamp: null,
      );
      expect(rec.activeSlots.containsKey('pa_horn'), isTrue);
      expect(rec.lastLowPassCutoffHz, 18000.0);

      // Arcade cabinet modal plays Track 17 on 'arcade_cabinet' slot anytime!
      ctrl.update(
        dtSeconds: 0.1,
        clock: const FestivalClockState(day: 1, minuteOfDay: 500.0),
        settings: settings,
        listenerX: 1700,
        listenerY: 1020,
        listenerInOcclusionZone: true,
        listenerInUndergrowthFog: false,
        activeArcadeTrackId: 'track_17',
        turntableTrackNumber: null,
        encoreAnywhereJukebox: false,
        onFiveMinuteBellAlert: null,
        onTrackHeardStamp: null,
      );
      expect(rec.activeSlots['arcade_cabinet']?.trackId, 'track_17');
      expect(rec.lastLowPassCutoffHz, 18000.0);
    });

    test(
        'Track 16 is post-rain mud-pit celebration (postStormMist + muddy) after Track 15 rainstorm',
        () {
      final clock = FestivalClockNotifier(bundle.setlist);
      final track15 = bundle.setlist.trackByNumber(15)!;
      final track16 = bundle.setlist.trackByNumber(16)!;

      clock.setClockDirect(day: 2, minuteOfDay: track15.startMinute + 10.0);
      expect(clock.state.weather, WeatherPhase.blightRainstorm);
      expect(clock.areDirtPathsMuddy, isTrue);

      clock.setClockDirect(day: 2, minuteOfDay: track16.startMinute + 10.0);
      expect(clock.state.weather, WeatherPhase.postStormMist);
      expect(clock.areDirtPathsMuddy, isTrue);
    });
  });

  group(
      'Lost-Woods Fog Maze, Remaining Cast Quests, Enhanced Moss & Sorting Hazards',
      () {
    test(
        'Lost-Woods Psych-Rock Fog maze enforces West->East->Sanctum progression and clears A* path on wrong turn',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final recAudio = RecordingAudioService();
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
        audioService: recAudio,
      );
      game.onGameResize(Vector2(960, 640));
      await game.onLoad();

      void closeActiveDialogue() {
        while (container.read(uiOverlayProvider).dialogue != null) {
          container.read(uiOverlayProvider.notifier).advanceOrCloseDialogue();
        }
      }

      // 1. Give player an active A* tap path, then teleport into a wrong-turn fog pocket (charging straight north!)
      game.teleportPlayer(1200.0, 248.0);
      game.player!.setTapPath([(1200.0, 144.0)]);
      expect(game.player!.hasActiveTapPath, isTrue);

      game.player!.position
          .setValues(1200.0, 168.0); // Straight north before Stage 0!
      game.update(0.05);

      // Must wrap back to entrance (1200, 248) AND clear active A* tap path!
      expect(game.player!.position.x,
          closeTo(PsychRockFogZone.entranceSpawn.dx, 2.0));
      expect(game.player!.position.y,
          closeTo(PsychRockFogZone.entranceSpawn.dy, 2.0));
      expect(game.player!.hasActiveTapPath, isFalse);

      // Tea-light altar is gated while sanctum is still shrouded!
      final altar =
          map.interactables.firstWhere((o) => o.name == 'tea_light_altar').rect;
      game.player!.position.setValues(altar.center.dx, altar.center.dy);
      game.handleInteract();
      expect(container.read(worldFlagsProvider).teaLightAltared, isFalse);

      // 2. Harmonize Stage 0 (West Moss Arch) -> Stage 1 (East Fern Clearing) -> Sanctum!
      game.teleportPlayer(
        PsychRockFogZone.acousticWaypoints[0].dx,
        PsychRockFogZone.acousticWaypoints[0].dy,
      );
      game.update(0.05);
      game.teleportPlayer(
        PsychRockFogZone.acousticWaypoints[1].dx,
        PsychRockFogZone.acousticWaypoints[1].dy,
      );
      game.update(0.05);

      // Now sanctum is parted! Light Tea-Light Altar -> Talk to Tula -> Side C + Sunset Shawl!
      game.teleportPlayer(altar.center.dx, altar.center.dy);
      game.handleInteract();
      expect(container.read(worldFlagsProvider).teaLightAltared, isTrue);

      final tula = bundle.npcById('tula_twigwalker')!;
      game.teleportPlayer(tula.spawnX, tula.spawnY + 10);
      game.handleInteract();
      closeActiveDialogue();
      expect(container.read(worldFlagsProvider).tulaQuestCompleted, isTrue);
      expect(container.read(journalStateProvider).collectedVinylIds,
          contains('vinyl_side_c'));
      expect(container.read(playerProfileProvider).unlockedWardrobeIds,
          contains('sunset_biolume_shawl'));

      // 3. Don Shell-O full quest chain (Gold Mic -> Meadow Blessing Stone -> Santurce Buried Stash -> Turn-in)
      final don = bundle.npcById('don_shello')!;
      final stone = map.interactables
          .firstWhere((o) => o.name == 'meadow_blessing_stone')
          .rect;
      final stash = map.interactables
          .firstWhere((o) => o.name == 'don_shello_buried_stash')
          .rect;

      game.teleportPlayer(stash.center.dx, stash.center.dy);
      game.handleInteract();
      expect(container.read(worldFlagsProvider).buriedStashUnearthed,
          isFalse); // Gated!

      game.teleportPlayer(don.spawnX, don.spawnY + 10);
      game.handleInteract();
      closeActiveDialogue();
      expect(container.read(worldFlagsProvider).donShelloQuestStarted, isTrue);

      game.teleportPlayer(stone.center.dx, stone.center.dy);
      game.handleInteract();
      expect(container.read(worldFlagsProvider).goldMicBlessed, isTrue);

      game.teleportPlayer(stash.center.dx, stash.center.dy);
      game.handleInteract();
      expect(container.read(worldFlagsProvider).buriedStashUnearthed, isTrue);

      game.teleportPlayer(don.spawnX, don.spawnY + 10);
      game.handleInteract();
      closeActiveDialogue();
      expect(
          container.read(worldFlagsProvider).donShelloQuestCompleted, isTrue);
      expect(container.read(journalStateProvider).collectedVinylIds,
          contains('vinyl_bootleg_omega'));
      expect(container.read(playerProfileProvider).unlockedWardrobeIds,
          contains('gold_w_vest'));

      // 4. Ziggy Shell-shock Morning Dew Dawn Walkover + Barnaby Breeze-Walker Old Oak Pick + Day 3 Pete Ladder
      container
          .read(festivalClockProvider.notifier)
          .restUntilSunrise(); // 5:05 AM dawn window!
      final ziggy = bundle.npcById('ziggy_shellshock')!;
      game.teleportPlayer(ziggy.spawnX, ziggy.spawnY + 10);
      game.handleInteract();
      closeActiveDialogue();

      for (final (dx, dy) in [
        (1096.0, 392.0),
        (1144.0, 408.0),
        (1208.0, 392.0)
      ]) {
        game.teleportPlayer(dx, dy);
        game.update(0.05);
      }
      expect(container.read(worldFlagsProvider).dewDropsCollected.length, 3);
      game.teleportPlayer(ziggy.spawnX, ziggy.spawnY + 10);
      game.handleInteract();
      closeActiveDialogue();
      expect(container.read(worldFlagsProvider).ziggyQuestCompleted, isTrue);
      expect(container.read(playerProfileProvider).unlockedWardrobeIds,
          contains('heart_specs'));

      // Barnaby Breeze-Walker Old Oak Pick
      final barnaby = bundle.npcById('barnaby_breezewalker')!;
      final roots =
          map.interactables.firstWhere((o) => o.name == 'old_oak_roots').rect;
      game.teleportPlayer(barnaby.spawnX, barnaby.spawnY + 10);
      game.handleInteract();
      closeActiveDialogue();
      game.teleportPlayer(roots.center.dx, roots.center.dy);
      game.handleInteract();
      expect(container.read(worldFlagsProvider).hasWillowPick, isTrue);
      game.teleportPlayer(barnaby.spawnX, barnaby.spawnY + 10);
      game.handleInteract();
      closeActiveDialogue();
      expect(container.read(worldFlagsProvider).breezewalkerQuestCompleted,
          isTrue);
      expect(container.read(playerProfileProvider).unlockedWardrobeIds,
          contains('willow_shawl'));

      // Patchouli Pete High-Branch Ladder: gated on Day 1, unlocks on Day 3!
      final ladder = map.interactables
          .firstWhere((o) => o.name == 'high_branch_ladder')
          .rect;
      container
          .read(festivalClockProvider.notifier)
          .setClockDirect(day: 1, minuteOfDay: 600.0);
      game.teleportPlayer(ladder.center.dx, ladder.center.dy);
      game.handleInteract();
      expect(
          container.read(worldFlagsProvider).peteInterviewCompleted, isFalse);

      container
          .read(festivalClockProvider.notifier)
          .setClockDirect(day: 3, minuteOfDay: 720.0);
      game.handleInteract();
      expect(container.read(worldFlagsProvider).peteInterviewCompleted, isTrue);
      expect(container.read(journalStateProvider).collectedVinylIds,
          contains('vinyl_side_a'));
    });

    test(
        'Enhanced Janice Moss-Bloom widens cliff terrace & NPCs A*-route to Main Roots without getting stuck',
        () {
      final mutators = WorldMutators(map);
      expect(map.isTileBlocked(11, 14), isTrue);
      expect(map.isTileBlocked(15, 14), isTrue);

      mutators.applyMossBloom(enhancedByTea: false);
      expect(map.isTileBlocked(13, 14), isFalse);
      expect(map.isTileBlocked(11, 14),
          isTrue); // Narrow 3-col bridge before Vocal Tea!

      mutators.applyMossBloom(enhancedByTea: true);
      expect(map.isTileBlocked(11, 14),
          isFalse); // Expanded 5-col emerald terrace!
      expect(map.isTileBlocked(15, 14), isFalse);

      // Test NPC A* crowd migration from Urbano Canopy (Wen-wan Elder) around obstacles toward Main Roots
      mutators.applyFenceDrop();
      final dummyImg = _TestDummyImage();
      final elderSpec = bundle.npcById('wen_wan_elder')!;
      final actor = NpcActor(spec: elderSpec, map: map, spriteSheet: dummyImg);
      final startDist = actor.position.distanceTo(Vector2(608, 500));
      for (var i = 0; i < 180; i++) {
        actor.stepAi(
          dt: 1 / 20.0,
          gMajorActive: false,
          organ440Level: 0.0,
          crowdMigrateMainRoots: true,
          playerDistance: 500.0,
        );
      }
      final endDist = actor.position.distanceTo(Vector2(608, 500));
      expect(endDist, lessThan(startDist - 120.0));
    });

    test(
        'SortingBeltSimulation rewards clicking target-to-remove kernels, warns on keep-grade kernels, and awards clean hopper pass-through',
        () {
      final sim = SortingBeltSimulation(autoGroove: false);
      sim.items.clear();
      final targetType = sim.targetToRemove;
      sim.items.add(
        BeltKernelItem(
          id: 901,
          type: targetType,
          progress: 0.50,
          crossPos: 0.50,
          rotationRad: 0.0,
          scale: 1.0,
        ),
      );
      expect(sim.clickItem(901), BeltClickResult.removedTarget);
      expect(sim.streak, 1);
      final scoreAfterRemoval = sim.score;
      expect(scoreAfterRemoval, greaterThan(100));

      // Clicking a prime keep-grade Extra-Light Half resets streak without removing it or penalizing points
      sim.items.add(
        BeltKernelItem(
          id: 902,
          type: WalnutKernelType.extraLightHalf,
          progress: 0.55,
          crossPos: 0.45,
          rotationRad: 0.0,
          scale: 1.0,
        ),
      );
      expect(sim.clickItem(902), BeltClickResult.wrongKernelType);
      expect(sim.streak, 0);
      expect(sim.score, scoreAfterRemoval);
      expect(sim.items.any((i) => i.id == 902), isTrue);

      // Letting a prime keep-grade kernel pass into the right harvest hopper awards +30 clean-harvest bonus!
      sim.items.clear();
      sim.items.add(
        BeltKernelItem(
          id: 903,
          type: WalnutKernelType.extraLightHalf,
          progress: 1.01,
          crossPos: 0.50,
          rotationRad: 0.0,
          scale: 1.0,
        ),
      );
      sim.step(0.1);
      expect(sim.score, scoreAfterRemoval + 30);
    });
  });
}

class _TestDummyImage implements ui.Image {
  @override
  int get width => 96;
  @override
  int get height => 128;
  @override
  void dispose() {}
  @override
  bool get debugDisposed => false;
  @override
  ui.Image clone() => this;
  @override
  bool isCloneOf(ui.Image other) => identical(this, other);
  @override
  ui.ColorSpace get colorSpace => ui.ColorSpace.sRGB;
  @override
  List<StackTrace>? debugGetOpenHandleStackTraces() => null;
  @override
  Future<ByteData?> toByteData(
          {ui.ImageByteFormat format = ui.ImageByteFormat.rawRgba}) async =>
      null;
}
