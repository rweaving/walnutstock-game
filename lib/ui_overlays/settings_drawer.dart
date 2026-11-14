// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/dialogue_and_overlay_state.dart';
import '../state/providers.dart';
import '../state/settings_state.dart';

class SettingsAccessibilityDrawer extends ConsumerWidget {
  const SettingsAccessibilityDrawer({super.key});

  static String _touchLayoutLabel(TouchControlsLayout layout) => switch (layout) {
        TouchControlsLayout.auto => 'Auto Touch',
        TouchControlsLayout.landscapeDpad => 'D-Pad + A/B',
        TouchControlsLayout.portraitGameBoy => 'Game Boy Deck',
        TouchControlsLayout.hidden => 'Hide Pads',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsN = ref.read(settingsProvider.notifier);
    final clock = ref.watch(festivalClockProvider);
    final clockN = ref.read(festivalClockProvider.notifier);
    final flags = ref.watch(worldFlagsProvider);
    final screen = MediaQuery.sizeOf(context);
    final maxModalH = (screen.height - 24.0).clamp(220.0, 540.0);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 440, maxHeight: maxModalH),
          child: Container(
            key: const ValueKey('settings_accessibility_modal'),
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xF522170F),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD49A5A), width: 2),
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
                        'SANCTUARY AUDIO, SHADER & ACCESSIBILITY OPTIONS',
                        style: TextStyle(
                          color: Color(0xFFFFD166),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
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
                SwitchListTile(
                  dense: true,
                  title: const Text(
                    'Pure Vibe / Auto-Groove Mode',
                    style: TextStyle(color: Color(0xFFF4E3C1), fontSize: 13),
                  ),
                  subtitle: const Text(
                    'Zero-stress auto-assist in Pinball, Sorting Belt & Stage Sway',
                    style: TextStyle(color: Color(0xFFB7A99A), fontSize: 11),
                  ),
                  value: clock.pureVibeMode,
                  onChanged: clockN.setPureVibeMode,
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text(
                    '"Just Listen" Concert Camera Mode',
                    style: TextStyle(color: Color(0xFFF4E3C1), fontSize: 13),
                  ),
                  value: flags.justListenStageMode,
                  onChanged: (_) => ref
                      .read(worldFlagsProvider.notifier)
                      .toggleJustListenMode(),
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text(
                    '5-Minute Stage Bell Wristband Alerts',
                    style: TextStyle(color: Color(0xFFF4E3C1), fontSize: 13),
                  ),
                  value: clock.wristbandAlertsEnabled,
                  onChanged: (_) => clockN.toggleWristbandAlerts(),
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text(
                    'Undergrowth Fog Shimmer Compass',
                    style: TextStyle(color: Color(0xFFF4E3C1), fontSize: 13),
                  ),
                  value: settings.fogVisualAssist,
                  onChanged: (_) => settingsN.toggleFogVisualAssist(),
                ),
                const SizedBox(height: 6),
                Text(
                  'Psychedelic Shader Intensity: ${(settings.shaderIntensity * 100).round()}%',
                  style:
                      const TextStyle(color: Color(0xFF80FFDB), fontSize: 12),
                ),
                Slider(
                  value: settings.shaderIntensity,
                  onChanged: settingsN.setShaderIntensity,
                ),
                Text(
                  'Master Volume: ${(settings.masterVolume * 100).round()}%',
                  style:
                      const TextStyle(color: Color(0xFFFFD166), fontSize: 12),
                ),
                Slider(
                  value: settings.masterVolume,
                  onChanged: settingsN.setMasterVolume,
                ),
                Text(
                  'Music Volume: ${(settings.musicVolume * 100).round()}%',
                  style:
                      const TextStyle(color: Color(0xFFFFD166), fontSize: 12),
                ),
                Slider(
                  value: settings.musicVolume,
                  onChanged: settingsN.setMusicVolume,
                ),
                Text(
                  'SFX Volume: ${(settings.sfxVolume * 100).round()}%',
                  style:
                      const TextStyle(color: Color(0xFFFFD166), fontSize: 12),
                ),
                Slider(
                  value: settings.sfxVolume,
                  onChanged: settingsN.setSfxVolume,
                ),
                Text(
                  'Dialogue Text Speed: ${settings.textSpeedMultiplier.toStringAsFixed(1)}x',
                  style:
                      const TextStyle(color: Color(0xFFF4E3C1), fontSize: 12),
                ),
                Slider(
                  value: settings.textSpeedMultiplier,
                  min: 0.5,
                  max: 2.5,
                  onChanged: settingsN.setTextSpeed,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final layout in TouchControlsLayout.values)
                      ChoiceChip(
                        label: Text(
                          _touchLayoutLabel(layout),
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        selected: settings.touchLayout == layout,
                        onSelected: (_) => settingsN.setTouchLayout(layout),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        await persistCurrentGameState(ref);
                        ref.read(uiOverlayProvider.notifier).closeModal();
                        ref.read(uiOverlayProvider.notifier).showToast(
                              '💾 Saved festival progress to Tent Slot!',
                            );
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Progress Now'),
                    ),
                    OutlinedButton(
                      onPressed: () => ref
                          .read(uiOverlayProvider.notifier)
                          .openModal(ActiveModalOverlay.finaleMontage),
                      child: const Text('View Credits'),
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
