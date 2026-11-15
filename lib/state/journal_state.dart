import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class JournalState extends Equatable {
  const JournalState({
    this.isOpen = false,
    this.activeTabIndex = 0,
    this.metNpcIds = const {},
    this.unlockedHiddenDetailNpcIds = const {},
    this.stampedTrackNumbers = const {},
    this.collectedItems = const {},
    this.collectedVinylIds = const {},
    this.collectedTotemIds = const {},
    this.inventoryCounts = const {},
    this.equippedGadgetId,
    this.peaceBeads = 12,
    this.snappedPolaroidStages = const {},
    this.recordedBootlegStages = const {},
    this.trackedQuestId,
  });

  factory JournalState.fromJson(Map<String, dynamic> json) {
    Set<String> strSet(String key) {
      final raw = json[key] as List<dynamic>?;
      if (raw == null) return const {};
      return raw.map((e) => e.toString()).toSet();
    }

    final rawStamped = json['stampedTrackNumbers'] as List<dynamic>?;
    final stamped = rawStamped == null
        ? const <int>{}
        : rawStamped.map((e) => (e as num).toInt()).toSet();

    final rawCounts = json['inventoryCounts'] as Map<String, dynamic>?;
    final counts = <String, int>{};
    if (rawCounts != null) {
      for (final entry in rawCounts.entries) {
        final v = (entry.value as num?)?.toInt() ?? 0;
        if (v > 0) counts[entry.key] = v;
      }
    }

    return JournalState(
      metNpcIds: strSet('metNpcIds'),
      unlockedHiddenDetailNpcIds: strSet('unlockedHiddenDetailNpcIds'),
      stampedTrackNumbers: stamped,
      collectedItems: strSet('collectedItems'),
      collectedVinylIds: strSet('collectedVinylIds'),
      collectedTotemIds: strSet('collectedTotemIds'),
      inventoryCounts: counts,
      equippedGadgetId: json['equippedGadgetId'] as String?,
      peaceBeads: (json['peaceBeads'] as num?)?.toInt() ?? 12,
      snappedPolaroidStages: strSet('snappedPolaroidStages'),
      recordedBootlegStages: strSet('recordedBootlegStages'),
      trackedQuestId: json['trackedQuestId'] as String?,
    );
  }

  final bool isOpen;
  final int activeTabIndex;
  final Set<String> metNpcIds;
  final Set<String> unlockedHiddenDetailNpcIds;
  final Set<int> stampedTrackNumbers;
  final Set<String> collectedItems;
  final Set<String> collectedVinylIds;
  final Set<String> collectedTotemIds;
  final Map<String, int> inventoryCounts;
  final String? equippedGadgetId;
  final int peaceBeads;
  final Set<String> snappedPolaroidStages;
  final Set<String> recordedBootlegStages;
  final String? trackedQuestId;

  /// Core 26 album tracks stamped count (tracks 1..26).
  int get coreAlbumStampedCount =>
      stampedTrackNumbers.where((n) => n >= 1 && n <= 26).length;

  int itemCount(String itemId) => inventoryCounts[itemId] ?? 0;

  bool hasItem(String itemId) => itemCount(itemId) > 0;

  int get totalDistinctSatchelItems =>
      inventoryCounts.entries.where((e) => e.value > 0).length;

  JournalState copyWith({
    bool? isOpen,
    int? activeTabIndex,
    Set<String>? metNpcIds,
    Set<String>? unlockedHiddenDetailNpcIds,
    Set<int>? stampedTrackNumbers,
    Set<String>? collectedItems,
    Set<String>? collectedVinylIds,
    Set<String>? collectedTotemIds,
    Map<String, int>? inventoryCounts,
    String? equippedGadgetId,
    bool clearEquippedGadget = false,
    int? peaceBeads,
    Set<String>? snappedPolaroidStages,
    Set<String>? recordedBootlegStages,
    String? trackedQuestId,
    bool clearTrackedQuest = false,
  }) {
    return JournalState(
      isOpen: isOpen ?? this.isOpen,
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
      metNpcIds: metNpcIds ?? this.metNpcIds,
      unlockedHiddenDetailNpcIds:
          unlockedHiddenDetailNpcIds ?? this.unlockedHiddenDetailNpcIds,
      stampedTrackNumbers: stampedTrackNumbers ?? this.stampedTrackNumbers,
      collectedItems: collectedItems ?? this.collectedItems,
      collectedVinylIds: collectedVinylIds ?? this.collectedVinylIds,
      collectedTotemIds: collectedTotemIds ?? this.collectedTotemIds,
      inventoryCounts: inventoryCounts ?? this.inventoryCounts,
      equippedGadgetId: clearEquippedGadget
          ? null
          : (equippedGadgetId ?? this.equippedGadgetId),
      peaceBeads: peaceBeads ?? this.peaceBeads,
      snappedPolaroidStages:
          snappedPolaroidStages ?? this.snappedPolaroidStages,
      recordedBootlegStages:
          recordedBootlegStages ?? this.recordedBootlegStages,
      trackedQuestId:
          clearTrackedQuest ? null : (trackedQuestId ?? this.trackedQuestId),
    );
  }

  Map<String, dynamic> toJson() => {
        'metNpcIds': metNpcIds.toList()..sort(),
        'unlockedHiddenDetailNpcIds': unlockedHiddenDetailNpcIds.toList()
          ..sort(),
        'stampedTrackNumbers': stampedTrackNumbers.toList()..sort(),
        'collectedItems': collectedItems.toList()..sort(),
        'collectedVinylIds': collectedVinylIds.toList()..sort(),
        'collectedTotemIds': collectedTotemIds.toList()..sort(),
        'inventoryCounts': {
          for (final entry in inventoryCounts.entries)
            if (entry.value > 0) entry.key: entry.value,
        },
        if (equippedGadgetId != null) 'equippedGadgetId': equippedGadgetId,
        'peaceBeads': peaceBeads,
        if (snappedPolaroidStages.isNotEmpty)
          'snappedPolaroidStages': snappedPolaroidStages.toList()..sort(),
        if (recordedBootlegStages.isNotEmpty)
          'recordedBootlegStages': recordedBootlegStages.toList()..sort(),
        if (trackedQuestId != null) 'trackedQuestId': trackedQuestId,
      };

  @override
  List<Object?> get props => [
        isOpen,
        activeTabIndex,
        metNpcIds,
        unlockedHiddenDetailNpcIds,
        stampedTrackNumbers,
        collectedItems,
        collectedVinylIds,
        collectedTotemIds,
        inventoryCounts,
        equippedGadgetId,
        peaceBeads,
        snappedPolaroidStages,
        recordedBootlegStages,
        trackedQuestId,
      ];
}

class JournalStateNotifier extends StateNotifier<JournalState> {
  JournalStateNotifier() : super(const JournalState());

  void hydrate(JournalState journal) => state = journal;

  void openJournal({int? tabIndex}) {
    state = state.copyWith(
      isOpen: true,
      activeTabIndex: (tabIndex ?? state.activeTabIndex).clamp(0, 5),
    );
  }

  void closeJournal() {
    state = state.copyWith(isOpen: false);
  }

  void toggleJournal() {
    state = state.copyWith(isOpen: !state.isOpen);
  }

  void setTab(int index) {
    state = state.copyWith(activeTabIndex: index.clamp(0, 5));
  }

  void markNpcMet(String npcId) {
    if (state.metNpcIds.contains(npcId)) return;
    state = state.copyWith(metNpcIds: {...state.metNpcIds, npcId});
  }

  void unlockHiddenDetail(String npcId) {
    state = state.copyWith(
      metNpcIds: {...state.metNpcIds, npcId},
      unlockedHiddenDetailNpcIds: {
        ...state.unlockedHiddenDetailNpcIds,
        npcId,
      },
    );
  }

  /// Returns `true` if newly stamped.
  bool stampTrack(int trackNumber) {
    if (state.stampedTrackNumbers.contains(trackNumber)) return false;
    state = state.copyWith(
      stampedTrackNumbers: {...state.stampedTrackNumbers, trackNumber},
    );
    return true;
  }

  void addItem(String itemName) {
    state = state.copyWith(
      collectedItems: {...state.collectedItems, itemName},
    );
  }

  void grantItem(
    String itemId, {
    int count = 1,
    bool autoEquipGadget = false,
    String? displayLabel,
  }) {
    if (count <= 0) return;
    final nextCounts = Map<String, int>.from(state.inventoryCounts);
    nextCounts[itemId] = (nextCounts[itemId] ?? 0) + count;
    final nextEquipped = (autoEquipGadget || state.equippedGadgetId == null) &&
            (itemId.startsWith('gadget_') || itemId == 'quest_reel_tape')
        ? itemId
        : state.equippedGadgetId;
    state = state.copyWith(
      inventoryCounts: nextCounts,
      equippedGadgetId: nextEquipped,
      collectedItems: displayLabel != null
          ? {...state.collectedItems, displayLabel}
          : state.collectedItems,
    );
  }

  bool consumeItem(String itemId, {int count = 1}) {
    final current = state.itemCount(itemId);
    if (current < count) return false;
    final nextCounts = Map<String, int>.from(state.inventoryCounts);
    final remaining = current - count;
    if (remaining <= 0) {
      nextCounts.remove(itemId);
    } else {
      nextCounts[itemId] = remaining;
    }
    final clearEquipped = remaining <= 0 && state.equippedGadgetId == itemId;
    state = state.copyWith(
      inventoryCounts: nextCounts,
      clearEquippedGadget: clearEquipped,
    );
    return true;
  }

  void equipGadget(String? gadgetId) {
    if (gadgetId == null) {
      state = state.copyWith(clearEquippedGadget: true);
      return;
    }
    if (!state.hasItem(gadgetId)) return;
    state = state.copyWith(equippedGadgetId: gadgetId);
  }

  void addPeaceBeads(int delta) {
    if (delta == 0) return;
    final next = (state.peaceBeads + delta).clamp(0, 9999);
    state = state.copyWith(peaceBeads: next);
  }

  bool spendPeaceBeads(int cost) {
    if (cost <= 0) return true;
    if (state.peaceBeads < cost) return false;
    state = state.copyWith(peaceBeads: state.peaceBeads - cost);
    return true;
  }

  bool recordStagePolaroid(String stageId) {
    if (state.snappedPolaroidStages.contains(stageId)) return false;
    state = state.copyWith(
      snappedPolaroidStages: {...state.snappedPolaroidStages, stageId},
    );
    return true;
  }

  bool recordBootlegStage(String stageId) {
    if (state.recordedBootlegStages.contains(stageId)) return false;
    state = state.copyWith(
      recordedBootlegStages: {...state.recordedBootlegStages, stageId},
    );
    return true;
  }

  void setTrackedQuest(String? questId) {
    if (questId == null || state.trackedQuestId == questId) {
      state = state.copyWith(clearTrackedQuest: true);
    } else {
      state = state.copyWith(trackedQuestId: questId);
    }
  }

  void collectVinyl(String vinylId) {
    if (state.collectedVinylIds.contains(vinylId)) return;
    state = state.copyWith(
      collectedVinylIds: {...state.collectedVinylIds, vinylId},
    );
  }

  void unlockAllVinyls(Iterable<String> allIds) {
    state = state.copyWith(
      collectedVinylIds: {...state.collectedVinylIds, ...allIds},
    );
  }

  void collectTotem(String totemId) {
    if (state.collectedTotemIds.contains(totemId)) return;
    state = state.copyWith(
      collectedTotemIds: {...state.collectedTotemIds, totemId},
    );
  }
}
