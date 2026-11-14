// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/walnutstock_app.dart';
import 'audio/soloud_audio_service.dart';
import 'data/models.dart';
import 'game/world/tiled_map_parser.dart';
import 'state/providers.dart';
import 'state/save_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final results = await Future.wait([
    FestivalDataBundle.loadFromAssets(),
    TiledMapParser.loadFromAssets(),
    SaveRepository.open(),
  ]);

  final data = results[0] as FestivalDataBundle;
  final mapData = results[1] as OrchardMapData;
  final saveRepo = results[2] as SaveRepository;
  final audioService = SoloudAudioService();

  runApp(
    ProviderScope(
      overrides: [
        festivalDataProvider.overrideWithValue(data),
        saveRepositoryProvider.overrideWithValue(saveRepo),
      ],
      child: WalnutstockApp(
        data: data,
        mapData: mapData,
        audioService: audioService,
      ),
    ),
  );
}
