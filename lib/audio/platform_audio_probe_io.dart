import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

void reportWebBootStage(double fraction, [String? message]) {}

void markWebWorldReady() {}

bool isWebTicketLoaderActive() => false;

void registerWebTicketTearCallback(void Function() onTorn) {}

Future<void> ensureWebAudioUnlockedAndReady() async {}

Future<String> detectPreferredTrackExtension() async {
  // SoLoud's C++ engine natively decodes Ogg Opus (.ogg) across iOS, Android & macOS.
  return 'ogg';
}

Future<String?> cacheTrackProgressive(String trackId, String ext) async {
  try {
    final supportDir = await getApplicationSupportDirectory();
    final target = File('${supportDir.path}/tracks/$trackId.$ext');
    if (await target.exists()) {
      return target.path;
    }
    final localRepoCandidate = File('assets/audio/tracks/$trackId.$ext');
    if (await localRepoCandidate.exists()) {
      await target.parent.create(recursive: true);
      await localRepoCandidate.copy(target.path);
      return target.path;
    }
  } catch (_) {
    // Non-fatal in unit test or sandboxed environments without path_provider plugin
  }
  return null;
}

Future<Uint8List?> fetchCachedWebAudioBytes(String url) async => null;
