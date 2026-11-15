import 'dart:async';

import 'package:flame/game.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/platform_audio_probe.dart';
import '../audio/soloud_audio_service.dart';
import '../data/models.dart';
import '../game/minigames/sorting_belt_blues_game.dart';
import '../game/minigames/sorting_pinball_game.dart';
import '../game/walnutstock_game.dart';
import '../game/world/tiled_map_parser.dart';
import '../state/dialogue_and_overlay_state.dart';
import '../state/providers.dart';
import '../ui_overlays/dialogue_box.dart';
import '../ui_overlays/encore_control_deck.dart';
import '../ui_overlays/festival_stall_modal.dart';
import '../ui_overlays/finale_montage_overlay.dart';
import '../ui_overlays/floating_thumb_joystick.dart';
import '../ui_overlays/pocket_program_sheet.dart';
import '../ui_overlays/settings_drawer.dart';
import '../ui_overlays/vibe_journal.dart';
import '../ui_overlays/vinyl_player.dart';
import '../ui_overlays/wristband_hud.dart';
import 'orchard_loading_screen.dart';

class WalnutstockApp extends ConsumerStatefulWidget {
  const WalnutstockApp({
    super.key,
    required this.data,
    required this.mapData,
    required this.audioService,
  });

  final FestivalDataBundle data;
  final OrchardMapData mapData;
  final SoloudAudioService audioService;

  @override
  ConsumerState<WalnutstockApp> createState() => _WalnutstockAppState();
}

class _WalnutstockAppState extends ConsumerState<WalnutstockApp> {
  WalnutstockGame? _game;
  final ValueNotifier<int> _userActivityEpoch = ValueNotifier<int>(0);

  void _notifyUserActivity() {
    _userActivityEpoch.value++;
  }

  @override
  void initState() {
    super.initState();
    registerWebTicketTearCallback(() {
      if (!mounted) return;
      _notifyUserActivity();
      unawaited(widget.audioService.unlockAndInitialize());
      ref.read(playerProfileProvider.notifier).confirmCultivarAndEnter();
      final container = ProviderScope.containerOf(context, listen: false);
      unawaited(persistCurrentGameStateFromContainer(container));
    });
  }

  @override
  void dispose() {
    _userActivityEpoch.dispose();
    super.dispose();
  }

  WalnutstockGame _ensureGame(ProviderContainer container) {
    return _game ??= WalnutstockGame(
      container: container,
      data: widget.data,
      mapData: widget.mapData,
      audioService: widget.audioService,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Walnutstock — Three Days of Peace, Shells & Music',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD49A5A),
          brightness: Brightness.dark,
        ),
      ),
      home: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          _notifyUserActivity();
          unawaited(widget.audioService.unlockAndInitialize());
        },
        onPointerUp: (_) {
          _notifyUserActivity();
          unawaited(widget.audioService.unlockAndInitialize());
        },
        child: _buildPlayableOrchard(context),
      ),
    );
  }

  Widget _buildPlayableOrchard(BuildContext context) {
    final container = ProviderScope.containerOf(context, listen: false);
    final game = _ensureGame(container);
    final overlay = ref.watch(uiOverlayProvider);
    final journalOpen = ref.watch(journalStateProvider).isOpen;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          _notifyUserActivity();
          if (ref.read(uiOverlayProvider).pocketProgramOpen) {
            ref.read(uiOverlayProvider.notifier).closePocketProgram();
          } else if (ref.read(journalStateProvider).isOpen) {
            ref.read(journalStateProvider.notifier).closeJournal();
          } else if (ref.read(uiOverlayProvider).modal !=
              ActiveModalOverlay.none) {
            ref.read(uiOverlayProvider.notifier).closeModal();
          }
        },
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF140D1B),
        body: Stack(
          fit: StackFit.expand,
          children: [
            GameWidget<WalnutstockGame>(
              game: game,
              autofocus: true,
              loadingBuilder: (context) => isWebTicketLoaderActive()
                  ? const ColoredBox(color: Color(0xFF140D1B))
                  : OrchardLoadingScreen(
                      progressListenable: game.loadProgress,
                    ),
            ),
            FloatingThumbJoystick(
              game: game,
              onUserActivity: _notifyUserActivity,
            ),
            WristbandHud(
              game: game,
              userActivityListenable: _userActivityEpoch,
            ),
            if (overlay.pocketProgramOpen) PocketProgramSheet(game: game),
            if (overlay.dialogue != null)
              DialogueBoxOverlay(
                session: overlay.dialogue!,
                onAdvance: game.handleInteract,
              ),
            if (overlay.modal == ActiveModalOverlay.tentRest)
              const TentRestModal(),
            if (overlay.modal == ActiveModalOverlay.turntable)
              const VinylTurntableModal(),
            if (overlay.modal == ActiveModalOverlay.pinball)
              SortingPinballOverlay(audio: widget.audioService),
            if (overlay.modal == ActiveModalOverlay.sortingBelt)
              SortingBeltBluesOverlay(audio: widget.audioService),
            if (overlay.modal == ActiveModalOverlay.artifactBooth)
              const ArtifactBoothModal(),
            if (overlay.modal == ActiveModalOverlay.vendorStall)
              FestivalStallModal(
                onUseItem: game.useEquippedFestivalItem,
              ),
            if (overlay.modal == ActiveModalOverlay.encoreDeck)
              EncoreControlDeck(game: game),
            if (overlay.modal == ActiveModalOverlay.finaleMontage)
              const FinaleMontageOverlay(),
            if (overlay.modal == ActiveModalOverlay.settingsDrawer)
              const SettingsAccessibilityDrawer(),
            if (journalOpen)
              VibeJournalModal(
                onUseItem: game.useEquippedFestivalItem,
              ),
          ],
        ),
      ),
    );
  }
}
