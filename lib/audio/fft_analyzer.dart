import 'dart:math' as math;
import 'package:flutter_soloud/flutter_soloud.dart';
import '../data/models.dart';
import '../game/world/concert_light_show.dart';

class FftFrame {
  const FftFrame({
    this.subBass = 0.0,
    this.bass = 0.0,
    this.lowMid = 0.0,
    this.organ440 = 0.0,
    this.highMid = 0.0,
    this.air = 0.0,
    this.gMajorActive = false,
  });

  final double subBass;
  final double bass;
  final double lowMid;
  final double organ440;
  final double highMid;
  final double air;
  final bool gMajorActive;
}

class FftAnalyzer {
  AudioData? _audioData;
  bool _fftAvailable = false;

  void initializeIfSupported() {
    try {
      if (SoLoud.instance.isInitialized) {
        SoLoud.instance.setVisualizationEnabled(true);
        _audioData = AudioData(GetSamplesKind.linear);
        _fftAvailable = true;
      }
    } catch (_) {
      _fftAvailable = false;
    }
  }

  FftFrame sample({
    required double timeSeconds,
    required List<ScheduledTrack> activeTracks,
    required double audibleStageGain,
    StageShowFrame? scannedShowFrame,
  }) {
    if (audibleStageGain <= 0.01 && activeTracks.isEmpty) {
      return const FftFrame();
    }

    final cues = <String>{
      for (final t in activeTracks) ...t.reactiveCues,
    };
    final gMajor = cues.contains('g_major_chord') &&
        (scannedShowFrame != null
            ? (scannedShowFrame.mid > 0.45 || scannedShowFrame.highMid > 0.45)
            : (math.sin(timeSeconds * 1.4) > 0.25));

    if (_fftAvailable && _audioData != null) {
      try {
        _audioData!.updateSamples();
        final samples = _audioData!.getAudioData();
        if (samples.length >= 128) {
          double bandAvg(int start, int end) {
            var sum = 0.0;
            final count = math.max(1, end - start);
            for (var i = start; i < end && i < samples.length; i++) {
              sum += samples[i].abs();
            }
            return (sum / count * 3.2).clamp(0.0, 1.0);
          }

          final sub = bandAvg(0, 6);
          final bass = bandAvg(6, 18);
          final lowMid = bandAvg(18, 36);
          final organ = bandAvg(36, 56);
          final highMid = bandAvg(56, 88);
          final air = bandAvg(88, 128);
          if (sub + bass + lowMid + organ > 0.01) {
            return FftFrame(
              subBass: sub,
              bass: bass,
              lowMid: lowMid,
              organ440:
                  cues.contains('organ_440') ? math.max(organ, 0.55) : organ,
              highMid: highMid,
              air: air,
              gMajorActive: gMajor,
            );
          }
        }
      } catch (_) {
        // Fall through to real scanned envelope / musical cue synthesis
      }
    }

    // Use real 100ms-scanned audio envelopes & beat transients when available!
    if (scannedShowFrame != null) {
      final hasOrgan = cues.contains('organ_440');
      final gainScale = math.max(0.25, audibleStageGain);
      return FftFrame(
        subBass: (scannedShowFrame.bass *
                (0.85 + scannedShowFrame.beatPulse * 0.25) *
                gainScale)
            .clamp(0.0, 1.0),
        bass: (scannedShowFrame.bass * gainScale).clamp(0.0, 1.0),
        lowMid: (scannedShowFrame.mid * gainScale).clamp(0.0, 1.0),
        organ440: ((hasOrgan
                    ? math.max(scannedShowFrame.mid, 0.54)
                    : scannedShowFrame.mid * 0.65) *
                gainScale)
            .clamp(0.0, 1.0),
        highMid: (scannedShowFrame.highMid * gainScale).clamp(0.0, 1.0),
        air: (scannedShowFrame.air * gainScale).clamp(0.0, 1.0),
        gMajorActive: gMajor,
      );
    }

    // Schedule-synced musical envelope fallback (ensures shaders, spotlights & haptics stay reactive everywhere)
    final beat = 0.5 + 0.5 * math.sin(timeSeconds * 6.8);
    final swell = 0.5 + 0.5 * math.sin(timeSeconds * 1.9);
    final hasBass = cues.contains('bass_pulse');
    final hasOrgan = cues.contains('organ_440');
    final hasVocal = cues.contains('vocal_peak');

    return FftFrame(
      subBass: (hasBass ? 0.45 + 0.5 * beat : 0.2 * beat) * audibleStageGain,
      bass: (hasBass ? 0.4 + 0.55 * beat : 0.25 * beat) * audibleStageGain,
      lowMid: (0.3 + 0.4 * swell) * audibleStageGain,
      organ440:
          (hasOrgan ? 0.55 + 0.4 * swell : 0.15 * swell) * audibleStageGain,
      highMid: (hasVocal ? 0.6 + 0.35 * swell : 0.25 * beat) * audibleStageGain,
      air: 0.2 * swell * audibleStageGain,
      gMajorActive: gMajor,
    );
  }

  void dispose() {
    _audioData?.dispose();
    _audioData = null;
    _fftAvailable = false;
  }
}
