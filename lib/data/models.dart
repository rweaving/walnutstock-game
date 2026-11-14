import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';

import '../game/world/concert_light_show.dart';

class StageInfo extends Equatable {
  const StageInfo({
    required this.id,
    required this.name,
    required this.zone,
    required this.x,
    required this.y,
    required this.minDist,
    required this.maxDist,
  });

  factory StageInfo.fromJson(String id, Map<String, dynamic> json) {
    return StageInfo(
      id: id,
      name: json['name'] as String? ?? id,
      zone: json['zone'] as String? ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      minDist: (json['minDist'] as num?)?.toDouble() ?? 80.0,
      maxDist: (json['maxDist'] as num?)?.toDouble() ?? 560.0,
    );
  }

  final String id;
  final String name;
  final String zone;
  final double x;
  final double y;
  final double minDist;
  final double maxDist;

  @override
  List<Object?> get props => [id, name, zone, x, y, minDist, maxDist];
}

class ScheduledTrack extends Equatable {
  const ScheduledTrack({
    required this.trackNumber,
    required this.id,
    required this.title,
    required this.artist,
    required this.day,
    required this.startMinute,
    required this.endMinute,
    required this.durationSeconds,
    required this.stageId,
    required this.assetPath,
    this.bundledInCore = false,
    this.isPaBroadcast = false,
    this.isBonusStem = false,
    this.worldEvent,
    this.reactiveCues = const [],
    this.subtitle,
  });

  factory ScheduledTrack.fromJson(Map<String, dynamic> json) {
    return ScheduledTrack(
      trackNumber: (json['trackNumber'] as num).toInt(),
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      day: (json['day'] as num).toInt(),
      startMinute: (json['startMinute'] as num).toDouble(),
      endMinute: (json['endMinute'] as num).toDouble(),
      durationSeconds: (json['durationSeconds'] as num).toDouble(),
      stageId: json['stageId'] as String,
      assetPath: json['assetPath'] as String,
      bundledInCore: json['bundledInCore'] as bool? ?? false,
      isPaBroadcast: json['isPaBroadcast'] as bool? ?? false,
      isBonusStem: json['isBonusStem'] as bool? ?? false,
      worldEvent: json['worldEvent'] as String?,
      reactiveCues: (json['reactiveCues'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      subtitle: json['subtitle'] as String?,
    );
  }

  final int trackNumber;
  final String id;
  final String title;
  final String artist;
  final int day;
  final double startMinute;
  final double endMinute;
  final double durationSeconds;
  final String stageId;
  final String assetPath;
  final bool bundledInCore;
  final bool isPaBroadcast;
  final bool isBonusStem;
  final String? worldEvent;
  final List<String> reactiveCues;
  final String? subtitle;

  bool isActiveAt(int currentDay, double minuteOfDay) {
    return day == currentDay &&
        minuteOfDay >= startMinute &&
        minuteOfDay < endMinute;
  }

  double seekOffsetSeconds(double minuteOfDay, double clockMinutesPerRealSec) {
    if (clockMinutesPerRealSec <= 0) return 0.0;
    final elapsedMinutes = (minuteOfDay - startMinute).clamp(
      0.0,
      endMinute - startMinute,
    );
    return (elapsedMinutes / clockMinutesPerRealSec).clamp(
      0.0,
      durationSeconds,
    );
  }

  @override
  List<Object?> get props => [
        trackNumber,
        id,
        title,
        artist,
        day,
        startMinute,
        endMinute,
        durationSeconds,
        stageId,
        assetPath,
        bundledInCore,
        isPaBroadcast,
        isBonusStem,
        worldEvent,
        reactiveCues,
        subtitle,
      ];
}

class SetlistCatalog {
  const SetlistCatalog({
    required this.albumTitle,
    required this.albumArtist,
    required this.clockMinutesPerRealSecond,
    required this.stages,
    required this.tracks,
  });

  factory SetlistCatalog.fromJson(Map<String, dynamic> json) {
    final stagesRaw = json['stages'] as Map<String, dynamic>? ?? const {};
    final stages = <String, StageInfo>{
      for (final entry in stagesRaw.entries)
        entry.key: StageInfo.fromJson(
          entry.key,
          entry.value as Map<String, dynamic>,
        ),
    };
    final tracksRaw = json['tracks'] as List<dynamic>? ?? const [];
    final tracks = tracksRaw
        .map((e) => ScheduledTrack.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);

    return SetlistCatalog(
      albumTitle: json['albumTitle'] as String? ?? 'Walnutstock (Live)',
      albumArtist: json['albumArtist'] as String? ?? 'Literally Infinite',
      clockMinutesPerRealSecond:
          (json['clockMinutesPerRealSecond'] as num?)?.toDouble() ?? 0.55,
      stages: stages,
      tracks: tracks,
    );
  }

  final String albumTitle;
  final String albumArtist;
  final double clockMinutesPerRealSecond;
  final Map<String, StageInfo> stages;
  final List<ScheduledTrack> tracks;

  List<ScheduledTrack> activeTracksAt(int day, double minuteOfDay) {
    return tracks
        .where((t) => t.isActiveAt(day, minuteOfDay))
        .toList(growable: false);
  }

  ScheduledTrack? trackByNumber(int trackNumber) {
    for (final t in tracks) {
      if (t.trackNumber == trackNumber) return t;
    }
    return null;
  }

  ScheduledTrack? trackById(String id) {
    for (final t in tracks) {
      if (t.id == id) return t;
    }
    return null;
  }

  double lastEndMinuteForDay(int day) {
    var maxEnd = 1560.0;
    for (final t in tracks) {
      if (t.day == day && t.endMinute > maxEnd) {
        maxEnd = t.endMinute;
      }
    }
    return maxEnd;
  }

  /// Finds the next scheduled performance chronologically from (day, minute).
  ScheduledTrack? nextUpcomingTrack(int day, double minuteOfDay) {
    final sorted = [...tracks]..sort((a, b) {
        final c = a.day.compareTo(b.day);
        if (c != 0) return c;
        return a.startMinute.compareTo(b.startMinute);
      });
    for (final t in sorted) {
      if (t.day > day || (t.day == day && t.startMinute > minuteOfDay + 0.5)) {
        return t;
      }
    }
    return sorted.isNotEmpty ? sorted.first : null;
  }
}

class CultivarSpec extends Equatable {
  const CultivarSpec({
    required this.id,
    required this.name,
    required this.tagline,
    this.origin = 'California Free Orchard',
    this.shellShape = 'Classic Heirloom Shell',
    this.flavorNotes = 'Warm Toasted Kernel',
    this.accentHex = '#ffd166',
  });

  factory CultivarSpec.fromJson(Map<String, dynamic> json) {
    return CultivarSpec(
      id: json['id'] as String,
      name: json['name'] as String,
      tagline: json['tagline'] as String? ?? '',
      origin: json['origin'] as String? ?? 'California Free Orchard',
      shellShape: json['shellShape'] as String? ?? 'Classic Heirloom Shell',
      flavorNotes: json['flavorNotes'] as String? ?? 'Warm Toasted Kernel',
      accentHex: json['accentHex'] as String? ?? '#ffd166',
    );
  }

  final String id;
  final String name;
  final String tagline;
  final String origin;
  final String shellShape;
  final String flavorNotes;
  final String accentHex;

  String get portraitAsset =>
      'assets/images/characters/cultivar_${id}_portrait.png';
  String get sheetAsset => 'assets/images/characters/cultivar_${id}_sheet.png';

  @override
  List<Object?> get props => [
        id,
        name,
        tagline,
        origin,
        shellShape,
        flavorNotes,
        accentHex,
      ];
}

class WardrobeItemSpec extends Equatable {
  const WardrobeItemSpec({
    required this.id,
    required this.name,
    required this.description,
    required this.unlockedByDefault,
  });

  factory WardrobeItemSpec.fromJson(Map<String, dynamic> json) {
    return WardrobeItemSpec(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      unlockedByDefault: json['unlockedByDefault'] as bool? ?? false,
    );
  }

  final String id;
  final String name;
  final String description;
  final bool unlockedByDefault;

  @override
  List<Object?> get props => [id, name, description, unlockedByDefault];
}

class VinylSpec extends Equatable {
  const VinylSpec({
    required this.id,
    required this.title,
    required this.tracks,
    required this.sourceHint,
  });

  factory VinylSpec.fromJson(Map<String, dynamic> json) {
    return VinylSpec(
      id: json['id'] as String,
      title: json['title'] as String,
      tracks: (json['tracks'] as List<dynamic>? ?? const [])
          .map((e) => (e as num).toInt())
          .toList(growable: false),
      sourceHint: json['sourceHint'] as String? ?? '',
    );
  }

  final String id;
  final String title;
  final List<int> tracks;
  final String sourceHint;

  @override
  List<Object?> get props => [id, title, tracks, sourceHint];
}

class TotemSpec extends Equatable {
  const TotemSpec({
    required this.id,
    required this.name,
    required this.zone,
    required this.x,
    required this.y,
    required this.sprite,
    required this.lore,
  });

  factory TotemSpec.fromJson(Map<String, dynamic> json) {
    return TotemSpec(
      id: json['id'] as String,
      name: json['name'] as String,
      zone: json['zone'] as String? ?? '',
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      sprite: json['sprite'] as String,
      lore: json['lore'] as String? ?? '',
    );
  }

  final String id;
  final String name;
  final String zone;
  final double x;
  final double y;
  final String sprite;
  final String lore;

  @override
  List<Object?> get props => [id, name, zone, x, y, sprite, lore];
}

class NpcSpec extends Equatable {
  const NpcSpec({
    required this.id,
    required this.spriteId,
    required this.name,
    required this.title,
    required this.zone,
    required this.catchphrase,
    required this.routine,
    required this.hiddenDetail,
    required this.voicePitch,
    required this.spawnX,
    required this.spawnY,
    required this.aiMode,
    required this.waypoints,
    required this.dialogue,
    this.questId,
    this.questTitle,
  });

  factory NpcSpec.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final rawWaypoints = json['waypoints'] as List<dynamic>? ?? const [];
    final rawDialogue = json['dialogue'] as Map<String, dynamic>? ?? const {};

    return NpcSpec(
      id: id,
      spriteId: json['spriteId'] as String? ?? 'npc_$id',
      name: json['name'] as String,
      title: json['title'] as String? ?? '',
      zone: json['zone'] as String? ?? '',
      catchphrase: json['catchphrase'] as String? ?? '',
      routine: json['routine'] as String? ?? '',
      hiddenDetail: json['hiddenDetail'] as String? ?? '',
      voicePitch: json['voicePitch'] as String? ?? 'mid',
      spawnX: (json['spawnX'] as num).toDouble(),
      spawnY: (json['spawnY'] as num).toDouble(),
      aiMode: json['aiMode'] as String? ?? 'stationary',
      waypoints: rawWaypoints
          .map(
            (pair) => [
              ((pair as List<dynamic>)[0] as num).toDouble(),
              (pair[1] as num).toDouble(),
            ],
          )
          .toList(growable: false),
      questId: json['questId'] as String?,
      questTitle: json['questTitle'] as String?,
      dialogue: {
        for (final entry in rawDialogue.entries)
          entry.key: (entry.value as List<dynamic>)
              .map((line) => line.toString())
              .toList(growable: false),
      },
    );
  }

  final String id;
  final String spriteId;
  final String name;
  final String title;
  final String zone;
  final String catchphrase;
  final String routine;
  final String hiddenDetail;
  final String voicePitch;
  final double spawnX;
  final double spawnY;
  final String aiMode;
  final List<List<double>> waypoints;
  final String? questId;
  final String? questTitle;
  final Map<String, List<String>> dialogue;

  String get portraitAsset =>
      'assets/images/characters/${spriteId}_portrait.png';
  String get sheetAsset => 'assets/images/characters/${spriteId}_sheet.png';

  @override
  List<Object?> get props => [id, spriteId, name, spawnX, spawnY, questId];
}

class FestivalDataBundle {
  const FestivalDataBundle({
    required this.setlist,
    required this.cultivars,
    required this.wardrobe,
    required this.vinyls,
    required this.totems,
    required this.npcs,
    this.lightshows = ConcertLightShowLibrary.empty,
  });

  factory FestivalDataBundle.fromJsonMaps({
    required Map<String, dynamic> setlistJson,
    required Map<String, dynamic> npcsJson,
    Map<String, dynamic>? lightshowsJson,
  }) {
    return FestivalDataBundle(
      setlist: SetlistCatalog.fromJson(setlistJson),
      cultivars: (npcsJson['cultivars'] as List<dynamic>? ?? const [])
          .map((e) => CultivarSpec.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      wardrobe: (npcsJson['wardrobe'] as List<dynamic>? ?? const [])
          .map((e) => WardrobeItemSpec.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      vinyls: (npcsJson['vinyls'] as List<dynamic>? ?? const [])
          .map((e) => VinylSpec.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      totems: (npcsJson['totems'] as List<dynamic>? ?? const [])
          .map((e) => TotemSpec.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      npcs: (npcsJson['npcs'] as List<dynamic>? ?? const [])
          .map((e) => NpcSpec.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      lightshows: lightshowsJson != null
          ? ConcertLightShowLibrary.fromJson(lightshowsJson)
          : ConcertLightShowLibrary.empty,
    );
  }

  static Future<FestivalDataBundle> loadFromAssets(
      [AssetBundle? bundle]) async {
    final assetBundle = bundle ?? rootBundle;
    final results = await Future.wait([
      assetBundle.loadString('assets/data/setlist_26_tracks.json'),
      assetBundle.loadString('assets/data/npcs_and_quests.json'),
    ]);
    Map<String, dynamic>? lightshowsJson;
    try {
      final rawShow =
          await assetBundle.loadString('assets/data/track_lightshows.json');
      lightshowsJson = jsonDecode(rawShow) as Map<String, dynamic>;
    } catch (_) {
      lightshowsJson = null;
    }
    return FestivalDataBundle.fromJsonMaps(
      setlistJson: jsonDecode(results[0]) as Map<String, dynamic>,
      npcsJson: jsonDecode(results[1]) as Map<String, dynamic>,
      lightshowsJson: lightshowsJson,
    );
  }

  final SetlistCatalog setlist;
  final List<CultivarSpec> cultivars;
  final List<WardrobeItemSpec> wardrobe;
  final List<VinylSpec> vinyls;
  final List<TotemSpec> totems;
  final List<NpcSpec> npcs;
  final ConcertLightShowLibrary lightshows;

  NpcSpec? npcById(String id) {
    for (final n in npcs) {
      if (n.id == id) return n;
    }
    return null;
  }
}
