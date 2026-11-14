import 'dart:math' as math;
import '../data/models.dart';

class SpatialMixResult {
  const SpatialMixResult({
    required this.gain,
    required this.pan,
    required this.lowPassCutoffHz,
    required this.distance,
    required this.isAudible,
  });

  final double gain;
  final double pan;
  final double lowPassCutoffHz;
  final double distance;
  final bool isAudible;
}

class SpatialStageEmitter {
  const SpatialStageEmitter._();

  /// -9 dB linear amplitude ratio: 10^(-9 / 20) ≈ 0.354813
  static const double paBroadcastDuckLinear = 0.354813389;

  /// Computes 2D spatial attenuation, stereo pan, canopy/tent LPF cutoff, and PA ducking.
  static SpatialMixResult computeMix({
    required StageInfo stage,
    required double listenerX,
    required double listenerY,
    required bool listenerInOcclusionZone,
    required bool isPaBroadcastTrack,
    required bool paBroadcastCurrentlyActive,
  }) {
    if (isPaBroadcastTrack || stage.id == 'pa_global_horn') {
      final dx = stage.x - listenerX;
      final pan = (dx / 600.0).clamp(-0.35, 0.35);
      return SpatialMixResult(
        gain: 0.92,
        pan: pan,
        lowPassCutoffHz: listenerInOcclusionZone ? 2400.0 : 5200.0,
        distance: 0.0,
        isAudible: true,
      );
    }

    final dx = stage.x - listenerX;
    final dy = stage.y - listenerY;
    final dist = math.sqrt(dx * dx + dy * dy);

    if (dist >= stage.maxDist) {
      return SpatialMixResult(
        gain: 0.0,
        pan: (dx / 280.0).clamp(-0.85, 0.85),
        lowPassCutoffHz: 420.0,
        distance: dist,
        isAudible: false,
      );
    }

    double attenuation;
    if (dist <= stage.minDist) {
      attenuation = 1.0;
    } else {
      final t = ((dist - stage.minDist) / (stage.maxDist - stage.minDist))
          .clamp(0.0, 1.0);
      // Smooth raised-cosine acoustic rolloff
      attenuation = 0.5 * (1.0 + math.cos(t * math.pi));
    }

    if (paBroadcastCurrentlyActive) {
      attenuation *= paBroadcastDuckLinear;
    }

    final pan = (dx / 260.0).clamp(-0.85, 0.85);

    // Real-time low-pass canopy & canvas tent occlusion (380 Hz - 18000 Hz)
    double cutoffHz;
    if (listenerInOcclusionZone && dist > stage.minDist * 1.15) {
      cutoffHz = 420.0;
    } else if (dist > stage.minDist * 1.5) {
      final distRatio =
          ((dist - stage.minDist) / (stage.maxDist - stage.minDist))
              .clamp(0.0, 1.0);
      cutoffHz = 18000.0 - distRatio * (18000.0 - 600.0);
    } else {
      cutoffHz = 18000.0;
    }

    return SpatialMixResult(
      gain: attenuation.clamp(0.0, 1.0),
      pan: pan,
      lowPassCutoffHz: cutoffHz,
      distance: dist,
      isAudible: attenuation > 0.008,
    );
  }
}
