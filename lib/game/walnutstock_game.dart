import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/orchard_loading_screen.dart';
import '../audio/audio_schedule_controller.dart';
import '../audio/soloud_audio_service.dart';
import '../data/models.dart';
import '../state/dialogue_and_overlay_state.dart';
import '../state/festival_clock.dart';
import '../state/providers.dart';
import '../state/world_flags.dart';
import 'actors/npc_actor.dart';
import 'actors/player_walnut.dart';
import 'actors/stage_performer_director.dart';
import 'input/unified_input_controller.dart';
import 'minigames/crowd_sway_controller.dart';
import 'shaders/shader_post_processor.dart';
import 'world/astar_pathfinder.dart';
import 'world/concert_light_show.dart';
import 'world/day_night_atmosphere.dart';
import 'world/electric_blueberry_experience_component.dart';
import 'world/mud_experience_component.dart';
import 'world/stage_3d_rig_component.dart';
import 'world/tiled_chunk_renderer.dart';
import 'world/tiled_map_parser.dart';
import 'world/world_mutators.dart';
import 'zones/psych_rock_fog_zone.dart';

class WalnutstockGame extends FlameGame with KeyboardEvents, TapCallbacks {
  WalnutstockGame({
    required this.container,
    required this.data,
    required this.mapData,
    required this.audioService,
  }) : super(camera: CameraComponent());

  final ProviderContainer container;
  final FestivalDataBundle data;
  final OrchardMapData mapData;
  final SoloudAudioService audioService;

  late final WorldMutators _mutators = WorldMutators(mapData);
  late final AudioScheduleController scheduleController =
      AudioScheduleController(
    catalog: data.setlist,
    audio: audioService,
    lightshows: data.lightshows,
  );
  final UnifiedInputController inputController = UnifiedInputController();
  final CrowdSwayController _crowdSway = CrowdSwayController();
  final ShaderPostProcessor _shaders = ShaderPostProcessor();
  final ValueNotifier<OrchardLoadProgress> loadProgress =
      ValueNotifier<OrchardLoadProgress>(OrchardLoadProgress.initial);
  bool _isRemoved = false;

  TiledChunkLayerComponent? _groundDecorLayer;
  TiledChunkLayerComponent? _canopyLayer;
  StagePerformerDirector? _performerDirector;
  MudExperienceController? _mudExperience;
  ElectricBlueberryExperienceController? _blueberryExperience;
  PlayerWalnut? player;
  PsychRockFogZone? _fogZone;
  final List<NpcActor> _npcActors = [];
  final Map<String, ui.Image> _characterSheets = {};
  final Map<String, ui.Image> _totemImages = {};
  ui.Image? _dewImage;

  DayNightMetrics _dayNightMetrics = DayNightMetrics.middayDefault;
  int _lastSyncedDay = -1;
  double _lastSyncedMinute = -9999.0;
  double _shaderClock = 0.0;
  double _blueberryVisualBlend = 0.0;
  double _autosaveTimer = 0.0;
  double _baseViewportZoom = 1.0;
  String _loadedCultivarId = '';
  bool _day1RainRampToastShown = false;
  bool _day1MudPartyToastShown = false;
  bool _day2BlueberriesToastShown = false;

  DayNightMetrics get currentDayNightMetrics => _dayNightMetrics;
  MudExperienceController? get mudExperience => _mudExperience;
  ElectricBlueberryExperienceController? get blueberryExperience =>
      _blueberryExperience;
  double get blueberryVisualBlend => _blueberryVisualBlend;

  NpcActor? npcActorById(String id) {
    for (final a in _npcActors) {
      if (a.spec.id == id) return a;
    }
    return null;
  }

  Set<String> get activeStagePerformerNpcIds => {
        for (final a in _npcActors)
          if (a.isOnStagePerforming) a.spec.id,
      };

  List<BandEnsembleMemberSpec> get activeEnsemblePerformers =>
      _performerDirector?.activeEnsembleSpecs ?? const [];

  Set<String> get liveStageIds =>
      _performerDirector?.liveStages.keys.toSet() ?? const {};

  Map<String, LiveStageVisualState> get liveStageVisuals =>
      _performerDirector?.liveStages ?? const {};

  List<LightSource3D> collectVisibleWorldLightsForBounds(ui.Rect bounds) =>
      _collectVisibleWorldLights(bounds);

  ui.Offset _cameraWorldCenter() {
    final p = player;
    if (p != null) {
      return ui.Offset(p.position.x, p.position.y);
    }
    return const ui.Offset(608.0, 368.0);
  }

  /// Computes an adaptive camera zoom so phones fill 100% of the screen (no
  /// black letterbox bars) with crisp, zoomed-in 16x16 tiles and 32x32 sprites,
  /// while desktop/laptop screens preserve classic ~480x270 orchard framing.
  static double computeAdaptiveBaseZoom(Vector2 canvasSize) {
    if (canvasSize.x <= 1.0 || canvasSize.y <= 1.0) {
      return 1.0;
    }
    final shortest = math.min(canvasSize.x, canvasSize.y);
    final isPortrait = canvasSize.y > canvasSize.x;
    if (shortest < 540.0) {
      final targetShortWorldSpan = isPortrait ? 236.0 : 222.0;
      return (shortest / targetShortWorldSpan).clamp(1.35, 2.35);
    }
    if (isPortrait && shortest < 900.0) {
      return (canvasSize.x / 360.0).clamp(1.6, 2.8);
    }
    return math.min(canvasSize.x / 480.0, canvasSize.y / 270.0).clamp(1.0, 4.5);
  }

  ui.Rect _cameraWorldBounds() {
    final center = _cameraWorldCenter();
    if (size.x <= 1.0 || size.y <= 1.0) {
      return ui.Rect.fromCenter(center: center, width: 680.0, height: 440.0);
    }
    final zoom = math.max(0.4, camera.viewfinder.zoom);
    return ui.Rect.fromCenter(
      center: center,
      width: size.x / zoom,
      height: size.y / zoom,
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final nextBase = computeAdaptiveBaseZoom(size);
    final prevBase = _baseViewportZoom > 0.0 ? _baseViewportZoom : 1.0;
    final currentRel = (camera.viewfinder.zoom / prevBase).clamp(0.75, 1.35);
    _baseViewportZoom = nextBase;
    camera.viewfinder.zoom = _baseViewportZoom * currentRel;
  }

  static const List<(String, double, double)> _meadowDewSpots = [
    ('dew_west', 1096.0, 392.0),
    ('dew_center', 1144.0, 408.0),
    ('dew_east', 1208.0, 392.0),
  ];

  @override
  ui.Color backgroundColor() => const ui.Color(0xFF1A2816);

  void _reportLoadProgress(int loaded, int total, String label) {
    if (_isRemoved) return;
    loadProgress.value = OrchardLoadProgress(
      loaded: loaded,
      total: total,
      stageLabel: label,
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    images.prefix = '';

    // Preload tileset, props, totems, cultivars, NPCs & shaders concurrently!
    const tilesetPath = 'assets/images/tiles/orchard_tileset.png';
    const dewPath = 'assets/images/props/dew_drop.png';
    final uniqueAssetPaths = <String>{
      tilesetPath,
      dewPath,
      for (final c in data.cultivars) c.sheetAsset,
      for (final npc in data.npcs) npc.sheetAsset,
      for (final perfKey in StagePerformerDirector.ensembleSheetKeys)
        'assets/images/characters/${perfKey}_sheet.png',
      for (final totem in data.totems) totem.sprite,
    };

    final totalSteps = uniqueAssetPaths.length + 2;
    var completedSteps = 0;
    _reportLoadProgress(
      0,
      totalSteps,
      'Unpacking orchard sprites & 1969 stage rigs…',
    );

    final loadedByPath = <String, ui.Image>{};
    await Future.wait<void>([
      for (final path in uniqueAssetPaths)
        images.load(path).then((img) {
          loadedByPath[path] = img;
          completedSteps += 1;
          final ratio = completedSteps / totalSteps;
          final label = ratio < 0.36
              ? 'Painting 11 walnut cultivars & tie-dye outfits…'
              : ratio < 0.72
                  ? 'Setting up 5 live concert stages & festival crew…'
                  : 'Hanging glowing totems & twilight lanterns…';
          _reportLoadProgress(completedSteps, totalSteps, label);
        }),
      _shaders.preloadShaders().then((_) {
        completedSteps += 1;
        _reportLoadProgress(
          completedSteps,
          totalSteps,
          'Warming psychedelic liquid-light projectors…',
        );
      }),
    ]);

    final tilesetImg = loadedByPath[tilesetPath]!;
    _dewImage = loadedByPath[dewPath];
    for (final c in data.cultivars) {
      _characterSheets[c.id] = loadedByPath[c.sheetAsset]!;
    }
    for (final npc in data.npcs) {
      _characterSheets[npc.spriteId] = loadedByPath[npc.sheetAsset]!;
    }
    for (final perfKey in StagePerformerDirector.ensembleSheetKeys) {
      _characterSheets[perfKey] =
          loadedByPath['assets/images/characters/${perfKey}_sheet.png']!;
    }
    for (final totem in data.totems) {
      _totemImages[totem.id] = loadedByPath[totem.sprite]!;
    }

    _groundDecorLayer = TiledChunkLayerComponent(
      map: mapData,
      tilesetImage: tilesetImg,
      isCanopyLayer: false,
      metricsGetter: () => _dayNightMetrics,
      cameraCenterGetter: _cameraWorldCenter,
      viewBoundsGetter: _cameraWorldBounds,
      timeGetter: () => _shaderClock,
      priority: -5000,
    );
    _canopyLayer = TiledChunkLayerComponent(
      map: mapData,
      tilesetImage: tilesetImg,
      isCanopyLayer: true,
      metricsGetter: () => _dayNightMetrics,
      cameraCenterGetter: _cameraWorldCenter,
      viewBoundsGetter: _cameraWorldBounds,
      timeGetter: () => _shaderClock,
      priority: 6000,
    );

    _performerDirector = StagePerformerDirector(
      catalog: data.setlist,
      characterSheets: _characterSheets,
      metricsGetter: () => _dayNightMetrics,
      bassGetter: () => scheduleController.latest.fft.bass,
      timeGetter: () => _shaderClock,
      lightshows: data.lightshows,
      trackTimeGetter: scheduleController.trackPositionSecondsFor,
    );

    _mudExperience = MudExperienceController(
      map: mapData,
      characterSheets: _characterSheets,
      metricsGetter: () => _dayNightMetrics,
      cameraCenterGetter: _cameraWorldCenter,
      viewBoundsGetter: _cameraWorldBounds,
      timeGetter: () => _shaderClock,
      onPlayMudSfx: (pan, volume) {
        final settings = container.read(settingsProvider);
        unawaited(
          audioService.playSfx(
            'assets/audio/sfx/sfx_step_mud.wav',
            volume: volume * settings.masterVolume * settings.sfxVolume,
            pan: pan,
          ),
        );
      },
      onPlayerScoredMudSplat: (targetName) {
        final totalSplats =
            container.read(worldFlagsProvider.notifier).recordMudSplat();
        _crowdSway.aura = (_crowdSway.aura + 0.08).clamp(0.0, 1.0);
        if (totalSplats == 3) {
          container
              .read(journalStateProvider.notifier)
              .addItem('Woodstock Mud-Slide Champion Ribbon');
          unawaited(
            audioService.playSfx(
              'assets/audio/sfx/sfx_quest_complete.wav',
              volume: 0.65,
            ),
          );
          container.read(uiOverlayProvider.notifier).showToast(
                '🏆 Mud-Fight Champion! 3 playful splats — awarded Woodstock Mud-Slide Champion Ribbon!',
              );
        } else {
          container.read(uiOverlayProvider.notifier).showToast(
                '🤎 Direct Mud Splat on $targetName! ($totalSplats splats — watch for their return toss!)',
              );
        }
      },
      onPlayerHitByFriendlyMud: () {
        _crowdSway.aura = (_crowdSway.aura + 0.05).clamp(0.0, 1.0);
      },
    );

    _blueberryExperience = ElectricBlueberryExperienceController(
      characterSheets: _characterSheets,
      metricsGetter: () => _dayNightMetrics,
      cameraCenterGetter: _cameraWorldCenter,
      viewBoundsGetter: _cameraWorldBounds,
      timeGetter: () => _shaderClock,
    );

    final profile = container.read(playerProfileProvider);
    _loadedCultivarId = profile.cultivarId;
    final initialSheet =
        _characterSheets[profile.cultivarId] ?? _characterSheets.values.first;

    // Ensure spawn position is never inside a blocked tile
    var spawnX = profile.savedX;
    var spawnY = profile.savedY;
    if (mapData.isPointBlocked(spawnX, spawnY)) {
      spawnX = 608.0;
      spawnY = 1344.0;
    }

    player = PlayerWalnut(
      map: mapData,
      spriteSheet: initialSheet,
      initialPosition: Vector2(spawnX, spawnY),
      metricsGetter: () => _dayNightMetrics,
    );

    await world.add(_groundDecorLayer!);
    await world.add(
      StageDeckRiserComponent(
        liveStagesGetter: () => _performerDirector?.liveStages ?? const {},
        cameraCenterGetter: _cameraWorldCenter,
        viewBoundsGetter: _cameraWorldBounds,
        timeGetter: () => _shaderClock,
        bassGetter: () => scheduleController.latest.fft.bass,
        priority: -4400,
      ),
    );
    await world.add(_blueberryExperience!.groundLayer);
    await world.add(_mudExperience!.groundLayer);
    await world.add(
      _CollectiblesRenderComponent(
        game: this,
        priority: 300,
      ),
    );

    for (final npcSpec in data.npcs) {
      final sheet =
          _characterSheets[npcSpec.spriteId] ?? _characterSheets.values.first;
      final actor = NpcActor(
        spec: npcSpec,
        map: mapData,
        spriteSheet: sheet,
        metricsGetter: () => _dayNightMetrics,
      );
      _npcActors.add(actor);
      await world.add(actor);
    }

    await world.add(player!);
    await world.add(_canopyLayer!);
    await world.add(
      StageOverheadTrussComponent(
        liveStagesGetter: () => _performerDirector?.liveStages ?? const {},
        metricsGetter: () => _dayNightMetrics,
        cameraCenterGetter: _cameraWorldCenter,
        viewBoundsGetter: _cameraWorldBounds,
        timeGetter: () => _shaderClock,
        bassGetter: () => scheduleController.latest.fft.bass,
        midGetter: () => scheduleController.latest.fft.lowMid,
        priority: 6300,
      ),
    );
    await world.add(_mudExperience!.airborneLayer);
    await world.add(_blueberryExperience!.airborneLayer);
    await world.add(
      WorldWeatherParticlesComponent(
        map: mapData,
        metricsGetter: () => _dayNightMetrics,
        cameraCenterGetter: _cameraWorldCenter,
        viewBoundsGetter: _cameraWorldBounds,
        timeGetter: () => _shaderClock,
        firefliesEnabledGetter: () {
          final clk = container.read(festivalClockProvider);
          final flg = container.read(worldFlagsProvider);
          return (flg.firefliesActive && clk.isNightOrDusk) ||
              clk.effectiveWeather == WeatherPhase.starryFireflies;
        },
        priority: 7500,
      ),
    );

    _fogZone = PsychRockFogZone(
      fogBounds: const ui.Rect.fromLTWH(896, 32, 608, 256),
      bellCenter: const ui.Offset(1200, 144),
    );
    await world.add(_fogZone!);

    await world.add(
      DayNightLightmapComponent(
        metricsGetter: () => _dayNightMetrics,
        cameraCenterGetter: _cameraWorldCenter,
        viewBoundsGetter: _cameraWorldBounds,
        lightsGetter: _collectVisibleWorldLights,
        priority: 9400,
      ),
    );
    await world.add(
      StageLiveBannerComponent(
        liveStagesGetter: () => _performerDirector?.liveStages ?? const {},
        stagesCatalog: data.setlist.stages,
        cameraCenterGetter: _cameraWorldCenter,
        viewBoundsGetter: _cameraWorldBounds,
        timeGetter: () => _shaderClock,
        priority: 9600,
      ),
    );

    _baseViewportZoom = computeAdaptiveBaseZoom(size);
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.zoom = _baseViewportZoom;
    camera.follow(player!, snap: true);

    // Sync initial atmosphere, live stage performers, and world mutations
    final initialClock = container.read(festivalClockProvider);
    _refreshAtmosphereAndPerformers(
      clock: initialClock,
      shaderIntensity: container.read(settingsProvider).shaderIntensity,
      bass: 0.0,
      snapPerformers: true,
    );
    _syncWorldMutations();

    // Start rolling-window background track pre-fetching (active + next upcoming sets)
    audioService.cache.startBackgroundPrefetch(
      data.setlist,
      currentDay: initialClock.day,
      currentMinute: initialClock.minuteOfDay,
    );

    _reportLoadProgress(
      totalSteps,
      totalSteps,
      'Gates Open — Peace, Shells & Music! ✌️',
    );
  }

  @override
  void onRemove() {
    _isRemoved = true;
    _shaders.dispose();
    super.onRemove();
  }

  void teleportPlayer(double wx, double wy) {
    final p = player;
    if (p == null) return;
    p.clearTapPath();
    p.position.setValues(wx, wy);
    camera.follow(p, snap: true);
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is KeyDownEvent) {
      unawaited(audioService.unlockAndInitialize());
    }
    final overlayState = container.read(uiOverlayProvider);
    if (overlayState.modal != ActiveModalOverlay.none ||
        container.read(journalStateProvider).isOpen) {
      inputController.clearAll();
      return KeyEventResult.ignored;
    }
    final action = inputController.handleKeyEvent(event);
    if (action != null) {
      _dispatchInputAction(action);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void onTapDown(TapDownEvent event) {
    unawaited(audioService.unlockAndInitialize());
    final overlayState = container.read(uiOverlayProvider);
    if (overlayState.isBlockingInput ||
        container.read(journalStateProvider).isOpen) {
      return;
    }
    final p = player;
    if (p == null) return;

    final worldPt = camera.globalToLocal(event.canvasPosition);
    // If tapping right beside an interactable/NPC within reach, trigger interact!
    if ((worldPt - p.position).length < 40.0 &&
        overlayState.nearbyInteractPrompt != null) {
      handleInteract();
      return;
    }

    // Tapping directly on the Day 2 Creekside Electric Purple Blueberries basket shares berries!
    final clock = container.read(festivalClockProvider);
    if (clock.isDay2BlueberrySharingActive) {
      final basketVec = Vector2(
        ElectricBlueberryExperienceController.basketWorldPos.dx,
        ElectricBlueberryExperienceController.basketWorldPos.dy,
      );
      if ((worldPt - basketVec).length < 28.0 &&
          (basketVec - p.position).length < 72.0) {
        triggerEatElectricBlueberries();
        return;
      }
    }

    // Tapping directly on a playful Mud Reveler during the Mud Experience flings a mudball!
    final mudCtrl = _mudExperience;
    if (mudCtrl != null && clock.isMudExperienceActive(data.setlist)) {
      for (final rev in mudCtrl.revelers) {
        if ((worldPt - rev.position).length < 24.0 &&
            (rev.position - p.position).length < 195.0) {
          triggerPlayerMudThrow(
            targetWorldPos: ui.Offset(rev.position.x, rev.position.y),
          );
          return;
        }
      }
    }

    final path = AStarPathfinder(mapData).findWorldPath(
      startX: p.position.x,
      startY: p.position.y,
      goalX: worldPt.x,
      goalY: worldPt.y,
    );
    if (path.isNotEmpty) {
      p.setTapPath(path);
    }
  }

  /// Triggers a joyful Woodstock Belly-Slide across muddy lanes & the Mud Pit Meadow!
  bool triggerPlayerMudSlide() {
    final p = player;
    if (p == null) return false;
    final clock = container.read(festivalClockProvider);
    final mudActive = clock.isOrchardMuddy(data.setlist) ||
        clock.isMudExperienceActive(data.setlist);
    final slid = p.triggerMudSlide(allowWetTurf: mudActive);
    if (!slid) {
      if (!mudActive) {
        container.read(uiOverlayProvider.notifier).showToast(
              '🛝 Wait for the rain after Day 1 Set 7–8 (or Rest to Mud Fest!) to belly-slide in the mud!',
            );
      }
      return false;
    }
    final settings = container.read(settingsProvider);
    unawaited(
      audioService.playSfx(
        'assets/audio/sfx/sfx_step_mud.wav',
        volume: 0.58 * settings.masterVolume * settings.sfxVolume,
      ),
    );
    _mudExperience?.recordSlideCallout(ui.Offset(p.position.x, p.position.y));
    final count = container.read(worldFlagsProvider.notifier).recordMudSlide();
    _crowdSway.aura = (_crowdSway.aura + 0.05).clamp(0.0, 1.0);
    if (count == 1) {
      container.read(uiOverlayProvider.notifier).showToast(
            '🛝 Wheee! Woodstock Mud Belly-Slide! Press [F] / Mud Toss for a mud fight!',
          );
    } else if (count == 3 &&
        container.read(worldFlagsProvider).mudFightsSplatted < 3) {
      container
          .read(journalStateProvider.notifier)
          .addItem('Woodstock Mud-Slide Champion Ribbon');
      container.read(uiOverlayProvider.notifier).showToast(
            '🏆 3 Mud Belly-Slides! Earned Woodstock Mud-Slide Champion Ribbon!',
          );
    }
    return true;
  }

  /// Scoops & lobs a 3D parabolic mudball in the post-rain Mud Fight!
  bool triggerPlayerMudThrow({ui.Offset? targetWorldPos}) {
    final p = player;
    final mudCtrl = _mudExperience;
    if (p == null || mudCtrl == null) return false;
    final clock = container.read(festivalClockProvider);
    final mudAllowed = clock.isOrchardMuddy(data.setlist) ||
        clock.isMudExperienceActive(data.setlist);
    final thrown = mudCtrl.throwPlayerMudball(
      player: p,
      npcs: _npcActors,
      mudAllowed: mudAllowed,
      targetWorldPos: targetWorldPos,
    );
    if (!thrown && !mudAllowed) {
      container.read(uiOverlayProvider.notifier).showToast(
            '🤎 No mud yet! Rain ramps up on Day 1 Set 7 and turns the orchard into a Mud Pit after Set 8!',
          );
    }
    return thrown;
  }

  /// Shares & tastes the Day 2 creekside Electric Purple Blueberries, making everything
  /// wavy and rainbow across the next 2 scheduled musical sets!
  bool triggerEatElectricBlueberries() {
    final clock = container.read(festivalClockProvider);
    final settings = container.read(settingsProvider);
    container.read(worldFlagsProvider.notifier).activateElectricBlueberries(
          data.setlist,
          day: clock.day,
          minuteOfDay: clock.minuteOfDay,
        );
    container
        .read(journalStateProvider.notifier)
        .addItem('Electric Purple Blueberries');
    _crowdSway.aura = (_crowdSway.aura + 0.14).clamp(0.0, 1.0);
    _blueberryVisualBlend = math.max(_blueberryVisualBlend, 0.45);
    _blueberryExperience?.recordBerrySharedBurst();
    unawaited(
      audioService.playSfx(
        'assets/audio/sfx/sfx_bell_cmajor.wav',
        volume: 0.65 * settings.masterVolume * settings.sfxVolume,
      ),
    );
    container.read(uiOverlayProvider.notifier).showToast(
          '🫐🌈 Shared Electric Purple Blueberries! Everything waves in rainbow colors for 2 sets!',
        );
    return true;
  }

  /// Toggles the player's music-synced Dance Groove!
  void togglePlayerDanceGroove() {
    final p = player;
    final notifier = container.read(worldFlagsProvider.notifier);
    notifier.togglePlayerDance();
    final updated = container.read(worldFlagsProvider);
    if (updated.playerDancing) {
      p?.clearTapPath();
      final nearStage = p != null ? _nearestLiveStageEntry(p.position) : null;
      final bpmLabel = nearStage != null
          ? ' (${nearStage.$2.show.bpm.round()} BPM synced!)'
          : '';
      container.read(uiOverlayProvider.notifier).showToast(
            '💃 Grooving (${updated.currentDanceStyleLabel})$bpmLabel — press [N] or Move to switch steps!',
          );
    }
  }

  /// Cycles through the 4 1969 Woodstock dance styles (Boogie, Twist, Shuffle, Spin).
  void cyclePlayerDanceMove() {
    player?.clearTapPath();
    container.read(worldFlagsProvider.notifier).cyclePlayerDanceStyle();
    final updated = container.read(worldFlagsProvider);
    container.read(uiOverlayProvider.notifier).showToast(
          '🕺 Dance Move: ${updated.currentDanceStyleLabel}!',
        );
  }

  void _dispatchInputAction(String action) {
    if (action == 'journal') {
      container.read(journalStateProvider.notifier).toggleJournal();
      return;
    }
    if (action == 'dance') {
      togglePlayerDanceGroove();
      return;
    }
    if (action == 'dance_style') {
      cyclePlayerDanceMove();
      return;
    }
    if (action == 'mud_slide') {
      triggerPlayerMudSlide();
      return;
    }
    if (action == 'mud_toss') {
      triggerPlayerMudThrow();
      return;
    }
    if (action == 'sway') {
      final flags = container.read(worldFlagsProvider);
      if (flags.slowWaveSwayUnlocked ||
          container.read(festivalClockProvider).pureVibeMode) {
        container.read(worldFlagsProvider.notifier).togglePlayerSway();
      } else {
        container.read(uiOverlayProvider.notifier).showToast(
              'Chat with Burt Baskernut or Joan Baezelnut to learn the Slow-Wave Sway!',
            );
      }
      return;
    }
    if (action == 'interact') {
      handleInteract();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Flame's GameWidget calls update(0) synchronously inside LayoutBuilder.build
    // on initial mount and viewport resizes; never mutate Riverpod providers during build.
    if (dt <= 0.0) {
      final clock = container.read(festivalClockProvider);
      final settings = container.read(settingsProvider);
      _dayNightMetrics = DayNightMetrics.compute(
        clock,
        timeSeconds: _shaderClock,
        bass: scheduleController.latest.fft.bass,
        shaderIntensity: settings.shaderIntensity,
        stormStartMinute: data.setlist.trackByNumber(15)?.startMinute ?? 1070.0,
        day1RainRampStartMinute:
            data.setlist.trackByNumber(7)?.startMinute ?? 1139.61,
        day1StormStartMinute:
            data.setlist.trackByNumber(8)?.startMinute ?? 1171.64,
      );
      _syncWorldMutations();
      return;
    }

    _shaderClock += dt;

    final p = player;
    if (p == null) return;

    final profile = container.read(playerProfileProvider);
    if (profile.cultivarId != _loadedCultivarId) {
      _loadedCultivarId = profile.cultivarId;
      final nextSheet = _characterSheets[profile.cultivarId];
      if (nextSheet != null) p.updateSheet(nextSheet);
    }

    final overlay = container.read(uiOverlayProvider);
    final journalOpen = container.read(journalStateProvider).isOpen;
    final blocked = overlay.isBlockingInput || journalOpen;

    // 1. Advance 3-Day Festival Clock
    final wasEncoreUnlocked =
        container.read(festivalClockProvider).encoreModeUnlocked;
    if (!blocked) {
      container.read(festivalClockProvider.notifier).tickRealSeconds(dt);
    }
    final clock = container.read(festivalClockProvider);
    final settings = container.read(settingsProvider);
    final flags = container.read(worldFlagsProvider);

    // Guarantee Finale Montage opens if Day 3 wrapped into Endless Encore Mode on this tick
    if (!wasEncoreUnlocked &&
        clock.encoreModeUnlocked &&
        !flags.finaleMontageShown) {
      container
          .read(journalStateProvider.notifier)
          .collectVinyl('vinyl_side_d');
      container.read(worldFlagsProvider.notifier).update(
            (cur) => cur.copyWith(finaleMontageShown: true),
          );
      container
          .read(uiOverlayProvider.notifier)
          .openModal(ActiveModalOverlay.finaleMontage);
    }

    // 2. Apply active scheduled track world events (Fence Drop, Moss-Bloom, Shaders, Finale!)
    final activeTracks =
        data.setlist.activeTracksAt(clock.day, clock.minuteOfDay);
    for (final t in activeTracks) {
      if (t.worldEvent != null) {
        final hadFences = container.read(worldFlagsProvider).fencesDropped;
        final hadMoss = container.read(worldFlagsProvider).mossBridgesBloomed;
        container
            .read(worldFlagsProvider.notifier)
            .applyScheduledWorldEvent(t.worldEvent);
        if (!hadFences && t.worldEvent == 'drop_front_gate_fences') {
          unawaited(
            audioService.playSfx(
              'assets/audio/sfx/sfx_fence_drop.wav',
              volume: 0.7 * settings.masterVolume * settings.sfxVolume,
            ),
          );
          container.read(uiOverlayProvider.notifier).showToast(
                "Patchouli Pete: 'The fences are DOWN! Welcome to the Free Orchard!'",
              );
        }
        if (!hadMoss && t.worldEvent == 'bloom_moss_bridges') {
          unawaited(
            audioService.playSfx(
              'assets/audio/sfx/sfx_moss_bloom.wav',
              volume: 0.65 * settings.masterVolume * settings.sfxVolume,
            ),
          );
          container.read(uiOverlayProvider.notifier).showToast(
                "Janice Joeplant's vocals bloomed a Moss-Bridge behind the Velvet Canopy!",
              );
        }
        if (t.worldEvent == 'unlock_encore_mode' &&
            clock.minuteOfDay >= t.endMinute - 3.0 &&
            !container.read(worldFlagsProvider).finaleMontageShown) {
          container.read(festivalClockProvider.notifier).unlockEncoreMode();
          container
              .read(journalStateProvider.notifier)
              .collectVinyl('vinyl_side_d');
          container.read(worldFlagsProvider.notifier).update(
                (cur) => cur.copyWith(finaleMontageShown: true),
              );
          container
              .read(uiOverlayProvider.notifier)
              .openModal(ActiveModalOverlay.finaleMontage);
        }
      }
    }
    container.read(worldFlagsProvider.notifier).syncTransientShaderEvents(
          activeTracks.map((t) => t.worldEvent).toList(growable: false),
          currentDay: clock.day,
          currentMinute: clock.minuteOfDay,
        );

    // Sync continuous Day/Night/Storm metrics + scheduled live stage performers
    final clockJumped = _lastSyncedDay != clock.day ||
        (clock.minuteOfDay - _lastSyncedMinute).abs() > 2.5;
    _refreshAtmosphereAndPerformers(
      clock: clock,
      shaderIntensity: settings.shaderIntensity,
      bass: scheduleController.latest.fft.bass,
      snapPerformers: clockJumped,
    );
    _syncWorldMutations();

    // 3. Player Input + Surface Physics
    final sampled = inputController.sampleMovementAndGamepad();
    if (sampled.gamepadAction != null) {
      _dispatchInputAction(sampled.gamepadAction!);
    }
    final currentFlags = container.read(worldFlagsProvider);
    p.isSwaying = currentFlags.playerSwaying;
    p.isDancing = currentFlags.playerDancing;
    p.danceStyle = currentFlags.playerDanceStyle;
    p.lowGravityEnhanced = currentFlags.cosmoQuestCompleted;
    p.equippedWardrobeId = profile.equippedWardrobeId;

    final stepSurface = p.stepPhysics(
      dt: dt,
      manualInput: sampled.move,
      inputBlocked: blocked,
    );
    if (stepSurface != null) {
      final stepAsset = switch (stepSurface) {
        'mud' => 'assets/audio/sfx/sfx_step_mud.wav',
        'dirt' => 'assets/audio/sfx/sfx_step_dirt.wav',
        'wood_stage' || 'velvet_carpet' => 'assets/audio/sfx/sfx_step_wood.wav',
        'asphalt' => 'assets/audio/sfx/sfx_step_asphalt.wav',
        _ => 'assets/audio/sfx/sfx_step_grass.wav',
      };
      unawaited(
        audioService.playSfx(
          stepAsset,
          volume: 0.24 * settings.masterVolume * settings.sfxVolume,
        ),
      );
    }

    // Check Morning Dew & 3D Totem Walk-Over Pickups
    _checkWalkoverCollectibles(p.position, clock, settings);

    // Update Zone Name & Lost-Woods Psych-Rock Fog Maze
    final fogZone = _fogZone;
    if (fogZone != null) {
      fogZone.visualAssistEnabled = settings.fogVisualAssist;
      final fogOutcome = fogZone.evaluateMazeStep(
        currentPos: ui.Offset(p.position.x, p.position.y),
        bypassMaze: clock.pureVibeMode ||
            container.read(worldFlagsProvider).tulaQuestCompleted,
      );
      if (fogOutcome == FogMazeStepOutcome.waypointHarmonized) {
        unawaited(
          audioService.playSfx(
            'assets/audio/sfx/sfx_bell_cmajor.wav',
            volume: 0.65 * settings.masterVolume * settings.sfxVolume,
          ),
        );
        container.read(uiOverlayProvider.notifier).showToast(
              '🔔 C-Major Bell Resonance (1/2) — follow the shifting stereo chime east!',
            );
      } else if (fogOutcome == FogMazeStepOutcome.sanctumRevealed) {
        unawaited(
          audioService.playSfx(
            'assets/audio/sfx/sfx_bell_cmajor.wav',
            volume: 0.72 * settings.masterVolume * settings.sfxVolume,
          ),
        );
        container.read(uiOverlayProvider.notifier).showToast(
              '✨ The Psych-Rock Fog parts around Tula’s Sacred Tea-Light Circle!',
            );
      } else if (fogOutcome == FogMazeStepOutcome.wrappedToEntrance) {
        teleportPlayer(
          PsychRockFogZone.entranceSpawn.dx,
          PsychRockFogZone.entranceSpawn.dy,
        );
        fogZone.playerPos = PsychRockFogZone.entranceSpawn;
        unawaited(
          audioService.playSfx(
            'assets/audio/sfx/sfx_bell_cmajor.wav',
            volume: 0.45 * settings.masterVolume * settings.sfxVolume,
          ),
        );
        container.read(uiOverlayProvider.notifier).showToast(
              '🌫️ Swirling Psych-Rock Fog wraps you back — follow the stereo C-major bells!',
            );
      }
    }

    final zoneName = mapData.zoneNameAtWorld(p.position.x, p.position.y);
    if (zoneName != profile.activeZoneName) {
      container
          .read(playerProfileProvider.notifier)
          .updatePosition(p.position.x, p.position.y, zoneName: zoneName);
    }

    // 4. Spatial Multi-Stage Audio + Arcade Cabinet + FFT
    final occluded = mapData.isOccludedAtWorld(p.position.x, p.position.y);
    final inFog = fogZone?.isPlayerInside ?? false;
    final fogTarget = fogZone?.activeBellTarget;
    final arcadeTrackId = switch (overlay.modal) {
      ActiveModalOverlay.pinball => 'track_17',
      ActiveModalOverlay.sortingBelt => 'track_20',
      _ => null,
    };
    final audioSnap = scheduleController.update(
      dtSeconds: dt,
      clock: clock,
      settings: settings,
      listenerX: p.position.x,
      listenerY: p.position.y,
      listenerInOcclusionZone: occluded,
      listenerInUndergrowthFog: inFog,
      fogBeaconWorldPos:
          fogTarget != null ? (fogTarget.dx, fogTarget.dy) : null,
      activeArcadeTrackId: arcadeTrackId,
      turntableTrackNumber: overlay.turntableTrackNumber,
      encoreAnywhereJukebox: clock.encoreModeUnlocked,
      justListenStageMode:
          container.read(worldFlagsProvider).justListenStageMode,
      onFiveMinuteBellAlert: (upcoming) {
        container.read(uiOverlayProvider.notifier).showToast(
              '🔔 5 Min Alert: "${upcoming.title}" starting soon at ${data.setlist.stages[upcoming.stageId]?.name ?? upcoming.stageId}!',
            );
      },
      onTrackHeardStamp: (heard) {
        container
            .read(journalStateProvider.notifier)
            .stampTrack(heard.trackNumber);
      },
    );

    // 5. Music-Synced Player Dance Frame + Crowd Resonance & Camera Zoom
    final updatedFlags = container.read(worldFlagsProvider);
    StageShowFrame? playerMusicShow;
    final nearestForPlayer = _nearestLiveStageEntry(p.position);
    if (nearestForPlayer != null &&
        (p.position.distanceTo(
                  Vector2(nearestForPlayer.$1.dx, nearestForPlayer.$1.dy),
                ) <=
                540.0 ||
            (audioSnap.primaryMix?.gain ?? 0.0) > 0.04)) {
      playerMusicShow = nearestForPlayer.$2.show;
    } else if (audioSnap.primaryTrack != null &&
        (audioSnap.primaryMix?.gain ?? 0.0) > 0.04) {
      final mixTrack = audioSnap.primaryTrack!;
      final tSec = scheduleController.trackPositionSecondsFor(mixTrack, clock);
      playerMusicShow = data.lightshows.sampleTrack(mixTrack, tSec);
    }
    p.isDancing = updatedFlags.playerDancing;
    p.danceStyle = updatedFlags.playerDanceStyle;
    p.activeMusicShow = playerMusicShow;
    p.musicBass = audioSnap.fft.bass;
    p.musicMid = audioSnap.fft.lowMid;
    p.musicEnergy =
        ((audioSnap.fft.bass + audioSnap.fft.lowMid) * 0.5).clamp(0.0, 1.0);

    final targetZoom = _crowdSway.update(
      dt: dt,
      audibleStageGain: audioSnap.primaryMix?.gain ?? 0.0,
      playerSwaying: updatedFlags.playerSwaying,
      playerDancing: updatedFlags.playerDancing,
      pureVibeMode: clock.pureVibeMode,
      justListenMode: updatedFlags.justListenStageMode,
    );
    p.crowdAura = _crowdSway.aura;
    if ((_crowdSway.aura - updatedFlags.crowdAura).abs() > 0.05) {
      container.read(worldFlagsProvider.notifier).setCrowdAura(_crowdSway.aura);
    }
    final desiredZoom = _baseViewportZoom * targetZoom;
    camera.viewfinder.zoom +=
        (desiredZoom - camera.viewfinder.zoom) * (dt * 3.0).clamp(0.0, 1.0);

    // 6. Step all 34 NPC AI routines (including on-stage performers & beat-synced stage dancers!)
    for (final actor in _npcActors) {
      final dist = actor.position.distanceTo(p.position);
      final nearStage = _nearestLiveStageEntry(actor.position);
      actor.stepAi(
        dt: dt,
        gMajorActive: audioSnap.fft.gMajorActive,
        organ440Level: audioSnap.fft.organ440,
        crowdMigrateMainRoots: updatedFlags.crowdMigrateMainRoots,
        playerDistance: dist,
        bassLevel: audioSnap.fft.bass,
        nearbyLiveStagePos: nearStage?.$1,
        nearbyStageShow: nearStage?.$2.show,
        playerDancingNearby: updatedFlags.playerDancing,
      );
    }

    // 6b. Step Woodstock Post-Rain Mud Experience (belly-slide trails, 3D mudballs & friendly mud fights!)
    final mudPartyActive = clock.isMudExperienceActive(data.setlist);
    final orchardMuddy = clock.isOrchardMuddy(data.setlist);
    if (clock.day == 1 &&
        clock.effectiveWeather == WeatherPhase.preStormHumid &&
        !_day1RainRampToastShown) {
      _day1RainRampToastShown = true;
      container.read(uiOverlayProvider.notifier).showToast(
            '🌧️ Set 7 Drizzle: Rainclouds are rolling over the lanterns — storm ramping up!',
          );
    }
    if (clock.day == 1 && mudPartyActive && !_day1MudPartyToastShown) {
      _day1MudPartyToastShown = true;
      container.read(uiOverlayProvider.notifier).showToast(
            '🛝 Woodstock Mud Experience! Slide with [Shift] / Mud Slide & fling mudballs with [F] / Mud Toss!',
          );
    }
    _mudExperience?.update(
      dt: dt,
      world: world,
      mudPartyActive: mudPartyActive,
      orchardMuddy: orchardMuddy,
      player: p,
      npcs: _npcActors,
    );

    // 6c. Step Day 2 Creekside Electric Purple Blueberries Sharing Circle & 2-Set Wavy Rainbow!
    if (clock.isDay2BlueberrySharingActive && !_day2BlueberriesToastShown) {
      _day2BlueberriesToastShown = true;
      container.read(uiOverlayProvider.notifier).showToast(
            '🫐 Day 2 Sunrise! Festivalgoers are sharing Electric Purple Blueberries near the Willow Creek & Meadow Stage!',
          );
    }
    final expiredAfterTwoSets = container
        .read(worldFlagsProvider.notifier)
        .clearExpiredBlueberryTrip(clock.day, clock.minuteOfDay);
    if (expiredAfterTwoSets) {
      container.read(uiOverlayProvider.notifier).showToast(
            '🌈 Two musical sets of wavy rainbow gently mellow back into peaceful orchard light!',
          );
    }
    final berryFlags = container.read(worldFlagsProvider);
    final sharingActive = clock.isDay2BlueberrySharingActive;
    final berryRainbowActive =
        berryFlags.isBlueberryRainbowActiveAt(clock.day, clock.minuteOfDay) ||
            clock.shaderOverride == 'electric_blueberry';
    _blueberryExperience?.update(
      dt: dt,
      world: world,
      sharingActive: sharingActive,
      rainbowActive: berryRainbowActive,
      player: p,
    );
    if (_blueberryExperience != null &&
        _blueberryExperience!.shouldAutoShareOnWalkover(
          p.position,
          alreadyInFirstSet: berryFlags.blueberrySetsRemainingAt(
                clock.day,
                clock.minuteOfDay,
              ) >=
              2,
        )) {
      triggerEatElectricBlueberries();
    }
    final postShareBerryActive = container
            .read(worldFlagsProvider)
            .isBlueberryRainbowActiveAt(clock.day, clock.minuteOfDay) ||
        clock.shaderOverride == 'electric_blueberry';
    final targetBerryBlend = postShareBerryActive ? 1.0 : 0.0;
    if (clockJumped) {
      _blueberryVisualBlend = targetBerryBlend;
    } else {
      _blueberryVisualBlend +=
          (targetBerryBlend - _blueberryVisualBlend) * (dt * 3.0).clamp(0.0, 1.0);
    }

    // 7. Update Contextual Interaction Prompt
    _updateInteractionPrompt(p.position);

    // Periodic gentle position & state autosave + rolling audio window warm-up
    _autosaveTimer += dt;
    if (_autosaveTimer >= 12.0) {
      _autosaveTimer = 0.0;
      container
          .read(playerProfileProvider.notifier)
          .updatePosition(p.position.x, p.position.y, zoneName: zoneName);
      unawaited(persistCurrentGameStateFromContainer(container));
      audioService.cache.startBackgroundPrefetch(
        data.setlist,
        currentDay: clock.day,
        currentMinute: clock.minuteOfDay,
      );
    }
  }

  void _refreshAtmosphereAndPerformers({
    required FestivalClockState clock,
    required double shaderIntensity,
    required double bass,
    required bool snapPerformers,
  }) {
    final stormTrack = data.setlist.trackByNumber(15);
    _dayNightMetrics = DayNightMetrics.compute(
      clock,
      timeSeconds: _shaderClock,
      bass: bass,
      shaderIntensity: shaderIntensity,
      stormStartMinute: stormTrack?.startMinute ?? 1070.0,
      day1RainRampStartMinute:
          data.setlist.trackByNumber(7)?.startMinute ?? 1139.61,
      day1StormStartMinute:
          data.setlist.trackByNumber(8)?.startMinute ?? 1171.64,
    );

    final director = _performerDirector;
    if (director != null) {
      director.updateSchedule(world: world, clock: clock);
      for (final actor in _npcActors) {
        final mark = director.activeNpcMarks[actor.spec.id];
        actor.applyStageAssignment(mark, snapImmediately: snapPerformers);
        actor.activeStageShow =
            mark != null ? director.liveStages[mark.stageId]?.show : null;
      }
    }

    _lastSyncedDay = clock.day;
    _lastSyncedMinute = clock.minuteOfDay;
  }

  (ui.Offset, LiveStageVisualState)? _nearestLiveStageEntry(Vector2 fromPos) {
    final live = _performerDirector?.liveStages;
    if (live == null || live.isEmpty) return null;
    (ui.Offset, LiveStageVisualState)? best;
    var bestD2 = double.infinity;
    for (final entry in live.entries) {
      if (entry.key == 'pa_global_horn') continue;
      final st = data.setlist.stages[entry.key];
      if (st == null) continue;
      final dx = st.x - fromPos.x;
      final dy = st.y - fromPos.y;
      final d2 = dx * dx + dy * dy;
      if (d2 < bestD2) {
        bestD2 = d2;
        best = (ui.Offset(st.x, st.y), entry.value);
      }
    }
    return best;
  }

  List<LightSource3D> _collectVisibleWorldLights(ui.Rect bounds) {
    final out = <LightSource3D>[];
    final flags = container.read(worldFlagsProvider);
    final lanternStrength = flags.lanternsLit
        ? math.max(_dayNightMetrics.lanternGlowStrength, 0.75)
        : _dayNightMetrics.lanternGlowStrength;

    // 1. Orchard pathway & stage lanterns
    final groundLayer = _groundDecorLayer;
    if (groundLayer != null && lanternStrength > 0.05) {
      for (final pt in groundLayer.lanternCenters) {
        if (bounds.contains(pt)) {
          out.add(
            LightSource3D(
              position: pt,
              radius: 44.0,
              color: const ui.Color(0xFFFFCF56),
              intensity: lanternStrength * 0.90,
            ),
          );
        }
      }
    }

    // 2. Active live concert stages (dynamic moving-head spot pools & blinders!)
    final live = _performerDirector?.liveStages;
    if (live != null) {
      for (final entry in live.entries) {
        final st = data.setlist.stages[entry.key];
        if (st == null) continue;
        final pos = ui.Offset(st.x, st.y);
        if (bounds.inflate(140).contains(pos)) {
          out.addAll(
            buildDynamicStageWorldLights(
              stageId: entry.key,
              stageCenter: pos,
              show: entry.value.show,
              primaryColor: entry.value.primaryColor,
              secondaryColor: entry.value.secondaryColor,
              soloFocusPos: entry.value.soloFocusPos,
            ),
          );
        }
      }
    }

    // 3. Architectural sanctuary & vehicle lights at dusk/night/storm
    if (_dayNightMetrics.darknessFactor > 0.06) {
      const sanctuaries = <(ui.Offset, double, ui.Color, double)>[
        (ui.Offset(1200, 144), 76.0, ui.Color(0xFF80FFDB), 0.85), // Tea-Light Altar
        (ui.Offset(1760, 352), 140.0, ui.Color(0xFF72EFDD), 0.88), // Andromeda Dome
        (ui.Offset(186, 1020), 66.0, ui.Color(0xFFFFE599), 0.80), // 1969 Urbano Headlights
        (ui.Offset(1746, 1002), 92.0, ui.Color(0xFFFFBE0B), 0.85), // Sorting Arcade Marquee
        (ui.Offset(1056, 976), 72.0, ui.Color(0xFFFFB703), 0.80), // Campground Turntable
      ];
      for (final (pos, r, col, str) in sanctuaries) {
        if (bounds.inflate(60).contains(pos)) {
          out.add(
            LightSource3D(
              position: pos,
              radius: r,
              color: col,
              intensity: str,
            ),
          );
        }
      }
    }

    // 4. Subtle personal moss-band / crowd-aura fill light around player
    final p = player;
    if (p != null && _dayNightMetrics.darknessFactor > 0.12) {
      out.add(
        LightSource3D(
          position: ui.Offset(p.position.x, p.position.y),
          radius: 40.0 + p.crowdAura * 28.0,
          color: const ui.Color(0xFFFFE599),
          intensity: 0.48 + p.crowdAura * 0.36,
        ),
      );
    }

    // 5. Day 2 Dawn Creekside Electric Purple Blueberries glowing sharing aura
    final clock = container.read(festivalClockProvider);
    if (clock.isDay2BlueberrySharingActive &&
        bounds.inflate(72).contains(
              ElectricBlueberryExperienceController.basketWorldPos,
            )) {
      out.add(
        const LightSource3D(
          position: ElectricBlueberryExperienceController.basketWorldPos,
          radius: 68.0,
          color: ui.Color(0xFF9D4EDD),
          intensity: 0.85,
        ),
      );
    }

    return out;
  }

  void _syncWorldMutations() {
    final flags = container.read(worldFlagsProvider);
    final clockNotifier = container.read(festivalClockProvider.notifier);
    var dirty = false;

    if (flags.fencesDropped && _mutators.applyFenceDrop()) {
      dirty = true;
    }
    if (flags.mossBridgesBloomed &&
        _mutators.applyMossBloom(enhancedByTea: flags.janiceQuestCompleted)) {
      dirty = true;
    }
    if (_mutators.syncRainstormMud(clockNotifier.areDirtPathsMuddy)) {
      dirty = true;
    }
    // Lantern halos glow warmly across Golden Hour, Dusk, Night, and Saturday's Rainstorm!
    final showLanternHalos =
        flags.lanternsLit || _dayNightMetrics.lanternGlowStrength > 0.12;
    if (_groundDecorLayer != null) {
      _groundDecorLayer!.lanternsLit = showLanternHalos;
    }

    if (dirty) {
      _groundDecorLayer?.invalidateAllChunks();
    }
  }

  void _checkWalkoverCollectibles(
    Vector2 pos,
    FestivalClockState clock,
    dynamic settings,
  ) {
    final flags = container.read(worldFlagsProvider);
    // Morning Dew drops in Mellow Meadow (5:00 AM - 8:30 AM)
    if (clock.isMorningDewWindow) {
      for (final (id, dx, dy) in _meadowDewSpots) {
        if (!flags.dewDropsCollected.contains(id)) {
          final dist = math.sqrt(
            math.pow(pos.x - dx, 2) + math.pow(pos.y - dy, 2),
          );
          if (dist < 22.0) {
            container.read(worldFlagsProvider.notifier).collectDewDrop(id);
            final count = flags.dewDropsCollected.length + 1;
            unawaited(
              audioService.playSfx('assets/audio/sfx/sfx_dew_pickup.wav'),
            );
            container.read(uiOverlayProvider.notifier).showToast(
                  '💧 Collected Shimmering Morning Dew ($count/3)!',
                );
          }
        }
      }
    }

    // 8 Hidden 3D-Printed Totems across the 9 zones
    final journal = container.read(journalStateProvider);
    for (final totem in data.totems) {
      if (!journal.collectedTotemIds.contains(totem.id)) {
        final dist = math.sqrt(
          math.pow(pos.x - totem.x, 2) + math.pow(pos.y - totem.y, 2),
        );
        if (dist < 24.0) {
          container.read(journalStateProvider.notifier).collectTotem(totem.id);
          container.read(journalStateProvider.notifier).addItem(totem.name);
          unawaited(
            audioService.playSfx('assets/audio/sfx/sfx_quest_complete.wav'),
          );
          container.read(uiOverlayProvider.notifier).showToast(
                '🗿 Discovered 3D Totem: ${totem.name} (${journal.collectedTotemIds.length + 1}/8)!',
              );
        }
      }
    }
  }

  void _updateInteractionPrompt(Vector2 pos) {
    final clock = container.read(festivalClockProvider);
    if (clock.isDay2BlueberrySharingActive &&
        (_blueberryExperience?.isPlayerNearBasket(pos) ?? false)) {
      container
          .read(uiOverlayProvider.notifier)
          .setNearbyPrompt('Share Electric Purple Blueberries [E]');
      return;
    }

    final npcHit = _nearestNpcWithDist(pos, maxRadius: 42.0);
    final objHit = _nearestInteractableWithDist(pos, maxRadius: 42.0);

    if (npcHit != null &&
        (objHit == null || _npcBeatsObject(pos, npcHit.$2, objHit.$1))) {
      container
          .read(uiOverlayProvider.notifier)
          .setNearbyPrompt('Talk to ${npcHit.$1.spec.name} [E]');
      return;
    }
    if (objHit != null) {
      final obj = objHit.$1;
      final label = switch (obj.name) {
        'tent_rest_spot' => 'Rest / Save at Personal Tent [E]',
        'turntable_spot' => 'Spin Campground Double-LP Turntable [E]',
        'falafel_stand' => 'Inspect Falafel Stand Counter [E]',
        'old_oak_roots' => 'Inspect Old Oak Roots [E]',
        'high_branch_ladder' => 'Climb High-Branch Booth Ladder [E]',
        'vocal_tea_vine' => 'Steep Aged-Grapevine Vocal Tea [E]',
        'resonator_nw' ||
        'resonator_ne' ||
        'resonator_se' =>
          'Tune Meteoric Space-Glass Resonator [E]',
        'meadow_blessing_stone' => 'Meadow Acoustic Blessing Stone [E]',
        'don_shello_buried_stash' => 'Inspect Orchard Root Coordinates [E]',
        'tea_light_altar' => 'Meditate at Sacred Tea-Light Altar [E]',
        'pinball_cabinet' => 'Play Pinball Wizard (Optical Sorter) [E]',
        'sorting_belt_console' => 'Play Sorting Belt Blues [E]',
        'artifact_booth' => 'Inspect Vintage Vinyl & 3D Totem Booth [E]',
        _ => 'Inspect Sound Terminal [E]',
      };
      container.read(uiOverlayProvider.notifier).setNearbyPrompt(label);
      return;
    }
    container.read(uiOverlayProvider.notifier).setNearbyPrompt(null);
  }

  bool _npcBeatsObject(Vector2 pos, double npcDist, MapObjectZone obj) {
    final cx = obj.rect.center.dx - pos.x;
    final cy = obj.rect.center.dy - pos.y;
    final objCenterDist = math.sqrt(cx * cx + cy * cy);
    return npcDist <= objCenterDist;
  }

  (NpcActor, double)? _nearestNpcWithDist(
    Vector2 pos, {
    required double maxRadius,
  }) {
    NpcActor? best;
    var bestDist = maxRadius;
    for (final actor in _npcActors) {
      final d = actor.position.distanceTo(pos);
      if (d < bestDist) {
        bestDist = d;
        best = actor;
      }
    }
    return best == null ? null : (best, bestDist);
  }

  (MapObjectZone, double)? _nearestInteractableWithDist(
    Vector2 pos, {
    required double maxRadius,
  }) {
    MapObjectZone? best;
    var bestDist = maxRadius;
    for (final obj in mapData.interactables) {
      final clampedX = pos.x.clamp(obj.rect.left, obj.rect.right);
      final clampedY = pos.y.clamp(obj.rect.top, obj.rect.bottom);
      final dx = clampedX - pos.x;
      final dy = clampedY - pos.y;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < bestDist) {
        bestDist = d;
        best = obj;
      }
    }
    return best == null ? null : (best, bestDist);
  }

  /// Primary contextual "[E] / A-Button / Tap" handler for dialogues, quests, and mini-games.
  void handleInteract() {
    final overlayNotifier = container.read(uiOverlayProvider.notifier);
    final overlay = container.read(uiOverlayProvider);

    if (overlay.dialogue != null) {
      final closed = overlayNotifier.advanceOrCloseDialogue();
      if (!closed) {
        _playVoiceBark(overlay.dialogue!.voicePitch);
      }
      return;
    }
    if (overlay.modal != ActiveModalOverlay.none) return;

    final p = player;
    if (p == null) return;

    final clock = container.read(festivalClockProvider);
    if (clock.isDay2BlueberrySharingActive &&
        (_blueberryExperience?.isPlayerNearBasket(p.position) ?? false)) {
      triggerEatElectricBlueberries();
      return;
    }

    final npcHit = _nearestNpcWithDist(p.position, maxRadius: 44.0);
    final objHit = _nearestInteractableWithDist(p.position, maxRadius: 44.0);

    if (npcHit != null &&
        (objHit == null || _npcBeatsObject(p.position, npcHit.$2, objHit.$1))) {
      _interactWithNpc(npcHit.$1.spec);
      return;
    }

    if (objHit != null) {
      _interactWithWorldObject(objHit.$1);
    }
  }

  void _playVoiceBark(String pitch) {
    final sfx = switch (pitch) {
      'low' => 'assets/audio/sfx/sfx_bark_low.wav',
      'high' => 'assets/audio/sfx/sfx_bark_high.wav',
      _ => 'assets/audio/sfx/sfx_bark_mid.wav',
    };
    unawaited(audioService.playSfx(sfx, volume: 0.42));
  }

  void _completeQuestFanfare(String npcId) {
    container.read(journalStateProvider.notifier).unlockHiddenDetail(npcId);
    unawaited(
      audioService.playSfx('assets/audio/sfx/sfx_quest_complete.wav',
          volume: 0.7),
    );
    unawaited(persistCurrentGameStateFromContainer(container));
  }

  void _interactWithNpc(NpcSpec npc) {
    container.read(journalStateProvider.notifier).markNpcMet(npc.id);
    final flags = container.read(worldFlagsProvider);
    final flagsN = container.read(worldFlagsProvider.notifier);
    final journalN = container.read(journalStateProvider.notifier);
    final profileN = container.read(playerProfileProvider.notifier);
    final clock = container.read(festivalClockProvider);

    List<String> lines = npc.dialogue['default'] ?? [npc.catchphrase];

    switch (npc.id) {
      case 'patchouli_pete':
        if (!flags.fencesDropped) {
          lines = npc.dialogue['before_fences']!;
        } else if (flags.peteInterviewCompleted) {
          lines = npc.dialogue['completed']!;
        } else if (clock.day == 3 || clock.encoreModeUnlocked) {
          lines = npc.dialogue['day3_interview_ready']!;
        } else {
          lines = npc.dialogue['after_fences']!;
        }
        break;

      case 'ziggy_shellshock':
        if (flags.ziggyQuestCompleted) {
          lines = npc.dialogue['completed']!;
        } else if (!flags.ziggyQuestStarted) {
          flagsN.update((s) => s.copyWith(ziggyQuestStarted: true));
          lines = npc.dialogue['intro']!;
        } else if (flags.dewDropsCollected.length >= 3) {
          flagsN.update((s) => s.copyWith(ziggyQuestCompleted: true));
          profileN.unlockWardrobe('heart_specs');
          journalN.addItem('Tangerine Heart Specs');
          _completeQuestFanfare(npc.id);
          lines = npc.dialogue['ready_to_turn_in']!;
        } else {
          lines = npc.dialogue['in_progress']!;
        }
        break;

      case 'barnaby_breezewalker':
        if (flags.breezewalkerQuestCompleted) {
          lines = npc.dialogue['completed']!;
        } else if (!flags.breezewalkerQuestStarted) {
          flagsN.update((s) => s.copyWith(breezewalkerQuestStarted: true));
          lines = npc.dialogue['intro']!;
        } else if (flags.hasWillowPick) {
          flagsN.update((s) => s.copyWith(breezewalkerQuestCompleted: true));
          profileN.unlockWardrobe('willow_shawl');
          journalN.addItem("McGregor's Heartwood Pick");
          _completeQuestFanfare(npc.id);
          lines = npc.dialogue['ready_to_turn_in']!;
        } else {
          lines = npc.dialogue['in_progress']!;
        }
        break;

      case 'burt_baskernut':
        if (flags.burtQuestCompleted) {
          lines = npc.dialogue['completed']!;
        } else if (!flags.burtQuestStarted) {
          flagsN.update((s) => s.copyWith(burtQuestStarted: true));
          lines = npc.dialogue['intro']!;
        } else if (flags.falafelCiderOffered) {
          flagsN.update(
            (s) => s.copyWith(
              burtQuestCompleted: true,
              slowWaveSwayUnlocked: true,
            ),
          );
          profileN.unlockWardrobe('mcgregor_vest');
          journalN.addItem('Fermented Persimmon Cider');
          _completeQuestFanfare(npc.id);
          lines = npc.dialogue['ready_to_turn_in']!;
        } else {
          lines = npc.dialogue['in_progress']!;
        }
        break;

      case 'barnaby_bittershell':
        if (!flags.bittershellMapCompleted) {
          flagsN.update((s) => s.copyWith(bittershellMapCompleted: true));
          journalN.addItem('Subwoofer Peace-Sign Map');
          _completeQuestFanfare(npc.id);
          lines = npc.dialogue['intro']!;
        } else {
          lines = npc.dialogue['completed']!;
        }
        break;

      case 'janice_joeplant':
        if (flags.janiceQuestCompleted) {
          lines = npc.dialogue['completed']!;
        } else if (!flags.janiceQuestStarted) {
          flagsN.update((s) => s.copyWith(janiceQuestStarted: true));
          lines = npc.dialogue['intro']!;
        } else if (flags.hasVocalTea) {
          flagsN.update(
            (s) => s.copyWith(
              janiceQuestCompleted: true,
              mossBridgesBloomed: true,
            ),
          );
          profileN.unlockWardrobe('amethyst_specs');
          journalN.collectVinyl('vinyl_side_b');
          journalN.addItem('Double-LP Side B');
          unawaited(
              audioService.playSfx('assets/audio/sfx/sfx_moss_bloom.wav'));
          _completeQuestFanfare(npc.id);
          lines = npc.dialogue['ready_to_turn_in']!;
        } else {
          lines = npc.dialogue['in_progress']!;
        }
        break;

      case 'cosmo_shellvoy':
        if (flags.cosmoQuestCompleted) {
          lines = npc.dialogue['completed']!;
        } else if (flags.tunedResonators.length >= 3) {
          flagsN.update(
            (s) => s.copyWith(
              cosmoQuestStarted: true,
              cosmoQuestCompleted: true,
            ),
          );
          profileN.unlockWardrobe('star_crystal_specs');
          journalN.collectVinyl('vinyl_bootleg_drupe');
          journalN.addItem('Bootleg 45: Drupe Dimension Drift');
          _completeQuestFanfare(npc.id);
          lines = npc.dialogue['ready_to_turn_in']!;
        } else if (!flags.cosmoQuestStarted) {
          flagsN.update((s) => s.copyWith(cosmoQuestStarted: true));
          lines = npc.dialogue['intro']!;
        } else {
          lines = npc.dialogue['in_progress']!;
        }
        break;

      case 'don_shello':
        if (flags.donShelloQuestCompleted) {
          lines = npc.dialogue['completed']!;
        } else if (!flags.donShelloQuestStarted) {
          flagsN.update((s) => s.copyWith(donShelloQuestStarted: true));
          journalN.addItem("Don Shell-O's 24k Gold Mic");
          lines = npc.dialogue['intro']!;
        } else if (flags.goldMicBlessed && flags.buriedStashUnearthed) {
          flagsN.update((s) => s.copyWith(donShelloQuestCompleted: true));
          profileN.unlockWardrobe('gold_w_vest');
          journalN.collectVinyl('vinyl_bootleg_omega');
          journalN.addItem('Bootleg 45: Shaking of the Branches');
          _completeQuestFanfare(npc.id);
          lines = npc.dialogue['ready_to_turn_in']!;
        } else {
          lines = npc.dialogue['in_progress']!;
        }
        break;

      case 'tula_twigwalker':
        if (flags.tulaQuestCompleted) {
          lines = npc.dialogue['completed']!;
        } else if (flags.teaLightAltared) {
          flagsN.update(
            (s) => s.copyWith(
              tulaQuestStarted: true,
              tulaQuestCompleted: true,
            ),
          );
          profileN.unlockWardrobe('sunset_biolume_shawl');
          journalN.collectVinyl('vinyl_side_c');
          journalN.addItem('Double-LP Side C');
          _completeQuestFanfare(npc.id);
          lines = npc.dialogue['ready_to_turn_in']!;
        } else if (!flags.tulaQuestStarted) {
          flagsN.update((s) => s.copyWith(tulaQuestStarted: true));
          lines = npc.dialogue['intro']!;
        } else {
          lines = npc.dialogue['in_progress']!;
        }
        break;

      case 'jimi_hendshell':
        if (flags.jimiQuestCompleted) {
          lines = npc.dialogue['completed']!;
        } else if (!flags.jimiQuestStarted) {
          flagsN.update((s) => s.copyWith(jimiQuestStarted: true));
          lines = npc.dialogue['intro']!;
        } else if (flags.hasHarmonyMilestoneForJimi) {
          flagsN.update((s) => s.copyWith(jimiQuestCompleted: true));
          profileN.unlockWardrobe('purple_haze_bandana');
          journalN.collectVinyl('vinyl_side_d');
          journalN.addItem('Double-LP Side D');
          _completeQuestFanfare(npc.id);
          lines = npc.dialogue['ready_to_turn_in']!;
        } else {
          lines = npc.dialogue['in_progress']!;
        }
        break;

      case 'joan_baezelnut':
        flagsN.update((s) => s.copyWith(slowWaveSwayUnlocked: true));
        journalN.unlockHiddenDetail(npc.id);
        break;

      default:
        journalN.unlockHiddenDetail(npc.id);
        break;
    }

    _playVoiceBark(npc.voicePitch);
    container.read(uiOverlayProvider.notifier).startDialogue(
          DialogueSession(
            speakerName: npc.name,
            speakerTitle: npc.title,
            portraitAsset: npc.portraitAsset,
            voicePitch: npc.voicePitch,
            lines: lines,
          ),
        );
  }

  void _interactWithWorldObject(MapObjectZone obj) {
    final flags = container.read(worldFlagsProvider);
    final flagsN = container.read(worldFlagsProvider.notifier);
    final journalN = container.read(journalStateProvider.notifier);
    final overlayN = container.read(uiOverlayProvider.notifier);
    final clock = container.read(festivalClockProvider);

    switch (obj.name) {
      case 'tent_rest_spot':
        overlayN.openModal(ActiveModalOverlay.tentRest);
        break;
      case 'turntable_spot':
        overlayN.openModal(ActiveModalOverlay.turntable);
        break;
      case 'pinball_cabinet':
        overlayN.openModal(ActiveModalOverlay.pinball);
        break;
      case 'sorting_belt_console':
        overlayN.openModal(ActiveModalOverlay.sortingBelt);
        break;
      case 'artifact_booth':
        overlayN.openModal(ActiveModalOverlay.artifactBooth);
        break;

      case 'falafel_stand':
        // Quest gating: requires Burt's quest started OR Track 6 truce event!
        if (!flags.burtQuestStarted && !flags.falafelTruceUnlocked) {
          overlayN.showToast(
            'Buzzing blowflies surround the pita counter—chat with Burt Baskernut right beside the stand first!',
          );
          return;
        }
        if (!flags.falafelCiderOffered) {
          flagsN.update((s) => s.copyWith(falafelCiderOffered: true));
          unawaited(
              audioService.playSfx('assets/audio/sfx/sfx_dew_pickup.wav'));
          overlayN.showToast(
            '🍯 Poured sweet Persimmon Cider! Now talk to Burt Baskernut!',
          );
        } else {
          overlayN
              .showToast('Warm tahini falafel & sweet cider—peaceful harmony!');
        }
        break;

      case 'old_oak_roots':
        if (!flags.breezewalkerQuestStarted && !flags.meadowScavengerUnlocked) {
          overlayN.showToast(
            'Ancient roots hum softly... Talk to Barnaby Breeze-Walker in the Mellow Meadow first!',
          );
          return;
        }
        if (!flags.hasWillowPick) {
          flagsN.update((s) => s.copyWith(hasWillowPick: true));
          unawaited(
              audioService.playSfx('assets/audio/sfx/sfx_lute_gmajor.wav'));
          overlayN.showToast(
            "🎸 Found Great Farmer McGregor's Heartwood Pick! Bring it back to Barnaby Breeze-Walker!",
          );
        } else {
          overlayN.showToast(
              'The Old Oak shade smells of clover and warm walnut wood.');
        }
        break;

      case 'vocal_tea_vine':
        if (!flags.janiceQuestStarted) {
          overlayN.showToast(
            'A copper kettle steeping fragrant Aged-Grapevine Vocal Tea for Janice Joeplant!',
          );
          return;
        }
        if (!flags.hasVocalTea) {
          flagsN.update((s) => s.copyWith(hasVocalTea: true));
          journalN.addItem('Aged-Grapevine Vocal Tea');
          unawaited(
              audioService.playSfx('assets/audio/sfx/sfx_dew_pickup.wav'));
          overlayN.showToast(
            '🍵 Filled Janice Joeplant’s Vocal Tea thermos! Bring it to the Velvet Canopy!',
          );
        } else {
          overlayN
              .showToast('You already have Janice’s warm Vocal Tea thermos!');
        }
        break;

      case 'resonator_nw':
      case 'resonator_ne':
      case 'resonator_se':
        flagsN.tuneResonator(obj.name);
        final count = container.read(worldFlagsProvider).tunedResonators.length;
        unawaited(
            audioService.playSfx('assets/audio/sfx/sfx_resonator_hum.wav'));
        overlayN.showToast(
          '🔮 Meteoric Space-Glass Resonator tuned ($count/3)!',
        );
        break;

      case 'meadow_blessing_stone':
        if (!flags.donShelloQuestStarted) {
          overlayN.showToast(
            'An acoustic standing stone that harmonizes with gold microphones—visit Don Shell-O at Urbano Canopy!',
          );
          return;
        }
        flagsN.update((s) => s.copyWith(goldMicBlessed: true));
        unawaited(
            audioService.playSfx('assets/audio/sfx/sfx_resonator_hum.wav'));
        overlayN.showToast(
          '✨ Blessed Don Shell-O’s Gold Mic! Now unearth his buried stash southwest of the Urbano truck!',
        );
        break;

      case 'don_shello_buried_stash':
        if (!flags.goldMicBlessed) {
          overlayN.showToast(
            'Ancient Santurce hand-sign marks the soil... Bless Don Shell-O’s Gold Mic in the Mellow Meadow first!',
          );
          return;
        }
        flagsN.update((s) => s.copyWith(buriedStashUnearthed: true));
        unawaited(
            audioService.playSfx('assets/audio/sfx/sfx_quest_complete.wav'));
        overlayN.showToast(
          '📦 Unearthed Don Shell-O’s Santurce Stash! Return to Don Shell-O!',
        );
        break;

      case 'tea_light_altar':
        if (!(_fogZone?.isSanctumUnlocked ?? true) &&
            !clock.pureVibeMode &&
            !flags.tulaQuestCompleted) {
          overlayN.showToast(
            'Swirling Psych-Rock Fog shrouds the altar—follow Tula’s stereo C-major bells from the Undergrowth entrance!',
          );
          return;
        }
        flagsN.update((s) => s.copyWith(teaLightAltared: true));
        unawaited(audioService.playSfx('assets/audio/sfx/sfx_bell_cmajor.wav'));
        overlayN.showToast(
          '🕯️ Lit a wish in the Sacred Tea-Light Circle! Speak with Tula Twigwalker!',
        );
        break;

      case 'high_branch_ladder':
        if (clock.day < 3 && !clock.encoreModeUnlocked) {
          overlayN.showToast(
            'Patchouli Pete’s High-Branch Booth ladder—return on Day 3 (Sunday) for his backstage vinyl interview!',
          );
          return;
        }
        if (!flags.peteInterviewCompleted) {
          flagsN.update((s) => s.copyWith(peteInterviewCompleted: true));
          journalN.collectVinyl('vinyl_side_a');
          journalN.addItem('Double-LP Side A');
          _completeQuestFanfare('patchouli_pete');
          overlayN.showToast(
            '🎙️ Recorded Day 3 High-Branch Interview with Patchouli Pete & unlocked Double-LP Side A!',
          );
        } else {
          overlayN.showToast(
            'Panoramic view of the entire Free Orchard from Patchouli Pete’s High-Branch Booth!',
          );
        }
        break;

      case 'terminal_velvet_ledge':
      case 'terminal_arcade':
        journalN.collectVinyl('vinyl_side_a');
        unawaited(
            audioService.playSfx('assets/audio/sfx/sfx_resonator_hum.wav'));
        overlayN.showToast(
          '📻 Literally Infinite Terminal: "I think of walnuts... every shell carries a song."',
        );
        break;
    }
  }

  @override
  void render(ui.Canvas canvas) {
    final screenSize =
        canvasSize.x > 1.0 && canvasSize.y > 1.0 ? canvasSize : size;
    final viewport = screenSize.toSize();
    final clock = container.read(festivalClockProvider);
    final flags = container.read(worldFlagsProvider);
    final settings = container.read(settingsProvider);
    final fft = scheduleController.latest.fft;

    final berryActive =
        flags.isBlueberryRainbowActiveAt(clock.day, clock.minuteOfDay) ||
            clock.shaderOverride == 'electric_blueberry';
    final waveAmount =
        (berryActive ? math.max(_blueberryVisualBlend, 1.0) : _blueberryVisualBlend) *
            settings.shaderIntensity;

    // When Electric Purple Blueberries are active (2 sets), warp the entire world
    // geometry in a liquid sinusoidal wave and shift every tile & walnut through ROYGBIV!
    if (waveAmount > 0.01 && viewport.width > 1.0 && viewport.height > 1.0) {
      canvas.save();
      canvas.clipRect(ui.Offset.zero & viewport);
      canvas.transform(
        ShaderPostProcessor.buildLiquidWaveMatrix(
          viewportSize: viewport,
          timeSeconds: _shaderClock,
          intensity: waveAmount,
          bass: fft.bass,
        ),
      );
      canvas.saveLayer(
        ui.Rect.fromLTWH(
          -viewport.width * 0.12,
          -viewport.height * 0.12,
          viewport.width * 1.24,
          viewport.height * 1.24,
        ),
        ui.Paint()
          ..colorFilter = ShaderPostProcessor.buildRainbowHueColorFilter(
            timeSeconds: _shaderClock,
            intensity: waveAmount,
            bass: fft.bass,
          ),
      );
      super.render(canvas);
      canvas.restore();
      canvas.restore();
    } else {
      super.render(canvas);
    }

    // Post-process GLSL Shaders over the viewport.
    final shaderKind = _selectActiveShader(clock, flags);
    _shaders.renderViewportOverlay(
      canvas: canvas,
      viewportSize: viewport,
      kind: shaderKind,
      timeSeconds: _shaderClock,
      intensity: settings.shaderIntensity,
      bass: fft.bass,
      mid: fft.lowMid,
      rainRamp: _dayNightMetrics.rainIntensity,
    );
  }

  OrchardShaderKind _selectActiveShader(
    FestivalClockState clock,
    WorldFlags flags,
  ) {
    final override = clock.shaderOverride;
    if (override != null) {
      switch (override) {
        case 'electric_blueberry':
          return OrchardShaderKind.electricBlueberry;
        case 'walnut_trip':
          return OrchardShaderKind.walnutTrip;
        case 'purple_haze':
          return OrchardShaderKind.purpleHaze;
        case 'nebula':
          return OrchardShaderKind.nebula;
        case 'pre_storm':
          return OrchardShaderKind.preStormOvercast;
        case 'rainstorm':
          return OrchardShaderKind.rainstorm;
        case 'mist':
          return OrchardShaderKind.morningMist;
      }
    }

    if (flags.isBlueberryRainbowActiveAt(clock.day, clock.minuteOfDay)) {
      return OrchardShaderKind.electricBlueberry;
    }

    final p = player;
    if (p != null && mapData.isLowGravityAtWorld(p.position.x, p.position.y)) {
      return OrchardShaderKind.nebula;
    }
    if (flags.walnutTripActive) return OrchardShaderKind.walnutTrip;
    if (flags.purpleDustActive ||
        clock.effectiveWeather == WeatherPhase.purpleDustFinale) {
      return OrchardShaderKind.purpleHaze;
    }
    if (clock.effectiveWeather == WeatherPhase.blightRainstorm) {
      return OrchardShaderKind.rainstorm;
    }
    if (clock.effectiveWeather == WeatherPhase.preStormHumid) {
      return OrchardShaderKind.preStormOvercast;
    }
    if (clock.effectiveWeather == WeatherPhase.postStormMist) {
      return OrchardShaderKind.morningMist;
    }
    return OrchardShaderKind.none;
  }
}

class _CollectiblesRenderComponent extends Component {
  _CollectiblesRenderComponent({
    required this.game,
    super.priority,
  });

  final WalnutstockGame game;

  @override
  void render(ui.Canvas canvas) {
    final clock = game.container.read(festivalClockProvider);
    final flags = game.container.read(worldFlagsProvider);
    final journal = game.container.read(journalStateProvider);
    final metrics = game._dayNightMetrics;
    final paint = ui.Paint()
      ..filterQuality = ui.FilterQuality.none
      ..isAntiAlias = false;

    // Morning Dew drops during dawn window
    if (clock.isMorningDewWindow && game._dewImage != null) {
      final bob = math.sin(game._shaderClock * 4.0) * 2.0;
      for (final (id, dx, dy) in WalnutstockGame._meadowDewSpots) {
        if (!flags.dewDropsCollected.contains(id)) {
          canvas.drawOval(
            ui.Rect.fromCenter(
              center: ui.Offset(dx + metrics.shadowOffset.dx * 0.4, dy + 6.5),
              width: 9.0,
              height: 3.5,
            ),
            ui.Paint()..color = const ui.Color(0x4408120C),
          );
          canvas.drawImage(
            game._dewImage!,
            ui.Offset(dx - 8, dy - 8 + bob),
            paint,
          );
        }
      }
    }

    // Uncollected 3D-Printed Totems across the 9 zones with 3D stone plinth & solar shadow!
    for (final totem in game.data.totems) {
      if (!journal.collectedTotemIds.contains(totem.id)) {
        final img = game._totemImages[totem.id];
        if (img != null) {
          final hover = math.sin(game._shaderClock * 2.6 + totem.x) * 1.6;
          canvas.drawOval(
            ui.Rect.fromCenter(
              center: ui.Offset(
                totem.x + metrics.shadowOffset.dx * 0.6,
                totem.y + 11.0 + metrics.shadowOffset.dy * 0.4,
              ),
              width: 17.0,
              height: 5.5,
            ),
            ui.Paint()
              ..color = ui.Color.fromRGBO(
                8,
                12,
                14,
                metrics.shadowAlpha.clamp(0.16, 0.38),
              ),
          );
          // 3D beveled stone pedestal base
          canvas.drawOval(
            ui.Rect.fromCenter(
              center: ui.Offset(totem.x, totem.y + 10.5),
              width: 16.0,
              height: 5.5,
            ),
            ui.Paint()..color = const ui.Color(0xFF4A4E69),
          );
          final dst = ui.Rect.fromCenter(
            center: ui.Offset(totem.x, totem.y - 1.5 + hover),
            width: 24,
            height: 24,
          );
          canvas.drawImageRect(
            img,
            ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            dst,
            paint,
          );
        }
      }
    }
  }
}
