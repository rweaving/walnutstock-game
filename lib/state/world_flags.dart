import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import 'journal_state.dart';

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
    // Festival Life Expansion: 8 new side quests, Vendor Row, & crowd micro-events
    this.sunnyPhotoQuestStarted = false,
    this.sunnyPhotoQuestCompleted = false,
    this.roxieStringQuestStarted = false,
    this.hasNickelString = false,
    this.roxieStringQuestCompleted = false,
    this.pennyTapestryQuestStarted = false,
    this.fabricSwatches = const {},
    this.pennyTapestryQuestCompleted = false,
    this.mateoTapeQuestStarted = false,
    this.mateoTapeQuestCompleted = false,
    this.fernCompassQuestStarted = false,
    this.hasBrassCompass = false,
    this.fernCompassQuestCompleted = false,
    this.astraBubbleQuestStarted = false,
    this.bubbledInDome = false,
    this.astraBubbleQuestCompleted = false,
    this.woodyMunchiesQuestStarted = false,
    this.woodyMunchiesQuestCompleted = false,
    this.rustyArcadeQuestStarted = false,
    this.rustyArcadeQuestCompleted = false,
    this.daisyFreeBubblesGifted = false,
    this.beachBallMaxRally = 0,
    this.collectedGroundBeadIds = const {},
    // Transient runtime aura, buffs, & handheld festival gadgets
    this.playerSwaying = false,
    this.playerDancing = false,
    this.playerDanceStyle = 0,
    this.crowdAura = 0.0,
    this.justListenStageMode = false,
    this.speedBuffSec = 0.0,
    this.speedBuffBonus = 0.0,
    this.activeFoodBuffLabel,
    this.mudGripSec = 0.0,
    this.fireflyAuraSec = 0.0,
    this.sparklerLit = false,
    this.picnicBlanketDeployed = false,
    this.picnicBlanketX = 0.0,
    this.picnicBlanketY = 0.0,
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
      sunnyPhotoQuestStarted:
          json['sunnyPhotoQuestStarted'] as bool? ?? false,
      sunnyPhotoQuestCompleted:
          json['sunnyPhotoQuestCompleted'] as bool? ?? false,
      roxieStringQuestStarted:
          json['roxieStringQuestStarted'] as bool? ?? false,
      hasNickelString: json['hasNickelString'] as bool? ?? false,
      roxieStringQuestCompleted:
          json['roxieStringQuestCompleted'] as bool? ?? false,
      pennyTapestryQuestStarted:
          json['pennyTapestryQuestStarted'] as bool? ?? false,
      fabricSwatches: strSet('fabricSwatches'),
      pennyTapestryQuestCompleted:
          json['pennyTapestryQuestCompleted'] as bool? ?? false,
      mateoTapeQuestStarted: json['mateoTapeQuestStarted'] as bool? ?? false,
      mateoTapeQuestCompleted:
          json['mateoTapeQuestCompleted'] as bool? ?? false,
      fernCompassQuestStarted:
          json['fernCompassQuestStarted'] as bool? ?? false,
      hasBrassCompass: json['hasBrassCompass'] as bool? ?? false,
      fernCompassQuestCompleted:
          json['fernCompassQuestCompleted'] as bool? ?? false,
      astraBubbleQuestStarted:
          json['astraBubbleQuestStarted'] as bool? ?? false,
      bubbledInDome: json['bubbledInDome'] as bool? ?? false,
      astraBubbleQuestCompleted:
          json['astraBubbleQuestCompleted'] as bool? ?? false,
      woodyMunchiesQuestStarted:
          json['woodyMunchiesQuestStarted'] as bool? ?? false,
      woodyMunchiesQuestCompleted:
          json['woodyMunchiesQuestCompleted'] as bool? ?? false,
      rustyArcadeQuestStarted:
          json['rustyArcadeQuestStarted'] as bool? ?? false,
      rustyArcadeQuestCompleted:
          json['rustyArcadeQuestCompleted'] as bool? ?? false,
      daisyFreeBubblesGifted:
          json['daisyFreeBubblesGifted'] as bool? ?? false,
      beachBallMaxRally: (json['beachBallMaxRally'] as num?)?.toInt() ?? 0,
      collectedGroundBeadIds: strSet('collectedGroundBeadIds'),
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

  // Festival Life Expansion persisted flags
  final bool sunnyPhotoQuestStarted;
  final bool sunnyPhotoQuestCompleted;
  final bool roxieStringQuestStarted;
  final bool hasNickelString;
  final bool roxieStringQuestCompleted;
  final bool pennyTapestryQuestStarted;
  final Set<String> fabricSwatches;
  final bool pennyTapestryQuestCompleted;
  final bool mateoTapeQuestStarted;
  final bool mateoTapeQuestCompleted;
  final bool fernCompassQuestStarted;
  final bool hasBrassCompass;
  final bool fernCompassQuestCompleted;
  final bool astraBubbleQuestStarted;
  final bool bubbledInDome;
  final bool astraBubbleQuestCompleted;
  final bool woodyMunchiesQuestStarted;
  final bool woodyMunchiesQuestCompleted;
  final bool rustyArcadeQuestStarted;
  final bool rustyArcadeQuestCompleted;
  final bool daisyFreeBubblesGifted;
  final int beachBallMaxRally;
  final Set<String> collectedGroundBeadIds;

  // Transient runtime aura, buffs & handheld gadgets
  final bool playerSwaying;
  final bool playerDancing;
  final int playerDanceStyle;
  final double crowdAura;
  final bool justListenStageMode;
  final double speedBuffSec;
  final double speedBuffBonus;
  final String? activeFoodBuffLabel;
  final double mudGripSec;
  final double fireflyAuraSec;
  final bool sparklerLit;
  final bool picnicBlanketDeployed;
  final double picnicBlanketX;
  final double picnicBlanketY;

  String get currentDanceStyleLabel =>
      danceStyleNames[playerDanceStyle % danceStyleNames.length];

  bool get mudGripActive => mudGripSec > 0.0;
  bool get fireflyAuraActive => fireflyAuraSec > 0.0;
  double get activeSpeedMultiplier =>
      speedBuffSec > 0.0 ? (1.0 + speedBuffBonus) : 1.0;

  double get activeBuffRemainingSec {
    var best = speedBuffSec;
    if (mudGripSec > best) best = mudGripSec;
    if (fireflyAuraSec > best) best = fireflyAuraSec;
    return best;
  }

  int get completedQuestCount {
    var count = 0;
    for (final done in [
      ziggyQuestCompleted,
      breezewalkerQuestCompleted,
      burtQuestCompleted,
      bittershellMapCompleted,
      janiceQuestCompleted,
      cosmoQuestCompleted,
      donShelloQuestCompleted,
      tulaQuestCompleted,
      jimiQuestCompleted,
      peteInterviewCompleted,
      sunnyPhotoQuestCompleted,
      roxieStringQuestCompleted,
      pennyTapestryQuestCompleted,
      mateoTapeQuestCompleted,
      fernCompassQuestCompleted,
      astraBubbleQuestCompleted,
      woodyMunchiesQuestCompleted,
      rustyArcadeQuestCompleted,
    ]) {
      if (done) count++;
    }
    return count;
  }

  /// Returns `'completed' | 'ready' | 'in_progress' | 'available'` for any quest ID.
  String questStatusFor(
    String questId,
    JournalState journal, {
    int currentDay = 1,
    bool encoreUnlocked = false,
  }) {
    switch (questId) {
      case 'quest_sunny_polaroids':
        if (sunnyPhotoQuestCompleted) return 'completed';
        if (sunnyPhotoQuestStarted && journal.snappedPolaroidStages.length >= 3) {
          return 'ready';
        }
        return sunnyPhotoQuestStarted ? 'in_progress' : 'available';
      case 'quest_roxie_string':
        if (roxieStringQuestCompleted) return 'completed';
        if (roxieStringQuestStarted &&
            (hasNickelString || journal.hasItem('quest_nickel_string'))) {
          return 'ready';
        }
        return roxieStringQuestStarted ? 'in_progress' : 'available';
      case 'quest_penny_tapestry':
        if (pennyTapestryQuestCompleted) return 'completed';
        if (pennyTapestryQuestStarted && fabricSwatches.length >= 3) {
          return 'ready';
        }
        return pennyTapestryQuestStarted ? 'in_progress' : 'available';
      case 'quest_mateo_bootleg':
        if (mateoTapeQuestCompleted) return 'completed';
        if (mateoTapeQuestStarted &&
            journal.recordedBootlegStages.length >= 2) {
          return 'ready';
        }
        return mateoTapeQuestStarted ? 'in_progress' : 'available';
      case 'quest_fern_compass':
        if (fernCompassQuestCompleted) return 'completed';
        if (hasBrassCompass || journal.hasItem('quest_brass_compass')) {
          return 'ready';
        }
        return fernCompassQuestStarted ? 'in_progress' : 'available';
      case 'quest_astra_bubbles':
        if (astraBubbleQuestCompleted) return 'completed';
        if (bubbledInDome) return 'ready';
        return astraBubbleQuestStarted ? 'in_progress' : 'available';
      case 'quest_woody_munchies':
        if (woodyMunchiesQuestCompleted) return 'completed';
        if (woodyMunchiesQuestStarted &&
            journal.hasItem('food_falafel_wrap') &&
            journal.hasItem('drink_chamomile_tea')) {
          return 'ready';
        }
        return woodyMunchiesQuestStarted ? 'in_progress' : 'available';
      case 'quest_rusty_arcade':
        if (rustyArcadeQuestCompleted) return 'completed';
        if (rustyArcadeQuestStarted &&
            pinballHighScore >= 1200 &&
            sortingBeltHighScore >= 100) {
          return 'ready';
        }
        return rustyArcadeQuestStarted ? 'in_progress' : 'available';
      case 'quest_falafel_truce':
        if (burtQuestCompleted) return 'completed';
        if (burtQuestStarted && falafelCiderOffered) return 'ready';
        return burtQuestStarted ? 'in_progress' : 'available';
      case 'quest_janice_tea':
        if (janiceQuestCompleted) return 'completed';
        if (janiceQuestStarted && hasVocalTea) return 'ready';
        return janiceQuestStarted ? 'in_progress' : 'available';
      case 'quest_ziggy_dew':
        if (ziggyQuestCompleted) return 'completed';
        if (ziggyQuestStarted && dewDropsCollected.length >= 3) return 'ready';
        return ziggyQuestStarted ? 'in_progress' : 'available';
      case 'quest_willow_pick':
        if (breezewalkerQuestCompleted) return 'completed';
        if (breezewalkerQuestStarted && hasWillowPick) return 'ready';
        return breezewalkerQuestStarted ? 'in_progress' : 'available';
      case 'quest_cosmo_resonators':
        if (cosmoQuestCompleted) return 'completed';
        if (tunedResonators.length >= 3) return 'ready';
        return cosmoQuestStarted ? 'in_progress' : 'available';
      case 'quest_don_shello_mic':
        if (donShelloQuestCompleted) return 'completed';
        if (donShelloQuestStarted && goldMicBlessed && buriedStashUnearthed) {
          return 'ready';
        }
        return donShelloQuestStarted ? 'in_progress' : 'available';
      case 'quest_tula_fog_bells':
        if (tulaQuestCompleted) return 'completed';
        if (teaLightAltared) return 'ready';
        return tulaQuestStarted ? 'in_progress' : 'available';
      case 'quest_bittershell_map':
        return bittershellMapCompleted ? 'completed' : 'available';
      case 'quest_free_orchard':
        if (peteInterviewCompleted) return 'completed';
        if (currentDay >= 3 || encoreUnlocked) return 'ready';
        return fencesDropped ? 'in_progress' : 'available';
      case 'quest_great_walnut_ritual':
        if (jimiQuestCompleted) return 'completed';
        if (jimiQuestStarted && hasHarmonyMilestoneForJimi) return 'ready';
        return jimiQuestStarted ? 'in_progress' : 'available';
      default:
        return 'available';
    }
  }

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
    bool? sunnyPhotoQuestStarted,
    bool? sunnyPhotoQuestCompleted,
    bool? roxieStringQuestStarted,
    bool? hasNickelString,
    bool? roxieStringQuestCompleted,
    bool? pennyTapestryQuestStarted,
    Set<String>? fabricSwatches,
    bool? pennyTapestryQuestCompleted,
    bool? mateoTapeQuestStarted,
    bool? mateoTapeQuestCompleted,
    bool? fernCompassQuestStarted,
    bool? hasBrassCompass,
    bool? fernCompassQuestCompleted,
    bool? astraBubbleQuestStarted,
    bool? bubbledInDome,
    bool? astraBubbleQuestCompleted,
    bool? woodyMunchiesQuestStarted,
    bool? woodyMunchiesQuestCompleted,
    bool? rustyArcadeQuestStarted,
    bool? rustyArcadeQuestCompleted,
    bool? daisyFreeBubblesGifted,
    int? beachBallMaxRally,
    Set<String>? collectedGroundBeadIds,
    bool? playerSwaying,
    bool? playerDancing,
    int? playerDanceStyle,
    double? crowdAura,
    bool? justListenStageMode,
    double? speedBuffSec,
    double? speedBuffBonus,
    String? activeFoodBuffLabel,
    bool clearFoodBuffLabel = false,
    double? mudGripSec,
    double? fireflyAuraSec,
    bool? sparklerLit,
    bool? picnicBlanketDeployed,
    double? picnicBlanketX,
    double? picnicBlanketY,
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
      sunnyPhotoQuestStarted:
          sunnyPhotoQuestStarted ?? this.sunnyPhotoQuestStarted,
      sunnyPhotoQuestCompleted:
          sunnyPhotoQuestCompleted ?? this.sunnyPhotoQuestCompleted,
      roxieStringQuestStarted:
          roxieStringQuestStarted ?? this.roxieStringQuestStarted,
      hasNickelString: hasNickelString ?? this.hasNickelString,
      roxieStringQuestCompleted:
          roxieStringQuestCompleted ?? this.roxieStringQuestCompleted,
      pennyTapestryQuestStarted:
          pennyTapestryQuestStarted ?? this.pennyTapestryQuestStarted,
      fabricSwatches: fabricSwatches ?? this.fabricSwatches,
      pennyTapestryQuestCompleted:
          pennyTapestryQuestCompleted ?? this.pennyTapestryQuestCompleted,
      mateoTapeQuestStarted:
          mateoTapeQuestStarted ?? this.mateoTapeQuestStarted,
      mateoTapeQuestCompleted:
          mateoTapeQuestCompleted ?? this.mateoTapeQuestCompleted,
      fernCompassQuestStarted:
          fernCompassQuestStarted ?? this.fernCompassQuestStarted,
      hasBrassCompass: hasBrassCompass ?? this.hasBrassCompass,
      fernCompassQuestCompleted:
          fernCompassQuestCompleted ?? this.fernCompassQuestCompleted,
      astraBubbleQuestStarted:
          astraBubbleQuestStarted ?? this.astraBubbleQuestStarted,
      bubbledInDome: bubbledInDome ?? this.bubbledInDome,
      astraBubbleQuestCompleted:
          astraBubbleQuestCompleted ?? this.astraBubbleQuestCompleted,
      woodyMunchiesQuestStarted:
          woodyMunchiesQuestStarted ?? this.woodyMunchiesQuestStarted,
      woodyMunchiesQuestCompleted:
          woodyMunchiesQuestCompleted ?? this.woodyMunchiesQuestCompleted,
      rustyArcadeQuestStarted:
          rustyArcadeQuestStarted ?? this.rustyArcadeQuestStarted,
      rustyArcadeQuestCompleted:
          rustyArcadeQuestCompleted ?? this.rustyArcadeQuestCompleted,
      daisyFreeBubblesGifted:
          daisyFreeBubblesGifted ?? this.daisyFreeBubblesGifted,
      beachBallMaxRally: beachBallMaxRally ?? this.beachBallMaxRally,
      collectedGroundBeadIds:
          collectedGroundBeadIds ?? this.collectedGroundBeadIds,
      playerSwaying: playerSwaying ?? this.playerSwaying,
      playerDancing: playerDancing ?? this.playerDancing,
      playerDanceStyle: playerDanceStyle ?? this.playerDanceStyle,
      crowdAura: crowdAura ?? this.crowdAura,
      justListenStageMode: justListenStageMode ?? this.justListenStageMode,
      speedBuffSec: speedBuffSec ?? this.speedBuffSec,
      speedBuffBonus: speedBuffBonus ?? this.speedBuffBonus,
      activeFoodBuffLabel: clearFoodBuffLabel
          ? null
          : (activeFoodBuffLabel ?? this.activeFoodBuffLabel),
      mudGripSec: mudGripSec ?? this.mudGripSec,
      fireflyAuraSec: fireflyAuraSec ?? this.fireflyAuraSec,
      sparklerLit: sparklerLit ?? this.sparklerLit,
      picnicBlanketDeployed:
          picnicBlanketDeployed ?? this.picnicBlanketDeployed,
      picnicBlanketX: picnicBlanketX ?? this.picnicBlanketX,
      picnicBlanketY: picnicBlanketY ?? this.picnicBlanketY,
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
        if (sunnyPhotoQuestStarted)
          'sunnyPhotoQuestStarted': sunnyPhotoQuestStarted,
        if (sunnyPhotoQuestCompleted)
          'sunnyPhotoQuestCompleted': sunnyPhotoQuestCompleted,
        if (roxieStringQuestStarted)
          'roxieStringQuestStarted': roxieStringQuestStarted,
        if (hasNickelString) 'hasNickelString': hasNickelString,
        if (roxieStringQuestCompleted)
          'roxieStringQuestCompleted': roxieStringQuestCompleted,
        if (pennyTapestryQuestStarted)
          'pennyTapestryQuestStarted': pennyTapestryQuestStarted,
        if (fabricSwatches.isNotEmpty)
          'fabricSwatches': fabricSwatches.toList()..sort(),
        if (pennyTapestryQuestCompleted)
          'pennyTapestryQuestCompleted': pennyTapestryQuestCompleted,
        if (mateoTapeQuestStarted)
          'mateoTapeQuestStarted': mateoTapeQuestStarted,
        if (mateoTapeQuestCompleted)
          'mateoTapeQuestCompleted': mateoTapeQuestCompleted,
        if (fernCompassQuestStarted)
          'fernCompassQuestStarted': fernCompassQuestStarted,
        if (hasBrassCompass) 'hasBrassCompass': hasBrassCompass,
        if (fernCompassQuestCompleted)
          'fernCompassQuestCompleted': fernCompassQuestCompleted,
        if (astraBubbleQuestStarted)
          'astraBubbleQuestStarted': astraBubbleQuestStarted,
        if (bubbledInDome) 'bubbledInDome': bubbledInDome,
        if (astraBubbleQuestCompleted)
          'astraBubbleQuestCompleted': astraBubbleQuestCompleted,
        if (woodyMunchiesQuestStarted)
          'woodyMunchiesQuestStarted': woodyMunchiesQuestStarted,
        if (woodyMunchiesQuestCompleted)
          'woodyMunchiesQuestCompleted': woodyMunchiesQuestCompleted,
        if (rustyArcadeQuestStarted)
          'rustyArcadeQuestStarted': rustyArcadeQuestStarted,
        if (rustyArcadeQuestCompleted)
          'rustyArcadeQuestCompleted': rustyArcadeQuestCompleted,
        if (daisyFreeBubblesGifted)
          'daisyFreeBubblesGifted': daisyFreeBubblesGifted,
        if (beachBallMaxRally > 0) 'beachBallMaxRally': beachBallMaxRally,
        if (collectedGroundBeadIds.isNotEmpty)
          'collectedGroundBeadIds': collectedGroundBeadIds.toList()..sort(),
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
        sunnyPhotoQuestStarted,
        sunnyPhotoQuestCompleted,
        roxieStringQuestStarted,
        hasNickelString,
        roxieStringQuestCompleted,
        pennyTapestryQuestStarted,
        fabricSwatches,
        pennyTapestryQuestCompleted,
        mateoTapeQuestStarted,
        mateoTapeQuestCompleted,
        fernCompassQuestStarted,
        hasBrassCompass,
        fernCompassQuestCompleted,
        astraBubbleQuestStarted,
        bubbledInDome,
        astraBubbleQuestCompleted,
        woodyMunchiesQuestStarted,
        woodyMunchiesQuestCompleted,
        rustyArcadeQuestStarted,
        rustyArcadeQuestCompleted,
        daisyFreeBubblesGifted,
        beachBallMaxRally,
        collectedGroundBeadIds,
        playerSwaying,
        playerDancing,
        playerDanceStyle,
        crowdAura,
        justListenStageMode,
        speedBuffSec,
        speedBuffBonus,
        activeFoodBuffLabel,
        mudGripSec,
        fireflyAuraSec,
        sparklerLit,
        picnicBlanketDeployed,
        picnicBlanketX,
        picnicBlanketY,
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

  void addFabricSwatch(String swatchId) {
    if (state.fabricSwatches.contains(swatchId)) return;
    state = state.copyWith(
      fabricSwatches: {...state.fabricSwatches, swatchId},
    );
  }

  bool collectGroundBead(String beadId) {
    if (state.collectedGroundBeadIds.contains(beadId)) return false;
    state = state.copyWith(
      collectedGroundBeadIds: {...state.collectedGroundBeadIds, beadId},
    );
    return true;
  }

  bool recordBeachBallRally(int rally) {
    if (rally <= state.beachBallMaxRally) return false;
    state = state.copyWith(beachBallMaxRally: rally);
    return true;
  }

  void applyFoodBuff({
    required String label,
    double speedBonus = 0.0,
    double speedDuration = 0.0,
    double mudGripDuration = 0.0,
    double fireflyDuration = 0.0,
    double auraBoost = 0.0,
  }) {
    state = state.copyWith(
      activeFoodBuffLabel: label,
      speedBuffBonus: speedDuration > 0 ? speedBonus : state.speedBuffBonus,
      speedBuffSec:
          speedDuration > state.speedBuffSec ? speedDuration : state.speedBuffSec,
      mudGripSec:
          mudGripDuration > state.mudGripSec ? mudGripDuration : state.mudGripSec,
      fireflyAuraSec: fireflyDuration > state.fireflyAuraSec
          ? fireflyDuration
          : state.fireflyAuraSec,
      crowdAura: (state.crowdAura + auraBoost).clamp(0.0, 1.0),
    );
  }

  void tickBuffTimers(double dt) {
    if (dt <= 0) return;
    if (state.speedBuffSec <= 0 &&
        state.mudGripSec <= 0 &&
        state.fireflyAuraSec <= 0) {
      return;
    }
    final nextSpeed = (state.speedBuffSec - dt).clamp(0.0, 9999.0);
    final nextMud = (state.mudGripSec - dt).clamp(0.0, 9999.0);
    final nextFirefly = (state.fireflyAuraSec - dt).clamp(0.0, 9999.0);
    final allExpired = nextSpeed <= 0 && nextMud <= 0 && nextFirefly <= 0;
    state = state.copyWith(
      speedBuffSec: nextSpeed,
      speedBuffBonus: nextSpeed > 0 ? state.speedBuffBonus : 0.0,
      mudGripSec: nextMud,
      fireflyAuraSec: nextFirefly,
      clearFoodBuffLabel: allExpired,
    );
  }

  void toggleSparkler() {
    state = state.copyWith(sparklerLit: !state.sparklerLit);
  }

  void setSparklerLit(bool lit) {
    if (state.sparklerLit == lit) return;
    state = state.copyWith(sparklerLit: lit);
  }

  bool togglePicnicBlanket(double x, double y) {
    final next = !state.picnicBlanketDeployed;
    state = state.copyWith(
      picnicBlanketDeployed: next,
      picnicBlanketX: next ? x : state.picnicBlanketX,
      picnicBlanketY: next ? y : state.picnicBlanketY,
    );
    return next;
  }
}
