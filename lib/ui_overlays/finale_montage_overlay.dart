// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

class FinaleMontageOverlay extends ConsumerWidget {
  const FinaleMontageOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(playerProfileProvider);
    final journal = ref.watch(journalStateProvider);
    final data = ref.watch(festivalDataProvider);

    return Container(
      color: const Color(0xE8130B21),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          key: const ValueKey('finale_montage_modal'),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF241536),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFD166), width: 2.5),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'WALNUTSTOCK 1969 · FESTIVAL PHOTO-BOOK & CREDITS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFFFD166),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Three Days of Peace, Shells & Music — Guest: ${profile.guestName}',
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Color(0xFFE0AAFF), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _PolaroidCard(
                        portrait:
                            'assets/images/characters/npc_patchouli_pete_portrait.png',
                        caption: 'Day 1: The Fences Come Down!',
                      ),
                      _PolaroidCard(
                        portrait:
                            'assets/images/characters/npc_janice_joeplant_portrait.png',
                        caption: 'Day 2: Velvet Canopy Moss-Bloom',
                      ),
                      _PolaroidCard(
                        portrait:
                            'assets/images/characters/npc_cosmo_shellvoy_portrait.png',
                        caption: 'Midnight: Astral Geodesic Bass',
                      ),
                      _PolaroidCard(
                        portrait:
                            'assets/images/characters/npc_jimi_hendshell_portrait.png',
                        caption: 'Day 3: Purple Haze of Walnut Dust',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Festival Memories Logged: ${journal.metNpcIds.length}/${data.npcs.length} Guests Met · '
                    '${journal.coreAlbumStampedCount}/26 Tracks Stamped · '
                    '${journal.collectedTotemIds.length}/8 3D Totems',
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Color(0xFF80FFDB), fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Original 26-Track Live Soundtrack & World Motif ("I think of walnuts")\n'
                    'by LITERALLY INFINITE\n'
                    'Engineered with Flutter · Flame 2D · SoLoud Spatial Audio',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFD9C398),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      key: const ValueKey('enter_endless_encore_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9D4EDD),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        ref
                            .read(festivalClockProvider.notifier)
                            .unlockEncoreMode();
                        ref.read(journalStateProvider.notifier).unlockAllVinyls(
                              data.vinyls.map((v) => v.id),
                            );
                        await persistCurrentGameState(ref);
                        ref.read(uiOverlayProvider.notifier).closeModal();
                        ref.read(uiOverlayProvider.notifier).showToast(
                              '✨ ENDLESS ENCORE MODE UNLOCKED! Full Time/Weather/Shader & Anywhere Vinyl Jukebox enabled!',
                            );
                      },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text(
                        'UNLOCK ENDLESS ENCORE FREE-ROAM & FULL VINYL JUKEBOX',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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

class _PolaroidCard extends StatelessWidget {
  const _PolaroidCard({
    required this.portrait,
    required this.caption,
  });

  final String portrait;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 124,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F1E5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Image.asset(portrait, filterQuality: FilterQuality.none),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF2B180A),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
