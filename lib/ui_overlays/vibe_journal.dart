import 'dart:math' as math;
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../state/providers.dart';

class VibeJournalModal extends ConsumerStatefulWidget {
  const VibeJournalModal({super.key});

  @override
  ConsumerState<VibeJournalModal> createState() => _VibeJournalModalState();
}

class _VibeJournalModalState extends ConsumerState<VibeJournalModal> {
  double _totemSpinRadians = 0.25;

  @override
  Widget build(BuildContext context) {
    final journal = ref.watch(journalStateProvider);
    final profile = ref.watch(playerProfileProvider);
    final data = ref.watch(festivalDataProvider);
    final clock = ref.watch(festivalClockProvider);

    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 740, maxHeight: 540),
        child: Container(
          key: const ValueKey('vibe_journal_modal'),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF261A11),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD49A5A), width: 2.5),
            boxShadow: const [
              BoxShadow(color: Colors.black87, blurRadius: 24),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'WALNUTSTOCK LINEUP & VIBE JOURNAL',
                        style: TextStyle(
                          color: Color(0xFFFFD166),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('close_journal_button'),
                      icon: const Icon(Icons.close, color: Color(0xFFF4E3C1)),
                      onPressed: () => ref
                          .read(journalStateProvider.notifier)
                          .closeJournal(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _TabButton(
                      tabKey: const ValueKey('journal_tab_roster'),
                      label:
                          'Roster (${journal.metNpcIds.length}/${data.npcs.length})',
                      selected: journal.activeTabIndex == 0,
                      onTap: () =>
                          ref.read(journalStateProvider.notifier).setTab(0),
                    ),
                    _TabButton(
                      tabKey: const ValueKey('journal_tab_setlist'),
                      label: 'Setlist (${journal.coreAlbumStampedCount}/26)',
                      selected: journal.activeTabIndex == 1,
                      onTap: () =>
                          ref.read(journalStateProvider.notifier).setTab(1),
                    ),
                    _TabButton(
                      tabKey: const ValueKey('journal_tab_wardrobe'),
                      label:
                          'Wardrobe (${profile.unlockedWardrobeIds.length}/${data.wardrobe.length})',
                      selected: journal.activeTabIndex == 2,
                      onTap: () =>
                          ref.read(journalStateProvider.notifier).setTab(2),
                    ),
                    _TabButton(
                      tabKey: const ValueKey('journal_tab_collectibles'),
                      label:
                          'Vinyl & 3D Totems (${journal.collectedTotemIds.length}/8)',
                      selected: journal.activeTabIndex == 3,
                      onTap: () =>
                          ref.read(journalStateProvider.notifier).setTab(3),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF6E4423), height: 20),
                Expanded(
                  child: IndexedStack(
                    index: journal.activeTabIndex,
                    children: [
                      _buildRosterTab(data.npcs, journal.metNpcIds,
                          journal.unlockedHiddenDetailNpcIds),
                      _buildSetlistTab(
                        data.setlist,
                        journal.stampedTrackNumbers,
                        clock.encoreModeUnlocked,
                      ),
                      _buildWardrobeTab(
                        data.wardrobe,
                        profile.unlockedWardrobeIds,
                        profile.equippedWardrobeId,
                      ),
                      _buildCollectiblesTab(
                        data.vinyls,
                        data.totems,
                        journal.collectedVinylIds,
                        journal.collectedTotemIds,
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

  Widget _buildRosterTab(
    List<NpcSpec> npcs,
    Set<String> metIds,
    Set<String> hiddenUnlockedIds,
  ) {
    return ListView.separated(
      itemCount: npcs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final npc = npcs[idx];
        final met = metIds.contains(npc.id);
        final hiddenUnlocked = hiddenUnlockedIds.contains(npc.id);

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1B120B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hiddenUnlocked
                  ? const Color(0xFF52B788)
                  : const Color(0xFF4A321F),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ColorFiltered(
                    colorFilter: met
                        ? const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.dst,
                          )
                        : const ColorFilter.mode(
                            Colors.black87,
                            BlendMode.srcATop,
                          ),
                    child: Image.asset(
                      npc.portraitAsset,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      met
                          ? '${npc.name} — ${npc.title}'
                          : '??? — Unmet Guest (${npc.zone})',
                      style: const TextStyle(
                        color: Color(0xFFFFD166),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      met
                          ? '"${npc.catchphrase}"\n${npc.routine}'
                          : 'Explore ${npc.zone} to meet this shell.',
                      style: const TextStyle(
                        color: Color(0xFFD9C398),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hiddenUnlocked
                          ? '✨ Hidden Detail: ${npc.hiddenDetail}'
                          : '🔒 Complete side-quest / chat to reveal Hidden Detail.',
                      style: TextStyle(
                        color: hiddenUnlocked
                            ? const Color(0xFF80FFDB)
                            : const Color(0xFF9C8978),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSetlistTab(
    SetlistCatalog catalog,
    Set<int> stamped,
    bool encoreUnlocked,
  ) {
    final sorted = [...catalog.tracks]..sort((a, b) {
        final d = a.day.compareTo(b.day);
        if (d != 0) return d;
        return a.startMinute.compareTo(b.startMinute);
      });

    return ListView.separated(
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, idx) {
        final t = sorted[idx];
        final isStamped = stamped.contains(t.trackNumber);
        final stageName = catalog.stages[t.stageId]?.name ?? t.stageId;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1B120B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  isStamped ? const Color(0xFFFFB703) : const Color(0xFF3E2A1B),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isStamped ? Icons.verified_rounded : Icons.album_outlined,
                color: isStamped
                    ? const Color(0xFFFFB703)
                    : const Color(0xFF7F6A58),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Day ${t.day} · #${t.trackNumber}: ${t.title}',
                      style: const TextStyle(
                        color: Color(0xFFF4E3C1),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${t.artist} @ $stageName',
                      style: const TextStyle(
                        color: Color(0xFFB7A99A),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(festivalClockProvider.notifier).jumpToTrack(t);
                  ref.read(journalStateProvider.notifier).closeJournal();
                  ref.read(uiOverlayProvider.notifier).showToast(
                        '🎶 Cued "${t.title}" at $stageName!',
                      );
                },
                child: const Text(
                  'Cue Set',
                  style: TextStyle(color: Color(0xFF80FFDB), fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWardrobeTab(
    List<WardrobeItemSpec> items,
    Set<String> unlocked,
    String equippedId,
  ) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final item = items[idx];
        final isUnlocked = unlocked.contains(item.id);
        final isEquipped = equippedId == item.id;

        return ListTile(
          tileColor: const Color(0xFF1B120B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isEquipped
                  ? const Color(0xFF52B788)
                  : const Color(0xFF4A321F),
            ),
          ),
          title: Text(
            item.name,
            style: TextStyle(
              color: isUnlocked
                  ? const Color(0xFFFFD166)
                  : const Color(0xFF8C7A6B),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          subtitle: Text(
            item.description,
            style: const TextStyle(color: Color(0xFFD9C398), fontSize: 12),
          ),
          trailing: isUnlocked
              ? ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEquipped
                        ? const Color(0xFF52B788)
                        : const Color(0xFF3C2A1E),
                  ),
                  onPressed: () => ref
                      .read(playerProfileProvider.notifier)
                      .equipWardrobe(item.id),
                  child: Text(isEquipped ? 'Equipped' : 'Wear'),
                )
              : const Icon(Icons.lock_outline, color: Color(0xFF8C7A6B)),
        );
      },
    );
  }

  Widget _buildCollectiblesTab(
    List<VinylSpec> vinyls,
    List<TotemSpec> totems,
    Set<String> ownedVinyls,
    Set<String> ownedTotems,
  ) {
    return ListView(
      children: [
        const Text(
          'DOUBLE-LP VINYL SIDES & BOOTLEG 45s',
          style: TextStyle(
            color: Color(0xFFFFD166),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        for (final v in vinyls)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1B120B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: ownedVinyls.contains(v.id)
                    ? const Color(0xFFE76F51)
                    : const Color(0xFF4A321F),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  ownedVinyls.contains(v.id) ? Icons.album : Icons.lock_outline,
                  color: ownedVinyls.contains(v.id)
                      ? const Color(0xFFE76F51)
                      : const Color(0xFF7F6A58),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ownedVinyls.contains(v.id)
                        ? '${v.title} (Unlocked — spin at Campground Turntable!)'
                        : '${v.title}\nHint: ${v.sourceHint}',
                    style: const TextStyle(
                      color: Color(0xFFF4E3C1),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          '3D-PRINTED ORCHARD TOTEMS (DRAG CARDS TO ROTATE 3D PREVIEW)',
          style: TextStyle(
            color: Color(0xFF80FFDB),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onHorizontalDragUpdate: (d) =>
              setState(() => _totemSpinRadians += d.delta.dx * 0.03),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final t in totems)
                Container(
                  width: 210,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B120B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ownedTotems.contains(t.id)
                          ? const Color(0xFF80FFDB)
                          : const Color(0xFF4A321F),
                    ),
                  ),
                  child: Column(
                    children: [
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.002)
                          ..rotateY(math.sin(_totemSpinRadians) * 0.55),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: ColorFiltered(
                            colorFilter: ownedTotems.contains(t.id)
                                ? const ColorFilter.mode(
                                    Colors.transparent,
                                    BlendMode.dst,
                                  )
                                : const ColorFilter.mode(
                                    Colors.black87,
                                    BlendMode.srcATop,
                                  ),
                            child: Image.asset(
                              t.sprite,
                              filterQuality: FilterQuality.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ownedTotems.contains(t.id) ? t.name : '??? (${t.zone})',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFFD166),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ownedTotems.contains(t.id)
                            ? t.lore
                            : 'Hidden somewhere in ${t.zone}.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFD9C398),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tabKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key tabKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      key: tabKey,
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFFD49A5A),
      backgroundColor: const Color(0xFF3A2618),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF1C140D) : const Color(0xFFF4E3C1),
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      onSelected: (_) => onTap(),
    );
  }
}
