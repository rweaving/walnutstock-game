import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../data/models.dart';
import 'day_night_atmosphere.dart';

enum LightShowSectionMode {
  paCadence,
  introDawn,
  versePocket,
  chorusAnthemy,
  soloShred,
  rhythmBreak,
  hushGlow,
  climaxPrism,
  outroFade;

  static LightShowSectionMode fromCode(String code) {
    switch (code) {
      case 'pa_cadence':
        return LightShowSectionMode.paCadence;
      case 'intro_dawn':
        return LightShowSectionMode.introDawn;
      case 'chorus_anthemy':
        return LightShowSectionMode.chorusAnthemy;
      case 'solo_shred':
        return LightShowSectionMode.soloShred;
      case 'rhythm_break':
        return LightShowSectionMode.rhythmBreak;
      case 'hush_glow':
        return LightShowSectionMode.hushGlow;
      case 'climax_prism':
        return LightShowSectionMode.climaxPrism;
      case 'outro_fade':
        return LightShowSectionMode.outroFade;
      case 'verse_pocket':
      default:
        return LightShowSectionMode.versePocket;
    }
  }

  String get displayBadge {
    switch (this) {
      case LightShowSectionMode.paCadence:
        return 'LIVE PA';
      case LightShowSectionMode.introDawn:
        return 'INTRO';
      case LightShowSectionMode.versePocket:
        return 'GROOVE';
      case LightShowSectionMode.chorusAnthemy:
        return 'CHORUS';
      case LightShowSectionMode.soloShred:
        return 'SOLO';
      case LightShowSectionMode.rhythmBreak:
        return 'BREAK';
      case LightShowSectionMode.hushGlow:
        return 'HUSH';
      case LightShowSectionMode.climaxPrism:
        return 'CLIMAX';
      case LightShowSectionMode.outroFade:
        return 'OUTRO';
    }
  }
}

enum LightShowAccentKind {
  none,
  kickDrop,
  snareSnap,
  cymbalBlinder,
  leadRiff;

  static LightShowAccentKind fromInt(int code) {
    switch (code) {
      case 0:
        return LightShowAccentKind.kickDrop;
      case 1:
        return LightShowAccentKind.snareSnap;
      case 2:
        return LightShowAccentKind.cymbalBlinder;
      case 3:
        return LightShowAccentKind.leadRiff;
      default:
        return LightShowAccentKind.none;
    }
  }
}

enum PerformerPoseMove {
  pocketGroove,
  soloShred,
  vocalBelt,
  powerJump,
  percussionFlurry,
  intimateSway,
  paSyllableSpeak,
}

class PerformerChoreoSample {
  const PerformerChoreoSample({
    required this.bounceY,
    required this.swayX,
    required this.forwardStepY,
    required this.bodyTiltRad,
    required this.spriteFrameCol,
    required this.strumPhase,
    required this.poseMove,
    required this.haloIntensity,
    required this.sparkBurst,
  });

  final double bounceY;
  final double swayX;
  final double forwardStepY;
  final double bodyTiltRad;
  final int spriteFrameCol;
  final double strumPhase;
  final PerformerPoseMove poseMove;
  final double haloIntensity;
  final double sparkBurst;
}

class ScannedSectionCue {
  const ScannedSectionCue({
    required this.startSec,
    required this.endSec,
    required this.mode,
    required this.intensity,
  });

  final double startSec;
  final double endSec;
  final LightShowSectionMode mode;
  final double intensity;
}

class ScannedAccentCue {
  const ScannedAccentCue({
    required this.timeSec,
    required this.kind,
    required this.strength,
  });

  final double timeSec;
  final LightShowAccentKind kind;
  final double strength;
}

class ScannedTrackShow {
  const ScannedTrackShow({
    required this.trackId,
    required this.trackNumber,
    required this.scannedDurationSec,
    required this.looped,
    required this.bpm,
    required this.beatOffsetSec,
    required this.envHz,
    required this.bassEnv,
    required this.midEnv,
    required this.highMidEnv,
    required this.airEnv,
    required this.sections,
    required this.accents,
  });

  static const String _b64Alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
  static final Int8List _b64DecodeLut = _buildLut();

  static Int8List _buildLut() {
    final lut = Int8List(128)..fillRange(0, 128, 0);
    for (var i = 0; i < _b64Alphabet.length; i++) {
      lut[_b64Alphabet.codeUnitAt(i)] = i;
    }
    return lut;
  }

  static Float32List _decodeEnvelope(String b64) {
    final out = Float32List(b64.length);
    for (var i = 0; i < b64.length; i++) {
      final code = b64.codeUnitAt(i);
      final q = code < 128 ? _b64DecodeLut[code] : 0;
      out[i] = (q / 63.0).clamp(0.0, 1.0);
    }
    return out;
  }

  factory ScannedTrackShow.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'] as List<dynamic>? ?? const [];
    final sections = <ScannedSectionCue>[
      for (final s in rawSections)
        if (s is List && s.length >= 4)
          ScannedSectionCue(
            startSec: (s[0] as num).toDouble(),
            endSec: (s[1] as num).toDouble(),
            mode: LightShowSectionMode.fromCode(s[2].toString()),
            intensity: (s[3] as num).toDouble(),
          ),
    ];

    final rawAccents = json['accents'] as List<dynamic>? ?? const [];
    final accents = <ScannedAccentCue>[
      for (final a in rawAccents)
        if (a is List && a.length >= 3)
          ScannedAccentCue(
            timeSec: (a[0] as num).toDouble(),
            kind: LightShowAccentKind.fromInt((a[1] as num).toInt()),
            strength: (a[2] as num).toDouble(),
          ),
    ];

    return ScannedTrackShow(
      trackId: json['id'] as String? ?? '',
      trackNumber: (json['trackNumber'] as num?)?.toInt() ?? 0,
      scannedDurationSec:
          (json['scannedDurationSec'] as num?)?.toDouble() ?? 180.0,
      looped: json['looped'] as bool? ?? false,
      bpm: (json['bpm'] as num?)?.toDouble() ?? 116.0,
      beatOffsetSec: (json['beatOffsetSec'] as num?)?.toDouble() ?? 0.0,
      envHz: (json['envHz'] as num?)?.toDouble() ?? 10.0,
      bassEnv: _decodeEnvelope(json['bassB64'] as String? ?? ''),
      midEnv: _decodeEnvelope(json['midB64'] as String? ?? ''),
      highMidEnv: _decodeEnvelope(json['highMidB64'] as String? ?? ''),
      airEnv: _decodeEnvelope(json['airB64'] as String? ?? ''),
      sections: sections,
      accents: accents,
    );
  }

  final String trackId;
  final int trackNumber;
  final double scannedDurationSec;
  final bool looped;
  final double bpm;
  final double beatOffsetSec;
  final double envHz;
  final Float32List bassEnv;
  final Float32List midEnv;
  final Float32List highMidEnv;
  final Float32List airEnv;
  final List<ScannedSectionCue> sections;
  final List<ScannedAccentCue> accents;

  double _sampleEnv(Float32List env, double tSec) {
    if (env.isEmpty) return 0.35;
    final pos = (tSec * envHz).clamp(0.0, env.length - 1.0001);
    final idx = pos.floor();
    final frac = pos - idx;
    final a = env[idx];
    final b = idx + 1 < env.length ? env[idx + 1] : a;
    return a + (b - a) * frac;
  }

  StageShowFrame sampleAt(ScheduledTrack track, double rawTrackTimeSec) {
    final effDur = math.max(1.0, scannedDurationSec);
    final tSec = looped
        ? (rawTrackTimeSec.abs() % effDur)
        : rawTrackTimeSec.clamp(0.0, effDur);

    final bass = _sampleEnv(bassEnv, tSec);
    final mid = _sampleEnv(midEnv, tSec);
    final highMid = _sampleEnv(highMidEnv, tSec);
    final air = _sampleEnv(airEnv, tSec);

    // Beat grid math locked to scanned BPM + beatOffsetSec
    final beatsPerSec = bpm / 60.0;
    final rawBeats = (tSec - beatOffsetSec) * beatsPerSec;
    final beatIndex = rawBeats.floor();
    final beatPhase = (rawBeats - beatIndex).clamp(0.0, 1.0);
    final barBeat = ((beatIndex % 4) + 4) % 4;
    final beatPulse = math.pow(1.0 - beatPhase, 2.55).toDouble();

    // Active structural musical section via binary search
    var sectionMode = track.isPaBroadcast
        ? LightShowSectionMode.paCadence
        : LightShowSectionMode.versePocket;
    var sectionIntensity = 0.65;
    var sectionProgress = 0.5;
    if (sections.isNotEmpty) {
      var lo = 0;
      var hi = sections.length - 1;
      var matched = sections.last;
      while (lo <= hi) {
        final midIdx = (lo + hi) >> 1;
        final cur = sections[midIdx];
        if (tSec < cur.startSec) {
          hi = midIdx - 1;
        } else if (tSec > cur.endSec && midIdx < sections.length - 1) {
          lo = midIdx + 1;
        } else {
          matched = cur;
          break;
        }
      }
      sectionMode = matched.mode;
      sectionIntensity = matched.intensity;
      final span = math.max(0.25, matched.endSec - matched.startSec);
      sectionProgress = ((tSec - matched.startSec) / span).clamp(0.0, 1.0);
    }

    // Nearest preceding transient accent within 0.34s via binary search
    var accentKind = LightShowAccentKind.none;
    var accentFlash = 0.0;
    var accentAgeSec = 9.0;
    if (accents.isNotEmpty) {
      var lo = 0;
      var hi = accents.length - 1;
      var bestIdx = -1;
      while (lo <= hi) {
        final midIdx = (lo + hi) >> 1;
        if (accents[midIdx].timeSec <= tSec + 0.015) {
          bestIdx = midIdx;
          lo = midIdx + 1;
        } else {
          hi = midIdx - 1;
        }
      }
      if (bestIdx >= 0) {
        final hit = accents[bestIdx];
        final dtHit = math.max(0.0, tSec - hit.timeSec);
        if (dtHit <= 0.34) {
          accentKind = hit.kind;
          accentAgeSec = dtHit;
          final decay = math.exp(-dtHit * 8.8);
          accentFlash = (hit.strength * decay).clamp(0.0, 1.0);
        }
      }
    }

    return StageShowFrame(
      trackId: track.id,
      trackNumber: track.trackNumber,
      trackTimeSec: tSec,
      bpm: bpm,
      sectionMode: sectionMode,
      sectionIntensity: sectionIntensity,
      sectionProgress: sectionProgress,
      bass: bass,
      mid: mid,
      highMid: highMid,
      air: air,
      beatIndex: beatIndex,
      barBeat: barBeat,
      beatPhase: beatPhase,
      beatPulse: beatPulse,
      accentKind: accentKind,
      accentFlash: accentFlash,
      accentAgeSec: accentAgeSec,
    );
  }
}

class StageShowFrame {
  const StageShowFrame({
    required this.trackId,
    required this.trackNumber,
    required this.trackTimeSec,
    required this.bpm,
    required this.sectionMode,
    required this.sectionIntensity,
    required this.sectionProgress,
    required this.bass,
    required this.mid,
    required this.highMid,
    required this.air,
    required this.beatIndex,
    required this.barBeat,
    required this.beatPhase,
    required this.beatPulse,
    required this.accentKind,
    required this.accentFlash,
    required this.accentAgeSec,
  });

  final String trackId;
  final int trackNumber;
  final double trackTimeSec;
  final double bpm;
  final LightShowSectionMode sectionMode;
  final double sectionIntensity;
  final double sectionProgress;
  final double bass;
  final double mid;
  final double highMid;
  final double air;
  final int beatIndex;
  final int barBeat;
  final double beatPhase;
  final double beatPulse;
  final LightShowAccentKind accentKind;
  final double accentFlash;
  final double accentAgeSec;

  double get totalEnergy =>
      (bass * 0.34 + mid * 0.26 + highMid * 0.26 + air * 0.14).clamp(0.0, 1.0);

  double get blinderBurst => accentKind == LightShowAccentKind.cymbalBlinder
      ? accentFlash
      : (sectionMode == LightShowSectionMode.climaxPrism && barBeat == 0
          ? beatPulse * 0.65 * sectionIntensity
          : 0.0);

  double get bassShockwave => accentKind == LightShowAccentKind.kickDrop
      ? accentFlash
      : (bass > 0.72 ? beatPulse * 0.55 : 0.0);

  bool get kickDrop => bassShockwave > 0.32;

  Color get primaryColor => switch (sectionMode) {
        LightShowSectionMode.chorusAnthemy => const Color(0xFFFFD166),
        LightShowSectionMode.soloShred => const Color(0xFF4CC9F0),
        LightShowSectionMode.climaxPrism => const Color(0xFFF72585),
        LightShowSectionMode.rhythmBreak => const Color(0xFF06D6A0),
        LightShowSectionMode.hushGlow => const Color(0xFF90E0EF),
        LightShowSectionMode.introDawn => const Color(0xFFFFBE0B),
        _ => const Color(0xFFFF9F1C),
      };

  Color get secondaryColor => switch (sectionMode) {
        LightShowSectionMode.chorusAnthemy => const Color(0xFFF72585),
        LightShowSectionMode.soloShred => const Color(0xFF9D4EDD),
        LightShowSectionMode.climaxPrism => const Color(0xFF80FFDB),
        LightShowSectionMode.rhythmBreak => const Color(0xFFFFBE0B),
        LightShowSectionMode.hushGlow => const Color(0xFFE0AAFF),
        LightShowSectionMode.introDawn => const Color(0xFF52B788),
        _ => const Color(0xFF48CAE4),
      };

  /// Computes role-accurate, beat-locked animation & signature Woodstock poses for an on-stage performer.
  PerformerChoreoSample samplePerformer({
    required bool isPercussion,
    required bool isBass,
    required bool isKeysOrDj,
    required bool isVocalist,
    required bool isGuitarist,
    required bool isLeadPerformer,
    required int rolePhaseIndex,
  }) {
    // 1. Patchouli Pete PA Broadcast syllable-synced speaking animation!
    if (sectionMode == LightShowSectionMode.paCadence) {
      final syllable = (mid * 0.45 + highMid * 0.55).clamp(0.0, 1.0);
      final speaking = syllable > 0.24;
      final emph = accentFlash > 0.35 ? accentFlash * 2.2 : 0.0;
      return PerformerChoreoSample(
        bounceY: speaking ? (syllable * 1.9 + emph) : 0.2,
        swayX: speaking
            ? math.sin(trackTimeSec * 4.5) * (1.2 + syllable * 1.5)
            : math.sin(trackTimeSec * 1.4) * 0.4,
        forwardStepY: speaking ? 1.2 * syllable : 0.0,
        bodyTiltRad: speaking ? math.sin(trackTimeSec * 6.0) * 0.06 : 0.0,
        spriteFrameCol: speaking ? ((trackTimeSec * 8.0).floor().abs() % 3) : 0,
        strumPhase: trackTimeSec * 6.0,
        poseMove: PerformerPoseMove.paSyllableSpeak,
        haloIntensity: (0.25 + syllable * 0.65).clamp(0.0, 1.0),
        sparkBurst: emph * 0.4,
      );
    }

    // 2. Musical Beat-Locked Bounce & Pose Selection
    final beatArc = math.sin(beatPhase * math.pi);
    final halfBeatIdx =
        ((trackTimeSec * (bpm / 60.0) * 2.0).floor() + rolePhaseIndex).abs();

    var pose = PerformerPoseMove.pocketGroove;
    var jumpLift = 0.0;
    var forwardStep = 0.0;
    var tilt = 0.0;
    var sparks = 0.0;
    var halo = 0.28 + totalEnergy * 0.35;

    if (sectionMode == LightShowSectionMode.hushGlow ||
        sectionMode == LightShowSectionMode.outroFade) {
      pose = PerformerPoseMove.intimateSway;
      final gentleSway =
          math.sin(trackTimeSec * 2.1 + rolePhaseIndex * 0.7) * 1.8;
      return PerformerChoreoSample(
        bounceY: beatArc * (0.65 + mid * 0.8),
        swayX: gentleSway,
        forwardStepY: 0.0,
        bodyTiltRad: gentleSway * 0.035,
        spriteFrameCol: (beatIndex + rolePhaseIndex).abs() % 3,
        strumPhase: trackTimeSec * 5.0,
        poseMove: pose,
        haloIntensity: 0.24 + highMid * 0.30,
        sparkBurst: 0.0,
      );
    }

    if (isPercussion) {
      final flurry = sectionMode == LightShowSectionMode.rhythmBreak ||
          accentKind == LightShowAccentKind.cymbalBlinder ||
          accentKind == LightShowAccentKind.snareSnap;
      if (flurry) {
        pose = PerformerPoseMove.percussionFlurry;
        sparks = (accentFlash * 0.85 + air * 0.35).clamp(0.0, 1.0);
        halo = 0.72 + accentFlash * 0.28;
      }
      final hitBounce =
          beatPulse * (1.5 + bass * 2.4) + accentFlash * (flurry ? 2.2 : 1.2);
      return PerformerChoreoSample(
        bounceY: hitBounce,
        swayX: math.sin(trackTimeSec * (flurry ? 11.0 : 5.2) + rolePhaseIndex) *
            (flurry ? 1.8 : 1.1),
        forwardStepY: 0.0,
        bodyTiltRad:
            math.sin(trackTimeSec * 8.5 + rolePhaseIndex) * (flurry ? 0.09 : 0.04),
        spriteFrameCol: flurry
            ? ((trackTimeSec * 14.0).floor().abs() % 3)
            : (halfBeatIdx % 3),
        strumPhase: trackTimeSec * (flurry ? 24.0 : 14.0) + accentFlash * 3.0,
        poseMove: pose,
        haloIntensity: halo,
        sparkBurst: sparks,
      );
    }

    // Lead Solo / Climax / Vocal Belt Choreography
    if (isLeadPerformer &&
        (sectionMode == LightShowSectionMode.soloShred ||
            accentKind == LightShowAccentKind.leadRiff)) {
      if (isGuitarist) {
        pose = PerformerPoseMove.soloShred;
        forwardStep = 4.2 * (0.55 + 0.45 * highMid);
        tilt = -0.14 - highMid * 0.10 - accentFlash * 0.08;
        sparks = (0.45 + highMid * 0.55 + accentFlash * 0.5).clamp(0.0, 1.0);
        halo = 0.88;
      } else if (isVocalist) {
        pose = PerformerPoseMove.vocalBelt;
        forwardStep = 3.2 * highMid;
        tilt = 0.10 * highMid;
        sparks = (highMid * 0.7 + accentFlash * 0.4).clamp(0.0, 1.0);
        halo = 0.85;
      }
    } else if (sectionMode == LightShowSectionMode.climaxPrism &&
        (isLeadPerformer || isGuitarist || isBass)) {
      if ((accentKind == LightShowAccentKind.kickDrop ||
              accentKind == LightShowAccentKind.cymbalBlinder) &&
          accentAgeSec < 0.28) {
        pose = PerformerPoseMove.powerJump;
        jumpLift = math.sin((accentAgeSec / 0.28) * math.pi) *
            (isLeadPerformer ? 6.2 : 4.2);
        sparks = accentFlash;
        halo = 0.95;
      } else if (isLeadPerformer && barBeat == 0) {
        pose = PerformerPoseMove.powerJump;
        jumpLift = beatArc * 4.5 * sectionIntensity;
        sparks = beatPulse * 0.65;
        halo = 0.85;
      }
    } else if (isVocalist && highMid > 0.66) {
      pose = PerformerPoseMove.vocalBelt;
      tilt = 0.08 * highMid;
      halo = 0.72;
      sparks = (highMid - 0.55) * 1.4;
    }

    final roleBand = isBass
        ? bass
        : isKeysOrDj
            ? (mid * 0.55 + highMid * 0.45)
            : isVocalist
                ? highMid
                : (mid * 0.45 + highMid * 0.55);

    final grooveBounce =
        beatArc * (1.1 + roleBand * 2.2) + beatPulse * bass * 1.1 + jumpLift;
    final barDir = (barBeat < 2 ? 1.0 : -1.0);
    final syncSway = sectionMode == LightShowSectionMode.chorusAnthemy ||
            sectionMode == LightShowSectionMode.climaxPrism
        ? math.sin((beatIndex + beatPhase) * math.pi * 0.5) * 2.5
        : math.sin(trackTimeSec * (bpm / 60.0) * math.pi * 0.5 +
                rolePhaseIndex * 0.9) *
            (1.3 + roleBand * 1.1) *
            barDir;

    final fastFrames = pose == PerformerPoseMove.soloShred ||
        sectionMode == LightShowSectionMode.climaxPrism;
    final frameCol = fastFrames
        ? ((trackTimeSec * 12.0 + rolePhaseIndex).floor().abs() % 3)
        : (halfBeatIdx % 3);

    return PerformerChoreoSample(
      bounceY: grooveBounce,
      swayX: syncSway,
      forwardStepY: forwardStep,
      bodyTiltRad: tilt == 0.0 ? syncSway * 0.025 : tilt,
      spriteFrameCol: frameCol,
      strumPhase: trackTimeSec * (fastFrames ? 22.0 : 13.0) +
          beatPulse * 1.8 +
          rolePhaseIndex,
      poseMove: pose,
      haloIntensity: halo.clamp(0.0, 1.0),
      sparkBurst: sparks.clamp(0.0, 1.0),
    );
  }
}

class ConcertLightShowLibrary {
  const ConcertLightShowLibrary(this._tracks);

  static const ConcertLightShowLibrary empty = ConcertLightShowLibrary({});

  factory ConcertLightShowLibrary.fromJson(Map<String, dynamic> json) {
    final rawMap = json['tracks'] as Map<String, dynamic>? ?? const {};
    final parsed = <String, ScannedTrackShow>{};
    for (final entry in rawMap.entries) {
      if (entry.value is Map<String, dynamic>) {
        parsed[entry.key] =
            ScannedTrackShow.fromJson(entry.value as Map<String, dynamic>);
      }
    }
    return ConcertLightShowLibrary(parsed);
  }

  final Map<String, ScannedTrackShow> _tracks;

  bool get isEmpty => _tracks.isEmpty;
  int get length => _tracks.length;

  ScannedTrackShow? showForTrackId(String trackId) => _tracks[trackId];

  StageShowFrame sampleTrack(ScheduledTrack track, double trackTimeSec) {
    final scanned = _tracks[track.id];
    if (scanned != null) {
      return scanned.sampleAt(track, trackTimeSec);
    }

    // Deterministic procedural fallback if JSON omitted in minimal unit tests
    const bpm = 118.0;
    final rawBeats = trackTimeSec * (bpm / 60.0);
    final beatIndex = rawBeats.floor();
    final beatPhase = (rawBeats - beatIndex).clamp(0.0, 1.0);
    final beatPulse = math.pow(1.0 - beatPhase, 2.5).toDouble();
    final swell = 0.5 + 0.5 * math.sin(trackTimeSec * 0.45);
    return StageShowFrame(
      trackId: track.id,
      trackNumber: track.trackNumber,
      trackTimeSec: trackTimeSec,
      bpm: bpm,
      sectionMode: track.isPaBroadcast
          ? LightShowSectionMode.paCadence
          : (swell > 0.72
              ? LightShowSectionMode.chorusAnthemy
              : LightShowSectionMode.versePocket),
      sectionIntensity: 0.45 + 0.45 * swell,
      sectionProgress: (trackTimeSec / math.max(1.0, track.durationSeconds))
          .clamp(0.0, 1.0),
      bass: (0.35 + 0.55 * beatPulse).clamp(0.0, 1.0),
      mid: (0.35 + 0.45 * swell).clamp(0.0, 1.0),
      highMid: (0.30 + 0.50 * swell).clamp(0.0, 1.0),
      air: (0.20 + 0.40 * beatPulse).clamp(0.0, 1.0),
      beatIndex: beatIndex,
      barBeat: ((beatIndex % 4) + 4) % 4,
      beatPhase: beatPhase,
      beatPulse: beatPulse,
      accentKind: beatPhase < 0.08
          ? LightShowAccentKind.kickDrop
          : LightShowAccentKind.none,
      accentFlash: beatPhase < 0.08 ? 0.65 : 0.0,
      accentAgeSec: beatPhase * (60.0 / bpm),
    );
  }
}

/// Renders 1969 liquid-light psychedelic floor gobos, beat-chasing footlights, and sub-bass shockwaves!
void renderStageFloorLightShow({
  required Canvas canvas,
  required Offset center,
  required double radiusX,
  required double radiusY,
  required StageShowFrame show,
  required Color primaryColor,
  required Color secondaryColor,
  Offset? soloFocusPos,
}) {
  final t = show.trackTimeSec;
  final mode = show.sectionMode;

  // 1. Rotating Liquid-Oil / Geometric Mandala Stage Floor Projection
  if (mode != LightShowSectionMode.paCadence) {
    final focus =
        (mode == LightShowSectionMode.soloShred && soloFocusPos != null)
            ? soloFocusPos
            : center;
    final scale = mode == LightShowSectionMode.soloShred
        ? 0.58 + show.highMid * 0.22
        : mode == LightShowSectionMode.hushGlow
            ? 0.48
            : (0.82 + show.bass * 0.24 + show.beatPulse * 0.10);
    final rx = radiusX * scale;
    final ry = radiusY * scale;

    final baseAlpha = switch (mode) {
      LightShowSectionMode.climaxPrism => 0.34,
      LightShowSectionMode.chorusAnthemy => 0.27,
      LightShowSectionMode.soloShred => 0.32,
      LightShowSectionMode.rhythmBreak => 0.24,
      LightShowSectionMode.hushGlow => 0.14,
      _ => 0.18,
    };

    canvas.save();
    canvas.translate(focus.dx, focus.dy);

    // Soft radial floor light pool
    final glowRect = Rect.fromCenter(
        center: Offset.zero, width: rx * 2.2, height: ry * 2.2);
    final poolGrad = Gradient.radial(
      Offset.zero,
      math.max(rx, ry),
      <Color>[
        primaryColor.withValues(alpha: (baseAlpha * 1.1).clamp(0.0, 0.45)),
        secondaryColor.withValues(alpha: (baseAlpha * 0.55).clamp(0.0, 0.25)),
        primaryColor.withValues(alpha: 0.0),
      ],
      const <double>[0.0, 0.58, 1.0],
    );
    canvas.drawOval(
      glowRect,
      Paint()
        ..shader = poolGrad
        ..blendMode = BlendMode.plus,
    );

    // Counter-rotating 6-petal / 8-petal gobo rosette
    final petals = mode == LightShowSectionMode.climaxPrism ? 8 : 6;
    final rotSpeed = mode == LightShowSectionMode.climaxPrism
        ? 1.35
        : mode == LightShowSectionMode.rhythmBreak
            ? 1.8
            : 0.72;
    final goboPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..blendMode = BlendMode.plus
      ..color = Color.lerp(primaryColor, const Color(0xFFFFFFFF),
              0.25 + show.beatPulse * 0.35)!
          .withValues(alpha: (baseAlpha * 1.25).clamp(0.0, 0.48));

    final path = Path();
    const steps = 36;
    for (var i = 0; i <= steps; i++) {
      final u = (i / steps) * math.pi * 2.0;
      final petalMod =
          0.72 + 0.28 * math.cos(u * petals + t * rotSpeed * 2.0);
      final px = math.cos(u + t * rotSpeed * 0.5) * rx * petalMod;
      final py = math.sin(u + t * rotSpeed * 0.5) * ry * petalMod;
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    canvas.drawPath(path, goboPaint);
    canvas.restore();
  }

  // 2. Expanding Sub-Bass Shockwave Ring on scanned Kick Drops!
  if (show.bassShockwave > 0.08) {
    final prog = (show.accentAgeSec / 0.34).clamp(0.0, 1.0);
    final ringRx = radiusX * (0.35 + prog * 0.95);
    final ringRy = radiusY * (0.35 + prog * 0.95);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: ringRx * 2, height: ringRy * 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 - prog * 0.8
        ..blendMode = BlendMode.plus
        ..color = primaryColor.withValues(
            alpha: (show.bassShockwave * 0.55 * (1.0 - prog)).clamp(0.0, 0.55)),
    );
  }
}

/// Renders multi-fixture truss PAR chases, volumetric moving heads, soloist follow-spots,
/// crisscrossing concert laser fans, and cymbal-crash audience blinders!
void renderConcertOverheadLightShow({
  required Canvas canvas,
  required List<Offset> fixtureOrigins,
  required Offset stageDeckCenter,
  required double deckWidth,
  required StageShowFrame show,
  required Color primaryColor,
  required Color secondaryColor,
  Offset? soloFocusPos,
}) {
  if (fixtureOrigins.isEmpty) return;
  final mode = show.sectionMode;
  final t = show.trackTimeSec;
  final count = fixtureOrigins.length;

  final prismPalette = <Color>[
    primaryColor,
    secondaryColor,
    const Color(0xFFFF007F),
    const Color(0xFF00F5D4),
    const Color(0xFFFFBE0B),
    const Color(0xFF9D4EDD),
  ];

  // 1. Draw Individual Chasing PAR Can Lens Glows Along Truss!
  for (var i = 0; i < count; i++) {
    final orig = fixtureOrigins[i];
    final bool isActiveCan = switch (mode) {
      LightShowSectionMode.hushGlow => i == count ~/ 2,
      LightShowSectionMode.soloShred => i == 0 || i == count - 1 || i == count ~/ 2,
      LightShowSectionMode.rhythmBreak =>
        (i + show.beatIndex) % 2 == 0 || show.accentFlash > 0.3,
      LightShowSectionMode.versePocket =>
        (i + show.barBeat) % 2 == 0 || i == count ~/ 2,
      _ => true,
    };

    final Color canColor;
    if (mode == LightShowSectionMode.climaxPrism ||
        mode == LightShowSectionMode.chorusAnthemy) {
      canColor = prismPalette[(i + show.barBeat) % prismPalette.length];
    } else {
      canColor = i.isEven ? primaryColor : secondaryColor;
    }

    final lensRadius =
        isActiveCan ? (2.3 + show.beatPulse * 1.2 + show.blinderBurst * 1.6) : 1.4;
    canvas.drawCircle(
      orig,
      lensRadius,
      Paint()
        ..color = isActiveCan
            ? Color.lerp(canColor, const Color(0xFFFFFFFF),
                (show.blinderBurst * 0.75 + show.beatPulse * 0.25).clamp(0.0, 1.0))!
            : canColor.withValues(alpha: 0.32),
    );
  }

  // 2. Volumetric Spotlight Beams Driven by Musical Section & Beat Grid!
  if (mode == LightShowSectionMode.hushGlow) {
    final midOrigin = fixtureOrigins[count ~/ 2];
    final target = soloFocusPos ?? stageDeckCenter;
    _drawVolumetricBeam(
      canvas,
      origin: midOrigin,
      target: target,
      targetHalfWidth: 16.0 + show.highMid * 6.0,
      color: const Color(0xFFFFF3B0),
      alpha: 0.26 + show.highMid * 0.14,
    );
    return;
  }

  if (mode == LightShowSectionMode.soloShred) {
    // Dramatic darkened outer stage + blazing twin converging follow-spots & laser lock on soloist!
    final target = soloFocusPos ?? stageDeckCenter;
    final leftOrig = fixtureOrigins.first;
    final rightOrig = fixtureOrigins.last;
    final centerOrig = fixtureOrigins[count ~/ 2];

    _drawVolumetricBeam(
      canvas,
      origin: leftOrig,
      target: target,
      targetHalfWidth: 14.0 + show.highMid * 6.0,
      color: primaryColor,
      alpha: 0.34 + show.highMid * 0.18,
    );
    _drawVolumetricBeam(
      canvas,
      origin: rightOrig,
      target: target,
      targetHalfWidth: 14.0 + show.highMid * 6.0,
      color: secondaryColor,
      alpha: 0.34 + show.highMid * 0.18,
    );
    _drawVolumetricBeam(
      canvas,
      origin: centerOrig,
      target: target,
      targetHalfWidth: 11.0 + show.accentFlash * 5.0,
      color: const Color(0xFFFFFFFF),
      alpha: 0.28 + show.highMid * 0.20,
    );

    // Twin crisp concert laser lines tracing the soloist!
    final laserPaint = Paint()
      ..strokeWidth = 1.15
      ..blendMode = BlendMode.plus
      ..color = Color.lerp(primaryColor, const Color(0xFFFFFFFF), 0.45)!
          .withValues(alpha: (0.45 + show.highMid * 0.40).clamp(0.0, 0.85));
    canvas.drawLine(leftOrig, target, laserPaint);
    canvas.drawLine(rightOrig, target, laserPaint);
  } else {
    // Verse / Chorus / Rhythm Break / Climax Multi-Head Volumetric Sweep!
    final beatSweep = (show.beatIndex + show.beatPhase) *
        (show.bpm / 120.0) *
        (mode == LightShowSectionMode.climaxPrism ? 1.55 : 0.95);
    final scissorFlip =
        (show.accentKind == LightShowAccentKind.snareSnap && show.accentFlash > 0.25)
            ? -1.0
            : 1.0;

    final beamStride = (mode == LightShowSectionMode.climaxPrism ||
            mode == LightShowSectionMode.chorusAnthemy)
        ? 1
        : math.max(1, count ~/ 3);

    for (var i = 0; i < count; i += beamStride) {
      if (mode == LightShowSectionMode.rhythmBreak &&
          (i + show.beatIndex) % 2 != 0 &&
          show.accentFlash < 0.35) {
        continue;
      }
      final orig = fixtureOrigins[i];
      final u = count > 1 ? (i / (count - 1)) * 2.0 - 1.0 : 0.0;
      final phase = beatSweep + i * 0.85;
      final sweepSpan = deckWidth *
          (mode == LightShowSectionMode.climaxPrism ? 0.38 : 0.24);
      final targetX = stageDeckCenter.dx +
          u * deckWidth * 0.28 * scissorFlip +
          math.sin(phase) * sweepSpan;
      final targetY = stageDeckCenter.dy +
          4.0 +
          math.cos(phase * 0.7) * 8.0 +
          (mode == LightShowSectionMode.climaxPrism ? 10.0 : 0.0);

      final beamColor = (mode == LightShowSectionMode.climaxPrism ||
              mode == LightShowSectionMode.chorusAnthemy)
          ? prismPalette[(i + show.barBeat) % prismPalette.length]
          : (i.isEven ? primaryColor : secondaryColor);

      final alpha = (0.16 +
              show.sectionIntensity * 0.12 +
              show.beatPulse * 0.12 +
              show.bass * 0.08)
          .clamp(0.10, 0.48);

      _drawVolumetricBeam(
        canvas,
        origin: orig,
        target: Offset(targetX, targetY),
        targetHalfWidth: 18.0 + show.bass * 8.0 + show.beatPulse * 5.0,
        color: beamColor,
        alpha: alpha,
      );
    }
  }

  // 3. Overhead Laser Fan Rays on Climax Prism & High-Energy Chorus Drops!
  if (mode == LightShowSectionMode.climaxPrism ||
      (mode == LightShowSectionMode.chorusAnthemy && show.totalEnergy > 0.62)) {
    final centerOrig = fixtureOrigins[count ~/ 2];
    final rayCount = mode == LightShowSectionMode.climaxPrism ? 7 : 5;
    final fanSpread = deckWidth * 0.72;
    final wag = math.sin(t * 3.4) * 14.0;
    for (var r = 0; r < rayCount; r++) {
      final frac = (r / (rayCount - 1)) * 2.0 - 1.0;
      final endPt = Offset(
        stageDeckCenter.dx + frac * fanSpread + wag * (r.isEven ? 1 : -1),
        stageDeckCenter.dy + 34.0 + (1.0 - frac.abs()) * 14.0,
      );
      final rayCol = prismPalette[(r + show.beatIndex) % prismPalette.length];
      canvas.drawLine(
        centerOrig,
        endPt,
        Paint()
          ..strokeWidth = 0.95 + show.beatPulse * 0.55
          ..blendMode = BlendMode.plus
          ..color = rayCol.withValues(
              alpha: (0.24 + show.beatPulse * 0.36).clamp(0.0, 0.62)),
      );
    }
  }

  // 4. Audience Cymbal-Crash Blinder Star-Flares!
  if (show.blinderBurst > 0.12) {
    final flareAlpha = (show.blinderBurst * 0.78).clamp(0.0, 0.78);
    final flarePaint = Paint()
      ..strokeWidth = 1.2
      ..blendMode = BlendMode.plus
      ..color = Color.fromRGBO(255, 250, 224, flareAlpha);
    for (var i = 0; i < count; i += math.max(1, count ~/ 3)) {
      final c = fixtureOrigins[i];
      final r = 5.0 + show.blinderBurst * 9.0;
      canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), flarePaint);
      canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), flarePaint);
      canvas.drawCircle(
        c,
        3.5 + show.blinderBurst * 4.5,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = Color.fromRGBO(255, 245, 200, flareAlpha * 0.65),
      );
    }
  }
}

void _drawVolumetricBeam(
  Canvas canvas, {
  required Offset origin,
  required Offset target,
  required double targetHalfWidth,
  required Color color,
  required double alpha,
}) {
  final path = Path()
    ..moveTo(origin.dx - 2.2, origin.dy)
    ..lineTo(origin.dx + 2.2, origin.dy)
    ..lineTo(target.dx + targetHalfWidth, target.dy)
    ..lineTo(target.dx - targetHalfWidth, target.dy)
    ..close();
  final grad = Gradient.linear(
    origin,
    target,
    <Color>[
      color.withValues(alpha: (alpha * 1.18).clamp(0.0, 0.56)),
      color.withValues(alpha: (alpha * 0.45).clamp(0.0, 0.28)),
      color.withValues(alpha: 0.0),
    ],
    const <double>[0.0, 0.68, 1.0],
  );
  canvas.drawPath(
    path,
    Paint()
      ..shader = grad
      ..blendMode = BlendMode.plus,
  );
}

/// Emits dynamic moving-head & blinder LightSource3D pools into the Night/Storm Lightmap!
List<LightSource3D> buildDynamicStageWorldLights({
  required String stageId,
  required Offset stageCenter,
  required StageShowFrame show,
  required Color primaryColor,
  required Color secondaryColor,
  Offset? soloFocusPos,
}) {
  if (stageId == 'pa_global_horn') {
    final syllable = (show.mid * 0.45 + show.highMid * 0.55).clamp(0.0, 1.0);
    return [
      LightSource3D(
        position: stageCenter,
        radius: 62.0 + syllable * 30.0,
        color: primaryColor,
        intensity: (0.78 + syllable * 0.22).clamp(0.0, 1.0),
      ),
    ];
  }

  final out = <LightSource3D>[];
  final mode = show.sectionMode;

  if (mode == LightShowSectionMode.soloShred && soloFocusPos != null) {
    out.add(
      LightSource3D(
        position: soloFocusPos,
        radius: 92.0 + show.highMid * 34.0 + show.accentFlash * 18.0,
        color: Color.lerp(primaryColor, const Color(0xFFFFFFFF), 0.35)!,
        intensity: 1.0,
      ),
    );
    return out;
  }

  // Core stage wash pool pulsing on real scanned bass & beatPulse
  final coreRadius = (mode == LightShowSectionMode.hushGlow ? 88.0 : 124.0) +
      show.bass * 26.0 +
      show.beatPulse * 16.0 +
      show.blinderBurst * 42.0;
  out.add(
    LightSource3D(
      position: stageCenter,
      radius: coreRadius,
      color: show.blinderBurst > 0.25
          ? Color.lerp(primaryColor, const Color(0xFFFFF8E7), show.blinderBurst)!
          : primaryColor,
      intensity: mode == LightShowSectionMode.hushGlow ? 0.72 : 1.0,
    ),
  );

  // Twin sweeping crowd-wash spot pools dancing across the stage apron & front lawn!
  if (mode != LightShowSectionMode.hushGlow) {
    final phase =
        (show.beatIndex + show.beatPhase) * (show.bpm / 120.0) * 1.1;
    final spreadX = mode == LightShowSectionMode.climaxPrism ? 68.0 : 44.0;
    final leftPool = Offset(
      stageCenter.dx - 28.0 + math.sin(phase) * spreadX,
      stageCenter.dy + 34.0 + math.cos(phase * 0.8) * 18.0,
    );
    final rightPool = Offset(
      stageCenter.dx + 28.0 - math.sin(phase * 0.9) * spreadX,
      stageCenter.dy + 38.0 - math.cos(phase * 0.8) * 18.0,
    );
    out.add(
      LightSource3D(
        position: leftPool,
        radius: 68.0 + show.mid * 24.0,
        color: secondaryColor,
        intensity: (0.65 + show.beatPulse * 0.35).clamp(0.0, 1.0),
      ),
    );
    out.add(
      LightSource3D(
        position: rightPool,
        radius: 68.0 + show.highMid * 24.0,
        color: mode == LightShowSectionMode.climaxPrism
            ? const Color(0xFFFF007F)
            : primaryColor,
        intensity: (0.65 + show.beatPulse * 0.35).clamp(0.0, 1.0),
      ),
    );
  }

  return out;
}
