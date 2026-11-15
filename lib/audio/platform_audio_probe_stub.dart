import 'dart:typed_data';

void reportWebBootStage(double fraction, [String? message]) {}

void markWebWorldReady() {}

bool isWebTicketLoaderActive() => false;

void registerWebTicketTearCallback(void Function() onTorn) {}

Future<void> ensureWebAudioUnlockedAndReady() async {}

Future<String> detectPreferredTrackExtension() async => 'ogg';

Future<String?> cacheTrackProgressive(String trackId, String ext) async => null;

Future<Uint8List?> fetchCachedWebAudioBytes(String url) async => null;
