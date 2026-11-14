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

    return JournalState(
      metNpcIds: strSet('metNpcIds'),
      unlockedHiddenDetailNpcIds: strSet('unlockedHiddenDetailNpcIds'),
      stampedTrackNumbers: stamped,
      collectedItems: strSet('collectedItems'),
      collectedVinylIds: strSet('collectedVinylIds'),
      collectedTotemIds: strSet('collectedTotemIds'),
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

  /// Core 26 album tracks stamped count (tracks 1..26).
  int get coreAlbumStampedCount =>
      stampedTrackNumbers.where((n) => n >= 1 && n <= 26).length;

  JournalState copyWith({
    bool? isOpen,
    int? activeTabIndex,
    Set<String>? metNpcIds,
    Set<String>? unlockedHiddenDetailNpcIds,
    Set<int>? stampedTrackNumbers,
    Set<String>? collectedItems,
    Set<String>? collectedVinylIds,
    Set<String>? collectedTotemIds,
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
      ];
}

class JournalStateNotifier extends StateNotifier<JournalState> {
  JournalStateNotifier() : super(const JournalState());

  void hydrate(JournalState journal) => state = journal;

  void openJournal({int? tabIndex}) {
    state = state.copyWith(
      isOpen: true,
      activeTabIndex: tabIndex ?? state.activeTabIndex,
    );
  }

  void closeJournal() {
    state = state.copyWith(isOpen: false);
  }

  void toggleJournal() {
    state = state.copyWith(isOpen: !state.isOpen);
  }

  void setTab(int index) {
    state = state.copyWith(activeTabIndex: index.clamp(0, 3));
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

  void stampTrack(int trackNumber) {
    if (state.stampedTrackNumbers.contains(trackNumber)) return;
    state = state.copyWith(
      stampedTrackNumbers: {...state.stampedTrackNumbers, trackNumber},
    );
  }

  void addItem(String itemName) {
    state = state.copyWith(
      collectedItems: {...state.collectedItems, itemName},
    );
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
