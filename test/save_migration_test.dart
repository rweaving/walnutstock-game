import 'package:flutter_test/flutter_test.dart';
import 'package:walnutstock/state/festival_clock.dart';
import 'package:walnutstock/state/save_repository.dart';

void main() {
  group('v0.1.0 -> v1.0 Save Slot Forward Compatibility (walnutstock_saves_v1)',
      () {
    test(
        'migrates legacy v0.1.0 slot_primary JSON cleanly without losing progress or spawning out-of-bounds',
        () {
      final legacyV010Json = <String, dynamic>{
        'profile': {
          'ticketTorn': true,
          'cultivarConfirmed': true,
          'guestName': 'Groovy Franquette',
          'cultivarId': 'franquette',
          'equippedWardrobeId': 'heart_specs',
          'unlockedWardrobeIds': ['none', 'moss_band', 'heart_specs'],
          'savedX': 304.0,
          'savedY': 648.0,
        },
        'clock': {
          'day': 2,
          'minuteOfDay': 745.0,
          'weather': 'clear',
          'pureVibeMode': true,
          'wristbandAlertsEnabled': true,
          'encoreModeUnlocked': false,
        },
        'flags': {
          'fencesDropped': true,
          'lanternsLit': true,
          'firefliesActive': true,
          'mossBridgesBloomed': false,
          'slowWaveSwayUnlocked': true,
          'dewDropsCollected': ['dew_1', 'dew_2', 'dew_3'],
          'ziggyQuestStarted': true,
          'ziggyQuestCompleted': true,
          'breezewalkerQuestStarted': true,
          'hasWillowPick': false,
          'breezewalkerQuestCompleted': false,
          'burtQuestStarted': true,
          'falafelCiderOffered': true,
          'burtQuestCompleted': true,
          'bittershellMapCompleted': true,
        },
        'journal': {
          'metNpcIds': ['patchouli_pete', 'ziggy_shellshock', 'burt_baskernut'],
          'unlockedHiddenDetailNpcIds': ['ziggy_shellshock', 'burt_baskernut'],
          'stampedTrackNumbers': [1, 2, 3, 4, 8, 10, 12],
          'collectedItems': [
            'Tangerine Heart Specs',
            'Fermented Persimmon Cider'
          ],
        },
        'savedAtIso': '2026-11-13T12:00:00Z',
      };

      final migrated = SaveSnapshot.fromJson(legacyV010Json);
      expect(migrated.schemaVersion, SaveSnapshot.currentSchemaVersion);
      expect(migrated.profile.guestName, 'Groovy Franquette');
      expect(migrated.profile.cultivarId, 'franquette');
      expect(migrated.profile.equippedWardrobeId, 'heart_specs');
      // v0.1.0 Front Gate (304, 648) translates cleanly to v1.0 Front Gate (608, 1344)
      expect(migrated.profile.savedX, 608.0);
      expect(migrated.profile.savedY, 1344.0);

      expect(migrated.clock.day, 2);
      expect(migrated.clock.pureVibeMode, isTrue);
      expect(migrated.flags.fencesDropped, isTrue);
      expect(migrated.flags.ziggyQuestCompleted, isTrue);
      expect(migrated.flags.burtQuestCompleted, isTrue);
      // Newly added Phase 3-5 flags default safely
      expect(migrated.flags.janiceQuestCompleted, isFalse);
      expect(migrated.flags.tunedResonators, isEmpty);

      expect(migrated.journal.stampedTrackNumbers, containsAll([1, 2, 10, 12]));
      expect(migrated.journal.collectedVinylIds, isEmpty);
      expect(migrated.journal.collectedTotemIds, isEmpty);
    });

    test(
        'round-trips v1.0 SaveSnapshot via SaveRepository without coordinate double-offsetting',
        () async {
      final repo = SaveRepository();
      expect(repo.hasPrimarySave, isFalse);

      final snap = SaveSnapshot.fromJson({
        'schemaVersion': 2,
        'profile': {
          'ticketTorn': true,
          'cultivarConfirmed': true,
          'guestName': 'Wen-wan Sage',
          'cultivarId': 'wen_wan',
          'savedX': 1760.0,
          'savedY': 368.0,
        },
        'clock': {
          'day': 3,
          'minuteOfDay': 1520.0,
          'weather': WeatherPhase.purpleDustFinale.name,
          'encoreModeUnlocked': true,
        },
        'flags': {
          'cosmoQuestCompleted': true,
          'tunedResonators': ['resonator_nw', 'resonator_ne', 'resonator_se'],
          'pinballHighScore': 4200,
        },
        'journal': {
          'collectedVinylIds': ['vinyl_side_a', 'vinyl_bootleg_drupe'],
          'collectedTotemIds': ['totem_01', 'totem_05'],
        },
      });

      await repo.savePrimary(snap);
      expect(repo.hasPrimarySave, isTrue);

      final loaded = repo.loadPrimary()!;
      expect(loaded.profile.savedX, 1760.0);
      expect(loaded.profile.savedY, 368.0);
      expect(loaded.clock.encoreModeUnlocked, isTrue);
      expect(loaded.flags.tunedResonators.length, 3);
      expect(loaded.flags.pinballHighScore, 4200);
      expect(loaded.journal.collectedTotemIds,
          containsAll(['totem_01', 'totem_05']));
    });

    test('handles empty or corrupted JSON gracefully without throwing', () {
      final fallback = SaveSnapshot.fromJson(const {});
      expect(fallback.profile.cultivarId, 'chandler');
      expect(fallback.clock.day, 1);
      expect(fallback.profile.savedX, inInclusiveRange(64.0, 1984.0));
    });
  });
}
