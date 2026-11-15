import 'dart:math' as math;

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../state/providers.dart';

class FestivalStallModal extends ConsumerWidget {
  const FestivalStallModal({
    super.key,
    this.onUseItem,
  });

  final ValueChanged<String>? onUseItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlay = ref.watch(uiOverlayProvider);
    final stallId = overlay.activeVendorStallId ?? 'burt_food';
    final journal = ref.watch(journalStateProvider);
    final flags = ref.watch(worldFlagsProvider);
    final clock = ref.watch(festivalClockProvider);
    final data = ref.watch(festivalDataProvider);

    final hasVip = journal.hasItem('vip_all_stage_laminate');

    final (title, subtitle, accentColor) = switch (stallId) {
      'penny_crafts' => (
          "🧶 PENNY'S CRAFT & CROWD TOY BLANKET",
          'Hand-woven 1969 crowd toys, streamers, tambourines & picnic blankets.',
          const Color(0xFFFF9F1C),
        ),
      'colin_curios' => (
          "📷 COLIN'S CAMERA & CURIO CRATE",
          'Instamatic cameras, Encore Sparklers, and musician courtesy strings.',
          const Color(0xFF4CC9F0),
        ),
      'bulletin_board' => (
          '📌 COMMUNITY BULLETIN & LOST-AND-FOUND',
          'Orchard schedule tips, lost-and-found notices & radar quest pins.',
          const Color(0xFF80FFDB),
        ),
      _ => (
          "🥙 BURT'S STREET FOOD & CIDER COUNTER",
          'Warm falafel, spiced persimmon cider, espresso & chamomile tea buffs.',
          const Color(0xFF52B788),
        ),
    };

    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 540),
        child: Container(
          key: ValueKey('festival_stall_modal_$stallId'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF241810),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accentColor, width: 2.3),
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
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A2618),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFD166)),
                      ),
                      child: Text(
                        clock.pureVibeMode
                            ? '📿 ${journal.peaceBeads} (Pure Vibe FREE)'
                            : '📿 ${journal.peaceBeads} Beads',
                        style: const TextStyle(
                          color: Color(0xFFFFD166),
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      key: const ValueKey('close_stall_modal_button'),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, color: Color(0xFFF4E3C1)),
                      onPressed: () =>
                          ref.read(uiOverlayProvider.notifier).closeModal(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  hasVip && stallId != 'bulletin_board'
                      ? '$subtitle · 🎟️ VIP Laminate active (-1 Bead discount!)'
                      : subtitle,
                  style: const TextStyle(
                    color: Color(0xFFD9C398),
                    fontSize: 12,
                  ),
                ),
                const Divider(color: Color(0xFF6E4423), height: 18),
                Expanded(
                  child: stallId == 'bulletin_board'
                      ? _buildBulletinBoard(context, ref, data)
                      : _buildVendorCatalog(
                          context,
                          ref,
                          stallId: stallId,
                          items: data.items
                              .where((i) => i.vendorStallId == stallId)
                              .toList(growable: false),
                          hasVip: hasVip,
                          pureVibe: clock.pureVibeMode,
                          roxieNeedsString: flags.roxieStringQuestStarted &&
                              !flags.roxieStringQuestCompleted &&
                              !flags.hasNickelString,
                          mateoNeedsTape: flags.mateoTapeQuestStarted &&
                              !journal.hasItem('quest_reel_tape'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVendorCatalog(
    BuildContext context,
    WidgetRef ref, {
    required String stallId,
    required List<FestivalItemSpec> items,
    required bool hasVip,
    required bool pureVibe,
    required bool roxieNeedsString,
    required bool mateoNeedsTape,
  }) {
    final journal = ref.watch(journalStateProvider);
    final visibleItems = items.where((item) {
      if (item.id == 'quest_nickel_string') {
        return roxieNeedsString || journal.hasItem('quest_nickel_string');
      }
      if (item.id == 'quest_reel_tape') {
        return mateoNeedsTape || journal.hasItem('quest_reel_tape');
      }
      return true;
    }).toList(growable: false);

    return ListView.separated(
      itemCount: visibleItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final item = visibleItems[idx];
        final ownedCount = journal.itemCount(item.id);
        final isOwnedReusable = item.reusable && ownedCount > 0;
        final isEquipped = journal.equippedGadgetId == item.id;
        final effectiveCost = item.beadCost == 0 || pureVibe
            ? 0
            : math.max(1, item.beadCost - (hasVip ? 1 : 0));
        final canAfford = effectiveCost == 0 || journal.peaceBeads >= effectiveCost;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A110B),
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
                  Text(item.icon, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ownedCount > 0
                              ? '${item.name}  (In Satchel: x$ownedCount)'
                              : item.name,
                          style: const TextStyle(
                            color: Color(0xFFFFD166),
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.description,
                          style: const TextStyle(
                            color: Color(0xFFD9C398),
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '✨ ${item.effectSummary}',
                          style: const TextStyle(
                            color: Color(0xFF80FFDB),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: [
                  if (!isOwnedReusable)
                    ElevatedButton(
                      key: ValueKey('stall_buy_${item.id}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canAfford
                            ? const Color(0xFF3A5A40)
                            : const Color(0xFF3B2D23),
                        foregroundColor: const Color(0xFFF4E3C1),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: canAfford
                          ? () => _purchaseItem(ref, item, effectiveCost)
                          : null,
                      child: Text(
                        effectiveCost == 0
                            ? 'Claim Free'
                            : 'Trade ($effectiveCost 📿)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (ownedCount > 0 &&
                      (item.category == 'gadget' ||
                          item.id == 'quest_reel_tape'))
                    OutlinedButton(
                      key: ValueKey('stall_equip_${item.id}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isEquipped
                            ? const Color(0xFF52B788)
                            : const Color(0xFFFFD166),
                        side: BorderSide(
                          color: isEquipped
                              ? const Color(0xFF52B788)
                              : const Color(0xFFFFD166),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        ref.read(journalStateProvider.notifier).equipGadget(
                              isEquipped ? null : item.id,
                            );
                      },
                      child: Text(
                        isEquipped ? 'Equipped [Q] ✓' : 'Equip [Q]',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  if (ownedCount > 0 &&
                      (item.category == 'consumable' ||
                          item.category == 'food'))
                    OutlinedButton(
                      key: ValueKey('stall_use_${item.id}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF80FFDB),
                        side: const BorderSide(color: Color(0xFF80FFDB)),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        if (onUseItem != null) {
                          onUseItem!(item.id);
                        }
                      },
                      child: const Text(
                        'Enjoy Now',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _purchaseItem(WidgetRef ref, FestivalItemSpec item, int cost) {
    final journalN = ref.read(journalStateProvider.notifier);
    if (cost > 0 && !journalN.spendPeaceBeads(cost)) {
      return;
    }
    final isGadget =
        item.category == 'gadget' || item.id == 'quest_reel_tape';
    journalN.grantItem(
      item.id,
      autoEquipGadget: isGadget,
      displayLabel: item.name,
    );
    if (item.id == 'quest_nickel_string') {
      ref
          .read(worldFlagsProvider.notifier)
          .update((s) => s.copyWith(hasNickelString: true));
    }
    ref.read(uiOverlayProvider.notifier).showToast(
          '${item.icon} Added ${item.name} to your Festival Satchel!',
        );
  }

  Widget _buildBulletinBoard(
    BuildContext context,
    WidgetRef ref,
    FestivalDataBundle data,
  ) {
    final journal = ref.watch(journalStateProvider);
    final flags = ref.watch(worldFlagsProvider);
    final clock = ref.watch(festivalClockProvider);

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
          currentDay: clock.day,
          encoreUnlocked: clock.encoreModeUnlocked,
        );
        final sb = flags.questStatusFor(
          b.id,
          journal,
          currentDay: clock.day,
          encoreUnlocked: clock.encoreModeUnlocked,
        );
        return (statusRank[sa] ?? 9).compareTo(statusRank[sb] ?? 9);
      });

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF18281E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF52B788)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🎪 LIVE ORCHARD HAPPENINGS & TIPS',
                style: TextStyle(
                  color: Color(0xFFFFD166),
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '• 🌧️ Day 1 Set 7 brings rainclouds — after Set 8, belly-slide & toss mudballs in the Woodstock Mud Pit!\n'
                '• 🫐 Start of Day 2: Share Electric Purple Blueberries by the Willow Creek Stage for 2 sets of wavy rainbow!\n'
                '• 🏐 Bump the Giant Crowd Beach Balls at Main Roots & Mellow Meadow (+3 Beads every 3-hit rally)!\n'
                '• 🧭 LOST & FOUND: Fern Whisper-Shell lost a Brass Compass along Main Roots south dirt lane (x:496, y:624).',
                style: TextStyle(
                  color: Color(0xFFE9F5DB),
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '📋 FESTIVAL QUEST BOARD (${flags.completedQuestCount}/${data.quests.length} COMPLETED)',
          style: const TextStyle(
            color: Color(0xFF80FFDB),
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 6),
        for (final q in sortedQuests)
          Builder(
            builder: (context) {
              final status = flags.questStatusFor(
                q.id,
                journal,
                currentDay: clock.day,
                encoreUnlocked: clock.encoreModeUnlocked,
              );
              final isTracked = journal.trackedQuestId == q.id;
              final badgeText = switch (status) {
                'ready' => '★ READY TO TURN IN',
                'in_progress' => '● IN PROGRESS',
                'completed' => '✓ COMPLETED',
                _ => '! OPEN QUEST',
              };
              final badgeColor = switch (status) {
                'ready' => const Color(0xFF52B788),
                'in_progress' => const Color(0xFFFFB703),
                'completed' => const Color(0xFF7F8C8D),
                _ => const Color(0xFF4CC9F0),
              };
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A110B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isTracked
                        ? const Color(0xFFFFD166)
                        : const Color(0xFF4A321F),
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
                              fontSize: 12.5,
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
                      '${q.zone} — ${q.summary}',
                      style: const TextStyle(
                        color: Color(0xFFD9C398),
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '🎁 ${q.rewardSummary}',
                            style: const TextStyle(
                              color: Color(0xFF80FFDB),
                              fontSize: 11,
                            ),
                          ),
                        ),
                        if (status != 'completed')
                          TextButton(
                            key: ValueKey('bulletin_pin_${q.id}'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () {
                              ref
                                  .read(journalStateProvider.notifier)
                                  .setTrackedQuest(q.id);
                            },
                            child: Text(
                              isTracked ? '📍 Pinned' : 'Pin Radar',
                              style: TextStyle(
                                color: isTracked
                                    ? const Color(0xFFFFD166)
                                    : const Color(0xFF95D5B2),
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
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
}
