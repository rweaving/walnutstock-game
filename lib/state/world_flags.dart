import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';

class WorldFlags extends Equatable {
  const WorldFlags({
    // v0.1.0 core flags (preserved verbatim for save compatibility)
    this.fencesDropped = false,
    this.lanternsLit = false,
    this.firefliesActive = false,
    this.mossBridgesBloomed = false,
    this.slowWaveSwayUnlocked = false,
    this.dewDropsCollected = const {},
    this.ziggyQuestStarted = false,
    this.ziggyQuestCompleted = false,
    this.breezewalkerQuestStarted = false,
    this.hasWillowPick = false,
    this.breezewalkerQuestCompleted = false,
    this.burtQuestStarted = false,
    this.falafelCiderOffered = false,
    this.burtQuestCompleted = false,
    this.bittershellMapCompleted = false,
    // Phase 3-5 expanded world events, quests, shaders & mini-game state
    this.meadowScavengerUnlocked = false,
    this.falafelTruceUnlocked = false,
    this.janiceQuestStarted = false,
    this.hasVocalTea = false,
    this.janiceQuestCompleted = false,
    this.cosmoQuestStarted = false,
    this.tunedResonators = const {},
    this.cosmoQuestCompleted = false,
    this.donShelloQuestStarted = false,
    this.goldMicBlessed = false,
    this.buriedStashUnearthed = false,
    this.donShelloQuestCompleted = false,
    this.tulaQuestStarted = false,
    this.teaLightAltared = false,
    this.tulaQuestCompleted = false,
    this.jimiQuestStarted = false,
    this.jimiQuestCompleted = false,
    this.peteInterviewCompleted = false,
    this.walnutTripActive = false,
    this.purpleDustActive = false,
    this.nebulaActive = false,
    this.crowdMigrateMainRoots = false,
    this.finaleMontageShown = false,
    this.pinballHighScore = 0,
    this.sortingBeltHighScore = 0,
    this.mudSlidesCount = 0,
    this.mudFightsSplatted = 0,
    this.blueberryTripActive = false,
    this.blueberryStartDay = 0,
    this.blueberryStartMinute = 0.0,
    this.blueberrySet1EndDay = 0,
    this.blueberrySet1EndMinute = 0.0,
    this.blueberryExpiryDay = 0,
    this.blueberryExpiryMinute = 0.0,
    this.blueberriesSharedCount = 0,
    this.playerSwaying = false,
    this.playerDancing = false,
    this.playerDanceStyle = 0,
    this.crowdAura = 0.0,
    this.justListenStageMode = false,
  });

  static const List<String> danceStyleNames = [
    'Boogie',
    'Twist',
    'Shuffle',
    'Spin',
  ];

  factory WorldFlags.fromJson(Map<String, dynamic> json) {
    Set<String> strSet(String key) {
      final raw = json[key] as List<dynamic>?;
      if (raw == null) return const {};
      return raw.map((e) => e.toString()).toSet();
    }

    return WorldFlags(
      fencesDropped: json['fencesDropped'] as bool? ?? false,
      lanternsLit: json['lanternsLit'] as bool? ?? false,
      firefliesActive: json['firefliesActive'] as bool? ?? false,
      mossBridgesBloomed: json['mossBridgesBloomed'] as bool? ?? false,
      slowWaveSwayUnlocked: json['slowWaveSwayUnlocked'] as bool? ?? false,
      dewDropsCollected: strSet('dewDropsCollected'),
      ziggyQuestStarted: json['ziggyQuestStarted'] as bool? ?? false,
      ziggyQuestCompleted: json['ziggyQuestCompleted'] as bool? ?? false,
      breezewalkerQuestStarted:
          json['breezewalkerQuestStarted'] as bool? ?? false,
      hasWillowPick: json['hasWillowPick'] as bool? ?? false,
      breezewalkerQuestCompleted:
          json['breezewalkerQuestCompleted'] as bool? ?? false,
      burtQuestStarted: json['burtQuestStarted'] as bool? ?? false,
      falafelCiderOffered: json['falafelCiderOffered'] as bool? ?? false,
      burtQuestCompleted: json['burtQuestCompleted'] as bool? ?? false,
      bittershellMapCompleted:
          json['bittershellMapCompleted'] as bool? ?? false,
      meadowScavengerUnlocked:
          json['meadowScavengerUnlocked'] as bool? ?? false,
      falafelTruceUnlocked: json['falafelTruceUnlocked'] as bool? ?? false,
      janiceQuestStarted: json['janiceQuestStarted'] as bool? ?? false,
      hasVocalTea: json['hasVocalTea'] as bool? ?? false,
      janiceQuestCompleted: json['janiceQuestCompleted'] as bool? ?? false,
      cosmoQuestStarted: json['cosmoQuestStarted'] as bool? ?? false,
      tunedResonators: strSet('tunedResonators'),
      cosmoQuestCompleted: json['cosmoQuestCompleted'] as bool? ?? false,
      donShelloQuestStarted: json['donShelloQuestStarted'] as bool? ?? false,
      goldMicBlessed: json['goldMicBlessed'] as bool? ?? false,
      buriedStashUnearthed: json['buriedStashUnearthed'] as bool? ?? false,
      donShelloQuestCompleted:
          json['donShelloQuestCompleted'] as bool? ?? false,
      tulaQuestStarted: json['tulaQuestStarted'] as bool? ?? false,
      teaLightAltared: json['teaLightAltared'] as bool? ?? false,
      tulaQuestCompleted: json['tulaQuestCompleted'] as bool? ?? false,
      jimiQuestStarted: json['jimiQuestStarted'] as bool? ?? false,
      jimiQuestCompleted: json['jimiQuestCompleted'] as bool? ?? false,
      peteInterviewCompleted: json['peteInterviewCompleted'] as bool? ?? false,
      walnutTripActive: json['walnutTripActive'] as bool? ?? false,
      purpleDustActive: json['purpleDustActive'] as bool? ?? false,
      nebulaActive: json['nebulaActive'] as bool? ?? false,
      crowdMigrateMainRoots: json['crowdMigrateMainRoots'] as bool? ?? false,
      finaleMontageShown: json['finaleMontageShown'] as bool? ?? false,
      pinballHighScore: (json['pinballHighScore'] as num?)?.toInt() ?? 0,
      sortingBeltHighScore:
          (json['sortingBeltHighScore'] as num?)?.toInt() ?? 0,
      mudSlidesCount: (json['mudSlidesCount'] as num?)?.toInt() ?? 0,
      mudFightsSplatted: (json['mudFightsSplatted'] as num?)?.toInt() ?? 0,
      blueberryTripActive: json['blueberryTripActive'] as bool? ?? false,
      blueberryStartDay: (json['blueberryStartDay'] as num?)?.toInt() ?? 0,
      blueberryStartMinute:
          (json['blueberryStartMinute'] as num?)?.toDouble() ?? 0.0,
      blueberrySet1EndDay: (json['blueberrySet1EndDay'] as num?)?.toInt() ?? 0,
      blueberrySet1EndMinute:
          (json['blueberrySet1EndMinute'] as num?)?.toDouble() ?? 0.0,
      blueberryExpiryDay: (json['blueberryExpiryDay'] as num?)?.toInt() ?? 0,
      blueberryExpiryMinute:
          (json['blueberryExpiryMinute'] as num?)?.toDouble() ?? 0.0,
      blueberriesSharedCount:
          (json['blueberriesSharedCount'] as num?)?.toInt() ?? 0,
    );
  }

  final bool fencesDropped;
  final bool lanternsLit;
  final bool firefliesActive;
  final bool mossBridgesBloomed;
  final bool slowWaveSwayUnlocked;
  final Set<String> dewDropsCollected;
  final bool ziggyQuestStarted;
  final bool ziggyQuestCompleted;
  final bool breezewalkerQuestStarted;
  final bool hasWillowPick;
  final bool breezewalkerQuestCompleted;
  final bool burtQuestStarted;
  final bool falafelCiderOffered;
  final bool burtQuestCompleted;
  final bool bittershellMapCompleted;

  final bool meadowScavengerUnlocked;
  final bool falafelTruceUnlocked;
  final bool janiceQuestStarted;
  final bool hasVocalTea;
  final bool janiceQuestCompleted;
  final bool cosmoQuestStarted;
  final Set<String> tunedResonators;
  final bool cosmoQuestCompleted;
  final bool donShelloQuestStarted;
  final bool goldMicBlessed;
  final bool buriedStashUnearthed;
  final bool donShelloQuestCompleted;
  final bool tulaQuestStarted;
  final bool teaLightAltared;
  final bool tulaQuestCompleted;
  final bool jimiQuestStarted;
  final bool jimiQuestCompleted;
  final bool peteInterviewCompleted;

  final bool walnutTripActive;
  final bool purpleDustActive;
  final bool nebulaActive;
  final bool crowdMigrateMainRoots;
  final bool finaleMontageShown;
  final int pinballHighScore;
  final int sortingBeltHighScore;
  final int mudSlidesCount;
  final int mudFightsSplatted;
  final bool blueberryTripActive;
  final int blueberryStartDay;
  final double blueberryStartMinute;
  final int blueberrySet1EndDay;
  final double blueberrySet1EndMinute;
  final int blueberryExpiryDay;
  final double blueberryExpiryMinute;
  final int blueberriesSharedCount;

  // Transient runtime aura & music-synced dance state
  final bool playerSwaying;
  final bool playerDancing;
  final int playerDanceStyle;
  final double crowdAura;
  final bool justListenStageMode;

  String get currentDanceStyleLabel =>
      danceStyleNames[playerDanceStyle % danceStyleNames.length];

  bool get hasHarmonyMilestoneForJimi =>
      mossBridgesBloomed ||
      janiceQuestCompleted ||
      cosmoQuestCompleted ||
      burtQuestCompleted ||
      crowdAura >= 0.75;

  static int _compareClock(int dA, double mA, int dB, double mB) {
    if (dA != dB) return dA.compareTo(dB);
    return mA.compareTo(mB);
  }

  /// Computes the exact 2-set duration window from `(startDay, startMinute)`,
  /// counting genuine non-PA, non-bonus-stem musical sets with >= 20 in-game minutes remaining.
  static ({
    int set1Day,
    double set1EndMin,
    int set2Day,
    double set2EndMin,
  }) computeTwoSetWindow(
    SetlistCatalog catalog, {
    required int startDay,
    required double startMinute,
  }) {
    final sets = catalog.tracks
        .where((t) => !t.isPaBroadcast && !t.isBonusStem)
        .toList()
      ..sort((a, b) {
        final c = a.day.compareTo(b.day);
        if (c != 0) return c;
        return a.startMinute.compareTo(b.startMinute);
      });

    final eligible = sets
        .where(
          (t) =>
              t.day > startDay ||
              (t.day == startDay && (t.endMinute - startMinute) >= 20.0),
        )
        .toList(growable: false);

    if (eligible.length >= 2) {
      return (
        set1Day: eligible[0].day,
        set1EndMin: eligible[0].endMinute,
        set2Day: eligible[1].day,
        set2EndMin: eligible[1].endMinute,
      );
    }
    if (eligible.length == 1) {
      return (
        set1Day: eligible[0].day,
        set1EndMin: eligible[0].endMinute,
        set2Day: eligible[0].day,
        set2EndMin: eligible[0].endMinute + 135.0,
      );
    }
    return (
      set1Day: startDay,
      set1EndMin: startMinute + 130.0,
      set2Day: startDay,
      set2EndMin: startMinute + 260.0,
    );
  }

  bool isBlueberryRainbowActiveAt(int day, double minuteOfDay) {
    if (!blueberryTripActive || blueberryExpiryDay <= 0) return false;
    final afterStart = _compareClock(
          day,
          minuteOfDay,
          blueberryStartDay,
          blueberryStartMinute - 1.0,
        ) >=
        0;
    final beforeEnd = _compareClock(
          day,
          minuteOfDay,
          blueberryExpiryDay,
          blueberryExpiryMinute,
        ) <=
        0;
    return afterStart && beforeEnd;
  }

  int blueberrySetsRemainingAt(int day, double minuteOfDay) {
    if (!isBlueberryRainbowActiveAt(day, minuteOfDay)) return 0;
    final inFirstSet = _compareClock(
          day,
          minuteOfDay,
          blueberrySet1EndDay,
          blueberrySet1EndMinute,
        ) <=
        0;
    return inFirstSet ? 2 : 1;
  }

  WorldFlags copyWith({
    bool? fencesDropped,
    bool? lanternsLit,
    bool? firefliesActive,
    bool? mossBridgesBloomed,
    bool? slowWaveSwayUnlocked,
    Set<String>? dewDropsCollected,
    bool? ziggyQuestStarted,
    bool? ziggyQuestCompleted,
    bool? breezewalkerQuestStarted,
    bool? hasWillowPick,
    bool? breezewalkerQuestCompleted,
    bool? burtQuestStarted,
    bool? falafelCiderOffered,
    bool? burtQuestCompleted,
    bool? bittershellMapCompleted,
    bool? meadowScavengerUnlocked,
    bool? falafelTruceUnlocked,
    bool? janiceQuestStarted,
    bool? hasVocalTea,
    bool? janiceQuestCompleted,
    bool? cosmoQuestStarted,
    Set<String>? tunedResonators,
    bool? cosmoQuestCompleted,
    bool? donShelloQuestStarted,
    bool? goldMicBlessed,
    bool? buriedStashUnearthed,
    bool? donShelloQuestCompleted,
    bool? tulaQuestStarted,
    bool? teaLightAltared,
    bool? tulaQuestCompleted,
    bool? jimiQuestStarted,
    bool? jimiQuestCompleted,
    bool? peteInterviewCompleted,
    bool? walnutTripActive,
    bool? purpleDustActive,
    bool? nebulaActive,
    bool? crowdMigrateMainRoots,
    bool? finaleMontageShown,
    int? pinballHighScore,
    int? sortingBeltHighScore,
    int? mudSlidesCount,
    int? mudFightsSplatted,
    bool? blueberryTripActive,
    int? blueberryStartDay,
    double? blueberryStartMinute,
    int? blueberrySet1EndDay,
    double? blueberrySet1EndMinute,
    int? blueberryExpiryDay,
    double? blueberryExpiryMinute,
    int? blueberriesSharedCount,
    bool? playerSwaying,
    bool? playerDancing,
    int? playerDanceStyle,
    double? crowdAura,
    bool? justListenStageMode,
  }) {
    return WorldFlags(
      fencesDropped: fencesDropped ?? this.fencesDropped,
      lanternsLit: lanternsLit ?? this.lanternsLit,
      firefliesActive: firefliesActive ?? this.firefliesActive,
      mossBridgesBloomed: mossBridgesBloomed ?? this.mossBridgesBloomed,
      slowWaveSwayUnlocked: slowWaveSwayUnlocked ?? this.slowWaveSwayUnlocked,
      dewDropsCollected: dewDropsCollected ?? this.dewDropsCollected,
      ziggyQuestStarted: ziggyQuestStarted ?? this.ziggyQuestStarted,
      ziggyQuestCompleted: ziggyQuestCompleted ?? this.ziggyQuestCompleted,
      breezewalkerQuestStarted:
          breezewalkerQuestStarted ?? this.breezewalkerQuestStarted,
      hasWillowPick: hasWillowPick ?? this.hasWillowPick,
      breezewalkerQuestCompleted:
          breezewalkerQuestCompleted ?? this.breezewalkerQuestCompleted,
      burtQuestStarted: burtQuestStarted ?? this.burtQuestStarted,
      falafelCiderOffered: falafelCiderOffered ?? this.falafelCiderOffered,
      burtQuestCompleted: burtQuestCompleted ?? this.burtQuestCompleted,
      bittershellMapCompleted:
          bittershellMapCompleted ?? this.bittershellMapCompleted,
      meadowScavengerUnlocked:
          meadowScavengerUnlocked ?? this.meadowScavengerUnlocked,
      falafelTruceUnlocked: falafelTruceUnlocked ?? this.falafelTruceUnlocked,
      janiceQuestStarted: janiceQuestStarted ?? this.janiceQuestStarted,
      hasVocalTea: hasVocalTea ?? this.hasVocalTea,
      janiceQuestCompleted: janiceQuestCompleted ?? this.janiceQuestCompleted,
      cosmoQuestStarted: cosmoQuestStarted ?? this.cosmoQuestStarted,
      tunedResonators: tunedResonators ?? this.tunedResonators,
      cosmoQuestCompleted: cosmoQuestCompleted ?? this.cosmoQuestCompleted,
      donShelloQuestStarted:
          donShelloQuestStarted ?? this.donShelloQuestStarted,
      goldMicBlessed: goldMicBlessed ?? this.goldMicBlessed,
      buriedStashUnearthed: buriedStashUnearthed ?? this.buriedStashUnearthed,
      donShelloQuestCompleted:
          donShelloQuestCompleted ?? this.donShelloQuestCompleted,
      tulaQuestStarted: tulaQuestStarted ?? this.tulaQuestStarted,
      teaLightAltared: teaLightAltared ?? this.teaLightAltared,
      tulaQuestCompleted: tulaQuestCompleted ?? this.tulaQuestCompleted,
      jimiQuestStarted: jimiQuestStarted ?? this.jimiQuestStarted,
      jimiQuestCompleted: jimiQuestCompleted ?? this.jimiQuestCompleted,
      peteInterviewCompleted:
          peteInterviewCompleted ?? this.peteInterviewCompleted,
      walnutTripActive: walnutTripActive ?? this.walnutTripActive,
      purpleDustActive: purpleDustActive ?? this.purpleDustActive,
      nebulaActive: nebulaActive ?? this.nebulaActive,
      crowdMigrateMainRoots:
          crowdMigrateMainRoots ?? this.crowdMigrateMainRoots,
      finaleMontageShown: finaleMontageShown ?? this.finaleMontageShown,
      pinballHighScore: pinballHighScore ?? this.pinballHighScore,
      sortingBeltHighScore: sortingBeltHighScore ?? this.sortingBeltHighScore,
      mudSlidesCount: mudSlidesCount ?? this.mudSlidesCount,
      mudFightsSplatted: mudFightsSplatted ?? this.mudFightsSplatted,
      blueberryTripActive: blueberryTripActive ?? this.blueberryTripActive,
      blueberryStartDay: blueberryStartDay ?? this.blueberryStartDay,
      blueberryStartMinute: blueberryStartMinute ?? this.blueberryStartMinute,
      blueberrySet1EndDay: blueberrySet1EndDay ?? this.blueberrySet1EndDay,
      blueberrySet1EndMinute:
          blueberrySet1EndMinute ?? this.blueberrySet1EndMinute,
      blueberryExpiryDay: blueberryExpiryDay ?? this.blueberryExpiryDay,
      blueberryExpiryMinute:
          blueberryExpiryMinute ?? this.blueberryExpiryMinute,
      blueberriesSharedCount:
          blueberriesSharedCount ?? this.blueberriesSharedCount,
      playerSwaying: playerSwaying ?? this.playerSwaying,
      playerDancing: playerDancing ?? this.playerDancing,
      playerDanceStyle: playerDanceStyle ?? this.playerDanceStyle,
      crowdAura: crowdAura ?? this.crowdAura,
      justListenStageMode: justListenStageMode ?? this.justListenStageMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'fencesDropped': fencesDropped,
        'lanternsLit': lanternsLit,
        'firefliesActive': firefliesActive,
        'mossBridgesBloomed': mossBridgesBloomed,
        'slowWaveSwayUnlocked': slowWaveSwayUnlocked,
        'dewDropsCollected': dewDropsCollected.toList()..sort(),
        'ziggyQuestStarted': ziggyQuestStarted,
        'ziggyQuestCompleted': ziggyQuestCompleted,
        'breezewalkerQuestStarted': breezewalkerQuestStarted,
        'hasWillowPick': hasWillowPick,
        'breezewalkerQuestCompleted': breezewalkerQuestCompleted,
        'burtQuestStarted': burtQuestStarted,
        'falafelCiderOffered': falafelCiderOffered,
        'burtQuestCompleted': burtQuestCompleted,
        'bittershellMapCompleted': bittershellMapCompleted,
        'meadowScavengerUnlocked': meadowScavengerUnlocked,
        'falafelTruceUnlocked': falafelTruceUnlocked,
        'janiceQuestStarted': janiceQuestStarted,
        'hasVocalTea': hasVocalTea,
        'janiceQuestCompleted': janiceQuestCompleted,
        'cosmoQuestStarted': cosmoQuestStarted,
        'tunedResonators': tunedResonators.toList()..sort(),
        'cosmoQuestCompleted': cosmoQuestCompleted,
        'donShelloQuestStarted': donShelloQuestStarted,
        'goldMicBlessed': goldMicBlessed,
        'buriedStashUnearthed': buriedStashUnearthed,
        'donShelloQuestCompleted': donShelloQuestCompleted,
        'tulaQuestStarted': tulaQuestStarted,
        'teaLightAltared': teaLightAltared,
        'tulaQuestCompleted': tulaQuestCompleted,
        'jimiQuestStarted': jimiQuestStarted,
        'jimiQuestCompleted': jimiQuestCompleted,
        'peteInterviewCompleted': peteInterviewCompleted,
        'walnutTripActive': walnutTripActive,
        'purpleDustActive': purpleDustActive,
        'nebulaActive': nebulaActive,
        'crowdMigrateMainRoots': crowdMigrateMainRoots,
        'finaleMontageShown': finaleMontageShown,
        'pinballHighScore': pinballHighScore,
        'sortingBeltHighScore': sortingBeltHighScore,
        if (mudSlidesCount > 0) 'mudSlidesCount': mudSlidesCount,
        if (mudFightsSplatted > 0) 'mudFightsSplatted': mudFightsSplatted,
        if (blueberryTripActive) 'blueberryTripActive': blueberryTripActive,
        if (blueberryStartDay > 0) 'blueberryStartDay': blueberryStartDay,
        if (blueberryStartMinute > 0)
          'blueberryStartMinute': blueberryStartMinute,
        if (blueberrySet1EndDay > 0) 'blueberrySet1EndDay': blueberrySet1EndDay,
        if (blueberrySet1EndMinute > 0)
          'blueberrySet1EndMinute': blueberrySet1EndMinute,
        if (blueberryExpiryDay > 0) 'blueberryExpiryDay': blueberryExpiryDay,
        if (blueberryExpiryMinute > 0)
          'blueberryExpiryMinute': blueberryExpiryMinute,
        if (blueberriesSharedCount > 0)
          'blueberriesSharedCount': blueberriesSharedCount,
      };

  @override
  List<Object?> get props => [
        fencesDropped,
        lanternsLit,
        firefliesActive,
        mossBridgesBloomed,
        slowWaveSwayUnlocked,
        dewDropsCollected,
        ziggyQuestStarted,
        ziggyQuestCompleted,
        breezewalkerQuestStarted,
        hasWillowPick,
        breezewalkerQuestCompleted,
        burtQuestStarted,
        falafelCiderOffered,
        burtQuestCompleted,
        bittershellMapCompleted,
        meadowScavengerUnlocked,
        falafelTruceUnlocked,
        janiceQuestStarted,
        hasVocalTea,
        janiceQuestCompleted,
        cosmoQuestStarted,
        tunedResonators,
        cosmoQuestCompleted,
        donShelloQuestStarted,
        goldMicBlessed,
        buriedStashUnearthed,
        donShelloQuestCompleted,
        tulaQuestStarted,
        teaLightAltared,
        tulaQuestCompleted,
        jimiQuestStarted,
        jimiQuestCompleted,
        peteInterviewCompleted,
        walnutTripActive,
        purpleDustActive,
        nebulaActive,
        crowdMigrateMainRoots,
        finaleMontageShown,
        pinballHighScore,
        sortingBeltHighScore,
        mudSlidesCount,
        mudFightsSplatted,
        blueberryTripActive,
        blueberryStartDay,
        blueberryStartMinute,
        blueberrySet1EndDay,
        blueberrySet1EndMinute,
        blueberryExpiryDay,
        blueberryExpiryMinute,
        blueberriesSharedCount,
        playerSwaying,
        playerDancing,
        playerDanceStyle,
        crowdAura,
        justListenStageMode,
      ];
}

class WorldFlagsNotifier extends StateNotifier<WorldFlags> {
  WorldFlagsNotifier() : super(const WorldFlags());

  void hydrate(WorldFlags flags) => state = flags;

  void update(WorldFlags Function(WorldFlags current) fn) {
    state = fn(state);
  }

  /// Applies scheduled track `worldEvent` triggers idempotently.
  void applyScheduledWorldEvent(String? eventKey) {
    if (eventKey == null) return;
    switch (eventKey) {
      case 'drop_front_gate_fences':
        if (!state.fencesDropped) {
          state = state.copyWith(fencesDropped: true);
        }
        break;
      case 'unlock_meadow_scavenger':
        state = state.copyWith(meadowScavengerUnlocked: true);
        break;
      case 'unlock_falafel_truce':
        state = state.copyWith(falafelTruceUnlocked: true);
        break;
      case 'light_evening_lanterns':
        state = state.copyWith(lanternsLit: true);
        break;
      case 'emerge_fireflies':
        state = state.copyWith(firefliesActive: true);
        break;
      case 'bloom_moss_bridges':
        state = state.copyWith(mossBridgesBloomed: true);
        break;
      case 'activate_andromeda_nebula':
        state = state.copyWith(nebulaActive: true);
        break;
      case 'activate_walnut_trip_shader':
        state = state.copyWith(walnutTripActive: true);
        break;
      case 'migrate_crowd_main_roots':
        state = state.copyWith(crowdMigrateMainRoots: true);
        break;
      case 'purple_walnut_dust':
        state = state.copyWith(purpleDustActive: true, walnutTripActive: false);
        break;
      default:
        break;
    }
  }

  void syncTransientShaderEvents(
    List<String?> activeWorldEvents, {
    int? currentDay,
    double? currentMinute,
  }) {
    final hasTrip = activeWorldEvents.contains('activate_walnut_trip_shader');
    final hasPurple = activeWorldEvents.contains('purple_walnut_dust');
    final hasNebula = activeWorldEvents.contains('activate_andromeda_nebula');
    final inSundayFinaleConvergence =
        activeWorldEvents.contains('migrate_crowd_main_roots') ||
            (currentDay == 3 && (currentMinute ?? 0.0) >= 1220.0);
    if (state.walnutTripActive != hasTrip ||
        state.purpleDustActive != hasPurple ||
        state.nebulaActive != hasNebula ||
        (currentDay != null &&
            state.crowdMigrateMainRoots != inSundayFinaleConvergence)) {
      state = state.copyWith(
        walnutTripActive: hasTrip,
        purpleDustActive: hasPurple,
        nebulaActive: hasNebula,
        crowdMigrateMainRoots: currentDay != null
            ? inSundayFinaleConvergence
            : state.crowdMigrateMainRoots,
      );
    }
  }

  void collectDewDrop(String dropId) {
    if (state.dewDropsCollected.contains(dropId)) return;
    state = state.copyWith(
      dewDropsCollected: {...state.dewDropsCollected, dropId},
    );
  }

  void tuneResonator(String resonatorId) {
    if (state.tunedResonators.contains(resonatorId)) return;
    state = state.copyWith(
      tunedResonators: {...state.tunedResonators, resonatorId},
    );
  }

  void togglePlayerSway() {
    state = state.copyWith(playerSwaying: !state.playerSwaying);
  }

  void togglePlayerDance() {
    final next = !state.playerDancing;
    state = state.copyWith(
      playerDancing: next,
      crowdAura: next ? (state.crowdAura + 0.08).clamp(0.0, 1.0) : state.crowdAura,
    );
  }

  void setPlayerDancing(bool dancing) {
    if (state.playerDancing == dancing) return;
    state = state.copyWith(playerDancing: dancing);
  }

  void cyclePlayerDanceStyle() {
    final nextStyle =
        (state.playerDanceStyle + 1) % WorldFlags.danceStyleNames.length;
    state = state.copyWith(
      playerDancing: true,
      playerDanceStyle: nextStyle,
    );
  }

  void setCrowdAura(double aura) {
    state = state.copyWith(crowdAura: aura.clamp(0.0, 1.0));
  }

  void toggleJustListenMode() {
    state = state.copyWith(justListenStageMode: !state.justListenStageMode);
  }

  void recordPinballScore(int score) {
    if (score > state.pinballHighScore) {
      state = state.copyWith(pinballHighScore: score);
    }
  }

  void recordSortingBeltScore(int score) {
    if (score > state.sortingBeltHighScore) {
      state = state.copyWith(sortingBeltHighScore: score);
    }
  }

  int recordMudSlide() {
    final next = state.mudSlidesCount + 1;
    state = state.copyWith(
      mudSlidesCount: next,
      crowdAura: (state.crowdAura + 0.06).clamp(0.0, 1.0),
    );
    return next;
  }

  int recordMudSplat() {
    final next = state.mudFightsSplatted + 1;
    state = state.copyWith(
      mudFightsSplatted: next,
      crowdAura: (state.crowdAura + 0.09).clamp(0.0, 1.0),
    );
    return next;
  }

  void activateElectricBlueberries(
    SetlistCatalog catalog, {
    required int day,
    required double minuteOfDay,
  }) {
    final win = WorldFlags.computeTwoSetWindow(
      catalog,
      startDay: day,
      startMinute: minuteOfDay,
    );
    state = state.copyWith(
      blueberryTripActive: true,
      blueberryStartDay: day,
      blueberryStartMinute: minuteOfDay,
      blueberrySet1EndDay: win.set1Day,
      blueberrySet1EndMinute: win.set1EndMin,
      blueberryExpiryDay: win.set2Day,
      blueberryExpiryMinute: win.set2EndMin,
      blueberriesSharedCount: state.blueberriesSharedCount + 1,
      crowdAura: (state.crowdAura + 0.16).clamp(0.0, 1.0),
    );
  }

  /// Clears `blueberryTripActive` once the 2nd musical set completes (or if clock rewinds before start).
  /// Returns `true` if the trip naturally finished after 2 sets.
  bool clearExpiredBlueberryTrip(int day, double minuteOfDay) {
    if (!state.blueberryTripActive) return false;
    final pastExpiry = WorldFlags._compareClock(
          day,
          minuteOfDay,
          state.blueberryExpiryDay,
          state.blueberryExpiryMinute,
        ) >
        0;
    final rewoundBeforeStart = WorldFlags._compareClock(
          day,
          minuteOfDay,
          state.blueberryStartDay,
          state.blueberryStartMinute - 1.0,
        ) <
        0;
    if (pastExpiry || rewoundBeforeStart) {
      state = state.copyWith(blueberryTripActive: false);
      return pastExpiry;
    }
    return false;
  }
}
