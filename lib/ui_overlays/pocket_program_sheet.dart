import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../game/walnutstock_game.dart';
import '../game/world/astar_pathfinder.dart';
import '../game/world/orchard_gate_component.dart';
import '../state/dialogue_and_overlay_state.dart';
import '../state/festival_clock.dart';
import '../state/journal_state.dart';
import '../state/player_profile.dart';
import '../state/providers.dart';
import '../state/world_flags.dart';
import 'minimap_radar.dart';

/// Styled **1969 Folded Festival Program** modal sheet unfolded from the top
/// Pocket Program pill (or the diegetic Orchard Gate kiosks).
///
/// Consolidates:
/// 1. **Setlist & Stages** (5 concert stages, all 30 sets, live stage/clock/dance controls)
/// 2. **Orchard Map** (interactive 2048x1536 map, stage quick-walks, Journal & Quests launcher)
/// 3. **Cultivar Pouch (x/11) + Audio/Settings** (all 11 cultivars, wardrobe, audio mix, save/reset)
class PocketProgramSheet extends ConsumerStatefulWidget {
  const PocketProgramSheet({
    super.key,
    required this.game,
  });

  final WalnutstockGame game;

  @override
  ConsumerState<PocketProgramSheet> createState() => _PocketProgramSheetState();
}

class _PocketProgramSheetState extends ConsumerState<PocketProgramSheet> {
  int _selectedDayFilter = 0; // 0 = All, 1..3 = Day 1..3
  bool _confirmingReset = false;

  void _walkPlayerTo(double wx, double wy, String label) {
    final p = widget.game.player;
    if (p != null) {
      final path = AStarPathfinder(widget.game.mapData).findWorldPath(
        startX: p.position.x,
        startY: p.position.y,
        goalX: wx,
        goalY: wy,
      );
      if (path.isNotEmpty) {
        p.setTapPath(path);
      }
    }
    ref.read(uiOverlayProvider.notifier).closePocketProgram();
    ref.read(uiOverlayProvider.notifier).showToast('🧭 Heading toward $label');
  }

  String _formatMinute(double minuteOfDay) {
    final totalMins = minuteOfDay.floor() % 1440;
    final hour24 = totalMins ~/ 60;
    final min = totalMins % 60;
    final suffix = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:${min.toString().padLeft(2, '0')} $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final overlay = ref.watch(uiOverlayProvider);
    final profile = ref.watch(playerProfileProvider);
    final clock = ref.watch(festivalClockProvider);
    final flags = ref.watch(worldFlagsProvider);
    final journal = ref.watch(journalStateProvider);
    final data = ref.watch(festivalDataProvider);
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 520;

    final activeTab = overlay.pocketProgramTab;
    final discoveredCount = profile.discoveredCultivarIds.length;

    return Material(
      color: const Color(0xB809060C),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ref.read(uiOverlayProvider.notifier).closePocketProgram(),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 10 : 18,
                8,
                isCompact ? 10 : 18,
                12,
              ),
              child: GestureDetector(
                onTap: () {}, // Consume taps inside the program card
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 620,
                    maxHeight: (size.height - 36).clamp(320.0, 740.0),
                  ),
                  child: Container(
                    key: const ValueKey('pocket_program_sheet'),
                    decoration: BoxDecoration(
                      color: const Color(0xFA23160E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE0A96D),
                        width: 2.0,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xCC000000),
                          blurRadius: 28,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                        // 1969 Folded Program Poster Masthead
                        Container(
                          padding: EdgeInsets.fromLTRB(
                            isCompact ? 14 : 18,
                            12,
                            10,
                            10,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2E1C11),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(18),
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: Color(0x66D49A5A),
                                width: 1.2,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'AUGUST 1969 · FOLDED POCKET PROGRAM',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Color(0xFFE0A96D),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'WALNUTSTOCK · ${clock.dayLabel} · ${clock.formattedClock}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: const Color(0xFFFFF3D6),
                                        fontSize: isCompact ? 14.5 : 16.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3D2718),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0x99FFD166),
                                  ),
                                ),
                                child: Text(
                                  '📿 ${journal.peaceBeads}',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD166),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                key: const ValueKey(
                                  'close_pocket_program_button',
                                ),
                                tooltip: 'Close Program',
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Color(0xFFF4E3C1),
                                ),
                                onPressed: () => ref
                                    .read(uiOverlayProvider.notifier)
                                    .closePocketProgram(),
                              ),
                            ],
                          ),
                        ),

                        // 3 Clean Program Tabs
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: _ProgramTabPill(
                                  tabKey: const ValueKey('program_tab_setlist'),
                                  icon: Icons.queue_music_rounded,
                                  label: isCompact
                                      ? 'Setlist'
                                      : 'Setlist & Stages',
                                  selected: activeTab ==
                                      PocketProgramTab.setlistAndStages,
                                  onTap: () => ref
                                      .read(uiOverlayProvider.notifier)
                                      .setPocketProgramTab(
                                        PocketProgramTab.setlistAndStages,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _ProgramTabPill(
                                  tabKey: const ValueKey('program_tab_map'),
                                  icon: Icons.map_outlined,
                                  label: isCompact ? 'Map' : 'Orchard Map',
                                  selected:
                                      activeTab == PocketProgramTab.orchardMap,
                                  onTap: () => ref
                                      .read(uiOverlayProvider.notifier)
                                      .setPocketProgramTab(
                                        PocketProgramTab.orchardMap,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _ProgramTabPill(
                                  tabKey: const ValueKey(
                                    'program_tab_cultivars',
                                  ),
                                  icon: Icons.eco_rounded,
                                  label: isCompact
                                      ? 'Pouch ($discoveredCount/11)'
                                      : 'Cultivars ($discoveredCount/11)',
                                  selected: activeTab ==
                                      PocketProgramTab.cultivarAndMix,
                                  onTap: () => ref
                                      .read(uiOverlayProvider.notifier)
                                      .setPocketProgramTab(
                                        PocketProgramTab.cultivarAndMix,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Divider(height: 1, color: Color(0x44D49A5A)),

                        // Active Tab Body
                        Expanded(
                          child: switch (activeTab) {
                            PocketProgramTab.setlistAndStages =>
                              _buildSetlistTab(
                                context,
                                data: data,
                                clock: clock,
                                flags: flags,
                                journal: journal,
                                isCompact: isCompact,
                              ),
                            PocketProgramTab.orchardMap => _buildMapTab(
                                context,
                                data: data,
                                profile: profile,
                                flags: flags,
                                journal: journal,
                                isCompact: isCompact,
                              ),
                              PocketProgramTab.cultivarAndMix =>
                                _buildCultivarAndMixTab(
                                  context,
                                  data: data,
                                  profile: profile,
                                  clock: clock,
                                  flags: flags,
                                  journal: journal,
                                  isCompact: isCompact,
                                ),
                            },
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
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: SETLIST & STAGES (5 Concert Stages · 30 Sets)
  // ---------------------------------------------------------------------------
  Widget _buildSetlistTab(
    BuildContext context, {
    required FestivalDataBundle data,
    required FestivalClockState clock,
    required WorldFlags flags,
    required JournalState journal,
    required bool isCompact,
  }) {
    final activeIds = data.setlist
        .activeTracksAt(clock.day, clock.minuteOfDay)
        .map((t) => t.id)
        .toSet();
    final filteredTracks = _selectedDayFilter == 0
        ? data.setlist.tracks
        : data.setlist.tracks
            .where((t) => t.day == _selectedDayFilter)
            .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      children: [
        // Day/Night Sky Progression + Quick Stage/Groove Actions
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A110B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x66D49A5A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${clock.dayLabel} · ${clock.formattedClock} · ${clock.timeOfDayLabel}',
                      style: const TextStyle(
                        color: Color(0xFFFFD166),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    'Heard ${journal.coreAlbumStampedCount}/26',
                    style: const TextStyle(
                      color: Color(0xFF95D5B2),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ProgramSkyProgressionBar(
                key: const ValueKey('sky_progression_bar'),
                clock: clock,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _ActionChipButton(
                    buttonKey: const ValueKey('next_set_button'),
                    icon: Icons.skip_next_rounded,
                    label: 'Next Set',
                    active: false,
                    onTap: () {
                      unawaited(
                        widget.game.audioService.unlockAndInitialize(),
                      );
                      final jumped = ref
                          .read(festivalClockProvider.notifier)
                          .jumpToNextScheduledSet();
                      if (jumped != null) {
                        ref.read(uiOverlayProvider.notifier).showToast(
                              '⏭️ Cued #${jumped.trackNumber}: ${jumped.title}',
                            );
                      }
                    },
                  ),
                  _ActionChipButton(
                    buttonKey: const ValueKey('time_speed_button'),
                    icon: clock.timeSpeedMultiplier > 1.0
                        ? Icons.fast_forward_rounded
                        : Icons.schedule_rounded,
                    label: 'Time ${clock.timeSpeedMultiplier.round()}x',
                    active: clock.timeSpeedMultiplier > 1.0,
                    onTap: () {
                      ref.read(festivalClockProvider.notifier).cycleTimeSpeed();
                    },
                  ),
                  _ActionChipButton(
                    buttonKey: const ValueKey('dance_groove_button'),
                    icon: Icons.music_note_rounded,
                    label: flags.playerDancing
                        ? 'Dancing (${flags.currentDanceStyleLabel})'
                        : 'Dance',
                    active: flags.playerDancing,
                    onTap: () {
                      unawaited(
                        widget.game.audioService.unlockAndInitialize(),
                      );
                      widget.game.togglePlayerDanceGroove();
                    },
                  ),
                  if (flags.playerDancing)
                    _ActionChipButton(
                      buttonKey: const ValueKey('dance_style_button'),
                      icon: Icons.autorenew_rounded,
                      label: 'Move: ${flags.currentDanceStyleLabel}',
                      active: false,
                      onTap: widget.game.cyclePlayerDanceMove,
                    ),
                  _ActionChipButton(
                    buttonKey: const ValueKey('sway_emote_button'),
                    icon: Icons.waves_rounded,
                    label: 'Sway',
                    active: flags.playerSwaying,
                    onTap: () {
                      if (flags.slowWaveSwayUnlocked || clock.pureVibeMode) {
                        ref.read(worldFlagsProvider.notifier).togglePlayerSway();
                      } else {
                        ref.read(uiOverlayProvider.notifier).showToast(
                              'Help Burt Baskernut at Vendor Row to unlock Slow-Wave Sway!',
                            );
                      }
                    },
                  ),
                  _ActionChipButton(
                    buttonKey: const ValueKey('just_listen_button'),
                    icon: Icons.headphones_rounded,
                    label: 'Just Listen',
                    active: flags.justListenStageMode,
                    onTap: () => ref
                        .read(worldFlagsProvider.notifier)
                        .toggleJustListenMode(),
                  ),
                  _ActionChipButton(
                    buttonKey: const ValueKey('pure_vibe_button'),
                    icon: Icons.spa_outlined,
                    label: 'Pure Vibe',
                    active: clock.pureVibeMode,
                    onTap: () => ref
                        .read(festivalClockProvider.notifier)
                        .togglePureVibeMode(),
                  ),
                  if (clock.encoreModeUnlocked)
                    _ActionChipButton(
                      buttonKey: const ValueKey('encore_deck_button'),
                      icon: Icons.auto_awesome_rounded,
                      label: 'Encore Deck',
                      active: false,
                      onTap: () {
                        ref
                            .read(uiOverlayProvider.notifier)
                            .closePocketProgram();
                        ref
                            .read(uiOverlayProvider.notifier)
                            .openModal(ActiveModalOverlay.encoreDeck);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Day Filter Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (dayVal, dayTitle) in const [
                (0, 'All 30 Sets'),
                (1, 'Day 1 · Fri'),
                (2, 'Day 2 · Sat'),
                (3, 'Day 3 · Sun'),
              ]) ...[
                if (dayVal > 0) const SizedBox(width: 6),
                ChoiceChip(
                  label: Text(
                    dayTitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  selected: _selectedDayFilter == dayVal,
                  selectedColor: const Color(0xFFE9C46A),
                  backgroundColor: const Color(0xFF2D1E14),
                  labelStyle: TextStyle(
                    color: _selectedDayFilter == dayVal
                        ? const Color(0xFF1E120A)
                        : const Color(0xFFF4E3C1),
                  ),
                  onSelected: (_) =>
                      setState(() => _selectedDayFilter = dayVal),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 30 Scheduled Sets Cards
        for (final track in filteredTracks)
          _buildTrackCard(
            track: track,
            stage: data.setlist.stages[track.stageId],
            isLive: activeIds.contains(track.id),
            isStamped: journal.stampedTrackNumbers.contains(track.trackNumber),
          ),
      ],
    );
  }

  Widget _buildTrackCard({
    required ScheduledTrack track,
    required StageInfo? stage,
    required bool isLive,
    required bool isStamped,
  }) {
    final stageName = stage?.name ?? track.stageId;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isLive ? const Color(0xFF332211) : const Color(0xFF1B120C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLive ? const Color(0xFFFFBE0B) : const Color(0x44B08968),
          width: isLive ? 1.6 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isLive ? const Color(0xFFFFBE0B) : const Color(0xFF2D1E14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#${track.trackNumber}',
              style: TextStyle(
                color:
                    isLive ? const Color(0xFF1E120A) : const Color(0xFFFFD166),
                fontWeight: FontWeight.w900,
                fontSize: 11.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isLive) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFBE0B),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Color(0xFF1B1008),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFFFF3D6),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (isStamped)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.verified_rounded,
                          size: 15,
                          color: Color(0xFF74C69D),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${track.artist} · $stageName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD8C3A5),
                    fontSize: 11.5,
                  ),
                ),
                Text(
                  'Day ${track.day} · ${_formatMinute(track.startMinute)} – ${_formatMinute(track.endMinute)}',
                  style: const TextStyle(
                    color: Color(0xFF95D5B2),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (stage != null && stage.id != 'pa_global_horn') ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Walk to $stageName',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF2E2015),
                minimumSize: const Size(38, 38),
              ),
              icon: const Icon(
                Icons.directions_walk_rounded,
                size: 18,
                color: Color(0xFFFFD166),
              ),
              onPressed: () => _walkPlayerTo(stage.x, stage.y, stageName),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: ORCHARD MAP + STAGE SHORTCUTS + VIBE JOURNAL / QUESTS
  // ---------------------------------------------------------------------------
  Widget _buildMapTab(
    BuildContext context, {
    required FestivalDataBundle data,
    required PlayerProfile profile,
    required WorldFlags flags,
    required JournalState journal,
    required bool isCompact,
  }) {
    final pX = widget.game.player?.position.x ?? profile.savedX;
    final pY = widget.game.player?.position.y ?? profile.savedY;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '📍 ${profile.activeZoneName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF95D5B2),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Text(
              'Tap anywhere on map to walk',
              style: TextStyle(
                color: Color(0xFFB7A99A),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OrchardProgramMapView(
          playerX: pX,
          playerY: pY,
          onSelectWorldPoint: (wx, wy) =>
              _walkPlayerTo(wx, wy, 'selected orchard grove'),
        ),
        const SizedBox(height: 10),
        const Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _MapLegendDot(color: Color(0xFFFF595E), label: 'You'),
            _MapLegendDot(color: Color(0xFFFFBE0B), label: 'Live Stage'),
            _MapLegendDot(
              color: Color(0xFFE9C46A),
              label: 'Cultivar Discovered',
            ),
            _MapLegendDot(color: Color(0xFFFFD166), label: 'Pinned Quest'),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'QUICK WALK TO CONCERT STAGES',
          style: TextStyle(
            color: Color(0xFFE0A96D),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final st in data.setlist.stages.values)
              if (st.id != 'pa_global_horn')
                _ActionChipButton(
                  buttonKey: ValueKey('walk_stage_${st.id}'),
                  icon: Icons.place_outlined,
                  label: st.name.replaceAll(' Stage', ''),
                  active: false,
                  onTap: () => _walkPlayerTo(st.x, st.y, st.name),
                ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              key: const ValueKey('open_journal_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3D2818),
                foregroundColor: const Color(0xFFFFD166),
                side: const BorderSide(color: Color(0xFFD49A5A)),
              ),
              onPressed: () {
                ref.read(uiOverlayProvider.notifier).closePocketProgram();
                ref.read(journalStateProvider.notifier).openJournal();
              },
              icon: const Icon(Icons.menu_book_rounded, size: 17),
              label: Text(
                'Scrapbook, Satchel & Quests (${flags.completedQuestCount}/${data.quests.length})',
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('map_return_gate_button'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF4E3C1),
                side: const BorderSide(color: Color(0x88D49A5A)),
              ),
              onPressed: () {
                widget.game.teleportPlayer(608.0, 1344.0);
                ref.read(uiOverlayProvider.notifier).closePocketProgram();
                ref.read(uiOverlayProvider.notifier).showToast(
                      '⛩️ Returned to the Walnutstock Orchard Gate!',
                    );
              },
              icon: const Icon(Icons.door_sliding_outlined, size: 17),
              label: const Text('Return to Orchard Gate'),
            ),
          ],
        ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: CULTIVAR POUCH (x/11) + WARDROBE + AUDIO MIX & SAVE BOOTH
  // ---------------------------------------------------------------------------
  Widget _buildCultivarAndMixTab(
    BuildContext context, {
    required FestivalDataBundle data,
    required PlayerProfile profile,
    required FestivalClockState clock,
    required WorldFlags flags,
    required JournalState journal,
    required bool isCompact,
  }) {
    final settings = ref.watch(settingsProvider);
    final settingsN = ref.read(settingsProvider.notifier);
    final equippedSpec = journal.equippedGadgetId != null
        ? data.itemById(journal.equippedGadgetId!)
        : null;

    final groveById = <String, HeritageCultivarTreeSpot>{
      for (final s in OrchardGateLayout.heritageCultivarSpots) s.cultivarId: s,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        // 1. Heritage Walnut Cultivar Pouch (x/11)
        Row(
          children: [
            Expanded(
              child: Text(
                'HERITAGE CULTIVAR POUCH (${profile.discoveredCultivarIds.length}/11)',
                style: const TextStyle(
                  color: Color(0xFFFFD166),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
            ),
            Text(
              'Tap any cultivar to embody',
              style: TextStyle(
                color: const Color(0xFFB7A99A),
                fontSize: isCompact ? 10.5 : 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final cultivar in data.cultivars)
          _buildCultivarRow(
            cultivar: cultivar,
            spot: groveById[cultivar.id],
            selected: profile.cultivarId == cultivar.id,
            discovered: profile.discoveredCultivarIds.contains(cultivar.id),
          ),

        const SizedBox(height: 14),
        const Divider(color: Color(0x44D49A5A)),
        const SizedBox(height: 10),

        // 2. 1969 Wardrobe & Satchel Quick Gadget
        Row(
          children: [
            const Expanded(
              child: Text(
                '1969 FESTIVAL WARDROBE & SATCHEL',
                style: TextStyle(
                  color: Color(0xFFFFD166),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
            ),
            _ActionChipButton(
              buttonKey: const ValueKey('quick_item_button'),
              icon: equippedSpec != null
                  ? Icons.auto_fix_high_rounded
                  : Icons.backpack_outlined,
              label: equippedSpec != null
                  ? '${equippedSpec.icon} Use ${equippedSpec.name}'
                  : 'Open Satchel',
              active: false,
              onTap: () {
                ref.read(uiOverlayProvider.notifier).closePocketProgram();
                if (equippedSpec != null) {
                  widget.game.useEquippedFestivalItem();
                } else {
                  ref
                      .read(journalStateProvider.notifier)
                      .openJournal(tabIndex: 4);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final item in data.wardrobe)
              if (profile.unlockedWardrobeIds.contains(item.id))
                ChoiceChip(
                  key: ValueKey('outfit_chip_${item.id}'),
                  label: Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  selected: profile.equippedWardrobeId == item.id,
                  selectedColor: const Color(0xFF52B788),
                  backgroundColor: const Color(0xFF2B1C12),
                  labelStyle: TextStyle(
                    color: profile.equippedWardrobeId == item.id
                        ? const Color(0xFF081C15)
                        : const Color(0xFFF4E3C1),
                  ),
                  onSelected: (_) {
                    ref
                        .read(playerProfileProvider.notifier)
                        .equipWardrobe(item.id);
                    unawaited(persistCurrentGameState(ref));
                  },
                ),
          ],
        ),

        const SizedBox(height: 14),
        const Divider(color: Color(0x44D49A5A)),
        const SizedBox(height: 10),

        // 3. Audio Mix & Accessibility Sliders
        const Text(
          'AUDIO MIX & ACCESSIBILITY BOOTH',
          style: TextStyle(
            color: Color(0xFFFFD166),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        _CompactSliderRow(
          label: 'Master Mix',
          value: settings.masterVolume,
          onChanged: settingsN.setMasterVolume,
        ),
        _CompactSliderRow(
          label: 'Stage Music',
          value: settings.musicVolume,
          onChanged: settingsN.setMusicVolume,
        ),
        _CompactSliderRow(
          label: 'Orchard SFX',
          value: settings.sfxVolume,
          onChanged: settingsN.setSfxVolume,
        ),
        _CompactSliderRow(
          label: '1969 Shaders',
          value: settings.shaderIntensity,
          onChanged: settingsN.setShaderIntensity,
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            '5-Minute Stage Bell Alerts',
            style: TextStyle(color: Color(0xFFF4E3C1), fontSize: 12.5),
          ),
          value: clock.wristbandAlertsEnabled,
          onChanged: (_) =>
              ref.read(festivalClockProvider.notifier).toggleWristbandAlerts(),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Undergrowth Fog Shimmer Compass',
            style: TextStyle(color: Color(0xFFF4E3C1), fontSize: 12.5),
          ),
          value: settings.fogVisualAssist,
          onChanged: (_) => settingsN.toggleFogVisualAssist(),
        ),

        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              key: const ValueKey('program_save_now_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D6A4F),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await persistCurrentGameState(ref);
                ref.read(uiOverlayProvider.notifier).showToast(
                      '💾 Saved orchard progress!',
                    );
              },
              icon: const Icon(Icons.save_outlined, size: 17),
              label: const Text('Save Progress'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                ref.read(uiOverlayProvider.notifier).closePocketProgram();
                ref
                    .read(uiOverlayProvider.notifier)
                    .openModal(ActiveModalOverlay.finaleMontage);
              },
              icon: const Icon(Icons.auto_awesome_outlined, size: 17),
              label: const Text('Credits'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('program_reset_save_button'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _confirmingReset
                    ? const Color(0xFFFF6B6B)
                    : const Color(0xFFD8C3A5),
                side: BorderSide(
                  color: _confirmingReset
                      ? const Color(0xFFFF6B6B)
                      : const Color(0x66B08968),
                ),
              ),
              onPressed: () async {
                if (!_confirmingReset) {
                  setState(() => _confirmingReset = true);
                  return;
                }
                await ref.read(saveRepositoryProvider).clearPrimary();
                ref
                    .read(playerProfileProvider.notifier)
                    .hydrate(const PlayerProfile(
                      ticketTorn: true,
                      cultivarConfirmed: true,
                    ));
                ref
                    .read(worldFlagsProvider.notifier)
                    .hydrate(const WorldFlags());
                ref
                    .read(journalStateProvider.notifier)
                    .hydrate(const JournalState());
                widget.game.teleportPlayer(608.0, 1344.0);
                setState(() => _confirmingReset = false);
                ref.read(uiOverlayProvider.notifier).closePocketProgram();
                ref.read(uiOverlayProvider.notifier).showToast(
                      '🌱 Fresh 1969 Festival Pass started at the Orchard Gate!',
                    );
              },
              icon: const Icon(Icons.restart_alt_rounded, size: 17),
              label: Text(
                _confirmingReset ? 'Tap Again to Confirm Reset' : 'Reset Save',
              ),
            ),
          ],
        ),
        ],
      ),
    );
  }

  Widget _buildCultivarRow({
    required CultivarSpec cultivar,
    required HeritageCultivarTreeSpot? spot,
    required bool selected,
    required bool discovered,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: selected ? const Color(0xFF382414) : const Color(0xFF1A110B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected
                ? const Color(0xFFFFD166)
                : (discovered
                    ? const Color(0x8874C69D)
                    : const Color(0x38B08968)),
            width: selected ? 1.8 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('cultivar_chip_${cultivar.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            unawaited(widget.game.audioService.unlockAndInitialize());
            ref
                .read(playerProfileProvider.notifier)
                .selectCultivar(cultivar.id);
            unawaited(persistCurrentGameState(ref));
            ref.read(uiOverlayProvider.notifier).showToast(
                  '🌰 Playing as ${cultivar.name} — ${cultivar.tagline}',
                );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 38,
                  height: 38,
                  color: const Color(0xFF2B1B10),
                  child: Image.asset(
                    cultivar.portraitAsset,
                    filterQuality: FilterQuality.none,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cultivar.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFFFF3D6),
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFFFD166)
                                : (discovered
                                    ? const Color(0x3352B788)
                                    : const Color(0x22FFFFFF)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            selected
                                ? 'ACTIVE'
                                : (discovered ? 'FOUND ✓' : 'IN ORCHARD'),
                            style: TextStyle(
                              color: selected
                                  ? const Color(0xFF1E120A)
                                  : (discovered
                                      ? const Color(0xFF95D5B2)
                                      : const Color(0xFFB7A99A)),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${cultivar.shellShape} · ${cultivar.flavorNotes}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFD8C3A5),
                        fontSize: 11,
                      ),
                    ),
                    if (spot != null)
                      Text(
                        'Grove: ${spot.groveLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF95D5B2),
                          fontSize: 10.5,
                        ),
                      ),
                  ],
                ),
              ),
              if (spot != null && !discovered) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Walk to ${spot.groveLabel}',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.explore_outlined,
                    size: 18,
                    color: Color(0xFFFFD166),
                  ),
                  onPressed: () =>
                      _walkPlayerTo(spot.x, spot.y, spot.groveLabel),
                ),
              ],
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _ProgramTabPill extends StatelessWidget {
  const _ProgramTabPill({
    required this.tabKey,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key tabKey;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE9C46A) : const Color(0xFF2D1E14),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: tabKey,
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 42),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: selected
                      ? const Color(0xFF1E120A)
                      : const Color(0xFFFFD166),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF1E120A)
                          : const Color(0xFFF4E3C1),
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                    ),
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

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? const Color(0xFF52B788) : const Color(0xFF2A1C12),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: buttonKey,
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? const Color(0xFFD8F3DC) : const Color(0x88B08968),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
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
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapLegendDot extends StatelessWidget {
  const _MapLegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFD8C3A5), fontSize: 11),
        ),
      ],
    );
  }
}

class _CompactSliderRow extends StatelessWidget {
  const _CompactSliderRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            '$label ${(value * 100).round()}%',
            style: const TextStyle(
              color: Color(0xFFF4E3C1),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value,
              activeColor: const Color(0xFFE9C46A),
              inactiveColor: const Color(0x44D49A5A),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// Day/Night + Storm progression bar embedded in the Pocket Program Setlist header.
class ProgramSkyProgressionBar extends StatelessWidget {
  const ProgramSkyProgressionBar({
    super.key,
    required this.clock,
  });

  final FestivalClockState clock;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 8,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final pipX = (w * clock.dayArcProgress)
              .clamp(4.0, (w - 4.0).clamp(4.0, double.infinity));
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 6,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF9671),
                      Color(0xFF74C69D),
                      Color(0xFF4CC9F0),
                      Color(0xFFFF9E00),
                      Color(0xFF7B2CBF),
                      Color(0xFF1D1E4E),
                    ],
                    stops: [0.0, 0.14, 0.36, 0.56, 0.67, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: pipX - 4.0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFF3B0),
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
