import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'festival_clock.dart';
import 'journal_state.dart';
import 'player_profile.dart';
import 'settings_state.dart';
import 'world_flags.dart';

class SaveSnapshot {
  const SaveSnapshot({
    required this.profile,
    required this.clock,
    required this.flags,
    required this.journal,
    required this.settings,
    required this.savedAtIso,
    this.schemaVersion = currentSchemaVersion,
  });

  factory SaveSnapshot.fromJson(Map<String, dynamic> json) {
    final schemaVersion = (json['schemaVersion'] as num?)?.toInt() ?? 1;
    final profileMap =
        (json['profile'] as Map?)?.cast<String, dynamic>() ?? const {};
    final clockMap =
        (json['clock'] as Map?)?.cast<String, dynamic>() ?? const {};
    final flagsMap =
        (json['flags'] as Map?)?.cast<String, dynamic>() ?? const {};
    final journalMap =
        (json['journal'] as Map?)?.cast<String, dynamic>() ?? const {};
    final settingsMap =
        (json['settings'] as Map?)?.cast<String, dynamic>() ?? const {};

    return SaveSnapshot(
      profile: PlayerProfile.fromJson(profileMap, schemaVersion: schemaVersion),
      clock: FestivalClockState.fromJson(clockMap),
      flags: WorldFlags.fromJson(flagsMap),
      journal: JournalState.fromJson(journalMap),
      settings: SettingsState.fromJson(settingsMap),
      savedAtIso: json['savedAtIso'] as String? ??
          DateTime.now().toUtc().toIso8601String(),
      schemaVersion: currentSchemaVersion,
    );
  }

  static const int currentSchemaVersion = 2;

  final PlayerProfile profile;
  final FestivalClockState clock;
  final WorldFlags flags;
  final JournalState journal;
  final SettingsState settings;
  final String savedAtIso;
  final int schemaVersion;

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'profile': profile.toJson(),
        'clock': clock.toJson(),
        'flags': flags.toJson(),
        'journal': journal.toJson(),
        'settings': settings.toJson(),
        'savedAtIso': savedAtIso,
      };
}

class SaveRepository {
  SaveRepository({Box<String>? injectedBox}) : _box = injectedBox;

  static const String boxName = 'walnutstock_saves_v1';
  static const String primarySlotKey = 'slot_primary';

  final Box<String>? _box;
  final Map<String, String> _memoryFallback = {};

  static Future<SaveRepository> open() async {
    try {
      if (!kIsWeb) {
        final dir = await getApplicationSupportDirectory();
        Hive.init(dir.path);
      }
      final box = await Hive.openBox<String>(boxName);
      return SaveRepository(injectedBox: box);
    } catch (_) {
      return SaveRepository();
    }
  }

  bool get hasPrimarySave {
    final raw = _readRaw(primarySlotKey);
    return raw != null && raw.isNotEmpty;
  }

  SaveSnapshot? loadPrimary() {
    final raw = _readRaw(primarySlotKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return SaveSnapshot.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> savePrimary(SaveSnapshot snapshot) async {
    final encoded = jsonEncode(snapshot.toJson());
    await _writeRaw(primarySlotKey, encoded);
  }

  Future<void> clearPrimary() async {
    if (_box != null) {
      await _box.delete(primarySlotKey);
    }
    _memoryFallback.remove(primarySlotKey);
  }

  String? _readRaw(String key) {
    if (_box != null) {
      return _box.get(key);
    }
    return _memoryFallback[key];
  }

  Future<void> _writeRaw(String key, String value) async {
    _memoryFallback[key] = value;
    if (_box != null) {
      await _box.put(key, value);
    }
  }
}
