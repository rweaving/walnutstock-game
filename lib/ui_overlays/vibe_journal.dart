import 'dart:math' as math;
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../state/journal_state.dart';
import '../state/providers.dart';
import '../state/world_flags.dart';

class VibeJournalModal extends ConsumerStatefulWidget {
  const VibeJournalModal({
    super.key,
    this.onUseItem,
  });

  final ValueChanged<String>? onUseItem;

  @override
  ConsumerState<VibeJournalModal> createState() => _VibeJournalModalState();
}

class _VibeJournalModalState extends ConsumerState<VibeJournalModal> {
  double _totemSpinRadians = 0.25;

  @override
  Widget build(BuildContext context) {
    final journal = ref.watch(journalStateProvider);
    final profile = ref.watch(playerProfileProvider);
    final flags = ref.watch(worldFlagsProvider);
    final data = ref.watch(festivalDataProvider);
    final clock = ref.watch(festivalClockProvider);
    final screenW = MediaQuery.sizeOf(context).width;
    final isCompact = screenW < 560;

    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      padding: EdgeInsets.all(isCompact ? 10 : 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 560),
        child: Container(
          key: const ValueKey('vibe_journal_modal'),
          padding: EdgeInsets.all(isCompact ? 12 : 18),
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'WALNUTSTOCK LINEUP & VIBE JOURNAL',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFFFFD166),
                          fontSize: isCompact ? 14 : 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.9,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A2618),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFD166)),
                      ),
                      child: Text(
                        '📿 ${journal.peaceBeads}',
                        style: const TextStyle(
                          color: Color(0xFFFFD166),
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      key: const ValueKey('close_journal_button'),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, color: Color(0xFFF4E3C1)),
                      onPressed: () => ref
                          .read(journalStateProvider.notifier)
                          .closeJournal(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
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
                          'Vinyl & Totems (${journal.collectedTotemIds.length}/8)',
                      selected: journal.activeTabIndex == 3,
                      onTap: () =>
                          ref.read(journalStateProvider.notifier).setTab(3),
                    ),
                    _TabButton(
                      tabKey: const ValueKey('journal_tab_satchel'),
                      label: 'Satchel (${journal.totalDistinctSatchelItems})',
                      selected: journal.activeTabIndex == 4,
                      onTap: () =>
                          ref.read(journalStateProvider.notifier).setTab(4),
                    ),
                    _TabButton(
                      tabKey: const ValueKey('journal_tab_quests'),
                      label:
                          'Quests (${flags.completedQuestCount}/${data.quests.length})',
                      selected: journal.activeTabIndex == 5,
                      onTap: () =>
                          ref.read(journalStateProvider.notifier).setTab(5),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF6E4423), height: 16),
                Expanded(
                  child: IndexedStack(
                    index: journal.activeTabIndex.clamp(0, 5),
                    children: [
                      _buildRosterTab(
                        data.npcs,
                        journal.metNpcIds,
                        journal.unlockedHiddenDetailNpcIds,
                      ),
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
                      _buildSatchelTab(data, journal, flags),
                      _buildQuestsTab(
                        data,
                        journal,
                        flags,
                        currentDay: clock.day,
                        encoreUnlocked: clock.encoreModeUnlocked,
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

  Widget _buildSatchelTab(
    FestivalDataBundle data,
    JournalState journal,
    WorldFlags flags,
  ) {
    final ownedSpecs =
        data.items.where((i) => journal.hasItem(i.id)).toList(growable: false);
    final equippedSpec = journal.equippedGadgetId != null
        ? data.itemById(journal.equippedGadgetId!)
        : null;

    const mainStageIds = <String>[
      'main_roots_stage',
      'mellow_meadow_stage',
      'velvet_canopy_stage',
      'urbano_canopy_stage',
      'andromeda_pavilion_stage',
    ];

    return ListView(
      children: [
        // Quick-Slot & Peace Beads Status Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A281E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF52B788)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    equippedSpec != null
                        ? '⚡ Quick-Item [Q]: ${equippedSpec.icon} ${equippedSpec.name}'
                        : '⚡ Quick-Item [Q]: None Equipped',
                    style: const TextStyle(
                      color: Color(0xFFFFD166),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '📿 Peace Beads: ${journal.peaceBeads}',
                    style: const TextStyle(
                      color: Color(0xFF80FFDB),
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
              if (flags.activeFoodBuffLabel != null &&
                  flags.activeBuffRemainingSec > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '🥙 Active Buff: ${flags.activeFoodBuffLabel} (${flags.activeBuffRemainingSec.ceil()}s left)',
                  style: const TextStyle(
                    color: Color(0xFF95D5B2),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              const Text(
                'Earn Peace Beads by stamping live sets (+5), completing quests (+15..25), rallying Crowd Beach Balls (+3), or playing Arcade Tent games!',
                style: TextStyle(color: Color(0xFFD9C398), fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '🎒 FESTIVAL SATCHEL ITEMS',
          style: TextStyle(
            color: Color(0xFFFFD166),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        if (ownedSpecs.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1B120B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4A321F)),
            ),
            child: const Text(
              'Your Satchel has room for gadgets, street food, and festival curios!\n'
              '• Chat with Daisy Sprout at the Front Gate for a complimentary Soap Bubble Wand.\n'
              '• Visit Vendor Row in Shady Bottoms to browse Penny’s Craft Blanket, Colin’s Camera Crate, and Burt’s Street Food Cart!',
              style: TextStyle(color: Color(0xFFD9C398), fontSize: 12),
            ),
          ),
        for (final item in ownedSpecs)
          Builder(
            builder: (context) {
              final count = journal.itemCount(item.id);
              final isEquipped = journal.equippedGadgetId == item.id;
              final canEquip =
                  item.category == 'gadget' || item.id == 'quest_reel_tape';
              final isConsumable =
                  item.category == 'consumable' || item.category == 'food';
              final canUseNow = canEquip || isConsumable;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B120B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isEquipped
                        ? const Color(0xFF52B788)
                        : const Color(0xFF4A321F),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.icon, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.name}  (x$count)',
                                style: const TextStyle(
                                  color: Color(0xFFFFD166),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.effectSummary,
                                style: const TextStyle(
                                  color: Color(0xFF80FFDB),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (canEquip || canUseNow) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.end,
                        children: [
                          if (canEquip)
                            OutlinedButton(
                              key: ValueKey('satchel_equip_${item.id}'),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: isEquipped
                                    ? const Color(0xFF52B788)
                                    : const Color(0xFFFFD166),
                                side: BorderSide(
                                  color: isEquipped
                                      ? const Color(0xFF52B788)
                                      : const Color(0xFFFFD166),
                                ),
                              ),
                              onPressed: () {
                                ref
                                    .read(journalStateProvider.notifier)
                                    .equipGadget(isEquipped ? null : item.id);
                              },
                              child: Text(
                                isEquipped ? 'Equipped [Q] ✓' : 'Equip [Q]',
                                style: const TextStyle(fontSize: 11.5),
                              ),
                            ),
                          if (canUseNow)
                            ElevatedButton(
                              key: ValueKey('satchel_use_${item.id}'),
                              style: ElevatedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                backgroundColor: const Color(0xFF3A5A40),
                                foregroundColor: const Color(0xFFF4E3C1),
                              ),
                              onPressed: () {
                                if (widget.onUseItem != null) {
                                  ref
                                      .read(journalStateProvider.notifier)
                                      .closeJournal();
                                  widget.onUseItem!(item.id);
                                } else if (canEquip) {
                                  ref
                                      .read(journalStateProvider.notifier)
                                      .equipGadget(item.id);
                                }
                              },
                              child: Text(
                                isConsumable ? 'Enjoy Now' : 'Use Now',
                                style: const TextStyle(fontSize: 11.5),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 12),
        Text(
          '📸 LIVE STAGE POLAROID SCRAPBOOK (${journal.snappedPolaroidStages.length}/5 STAGES)',
          style: const TextStyle(
            color: Color(0xFF80FFDB),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final stId in mainStageIds)
              Builder(
                builder: (context) {
                  final snapped = journal.snappedPolaroidStages.contains(stId);
                  final stName = data.setlist.stages[stId]?.name ?? stId;
                  return Container(
                    width: 134,
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                    decoration: BoxDecoration(
                      color: snapped
                          ? const Color(0xFFF6F1E3)
                          : const Color(0xFF1B120B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: snapped
                            ? const Color(0xFFFFB703)
                            : const Color(0xFF4A321F),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: snapped
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF7B2CBF),
                                      Color(0xFFF72585),
                                      Color(0xFFFFBE0B),
                                    ],
                                  )
                                : null,
                            color: snapped ? null : const Color(0xFF2B1D12),
                          ),
                          child: Text(
                            snapped ? '📸✨' : '🎞️',
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          stName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: snapped
                                ? const Color(0xFF261A11)
                                : const Color(0xFF9C8978),
                            fontWeight: FontWeight.bold,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuestsTab(
    FestivalDataBundle data,
    JournalState journal,
    WorldFlags flags, {
    required int currentDay,
    required bool encoreUnlocked,
  }) {
    const statusRank = <String, int>{
      'ready': 0,
      'in_progress': 1,
      'available': 2,
      'completed': 3,
    };

    final sortedQuests = [...data.quests]..sort((a, b) {
        final sa = flags.questStatusFor(
          a.id,
          journal,
          currentDay: currentDay,
          encoreUnlocked: encoreUnlocked,
        );
        final sb = flags.questStatusFor(
          b.id,
          journal,
          currentDay: currentDay,
          encoreUnlocked: encoreUnlocked,
        );
        return (statusRank[sa] ?? 9).compareTo(statusRank[sb] ?? 9);
      });

    final completed = flags.completedQuestCount;
    final hasVip = journal.hasItem('vip_all_stage_laminate');

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A281E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF52B788)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🌟 ORCHARD HARMONY QUESTS: $completed / ${data.quests.length} COMPLETED',
                style: const TextStyle(
                  color: Color(0xFFFFD166),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasVip
                    ? '🎟️ VIP All-Stage Laminate Active (+25% Crowd Aura & -1 Bead Vendor Discount)!'
                    : '🎟️ Milestone: Complete ${math.max(0, 5 - completed)} more quests to earn the VIP All-Stage Laminate!',
                style: const TextStyle(
                  color: Color(0xFF80FFDB),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final q in sortedQuests)
          Builder(
            builder: (context) {
              final status = flags.questStatusFor(
                q.id,
                journal,
                currentDay: currentDay,
                encoreUnlocked: encoreUnlocked,
              );
              final isTracked = journal.trackedQuestId == q.id;
              final progressNote = _questProgressNote(q.id, journal, flags);
              final (badgeText, badgeColor) = switch (status) {
                'ready' => ('★ READY TO TURN IN', const Color(0xFF52B788)),
                'in_progress' => ('● IN PROGRESS', const Color(0xFFFFB703)),
                'completed' => ('✓ COMPLETED', const Color(0xFF95D5B2)),
                _ => ('! AVAILABLE', const Color(0xFF4CC9F0)),
              };

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B120B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isTracked
                        ? const Color(0xFFFFD166)
                        : (status == 'ready'
                            ? const Color(0xFF52B788)
                            : const Color(0xFF4A321F)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            q.title,
                            style: const TextStyle(
                              color: Color(0xFFFFD166),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          badgeText,
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '📍 ${q.zone} — ${q.summary}',
                      style: const TextStyle(
                        color: Color(0xFFD9C398),
                        fontSize: 11.5,
                      ),
                    ),
                    if (progressNote != null && status != 'completed') ...[
                      const SizedBox(height: 3),
                      Text(
                        progressNote,
                        style: const TextStyle(
                          color: Color(0xFFFFB703),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Text(
                          '🎁 ${q.rewardSummary}',
                          style: const TextStyle(
                            color: Color(0xFF80FFDB),
                            fontSize: 11,
                          ),
                        ),
                        if (status != 'completed')
                          OutlinedButton(
                            key: ValueKey('track_quest_${q.id}'),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: isTracked
                                  ? const Color(0xFFFFD166)
                                  : const Color(0xFF95D5B2),
                              side: BorderSide(
                                color: isTracked
                                    ? const Color(0xFFFFD166)
                                    : const Color(0xFF52B788),
                              ),
                            ),
                            onPressed: () {
                              ref
                                  .read(journalStateProvider.notifier)
                                  .setTrackedQuest(q.id);
                            },
                            child: Text(
                              isTracked ? '📍 Radar Active' : 'Track on Radar',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  String? _questProgressNote(
    String questId,
    JournalState journal,
    WorldFlags flags,
  ) {
    return switch (questId) {
      'quest_sunny_polaroids' =>
        'Progress: ${journal.snappedPolaroidStages.length}/3 Live Stages Photographed',
      'quest_penny_tapestry' =>
        'Progress: ${flags.fabricSwatches.length}/3 Embroidered Swatches Collected',
      'quest_mateo_bootleg' =>
        'Progress: ${journal.recordedBootlegStages.length}/2 Live Stages Recorded',
      'quest_rusty_arcade' =>
        'Progress: Pinball ${flags.pinballHighScore}/1200 · Kernel Sorter ${flags.sortingBeltHighScore}/100',
      'quest_ziggy_dew' =>
        'Progress: ${flags.dewDropsCollected.length}/3 Morning Dew Drops',
      'quest_cosmo_resonators' =>
        'Progress: ${flags.tunedResonators.length}/3 Space-Glass Resonators Tuned',
      _ => null,
    };
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
      visualDensity: VisualDensity.compact,
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFFD49A5A),
      backgroundColor: const Color(0xFF3A2618),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF1C140D) : const Color(0xFFF4E3C1),
        fontWeight: FontWeight.bold,
        fontSize: 11.5,
      ),
      onSelected: (_) => onTap(),
    );
  }
}
