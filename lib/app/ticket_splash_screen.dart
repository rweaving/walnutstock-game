// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/soloud_audio_service.dart';
import '../state/providers.dart';

class TicketSplashScreen extends ConsumerWidget {
  const TicketSplashScreen({
    super.key,
    required this.audioService,
  });

  final SoloudAudioService audioService;

  Future<void> _unlockAudioAndStartNew(WidgetRef ref) async {
    await audioService.unlockAndInitialize();
    await audioService.playSfx(
      'assets/audio/sfx/sfx_ticket_tear.wav',
      volume: 0.75,
    );
    ref.read(playerProfileProvider.notifier).tearTicket();
  }

  Future<void> _resumeSavedFestival(WidgetRef ref) async {
    await audioService.unlockAndInitialize();
    await audioService.playSfx(
      'assets/audio/sfx/sfx_ticket_tear.wav',
      volume: 0.75,
    );
    final saved = ref.read(saveRepositoryProvider).loadPrimary();
    if (saved != null) {
      ref.read(playerProfileProvider.notifier).hydrate(
            saved.profile.copyWith(ticketTorn: true, cultivarConfirmed: true),
          );
      ref.read(festivalClockProvider.notifier).hydrate(saved.clock);
      ref.read(worldFlagsProvider.notifier).hydrate(saved.flags);
      ref.read(journalStateProvider.notifier).hydrate(saved.journal);
      ref.read(settingsProvider.notifier).hydrate(saved.settings);
    } else {
      ref.read(playerProfileProvider.notifier).tearTicket();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saveRepo = ref.watch(saveRepositoryProvider);
    final hasSave = saveRepo.hasPrimarySave;
    final screenW = MediaQuery.sizeOf(context).width;
    final isMobile = screenW < 520;

    return Scaffold(
      backgroundColor: const Color(0xFF19110B),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.25),
            radius: 1.15,
            colors: [
              Color(0xFF432915),
              Color(0xFF24160D),
              Color(0xFF140C07),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 18,
                vertical: isMobile ? 10 : 14,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 14 : 22,
                    isMobile ? 14 : 18,
                    isMobile ? 14 : 22,
                    isMobile ? 16 : 20,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFF8EBD0),
                        Color(0xFFF0D9B0),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF8C5832),
                      width: 3,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 28,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Vintage Ticket Serial & Gate Header
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2B180A),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PASS #0815-1969',
                              style: TextStyle(
                                color: Color(0xFFFFD166),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                          const Text(
                            'MAX YASGUR-SHELL’S FREE ORCHARD',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF6E4423),
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D6A4F),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '3-DAY ALL ACCESS',
                              style: TextStyle(
                                color: Color(0xFFFFF8E7),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.9,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'WALNUTSTOCK',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF2B180A),
                          fontSize: isMobile ? 27 : 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: isMobile ? 1.8 : 2.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'THREE DAYS OF PEACE, SHELLS, OUTFITS & LIVE MUSIC',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF9B2226),
                          fontSize: isMobile ? 12.5 : 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const _PerforatedDivider(),
                      const SizedBox(height: 10),

                      // 4-Card Onboarding Festival Highlights Grid
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 480;
                          const cards = [
                            _FestivalHighlightBadge(
                              icon: Icons.album_rounded,
                              accent: Color(0xFF9B2226),
                              title: '5 Stages · 30 Live Sets',
                              detail:
                                  'Walk between bands with spatial stereo sound, beat-synced lights & unique artists.',
                            ),
                            _FestivalHighlightBadge(
                              icon: Icons.checkroom_rounded,
                              accent: Color(0xFF7209B7),
                              title: '11 Cultivars & Outfits',
                              detail:
                                  'Pick distinct walnut shells—Heartnut, Red Livermore, Butternut—and 1969 outfits.',
                            ),
                            _FestivalHighlightBadge(
                              icon: Icons.music_note_rounded,
                              accent: Color(0xFF2D6A4F),
                              title: 'Crowd & Player Dancing',
                              detail:
                                  '34 orchard characters dance near live stages—tap Dance [B] to groove on the beat!',
                            ),
                            _FestivalHighlightBadge(
                              icon: Icons.thunderstorm_rounded,
                              accent: Color(0xFF1D3557),
                              title: 'Mud Pit & Blueberries',
                              detail:
                                  'Slide in Friday’s post-rain Mud Pit & share Day 2 Creekside Electric Blueberries!',
                            ),
                          ];
                          if (wide) {
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: cards[0]),
                                    const SizedBox(width: 8),
                                    Expanded(child: cards[1]),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: cards[2]),
                                    const SizedBox(width: 8),
                                    Expanded(child: cards[3]),
                                  ],
                                ),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              for (var i = 0; i < cards.length; i++) ...[
                                if (i > 0) const SizedBox(height: 6),
                                cards[i],
                              ],
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 10),
                      // Quick Controls Onboarding Bar
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6CCA0),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFB08968)),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 6,
                          children: isMobile
                              ? const [
                                  _ControlHintPill(
                                    keys: 'D-Pad / Tap',
                                    action: 'Roam',
                                  ),
                                  _ControlHintPill(
                                    keys: 'B / Dance',
                                    action: 'Groove',
                                  ),
                                  _ControlHintPill(
                                    keys: 'A / Tap',
                                    action: 'Chat & Act',
                                  ),
                                  _ControlHintPill(
                                    keys: 'Journal',
                                    action: 'Setlist',
                                  ),
                                ]
                              : const [
                                  _ControlHintPill(
                                    keys: 'WASD / Tap',
                                    action: 'Roam',
                                  ),
                                  _ControlHintPill(
                                    keys: 'B / Dance',
                                    action: 'Sync Groove',
                                  ),
                                  _ControlHintPill(
                                    keys: 'N',
                                    action: 'Switch Move',
                                  ),
                                  _ControlHintPill(
                                    keys: 'E / Space',
                                    action: 'Chat',
                                  ),
                                  _ControlHintPill(
                                    keys: 'Tab',
                                    action: 'Journal',
                                  ),
                                ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          key: const ValueKey('tear_ticket_button'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9B2226),
                            foregroundColor: const Color(0xFFFFF8E7),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _unlockAudioAndStartNew(ref),
                          icon: const Icon(Icons.confirmation_number_outlined),
                          label: Text(
                            isMobile
                                ? 'TEAR TICKET & CUSTOMIZE WALNUT'
                                : 'TEAR TICKET STUB & CUSTOMIZE YOUR WALNUT',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                      if (hasSave) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            key: const ValueKey('resume_tent_save_button'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2D6A4F),
                              side: const BorderSide(
                                color: Color(0xFF2D6A4F),
                                width: 2,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => _resumeSavedFestival(ref),
                            icon: const Icon(Icons.night_shelter_outlined),
                            label: const Text(
                              'RESUME SAVED TENT SESSION',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PerforatedDivider extends StatelessWidget {
  const _PerforatedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dashCount = (constraints.maxWidth / 12).floor().clamp(8, 60);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            dashCount,
            (_) => Container(
              width: 6,
              height: 2,
              decoration: BoxDecoration(
                color: const Color(0xFFA47551),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FestivalHighlightBadge extends StatelessWidget {
  const _FestivalHighlightBadge({
    required this.icon,
    required this.accent,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFCF4E4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF2B180A),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    color: Color(0xFF5C3D28),
                    fontSize: 11.5,
                    height: 1.28,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlHintPill extends StatelessWidget {
  const _ControlHintPill({
    required this.keys,
    required this.action,
  });

  final String keys;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF2B180A),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            keys,
            style: const TextStyle(
              color: Color(0xFFFFD166),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          action,
          style: const TextStyle(
            color: Color(0xFF3D2512),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
