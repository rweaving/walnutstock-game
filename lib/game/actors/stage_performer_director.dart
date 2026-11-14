import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/models.dart';
import '../../state/festival_clock.dart';
import '../world/concert_light_show.dart';
import '../world/day_night_atmosphere.dart';
import '../world/stage_3d_rig_component.dart';

enum PerformerInstrument {
  leadVocalMic,
  electricGuitar,
  hendrixStrat,
  acousticLute,
  acousticGuitar,
  bassGuitar,
  crystalBass,
  drumKit,
  hammondOrgan,
  congasTimbales,
  turntablesDj,
  paBroadcastMic,
  tambourineVocals,
}

extension PerformerInstrumentChoreoX on PerformerInstrument {
  bool get isPercussion =>
      this == PerformerInstrument.drumKit ||
      this == PerformerInstrument.congasTimbales;

  bool get isBass =>
      this == PerformerInstrument.bassGuitar ||
      this == PerformerInstrument.crystalBass;

  bool get isKeysOrDj =>
      this == PerformerInstrument.hammondOrgan ||
      this == PerformerInstrument.turntablesDj;

  bool get isVocalist =>
      this == PerformerInstrument.leadVocalMic ||
      this == PerformerInstrument.tambourineVocals;

  bool get isGuitarist =>
      this == PerformerInstrument.electricGuitar ||
      this == PerformerInstrument.hendrixStrat ||
      this == PerformerInstrument.acousticGuitar ||
      this == PerformerInstrument.acousticLute ||
      this == PerformerInstrument.crystalBass;
}

PerformerChoreoSample sampleChoreographyForPerformer({
  required StageShowFrame show,
  required PerformerInstrument instrument,
  required bool isLeadPerformer,
  required int rolePhaseIndex,
}) {
  return show.samplePerformer(
    isPercussion: instrument.isPercussion,
    isBass: instrument.isBass,
    isKeysOrDj: instrument.isKeysOrDj,
    isVocalist: instrument.isVocalist,
    isGuitarist: instrument.isGuitarist,
    isLeadPerformer: isLeadPerformer,
    rolePhaseIndex: rolePhaseIndex,
  );
}

class NpcStageMark {
  const NpcStageMark({
    required this.npcId,
    required this.stageId,
    required this.trackNumber,
    required this.stagePos,
    required this.instrument,
    required this.spotlightColor,
    this.isLeadPerformer = true,
    this.instrumentBodyColor,
    this.instrumentPickguardColor,
    this.isSoundcheck = false,
  });

  final String npcId;
  final String stageId;
  final int trackNumber;
  final Offset stagePos;
  final PerformerInstrument instrument;
  final Color spotlightColor;
  final bool isLeadPerformer;
  final Color? instrumentBodyColor;
  final Color? instrumentPickguardColor;
  final bool isSoundcheck;
}

class BandEnsembleMemberSpec {
  const BandEnsembleMemberSpec({
    required this.id,
    required this.stageId,
    required this.sheetKey,
    required this.stagePos,
    required this.instrument,
    required this.accentColor,
    this.isLeadPerformer = false,
    this.instrumentBodyColor,
    this.instrumentPickguardColor,
  });

  final String id;
  final String stageId;
  final String sheetKey;
  final Offset stagePos;
  final PerformerInstrument instrument;
  final Color accentColor;
  final bool isLeadPerformer;
  final Color? instrumentBodyColor;
  final Color? instrumentPickguardColor;
}

/// Coordinates on-stage named NPC headliners, 25 unique bespoke ensemble musicians,
/// and sample-synced concert light shows across all 30 scheduled tracks.
class StagePerformerDirector {
  StagePerformerDirector({
    required this.catalog,
    required this.characterSheets,
    required this.metricsGetter,
    required this.bassGetter,
    required this.timeGetter,
    this.lightshows = ConcertLightShowLibrary.empty,
    this.trackTimeGetter,
  });

  /// All 70 bespoke ensemble musician sprite sheet keys (`assets/images/characters/<key>_sheet.png`).
  static const List<String> ensembleSheetKeys = <String>[
    'perf_meadow_bass',
    'perf_carlos_santana',
    'perf_santana_congas',
    'perf_santana_drums',
    'perf_santana_organ',
    'perf_kozmic_guitar',
    'perf_kozmic_drums',
    'perf_kozmic_organ',
    'perf_john_fogerty',
    'perf_tom_fogerty',
    'perf_stu_cook',
    'perf_doug_clifford',
    'perf_mama_cass',
    'perf_michelle_husk',
    'perf_denny_husk',
    'perf_john_husk',
    'perf_billy_cox',
    'perf_mitch_mitchell',
    'perf_urbano_dj',
    'perf_urbano_perc',
    'perf_cosmo_synth',
    'perf_cosmo_perc',
    'perf_li_drums',
    'perf_li_bass',
    'perf_li_organ',
    // Track 1: Nutcracker Joe & The Hull Band
    'perf_nutcracker_joe',
    'perf_hullband_guitar',
    'perf_hullband_bass',
    'perf_hullband_drums',
    // Track 3: Richie Shellens Acoustic Trio
    'perf_richie_shellens',
    'perf_richie_guitar2',
    'perf_richie_congas',
    // Track 4: The Walnut Blues Band
    'perf_blues_frontman',
    'perf_blues_organ',
    'perf_blues_bass',
    'perf_blues_drums',
    // Track 5: Melanie Sapka
    'perf_melanie_sapka',
    // Track 6: Arlo Nutthrie
    'perf_arlo_nutthrie',
    'perf_arlo_dobro',
    'perf_arlo_bass',
    'perf_arlo_drums',
    // Track 9: Canned Walnut
    'perf_canned_bear',
    'perf_canned_blindowl',
    'perf_canned_bass',
    'perf_canned_drums',
    // Track 10: Mountain Grove
    'perf_mountain_leslie',
    'perf_mountain_felix',
    'perf_mountain_drums',
    // Track 13: Crosby, Stills, Nash & Walnut
    'perf_csny_stills',
    'perf_csny_crosby',
    'perf_csny_nash',
    'perf_csny_walnut',
    // Tracks 16 & 17: The Hull
    'perf_hull_daltrey',
    'perf_hull_townshend',
    'perf_hull_entwistle',
    'perf_hull_moon',
    // Track 21: Country Joe & The Nut
    'perf_country_joe',
    'perf_fish_barry',
    'perf_fish_organ',
    'perf_fish_drums',
    // Track 22: Jefferson Orchard
    'perf_jefferson_grace',
    'perf_jefferson_marty',
    'perf_jefferson_jorma',
    'perf_jefferson_jack',
    'perf_jefferson_drums',
    // Track 23: The Grateful Nut
    'perf_grateful_jerry',
    'perf_grateful_bob',
    'perf_grateful_phil',
    'perf_grateful_pigpen',
    'perf_grateful_drums',
  ];

  final SetlistCatalog catalog;
  final Map<String, Image> characterSheets;
  final DayNightMetrics Function() metricsGetter;
  final double Function() bassGetter;
  final double Function() timeGetter;
  final ConcertLightShowLibrary lightshows;
  final double Function(ScheduledTrack track, FestivalClockState clock)?
      trackTimeGetter;

  final Map<String, LiveStageVisualState> _liveStages = {};
  final Map<String, NpcStageMark> _activeNpcMarks = {};
  final Map<String, StageBandMemberComponent> _spawnedBandComponents = {};
  List<BandEnsembleMemberSpec> _activeEnsembleSpecs = const [];

  Map<String, LiveStageVisualState> get liveStages => _liveStages;
  Map<String, NpcStageMark> get activeNpcMarks => _activeNpcMarks;
  List<BandEnsembleMemberSpec> get activeEnsembleSpecs => _activeEnsembleSpecs;

  /// Off-stage greenroom/rest coordinate for named performers when they have no active set.
  static Offset offStageRestPositionFor(NpcSpec spec) {
    switch (spec.id) {
      case 'literally_infinite':
        // Off the Main Roots wooden deck (southwest stage steps) so the deck stays clear between sets!
        return const Offset(496.0, 462.0);
      case 'jimi_hendshell':
        // Just south of the Main Roots stage riser (within 30px of spawn for quest turn-in, off the wood deck)
        return const Offset(584.0, 460.0);
      case 'cosmo_shellvoy':
        // South perimeter of Andromeda crystal floor when off-set (steps up to center 344 dais at Midnight!)
        return const Offset(1760.0, 384.0);
      default:
        return Offset(spec.spawnX, spec.spawnY);
    }
  }

  void updateSchedule({
    required World world,
    required FestivalClockState clock,
  }) {
    _liveStages.clear();
    _activeNpcMarks.clear();
    final ensembleOut = <BandEnsembleMemberSpec>[];

    final activeTracks = catalog.activeTracksAt(clock.day, clock.minuteOfDay);
    for (final track in activeTracks) {
      final palette = _stageColorsForTrack(track);
      final (npcMarks, bandMembers) =
          rosterForTrack(track, isSoundcheck: false);

      final trackTimeSec = trackTimeGetter != null
          ? trackTimeGetter!(track, clock)
          : track.seekOffsetSeconds(
              clock.minuteOfDay,
              catalog.clockMinutesPerRealSecond,
            );
      final show = lightshows.sampleTrack(track, trackTimeSec);
      final soloFocus = _resolveSoloFocusPos(
        show: show,
        npcMarks: npcMarks,
        bandMembers: bandMembers,
      );

      _liveStages[track.stageId] = LiveStageVisualState(
        stageId: track.stageId,
        track: track,
        primaryColor: palette.$1,
        secondaryColor: palette.$2,
        show: show,
        soloFocusPos: soloFocus,
      );

      for (final mark in npcMarks) {
        _activeNpcMarks[mark.npcId] = mark;
      }
      ensembleOut.addAll(bandMembers);
    }

    // Soundcheck pre-arrival: 3.5 in-game minutes before a set starts on an open stage,
    // named NPC performers begin walking onto stage to tune up!
    for (final track in catalog.tracks) {
      if (track.day != clock.day) continue;
      if (_liveStages.containsKey(track.stageId)) continue;
      final minsUntil = track.startMinute - clock.minuteOfDay;
      if (minsUntil > 0.0 && minsUntil <= 3.5) {
        final (npcMarks, _) = rosterForTrack(track, isSoundcheck: true);
        for (final mark in npcMarks) {
          _activeNpcMarks.putIfAbsent(mark.npcId, () => mark);
        }
      }
    }

    _activeEnsembleSpecs = ensembleOut;
    _syncEnsembleComponents(world, ensembleOut);
  }

  Offset? _resolveSoloFocusPos({
    required StageShowFrame show,
    required List<NpcStageMark> npcMarks,
    required List<BandEnsembleMemberSpec> bandMembers,
  }) {
    if (show.sectionMode == LightShowSectionMode.rhythmBreak) {
      for (final b in bandMembers) {
        if (b.instrument.isPercussion) return b.stagePos;
      }
    }

    for (final m in npcMarks) {
      if (m.isLeadPerformer) {
        final choreo = sampleChoreographyForPerformer(
          show: show,
          instrument: m.instrument,
          isLeadPerformer: true,
          rolePhaseIndex: 0,
        );
        return Offset(m.stagePos.dx, m.stagePos.dy + choreo.forwardStepY);
      }
    }
    for (final b in bandMembers) {
      if (b.isLeadPerformer) {
        final choreo = sampleChoreographyForPerformer(
          show: show,
          instrument: b.instrument,
          isLeadPerformer: true,
          rolePhaseIndex: b.id.hashCode.abs() % 7,
        );
        return Offset(b.stagePos.dx, b.stagePos.dy + choreo.forwardStepY);
      }
    }
    if (npcMarks.isNotEmpty) return npcMarks.first.stagePos;
    if (bandMembers.isNotEmpty) return bandMembers.first.stagePos;
    return null;
  }

  void _syncEnsembleComponents(
    World world,
    List<BandEnsembleMemberSpec> desired,
  ) {
    final desiredIds = <String>{for (final s in desired) s.id};
    final toRemove = _spawnedBandComponents.keys
        .where((id) => !desiredIds.contains(id))
        .toList(growable: false);
    for (final id in toRemove) {
      final comp = _spawnedBandComponents.remove(id);
      comp?.removeFromParent();
    }

    for (final spec in desired) {
      final existing = _spawnedBandComponents[spec.id];
      if (existing != null) {
        final nextSheet = characterSheets[spec.sheetKey];
        existing.updateSpec(spec, nextSheet: nextSheet);
      } else {
        final sheet =
            characterSheets[spec.sheetKey] ?? characterSheets.values.first;
        final comp = StageBandMemberComponent(
          spec: spec,
          spriteSheet: sheet,
          metricsGetter: metricsGetter,
          bassGetter: bassGetter,
          timeGetter: timeGetter,
          stageShowGetter: (stageId) => _liveStages[stageId]?.show,
        );
        _spawnedBandComponents[spec.id] = comp;
        world.add(comp);
      }
    }
  }

  static (Color, Color) _stageColorsForTrack(ScheduledTrack track) {
    switch (track.trackNumber) {
      case 1: // Nutcracker Joe & The Hull Band
        return (const Color(0xFFFFB703), const Color(0xFF4CC9F0));
      case 3: // Richie Shellens
        return (const Color(0xFFFF9F1C), const Color(0xFFE76F51));
      case 4: // The Walnut Blues Band
        return (const Color(0xFF4EA8DE), const Color(0xFFFFB703));
      case 5: // Melanie Sapka
        return (const Color(0xFFFFE599), const Color(0xFF80ED99));
      case 6: // Arlo Nutthrie
        return (const Color(0xFFF4A261), const Color(0xFF74C69D));
      case 8: // Nutana
        return (const Color(0xFFFF6B35), const Color(0xFFFFD166));
      case 9: // Canned Walnut
        return (const Color(0xFFFFBE0B), const Color(0xFF90BE6D));
      case 10: // Mountain Grove
        return (const Color(0xFFFFD166), const Color(0xFF06D6A0));
      case 12: // Janice Joeplant
        return (const Color(0xFFFF70A6), const Color(0xFFFFB703));
      case 13: // Crosby, Stills, Nash & Walnut
        return (const Color(0xFF80ED99), const Color(0xFFFFD166));
      case 14: // Creedence Clearwater Harvest
      case 15:
        return (const Color(0xFF48CAE4), const Color(0xFFFFD166));
      case 16: // The Hull (Main Roots)
        return (const Color(0xFF00F5D4), const Color(0xFFFF006E));
      case 17: // The Hull (Sorting Arcade)
        return (const Color(0xFF00F5D4), const Color(0xFFFFBE0B));
      case 19: // The Walnuts & The Shells (Meadow)
      case 20: // The Walnuts & The Shells (Arcade)
        return (const Color(0xFFFFAFCC), const Color(0xFFFFD166));
      case 21: // Country Joe & The Nut
        return (const Color(0xFFFFD166), const Color(0xFFFF595E));
      case 22: // Jefferson Orchard
        return (const Color(0xFFC77DFF), const Color(0xFF00F5D4));
      case 23: // The Grateful Nut
        return (const Color(0xFFFF4D6D), const Color(0xFF4CC9F0));
      case 25: // Jimi Hendshell
      case 26:
        return (const Color(0xFFC77DFF), const Color(0xFFFF9E00));
    }
    switch (track.stageId) {
      case 'main_roots_stage':
        return (const Color(0xFFFFD166), const Color(0xFF52B788));
      case 'velvet_canopy_stage':
        return (const Color(0xFFFF70A6), const Color(0xFFFFB703));
      case 'mellow_meadow_stage':
        return (const Color(0xFFFFE599), const Color(0xFF80ED99));
      case 'andromeda_pavilion_stage':
        return (const Color(0xFF72EFDD), const Color(0xFFC77DFF));
      case 'urbano_canopy_stage':
        return (const Color(0xFFFFD166), const Color(0xFFE63946));
      case 'sorting_arcade_stage':
        return (const Color(0xFF00F5D4), const Color(0xFFFFBE0B));
      case 'pa_global_horn':
      default:
        return (const Color(0xFFFFD166), const Color(0xFFF4A261));
    }
  }

  /// Returns the exact headliner NPC marks + bespoke band musicians for a scheduled track.
  static (List<NpcStageMark>, List<BandEnsembleMemberSpec>) rosterForTrack(
    ScheduledTrack track, {
    required bool isSoundcheck,
  }) {
    final (primaryCol, secondaryCol) = _stageColorsForTrack(track);
    final n = track.trackNumber;
    final st = track.stageId;

    // PA Announcements (Tracks 2, 7, 11, 18, 24: "The Festival MC") -> Patchouli Pete at High-Branch PA Mic
    if (track.isPaBroadcast || st == 'pa_global_horn') {
      return (
        [
          NpcStageMark(
            npcId: 'patchouli_pete',
            stageId: st,
            trackNumber: n,
            stagePos: const Offset(776.0, 344.0),
            instrument: PerformerInstrument.paBroadcastMic,
            spotlightColor: primaryCol,
            isSoundcheck: isSoundcheck,
          ),
        ],
        const [],
      );
    }

    // Track 0: Barnaby Breeze-Walker 5AM Willow Lute Prelude (Mellow Meadow)
    if (n == 0) {
      return (
        [
          NpcStageMark(
            npcId: 'barnaby_breezewalker',
            stageId: st,
            trackNumber: n,
            stagePos: const Offset(1132.0, 434.0),
            instrument: PerformerInstrument.acousticLute,
            spotlightColor: primaryCol,
            isSoundcheck: isSoundcheck,
          ),
        ],
        const [],
      );
    }

    // Track 1: Nutcracker Joe & The Hull Band — "With a Little Help from My Shell (Live)"
    if (n == 1) {
      return (
        const [],
        [
          BandEnsembleMemberSpec(
            id: 'nutcracker_joe_lead',
            stageId: st,
            sheetKey: 'perf_nutcracker_joe',
            stagePos: const Offset(608.0, 380.0),
            instrument: PerformerInstrument.leadVocalMic,
            accentColor: primaryCol,
            isLeadPerformer: true,
          ),
          BandEnsembleMemberSpec(
            id: 'hullband_guitar',
            stageId: st,
            sheetKey: 'perf_hullband_guitar',
            stagePos: const Offset(562.0, 368.0),
            instrument: PerformerInstrument.electricGuitar,
            accentColor: secondaryCol,
            instrumentBodyColor: const Color(0xFFE07A5F),
            instrumentPickguardColor: const Color(0xFFFFF8E7),
          ),
          BandEnsembleMemberSpec(
            id: 'hullband_bass',
            stageId: st,
            sheetKey: 'perf_hullband_bass',
            stagePos: const Offset(654.0, 368.0),
            instrument: PerformerInstrument.bassGuitar,
            accentColor: primaryCol,
            instrumentBodyColor: const Color(0xFF582F0E),
            instrumentPickguardColor: const Color(0xFFFFD166),
          ),
          BandEnsembleMemberSpec(
            id: 'hullband_drums',
            stageId: st,
            sheetKey: 'perf_hullband_drums',
            stagePos: const Offset(608.0, 352.0),
            instrument: PerformerInstrument.drumKit,
            accentColor: secondaryCol,
          ),
        ],
      );
    }

    // Track 3: Richie Shellens — "Crackin' Free (Live)" (Woodstock Opening Acoustic Trio!)
    if (n == 3) {
      return (
        const [],
        [
          BandEnsembleMemberSpec(
            id: 'richie_shellens_lead',
            stageId: st,
            sheetKey: 'perf_richie_shellens',
            stagePos: const Offset(608.0, 380.0),
            instrument: PerformerInstrument.acousticGuitar,
            accentColor: primaryCol,
            isLeadPerformer: true,
            instrumentBodyColor: const Color(0xFFD9822B),
            instrumentPickguardColor: const Color(0xFF2B180E),
          ),
          BandEnsembleMemberSpec(
            id: 'richie_guitar2',
            stageId: st,
            sheetKey: 'perf_richie_guitar2',
            stagePos: const Offset(564.0, 368.0),
            instrument: PerformerInstrument.acousticGuitar,
            accentColor: secondaryCol,
            instrumentBodyColor: const Color(0xFFBC6C25),
            instrumentPickguardColor: const Color(0xFF3D220D),
          ),
          BandEnsembleMemberSpec(
            id: 'richie_congas',
            stageId: st,
            sheetKey: 'perf_richie_congas',
            stagePos: const Offset(652.0, 368.0),
            instrument: PerformerInstrument.congasTimbales,
            accentColor: primaryCol,
          ),
        ],
      );
    }

    // Track 4: The Walnut Blues Band — "Getting Harder (Live)"
    if (n == 4) {
      return (
        const [],
        [
          BandEnsembleMemberSpec(
            id: 'walnut_blues_lead',
            stageId: st,
            sheetKey: 'perf_blues_frontman',
            stagePos: const Offset(608.0, 380.0),
            instrument: PerformerInstrument.electricGuitar,
            accentColor: primaryCol,
            isLeadPerformer: true,
            instrumentBodyColor: const Color(0xFF9E2A2B),
            instrumentPickguardColor: const Color(0xFF141418),
          ),
          BandEnsembleMemberSpec(
            id: 'walnut_blues_bass',
            stageId: st,
            sheetKey: 'perf_blues_bass',
            stagePos: const Offset(562.0, 368.0),
            instrument: PerformerInstrument.bassGuitar,
            accentColor: secondaryCol,
            instrumentBodyColor: const Color(0xFF7F4F24),
            instrumentPickguardColor: const Color(0xFFF4E285),
          ),
          BandEnsembleMemberSpec(
            id: 'walnut_blues_organ',
            stageId: st,
            sheetKey: 'perf_blues_organ',
            stagePos: const Offset(654.0, 368.0),
            instrument: PerformerInstrument.hammondOrgan,
            accentColor: primaryCol,
          ),
          BandEnsembleMemberSpec(
            id: 'walnut_blues_drums',
            stageId: st,
            sheetKey: 'perf_blues_drums',
            stagePos: const Offset(608.0, 352.0),
            instrument: PerformerInstrument.drumKit,
            accentColor: secondaryCol,
          ),
        ],
      );
    }

    // Track 5: Melanie Sapka — "Brand New Key (And I Found It Under a Walnut Tree) [Live]"
    if (n == 5) {
      return (
        [
          NpcStageMark(
            npcId: 'joan_baezelnut',
            stageId: st,
            trackNumber: n,
            stagePos: const Offset(1182.0, 433.0),
            instrument: PerformerInstrument.tambourineVocals,
            spotlightColor: secondaryCol,
            isLeadPerformer: false,
            isSoundcheck: isSoundcheck,
          ),
          NpcStageMark(
            npcId: 'barnaby_breezewalker',
            stageId: st,
            trackNumber: n,
            stagePos: const Offset(1126.0, 434.0),
            instrument: PerformerInstrument.acousticLute,
            spotlightColor: secondaryCol,
            isLeadPerformer: false,
            isSoundcheck: isSoundcheck,
          ),
        ],
        [
          BandEnsembleMemberSpec(
            id: 'melanie_sapka_lead',
            stageId: st,
            sheetKey: 'perf_melanie_sapka',
            stagePos: const Offset(1154.0, 430.0),
            instrument: PerformerInstrument.acousticGuitar,
            accentColor: primaryCol,
            isLeadPerformer: true,
            instrumentBodyColor: const Color(0xFFB5651D),
            instrumentPickguardColor: const Color(0xFFFFF3B0),
          ),
          BandEnsembleMemberSpec(
            id: 'melanie_meadow_bass',
            stageId: st,
            sheetKey: 'perf_meadow_bass',
            stagePos: const Offset(1108.0, 432.0),
            instrument: PerformerInstrument.bassGuitar,
            accentColor: secondaryCol,
          ),
        ],
      );
    }

    // Track 6: Arlo Nutthrie — "Open Shells, Open Hearts (Live)"
    if (n == 6) {
      return (
        const [],
        [
          BandEnsembleMemberSpec(
            id: 'arlo_nutthrie_lead',
            stageId: st,
            sheetKey: 'perf_arlo_nutthrie',
            stagePos: const Offset(608.0, 380.0),
            instrument: PerformerInstrument.acousticGuitar,
            accentColor: primaryCol,
            isLeadPerformer: true,
            instrumentBodyColor: const Color(0xFFF4E285),
            instrumentPickguardColor: const Color(0xFF582F0E),
          ),
          BandEnsembleMemberSpec(
            id: 'arlo_dobro',
            stageId: st,
            sheetKey: 'perf_arlo_dobro',
            stagePos: const Offset(564.0, 368.0),
            instrument: PerformerInstrument.acousticGuitar,
            accentColor: secondaryCol,
            instrumentBodyColor: const Color(0xFFADB5BD),
            instrumentPickguardColor: const Color(0xFF343A40),
          ),
          BandEnsembleMemberSpec(
            id: 'arlo_bass',
            stageId: st,
            sheetKey: 'perf_arlo_bass',
            stagePos: const Offset(652.0, 368.0),
            instrument: PerformerInstrument.bassGuitar,
            accentColor: primaryCol,
            instrumentBodyColor: const Color(0xFF6C462A),
            instrumentPickguardColor: const Color(0xFFFDF0D5),
          ),
          BandEnsembleMemberSpec(
            id: 'arlo_drums',
            stageId: st,
            sheetKey: 'perf_arlo_drums',
            stagePos: const Offset(608.0, 352.0),
            instrument: PerformerInstrument.drumKit,
            accentColor: secondaryCol,
          ),
        ],
      );
    }

    // Track 8: Nutana — "Walnut Smooth (Live)" (Velvet Canopy Stage Latin Psych!)
    if (n == 8) {
      return (
        const [],
        [
          BandEnsembleMemberSpec(
            id: 'santana_lead',
            stageId: st,
            sheetKey: 'perf_carlos_santana',
            stagePos: const Offset(216.0, 368.0),
            instrument: PerformerInstrument.electricGuitar,
            accentColor: primaryCol,
            isLeadPerformer: true,
            // Carlos's iconic 1969 Woodstock Cherry-Red SG Special + black pickguard!
            instrumentBodyColor: const Color(0xFFB5172C),
            instrumentPickguardColor: const Color(0xFF1B1B22),
          ),
          BandEnsembleMemberSpec(
            id: 'santana_congas',
            stageId: st,
            sheetKey: 'perf_santana_congas',
            stagePos: const Offset(180.0, 356.0),
            instrument: PerformerInstrument.congasTimbales,
            accentColor: secondaryCol,
          ),
          BandEnsembleMemberSpec(
            id: 'santana_drums',
            stageId: st,
            sheetKey: 'perf_santana_drums',
            stagePos: const Offset(216.0, 344.0),
            instrument: PerformerInstrument.drumKit,
            accentColor: primaryCol,
          ),
          BandEnsembleMemberSpec(
            id: 'santana_organ',
            stageId: st,
            sheetKey: 'perf_santana_organ',
            stagePos: const Offset(252.0, 354.0),
            instrument: PerformerInstrument.hammondOrgan,
            accentColor: secondaryCol,
          ),
        ],
      );
    }

    // Track 9: Canned Walnut — "Kernel of Truth (Live)"
    if (n == 9) {
      return (
        const [],
        [
          BandEnsembleMemberSpec(
            id: 'canned_bear_lead',
            stageId: st,
            sheetKey: 'perf_canned_bear',
            stagePos: const Offset(608.0, 380.0),
            instrument: PerformerInstrument.tambourineVocals,
            accentColor: primaryCol,
            isLeadPerformer: true,
          ),
          BandEnsembleMemberSpec(
            id: 'canned_blindowl_guitar',
            stageId: st,
            sheetKey: 'perf_canned_blindowl',
            stagePos: const Offset(562.0, 368.0),
            instrument: PerformerInstrument.electricGuitar,
            accentColor: secondaryCol,
            instrumentBodyColor: const Color(0xFFE9C46A),
            instrumentPickguardColor: const Color(0xFFFFF8E7),
          ),
          BandEnsembleMemberSpec(
            id: 'canned_bass',
            stageId: st,
            sheetKey: 'perf_canned_bass',
            stagePos: const Offset(654.0, 368.0),
            instrument: PerformerInstrument.bassGuitar,
            accentColor: primaryCol,
            instrumentBodyColor: const Color(0xFFF8F9FA),
            instrumentPickguardColor: const Color(0xFF9B2226),
          ),
          BandEnsembleMemberSpec(
            id: 'canned_drums',
            stageId: st,
            sheetKey: 'perf_canned_drums',
            stagePos: const Offset(608.0, 352.0),
            instrument: PerformerInstrument.drumKit,
            accentColor: secondaryCol,
          ),
        ],
      );
    }

    // Track 10: Mountain Grove — "I Think of Walnuts (Live)" (Friday Headliner Anthem + Literally Infinite cameo!)
    if (n == 10) {
      return (
        [
          NpcStageMark(
            npcId: 'literally_infinite',
            stageId: st,
            trackNumber: n,
            stagePos: const Offset(656.0, 368.0),
            instrument: PerformerInstrument.hammondOrgan,
            spotlightColor: secondaryCol,
            isLeadPerformer: false,
            isSoundcheck: isSoundcheck,
          ),
        ],
        [
          BandEnsembleMemberSpec(
            id: 'mountain_leslie_lead',
            stageId: st,
            sheetKey: 'perf_mountain_leslie',
            stagePos: const Offset(608.0, 380.0),
            instrument: PerformerInstrument.electricGuitar,
            accentColor: primaryCol,
            isLeadPerformer: true,
            instrumentBodyColor: const Color(0xFFD97706),
            instrumentPickguardColor: const Color(0xFF1C1917),
          ),
          BandEnsembleMemberSpec(
            id: 'mountain_felix_bass',
            stageId: st,
            sheetKey: 'perf_mountain_felix',
            stagePos: const Offset(560.0, 368.0),
            instrument: PerformerInstrument.bassGuitar,
            accentColor: secondaryCol,
            instrumentBodyColor: const Color(0xFFF8F9FA),
            instrumentPickguardColor: const Color(0xFF1B1B22),
          ),
          BandEnsembleMemberSpec(
            id: 'mountain_drums',
            stageId: st,
            sheetKey: 'perf_mountain_drums',
            stagePos: const Offset(608.0, 352.0),
            instrument: PerformerInstrument.drumKit,
            accentColor: primaryCol,
          ),
        ],
      );
    }

    // Track 12: Janice Joeplant — "Piece of My Walnut (Live)" (Velvet Canopy Stage)
    if (n == 12) {
      return (
        [
          NpcStageMark(
            npcId: 'janice_joeplant',
            stageId: st,
            trackNumber: n,
            stagePos: const Offset(216.0, 368.0),
            instrument: PerformerInstrument.leadVocalMic,
            spotlightColor: primaryCol,
            isLeadPerformer: true,
            isSoundcheck: isSoundcheck,
          ),
        ],
        [
          BandEnsembleMemberSpec(
            id: 'janice_guitar',
            stageId: st,
            sheetKey: 'perf_kozmic_guitar',
            stagePos: const Offset(180.0, 356.0),
            instrument: PerformerInstrument.electricGuitar,
            accentColor: primaryCol,
            // Butterscotch Blonde Telecaster!
            instrumentBodyColor: const Color(0xFFF4A261),
            instrumentPickguardColor: const Color(0xFF212529),
          ),
          BandEnsembleMemberSpec(
            id: 'janice_drums',
            stageId: st,
            sheetKey: 'perf_kozmic_drums',
            stagePos: const Offset(216.0, 344.0),
            instrument: PerformerInstrument.drumKit,
            accentColor: secondaryCol,
          ),
          BandEnsembleMemberSpec(
            id: 'janice_organ',
            stageId: st,
            sheetKey: 'perf_kozmic_organ',
            stagePos: const Offset(252.0, 354.0),
            instrument: PerformerInstrument.hammondOrgan,
            accentColor: secondaryCol,
          ),
        ],
      );
    }

    // Track 13: Crosby, Stills, Nash & Walnut — "Our Shell (Live)" (4-Frontman Harmony Line!)
    if (n == 13) {
      return (
        const [],
        [
          BandEnsembleMemberSpec(
            id: 'csny_stills_lead',
            stageId: st,
            sheetKey: 'perf_csny_stills',
            stagePos: const Offset(590.0, 380.0),
            instrument: PerformerInstrument.acousticGuitar,
            accentColor: primaryCol,
            isLeadPerformer: true,
            instrumentBodyColor: const Color(0xFFDDA15E),
            instrumentPickguardColor: const Color(0xFF4A2C18),
          ),
          BandEnsembleMemberSpec(
            id: 'csny_crosby',
            stageId: st,
            sheetKey: 'perf_csny_crosby',
            stagePos: const Offset(552.0, 372.0),
            instrument: PerformerInstrument.acousticGuitar,
            accentColor: secondaryCol,
            instrumentBodyColor: const Color(0xFFBC6C25),
            instrumentPickguardColor: const Color(0xFF3D220D),
          ),
          BandEnsembleMemberSpec(
            id: 'csny_nash',
            stageId: st,
            sheetKey: 'perf_csny_nash',
            stagePos: const Offset(626.0, 380.0),
            instrument: PerformerInstrument.tambourineVocals,
            accentColor: primaryCol,
          ),
          BandEnsembleMemberSpec(
            id: 'csny_walnut',
            stageId: st,
            sheetKey: 'perf_csny_walnut',
            stagePos: const Offset(664.0, 372.0),
            instrument: PerformerInstrument.electricGuitar,
            accentColor: secondaryCol,
            // Neil's legendary "Old Black" Les Paul!
            instrumentBodyColor: const Color(0xFF212529),
            instrumentPickguardColor: const Color(0xFFCED4DA),
          ),
        ],
      );
    }

    // Tracks 14 & 15: Creedence Clearwater Harvest on Main Roots Stage (playing straight through Saturday's Rainstorm!)
    if (n == 14 || n == 15) {
      return (
        const [],
        [
          BandEnsembleMemberSpec(
            id: 'ccr_fogerty_lead',
            stageId: st,
            sheetKey: 'perf_john_fogerty',
            stagePos: const Offset(608.0, 380.0),
            instrument: PerformerInstrument.electricGuitar,
            accentColor: primaryCol,
            isLeadPerformer: true,
            // John Fogerty's Woodstock Rickenbacker 325 Fireglo + white pickguard!
            instrumentBodyColor: const Color(0xFFC1121F),
            instrumentPickguardColor: const Color(0xFFF8F9FA),
          ),
          BandEnsembleMemberSpec(
            id: 'ccr_rhythm_guitar',
            stageId: st,
            sheetKey: 'perf_tom_fogerty',
            stagePos: const Offset(562.0, 368.0),
            instrument: PerformerInstrument.acousticGuitar,
            accentColor: secondaryCol,
            instrumentBodyColor: const Color(0xFFBC6C25),
            instrumentPickguardColor: const Color(0xFFFFF3B0),
          ),
          BandEnsembleMemberSpec(
            id: 'ccr_bass',
            stageId: st,
            sheetKey: 'perf_stu_cook',
            stagePos: const Offset(654.0, 368.0),
            instrument: PerformerInstrument.bassGuitar,
            accentColor: primaryCol,
            instrumentBodyColor: const Color(0xFFFDF0D5),
            instrumentPickguardColor: const Color(0xFF780000),
          ),
          BandEnsembleMemberSpec(
            id: 'ccr_drums',
            stageId: st,
            sheetKey: 'perf_doug_clifford',
            stagePos: const Offset(608.0, 352.0),
            instrument: PerformerInstrument.drumKit,
            accentColor: secondaryCol,
          ),
        ],
      );
    }

    // Track 16: The Hull — "Talkin' 'Bout My Dehiscence (Live)" on Main Roots Stage
    if (n == 16) {
      return (
        const [],
        [
          BandEnsembleMemberSpec(
            id: 'hull_daltrey_lead',
            stageId: st,
            sheetKey: 'perf_hull_daltrey',
            stagePos: const Offset(608.0, 380.0),
            instrument: PerformerInstrument.leadVocalMic,
            accentColor: primaryCol,
            isLeadPerformer: true,
          ),
          BandEnsembleMemberSpec(
            id: 'hull_townshend_guitar',
            stageId: st,
            sheetKey: 'perf_hull_townshend',
            stagePos: const Offset(654.0, 370.0),
            instrument: PerformerInstrument.electricGuitar,
            accentColor: secondaryCol,
            instrumentBodyColor: const Color(0xFFC1121F),
            instrumentPickguardColor: const Color(0xFF111116),
          ),
          BandEnsembleMemberSpec(
            id: 'hull_entwistle_bass',
            stageId: st,
            sheetKey: 'perf_hull_entwistle',
            stagePos: const Offset(562.0, 368.0),
            instrument: PerformerInstrument.bassGuitar,
            accentColor: primaryCol,
            instrumentBodyColor: const Color(0xFFF4A261),
            instrumentPickguardColor: const Color(0xFF1B1B22),
          ),
          BandEnsembleMemberSpec(
            id: 'hull_moon_drums',
            stageId: st,
            sheetKey: 'perf_hull_moon',
            stagePos: const Offset(608.0, 352.0),
            instrument: PerformerInstrument.drumKit,
            accentColor: secondaryCol,
          ),
        ],
      );
    }

    // Track 17: The Hull — "Pinball Wizard (at the Sorting Machine) [Live]" at Sorting Arcade Stage
    if (n == 17) {
      return (
        [
          NpcStageMark(
            npcId: 'arcade_attendant',
            stageId: st,
            trackNumber: n,
            stagePos: const Offset(1726.0, 1008.0),
            instrument: PerformerInstrument.turntablesDj,
            spotlightColor: secondaryCol,
            isLeadPerformer: false,
            isSoundcheck: isSoundcheck,
          ),
        ],
        [
          BandEnsembleMemberSpec(
            id: 'hull_arcade_daltrey',
            stageId: st,
            sheetKey: 'perf_hull_daltrey',
            stagePos: const Offset(1744.0, 1002.0),
            instrument: PerformerInstrument.leadVocalMic,
            accentColor: primaryCol,
            isLeadPerformer: true,
          ),
          BandEnsembleMemberSpec(
            id: 'hull_arcade_townshend',
            stageId: st,
            sheetKey: 'perf_hull_townshend',
            stagePos: const Offset(1760.0, 990.0),
            instrument: PerformerInstrument.electricGuitar,
            accentColor: secondaryCol,
            instrumentBodyColor: const Color(0xFFC1121F),
            instrumentPickguardColor: const Color(0xFF111116),
          ),
        ],
      );
    }

    // Track 19: The Walnuts & The Shells — "California Dreamin'" on Willow Creek & Meadow Stage
    if (n == 19) {
      return (
        const [],
        [
          BandEnsembleMemberSpec(
            id: 'walnuts_shells_meadow_lead',
            stageId: st,
            sheetKey: 'perf_mama_cass',
            stagePos: const Offset(1140.0, 430.0),
            instrument: PerformerInstrument.tambourineVocals,
            accentColor: primaryCol,
            isLeadPerformer: true,
          ),
          BandEnsembleMemberSpec(
            id: 'walnuts_shells_meadow_michelle',
            stageId: st,
            sheetKey: 'perf_michelle_husk',
            stagePos: const Offset(1162.0, 430.0),
            instrument: PerformerInstrument.leadVocalMic,
            accentColor: secondaryCol,
          ),
          BandEnsembleMemberSpec(
            id: 'walnuts_shells_meadow_denny',
            stageId: st,
            sheetKey: 'perf_denny_husk',
            stagePos: const Offset(1118.0, 434.0),
            instrument: PerformerInstrument.acousticGuitar,
            accentColor: secondaryCol,
            instrumentBodyColor: const Color(0xFFD4A373),
          ),
          BandEnsembleMemberSpec(
            id: 'walnuts_shells_meadow_john',
            stageId: st,
            sheetKey: 'perf_john_husk',
            stagePos: const Offset(1182.0, 434.0),
            instrument: PerformerInstrument.acousticGuitar,
            accentColor: primaryCol,
            instrumentBodyColor: const Color(0xFF9C6644),
          ),
        ],
      );
    }

    // Track 20: The Walnuts & The Shells — "Monday, Monday" at Sorting Machine Arcade Stage
    if (n == 20) {
      return (
        [
          NpcStageMark(
            npcId: 'arcade_attendant',
            stageId: st,
            trackNumber: n,
            stagePos: const Offset(1726.0, 1008.0),
            instrument: PerformerInstrument.turntablesDj,
            spotlightColor: secondaryCol,
            isLeadPerformer: false,
            isSoundcheck: isSoundcheck,
          ),
        ],
        [
          BandEnsembleMemberSpec(
            id: 'mamas_arcade_lead',
            stageId: st,
            sheetKey: 'perf_mama_cass',
            stagePos: const Offset(1746.0, 1002.0),
            instrument: PerformerInstrument.leadVocalMic,
            accentColor: primaryCol,
            isLeadPerformer: true,
          ),
          BandEnsembleMemberSpec(
            id: 'mamas_arcade_harm',
            stageId: st,
            sheetKey: 'perf_michelle_husk',
            stagePos: const Offset(1734.0, 990.0),
            instrument: PerformerInstrument.tambourineVocals,
            accentColor: secondaryCol,
          ),
          BandEnsembleMemberSpec(
            id: 'mamas_arcade_gtr',
            stageId: st,
            sheetKey: 'perf_john_husk',
            stagePos: const Offset(1760.0, 990.0),
            instrument: PerformerInstrument.acousticGuitar,
            accentColor: primaryCol,
          ),
        ],
      );
    }

    // Track 21: Country Joe & The Nut — "Walnut Cruncherman (Live)"
    if (n == 21) {
      return (
        const [],
        [
          BandEnsembleMemberSpec(
            id: 'country_joe_lead',
            stageId: st,
            sheetKey: 'perf_country_joe',
            stagePos: const Offset(608.0, 380.0),
            instrument: PerformerInstrument.acousticGuitar,
            accentColor: primaryCol,
            isLeadPerformer: true,
            instrumentBodyColor: const Color(0xFFD4A373),
            instrumentPickguardColor: const Color(0xFF780000),
          ),
          BandEnsembleMemberSpec(
            id: 'fish_barry_guitar',
            stageId: st,
            sheetKey: 'perf_fish_barry',
            stagePos: const Offset(654.0, 368.0),
            instrument: PerformerInstrument.electricGuitar,
            accentColor: secondaryCol,
            instrumentBodyColor: const Color(0xFFE9C46A),
            instrumentPickguardColor: const Color(0xFF1D1E2C),
          ),
          BandEnsembleMemberSpec(
            id: 'fish_organ',
            stageId: st,
            sheetKey: 'perf_fish_organ',
            stagePos: const Offset(562.0, 368.0),
            instrument: PerformerInstrument.hammondOrgan,
            accentColor: primaryCol,
          ),
          BandEnsembleMemberSpec(
            id: 'fish_drums',
            stageId: st,
            sheetKey: 'perf_fish_drums',
            stagePos: const Offset(608.0, 352.0),
            instrument: PerformerInstrument.drumKit,
            accentColor: secondaryCol,
          ),
        ],
      );
    }

    // Track 22: Jefferson Orchard — "The Walnut Trip (Live)"
    if (n == 22) {
      return (
        const [],
        [
          BandEnsembleMemberSpec(
            id: 'jefferson_grace_lead',
            stageId: st,
            sheetKey: 'perf_jefferson_grace',
            stagePos: const Offset(608.0, 380.0),
            instrument: PerformerInstrument.tambourineVocals,
            accentColor: primaryCol,
            isLeadPerformer: true,
          ),
          BandEnsembleMemberSpec(
            id: 'jefferson_marty_vocals',
            stageId: st,
            sheetKey: 'perf_jefferson_marty',
            stagePos: const Offset(576.0, 376.0),
            instrument: PerformerInstrument.leadVocalMic,
            accentColor: secondaryCol,
          ),
          BandEnsembleMemberSpec(
            id: 'jefferson_jorma_guitar',
            stageId: st,
            sheetKey: 'perf_jefferson_jorma',
            stagePos: const Offset(654.0, 368.0),
            instrument: PerformerInstrument.electricGuitar,
            accentColor: primaryCol,
            instrumentBodyColor: const Color(0xFFE76F51),
            instrumentPickguardColor: const Color(0xFF1B1B22),
          ),
          BandEnsembleMemberSpec(
            id: 'jefferson_jack_bass',
            stageId: st,
            sheetKey: 'perf_jefferson_jack',
            stagePos: const Offset(546.0, 366.0),
            instrument: PerformerInstrument.crystalBass,
            accentColor: secondaryCol,
            instrumentBodyColor: const Color(0xFFFFBE0B),
            instrumentPickguardColor: const Color(0xFF3C096C),
          ),
          BandEnsembleMemberSpec(
            id: 'jefferson_drums',
            stageId: st,
            sheetKey: 'perf_jefferson_drums',
            stagePos: const Offset(608.0, 352.0),
            instrument: PerformerInstrument.drumKit,
            accentColor: primaryCol,
          ),
        ],
      );
    }

    // Track 23: The Grateful Nut — "Help I'm a Walnut (Live)" at Velvet Canopy Stage
    if (n == 23) {
      return (
        const [],
        [
          BandEnsembleMemberSpec(
            id: 'grateful_jerry_lead',
            stageId: st,
            sheetKey: 'perf_grateful_jerry',
            stagePos: const Offset(216.0, 368.0),
            instrument: PerformerInstrument.electricGuitar,
            accentColor: primaryCol,
            isLeadPerformer: true,
            instrumentBodyColor: const Color(0xFFB5172C),
            instrumentPickguardColor: const Color(0xFF141418),
          ),
          BandEnsembleMemberSpec(
            id: 'grateful_bob_guitar',
            stageId: st,
            sheetKey: 'perf_grateful_bob',
            stagePos: const Offset(178.0, 360.0),
            instrument: PerformerInstrument.electricGuitar,
            accentColor: secondaryCol,
            instrumentBodyColor: const Color(0xFFD62828),
            instrumentPickguardColor: const Color(0xFFF8F9FA),
          ),
          BandEnsembleMemberSpec(
            id: 'grateful_phil_bass',
            stageId: st,
            sheetKey: 'perf_grateful_phil',
            stagePos: const Offset(252.0, 360.0),
            instrument: PerformerInstrument.bassGuitar,
            accentColor: primaryCol,
            instrumentBodyColor: const Color(0xFF9C6644),
            instrumentPickguardColor: const Color(0xFFFFD166),
          ),
          BandEnsembleMemberSpec(
            id: 'grateful_pigpen_organ',
            stageId: st,
            sheetKey: 'perf_grateful_pigpen',
            stagePos: const Offset(250.0, 345.0),
            instrument: PerformerInstrument.hammondOrgan,
            accentColor: secondaryCol,
          ),
          BandEnsembleMemberSpec(
            id: 'grateful_drums',
            stageId: st,
            sheetKey: 'perf_grateful_drums',
            stagePos: const Offset(212.0, 344.0),
            instrument: PerformerInstrument.drumKit,
            accentColor: primaryCol,
          ),
        ],
      );
    }

    // Tracks 25 & 26: Jimi Hendshell + Gypsy Sun & Rainbows Experience Trio on Main Roots Stage!
    if (n == 25 || n == 26) {
      return (
        [
          NpcStageMark(
            npcId: 'jimi_hendshell',
            stageId: st,
            trackNumber: n,
            stagePos: const Offset(608.0, 380.0),
            instrument: PerformerInstrument.hendrixStrat,
            spotlightColor: primaryCol,
            isLeadPerformer: true,
            isSoundcheck: isSoundcheck,
          ),
        ],
        [
          BandEnsembleMemberSpec(
            id: 'hendshell_bass',
            stageId: st,
            sheetKey: 'perf_billy_cox',
            stagePos: const Offset(562.0, 368.0),
            instrument: PerformerInstrument.bassGuitar,
            accentColor: secondaryCol,
            instrumentBodyColor: const Color(0xFF9B2226),
            instrumentPickguardColor: const Color(0xFFF8F9FA),
          ),
          BandEnsembleMemberSpec(
            id: 'hendshell_drums',
            stageId: st,
            sheetKey: 'perf_mitch_mitchell',
            stagePos: const Offset(608.0, 352.0),
            instrument: PerformerInstrument.drumKit,
            accentColor: primaryCol,
          ),
        ],
      );
    }

    // Track 27: Don Shell-O Midnight Dem-Bow on Urbano Produce-Truck Stage!
    if (n == 27) {
      return (
        [
          NpcStageMark(
            npcId: 'don_shello',
            stageId: st,
            trackNumber: n,
            stagePos: const Offset(228.0, 1018.0),
            instrument: PerformerInstrument.leadVocalMic,
            spotlightColor: primaryCol,
            isLeadPerformer: true,
            isSoundcheck: isSoundcheck,
          ),
        ],
        [
          BandEnsembleMemberSpec(
            id: 'urbano_dj',
            stageId: st,
            sheetKey: 'perf_urbano_dj',
            stagePos: const Offset(194.0, 1011.0),
            instrument: PerformerInstrument.turntablesDj,
            accentColor: secondaryCol,
          ),
          BandEnsembleMemberSpec(
            id: 'urbano_perc',
            stageId: st,
            sheetKey: 'perf_urbano_perc',
            stagePos: const Offset(262.0, 1011.0),
            instrument: PerformerInstrument.congasTimbales,
            accentColor: primaryCol,
          ),
        ],
      );
    }

    // Tracks 28 & 29: Cosmo Shell-voy Midnight Astral Dome Sets!
    if (n == 28 || n == 29) {
      return (
        [
          NpcStageMark(
            npcId: 'cosmo_shellvoy',
            stageId: st,
            trackNumber: n,
            stagePos: const Offset(1760.0, 344.0),
            instrument: PerformerInstrument.crystalBass,
            spotlightColor: primaryCol,
            isLeadPerformer: true,
            isSoundcheck: isSoundcheck,
          ),
        ],
        [
          BandEnsembleMemberSpec(
            id: 'cosmo_synth',
            stageId: st,
            sheetKey: 'perf_cosmo_synth',
            stagePos: const Offset(1724.0, 332.0),
            instrument: PerformerInstrument.hammondOrgan,
            accentColor: secondaryCol,
          ),
          BandEnsembleMemberSpec(
            id: 'cosmo_perc',
            stageId: st,
            sheetKey: 'perf_cosmo_perc',
            stagePos: const Offset(1796.0, 332.0),
            instrument: PerformerInstrument.congasTimbales,
            accentColor: primaryCol,
          ),
        ],
      );
    }

    // Fallback for any custom future tracks: Literally Infinite + 3-piece live orchard band!
    return (
      [
        NpcStageMark(
          npcId: 'literally_infinite',
          stageId: st,
          trackNumber: n,
          stagePos: const Offset(608.0, 380.0),
          instrument: PerformerInstrument.electricGuitar,
          spotlightColor: primaryCol,
          isLeadPerformer: true,
          instrumentBodyColor: const Color(0xFFFFB703),
          instrumentPickguardColor: const Color(0xFF80FFDB),
          isSoundcheck: isSoundcheck,
        ),
      ],
      [
        BandEnsembleMemberSpec(
          id: 'li_main_drums',
          stageId: st,
          sheetKey: 'perf_li_drums',
          stagePos: const Offset(608.0, 352.0),
          instrument: PerformerInstrument.drumKit,
          accentColor: secondaryCol,
        ),
        BandEnsembleMemberSpec(
          id: 'li_main_bass',
          stageId: st,
          sheetKey: 'perf_li_bass',
          stagePos: const Offset(562.0, 368.0),
          instrument: PerformerInstrument.bassGuitar,
          accentColor: primaryCol,
          instrumentBodyColor: const Color(0xFF7F4F24),
          instrumentPickguardColor: const Color(0xFF4CC9F0),
        ),
        BandEnsembleMemberSpec(
          id: 'li_main_organ',
          stageId: st,
          sheetKey: 'perf_li_organ',
          stagePos: const Offset(654.0, 368.0),
          instrument: PerformerInstrument.hammondOrgan,
          accentColor: secondaryCol,
        ),
      ],
    );
  }
}

/// Renders an active 3D ensemble band musician on stage with directional shadows & music-synced choreography.
class StageBandMemberComponent extends PositionComponent {
  StageBandMemberComponent({
    required BandEnsembleMemberSpec spec,
    required Image spriteSheet,
    required this.metricsGetter,
    required this.bassGetter,
    required this.timeGetter,
    this.stageShowGetter,
  })  : _spec = spec,
        _spriteSheet = spriteSheet,
        super(
          position: Vector2(spec.stagePos.dx, spec.stagePos.dy),
          size: Vector2.all(32),
          anchor: Anchor.center,
          priority: spec.stagePos.dy.round(),
        );

  BandEnsembleMemberSpec _spec;
  Image _spriteSheet;
  final DayNightMetrics Function() metricsGetter;
  final double Function() bassGetter;
  final double Function() timeGetter;
  final StageShowFrame? Function(String stageId)? stageShowGetter;

  void updateSpec(BandEnsembleMemberSpec next, {Image? nextSheet}) {
    _spec = next;
    if (nextSheet != null) {
      _spriteSheet = nextSheet;
    }
    position.setValues(next.stagePos.dx, next.stagePos.dy);
    priority = next.stagePos.dy.round();
  }

  @override
  void render(Canvas canvas) {
    final t = timeGetter();
    final bass = bassGetter();
    final metrics = metricsGetter();
    final roleIdx = _spec.id.hashCode.abs() % 7;
    final show = stageShowGetter?.call(_spec.stageId);

    final PerformerChoreoSample choreo = show != null
        ? sampleChoreographyForPerformer(
            show: show,
            instrument: _spec.instrument,
            isLeadPerformer: _spec.isLeadPerformer,
            rolePhaseIndex: roleIdx,
          )
        : PerformerChoreoSample(
            bounceY:
                math.sin(t * 7.2 + roleIdx * 0.6).abs() * (1.4 + bass * 2.2),
            swayX: math.sin(t * 3.6 + roleIdx * 0.6) * 1.4,
            forwardStepY: 0.0,
            bodyTiltRad: 0.0,
            spriteFrameCol: ((t * 5.2 + roleIdx).floor().abs() % 3),
            strumPhase: t * 14.0 + roleIdx,
            poseMove: PerformerPoseMove.pocketGroove,
            haloIntensity: 0.28,
            sparkBurst: 0.0,
          );

    final swayX = choreo.swayX;
    final stepForwardY = choreo.forwardStepY;
    final grooveBounce = choreo.bounceY;

    // 1. Directional 3D ground shadow + beat-synced spotlight floor halo
    renderActor3dShadow(
      canvas: canvas,
      metrics: metrics,
      centerX: 16.0 + swayX * 0.45,
      footY: 28.5 + stepForwardY,
      spotlightColor: _spec.accentColor,
      haloIntensity: choreo.haloIntensity,
    );

    // 2. Animated bespoke 3D musician sprite (beat-locked frames & expressive body lean)
    final src =
        Rect.fromLTWH(choreo.spriteFrameCol * 32.0, 0.0, 32.0, 32.0);
    final dst =
        Rect.fromLTWH(swayX, stepForwardY - grooveBounce, 32.0, 32.0);

    canvas.save();
    if (choreo.bodyTiltRad.abs() > 0.005) {
      final pivotX = 16.0 + swayX;
      final pivotY = 22.0 + stepForwardY - grooveBounce;
      canvas.translate(pivotX, pivotY);
      canvas.rotate(choreo.bodyTiltRad);
      canvas.translate(-pivotX, -pivotY);
    }
    canvas.drawImageRect(
      _spriteSheet,
      src,
      dst,
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );
    canvas.restore();

    // 3. Detailed 3D stage instrument, custom colorway, drumsticks, solo sparks & notes!
    renderPerformerInstrumentProp(
      canvas: canvas,
      instrument: _spec.instrument,
      time: show?.trackTimeSec ?? (t + roleIdx * 0.4),
      bass: show?.bass ?? bass,
      offsetX: swayX,
      liftY: grooveBounce,
      stepForwardY: stepForwardY,
      accentColor: _spec.accentColor,
      instrumentBodyColor: _spec.instrumentBodyColor,
      instrumentPickguardColor: _spec.instrumentPickguardColor,
      choreo: choreo,
      emitNotes: (_spec.id.hashCode.abs() % 2) == 0 || _spec.isLeadPerformer,
    );
  }
}

/// Shared 3D directional sun/moon ground shadow + optional stage spotlight rim pool for actors.
void renderActor3dShadow({
  required Canvas canvas,
  required DayNightMetrics metrics,
  required double centerX,
  required double footY,
  Color? spotlightColor,
  double haloIntensity = 0.26,
}) {
  // Spotlight floor pool when performing on stage
  if (spotlightColor != null) {
    final w = 22.0 + haloIntensity * 12.0;
    final h = 8.5 + haloIntensity * 4.5;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, footY + 0.5),
        width: w,
        height: h,
      ),
      Paint()
        ..color = spotlightColor
            .withValues(alpha: (0.14 + haloIntensity * 0.28).clamp(0.14, 0.46))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  // Skewed solar/lunar 3D cast shadow
  final sx = metrics.shadowOffset.dx * 0.68;
  final sy = metrics.shadowOffset.dy * 0.55;
  final shadowW = 15.0 + metrics.shadowOffset.dx.abs() * 0.65;
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(centerX + sx, footY + sy),
      width: shadowW,
      height: 5.8,
    ),
    Paint()
      ..color = Color.fromRGBO(
        8,
        12,
        14,
        metrics.shadowAlpha.clamp(0.14, 0.42),
      ),
  );

  // Tight ambient-occlusion contact shadow directly under boots
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(centerX, footY + 0.6),
      width: 12.5,
      height: 4.2,
    ),
    Paint()..color = const Color(0x48070A0C),
  );
}

/// Renders 3D instruments, chrome microphone stands, drumsticks, solo sparks, vocal auras, and floating notes.
void renderPerformerInstrumentProp({
  required Canvas canvas,
  required PerformerInstrument instrument,
  required double time,
  required double bass,
  required double offsetX,
  required double liftY,
  required Color accentColor,
  double stepForwardY = 0.0,
  Color? instrumentBodyColor,
  Color? instrumentPickguardColor,
  PerformerChoreoSample? choreo,
  bool emitNotes = true,
}) {
  final isShred = choreo?.poseMove == PerformerPoseMove.soloShred;
  final isFlurry = choreo?.poseMove == PerformerPoseMove.percussionFlurry;
  final isVocalBelt = choreo?.poseMove == PerformerPoseMove.vocalBelt;
  final isPaSpeak = choreo?.poseMove == PerformerPoseMove.paSyllableSpeak;

  final strumPhase = choreo?.strumPhase ?? (time * 14.0);
  final strum = math.sin(strumPhase) * (isShred ? 2.1 : 1.3);
  final handLiftY = liftY - stepForwardY;
  final neckSkyLift = isShred ? 3.8 : 0.0;

  switch (instrument) {
    case PerformerInstrument.drumKit:
      // 3D Walnut Bass Drum + Snare + Shimmering Brass Crash Cymbals + Animated Drumsticks!
      final stickSpeed = isFlurry ? 26.0 : 16.0;
      final stickAmp = isFlurry ? 5.2 : 3.5;
      final stickL = math.sin(time * stickSpeed) * stickAmp;
      final stickR = math.cos(time * stickSpeed) * stickAmp;
      final stickPaint = Paint()
        ..color = const Color(0xFFF3D5B5)
        ..strokeWidth = 1.25;
      canvas.drawLine(
        Offset(11 + offsetX, 19 - handLiftY),
        Offset(13 + offsetX * 0.4, 23 + stickL * 0.45),
        stickPaint,
      );
      canvas.drawLine(
        Offset(21 + offsetX, 19 - handLiftY),
        Offset(19 + offsetX * 0.4, 23 + stickR * 0.45),
        stickPaint,
      );
      // Kick drum shell in front
      canvas.drawCircle(
        const Offset(16, 26.5),
        5.5 + bass * 0.9,
        Paint()..color = const Color(0xFF7F1D1D),
      );
      canvas.drawCircle(
        const Offset(16, 26.5),
        4.1 + bass * 0.7,
        Paint()..color = const Color(0xFFFDF0D5),
      );
      // Left & right brass crash cymbals
      final cymShimmer = math.sin(time * (isFlurry ? 28.0 : 18.0)) *
          (isFlurry ? 1.5 : 0.8);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(6.5, 20.0 + cymShimmer), width: 8.5, height: 2.6),
        Paint()..color = const Color(0xFFFFD166),
      );
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(25.5, 20.0 - cymShimmer), width: 8.5, height: 2.6),
        Paint()..color = const Color(0xFFFFB703),
      );
      if (isFlurry) {
        final ringPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = const Color(0xAAFFF3B0);
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(6.5, 20.0 + cymShimmer), width: 12.0, height: 4.5),
          ringPaint,
        );
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(25.5, 20.0 - cymShimmer),
              width: 12.0,
              height: 4.5),
          ringPaint,
        );
      }
      break;

    case PerformerInstrument.hendrixStrat:
      // Upside-down Left-Handed White Strat-Nut + Electric Purple Feedback Sparks!
      _drawGuitar3D(
        canvas,
        offsetX: offsetX,
        liftY: handLiftY,
        strum: strum,
        neckAngleLift: neckSkyLift,
        bodyColor: instrumentBodyColor ?? const Color(0xFFF8F9FA),
        pickguardColor: instrumentPickguardColor ?? const Color(0xFFE63946),
        leftHanded: true,
      );
      _drawChromeStandMic(canvas, x: 16.0);
      final sparkCount = isShred ? 5 : 3;
      for (var i = 0; i < sparkCount; i++) {
        final ang = time * (isShred ? 10.0 : 6.0) + i * 1.9;
        canvas.drawCircle(
          Offset(6.0 + offsetX + math.cos(ang) * (isShred ? 4.4 : 3.2),
              14.0 - handLiftY - neckSkyLift + math.sin(ang) * 3.4),
          isShred ? 1.5 : 1.15,
          Paint()..color = const Color(0xFFE0AAFF),
        );
      }
      break;

    case PerformerInstrument.electricGuitar:
      _drawGuitar3D(
        canvas,
        offsetX: offsetX,
        liftY: handLiftY,
        strum: strum,
        neckAngleLift: neckSkyLift,
        bodyColor: instrumentBodyColor ?? const Color(0xFFD62828),
        pickguardColor: instrumentPickguardColor ?? const Color(0xFFFFEA00),
      );
      _drawChromeStandMic(canvas, x: 16.0);
      break;

    case PerformerInstrument.acousticGuitar:
    case PerformerInstrument.acousticLute:
      _drawGuitar3D(
        canvas,
        offsetX: offsetX,
        liftY: handLiftY,
        strum: strum,
        neckAngleLift: neckSkyLift * 0.65,
        bodyColor: instrumentBodyColor ??
            (instrument == PerformerInstrument.acousticLute
                ? const Color(0xFFB5E48C)
                : const Color(0xFFD4A373)),
        pickguardColor: instrumentPickguardColor ?? const Color(0xFF4A2C18),
      );
      break;

    case PerformerInstrument.bassGuitar:
      _drawGuitar3D(
        canvas,
        offsetX: offsetX,
        liftY: handLiftY,
        strum: strum * 0.75,
        neckAngleLift: neckSkyLift * 0.5,
        bodyColor: instrumentBodyColor ?? const Color(0xFF582F0E),
        pickguardColor: instrumentPickguardColor ?? const Color(0xFFE9C46A),
        longNeck: true,
      );
      break;

    case PerformerInstrument.crystalBass:
      _drawGuitar3D(
        canvas,
        offsetX: offsetX,
        liftY: handLiftY,
        strum: strum,
        neckAngleLift: neckSkyLift,
        bodyColor: instrumentBodyColor ?? const Color(0xFF72EFDD),
        pickguardColor: instrumentPickguardColor ?? const Color(0xFFC77DFF),
        longNeck: true,
      );
      break;

    case PerformerInstrument.hammondOrgan:
      // 3D Walnut Organ Manual & Ivory Keys with animated chord-highlight glint!
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(5, 22, 22, 7),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF4A2511),
      );
      canvas.drawRect(
        const Rect.fromLTWH(7, 23.5, 18, 2.5),
        Paint()..color = const Color(0xFFF8F9FA),
      );
      final keyRun = 7.5 + ((strumPhase * 1.7).abs() % 15.0);
      canvas.drawRect(
        Rect.fromLTWH(keyRun, 23.5, 2.2, 2.5),
        Paint()..color = accentColor,
      );
      break;

    case PerformerInstrument.congasTimbales:
      // Twin 3D Wooden Santurce/Velvet Conga Drums + flying hand slap rings!
      for (final cx in const [11.5, 20.5]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, 25.5), width: 6.5, height: 8.0),
            const Radius.circular(2.5),
          ),
          Paint()..color = const Color(0xFF9C4221),
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, 22.0), width: 6.5, height: 2.6),
          Paint()..color = const Color(0xFFFDF0D5),
        );
      }
      if (isFlurry) {
        final slapX = (strumPhase.floor().isEven) ? 11.5 : 20.5;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(slapX, 21.8), width: 9.2, height: 4.0),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..color = accentColor.withValues(alpha: 0.8),
        );
      }
      break;

    case PerformerInstrument.turntablesDj:
      // Twin 3D Vinyl Turntable Deck with spinning platter tonearm glints!
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(5, 22, 22, 7),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF1D1E2C),
      );
      for (final dx in const [10.5, 21.5]) {
        canvas.drawCircle(
            Offset(dx, 25.2), 3.0, Paint()..color = const Color(0xFF111116));
        canvas.drawCircle(
            Offset(dx, 25.2), 1.1, Paint()..color = accentColor);
        final spinAng = strumPhase * 0.7;
        canvas.drawLine(
          Offset(dx, 25.2),
          Offset(dx + math.cos(spinAng) * 2.7, 25.2 + math.sin(spinAng) * 2.7),
          Paint()
            ..strokeWidth = 0.8
            ..color = const Color(0x99FFFFFF),
        );
      }
      break;

    case PerformerInstrument.paBroadcastMic:
      // Vintage Silver Ribbon Broadcast Stand Mic + live speech cadence arcs
      _drawChromeStandMic(canvas, x: 16.0, vintageRibbon: true);
      if (isPaSpeak && (choreo?.haloIntensity ?? 0.0) > 0.42) {
        final waveAlpha =
            (((choreo?.haloIntensity ?? 0.5) - 0.35) * 1.1).clamp(0.15, 0.75);
        canvas.drawArc(
          Rect.fromCenter(
              center: const Offset(16.0, 16.8), width: 11.0, height: 11.0),
          -math.pi * 0.8,
          math.pi * 1.6,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = Color.fromRGBO(255, 214, 102, waveAlpha),
        );
      }
      break;

    case PerformerInstrument.leadVocalMic:
      _drawChromeStandMic(canvas, x: 16.0);
      break;

    case PerformerInstrument.tambourineVocals:
      _drawChromeStandMic(canvas, x: 15.0);
      final shake = math.sin(strumPhase * 1.15) * 1.8;
      canvas.drawCircle(
        Offset(23.5 + offsetX, 19.5 - handLiftY + shake),
        3.2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFFFFD166),
      );
      break;
  }

  // Soulful Vocal Belt Aura Rings (Janice Joeplant, Mama Cass, Don Shell-O, Joan)!
  if (isVocalBelt) {
    final pulse = (time * 3.2) % 1.0;
    final r = 5.0 + pulse * 9.5;
    canvas.drawCircle(
      Offset(16.0 + offsetX * 0.5, 16.5 - handLiftY * 0.4),
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = accentColor.withValues(alpha: (1.0 - pulse) * 0.75),
    );
  }

  // Scanned Transient Spark Burst on Guitar Shreds, Climax Jumps & Cymbal Accents!
  final sparkBurst = choreo?.sparkBurst ?? 0.0;
  if (sparkBurst > 0.16) {
    final sparkPaint = Paint()
      ..color = Color.lerp(accentColor, const Color(0xFFFFFFFF), 0.55)!
          .withValues(alpha: (sparkBurst * 0.92).clamp(0.0, 0.92));
    for (var s = 0; s < 4; s++) {
      final a = time * 9.0 + s * (math.pi * 0.5);
      final rad = 7.0 + sparkBurst * 6.5;
      canvas.drawCircle(
        Offset(
          16.0 + offsetX + math.cos(a) * rad,
          16.0 - handLiftY + math.sin(a) * (rad * 0.65),
        ),
        1.2 + sparkBurst * 0.6,
        sparkPaint,
      );
    }
  }

  // Floating 3D stage musical note particles rising above active performers!
  if (emitNotes) {
    final noteSpeed = isShred || isVocalBelt ? 1.35 : 0.85;
    final noteCycle = (time * noteSpeed) % 1.0;
    final ny = 4.0 - noteCycle * 14.5 - handLiftY * 0.45;
    final nx = 18.0 + math.sin(time * 3.4) * 5.5 + offsetX;
    final alpha = (math.sin(noteCycle * math.pi) * 0.92).clamp(0.0, 0.92);
    final noteCol = accentColor.withValues(alpha: alpha);
    final notePaint = Paint()
      ..color = noteCol
      ..strokeWidth = 1.2;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(nx, ny), width: 3.2, height: 2.4),
      Paint()..color = noteCol,
    );
    canvas.drawLine(
        Offset(nx + 1.3, ny), Offset(nx + 1.3, ny - 5.0), notePaint);
    canvas.drawLine(
        Offset(nx + 1.3, ny - 5.0), Offset(nx + 4.0, ny - 4.0), notePaint);
  }
}

void _drawGuitar3D(
  Canvas canvas, {
  required double offsetX,
  required double liftY,
  required double strum,
  required Color bodyColor,
  required Color pickguardColor,
  double neckAngleLift = 0.0,
  bool leftHanded = false,
  bool longNeck = false,
}) {
  final dir = leftHanded ? -1.0 : 1.0;
  final bx = 15.0 + offsetX - dir * 2.0;
  final by = 21.5 - liftY + strum * 0.25;
  final neckLen = longNeck ? 11.5 : 9.2;

  // 3D body shadow bevel
  canvas.drawOval(
    Rect.fromCenter(center: Offset(bx, by + 1.2), width: 9.5, height: 6.5),
    Paint()..color = const Color(0xFF1E140C),
  );
  // Guitar body
  canvas.drawOval(
    Rect.fromCenter(center: Offset(bx, by), width: 9.2, height: 6.2),
    Paint()..color = bodyColor,
  );
  canvas.drawCircle(
    Offset(bx + dir * 1.0, by),
    1.8,
    Paint()..color = pickguardColor,
  );
  // Neck + headstock (lifts toward sky during Solo Shred!)
  final headX = bx + dir * (3.0 + neckLen - neckAngleLift * 0.35);
  final headY = by - 4.8 - neckAngleLift;
  canvas.drawLine(
    Offset(bx + dir * 3.0, by - 0.8),
    Offset(headX, headY),
    Paint()
      ..color = const Color(0xFFE6CCB2)
      ..strokeWidth = 1.8,
  );
  canvas.drawCircle(
    Offset(headX + dir * 0.4, headY - 0.2),
    1.55,
    Paint()..color = bodyColor,
  );
}

void _drawChromeStandMic(
  Canvas canvas, {
  required double x,
  bool vintageRibbon = false,
}) {
  // Weighted 3D circular chrome base on stage deck
  canvas.drawOval(
    Rect.fromCenter(center: Offset(x, 29.8), width: 7.0, height: 2.6),
    Paint()..color = const Color(0xFF495057),
  );
  canvas.drawLine(
    Offset(x, 29.5),
    Offset(x, 18.2),
    Paint()
      ..color = const Color(0xFFCED4DA)
      ..strokeWidth = 1.1,
  );
  if (vintageRibbon) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, 16.8), width: 4.2, height: 5.0),
        const Radius.circular(1.5),
      ),
      Paint()..color = const Color(0xFFFFD166),
    );
  } else {
    canvas.drawCircle(
      Offset(x, 17.4),
      2.0,
      Paint()..color = const Color(0xFFF8F9FA),
    );
  }
}
