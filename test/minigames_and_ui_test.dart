import 'dart:convert';
import 'dart:io';
// ignore: deprecated_member_use
import 'package:flame/game.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walnutstock/app/orchard_loading_screen.dart';
import 'package:walnutstock/app/walnutstock_app.dart';
import 'package:walnutstock/audio/soloud_audio_service.dart';
import 'package:walnutstock/data/models.dart';
import 'package:walnutstock/game/minigames/sorting_belt_blues_game.dart';
import 'package:walnutstock/game/minigames/sorting_pinball_game.dart';
import 'package:walnutstock/game/walnutstock_game.dart';
import 'package:walnutstock/game/world/tiled_map_parser.dart';
import 'package:walnutstock/state/dialogue_and_overlay_state.dart';
import 'package:walnutstock/state/player_profile.dart';
import 'package:walnutstock/state/providers.dart';
import 'package:walnutstock/state/save_repository.dart';

void main() {
  late FestivalDataBundle data;
  late OrchardMapData mapData;

  setUpAll(() {
    final setlistJson = jsonDecode(
      File('assets/data/setlist_26_tracks.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final npcsJson = jsonDecode(
      File('assets/data/npcs_and_quests.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final lightshowsJson = jsonDecode(
      File('assets/data/track_lightshows.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    data = FestivalDataBundle.fromJsonMaps(
      setlistJson: setlistJson,
      npcsJson: npcsJson,
      lightshowsJson: lightshowsJson,
    );

    final tmx = File('assets/tiles/free_orchard_full.tmx').readAsStringSync();
    final tsx = File('assets/tiles/orchard_tileset.tsx').readAsStringSync();
    mapData =
        TiledMapParser.parseTmxAndTsx(tmxXmlString: tmx, tsxXmlString: tsx);
  });

  group('Mini-Games Auto-Groove & UI ValueKey Flow Tests', () {
    test(
        'Pinball Wizard Auto-Groove scores bumper/chute points without draining failure',
        () {
      final sim = PinballSimulation(autoGroove: true);
      for (var i = 0; i < 600; i++) {
        sim.step(1 / 60.0);
      }
      expect(sim.score, greaterThan(0));
    });

    test(
        'Sorting Belt Blues Auto-Groove sorts incoming golden walnut kernels cleanly',
        () {
      final sim = SortingBeltSimulation(autoGroove: true);
      for (var i = 0; i < 360; i++) {
        sim.step(1 / 60.0);
      }
      expect(sim.score, greaterThan(0));
      expect(sim.streak, greaterThan(0));
    });

    test(
        'Photorealistic walnut pinball & 6 walnut kernel PNG sprites exist with transparent studio quality',
        () {
      final pinballAsset = File('assets/images/props/walnut_pinball.png');
      expect(pinballAsset.existsSync(), isTrue);
      expect(pinballAsset.lengthSync(), greaterThan(40000));

      expect(WalnutKernelType.values.length, 6);
      for (final kernelType in WalnutKernelType.values) {
        final f = File(kernelType.assetPath);
        expect(
          f.existsSync(),
          isTrue,
          reason: 'Missing realistic kernel image: ${kernelType.assetPath}',
        );
        expect(
          f.lengthSync(),
          greaterThan(40000),
          reason: 'Kernel image unexpectedly tiny: ${kernelType.assetPath}',
        );
      }
    });

    test(
        'Upgraded Walnut Pinball features 520x680 wide-body playfield, spinning walnut ball, shooter plunger, 5 bumpers, and H-U-L-L Multiball',
        () {
      final sim = PinballSimulation(autoGroove: false);
      expect(PinballSimulation.boardW, 520.0);
      expect(PinballSimulation.boardH, 680.0);
      expect(sim.bumpers.length, 5);
      expect(sim.dropTargets.length, 4);
      expect(sim.balls.length, 1);

      // Verify walnut pinball dynamically spins as it rolls/falls
      final initialSpin = sim.balls.first.spinAngle;
      sim.step(1 / 30.0);
      expect(sim.balls.first.spinAngle, isNot(equals(initialSpin)));

      // Verify left & upper-left mini-flipper actuate upward when leftFlipperUp is pressed
      final restLeftAngle = sim.leftFlipperAngle;
      final restUpperLeftAngle = sim.upperLeftFlipperAngle;
      sim.leftFlipperUp = true;
      for (var i = 0; i < 8; i++) {
        sim.step(1 / 60.0);
      }
      expect(sim.leftFlipperAngle, lessThan(restLeftAngle - 0.5));
      expect(sim.upperLeftFlipperAngle, lessThan(restUpperLeftAngle - 0.5));
      sim.leftFlipperUp = false;

      // Verify spring plunger launches a walnut waiting in the right shooter lane
      sim.balls
        ..clear()
        ..add(
          WalnutPinball(
            x: PinballSimulation.shooterLaneCenterX,
            y: 618.0,
            vx: 0.0,
            vy: 0.0,
            inShooterLane: true,
          ),
        );
      expect(sim.hasBallWaitingInShooter, isTrue);
      expect(sim.launchPlunger(), equals('flipper'));
      expect(sim.balls.first.vy, lessThan(-700.0));

      // Verify knocking down all 4 H-U-L-L drop targets triggers Walnut Multiball!
      sim.dropTargets[0].isDown = true;
      sim.dropTargets[1].isDown = true;
      sim.dropTargets[2].isDown = true;
      final lastTarget = sim.dropTargets[3];
      sim.balls
        ..clear()
        ..add(
          WalnutPinball(
            x: lastTarget.center.dx - 8.0,
            y: lastTarget.center.dy,
            vx: 260.0,
            vy: 0.0,
            inShooterLane: false,
          ),
        );
      sim.step(1 / 60.0);
      expect(sim.multiballCount, 1);
      expect(sim.multiballActive, isTrue);
      expect(sim.balls.length, greaterThanOrEqualTo(2));
    });

    test(
        'Single-Belt Walnut Kernel Inspection rotates target order every 6 removals and enforces target-only clicking',
        () {
      final sim = SortingBeltSimulation(autoGroove: false);
      final initialTarget = sim.targetToRemove;
      expect(initialTarget, WalnutKernelType.darkShrivel);

      // Remove 6 matching target kernels on the single belt -> triggers shift order rotation!
      for (var n = 0; n < SortingBeltSimulation.removalsPerShift; n++) {
        final id = 500 + n;
        sim.items.add(
          BeltKernelItem(
            id: id,
            type: initialTarget,
            progress: 0.45,
            crossPos: 0.50,
            rotationRad: 0.0,
            scale: 1.0,
          ),
        );
        expect(sim.clickItem(id), BeltClickResult.removedTarget);
      }
      expect(sim.shiftNumber, 2);
      expect(sim.targetToRemove, isNot(equals(initialTarget)));
      expect(sim.removedTotal, SortingBeltSimulation.removalsPerShift);
    });

    testWidgets(
        'Direct Orchard Gate Entry -> Pocket Program Pill (3 Tabs) -> Vibe Journal -> All Modals & Encore Deck flow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(960, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final saveRepo = SaveRepository();
      final audioService = SoloudAudioService();
      final container = ProviderContainer(
        overrides: [
          festivalDataProvider.overrideWithValue(data),
          saveRepositoryProvider.overrideWithValue(saveRepo),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: WalnutstockApp(
            data: data,
            mapData: mapData,
            audioService: audioService,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Boots directly into playable Orchard Gate with zero double-splash menu!
      expect(find.byKey(const ValueKey('tear_ticket_button')), findsNothing);
      expect(find.byKey(const ValueKey('enter_orchard_button')), findsNothing);
      expect(find.byKey(const ValueKey('pocket_program_pill')), findsOneWidget);

      // 2. Unfold single Pocket Program pill -> Setlist & Stages tab
      await tester.tap(find.byKey(const ValueKey('pocket_program_pill')));
      await tester.pump();
      expect(find.byKey(const ValueKey('pocket_program_sheet')), findsOneWidget);
      expect(find.byKey(const ValueKey('next_set_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('pure_vibe_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('sway_emote_button')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('pure_vibe_button')));
      await tester.pump();

      // 3. Switch to Cultivar Pouch tab -> select Juglans Hindsii
      await tester.tap(find.byKey(const ValueKey('program_tab_cultivars')));
      await tester.pump();
      final hindsiiChip =
          find.byKey(const ValueKey('cultivar_chip_juglans_hindsii'));
      await tester.ensureVisible(hindsiiChip);
      await tester.tap(hindsiiChip);
      await tester.pump();
      expect(container.read(playerProfileProvider).cultivarId, 'juglans_hindsii');

      // 4. Switch to Orchard Map tab -> launch Vibe Journal & cycle tabs
      await tester.tap(find.byKey(const ValueKey('program_tab_map')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('orchard_program_map_view')),
        findsOneWidget,
      );
      final openJournalBtn = find.byKey(const ValueKey('open_journal_button'));
      await tester.ensureVisible(openJournalBtn);
      await tester.tap(openJournalBtn);
      await tester.pump();
      expect(find.byKey(const ValueKey('vibe_journal_modal')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('journal_tab_setlist')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('journal_tab_wardrobe')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('journal_tab_collectibles')));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('close_journal_button')));
      await tester.pump();
      expect(find.byKey(const ValueKey('vibe_journal_modal')), findsNothing);

      // 5. Verify Tent Rest Modal & ValueKeys (campground_tent, rest_sunrise, rest_next_set, rest_saturday_storm)
      container
          .read(uiOverlayProvider.notifier)
          .openModal(ActiveModalOverlay.tentRest);
      await tester.pump();
      expect(find.byKey(const ValueKey('campground_tent')), findsOneWidget);
      expect(find.byKey(const ValueKey('rest_sunrise')), findsOneWidget);
      expect(find.byKey(const ValueKey('rest_next_set')), findsOneWidget);
      expect(find.byKey(const ValueKey('rest_saturday_storm')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rest_saturday_storm')));
      await tester.pump();
      expect(container.read(festivalClockProvider).day, 2);

      // 6. Verify Double-LP Turntable, Pinball, Sorting Belt, Settings, and Finale -> Encore Deck
      for (final modal in [
        ActiveModalOverlay.turntable,
        ActiveModalOverlay.pinball,
        ActiveModalOverlay.sortingBelt,
        ActiveModalOverlay.artifactBooth,
        ActiveModalOverlay.settingsDrawer,
      ]) {
        container.read(uiOverlayProvider.notifier).openModal(modal);
        await tester.pump(const Duration(milliseconds: 50));
        container.read(uiOverlayProvider.notifier).closeModal();
        await tester.pump();
      }

      // Finale Montage -> Unlock Endless Encore Mode -> Encore Control Deck
      container
          .read(uiOverlayProvider.notifier)
          .openModal(ActiveModalOverlay.finaleMontage);
      await tester.pump();
      expect(
          find.byKey(const ValueKey('finale_montage_modal')), findsOneWidget);
      await tester
          .tap(find.byKey(const ValueKey('enter_endless_encore_button')));
      await tester.pump();
      expect(container.read(festivalClockProvider).encoreModeUnlocked, isTrue);

      container
          .read(uiOverlayProvider.notifier)
          .openModal(ActiveModalOverlay.encoreDeck);
      await tester.pump();
      expect(find.byKey(const ValueKey('encore_control_deck')), findsOneWidget);
      container.read(uiOverlayProvider.notifier).closeModal();
      await tester.pump();

      // 7. Mobile Portrait Viewport (390x844) layout verification
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Large Walnut Pinball & Single-Belt Sorting modals handle keyboard keys without moving overworld player and register realistic kernel clicks',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 720);
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
      });

      final saveRepo = SaveRepository();
      final audioService = SoloudAudioService();
      final container = ProviderContainer(
        overrides: [
          festivalDataProvider.overrideWithValue(data),
          saveRepositoryProvider.overrideWithValue(saveRepo),
        ],
      );
      addTearDown(container.dispose);

      // Jump straight into the overworld
      container.read(playerProfileProvider.notifier).confirmCultivarAndEnter();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: WalnutstockApp(
            data: data,
            mapData: mapData,
            audioService: audioService,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      final gameWidget = tester.widget<GameWidget<WalnutstockGame>>(
        find.byType(GameWidget<WalnutstockGame>),
      );
      final game = gameWidget.game!;
      final startPlayerPos = game.player?.position.clone();

      // A. Open Wide-Body Walnut Pinball Cabinet & verify expanded size + working keyboard keys
      container
          .read(uiOverlayProvider.notifier)
          .openModal(ActiveModalOverlay.pinball);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      final pinballModalFinder =
          find.byKey(const ValueKey('pinball_wizard_modal'));
      expect(pinballModalFinder, findsOneWidget);
      final pinballSize = tester.getSize(pinballModalFinder);
      expect(pinballSize.width, greaterThanOrEqualTo(760.0));
      expect(pinballSize.height, greaterThanOrEqualTo(580.0));

      // Send A (left flipper), ArrowRight (right flipper), Space (plunger), W (nudge)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        container.read(uiOverlayProvider).modal,
        ActiveModalOverlay.pinball,
      );
      // Overworld input & player MUST remain frozen while holding A inside Pinball!
      expect(game.inputController.sampleMovementAndGamepad().move.length, 0.0);
      game.update(0.15);
      if (startPlayerPos != null && game.player != null) {
        expect(
          game.player!.position.distanceTo(startPlayerPos),
          lessThan(0.01),
        );
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 50));
      expect(game.inputController.sampleMovementAndGamepad().move.length, 0.0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      expect(tester.takeException(), isNull);

      // Mobile portrait check for Pinball modal (390x844 true MediaQuery)
      tester.view.physicalSize = const Size(390, 844);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Restore desktop size (1280x720) & switch to Single-Belt Walnut Kernel Inspection
      tester.view.physicalSize = const Size(1280, 720);
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      await tester.pump();
      container
          .read(uiOverlayProvider.notifier)
          .openModal(ActiveModalOverlay.sortingBelt);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      final beltModalFinder =
          find.byKey(const ValueKey('sorting_belt_blues_modal'));
      expect(beltModalFinder, findsOneWidget);
      final beltSize = tester.getSize(beltModalFinder);
      expect(beltSize.width, equals(900.0));
      expect(beltSize.height, equals(600.0));

      expect(
        find.byKey(const ValueKey('sorting_belt_target_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('sorting_single_belt_surface')),
        findsOneWidget,
      );

      // Item #2 is seeded at progress 0.34 as a matching targetToRemove kernel!
      final scoreBeforeClick =
          container.read(worldFlagsProvider).sortingBeltHighScore;
      final targetKernelFinder = find.byKey(const ValueKey('belt_kernel_2'));
      expect(targetKernelFinder, findsOneWidget);
      await tester.tap(targetKernelFinder);
      await tester.pump();
      expect(
        container.read(worldFlagsProvider).sortingBeltHighScore,
        greaterThan(scoreBeforeClick),
      );

      // Rotate inspection order button works cleanly
      await tester.tap(find.byKey(const ValueKey('sorting_switch_target_button')));
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Mobile portrait check for Single-Belt Sorting modal (390x844 true MediaQuery)
      tester.view.physicalSize = const Size(390, 844);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    test(
        '11 distinct walnut cultivars, 8 unlocked starter outfits, and 34 festival NPCs have unique pixel art & complete metadata',
        () {
      expect(data.cultivars.length, 11);
      expect(data.npcs.length, 34);
      expect(data.wardrobe.length, 20);
      expect(data.items.length, 18);
      expect(data.quests.length, 18);

      final starterOutfits =
          data.wardrobe.where((w) => w.unlockedByDefault).toList();
      expect(starterOutfits.length, 8);
      expect(
        const PlayerProfile().unlockedWardrobeIds,
        containsAll(starterOutfits.map((w) => w.id)),
      );

      final expectedNewVarieties = {
        'red_livermore',
        'serr',
        'japonica_heartnut',
        'cinerea_butternut',
      };
      expect(
        data.cultivars.map((c) => c.id),
        containsAll(expectedNewVarieties),
      );

      final portraitFingerprints = <String>{};
      final sheetFingerprints = <String>{};
      for (final c in data.cultivars) {
        expect(c.origin, isNotEmpty, reason: 'Missing origin on ${c.id}');
        expect(c.shellShape, isNotEmpty, reason: 'Missing shellShape on ${c.id}');
        expect(c.flavorNotes, isNotEmpty, reason: 'Missing flavorNotes on ${c.id}');
        expect(c.accentHex, startsWith('#'));

        final portraitFile = File(c.portraitAsset);
        final sheetFile = File(c.sheetAsset);
        expect(portraitFile.existsSync(), isTrue, reason: c.portraitAsset);
        expect(sheetFile.existsSync(), isTrue, reason: c.sheetAsset);
        expect(portraitFile.lengthSync(), greaterThan(400));
        expect(sheetFile.lengthSync(), greaterThan(800));

        portraitFingerprints.add(base64Encode(portraitFile.readAsBytesSync()));
        sheetFingerprints.add(base64Encode(sheetFile.readAsBytesSync()));
      }
      // Every single cultivar portrait and sprite sheet must be visually distinct!
      expect(portraitFingerprints.length, 11);
      expect(sheetFingerprints.length, 11);

      for (final npc in data.npcs) {
        expect(File(npc.portraitAsset).existsSync(), isTrue, reason: npc.id);
        expect(File(npc.sheetAsset).existsSync(), isTrue, reason: npc.id);
        expect(npc.dialogue, isNotEmpty, reason: npc.id);
      }
    });

    testWidgets(
        'Orchard Gate diegetic kiosks, Pocket Program Cultivar Pouch, Floating Thumb Joystick, Contextual Bubbles, and Concert Vibe Mode work across 390x844 & 375x667 viewports',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        return tester.binding.setSurfaceSize(null);
      });

      final saveRepo = SaveRepository();
      final container = ProviderContainer(
        overrides: [
          festivalDataProvider.overrideWithValue(data),
          saveRepositoryProvider.overrideWithValue(saveRepo),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: WalnutstockApp(
            data: data,
            mapData: mapData,
            audioService: SoloudAudioService(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull);

      final gameWidget = tester.widget<GameWidget<WalnutstockGame>>(
        find.byType(GameWidget<WalnutstockGame>),
      );
      final game = gameWidget.game!;
      if (game.player == null) {
        await game.onLoad();
        game.onGameResize(Vector2(390, 844));
      }
      game.update(0.05);
      await tester.pump();

      // 1. Verify portrait phone viewports (390x844 iPhone 15 Pro & 375x667 iPhone SE)
      //    show ONLY the slim Pocket Program pill + diegetic gate badges (no permanent D-pad or interact button!)
      for (final mobileSize in const [Size(390, 844), Size(375, 667)]) {
        tester.view.physicalSize = mobileSize;
        await tester.binding.setSurfaceSize(mobileSize);
        game.onGameResize(Vector2(mobileSize.width, mobileSize.height));
        game.update(0.05);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('pocket_program_pill')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('orchard_gate_lineup_kiosk')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('orchard_gate_cultivar_booth')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('world_context_bubble')), findsNothing);
      }

      // 2. Tap Right Diegetic Gate Badge (Cultivar Booth) -> pick Japonica Heartnut & Velvet Bellbottom Coat!
      await tester.tap(find.byKey(const ValueKey('orchard_gate_cultivar_booth')));
      await tester.pump();
      expect(find.byKey(const ValueKey('pocket_program_sheet')), findsOneWidget);

      final heartnutChip =
          find.byKey(const ValueKey('cultivar_chip_japonica_heartnut'));
      await tester.ensureVisible(heartnutChip);
      await tester.tap(heartnutChip);
      await tester.pump();
      expect(
        container.read(playerProfileProvider).cultivarId,
        'japonica_heartnut',
      );
      expect(
        container.read(playerProfileProvider).discoveredCultivarIds,
        contains('japonica_heartnut'),
      );

      final velvetCoatChip =
          find.byKey(const ValueKey('outfit_chip_velvet_bellbottom_coat'));
      await tester.ensureVisible(velvetCoatChip);
      await tester.tap(velvetCoatChip);
      await tester.pump();
      expect(
        container.read(playerProfileProvider).equippedWardrobeId,
        'velvet_bellbottom_coat',
      );
      expect(saveRepo.loadPrimary()?.profile.cultivarId, 'japonica_heartnut');
      expect(
        saveRepo.loadPrimary()?.profile.equippedWardrobeId,
        'velvet_bellbottom_coat',
      );

      await tester.tap(find.byKey(const ValueKey('close_pocket_program_button')));
      await tester.pump();

      // 3. Test Invisible Floating Thumb Joystick: drag north -> ring appears -> release -> ring fades out!
      expect(find.byKey(const ValueKey('floating_thumb_ring')), findsNothing);
      final gesture = await tester.startGesture(const Offset(185, 500));
      await gesture.moveBy(const Offset(0, -42));
      await tester.pump();
      expect(find.byKey(const ValueKey('floating_thumb_ring')), findsOneWidget);
      expect(
        game.inputController.sampleMovementAndGamepad().move.y,
        lessThan(-0.5),
      );
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      expect(find.byKey(const ValueKey('floating_thumb_ring')), findsNothing);
      expect(game.inputController.sampleMovementAndGamepad().move.length, 0.0);

      // 4. Context-Only World Bubble + Heritage Cultivar Discovery + 2.5s Toast!
      // Step beside the Hartley Heritage Cultivar Tree at (744, 520)
      game.teleportPlayer(744.0, 540.0);
      game.update(0.05);
      await tester.pump();
      expect(find.byKey(const ValueKey('world_context_bubble')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('world_context_bubble')));
      await tester.pump();
      expect(
        container.read(playerProfileProvider).discoveredCultivarIds,
        contains('hartley'),
      );
      expect(find.byKey(const ValueKey('festival_toast_banner')), findsOneWidget);

      // Walk away into open grass -> world_context_bubble hides immediately!
      game.teleportPlayer(660.0, 620.0);
      game.update(0.05);
      await tester.pump();
      expect(find.byKey(const ValueKey('world_context_bubble')), findsNothing);

      // Wait 2.6s -> toast auto-clears!
      await tester.pump(const Duration(milliseconds: 2600));
      expect(find.byKey(const ValueKey('festival_toast_banner')), findsNothing);

      // 5. Concert Vibe Mode: stand near live Main Roots Stage (608, 448) idle >= 2.5s -> top pill dims, touch wakes!
      game.teleportPlayer(608.0, 464.0);
      game.update(0.1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2800));
      final dimmedOpacity = tester.widget<AnimatedOpacity>(
        find.byKey(const ValueKey('concert_vibe_hud_opacity')),
      );
      expect(dimmedOpacity.opacity, closeTo(0.15, 0.05));

      // Touch canvas -> Concert Vibe Mode wakes immediately back to 1.0!
      await tester.tapAt(const Offset(180, 420));
      await tester.pump();
      final wokenOpacity = tester.widget<AnimatedOpacity>(
        find.byKey(const ValueKey('concert_vibe_hud_opacity')),
      );
      expect(wokenOpacity.opacity, equals(1.0));
    });

    testWidgets(
        'Pocket Program Dance & Move buttons and B/N keyboard shortcuts toggle dancing and cycle all 4 dance moves',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 720);
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        return tester.binding.setSurfaceSize(null);
      });

      final localMap = TiledMapParser.parseTmxAndTsx(
        tmxXmlString: File('assets/tiles/free_orchard_full.tmx').readAsStringSync(),
        tsxXmlString: File('assets/tiles/orchard_tileset.tsx').readAsStringSync(),
      );
      final container = ProviderContainer(
        overrides: [
          festivalDataProvider.overrideWithValue(data),
          saveRepositoryProvider.overrideWithValue(SaveRepository()),
        ],
      );
      addTearDown(container.dispose);

      container.read(playerProfileProvider.notifier)
        ..tearTicket()
        ..selectCultivar('red_livermore')
        ..unlockWardrobe('flower_crown_poncho', autoEquip: true)
        ..confirmCultivarAndEnter();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: WalnutstockApp(
            data: data,
            mapData: localMap,
            audioService: SoloudAudioService(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull);

      // 1. Unfold Pocket Program pill -> Dance button is immediately visible!
      await tester.tap(find.byKey(const ValueKey('pocket_program_pill')));
      await tester.pump();
      final danceBtn = find.byKey(const ValueKey('dance_groove_button'));
      expect(danceBtn, findsOneWidget);
      expect(find.byKey(const ValueKey('dance_style_button')), findsNothing);

      // Tap Dance button -> activates dancing & reveals Move style cycler!
      await tester.tap(danceBtn);
      await tester.pump();
      expect(container.read(worldFlagsProvider).playerDancing, isTrue);
      expect(
        container.read(worldFlagsProvider).currentDanceStyleLabel,
        'Boogie',
      );

      final moveBtn = find.byKey(const ValueKey('dance_style_button'));
      expect(moveBtn, findsOneWidget);

      // Tap Move button -> cycles Boogie -> Twist
      await tester.tap(moveBtn);
      await tester.pump();
      expect(
        container.read(worldFlagsProvider).currentDanceStyleLabel,
        'Twist',
      );

      // Close Pocket Program sheet to verify live world keyboard B/N shortcuts
      await tester.tap(find.byKey(const ValueKey('close_pocket_program_button')));
      await tester.pump();

      // Keyboard N cycles Twist -> Shuffle -> Spin -> Boogie
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyN);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
      expect(
        container.read(worldFlagsProvider).currentDanceStyleLabel,
        'Shuffle',
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyN);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
      expect(
        container.read(worldFlagsProvider).currentDanceStyleLabel,
        'Spin',
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyN);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
      expect(
        container.read(worldFlagsProvider).currentDanceStyleLabel,
        'Boogie',
      );

      // Keyboard B toggles Dance off & back on
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyB);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyB);
      expect(container.read(worldFlagsProvider).playerDancing, isFalse);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyB);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyB);
      expect(container.read(worldFlagsProvider).playerDancing, isTrue);

      // Verify mobile portrait HUD + unfolded Pocket Program have 0 overflows
      tester.view.physicalSize = const Size(390, 844);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Adaptive mobile camera zoom & compact phone portrait/landscape modals render without overflow',
        (tester) async {
      // 1. Adaptive camera zoom scales up on phones vs old 0.81x fixed-resolution letterbox
      final portraitPhoneZoom =
          WalnutstockGame.computeAdaptiveBaseZoom(Vector2(390, 844));
      final landscapePhoneZoom =
          WalnutstockGame.computeAdaptiveBaseZoom(Vector2(844, 390));
      final desktopZoom =
          WalnutstockGame.computeAdaptiveBaseZoom(Vector2(1280, 720));

      expect(portraitPhoneZoom, greaterThan(1.55));
      expect(landscapePhoneZoom, greaterThan(1.65));
      expect(desktopZoom, closeTo(1280.0 / 480.0, 0.02));

      // 2. Pump app across small portrait (360x640) & landscape (640x360) phones with modals open
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        return tester.binding.setSurfaceSize(null);
      });

      final saveRepo = SaveRepository();
      final container = ProviderContainer(
        overrides: [
          festivalDataProvider.overrideWithValue(data),
          saveRepositoryProvider.overrideWithValue(saveRepo),
        ],
      );
      addTearDown(container.dispose);

      container.read(playerProfileProvider.notifier).hydrate(
            const PlayerProfile(
              guestName: 'Mobile Tester',
              cultivarId: 'chandler',
              ticketTorn: true,
              cultivarConfirmed: true,
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: WalnutstockApp(
            data: data,
            mapData: mapData,
            audioService: SoloudAudioService(),
          ),
        ),
      );
      await tester.pump();

      for (final screenSize in const [Size(360, 640), Size(640, 360)]) {
        tester.view.physicalSize = screenSize;
        await tester.binding.setSurfaceSize(screenSize);
        await tester.pump();
        expect(tester.takeException(), isNull);

        for (final modal in const [
          ActiveModalOverlay.settingsDrawer,
          ActiveModalOverlay.turntable,
          ActiveModalOverlay.tentRest,
          ActiveModalOverlay.artifactBooth,
          ActiveModalOverlay.pinball,
          ActiveModalOverlay.sortingBelt,
        ]) {
          container.read(uiOverlayProvider.notifier).openModal(modal);
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Modal $modal should not overflow at $screenSize',
          );
        }
        container.read(uiOverlayProvider.notifier).closeModal();
        await tester.pump();
      }
    });

    testWidgets(
        'OrchardLoadingScreen renders progress, supports interactive cheer, and settles without overflow across viewports',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        return tester.binding.setSurfaceSize(null);
      });

      final progress = ValueNotifier<OrchardLoadProgress>(
        const OrchardLoadProgress(
          loaded: 18,
          total: 60,
          stageLabel: 'Setting up 5 live concert stages & festival crew…',
        ),
      );
      addTearDown(progress.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrchardLoadingScreen(progressListenable: progress),
          ),
        ),
      );

      for (final screenSize in const [
        Size(360, 640),
        Size(640, 360),
        Size(1280, 720),
      ]) {
        tester.view.physicalSize = screenSize;
        await tester.binding.setSurfaceSize(screenSize);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('orchard_loading_card')), findsOneWidget);
      }

      expect(find.text('30%'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('orchard_loader_cheer_button')));
      await tester.pumpAndSettle();
      expect(find.text('Hype 1x'), findsOneWidget);

      progress.value = const OrchardLoadProgress(
        loaded: 54,
        total: 60,
        stageLabel: 'Hanging glowing totems & twilight lanterns…',
      );
      await tester.pumpAndSettle();
      expect(find.text('90%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Festival Satchel, Quests Tab, Vendor Stall Modals, and Pocket Program Quick-Item Chip render & interact cleanly across 1280x720, 960x640, and 390x844 viewports',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 720);
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        return tester.binding.setSurfaceSize(null);
      });

      final container = ProviderContainer(
        overrides: [
          festivalDataProvider.overrideWithValue(data),
          saveRepositoryProvider.overrideWithValue(SaveRepository()),
        ],
      );
      addTearDown(container.dispose);

      container.read(playerProfileProvider.notifier).confirmCultivarAndEnter();
      container.read(journalStateProvider.notifier).addPeaceBeads(25);
      container.read(journalStateProvider.notifier).grantItem(
            'gadget_bubble_wand',
            autoEquipGadget: true,
            displayLabel: 'Soap Bubble Wand',
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: WalnutstockApp(
            data: data,
            mapData: mapData,
            audioService: SoloudAudioService(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Pocket Program Cultivar/Satchel tab Quick-Item chip triggers equipped Soap Bubble Wand cleanly
      await tester.tap(find.byKey(const ValueKey('pocket_program_pill')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('program_tab_cultivars')));
      await tester.pump();
      final quickChip = find.byKey(const ValueKey('quick_item_button'));
      await tester.ensureVisible(quickChip);
      await tester.tap(quickChip);
      await tester.pump();
      expect(tester.takeException(), isNull);

      // 2. Open Vibe Journal -> Satchel tab & Quests tab + Radar quest tracking
      container.read(journalStateProvider.notifier).openJournal();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('journal_tab_satchel')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('satchel_equip_gadget_bubble_wand')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('journal_tab_quests')));
      await tester.pump();
      final trackSunny =
          find.byKey(const ValueKey('track_quest_quest_sunny_polaroids'));
      expect(trackSunny, findsOneWidget);
      await tester.tap(trackSunny);
      await tester.pump();
      expect(
        container.read(journalStateProvider).trackedQuestId,
        'quest_sunny_polaroids',
      );

      // Verify Satchel & Quests tabs have zero layout overflow across all target viewports
      for (final sz in const [
        Size(1280, 720),
        Size(960, 640),
        Size(390, 844),
      ]) {
        tester.view.physicalSize = sz;
        await tester.binding.setSurfaceSize(sz);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'Journal at $sz');
      }
      container.read(journalStateProvider.notifier).closeJournal();
      await tester.pump();

      // 3. Open Burt's Street Food Stall -> Buy Warm Tahini Falafel -> Enjoy Now -> verify across all 4 stalls & viewports
      tester.view.physicalSize = const Size(1280, 720);
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      await tester.pump();

      container.read(uiOverlayProvider.notifier).openVendorStall('burt_food');
      await tester.pump();
      expect(
        find.byKey(const ValueKey('festival_stall_modal_burt_food')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('stall_buy_food_falafel_wrap')));
      await tester.pump();
      expect(
        container.read(journalStateProvider).hasItem('food_falafel_wrap'),
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('stall_use_food_falafel_wrap')));
      await tester.pump();
      expect(
        container.read(worldFlagsProvider).activeSpeedMultiplier,
        greaterThan(1.1),
      );

      for (final stallId in const [
        'burt_food',
        'penny_crafts',
        'colin_curios',
        'bulletin_board',
      ]) {
        container.read(uiOverlayProvider.notifier).openVendorStall(stallId);
        for (final sz in const [
          Size(1280, 720),
          Size(960, 640),
          Size(390, 844),
        ]) {
          tester.view.physicalSize = sz;
          await tester.binding.setSurfaceSize(sz);
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Stall $stallId should not overflow at $sz',
          );
        }
      }
      container.read(uiOverlayProvider.notifier).closeModal();
      await tester.pump();
    });
  });
}
