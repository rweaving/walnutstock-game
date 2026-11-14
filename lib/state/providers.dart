import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import 'dialogue_and_overlay_state.dart';
import 'festival_clock.dart';
import 'journal_state.dart';
import 'player_profile.dart';
import 'save_repository.dart';
import 'settings_state.dart';
import 'world_flags.dart';

final festivalDataProvider = Provider<FestivalDataBundle>((ref) {
  throw UnimplementedError('festivalDataProvider must be overridden at boot');
});

final saveRepositoryProvider = Provider<SaveRepository>((ref) {
  return SaveRepository();
});

final playerProfileProvider =
    StateNotifierProvider<PlayerProfileNotifier, PlayerProfile>(
  (ref) => PlayerProfileNotifier(),
);

final festivalClockProvider =
    StateNotifierProvider<FestivalClockNotifier, FestivalClockState>((ref) {
  SetlistCatalog? catalog;
  try {
    catalog = ref.watch(festivalDataProvider).setlist;
  } catch (_) {
    catalog = null;
  }
  return FestivalClockNotifier(catalog);
});

final worldFlagsProvider =
    StateNotifierProvider<WorldFlagsNotifier, WorldFlags>(
  (ref) => WorldFlagsNotifier(),
);

final journalStateProvider =
    StateNotifierProvider<JournalStateNotifier, JournalState>(
  (ref) => JournalStateNotifier(),
);

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);

final uiOverlayProvider =
    StateNotifierProvider<UiOverlayNotifier, UiOverlayState>(
  (ref) => UiOverlayNotifier(),
);

/// Helper to persist all active providers into `walnutstock_saves_v1` (`slot_primary`).
Future<void> persistCurrentGameState(WidgetRef ref) async {
  final repo = ref.read(saveRepositoryProvider);
  final snapshot = SaveSnapshot(
    profile: ref.read(playerProfileProvider),
    clock: ref.read(festivalClockProvider),
    flags: ref.read(worldFlagsProvider),
    journal: ref.read(journalStateProvider),
    settings: ref.read(settingsProvider),
    savedAtIso: DateTime.now().toUtc().toIso8601String(),
  );
  await repo.savePrimary(snapshot);
}

Future<void> persistCurrentGameStateFromContainer(ProviderContainer c) async {
  final repo = c.read(saveRepositoryProvider);
  final snapshot = SaveSnapshot(
    profile: c.read(playerProfileProvider),
    clock: c.read(festivalClockProvider),
    flags: c.read(worldFlagsProvider),
    journal: c.read(journalStateProvider),
    settings: c.read(settingsProvider),
    savedAtIso: DateTime.now().toUtc().toIso8601String(),
  );
  await repo.savePrimary(snapshot);
}
