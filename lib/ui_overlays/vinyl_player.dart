import 'dart:math' as math;
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

class VinylTurntableModal extends ConsumerStatefulWidget {
  const VinylTurntableModal({super.key});

  @override
  ConsumerState<VinylTurntableModal> createState() =>
      _VinylTurntableModalState();
}

class _VinylTurntableModalState extends ConsumerState<VinylTurntableModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _platterController;

  @override
  void initState() {
    super.initState();
    _platterController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _platterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(festivalDataProvider);
    final journal = ref.watch(journalStateProvider);
    final clock = ref.watch(festivalClockProvider);
    final overlay = ref.watch(uiOverlayProvider);
    final settings = ref.watch(settingsProvider);

    final activeTrackNo = overlay.turntableTrackNumber;
    final unlockedVinyls = clock.encoreModeUnlocked
        ? data.vinyls.map((v) => v.id).toSet()
        : {...journal.collectedVinylIds, 'vinyl_side_a'};

    final screen = MediaQuery.sizeOf(context);
    final isCompact = screen.width < 460 || screen.height < 460;
    final maxModalHeight = (screen.height - 24.0).clamp(220.0, 520.0);
    final platterSize = isCompact ? 68.0 : 96.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 480, maxHeight: maxModalHeight),
          child: Container(
            key: const ValueKey('vinyl_turntable_modal'),
            width: double.infinity,
            padding: EdgeInsets.all(isCompact ? 14 : 18),
            decoration: BoxDecoration(
              color: const Color(0xF5211610),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE76F51), width: 2.5),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'CAMPGROUND DOUBLE-LP TURNTABLE',
                      style: TextStyle(
                        color: Color(0xFFFFD166),
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  FilterChip(
                    label:
                        const Text('Crackle', style: TextStyle(fontSize: 11)),
                    selected: settings.vinylCrackleEnabled,
                    selectedColor: const Color(0xFFE76F51),
                    onSelected: (_) => ref
                        .read(settingsProvider.notifier)
                        .toggleVinylCrackle(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFFF4E3C1)),
                    onPressed: () =>
                        ref.read(uiOverlayProvider.notifier).closeModal(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Spinning Platter + Tonearm
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _platterController,
                    builder: (context, child) {
                      final angle = activeTrackNo != null
                          ? _platterController.value * 2 * math.pi
                          : 0.0;
                      return Transform.rotate(angle: angle, child: child);
                    },
                    child: Container(
                      width: platterSize,
                      height: platterSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF141418),
                        border: Border.all(
                          color: const Color(0xFF3A3A48),
                          width: 4,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: isCompact ? 26 : 34,
                        height: isCompact ? 26 : 34,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE76F51),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.music_note,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeTrackNo != null
                              ? 'NOW SPINNING: Track #$activeTrackNo — ${data.setlist.trackByNumber(activeTrackNo)?.artist ?? ''} · ${data.setlist.trackByNumber(activeTrackNo)?.title ?? ''}'
                              : 'Select any unlocked Double-LP Side or Bootleg 45 cut:',
                          style: const TextStyle(
                            color: Color(0xFFF4E3C1),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (activeTrackNo != null)
                          OutlinedButton.icon(
                            onPressed: () => ref
                                .read(uiOverlayProvider.notifier)
                                .setTurntableTrack(null),
                            icon: const Icon(Icons.stop_circle_outlined,
                                size: 16),
                            label: const Text(
                                'Lift Tonearm (Return to Live Stages)'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF6E4423), height: 18),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final v in data.vinyls)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              unlockedVinyls.contains(v.id)
                                  ? '💿 ${v.title}'
                                  : '🔒 ${v.title} (${v.sourceHint})',
                              style: TextStyle(
                                color: unlockedVinyls.contains(v.id)
                                    ? const Color(0xFF80FFDB)
                                    : const Color(0xFF8C7A6B),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            if (unlockedVinyls.contains(v.id))
                              Wrap(
                                spacing: 6,
                                children: [
                                  for (final tNum in v.tracks)
                                    ActionChip(
                                      backgroundColor: activeTrackNo == tNum
                                          ? const Color(0xFFE76F51)
                                          : const Color(0xFF3A2618),
                                      label: Text(
                                        '#$tNum ${data.setlist.trackByNumber(tNum)?.title ?? ''}',
                                        style: const TextStyle(
                                          color: Color(0xFFF4E3C1),
                                          fontSize: 11,
                                        ),
                                      ),
                                      onPressed: () => ref
                                          .read(uiOverlayProvider.notifier)
                                          .setTurntableTrack(tNum),
                                    ),
                                ],
                              ),
                          ],
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
      ),
    );
  }
}

class TentRestModal extends ConsumerWidget {
  const TentRestModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maxModalHeight =
        (MediaQuery.sizeOf(context).height - 24.0).clamp(200.0, 560.0);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 396, maxHeight: maxModalHeight),
          child: Container(
            key: const ValueKey('campground_tent'),
            width: double.infinity,
            padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xF5241810),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF52B788), width: 2),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'SHADY BOTTOMS PERSONAL TENT',
                        style: TextStyle(
                          color: Color(0xFFFFD166),
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFFF4E3C1)),
                      onPressed: () =>
                          ref.read(uiOverlayProvider.notifier).closeModal(),
                    ),
                  ],
                ),
                const Text(
                  'Save your festival progress or rest smoothly to an upcoming time of day or weather event:',
                  style: TextStyle(color: Color(0xFFD9C398), fontSize: 12),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const ValueKey('rest_next_set'),
                    onPressed: () async {
                      final next = ref
                          .read(festivalClockProvider.notifier)
                          .jumpToNextScheduledSet();
                      await persistCurrentGameState(ref);
                      ref.read(uiOverlayProvider.notifier).closeModal();
                      if (next != null) {
                        ref.read(uiOverlayProvider.notifier).showToast(
                              '⛺ Saved & rested until #${next.trackNumber}: ${next.title}!',
                            );
                      }
                    },
                    icon: const Icon(Icons.music_note),
                    label: const Text('Save & Rest Until Next Live Set'),
                  ),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const ValueKey('rest_sunrise'),
                    onPressed: () async {
                      ref
                          .read(festivalClockProvider.notifier)
                          .restUntilSunrise();
                      await persistCurrentGameState(ref);
                      ref.read(uiOverlayProvider.notifier).closeModal();
                      ref.read(uiOverlayProvider.notifier).showToast(
                            '🌅 Rested until 5:05 AM Sunrise (Morning Dew sparkles in the Mellow Meadow!)',
                          );
                    },
                    icon: const Icon(Icons.wb_twilight),
                    label:
                        const Text('Rest Until 5:00 AM Sunrise (Morning Dew)'),
                  ),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const ValueKey('rest_golden_hour'),
                    onPressed: () async {
                      ref
                          .read(festivalClockProvider.notifier)
                          .restUntilGoldenHour();
                      await persistCurrentGameState(ref);
                      ref.read(uiOverlayProvider.notifier).closeModal();
                      ref.read(uiOverlayProvider.notifier).showToast(
                            '🌇 Rested until 6:00 PM Golden Hour — warm sunset shadows & lanterns glow!',
                          );
                    },
                    icon: const Icon(Icons.wb_sunny_outlined),
                    label: const Text(
                        'Rest Until 6:00 PM Golden Hour / Sunset'),
                  ),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const ValueKey('rest_starry_night'),
                    onPressed: () async {
                      ref
                          .read(festivalClockProvider.notifier)
                          .restUntilStarryNight();
                      await persistCurrentGameState(ref);
                      ref.read(uiOverlayProvider.notifier).closeModal();
                      ref.read(uiOverlayProvider.notifier).showToast(
                            '🌙 Rested until 10:00 PM Starry Night — stage spotlights & lanterns shine!',
                          );
                    },
                    icon: const Icon(Icons.nights_stay_outlined),
                    label: const Text('Rest Until 10:00 PM Starry Night'),
                  ),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const ValueKey('rest_mud_fest'),
                    onPressed: () async {
                      ref
                          .read(festivalClockProvider.notifier)
                          .restUntilMudExperience();
                      await persistCurrentGameState(ref);
                      ref.read(uiOverlayProvider.notifier).closeModal();
                      ref.read(uiOverlayProvider.notifier).showToast(
                            '🛝 Post-Set-8 Woodstock Mud Experience! Head to the Mud Pit to Belly-Slide & Toss Mudballs!',
                          );
                    },
                    icon: const Icon(Icons.downhill_skiing_rounded),
                    label: const Text(
                        'Jump to Post-Set-8 Mud Slide & Mud Fight'),
                  ),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const ValueKey('rest_day2_blueberries'),
                    onPressed: () async {
                      ref
                          .read(festivalClockProvider.notifier)
                          .restUntilDay2Blueberries();
                      await persistCurrentGameState(ref);
                      ref.read(uiOverlayProvider.notifier).closeModal();
                      ref.read(uiOverlayProvider.notifier).showToast(
                            '🫐🌅 Day 2 Sunrise! Head to Willow Creek & Meadow Stage for shared Electric Purple Blueberries!',
                          );
                    },
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text(
                        'Jump to Day 2 Dawn Creek Blueberries'),
                  ),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const ValueKey('rest_saturday_storm'),
                    onPressed: () async {
                      ref
                          .read(festivalClockProvider.notifier)
                          .restUntilSaturdayStorm();
                      await persistCurrentGameState(ref);
                      ref.read(uiOverlayProvider.notifier).closeModal();
                      ref.read(uiOverlayProvider.notifier).showToast(
                            "⛈️ Rested until Saturday's 'Bad Moon Risin'' Rainstorm!",
                          );
                    },
                    icon: const Icon(Icons.thunderstorm_outlined),
                    label: const Text(
                        'Jump to Saturday Dusk Storm & Arcade Night'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
        ),
      ),
    );
  }
}

class ArtifactBoothModal extends ConsumerWidget {
  const ArtifactBoothModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(festivalDataProvider);
    final journal = ref.watch(journalStateProvider);
    final maxModalHeight =
        (MediaQuery.sizeOf(context).height - 24.0).clamp(200.0, 520.0);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 440, maxHeight: maxModalHeight),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xF5241810),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF80FFDB), width: 2),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'VINTAGE VINYL & 3D ARTIFACT BOOTH',
                      style: TextStyle(
                        color: Color(0xFF80FFDB),
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFFF4E3C1)),
                    onPressed: () =>
                        ref.read(uiOverlayProvider.notifier).closeModal(),
                  ),
                ],
              ),
              Text(
                'Pedestal Display: ${journal.collectedTotemIds.length}/8 3D Totems · ${journal.collectedVinylIds.length}/6 Vinyls',
                style: const TextStyle(color: Color(0xFFFFD166), fontSize: 12),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (final t in data.totems)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF140E09),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: journal.collectedTotemIds.contains(t.id)
                                  ? const Color(0xFF80FFDB)
                                  : const Color(0xFF4A321F),
                            ),
                          ),
                          child: Opacity(
                            opacity: journal.collectedTotemIds.contains(t.id)
                                ? 1.0
                                : 0.2,
                            child: Image.asset(
                              t.sprite,
                              filterQuality: FilterQuality.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
              ),
        ),
      ),
        ),
      ),
    );
  }
}
