import 'dart:async';
import 'dart:math' as math;

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/walnutstock_game.dart';
import '../game/world/orchard_gate_component.dart';
import '../state/dialogue_and_overlay_state.dart';
import '../state/providers.dart';

/// Minimal mobile-first HUD keeping **85–90%+** of the viewport open for exploration & live music:
/// - **Single Slim "Pocket Program" Top Pill (`~36px` visual height inside `SafeArea`)**
///   with animated EQ bars + current Stage/Track (or Area) + Festival Day.
/// - **Celebratory `2.5s` Slide-Down Toast Banner** on cultivar discoveries & set changes.
/// - **Diegetic Orchard Gate World Badges (`>=48x48px`)** over the flanking Lineup Kiosk & Cultivar Booth.
/// - **Context-Only World-Space Interaction Bubble (`>=48x48px`)** directly above in-range NPCs, trees, & booths.
/// - **"Concert Vibe Mode" `2.5s` Auto-Hide** fading non-essential chrome inside active stage zones.
class WristbandHud extends ConsumerStatefulWidget {
  const WristbandHud({
    super.key,
    required this.game,
    this.userActivityListenable,
  });

  final WalnutstockGame game;
  final ValueNotifier<int>? userActivityListenable;

  @override
  ConsumerState<WristbandHud> createState() => _WristbandHudState();
}

class _WristbandHudState extends ConsumerState<WristbandHud>
    with SingleTickerProviderStateMixin {
  static const int _vibeIdleThresholdMs = 2500;
  static const int _pollIntervalMs = 200;
  static const Duration _toastDisplayDuration = Duration(milliseconds: 2500);

  late final AnimationController _hudPulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  Timer? _idlePollTimer;
  Timer? _toastAutoClearTimer;
  int _lastObservedToastSerial = -1;

  int _idleElapsedMs = 0;
  Offset? _lastPlayerPos;
  bool _concertVibeDimmed = false;

  @override
  void initState() {
    super.initState();
    widget.userActivityListenable?.addListener(_onExternalActivity);
    _idlePollTimer = Timer.periodic(
      const Duration(milliseconds: _pollIntervalMs),
      (_) => _evaluateConcertVibeIdle(),
    );
  }

  @override
  void didUpdateWidget(covariant WristbandHud oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userActivityListenable != widget.userActivityListenable) {
      oldWidget.userActivityListenable?.removeListener(_onExternalActivity);
      widget.userActivityListenable?.addListener(_onExternalActivity);
    }
  }

  @override
  void dispose() {
    widget.userActivityListenable?.removeListener(_onExternalActivity);
    _idlePollTimer?.cancel();
    _toastAutoClearTimer?.cancel();
    _hudPulseController.dispose();
    super.dispose();
  }

  void _onExternalActivity() {
    _idleElapsedMs = 0;
    if (_concertVibeDimmed && mounted) {
      setState(() => _concertVibeDimmed = false);
    }
  }

  void _evaluateConcertVibeIdle() {
    if (!mounted) return;
    try {
      var movedThisTick = false;
      final p = widget.game.player;
      if (p != null) {
        final cur = Offset(p.position.x, p.position.y);
        if (_lastPlayerPos != null && (cur - _lastPlayerPos!).distance > 0.55) {
          movedThisTick = true;
        }
        _lastPlayerPos = cur;
      }

      if (movedThisTick) {
        _idleElapsedMs = 0;
      } else {
        _idleElapsedMs += _pollIntervalMs;
      }

      final overlay = ref.read(uiOverlayProvider);
      final journalOpen = ref.read(journalStateProvider).isOpen;
      final snap = widget.game.scheduleController.latest;
      final inStageZone = (snap.primaryMix?.gain ?? 0.0) > 0.20 &&
          widget.game.outerGateApproachFactor < 0.30;
      final hasBlockingUi = overlay.isBlockingInput ||
          journalOpen ||
          overlay.toastBanner != null;

      final shouldDim = !hasBlockingUi &&
          inStageZone &&
          _idleElapsedMs >= _vibeIdleThresholdMs;

      if (shouldDim != _concertVibeDimmed) {
        setState(() => _concertVibeDimmed = shouldDim);
      }
    } on StateError {
      // Container already disposed during test teardown.
    }
  }

  void _syncToastAutoDismiss(UiOverlayState overlay) {
    if (overlay.toastSerial == _lastObservedToastSerial) return;
    _lastObservedToastSerial = overlay.toastSerial;
    _toastAutoClearTimer?.cancel();
    if (overlay.toastBanner != null) {
      _toastAutoClearTimer = Timer(_toastDisplayDuration, () {
        if (!mounted) return;
        ref.read(uiOverlayProvider.notifier).clearToast();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final clock = ref.watch(festivalClockProvider);
    final profile = ref.watch(playerProfileProvider);
    final flags = ref.watch(worldFlagsProvider);
    final overlay = ref.watch(uiOverlayProvider);
    final journalOpen = ref.watch(journalStateProvider).isOpen;
    final data = ref.watch(festivalDataProvider);

    _syncToastAutoDismiss(overlay);

    final activeTracks =
        data.setlist.activeTracksAt(clock.day, clock.minuteOfDay);
    final snap = widget.game.scheduleController.latest;
    final primaryTrack = snap.primaryTrack ??
        (overlay.turntableTrackNumber != null
            ? data.setlist.trackByNumber(overlay.turntableTrackNumber!)
            : (activeTracks.isNotEmpty ? activeTracks.first : null));
    final isAudible = (snap.primaryMix?.gain ?? 0.0) > 0.06;

    final paSubtitle = activeTracks
        .where((t) => t.subtitle != null)
        .map((t) => t.subtitle!)
        .firstOrNull;
    final berrySetsLeft =
        flags.blueberrySetsRemainingAt(clock.day, clock.minuteOfDay);
    final mudActive = clock.isOrchardMuddy(data.setlist) ||
        clock.isMudExperienceActive(data.setlist);

    // Concise headline inside the single top Pocket Program pill
    final String pillHeadline;
    if (widget.game.outerGateApproachFactor > 0.35) {
      pillHeadline = primaryTrack != null
          ? 'Orchard Gate · ♪ ${primaryTrack.title}'
          : 'Orchard Gate · Gates Open';
    } else if (primaryTrack != null && isAudible) {
      final stShort = (data.setlist.stages[primaryTrack.stageId]?.name ??
              primaryTrack.stageId)
          .replaceAll(' Stage', '')
          .replaceAll('The ', '');
      pillHeadline = '$stShort · ${primaryTrack.title}';
    } else {
      pillHeadline = profile.activeZoneName;
    }
    final dayShort = clock.encoreModeUnlocked ? 'Encore' : 'Day ${clock.day}';

    final screenSize = MediaQuery.sizeOf(context);
    final uiBlocked = overlay.isBlockingInput || journalOpen;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final safeW = constraints.maxWidth;
          final safeH = constraints.maxHeight;
          final mediaPadding = MediaQuery.paddingOf(context);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Diegetic Orchard Gate Flanking World Badges (>= 48x48px tap targets)
              if (!uiBlocked)
                AnimatedBuilder(
                  animation: _hudPulseController,
                  builder: (context, _) {
                    if (!widget.game.isPlayerNearOrchardGate) {
                      return const SizedBox.shrink();
                    }
                    final lineupScreen = widget.game.worldToScreen(
                      OrchardGateLayout.lineupKioskPos.translate(0, -30),
                    );
                    final boothScreen = widget.game.worldToScreen(
                      OrchardGateLayout.cultivarBoothPos.translate(0, -30),
                    );
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (lineupScreen != null)
                          _buildDiegeticGateBadge(
                            badgeKey:
                                const ValueKey('orchard_gate_lineup_kiosk'),
                            screenPt: lineupScreen,
                            mediaTopInset: mediaPadding.top,
                            safeW: safeW,
                            safeH: safeH,
                            icon: '🎸',
                            title: 'Lineup',
                            subtitle: '30 Sets',
                            accentColor: const Color(0xFFFFD166),
                            alignRightHalf: false,
                            onTap: () {
                              _onExternalActivity();
                              widget.game.openLineupKiosk();
                            },
                          ),
                        if (boothScreen != null)
                          _buildDiegeticGateBadge(
                            badgeKey:
                                const ValueKey('orchard_gate_cultivar_booth'),
                            screenPt: boothScreen,
                            mediaTopInset: mediaPadding.top,
                            safeW: safeW,
                            safeH: safeH,
                            icon: '🌰',
                            title: 'Cultivars',
                            subtitle:
                                '${profile.discoveredCultivarIds.length}/11 & Mix',
                            accentColor: const Color(0xFF74C69D),
                            alignRightHalf: true,
                            onTap: () {
                              _onExternalActivity();
                              widget.game.openCultivarBooth();
                            },
                          ),
                      ],
                    );
                  },
                ),

              // 2. Context-Only World-Space Interaction Bubble (>= 48x48px tap target)
              ValueListenableBuilder<WorldContextPrompt?>(
                valueListenable: widget.game.worldContextPrompt,
                builder: (context, prompt, _) {
                  final visible = prompt != null && !uiBlocked;
                  if (!visible) {
                    return const SizedBox.shrink();
                  }
                  final localX =
                      (prompt.screenAnchor.dx - mediaPadding.left).clamp(
                    68.0,
                    math.max(68.0, safeW - 68.0),
                  );
                  final localY =
                      (prompt.screenAnchor.dy - mediaPadding.top - 26.0).clamp(
                    54.0,
                    math.max(54.0, safeH - 64.0),
                  );

                  return Positioned(
                    left: localX - 92.0,
                    top: localY - 24.0,
                    width: 184.0,
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey('bubble_anim_${prompt.id}'),
                        tween: Tween<double>(begin: 0.86, end: 1.0),
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: const ValueKey('world_context_bubble'),
                            borderRadius: BorderRadius.circular(24),
                            onTap: () {
                              _onExternalActivity();
                              widget.game.handleInteract();
                            },
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 56,
                                minHeight: 48,
                              ),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 13,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xF024160D),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: const Color(0xFFFFD166),
                                      width: 1.6,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x88000000),
                                        blurRadius: 10,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        prompt.icon,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          prompt.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFFFFF8E7),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // 3. Single Slim Top-Center "Pocket Program" Pill + Concert Vibe Mode Auto-Hide
              Positioned(
                top: 4,
                left: 12,
                right: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedOpacity(
                      key: const ValueKey('concert_vibe_hud_opacity'),
                      opacity: _concertVibeDimmed ? 0.15 : 1.0,
                      duration: Duration(
                        milliseconds: _concertVibeDimmed ? 620 : 140,
                      ),
                      curve: Curves.easeOut,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: 48,
                            maxWidth: math.min(screenSize.width - 24, 356),
                          ),
                          child: Center(
                            child: GestureDetector(
                              key: const ValueKey('pocket_program_pill'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                _onExternalActivity();
                                unawaited(
                                  widget.game.audioService
                                      .unlockAndInitialize(),
                                );
                                ref
                                    .read(uiOverlayProvider.notifier)
                                    .togglePocketProgram();
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Container(
                                  height: 36,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 13,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xEB1D120B),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: overlay.pocketProgramOpen
                                          ? const Color(0xFFFFBE0B)
                                          : const Color(0xFFD49A5A),
                                      width: 1.4,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x77000000),
                                        blurRadius: 12,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedBuilder(
                                        animation: _hudPulseController,
                                        builder: (context, _) =>
                                            _MiniEqualizerBars(
                                          phase: _hudPulseController.value,
                                          energy: isAudible
                                              ? (0.38 +
                                                      snap.fft.bass * 0.62)
                                                  .clamp(0.25, 1.0)
                                              : 0.18,
                                          active: isAudible,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          pillHeadline,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFFFFF3D6),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.15,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 1,
                                        height: 14,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        color: const Color(0x55D49A5A),
                                      ),
                                      Text(
                                        dayShort,
                                        style: const TextStyle(
                                          color: Color(0xFFFFD166),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Icon(
                                        overlay.pocketProgramOpen
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons.keyboard_arrow_down_rounded,
                                        size: 16,
                                        color: const Color(0xFFE0A96D),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Celebratory 2.5s Slide-Down Toast Notification
                    if (overlay.toastBanner != null)
                      TweenAnimationBuilder<double>(
                        key: ValueKey('toast_${overlay.toastSerial}'),
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, child) => Opacity(
                          opacity: t.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, (1.0 - t) * -10.0),
                            child: child,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: GestureDetector(
                            key: const ValueKey('festival_toast_banner'),
                            onTap: () => ref
                                .read(uiOverlayProvider.notifier)
                                .clearToast(),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 360),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xF2173628),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFF74C69D),
                                    width: 1.3,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x66000000),
                                      blurRadius: 10,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  overlay.toastBanner!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFE9F5DB),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Rare PA Horn Broadcast Subtitle
                    if (paSubtitle != null && !uiBlocked)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 350),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xE8341B0D),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFFB703),
                              ),
                            ),
                            child: Text(
                              '📢 "$paSubtitle"',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFFF3B0),
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 4. Ephemeral Event-Only Context Chips (Mud Fest or Day 2 Blueberries ONLY)
              if (!uiBlocked && (mudActive || berrySetsLeft > 0))
                Positioned(
                  bottom: 10,
                  left: 12,
                  right: 12,
                  child: AnimatedOpacity(
                    opacity: _concertVibeDimmed ? 0.20 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Center(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          if (berrySetsLeft > 0)
                            Container(
                              key: const ValueKey(
                                'electric_blueberry_hud_badge',
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xEE7B2CBF),
                                    Color(0xEE3A86FF),
                                  ],
                                ),
                                border: Border.all(
                                  color: const Color(0xFFFFEA00),
                                ),
                              ),
                              child: Text(
                                '🫐 Rainbow ($berrySetsLeft ${berrySetsLeft == 1 ? "Set" : "Sets"} Left)',
                                style: const TextStyle(
                                  color: Color(0xFFFFF8E7),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          if (mudActive) ...[
                            _CompactEventPill(
                              pillKey: const ValueKey('mud_slide_button'),
                              label: '🛝 Mud Slide',
                              onTap: () {
                                _onExternalActivity();
                                widget.game.triggerPlayerMudSlide();
                              },
                            ),
                            _CompactEventPill(
                              pillKey: const ValueKey('mud_toss_button'),
                              label: flags.mudFightsSplatted > 0
                                  ? '🤎 Mud Toss (${flags.mudFightsSplatted})'
                                  : '🤎 Mud Toss',
                              onTap: () {
                                _onExternalActivity();
                                widget.game.triggerPlayerMudThrow();
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDiegeticGateBadge({
    required Key badgeKey,
    required Offset screenPt,
    required double mediaTopInset,
    required double safeW,
    required double safeH,
    required String icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required bool alignRightHalf,
    required VoidCallback onTap,
  }) {
    const badgeW = 114.0;
    const badgeH = 50.0;
    final minX = alignRightHalf ? safeW * 0.50 + 4.0 : 8.0;
    final maxX = alignRightHalf
        ? math.max(minX, safeW - badgeW - 8.0)
        : math.max(8.0, safeW * 0.50 - badgeW - 4.0);
    final left = (screenPt.dx - badgeW * 0.5).clamp(minX, maxX).toDouble();
    final top = (screenPt.dy - mediaTopInset - badgeH * 0.5)
        .clamp(
          62.0,
          math.max(62.0, safeH - badgeH - 18.0),
        )
        .toDouble();

    return Positioned(
      left: left,
      top: top,
      width: badgeW,
      height: badgeH,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: badgeKey,
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xEB22140C),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accentColor, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x88000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(icon, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 5),
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFFFF8E7),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 9.8,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniEqualizerBars extends StatelessWidget {
  const _MiniEqualizerBars({
    required this.phase,
    required this.energy,
    required this.active,
  });

  final double phase;
  final double energy;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final rad = phase * math.pi * 2.0;
    final heights = <double>[
      4.0 + 10.0 * energy * (0.55 + 0.45 * math.sin(rad).abs()),
      5.0 + 11.0 * energy * (0.55 + 0.45 * math.cos(rad * 1.3 + 0.7).abs()),
      4.0 + 10.0 * energy * (0.55 + 0.45 * math.sin(rad * 1.7 + 1.5).abs()),
      3.5 + 9.0 * energy * (0.55 + 0.45 * math.cos(rad * 0.9 + 2.1).abs()),
    ];
    return SizedBox(
      width: 15,
      height: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              width: 2.5,
              height: heights[i].clamp(3.0, 15.0),
              decoration: BoxDecoration(
                color: active
                    ? (i.isOdd
                        ? const Color(0xFFFFBE0B)
                        : const Color(0xFF74C69D))
                    : const Color(0xAA95D5B2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompactEventPill extends StatelessWidget {
  const _CompactEventPill({
    required this.pillKey,
    required this.label,
    required this.onTap,
  });

  final Key pillKey;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE6281910),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        key: pillKey,
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFFFD166),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
