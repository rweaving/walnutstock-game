import 'dart:async';
import 'dart:math' as math;

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/soloud_audio_service.dart';
import '../../state/providers.dart';

enum WalnutKernelType {
  extraLightHalf(
    id: 'extra_light',
    displayName: 'Extra-Light Golden Half',
    shortName: 'Extra-Light Half',
    visualCue: 'Plump creamy pale-gold butterfly half (Prime Keep Grade)',
    assetPath: 'assets/images/props/kernel_extra_light.png',
    badgeColor: Color(0xFFF3D599),
    isDefectByDefault: false,
  ),
  lightAmberHalf(
    id: 'light_amber',
    displayName: 'Honey-Amber Half',
    shortName: 'Honey-Amber',
    visualCue: 'Warm toasted caramel-amber butterfly half',
    assetPath: 'assets/images/props/kernel_light_amber.png',
    badgeColor: Color(0xFFE09F3E),
    isDefectByDefault: false,
  ),
  darkShrivel(
    id: 'dark_shrivel',
    displayName: 'Dark Shriveled Blight',
    shortName: 'Dark Shrivel',
    visualCue: 'Deeply wrinkled espresso-black shriveled lobes',
    assetPath: 'assets/images/props/kernel_dark_shrivel.png',
    badgeColor: Color(0xFF9E6B55),
    isDefectByDefault: true,
  ),
  shellStuck(
    id: 'shell_stuck',
    displayName: 'Shell-Stuck Fragment',
    shortName: 'Shell Fragment',
    visualCue: 'Jagged hard woody outer shell & septum wedged on nutmeat',
    assetPath: 'assets/images/props/kernel_shell_stuck.png',
    badgeColor: Color(0xFFD4A373),
    isDefectByDefault: true,
  ),
  moldSpotted(
    id: 'mold_spotted',
    displayName: 'Mold-Spotted Kernel',
    shortName: 'Mold-Spotted',
    visualCue: 'Dull grey-tan half with fuzzy white & blue-grey mold',
    assetPath: 'assets/images/props/kernel_mold_spotted.png',
    badgeColor: Color(0xFF90E0EF),
    isDefectByDefault: true,
  ),
  insectScorched(
    id: 'insect_scorched',
    displayName: 'Scorched & Pinhole Kernel',
    shortName: 'Scorched Pinhole',
    visualCue: 'Charred dark tip-burn edge with tiny dark pinhole bores',
    assetPath: 'assets/images/props/kernel_insect_scorched.png',
    badgeColor: Color(0xFFFF758F),
    isDefectByDefault: true,
  );

  const WalnutKernelType({
    required this.id,
    required this.displayName,
    required this.shortName,
    required this.visualCue,
    required this.assetPath,
    required this.badgeColor,
    required this.isDefectByDefault,
  });

  final String id;
  final String displayName;
  final String shortName;
  final String visualCue;
  final String assetPath;
  final Color badgeColor;
  final bool isDefectByDefault;

  static const List<WalnutKernelType> removalRotation = <WalnutKernelType>[
    WalnutKernelType.darkShrivel,
    WalnutKernelType.shellStuck,
    WalnutKernelType.moldSpotted,
    WalnutKernelType.insectScorched,
    WalnutKernelType.lightAmberHalf,
  ];
}

enum BeltClickResult {
  removedTarget,
  wrongKernelType,
  missedEmpty,
}

class BeltKernelItem {
  BeltKernelItem({
    required this.id,
    required this.type,
    required this.progress,
    required this.crossPos,
    required this.rotationRad,
    required this.scale,
  });

  final int id;
  final WalnutKernelType type;

  /// Horizontal progress across the single belt (`0.0` left infeed -> `1.0` right hopper).
  double progress;

  /// Vertical position across the single belt's width (`0.16` top edge .. `0.84` bottom edge).
  final double crossPos;

  final double rotationRad;
  final double scale;
  bool removed = false;
  double wrongShakeTimer = 0.0;
}

class BeltFeedbackBurst {
  BeltFeedbackBurst({
    required this.progress,
    required this.crossPos,
    required this.label,
    required this.color,
  });

  final double progress;
  final double crossPos;
  final String label;
  final Color color;
  double age = 0.0;
  static const double maxAge = 0.85;
}

class SortingBeltSimulation {
  SortingBeltSimulation({this.autoGroove = false}) {
    // Seed 3 initial spaced kernels on the single belt so the belt looks alive right away!
    _spawnSpecific(progress: 0.14, forceTarget: false);
    _spawnSpecific(progress: 0.34, forceTarget: true);
    _spawnSpecific(progress: 0.54, forceTarget: false);
  }

  static const int removalsPerShift = 6;

  bool autoGroove;
  int score = 0;
  int streak = 0;
  int removedTotal = 0;
  int shiftRemovals = 0;
  int shiftNumber = 1;
  int _rotationIndex = 0;

  double beltScrollPhase = 0.0;
  double _spawnTimer = 0.42;
  int _nextId = 1;
  int _targetGuaranteeCounter = 0;
  final math.Random _rng = math.Random(1969);

  String inspectorCallout =
      'INSPECT THE SINGLE BELT: CLICK ALL DARK SHRIVELED KERNELS TO REMOVE!';
  double shiftBannerTimer = 0.0;

  final List<BeltKernelItem> items = <BeltKernelItem>[];
  final List<BeltFeedbackBurst> bursts = <BeltFeedbackBurst>[];

  WalnutKernelType get targetToRemove =>
      WalnutKernelType.removalRotation[
          _rotationIndex % WalnutKernelType.removalRotation.length];

  void rotateTargetOrder() {
    _rotationIndex =
        (_rotationIndex + 1) % WalnutKernelType.removalRotation.length;
    shiftRemovals = 0;
    shiftNumber++;
    shiftBannerTimer = 2.6;
    inspectorCallout =
        'SHIFT #$shiftNumber ORDER: CLICK ALL ${targetToRemove.displayName.toUpperCase()}S!';
  }

  void _spawnSpecific({required double progress, required bool forceTarget}) {
    final chosen = forceTarget ? targetToRemove : _pickNonTargetType();
    final crossSlots = <double>[0.22, 0.38, 0.52, 0.66, 0.80];
    var bestCross = crossSlots[_nextId % crossSlots.length];
    // Pick a vertical slot across the single wide belt furthest from nearby kernels
    var bestClearance = -1.0;
    for (final slot in crossSlots) {
      var minDist = 999.0;
      for (final existing in items) {
        final dx = (existing.progress - progress) * 2.4;
        final dy = existing.crossPos - slot;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d < minDist) minDist = d;
      }
      if (minDist > bestClearance) {
        bestClearance = minDist;
        bestCross = slot;
      }
    }
    final jitter = (_rng.nextDouble() - 0.5) * 0.06;
    items.add(
      BeltKernelItem(
        id: _nextId++,
        type: chosen,
        progress: progress,
        crossPos: (bestCross + jitter).clamp(0.17, 0.83),
        rotationRad: (_rng.nextDouble() - 0.5) * 0.95,
        scale: 0.94 + _rng.nextDouble() * 0.14,
      ),
    );
  }

  WalnutKernelType _pickNextKernelType() {
    // Guarantee at least ~42% target kernels so the player always has satisfying clicks!
    _targetGuaranteeCounter++;
    if (_targetGuaranteeCounter >= 3 || _rng.nextDouble() < 0.42) {
      _targetGuaranteeCounter = 0;
      return targetToRemove;
    }
    return _pickNonTargetType();
  }

  WalnutKernelType _pickNonTargetType() {
    final r = _rng.nextDouble();
    if (r < 0.52 && targetToRemove != WalnutKernelType.extraLightHalf) {
      return WalnutKernelType.extraLightHalf;
    }
    if (r < 0.78 && targetToRemove != WalnutKernelType.lightAmberHalf) {
      return WalnutKernelType.lightAmberHalf;
    }
    final others = WalnutKernelType.values
        .where((t) => t != targetToRemove)
        .toList(growable: false);
    return others[_rng.nextInt(others.length)];
  }

  /// Advances the single conveyor belt by `dt` seconds. Returns `true` when score increases.
  bool step(double dt) {
    if (dt <= 0.0) return false;
    var scoredAny = false;
    final beltSpeed = 0.165; // ~6 seconds across the wide inspection table

    beltScrollPhase = (beltScrollPhase + dt * beltSpeed) % 1.0;
    shiftBannerTimer = math.max(0.0, shiftBannerTimer - dt);

    for (final b in bursts) {
      b.age += dt;
    }
    bursts.removeWhere((b) => b.age >= BeltFeedbackBurst.maxAge);

    _spawnTimer -= dt;
    if (_spawnTimer <= 0.0 && items.length < 13) {
      _spawnTimer = 0.54 + _rng.nextDouble() * 0.18;
      final nextType = _pickNextKernelType();
      _spawnWithType(nextType);
    }

    for (final item in items) {
      item.progress += dt * beltSpeed;
      if (item.wrongShakeTimer > 0.0) {
        item.wrongShakeTimer = math.max(0.0, item.wrongShakeTimer - dt);
      }

      // Auto-Groove optical air-jet removes required target kernels automatically at scanner line
      if (autoGroove &&
          !item.removed &&
          item.type == targetToRemove &&
          item.progress >= 0.66 &&
          item.progress <= 0.88) {
        _completeRemoval(item, isAuto: true);
        scoredAny = true;
      }

      // End of single belt (Prime Harvest Hopper at right edge)
      if (!item.removed && item.progress > 1.02) {
        if (item.type == targetToRemove) {
          if (!autoGroove) {
            streak = 0;
            inspectorCallout =
                'MISSED A ${targetToRemove.shortName.toUpperCase()}! WATCH THE RIGHT END OF THE BELT!';
            bursts.add(
              BeltFeedbackBurst(
                progress: 0.95,
                crossPos: item.crossPos,
                label: 'MISSED!',
                color: const Color(0xFFFF595E),
              ),
            );
          }
        } else {
          // Good / non-target kernel safely entered Prime Harvest Hopper!
          score += 30;
          scoredAny = true;
        }
      }
    }

    items.removeWhere((i) => i.removed || i.progress > 1.02);
    return scoredAny;
  }

  void _spawnWithType(WalnutKernelType type) {
    const slots = <double>[0.20, 0.35, 0.50, 0.65, 0.80];
    var bestSlot = slots[_nextId % slots.length];
    var bestDist = -1.0;
    for (final s in slots) {
      var nearest = 999.0;
      for (final other in items) {
        if (other.progress > 0.32) continue;
        final dx = other.progress * 2.5;
        final dy = other.crossPos - s;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d < nearest) nearest = d;
      }
      if (nearest > bestDist) {
        bestDist = nearest;
        bestSlot = s;
      }
    }
    items.add(
      BeltKernelItem(
        id: _nextId++,
        type: type,
        progress: -0.04,
        crossPos: (bestSlot + (_rng.nextDouble() - 0.5) * 0.06).clamp(0.16, 0.84),
        rotationRad: (_rng.nextDouble() - 0.5) * 1.1,
        scale: 0.94 + _rng.nextDouble() * 0.14,
      ),
    );
  }

  void _completeRemoval(BeltKernelItem item, {required bool isAuto}) {
    item.removed = true;
    streak++;
    removedTotal++;
    shiftRemovals++;
    final pts = (isAuto ? 120 : 150) + streak * 20;
    score += pts;

    bursts.add(
      BeltFeedbackBurst(
        progress: item.progress.clamp(0.06, 0.94),
        crossPos: item.crossPos,
        label: '+$pts REMOVED!',
        color: const Color(0xFF80FFDB),
      ),
    );

    if (shiftRemovals >= removalsPerShift) {
      final shiftBonus = 400;
      score += shiftBonus;
      rotateTargetOrder();
      bursts.add(
        BeltFeedbackBurst(
          progress: 0.50,
          crossPos: 0.25,
          label: 'SHIFT CLEAR +$shiftBonus!',
          color: const Color(0xFFFFBE0B),
        ),
      );
    } else {
      inspectorCallout =
          'GREAT EYE! REMOVED ${item.type.shortName.toUpperCase()} ($shiftRemovals/$removalsPerShift IN BATCH)';
    }
  }

  /// Directly clicks a specific walnut kernel on the single conveyor belt.
  BeltClickResult clickItem(int itemId) {
    for (final item in items) {
      if (!item.removed && item.id == itemId) {
        if (item.type == targetToRemove) {
          _completeRemoval(item, isAuto: false);
          items.removeWhere((i) => i.removed);
          return BeltClickResult.removedTarget;
        } else {
          streak = 0;
          item.wrongShakeTimer = 0.38;
          inspectorCallout =
              'LEAVE ${item.type.shortName.toUpperCase()} ON BELT! ONLY REMOVE ${targetToRemove.shortName.toUpperCase()}!';
          bursts.add(
            BeltFeedbackBurst(
              progress: item.progress.clamp(0.06, 0.94),
              crossPos: item.crossPos,
              label: 'KEEP ON BELT!',
              color: const Color(0xFFFFB703),
            ),
          );
          return BeltClickResult.wrongKernelType;
        }
      }
    }
    return BeltClickResult.missedEmpty;
  }

  /// Accessibility / keyboard action (`Space` / `Enter`): zaps the furthest-right matching target kernel.
  BeltClickResult zapNearestTargetKernel() {
    BeltKernelItem? candidate;
    for (final item in items) {
      if (!item.removed &&
          item.type == targetToRemove &&
          item.progress >= 0.02 &&
          item.progress <= 0.98) {
        if (candidate == null || item.progress > candidate.progress) {
          candidate = item;
        }
      }
    }
    if (candidate != null) {
      return clickItem(candidate.id);
    }
    return BeltClickResult.missedEmpty;
  }
}

class SortingBeltBluesOverlay extends ConsumerStatefulWidget {
  const SortingBeltBluesOverlay({
    super.key,
    required this.audio,
  });

  final SoloudAudioService audio;

  @override
  ConsumerState<SortingBeltBluesOverlay> createState() =>
      _SortingBeltBluesOverlayState();
}

class _SortingBeltBluesOverlayState
    extends ConsumerState<SortingBeltBluesOverlay>
    with SingleTickerProviderStateMixin {
  late final SortingBeltSimulation _sim;
  late final Ticker _ticker;
  final FocusNode _focusNode = FocusNode(debugLabel: 'SortingBeltBluesFocus');
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    final pureVibe = ref.read(festivalClockProvider).pureVibeMode;
    _sim = SortingBeltSimulation(autoGroove: pureVibe);
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
    _ticker = createTicker((elapsed) {
      final dt = _last == Duration.zero
          ? 0.016
          : (elapsed - _last).inMicroseconds / 1000000.0;
      _last = elapsed;
      if (_sim.step(dt.clamp(0.0, 0.05))) {
        ref
            .read(worldFlagsProvider.notifier)
            .recordSortingBeltScore(_sim.score);
      }
      if (mounted) setState(() {});
    })
      ..start();
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.escape) {
      _closeModal();
      return true;
    }
    if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.enter) {
      _handleClickResult(_sim.zapNearestTargetKernel());
      return true;
    }
    if (k == LogicalKeyboardKey.keyR) {
      setState(() => _sim.rotateTargetOrder());
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onKernelClicked(int itemId) {
    _focusNode.requestFocus();
    _handleClickResult(_sim.clickItem(itemId));
  }

  void _onBeltSurfaceClicked(Offset localPos, Size beltSize) {
    _focusNode.requestFocus();
    if (beltSize.width <= 1 || beltSize.height <= 1) return;

    BeltKernelItem? closest;
    var bestDist = 48.0; // Forgiving click radius around moving kernels!
    for (final item in _sim.items) {
      if (item.removed) continue;
      final cx = item.progress * beltSize.width;
      final cy = item.crossPos * beltSize.height;
      final d = (Offset(cx, cy) - localPos).distance;
      if (d < bestDist) {
        bestDist = d;
        closest = item;
      }
    }
    if (closest != null) {
      _handleClickResult(_sim.clickItem(closest.id));
    }
  }

  void _handleClickResult(BeltClickResult res) {
    if (res == BeltClickResult.removedTarget) {
      unawaited(
        widget.audio.playSfx(
          'assets/audio/sfx/sfx_pinball_bumper.wav',
          volume: 0.42,
        ),
      );
      ref.read(worldFlagsProvider.notifier).recordSortingBeltScore(_sim.score);
    } else if (res == BeltClickResult.wrongKernelType) {
      unawaited(
        widget.audio.playSfx(
          'assets/audio/sfx/sfx_pinball_flipper.wav',
          volume: 0.30,
        ),
      );
    }
    if (mounted) setState(() {});
  }

  void _closeModal() {
    ref.read(worldFlagsProvider.notifier).recordSortingBeltScore(_sim.score);
    if (_sim.score > 0) {
      final beads = (_sim.score ~/ 30).clamp(1, 8);
      ref.read(journalStateProvider.notifier).addPeaceBeads(beads);
      ref.read(uiOverlayProvider.notifier).showToast(
            '🌰 Kernel Sorter Score ${_sim.score}! Earned +$beads Peace Beads!',
          );
    }
    ref.read(uiOverlayProvider.notifier).closeModal();
  }

  @override
  Widget build(BuildContext context) {
    final best = math.max(
      ref.watch(worldFlagsProvider).sortingBeltHighScore,
      _sim.score,
    );
    final screen = MediaQuery.sizeOf(context);
    final availW = math.max(260.0, screen.width - 16.0);
    final availH = math.max(240.0, screen.height - 16.0);
    final modalW = math.min(900.0, availW);
    final modalH = math.min(600.0, availH);
    final isCompact = modalW < 620.0 || modalH < 500.0;
    final stackBanner = modalW < 560.0;
    final target = _sim.targetToRemove;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      child: Center(
        child: Container(
          key: const ValueKey('sorting_belt_blues_modal'),
          width: modalW,
          height: modalH,
          padding: EdgeInsets.all(isCompact ? 10 : 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0xFA1B1E28),
                Color(0xFA12141C),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF4CC9F0), width: 2.4),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Colors.black87, blurRadius: 28),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // 1. Top Header Bar
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        '🌰 SORTING BELT BLUES · QUALITY INSPECTION LINE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF80FFDB),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    FilterChip(
                      key: const ValueKey('sorting_belt_autogroove_toggle'),
                      visualDensity: VisualDensity.compact,
                      label: const Text(
                        'Auto-Groove',
                        style: TextStyle(fontSize: 11),
                      ),
                      selected: _sim.autoGroove,
                      selectedColor: const Color(0xFF52B788),
                      onSelected: (v) => setState(() => _sim.autoGroove = v),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      key: const ValueKey('close_sorting_belt_button'),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, color: Color(0xFFF4E3C1)),
                      onPressed: _closeModal,
                    ),
                  ],
                ),
                SizedBox(height: isCompact ? 4 : 8),

                // 2. Prominent "REQUIRED TO REMOVE" Reference Photo Order Panel
                _buildTargetOrderBanner(target, best, isCompact, stackBanner),
                SizedBox(height: isCompact ? 6 : 10),

                // 3. Wide Panoramic Single Industrial Conveyor Belt with Realistic Walnut Kernels!
                Expanded(
                  child: _buildSingleConveyorBelt(isCompact),
                ),
                SizedBox(height: isCompact ? 5 : 8),

                // 4. Bottom Inspector Status & Reference Legend
                _buildBottomInspectorFooter(isCompact),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTargetOrderBanner(
    WalnutKernelType target,
    int best,
    bool isCompact,
    bool stackBanner,
  ) {
    final photoSize = isCompact ? 48.0 : 68.0;
    final photoBox = Container(
      width: photoSize,
      height: photoSize,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF14171F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF595E), width: 2),
      ),
      child: _KernelPhotoSprite(type: target),
    );

    final orderDetails = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE63946),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'CLICK TO REMOVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Text(
                target.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFFFFF8E7),
                  fontWeight: FontWeight.w900,
                  fontSize: isCompact ? 13 : 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            target.visualCue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFD9C5A0),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _sim.shiftRemovals /
                        SortingBeltSimulation.removalsPerShift,
                    minHeight: 6,
                    backgroundColor: const Color(0xFF343A40),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF06D6A0),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Batch ${_sim.shiftRemovals}/${SortingBeltSimulation.removalsPerShift}',
                style: const TextStyle(
                  color: Color(0xFF80FFDB),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final nextOrderButton = InkWell(
      key: const ValueKey('sorting_switch_target_button'),
      onTap: () => setState(() => _sim.rotateTargetOrder()),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF2B303C),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF4CC9F0)),
        ),
        child: const Text(
          'Next Order [R]',
          style: TextStyle(
            color: Color(0xFF90E0EF),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    return Container(
      key: const ValueKey('sorting_belt_target_card'),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 14,
        vertical: isCompact ? 6 : 10,
      ),
      decoration: BoxDecoration(
        color: _sim.shiftBannerTimer > 0
            ? const Color(0xFF3D1A28)
            : const Color(0xFF231C18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _sim.shiftBannerTimer > 0
              ? const Color(0xFFFF006E)
              : const Color(0xFFFFBE0B),
          width: 2.0,
        ),
      ),
      child: stackBanner
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    photoBox,
                    const SizedBox(width: 10),
                    orderDetails,
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        'SCORE: ${_sim.score} · x${_sim.streak} · BEST: $best',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF80FFDB),
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    nextOrderButton,
                  ],
                ),
              ],
            )
          : Row(
              children: <Widget>[
                photoBox,
                const SizedBox(width: 12),
                orderDetails,
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'SCORE: ${_sim.score}',
                      style: const TextStyle(
                        color: Color(0xFF80FFDB),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'STREAK: x${_sim.streak} · BEST: $best',
                      style: const TextStyle(
                        color: Color(0xFFFFD166),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    nextOrderButton,
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildSingleConveyorBelt(bool isCompact) {
    final kernelBaseSize = isCompact ? 54.0 : 74.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final beltSize = Size(constraints.maxWidth, constraints.maxHeight);
        return Listener(
          key: const ValueKey('sorting_single_belt_surface'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (ev) =>
              _onBeltSurfaceClicked(ev.localPosition, beltSize),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: <Widget>[
                // Animated Industrial Single Food-Grade Conveyor Belt Canvas
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SingleConveyorBeltPainter(
                      scrollPhase: _sim.beltScrollPhase,
                      autoGroove: _sim.autoGroove,
                    ),
                  ),
                ),

                // Left Infeed Hopper & Right Prime Harvest Bin Labels
                Positioned(
                  left: 10,
                  top: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xCC14171F),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF6C757D)),
                    ),
                    child: const Text(
                      'INFEED HOPPER ▶',
                      style: TextStyle(
                        color: Color(0xFFCED4DA),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xCC0D2818),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF52B788)),
                    ),
                    child: const Text(
                      '▶ PRIME HARVEST BIN',
                      style: TextStyle(
                        color: Color(0xFF95D5B2),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Realistic Walnut Kernel Photos Riding Along the Single Belt!
                for (final item in _sim.items)
                  Builder(
                    builder: (context) {
                      final size = kernelBaseSize * item.scale;
                      final shakeX = item.wrongShakeTimer > 0
                          ? math.sin(item.wrongShakeTimer * 55.0) * 6.0
                          : 0.0;
                      final left =
                          item.progress * beltSize.width - size * 0.5 + shakeX;
                      final top =
                          item.crossPos * beltSize.height - size * 0.5;
                      return Positioned(
                        left: left,
                        top: top,
                        width: size,
                        height: size,
                        child: Listener(
                          key: ValueKey('belt_kernel_${item.id}'),
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (_) => _onKernelClicked(item.id),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Transform.rotate(
                              angle: item.rotationRad,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: const <BoxShadow>[
                                    BoxShadow(
                                      color: Color(0x9906080C),
                                      blurRadius: 8,
                                      offset: Offset(3, 5),
                                    ),
                                  ],
                                  border: item.wrongShakeTimer > 0
                                      ? Border.all(
                                          color: const Color(0xFFFFB703),
                                          width: 2.5,
                                        )
                                      : null,
                                ),
                                child: _KernelPhotoSprite(type: item.type),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                // Floating Pneumatic Removal Popups
                for (final b in _sim.bursts)
                  Positioned(
                    left: (b.progress * beltSize.width - 64.0)
                        .clamp(4.0, math.max(4.0, beltSize.width - 132.0)),
                    top: (b.crossPos * beltSize.height -
                            14.0 -
                            (b.age / BeltFeedbackBurst.maxAge) * 26.0)
                        .clamp(4.0, math.max(4.0, beltSize.height - 28.0)),
                    width: 128,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity:
                            (1.0 - b.age / BeltFeedbackBurst.maxAge).clamp(0.0, 1.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xDD10141D),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: b.color),
                          ),
                          child: Text(
                            b.label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: b.color,
                              fontWeight: FontWeight.w900,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomInspectorFooter(bool isCompact) {
    final keepGrades = WalnutKernelType.values
        .where((t) => t != _sim.targetToRemove)
        .take(isCompact ? 2 : 4)
        .toList(growable: false);

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            _sim.inspectorCallout,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFF4E3C1),
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ),
        if (!isCompact) ...<Widget>[
          const SizedBox(width: 10),
          const Text(
            'KEEP ON BELT:',
            style: TextStyle(
              color: Color(0xFF95D5B2),
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 6),
          for (final g in keepGrades)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Tooltip(
                message: 'Keep: ${g.displayName}',
                child: Container(
                  width: 28,
                  height: 28,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F2B),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF52B788)),
                  ),
                  child: _KernelPhotoSprite(type: g),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _KernelPhotoSprite extends StatelessWidget {
  const _KernelPhotoSprite({required this.type});
  final WalnutKernelType type;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      type.assetPath,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, _, __) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: type.badgeColor,
          ),
        );
      },
    );
  }
}

class _SingleConveyorBeltPainter extends CustomPainter {
  const _SingleConveyorBeltPainter({
    required this.scrollPhase,
    required this.autoGroove,
  });

  final double scrollPhase;
  final bool autoGroove;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Top & bottom stainless steel conveyor guardrails
    const railH = 18.0;
    canvas.drawRect(
      rect,
      Paint()..color = const Color(0xFF222733),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, railH),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF6C757D), Color(0xFF343A40)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, railH)),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - railH, size.width, railH),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF343A40), Color(0xFF6C757D)],
        ).createShader(
            Rect.fromLTWH(0, size.height - railH, size.width, railH)),
    );

    // Wide single food-grade nitrile inspection belt surface
    final beltRect =
        Rect.fromLTWH(0, railH, size.width, math.max(10.0, size.height - railH * 2));
    canvas.drawRect(
      beltRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF1F2A32),
            Color(0xFF2B3A44),
            Color(0xFF26343D),
            Color(0xFF1B242B),
          ],
          stops: <double>[0.0, 0.25, 0.75, 1.0],
        ).createShader(beltRect),
    );

    // Scrolling vulcanized belt cleats & subtle woven texture lines
    const slatSpacing = 54.0;
    final offset = scrollPhase * slatSpacing;
    final cleatDark = Paint()
      ..color = const Color(0x5510171D)
      ..strokeWidth = 2.4;
    final cleatHighlight = Paint()
      ..color = const Color(0x33637E90)
      ..strokeWidth = 1.2;

    for (var x = (offset % slatSpacing) - slatSpacing;
        x < size.width + slatSpacing;
        x += slatSpacing) {
      canvas.drawLine(
        Offset(x, beltRect.top + 2),
        Offset(x, beltRect.bottom - 2),
        cleatDark,
      );
      canvas.drawLine(
        Offset(x + 2.0, beltRect.top + 2),
        Offset(x + 2.0, beltRect.bottom - 2),
        cleatHighlight,
      );
    }

    // Subtle directional chevrons along belt centerline
    final chevPaint = Paint()
      ..color = const Color(0x2280FFDB)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final midY = beltRect.center.dy;
    for (var x = (offset % slatSpacing);
        x < size.width;
        x += slatSpacing * 2) {
      final p = Path()
        ..moveTo(x - 8, midY - 12)
        ..lineTo(x + 6, midY)
        ..lineTo(x - 8, midY + 12);
      canvas.drawPath(p, chevPaint);
    }

    // Warm overhead inspection lamp illumination wash across center table
    canvas.drawRect(
      beltRect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment.center,
          radius: 0.78,
          colors: <Color>[
            Color(0x1EFFF8E7),
            Color(0x00000000),
          ],
        ).createShader(beltRect),
    );

    // Right-end emerald Prime Harvest Chute glow
    canvas.drawRect(
      Rect.fromLTWH(size.width - 28, beltRect.top, 28, beltRect.height),
      Paint()
        ..shader = const LinearGradient(
          colors: <Color>[
            Color(0x0006D6A0),
            Color(0x4406D6A0),
          ],
        ).createShader(
            Rect.fromLTWH(size.width - 28, beltRect.top, 28, beltRect.height)),
    );

    // Optional Auto-Groove optical laser line at 72% belt progress
    if (autoGroove) {
      final lx = size.width * 0.72;
      canvas.drawLine(
        Offset(lx, beltRect.top),
        Offset(lx, beltRect.bottom),
        Paint()
          ..color = const Color(0xAA06D6A0)
          ..strokeWidth = 2.2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SingleConveyorBeltPainter oldDelegate) =>
      oldDelegate.scrollPhase != scrollPhase ||
      oldDelegate.autoGroove != autoGroove;
}
