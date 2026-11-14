import 'dart:async';
import 'dart:math' as math;
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/walnutstock_game.dart';
import '../state/dialogue_and_overlay_state.dart';
import '../state/festival_clock.dart';
import '../state/providers.dart';
import '../state/settings_state.dart';
import 'minimap_radar.dart';

class WristbandHud extends ConsumerWidget {
  const WristbandHud({
    super.key,
    required this.game,
  });

  final WalnutstockGame game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clock = ref.watch(festivalClockProvider);
    final profile = ref.watch(playerProfileProvider);
    final flags = ref.watch(worldFlagsProvider);
    final overlay = ref.watch(uiOverlayProvider);
    final settings = ref.watch(settingsProvider);
    final data = ref.watch(festivalDataProvider);

    final activeTracks =
        data.setlist.activeTracksAt(clock.day, clock.minuteOfDay);
    final berrySetsLeft =
        flags.blueberrySetsRemainingAt(clock.day, clock.minuteOfDay);
    final snap = game.scheduleController.latest;
    final primaryTrack = snap.primaryTrack ??
        (overlay.turntableTrackNumber != null
            ? data.setlist.trackByNumber(overlay.turntableTrackNumber!)
            : (activeTracks.isNotEmpty ? activeTracks.first : null));
    final nearLiveStage = (snap.primaryMix?.gain ?? 0.0) > 0.25;

    final paSubtitle = activeTracks
        .where((t) => t.subtitle != null)
        .map((t) => t.subtitle!)
        .firstOrNull;

    final size = MediaQuery.sizeOf(context);
    final isPortrait = size.height > size.width;
    final isCompactWidth = size.width < 640;
    final isGameBoyDeck =
        settings.touchLayout == TouchControlsLayout.portraitGameBoy;
    final showTouchPads = switch (settings.touchLayout) {
      TouchControlsLayout.hidden => false,
      TouchControlsLayout.landscapeDpad ||
      TouchControlsLayout.portraitGameBoy =>
        true,
      TouchControlsLayout.auto => size.shortestSide < 560 || isPortrait,
    };

    final quickActionChips = <Widget>[
      _HudChipButton(
        buttonKey: const ValueKey('open_journal_button'),
        icon: Icons.menu_book_rounded,
        label: 'Journal',
        active: false,
        compactTouch: isCompactWidth,
        onTap: () => ref.read(journalStateProvider.notifier).openJournal(),
      ),
      _HudChipButton(
        buttonKey: const ValueKey('next_set_button'),
        icon: Icons.skip_next_rounded,
        label: 'Next Set',
        active: false,
        compactTouch: isCompactWidth,
        onTap: () {
          unawaited(game.audioService.unlockAndInitialize());
          final jumped =
              ref.read(festivalClockProvider.notifier).jumpToNextScheduledSet();
          if (jumped != null) {
            ref.read(uiOverlayProvider.notifier).showToast(
                  '⏭️ Cued #${jumped.trackNumber}: ${jumped.title} (${data.setlist.stages[jumped.stageId]?.name ?? jumped.stageId})',
                );
          }
        },
      ),
      _HudChipButton(
        buttonKey: const ValueKey('time_speed_button'),
        icon: clock.timeSpeedMultiplier > 1.0
            ? Icons.fast_forward_rounded
            : Icons.schedule_rounded,
        label: 'Time ${clock.timeSpeedMultiplier.round()}x',
        active: clock.timeSpeedMultiplier > 1.0,
        compactTouch: isCompactWidth,
        onTap: () {
          ref.read(festivalClockProvider.notifier).cycleTimeSpeed();
          final speed =
              ref.read(festivalClockProvider).timeSpeedMultiplier.round();
          ref.read(uiOverlayProvider.notifier).showToast(
                speed == 1
                    ? '⏱️ Festival Clock: Normal 1x Orchard Pace'
                    : '⏩ Festival Clock: ${speed}x Day/Night Progression!',
              );
        },
      ),
      _HudChipButton(
        buttonKey: const ValueKey('pure_vibe_button'),
        icon: Icons.spa_outlined,
        label: 'Pure Vibe',
        active: clock.pureVibeMode,
        compactTouch: isCompactWidth,
        onTap: () {
          unawaited(game.audioService.unlockAndInitialize());
          ref.read(festivalClockProvider.notifier).togglePureVibeMode();
        },
      ),
      _HudChipButton(
        buttonKey: const ValueKey('dance_groove_button'),
        icon: Icons.music_note_rounded,
        label: flags.playerDancing
            ? 'Dancing (${flags.currentDanceStyleLabel})'
            : 'Dance',
        active: flags.playerDancing,
        compactTouch: isCompactWidth,
        onTap: () {
          unawaited(game.audioService.unlockAndInitialize());
          game.togglePlayerDanceGroove();
        },
      ),
      if (flags.playerDancing)
        _HudChipButton(
          buttonKey: const ValueKey('dance_style_button'),
          icon: Icons.autorenew_rounded,
          label: 'Move: ${flags.currentDanceStyleLabel}',
          active: false,
          compactTouch: isCompactWidth,
          onTap: () {
            unawaited(game.audioService.unlockAndInitialize());
            game.cyclePlayerDanceMove();
          },
        ),
      _HudChipButton(
        buttonKey: const ValueKey('sway_emote_button'),
        icon: Icons.waves_rounded,
        label: flags.crowdAura > 0.15
            ? 'Sway ${(flags.crowdAura * 100).round()}%'
            : 'Sway',
        active: flags.playerSwaying,
        compactTouch: isCompactWidth,
        onTap: () {
          unawaited(game.audioService.unlockAndInitialize());
          if (flags.slowWaveSwayUnlocked || clock.pureVibeMode) {
            ref.read(worldFlagsProvider.notifier).togglePlayerSway();
          } else {
            ref.read(uiOverlayProvider.notifier).showToast(
                  'Help Burt Baskernut at Vendor Row (or talk to Joan Baezelnut) to unlock Slow-Wave Sway!',
                );
          }
        },
      ),
      if (berrySetsLeft > 0)
        Container(
          key: const ValueKey('electric_blueberry_hud_badge'),
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [
                Color(0xEE7B2CBF),
                Color(0xEE3A86FF),
                Color(0xEE00BBF9),
              ],
            ),
            border: Border.all(
              color: const Color(0xFFFFEA00),
              width: 1.3,
            ),
          ),
          child: Text(
            '🫐🌈 Wavy Rainbow ($berrySetsLeft ${berrySetsLeft == 1 ? "Set" : "Sets"} Left)',
            style: const TextStyle(
              color: Color(0xFFFFF8E7),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      if (clock.isOrchardMuddy(data.setlist) ||
          clock.isMudExperienceActive(data.setlist)) ...[
        _HudChipButton(
          buttonKey: const ValueKey('mud_slide_button'),
          icon: Icons.downhill_skiing_rounded,
          label: 'Mud Slide',
          active: game.player?.isBellySliding ?? false,
          compactTouch: isCompactWidth,
          onTap: () {
            unawaited(game.audioService.unlockAndInitialize());
            game.triggerPlayerMudSlide();
          },
        ),
        _HudChipButton(
          buttonKey: const ValueKey('mud_toss_button'),
          icon: Icons.sports_baseball_rounded,
          label: flags.mudFightsSplatted > 0
              ? 'Mud Toss (${flags.mudFightsSplatted})'
              : 'Mud Toss',
          active: false,
          compactTouch: isCompactWidth,
          onTap: () {
            unawaited(game.audioService.unlockAndInitialize());
            game.triggerPlayerMudThrow();
          },
        ),
      ],
      if (primaryTrack != null || nearLiveStage || flags.justListenStageMode)
        _HudChipButton(
          buttonKey: const ValueKey('just_listen_button'),
          icon: Icons.headphones_rounded,
          label: 'Just Listen',
          active: flags.justListenStageMode,
          compactTouch: isCompactWidth,
          onTap: () {
            unawaited(game.audioService.unlockAndInitialize());
            ref.read(worldFlagsProvider.notifier).toggleJustListenMode();
          },
        ),
      if (clock.encoreModeUnlocked)
        _HudChipButton(
          buttonKey: const ValueKey('encore_deck_button'),
          icon: Icons.auto_awesome_rounded,
          label: 'Encore Deck',
          active: overlay.modal == ActiveModalOverlay.encoreDeck,
          compactTouch: isCompactWidth,
          onTap: () {
            final cur = ref.read(uiOverlayProvider).modal;
            ref.read(uiOverlayProvider.notifier).openModal(
                  cur == ActiveModalOverlay.encoreDeck
                      ? ActiveModalOverlay.none
                      : ActiveModalOverlay.encoreDeck,
                );
          },
        ),
      _HudChipButton(
        buttonKey: const ValueKey('open_settings_button'),
        icon: Icons.tune_rounded,
        label: 'Options',
        active: false,
        compactTouch: isCompactWidth,
        onTap: () => ref.read(uiOverlayProvider.notifier).openModal(
              ActiveModalOverlay.settingsDrawer,
            ),
      ),
    ];

    return SafeArea(
      child: Stack(
        children: [
          // Unified Top-Bar + Quick-Action Chips + PA/Toast Stack (never overlaps on multi-line wrap!)
          Positioned(
            top: 8,
            left: 10,
            right: 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isCompactWidth ? 10 : 12,
                              vertical: isCompactWidth ? 6 : 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xE61F150E),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFD49A5A),
                                width: 1.5,
                              ),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final dayBadge = Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3A2618),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${clock.dayLabel} · ${clock.formattedClock} · ${clock.timeOfDayLabel} · ${_weatherLabel(clock, data.setlist)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFFFD166),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                );
                                final zoneLabel = Text(
                                  '📍 ${profile.activeZoneName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF95D5B2),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                                final stageShortName = primaryTrack != null
                                    ? (data.setlist.stages[primaryTrack.stageId]
                                            ?.name ??
                                        primaryTrack.stageId)
                                    : null;
                                final isTrackAudible =
                                    (snap.primaryMix?.isAudible ?? true);
                                final trackLabel = primaryTrack != null
                                    ? Text(
                                        isTrackAudible
                                            ? '🎵 #${primaryTrack.trackNumber}: ${primaryTrack.artist} — ${primaryTrack.title}'
                                            : '📻 #${primaryTrack.trackNumber}: ${primaryTrack.artist} — ${primaryTrack.title} (@ $stageShortName)',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isTrackAudible
                                              ? const Color(0xFFF4E3C1)
                                              : const Color(0xFFFFD166),
                                          fontSize: 12,
                                        ),
                                      )
                                    : const Text(
                                        '🌿 Canopy Breeze Between Sets (Tap "Next Set" to cue)',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Color(0xFFB7A99A),
                                          fontSize: 11,
                                        ),
                                      );

                                final headerContent = constraints.maxWidth >= 600
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(flex: 3, child: dayBadge),
                                          const SizedBox(width: 8),
                                          Flexible(flex: 2, child: zoneLabel),
                                          const SizedBox(width: 8),
                                          Flexible(flex: 3, child: trackLabel),
                                        ],
                                      )
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                flex: 3,
                                                child: dayBadge,
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                flex: 2,
                                                child: zoneLabel,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          trackLabel,
                                        ],
                                      );

                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    headerContent,
                                    const SizedBox(height: 5),
                                    _SkyProgressionBar(
                                      key: const ValueKey(
                                          'sky_progression_bar'),
                                      clock: clock,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          if (!isCompactWidth) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: quickActionChips,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    MinimapRadarWidget(
                      playerX: game.player?.position.x ?? profile.savedX,
                      playerY: game.player?.position.y ?? profile.savedY,
                    ),
                  ],
                ),
                if (isCompactWidth) ...[
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Row(
                      children: [
                        for (var i = 0; i < quickActionChips.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          quickActionChips[i],
                        ],
                      ],
                    ),
                  ),
                ],

                // PA Broadcast Subtitle Banner
                if (paSubtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 10, right: 10),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xEB3B1F0E),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFB703)),
                        ),
                        child: Text(
                          '📢 PA HORN: "$paSubtitle"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFFF3B0),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Toast Banner
                if (overlay.toastBanner != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 14, right: 14),
                    child: Center(
                      child: GestureDetector(
                        onTap: () =>
                            ref.read(uiOverlayProvider.notifier).clearToast(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xEE183A2C),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF52B788)),
                          ),
                          child: Text(
                            overlay.toastBanner!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFE9F5DB),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Contextual Pokémon-style Interaction Prompt
          if (overlay.nearbyInteractPrompt != null && overlay.dialogue == null)
            Positioned(
              bottom: showTouchPads
                  ? (isGameBoyDeck ? 168 : (isPortrait ? 162 : 44))
                  : 36,
              left: 12,
              right: 12,
              child: Center(
                child: ElevatedButton.icon(
                  key: const ValueKey('contextual_interact_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xEE2B1E14),
                    foregroundColor: const Color(0xFFFFD166),
                    side:
                        const BorderSide(color: Color(0xFFFFD166), width: 1.8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                  ),
                  onPressed: game.handleInteract,
                  icon: const Icon(Icons.chat_bubble_outline, size: 17),
                  label: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: math.max(160.0, size.width - 84.0),
                    ),
                    child: Text(
                      overlay.nearbyInteractPrompt!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),

          // Optional Responsive Virtual D-Pad + A/B Sanctuary Controls
          if (showTouchPads && !overlay.isBlockingInput)
            Positioned(
              bottom: isGameBoyDeck ? 8 : 14,
              left: isGameBoyDeck ? 10 : 14,
              right: isGameBoyDeck ? 10 : 14,
              child: Container(
                padding: isGameBoyDeck
                    ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
                    : EdgeInsets.zero,
                decoration: isGameBoyDeck
                    ? BoxDecoration(
                        color: const Color(0xCC1E140D),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xAA9C6644),
                          width: 1.5,
                        ),
                      )
                    : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _VirtualDpad(
                      onDirection: (dx, dy) {
                        unawaited(game.audioService.unlockAndInitialize());
                        game.inputController.setVirtualDpad(dx, dy);
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: _RoundArcadeButton(
                              label: 'B',
                              subtitle: 'Dance',
                              color: flags.playerDancing
                                  ? const Color(0xFFF72585)
                                  : const Color(0xFF40916C),
                              onTap: () {
                                unawaited(
                                    game.audioService.unlockAndInitialize());
                                game.togglePlayerDanceGroove();
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _RoundArcadeButton(
                              label: 'A',
                              subtitle: 'Act',
                              color: const Color(0xFF9B2226),
                              onTap: () {
                                unawaited(
                                    game.audioService.unlockAndInitialize());
                                game.handleInteract();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _weatherLabel(FestivalClockState clock, dynamic setlist) {
    final w = clock.effectiveWeather;
    if (clock.day == 1 && w == WeatherPhase.preStormHumid) {
      return '🌦️ Rain Ramp';
    }
    if (clock.isMudExperienceActive(setlist) &&
        w != WeatherPhase.blightRainstorm) {
      return '🛝 Mud Fest';
    }
    switch (w) {
      case WeatherPhase.clear:
        return '☀️ Sunny';
      case WeatherPhase.preStormHumid:
        return '🌥️ Humid';
      case WeatherPhase.blightRainstorm:
        return '🌧️ Storm';
      case WeatherPhase.postStormMist:
        return '🌫️ Mist';
      case WeatherPhase.starryFireflies:
        return '✨ Fireflies';
      case WeatherPhase.purpleDustFinale:
        return '🔮 Purple Dust';
    }
  }
}

class _HudChipButton extends StatelessWidget {
  const _HudChipButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.compactTouch = false,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool compactTouch;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? const Color(0xEE52B788) : const Color(0xDD261B12),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: buttonKey,
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compactTouch ? 11 : 10,
            vertical: compactTouch ? 8 : 6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? const Color(0xFFD8F3DC) : const Color(0xFFB08968),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: compactTouch ? 16 : 15,
                color:
                    active ? const Color(0xFF081C15) : const Color(0xFFFFD166),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: active
                      ? const Color(0xFF081C15)
                      : const Color(0xFFF4E3C1),
                  fontSize: compactTouch ? 12.5 : 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VirtualDpad extends StatefulWidget {
  const _VirtualDpad({required this.onDirection});
  final void Function(double dx, double dy) onDirection;

  @override
  State<_VirtualDpad> createState() => _VirtualDpadState();
}

class _VirtualDpadState extends State<_VirtualDpad> {
  static const double _padSize = 132.0;
  static const double _deadzone = 10.0;

  int? _activePointer;
  Offset _vec = Offset.zero;

  void _updateFromLocal(Offset localPos) {
    const center = Offset(_padSize * 0.5, _padSize * 0.5);
    final delta = localPos - center;
    final dist = delta.distance;
    if (dist < _deadzone) {
      if (_vec != Offset.zero) {
        setState(() => _vec = Offset.zero);
        widget.onDirection(0, 0);
      }
      return;
    }
    const maxRadius = _padSize * 0.42;
    final mag = ((dist - _deadzone) / (maxRadius - _deadzone)).clamp(0.35, 1.0);
    final nx = (delta.dx / dist) * mag;
    final ny = (delta.dy / dist) * mag;
    setState(() => _vec = Offset(nx, ny));
    widget.onDirection(nx, ny);
  }

  void _release() {
    _activePointer = null;
    if (_vec != Offset.zero) {
      setState(() => _vec = Offset.zero);
    }
    widget.onDirection(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    final upActive = _vec.dy < -0.25;
    final downActive = _vec.dy > 0.25;
    final leftActive = _vec.dx < -0.25;
    final rightActive = _vec.dx > 0.25;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        _activePointer = e.pointer;
        _updateFromLocal(e.localPosition);
      },
      onPointerMove: (e) {
        if (_activePointer == e.pointer) {
          _updateFromLocal(e.localPosition);
        }
      },
      onPointerUp: (e) {
        if (_activePointer == e.pointer) {
          _release();
        }
      },
      onPointerCancel: (e) {
        if (_activePointer == e.pointer) {
          _release();
        }
      },
      child: SizedBox(
        width: _padSize,
        height: _padSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Soft outer touch ring for comfortable 8-way thumb sliding
            Container(
              width: _padSize,
              height: _padSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x8C1E140D),
                border: Border.all(
                  color: _vec == Offset.zero
                      ? const Color(0x88D49A5A)
                      : const Color(0xDDFFD166),
                  width: 1.6,
                ),
              ),
            ),
            // Vertical cross arm
            Container(
              width: 44,
              height: 112,
              decoration: BoxDecoration(
                color: const Color(0xB82B1E14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x88B08968)),
              ),
            ),
            // Horizontal cross arm
            Container(
              width: 112,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xB82B1E14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x88B08968)),
              ),
            ),
            // Directional arrows
            Positioned(
              top: 10,
              child: Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 26,
                color: upActive
                    ? const Color(0xFFFFD166)
                    : const Color(0xCCF4E3C1),
              ),
            ),
            Positioned(
              bottom: 10,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 26,
                color: downActive
                    ? const Color(0xFFFFD166)
                    : const Color(0xCCF4E3C1),
              ),
            ),
            Positioned(
              left: 10,
              child: Icon(
                Icons.keyboard_arrow_left_rounded,
                size: 26,
                color: leftActive
                    ? const Color(0xFFFFD166)
                    : const Color(0xCCF4E3C1),
              ),
            ),
            Positioned(
              right: 10,
              child: Icon(
                Icons.keyboard_arrow_right_rounded,
                size: 26,
                color: rightActive
                    ? const Color(0xFFFFD166)
                    : const Color(0xCCF4E3C1),
              ),
            ),
            // Floating thumb nub indicator
            Transform.translate(
              offset: Offset(
                math.min(26.0, math.max(-26.0, _vec.dx * 26.0)),
                math.min(26.0, math.max(-26.0, _vec.dy * 26.0)),
              ),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _vec == Offset.zero
                      ? const Color(0xCC3E2A1B)
                      : const Color(0xEE52B788),
                  border: Border.all(
                    color: _vec == Offset.zero
                        ? const Color(0xFFD49A5A)
                        : const Color(0xFFFFF8E7),
                    width: 1.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundArcadeButton extends StatelessWidget {
  const _RoundArcadeButton({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.88),
          border: Border.all(color: const Color(0xFFF4E3C1), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 17,
                height: 1.05,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkyProgressionBar extends StatelessWidget {
  const _SkyProgressionBar({
    super.key,
    required this.clock,
  });

  final FestivalClockState clock;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 7,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final pipX = (w * clock.dayArcProgress)
              .clamp(3.5, (w - 3.5).clamp(3.5, double.infinity));
          final showDay1StormAndMud = clock.day == 1;
          final showDay2Storm = clock.day == 2;

          // Day 1 Set 7 Rain Ramp + Set 8 Storm (1140..1305) -> Post-Set-8 Mud Fest (1305..1660)
          final d1StormLeft = (w * ((1140.0 - 300.0) / 1380.0)).clamp(0.0, w);
          final d1StormWidth = (w * (165.0 / 1380.0)).clamp(4.0, w);
          final d1MudLeft = (w * ((1305.0 - 300.0) / 1380.0)).clamp(0.0, w);
          final d1MudWidth = (w * (355.0 / 1380.0)).clamp(4.0, w - d1MudLeft);

          // Day 2 Rainstorm window (~1075..1190) normalized across 300..1680:
          final stormLeft = (w * ((1075.0 - 300.0) / 1380.0)).clamp(0.0, w);
          final stormWidth = (w * (115.0 / 1380.0)).clamp(4.0, w);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 5,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF9671), // 5 AM Dawn
                      Color(0xFF74C69D), // Morning
                      Color(0xFF4CC9F0), // Midday Sun
                      Color(0xFFFF9E00), // 6 PM Golden Hour
                      Color(0xFF7B2CBF), // Dusk
                      Color(0xFF1D1E4E), // Midnight Stars
                    ],
                    stops: [0.0, 0.14, 0.36, 0.56, 0.67, 1.0],
                  ),
                ),
              ),
              if (showDay1StormAndMud) ...[
                Positioned(
                  left: d1StormLeft,
                  top: 1,
                  width: d1StormWidth,
                  height: 5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xDD3A86FF),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Positioned(
                  left: d1MudLeft,
                  top: 1,
                  width: d1MudWidth,
                  height: 5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xDDB07D4F),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
              if (showDay2Storm) ...[
                Positioned(
                  left: 0,
                  top: 1,
                  width: (w * ((900.0 - 300.0) / 1380.0)).clamp(4.0, w),
                  height: 5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xCC9D4EDD),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Positioned(
                  left: stormLeft,
                  top: 1,
                  width: stormWidth,
                  height: 5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xDD3A86FF),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
              Positioned(
                left: pipX - 3.5,
                top: 0,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: clock.effectiveWeather == WeatherPhase.blightRainstorm
                        ? const Color(0xFF90E0EF)
                        : (clock.isNightOrDusk
                            ? const Color(0xFFE0AAFF)
                            : const Color(0xFFFFF3B0)),
                    border: Border.all(
                      color: const Color(0xFF1F150E),
                      width: 1.2,
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
}
