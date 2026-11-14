// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/walnutstock_game.dart';
import '../state/dialogue_and_overlay_state.dart';
import '../state/festival_clock.dart';
import '../state/providers.dart';

class EncoreControlDeck extends ConsumerWidget {
  const EncoreControlDeck({
    super.key,
    required this.game,
  });

  final WalnutstockGame game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clock = ref.watch(festivalClockProvider);
    final clockN = ref.read(festivalClockProvider.notifier);
    final data = ref.watch(festivalDataProvider);
    final maxMin = clockN.dayEndMinuteFor(clock.day);

    final maxDeckHeight =
        (MediaQuery.sizeOf(context).height - 32.0).clamp(180.0, 640.0);

    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 380, maxHeight: maxDeckHeight),
          child: Container(
            key: const ValueKey('encore_control_deck'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xF21B1328),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF9D4EDD), width: 2),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '✨ ENDLESS ENCORE FREE-ROAM DECK',
                          style: TextStyle(
                            color: Color(0xFFE0AAFF),
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Color(0xFFF4E3C1), size: 18),
                        onPressed: () =>
                            ref.read(uiOverlayProvider.notifier).closeModal(),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final d in [1, 2, 3])
                        ChoiceChip(
                          label: Text('Day $d',
                              style: const TextStyle(fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                          selected: clock.day == d,
                          selectedColor: const Color(0xFF9D4EDD),
                          onSelected: (_) => clockN.setClockDirect(
                            day: d,
                            minuteOfDay: clock.minuteOfDay,
                          ),
                        ),
                      IconButton(
                        tooltip:
                            clock.clockPaused ? 'Resume Clock' : 'Lock Time',
                        icon: Icon(
                          clock.clockPaused ? Icons.play_arrow : Icons.pause,
                          color: const Color(0xFF80FFDB),
                        ),
                        onPressed: clockN.toggleClockPaused,
                      ),
                    ],
                  ),
                  Slider(
                    value: clock.minuteOfDay.clamp(300.0, maxMin),
                    min: 300.0,
                    max: maxMin,
                    activeColor: const Color(0xFFFFD166),
                    onChanged: (v) =>
                        clockN.setClockDirect(day: clock.day, minuteOfDay: v),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        label: const Text('🌅 Dawn',
                            style: TextStyle(fontSize: 11)),
                        onPressed: () => clockN.setClockDirect(
                            day: clock.day, minuteOfDay: 350.0),
                      ),
                      ActionChip(
                        label: const Text('🌇 Golden Hr',
                            style: TextStyle(fontSize: 11)),
                        onPressed: () => clockN.setClockDirect(
                            day: clock.day, minuteOfDay: 1080.0),
                      ),
                      ActionChip(
                        label: const Text('🌙 Night',
                            style: TextStyle(fontSize: 11)),
                        onPressed: () => clockN.setClockDirect(
                            day: clock.day, minuteOfDay: 1380.0),
                      ),
                      ActionChip(
                        label: const Text('Auto Weather',
                            style: TextStyle(fontSize: 11)),
                        onPressed: () => clockN.setWeatherOverride(null),
                      ),
                      ActionChip(
                        label: const Text('🌥️ Pre-Storm',
                            style: TextStyle(fontSize: 11)),
                        onPressed: () => clockN
                            .setWeatherOverride(WeatherPhase.preStormHumid),
                      ),
                      ActionChip(
                        label: const Text('🌧️ Storm',
                            style: TextStyle(fontSize: 11)),
                        onPressed: () => clockN
                            .setWeatherOverride(WeatherPhase.blightRainstorm),
                      ),
                      ActionChip(
                        label: const Text('🌦️ D1 Set 7 Rain',
                            style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          clockN.setWeatherOverride(null);
                          clockN.restUntilDay1RainRamp();
                        },
                      ),
                      ActionChip(
                        label: const Text('🛝 Post-Set-8 Mud',
                            style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          clockN.setWeatherOverride(null);
                          clockN.restUntilMudExperience();
                          game.teleportPlayer(312.0, 578.0);
                        },
                      ),
                      ActionChip(
                        label: const Text('🫐 D2 Creek Berries',
                            style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          clockN.restUntilDay2Blueberries();
                          game.teleportPlayer(1096.0, 520.0);
                        },
                      ),
                      ActionChip(
                        label: const Text('🌈 Electric Berry',
                            style: TextStyle(fontSize: 11)),
                        onPressed: () => clockN.setShaderOverride(
                          clock.shaderOverride == 'electric_blueberry'
                              ? null
                              : 'electric_blueberry',
                        ),
                      ),
                      ActionChip(
                        label: const Text('🔮 Walnut Trip',
                            style: TextStyle(fontSize: 11)),
                        onPressed: () => clockN.setShaderOverride(
                          clock.shaderOverride == 'walnut_trip'
                              ? null
                              : 'walnut_trip',
                        ),
                      ),
                      ActionChip(
                        label: const Text('💜 Purple Haze',
                            style: TextStyle(fontSize: 11)),
                        onPressed: () => clockN.setShaderOverride(
                          clock.shaderOverride == 'purple_haze'
                              ? null
                              : 'purple_haze',
                        ),
                      ),
                      ActionChip(
                        label: const Text('💿 Open Vinyl Jukebox',
                            style: TextStyle(fontSize: 11)),
                        onPressed: () => ref
                            .read(uiOverlayProvider.notifier)
                            .openModal(ActiveModalOverlay.turntable),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final s in data.setlist.stages.values)
                          if (s.id != 'pa_global_horn')
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: OutlinedButton(
                                onPressed: () =>
                                    game.teleportPlayer(s.x, s.y + 42.0),
                                child: Text(
                                  s.name,
                                  style: const TextStyle(fontSize: 11),
                                ),
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
      ),
    );
  }
}
